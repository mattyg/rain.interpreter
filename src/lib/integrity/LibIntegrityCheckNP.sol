// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import {Pointer} from "rain.solmem/lib/LibPointer.sol";

import {
    StackAllocationMismatch,
    StackOutputsMismatch,
    StackUnderflow,
    StackUnderflowHighwater,
    BadOpInputsLength
} from "../../error/ErrIntegrity.sol";
import {IInterpreterV2, SourceIndexV2} from "../../interface/unstable/IInterpreterV2.sol";
import {LibBytecode} from "../../lib/bytecode/LibBytecode.sol";
import {Operand} from "../../interface/unstable/IInterpreterV2.sol";
import {IInterpreterStoreV1, StateNamespace} from "../../interface/IInterpreterStoreV1.sol";
import {BadOpInputsLength} from "../../lib/integrity/LibIntegrityCheckNP.sol";

struct IntegrityCheckStateNP {
    uint256 stackIndex;
    uint256 stackMaxIndex;
    uint256 readHighwater;
    uint256[] constants;
    uint256 opIndex;
    bytes bytecode;
}

library LibIntegrityCheckNP {
    using LibIntegrityCheckNP for IntegrityCheckStateNP;

    function newState(bytes memory bytecode, uint256 stackIndex, uint256[] memory constants)
        internal
        pure
        returns (IntegrityCheckStateNP memory)
    {
        return IntegrityCheckStateNP(
            // stackIndex
            stackIndex,
            // stackMaxIndex
            stackIndex,
            // highwater (source inputs are always immutable)
            stackIndex,
            // constants
            constants,
            // opIndex
            0,
            // bytecode
            bytecode
        );
    }

    function integrityCheck2(bytes memory fPointers, bytes memory bytecode, uint256[] memory constants)
        internal
        view
        returns (bytes memory io)
    {
        unchecked {
            uint256 sourceCount = LibBytecode.sourceCount(bytecode);

            uint256 fPointersStart;
            assembly ("memory-safe") {
                fPointersStart := add(fPointers, 0x20)
            }

            // Ensure that the bytecode has no out of bounds pointers BEFORE we
            // start attempting to iterate over opcodes. This ensures the
            // integrity of the source count, relative offset pointers,
            // ops count per source, and that there is no garbage bytes at the
            // end or between these things. Basically everything structural about
            // the bytecode is confirmed here.
            LibBytecode.checkNoOOBPointers(bytecode);

            io = new bytes(sourceCount * 2);
            uint256 ioCursor;
            assembly ("memory-safe") {
                ioCursor := add(io, 0x20)
            }

            // Run the integrity check over each source. This needs to ensure
            // the integrity of each source's inputs, outputs, and stack
            // allocation, as well as the integrity of the bytecode itself on
            // a per-opcode basis, according to each opcode's implementation.
            for (uint256 i = 0; i < sourceCount; i++) {
                (uint256 inputsLength, uint256 outputsLength) = LibBytecode.sourceInputsOutputsLength(bytecode, i);
                // Inputs and outputs are 1 byte each. This is enforced by the
                // structure of the bytecode itself.
                assembly ("memory-safe") {
                    mstore8(ioCursor, inputsLength)
                    mstore8(add(ioCursor, 1), outputsLength)
                    ioCursor := add(ioCursor, 2)
                }

                IntegrityCheckStateNP memory state = LibIntegrityCheckNP.newState(bytecode, inputsLength, constants);

                // Have low 4 bytes of cursor overlap the first op, skipping the
                // prefix.
                uint256 cursor = Pointer.unwrap(LibBytecode.sourcePointer(bytecode, i)) - 0x18;
                uint256 end = cursor + LibBytecode.sourceOpsCount(bytecode, i) * 4;

                while (cursor < end) {
                    Operand operand;
                    uint256 bytecodeOpInputs;
                    function(IntegrityCheckStateNP memory, Operand)
                    view
                    returns (uint256, uint256) f;
                    assembly ("memory-safe") {
                        let word := mload(cursor)
                        f := shr(0xf0, mload(add(fPointersStart, mul(byte(28, word), 2))))
                        // 3 bytes mask.
                        operand := and(word, 0xFFFFFF)
                        bytecodeOpInputs := byte(29, word)
                    }
                    (uint256 calcOpInputs, uint256 calcOpOutputs) = f(state, operand);
                    if (calcOpInputs != bytecodeOpInputs) {
                        revert BadOpInputsLength(state.opIndex, calcOpInputs, bytecodeOpInputs);
                    }

                    if (calcOpInputs > state.stackIndex) {
                        revert StackUnderflow(state.opIndex, state.stackIndex, calcOpInputs);
                    }
                    state.stackIndex -= calcOpInputs;

                    // The stack index can't move below the highwater.
                    if (state.stackIndex < state.readHighwater) {
                        revert StackUnderflowHighwater(state.opIndex, state.stackIndex, state.readHighwater);
                    }

                    // Let's assume that sane opcode implementations don't
                    // overflow uint256 due to their outputs.
                    state.stackIndex += calcOpOutputs;

                    // Ensure the max stack index is updated if needed.
                    if (state.stackIndex > state.stackMaxIndex) {
                        state.stackMaxIndex = state.stackIndex;
                    }

                    // If there are multiple outputs the highwater MUST move.
                    if (calcOpOutputs > 1) {
                        state.readHighwater = state.stackIndex;
                    }

                    state.opIndex++;
                    cursor += 4;
                }

                // The final stack max index MUST match the bytecode allocation.
                if (state.stackMaxIndex != LibBytecode.sourceStackAllocation(bytecode, i)) {
                    revert StackAllocationMismatch(state.stackMaxIndex, LibBytecode.sourceStackAllocation(bytecode, i));
                }

                // The final stack index MUST match the bytecode source outputs.
                if (state.stackIndex != outputsLength) {
                    revert StackOutputsMismatch(state.stackIndex, outputsLength);
                }
            }
        }
    }
}
