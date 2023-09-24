// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import "../../interface/IInterpreterV1.sol";
import "rain.solmem/lib/LibPointer.sol";
import "rain.solmem/lib/LibBytes.sol";
import "rain.solmem/lib/LibMemCpy.sol";

/// Thrown when a bytecode source index is out of bounds.
/// @param bytecode The bytecode that was inspected.
/// @param sourceIndex The source index that was out of bounds.
error SourceIndexOutOfBounds(bytes bytecode, uint256 sourceIndex);

/// Thrown when a bytecode reports itself as 0 sources but has more than 1 byte.
/// @param bytecode The bytecode that was inspected.
error UnexpectedSources(bytes bytecode);

/// Thrown when bytes are discovered between the offsets and the sources.
/// @param bytecode The bytecode that was inspected.
error UnexpectedTrailingOffsetBytes(bytes bytecode);

/// Thrown when the end of a source as self reported by its header doesnt match
/// the start of the next source or the end of the bytecode.
/// @param bytecode The bytecode that was inspected.
error TruncatedSource(bytes bytecode);

/// Thrown when the offset to a source points to a location that cannot fit a
/// header before the start of the next source or the end of the bytecode.
/// @param bytecode The bytecode that was inspected.
error TruncatedHeader(bytes bytecode);

/// Thrown when the bytecode is truncated before the end of the header offsets.
/// @param bytecode The bytecode that was inspected.
error TruncatedHeaderOffsets(bytes bytecode);

/// @title LibBytecode
/// @notice A library for inspecting the bytecode of an expression. Largely
/// focused on reading the source headers rather than the opcodes themselves.
/// Designed to be efficient enough to be used in the interpreter directly.
/// As such, it is not particularly safe, notably it always assumes that the
/// headers are not lying about the structure and runtime behaviour of the
/// bytecode. This is by design as it allows much more simple, efficient and
/// decoupled implementation of authoring/parsing logic, which makes the author
/// of an expression responsible for producing well formed bytecode, such as
/// balanced LHS/RHS stacks. The deployment integrity checks are responsible for
/// checking that the headers match the structure and behaviour of the bytecode.
library LibBytecode {
    using LibPointer for Pointer;
    using LibBytes for bytes;
    using LibMemCpy for Pointer;

    /// The number of sources in the bytecode.
    /// If the bytecode is empty, returns 0.
    /// Otherwise, returns the first byte of the bytecode, which is the number
    /// of sources.
    /// Implies that 0x and 0x00 are equivalent, both having 0 sources. For this
    /// reason, contracts that handle bytecode MUST NOT rely on simple data
    /// length checks to determine if the bytecode is empty or not.
    /// DOES NOT check the integrity or even existence of the sources.
    /// @param bytecode The bytecode to inspect.
    /// @return count The number of sources in the bytecode.
    function sourceCount(bytes memory bytecode) internal pure returns (uint256 count) {
        if (bytecode.length == 0) {
            return 0;
        }
        assembly {
            // The first byte of rain bytecode is the count of how many sources
            // there are.
            count := byte(0, mload(add(bytecode, 0x20)))
        }
    }

    /// Checks the structural integrity of the bytecode from the perspective of
    /// potential out of bounds reads. Will revert if the bytecode is not
    /// well-formed. This check MUST be done BEFORE any attempts at per-opcode
    /// integrity checks, as the per-opcode checks assume that the headers define
    /// valid regions in memory to iterate over.
    ///
    /// Checks:
    /// - The offsets are populated according to the source count.
    /// - The offsets point to positions within the bytecode `bytes`.
    /// - There exists at least the 4 byte header for each source at the offset,
    ///   within the bounds of the bytecode `bytes`.
    /// - The number of opcodes specified in the header of each source locates
    ///   the end of the source exactly at either the offset of the next source
    ///   or the end of the bytecode `bytes`.
    function checkNoOOBPointers(bytes memory bytecode) internal pure {
        unchecked {
            uint256 count = sourceCount(bytecode);
            // The common case is that there are more than 0 sources.
            if (count > 0) {
                uint256 sourcesRelativeStart = 1 + count * 2;
                if (sourcesRelativeStart > bytecode.length) {
                    revert TruncatedHeaderOffsets(bytecode);
                }
                uint256 sourcesStart;
                assembly ("memory-safe") {
                    sourcesStart := add(bytecode, add(0x20, sourcesRelativeStart))
                }

                // Start at the end of the bytecode and work backwards. Find the
                // last unchecked relative offset, follow it, read the opcode
                // count from the header, and check that ends at the end cursor.
                // Set the end cursor to the relative offset then repeat until
                // there are no more unchecked relative offsets. The endCursor
                // as a relative offset must be 0 at the end of this process
                // (i.e. the first relative offset is always 0).
                uint256 endCursor;
                assembly ("memory-safe") {
                    endCursor := add(bytecode, add(0x20, mload(bytecode)))
                }
                // This cursor points at the 2 byte relative offset that we need
                // to check next.
                uint256 uncheckedOffsetCursor;
                uint256 end;
                assembly ("memory-safe") {
                    uncheckedOffsetCursor := add(bytecode, add(0x21, mul(sub(count, 1), 2)))
                    end := add(bytecode, 0x21)
                }

                while (uncheckedOffsetCursor >= end) {
                    // Read the relative offset from the bytecode.
                    uint256 relativeOffset;
                    assembly ("memory-safe") {
                        relativeOffset := shr(0xF0, mload(uncheckedOffsetCursor))
                    }
                    uint256 absoluteOffset = sourcesStart + relativeOffset;

                    // Check that the 4 byte header is within the upper bound
                    // established by the end cursor before attempting to read
                    // from it.
                    uint256 headerEnd = absoluteOffset + 4;
                    if (headerEnd > endCursor) {
                        revert TruncatedHeader(bytecode);
                    }

                    // The ops count is the first byte of the header.
                    uint256 opsCount;
                    assembly ("memory-safe") {
                        opsCount := byte(0, mload(absoluteOffset))
                    }

                    // The ops count is the number of 4 byte opcodes in the
                    // source. Check that the end of the source is at the end
                    // cursor.
                    uint256 sourceEnd = headerEnd + opsCount * 4;
                    if (sourceEnd != endCursor) {
                        revert TruncatedSource(bytecode);
                    }

                    // Move the end cursor to the start of the header.
                    endCursor = absoluteOffset;
                    // Move the unchecked offset cursor to the previous offset.
                    uncheckedOffsetCursor -= 2;
                }

                // If the end cursor is not pointing at the absolute start of the
                // sources, then somehow the bytecode has malformed data between
                // the offsets and the sources.
                if (endCursor != sourcesStart) {
                    revert UnexpectedTrailingOffsetBytes(bytecode);
                }
            } else {
                // If there are no sources the bytecode is either 0 length or a
                // single 0 byte, which we already implicity checked by reaching
                // this code path. Ensure the bytecode has no trailing bytes.
                if (bytecode.length > 1) {
                    revert UnexpectedSources(bytecode);
                }
            }
        }
    }

    /// The relative byte offset of a source in the bytecode.
    /// This is the offset from the start of the first source header, which is
    /// after the source count byte and the source offsets.
    /// This function DOES NOT check that the relative offset is within the
    /// bounds of the bytecode. Callers MUST `checkNoOOBPointers` BEFORE
    /// attempting to traverse the bytecode, otherwise the relative offset MAY
    /// point to memory outside the bytecode `bytes`.
    function sourceRelativeOffset(bytes memory bytecode, uint256 sourceIndex) internal pure returns (uint256 offset) {
        // If the source index requested is out of bounds, revert.
        if (sourceIndex >= sourceCount(bytecode)) {
            revert SourceIndexOutOfBounds(bytecode, sourceIndex);
        }
        assembly {
            // After the first byte, all the relative offset pointers are
            // stored sequentially as 16 bit values.
            offset := and(mload(add(add(bytecode, 3), mul(sourceIndex, 2))), 0xFFFF)
        }
    }

    function sourcePointer(bytes memory bytecode, uint256 sourceIndex) internal pure returns (Pointer pointer) {
        unchecked {
            uint256 sourcesStartOffset = 1 + sourceCount(bytecode) * 2;
            uint256 offset = sourceRelativeOffset(bytecode, sourceIndex);
            assembly {
                pointer := add(add(add(bytecode, 0x20), sourcesStartOffset), offset)
            }
        }
    }

    function sourceOpsLength(bytes memory bytecode, uint256 sourceIndex) internal pure returns (uint256 length) {
        unchecked {
            Pointer pointer = sourcePointer(bytecode, sourceIndex);
            assembly ("memory-safe") {
                length := byte(0, mload(pointer))
            }
        }
    }

    function sourceStackAllocation(bytes memory bytecode, uint256 sourceIndex)
        internal
        pure
        returns (uint256 allocation)
    {
        unchecked {
            Pointer pointer = sourcePointer(bytecode, sourceIndex);
            assembly ("memory-safe") {
                allocation := byte(1, mload(pointer))
            }
        }
    }

    function sourceInputsLength(bytes memory bytecode, uint256 sourceIndex) internal pure returns (uint256 length) {
        unchecked {
            Pointer pointer = sourcePointer(bytecode, sourceIndex);
            assembly ("memory-safe") {
                length := byte(2, mload(pointer))
            }
        }
    }

    function sourceOutputsLength(bytes memory bytecode, uint256 sourceIndex) internal pure returns (uint256 length) {
        unchecked {
            Pointer pointer = sourcePointer(bytecode, sourceIndex);
            assembly ("memory-safe") {
                length := byte(3, mload(pointer))
            }
        }
    }

    function sourceInputsOutputsLength(bytes memory bytecode, uint256 sourceIndex)
        internal
        pure
        returns (uint256 inputs, uint256 outputs)
    {
        unchecked {
            Pointer pointer = sourcePointer(bytecode, sourceIndex);
            assembly ("memory-safe") {
                let data := mload(pointer)
                inputs := byte(2, data)
                outputs := byte(3, data)
            }
        }
    }

    /// Backwards compatibility with the old way of representing sources.
    /// Requires allocation and copying so it isn't particularly efficient, but
    /// allows us to use the new bytecode format with old interpreter code. Not
    /// recommended for production code but useful for testing.
    function bytecodeToSources(bytes memory bytecode) internal pure returns (bytes[] memory) {
        unchecked {
            uint256 count = sourceCount(bytecode);
            bytes[] memory sources = new bytes[](count);
            for (uint256 i = 0; i < count; i++) {
                // Skip over the prefix 4 bytes.
                Pointer pointer = sourcePointer(bytecode, i).unsafeAddBytes(4);
                uint256 length = sourceOpsLength(bytecode, i) * 4;
                bytes memory source = new bytes(length);
                pointer.unsafeCopyBytesTo(source.dataPointer(), length);
                // Move the opcode index one byte for each opcode, into the input
                // position, as legacly sources did not have input bytes.
                assembly ("memory-safe") {
                    for {
                        let cursor := add(source, 0x20)
                        let end := add(cursor, length)
                    } lt(cursor, end) { cursor := add(cursor, 4) } {
                        mstore8(add(cursor, 1), byte(0, mload(cursor)))
                        mstore8(cursor, 0)
                    }
                }
                sources[i] = source;
            }
            return sources;
        }
    }
}
