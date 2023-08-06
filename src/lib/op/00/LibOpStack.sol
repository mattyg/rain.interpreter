// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.solmem/lib/LibStackPointer.sol";
import "../../state/LibInterpreterState.sol";
import "../../state/LibInterpreterStateNP.sol";
import "../../integrity/LibIntegrityCheck.sol";
import "../../integrity/LibIntegrityCheckNP.sol";

/// Legacy error without op index.
error BadStackRead(uint256 stackIndex, uint256 stackRead);

/// Thrown when a stack read index is outside the current stack top.
error OutOfBoundsStackRead(uint256 opIndex, uint256 stackTopIndex, uint256 stackRead);

/// @title LibOpStack
/// Implementation of copying a stack item from the stack to the stack.
/// Integrated deeply into LibParse, which requires this opcode or a variant
/// to be present at a known opcode index.
library LibOpStack {
    using LibPointer for Pointer;
    using LibStackPointer for Pointer;
    using LibIntegrityCheck for IntegrityCheckState;
    using LibIntegrityCheckNP for IntegrityCheckStateNP;

    /// Copies a stack item from the stack to the stack. Reading past the end of
    /// the stack is an integrity error. Reading a value moves the highwater so
    /// that the value cannot be consumed. i.e. the stack is immutable once read.
    /// @param integrityCheckState The integrity check state.
    /// @param stackTop The stack top.
    /// @return The new stack top.
    function integrity(IntegrityCheckState memory integrityCheckState, Operand operand, Pointer stackTop)
        internal
        pure
        returns (Pointer)
    {
        Pointer operandPointer = integrityCheckState.stackBottom.unsafeAddWords(Operand.unwrap(operand));

        // Ensure that we aren't reading beyond the current stack top.
        if (Pointer.unwrap(operandPointer) >= Pointer.unwrap(stackTop)) {
            revert BadStackRead(
                // Assume that negative stack top has been handled elsewhere by
                // caller.
                uint256(integrityCheckState.stackBottom.toIndexSigned(stackTop)),
                Operand.unwrap(operand)
            );
        }

        // Ensure that highwater is moved past any stack item that we
        // read so that copied values cannot later be consumed.
        if (Pointer.unwrap(operandPointer) > Pointer.unwrap(integrityCheckState.stackHighwater)) {
            integrityCheckState.stackHighwater = operandPointer;
        }

        return integrityCheckState.push(stackTop);
    }

    function integrityNP(IntegrityCheckStateNP memory state, Operand operand)
        internal
        pure
        returns (uint256, uint256)
    {
        uint256 readIndex = Operand.unwrap(operand);
        // Operand is the index so ensure it doesn't exceed the stack index.
        if (readIndex >= state.stackIndex) {
            revert OutOfBoundsStackRead(state.opIndex, state.stackIndex, readIndex);
        }

        // Move the read highwater if needed.
        if (readIndex > state.readHighwater) {
            state.readHighwater = readIndex;
        }

        return (0, 1);
    }

    /// Copies a stack item from the stack array to the stack.
    /// @param stackTop The stack top.
    /// @return The new stack top.
    function run(InterpreterState memory state, Operand operand, Pointer stackTop) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            mstore(stackTop, mload(add(mload(state), mul(0x20, operand))))
            stackTop := add(stackTop, 0x20)
        }
        return stackTop;
    }

    function runNP(InterpreterStateNP memory state, Operand operand, Pointer stackTop)
        internal
        pure
        returns (Pointer)
    {
        uint256 sourceIndex = state.sourceIndex;
        assembly ("memory-safe") {
            let stackBottom := mload(add(mload(state), mul(0x20, add(sourceIndex, 1))))
            let stackValue := mload(sub(stackBottom, mul(0x20, add(operand, 1))))
            stackTop := sub(stackTop, 0x20)
            mstore(stackTop, stackValue)
        }
        return stackTop;
    }
}
