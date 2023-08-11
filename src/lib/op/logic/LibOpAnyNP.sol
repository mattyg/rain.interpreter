// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "rain.solmem/lib/LibPointer.sol";

import "../../state/LibInterpreterStateNP.sol";
import "../../integrity/LibIntegrityCheckNP.sol";

/// @title LibOpAnyNP
/// @notice Opcode to return the first nonzero item on the stack up to the inputs
/// limit.
library LibOpAnyNP {
    using LibPointer for Pointer;

    function integrity(IntegrityCheckStateNP memory state, Operand operand) internal pure returns (uint256, uint256) {
        // Operand body must be zero.
        if (uint16(Operand.unwrap(operand)) != 0) {
            revert UnsupportedOperand(state.opIndex, operand);
        }
        // There must be at least one input.
        uint256 inputs = Operand.unwrap(operand) >> 0x10;
        inputs = inputs > 0 ? inputs : 1;
        return (inputs, 1);
    }

    /// ANY
    /// ANY is the first nonzero item, else 0.
    function run(InterpreterStateNP memory, Operand operand, Pointer stackTop) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            let length := mul(shr(0x10, operand), 0x20)
            let cursor := stackTop
            stackTop := sub(add(stackTop, length), 0x20)
            for { let end := add(cursor, length) } lt(cursor, end) { cursor := add(cursor, 0x20) } {
                let item := mload(cursor)
                if gt(item, 0) {
                    mstore(stackTop, item)
                    break
                }
            }
        }
        return stackTop;
    }

    /// Gas intensive reference implementation of ANY for testing.
    function referenceFn(uint256[] memory inputs) internal pure returns (uint256[] memory outputs) {
        uint256 value = 0;
        for (uint256 i = 0; i < inputs.length; i++) {
            value = inputs[i];
            if (value != 0) {
                break;
            }
        }
        outputs = new uint256[](1);
        outputs[0] = value;
    }
}
