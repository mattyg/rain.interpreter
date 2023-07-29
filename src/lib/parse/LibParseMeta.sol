// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "./LibCtPop.sol";

/// @dev For metadata builder.
error DuplicateFingerprint();

/// @dev Words and io fn pointers aren't the same length.
error WordIOFnPointerMismatch(uint256 wordsLength, uint256 ioFnPointersLength);

/// @dev 0xFFFFFF = 3 byte fingerprint
/// The fingerprint is 3 bytes because we're targetting the same collision
/// resistance on words as solidity functions. As we already use a fully byte to
/// map words across the expander, we only need 3 bytes for the fingerprint to
/// achieve 4 bytes of collision resistance, which is the same as a solidity
/// selector. This assumes that the byte selected to expand is uncorrelated with
/// the fingerprint bytes, which is a reasonable assumption as long as we use
/// different bytes from a keccak256 hash for each.
/// This assumes a single expander, if there are multiple expanders, then the
/// collision resistance only improves, so this is still safe.
uint256 constant FINGERPRINT_MASK = 0xFFFFFF;
/// @dev 4 = 1 byte opcode index + 3 byte fingerprint
uint256 constant META_ITEM_SIZE = 4;
uint256 constant META_ITEM_MASK = (1 << META_ITEM_SIZE) - 1;
/// @dev 33 = 32 bytes for expansion + 1 byte for seed
uint256 constant META_EXPANSION_SIZE = 0x21;
/// @dev 1 = 1 byte for depth
uint256 constant META_PREFIX_SIZE = 1;

library LibParseMeta {
    function wordBitmapped(uint256 seed, bytes32 word) internal pure returns (uint256 bitmap, uint256 hashed) {
        assembly ("memory-safe") {
            mstore(0, word)
            mstore8(0x20, seed)
            hashed := keccak256(0, 0x21)
            // We have to be careful here to avoid using the same byte for both
            // the expansion and the fingerprint. This is because we are relying
            // on the combined effect of both for collision resistance. We do
            // this by using the high byte of the hash for the bitmap, and the
            // low 3 bytes for the fingerprint.
            //slither-disable-next-line incorrect-shift
            bitmap := shl(byte(0, hashed), 1)
        }
    }

    function findBestExpander(bytes32[] memory words)
        internal
        pure
        returns (uint8 bestSeed, uint256 bestExpansion, bytes32[] memory remaining)
    {
        unchecked {
            {
                uint256 bestCt = 0;
                for (uint256 seed = 0; seed < type(uint8).max; seed++) {
                    uint256 expansion = 0;
                    for (uint256 i = 0; i < words.length; i++) {
                        (uint256 shifted, uint256 hashed) = wordBitmapped(seed, words[i]);
                        (hashed);
                        expansion = shifted | expansion;
                    }
                    uint256 ct = LibCtPop.ctpop(expansion);
                    if (ct > bestCt) {
                        bestCt = ct;
                        bestSeed = uint8(seed);
                        bestExpansion = expansion;
                    }
                    // perfect expansion.
                    if (ct == words.length) {
                        break;
                    }
                }
            }
            remaining = new bytes32[](words.length - LibCtPop.ctpop(bestExpansion));
            uint256 usedExpansion = 0;
            uint256 j = 0;
            for (uint256 i = 0; i < words.length; i++) {
                (uint256 shifted, uint256 hashed) = wordBitmapped(bestSeed, words[i]);
                (hashed);
                if ((shifted & usedExpansion) == 0) {
                    usedExpansion = shifted | usedExpansion;
                } else {
                    remaining[j] = words[i];
                    j++;
                }
            }
        }
    }

    function buildMeta(bytes32[] memory words, uint8 maxDepth)
        internal
        pure
        returns (bytes memory meta)
    {
        unchecked {
            // Write out expansions.
            uint8[] memory seeds;
            uint256[] memory expansions;
            bytes32[] memory ogWords;
            uint256 dataStart;
            {
                uint256 depth = 0;
                seeds = new uint8[](maxDepth);
                expansions = new uint256[](maxDepth);
                ogWords = words;
                while (words.length > 0) {
                    uint8 seed;
                    uint256 expansion;
                    (seed, expansion, words) = findBestExpander(words);
                    seeds[depth] = seed;
                    expansions[depth] = expansion;
                    depth++;
                }

                uint256 metaLength = META_PREFIX_SIZE + depth * META_EXPANSION_SIZE + ogWords.length * META_ITEM_SIZE;
                meta = new bytes(metaLength);
                assembly ("memory-safe") {
                    mstore8(add(meta, 0x20), depth)
                }
                for (uint256 j = 0; j < depth; j++) {
                    assembly ("memory-safe") {
                        // Write each seed immediately before its expansion.
                        let seedWriteAt := add(add(meta, 0x21), mul(0x21, j))
                        mstore8(seedWriteAt, mload(add(seeds, add(0x20, mul(0x20, j)))))
                        mstore(add(seedWriteAt, 1), mload(add(expansions, add(0x20, mul(0x20, j)))))
                    }
                }

                {
                    uint256 dataOffset = META_PREFIX_SIZE + META_ITEM_SIZE + depth * META_EXPANSION_SIZE;
                    assembly ("memory-safe") {
                        dataStart := add(meta, dataOffset)
                    }
                }
            }

            // Write words.
            for (uint256 k = 0; k < ogWords.length; k++) {
                uint256 s = 0;
                uint256 cumulativePos = 0;
                while (true) {
                    uint256 toWrite;
                    uint256 writeAt;

                    // Need some careful scoping here to avoid stack too deep.
                    {
                        uint256 expansion = expansions[s];

                        uint256 shifted;
                        uint256 hashed;
                        {
                            uint8 seed = seeds[s];
                            (shifted, hashed) = wordBitmapped(seed, ogWords[k]);

                            uint256 metaItemSize = META_ITEM_SIZE;
                            uint256 pos = LibCtPop.ctpop(expansion & (shifted - 1)) + cumulativePos;
                            assembly ("memory-safe") {
                                writeAt := add(dataStart, mul(pos, metaItemSize))
                            }
                        }

                        {
                            uint256 wordFingerprint = hashed & FINGERPRINT_MASK;
                            uint256 posFingerprint;
                            assembly ("memory-safe") {
                                posFingerprint := mload(writeAt)
                            }
                            posFingerprint &= FINGERPRINT_MASK;
                            if (posFingerprint != 0) {
                                if (posFingerprint == wordFingerprint) {
                                    revert DuplicateFingerprint();
                                }
                                // Collision, try next expansion.
                                s++;
                                cumulativePos = cumulativePos + LibCtPop.ctpop(expansion);
                                continue;
                            }
                            // Not collision, start preparing the write with the
                            // fingerprint.
                            toWrite = wordFingerprint;
                        }
                    }

                    // Write the io fn pointer and index offset.
                    toWrite |= k << 0x18;

                    uint256 mask = ~META_ITEM_MASK;
                    assembly ("memory-safe") {
                        mstore(writeAt, or(and(mload(writeAt), mask), toWrite))
                    }
                    // We're done with this word.
                    break;
                }
            }
        }
    }

    /// Given the parse meta and a word, return the index and io fn pointer for
    /// the word. If the word is not found, then `exists` will be false. The
    /// caller MUST check `exists` before using the other return values.
    /// @param meta The parse meta.
    /// @param word The word to lookup.
    /// @return True if the word exists in the parse meta.
    /// @return The index of the word in the parse meta.
    function lookupWordIndex(bytes memory meta, bytes32 word) internal pure returns (bool, uint256) {
        unchecked {
            uint256 dataStart;
            uint256 cursor;
            uint256 end;
            {
                uint256 metaExpansionSize = META_EXPANSION_SIZE;
                uint256 metaItemSize = META_ITEM_SIZE;
                assembly ("memory-safe") {
                    // Read depth from first meta byte.
                    cursor := add(meta, 1)
                    let depth := and(mload(cursor), 0xFF)
                    // 33 bytes per depth
                    end := add(cursor, mul(depth, metaExpansionSize))
                    dataStart := add(end, metaItemSize)
                }
            }

            uint256 cumulativeCt = 0;
            while (cursor < end) {
                uint256 expansion;
                uint256 posData;
                uint256 wordFingerprint;
                // Lookup the data at pos.
                {
                    uint256 seed;
                    assembly ("memory-safe") {
                        cursor := add(cursor, 1)
                        seed := and(mload(cursor), 0xFF)
                        cursor := add(cursor, 0x20)
                        expansion := mload(cursor)
                    }

                    (uint256 shifted, uint256 hashed) = wordBitmapped(seed, word);
                    uint256 pos = LibCtPop.ctpop(expansion & (shifted - 1)) + cumulativeCt;
                    wordFingerprint = hashed & FINGERPRINT_MASK;
                    uint256 metaItemSize = META_ITEM_SIZE;
                    assembly ("memory-safe") {
                        posData := mload(add(dataStart, mul(pos, metaItemSize)))
                    }
                }

                // Match
                if (wordFingerprint == posData & FINGERPRINT_MASK) {
                    uint256 index;
                    assembly ("memory-safe") {
                        index := byte(28, posData)
                    }
                    return (true, index);
                } else {
                    cumulativeCt += LibCtPop.ctpop(expansion);
                }
            }
            return (false, 0);
        }
    }
}
