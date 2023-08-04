// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.solmem/lib/LibStackPointer.sol";
import "../../state/LibInterpreterState.sol";
import "../../state/LibInterpreterStateNP.sol";
import "../../integrity/LibIntegrityCheck.sol";
import "../../integrity/LibIntegrityCheckNP.sol";

/// Thrown when a constant read index is outside the constants array.
error OutOfBoundsConstantsRead(uint256 constantsLength, uint256 constantsRead);

/// @title LibOpConstant
/// Implementation of copying a constant from the constants array to the stack.
/// Integrated deeply into LibParse, which requires this opcode or a variant
/// to be present at a known opcode index.
library LibOpConstant {
    using LibStackPointer for Pointer;
    using LibIntegrityCheck for IntegrityCheckState;
    using LibIntegrityCheckNP for IntegrityCheckStateNP;

    /// Copies a constant from the constants array to the stack. Reading past
    /// the end of the constants array will simply error.
    /// @param integrityCheckState The integrity check state.
    /// @param stackTop The stack top.
    /// @return The new stack top.
    function integrity(IntegrityCheckState memory integrityCheckState, Operand operand, Pointer stackTop)
        internal
        pure
        returns (Pointer)
    {
        if (Operand.unwrap(operand) >= integrityCheckState.constantsLength) {
            revert OutOfBoundsConstantsRead(integrityCheckState.constantsLength, Operand.unwrap(operand));
        }
        return integrityCheckState.push(stackTop);
    }

    function integrityNP(IntegrityCheckStateNP memory state, Operand operand, uint256)
        internal
        pure
        returns (Operand, uint256, uint256)
    {
        // Operand is the index so ensure it doesn't exceed the constants length.
        if (Operand.unwrap(operand) >= state.constantsLength) {
            revert OutOfBoundsConstantsRead(state.constantsLength, Operand.unwrap(operand));
        }
        return (operand, 0, 1);
    }

    /// Copies a constant from the constants array to the stack. Does NOT do
    /// any bounds checking as the integrity check MUST already have been
    /// performed.
    /// @param stackTop The stack top.
    /// @return The new stack top.
    function run(InterpreterState memory state, Operand operand, Pointer stackTop) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            mstore(stackTop, mload(add(mload(add(state, 0x20)), mul(operand, 0x20))))
            stackTop := add(stackTop, 0x20)
        }
        return stackTop;
    }

    function runNP(InterpreterStateNP memory state, Operand operand, Pointer stackTop)
        internal
        pure
        returns (Pointer)
    {
        assembly ("memory-safe") {
            let constantValue := mload(add(mload(add(state, 0x20)), mul(operand, 0x20)))
            stackTop := sub(stackTop, 0x20)
            mstore(stackTop, constantValue)
        }
        return stackTop;
    }
}
