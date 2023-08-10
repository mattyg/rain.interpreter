// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "../../state/LibInterpreterStateNP.sol";
import "../../integrity/LibIntegrityCheckNP.sol";

/// @title LibOpHashNP
/// Implementation of keccak256 hashing as a standard Rainlang opcode.
library LibOpHashNP {
    function integrity(IntegrityCheckStateNP memory state, Operand operand) internal pure returns (uint256, uint256) {
        // Any number of inputs are valid.
        // 0 inputs will be the hash of empty (0 length) bytes.
        uint256 inputs = Operand.unwrap(operand) >> 0x10;
        // Low 16 bits MUST be zero.
        if (Operand.unwrap(operand) & 0xffff != 0) {
            revert UnsupportedOperand(state.opIndex, operand);
        }
        return (inputs, 1);
    }

    function run(InterpreterStateNP memory, Operand operand, Pointer stackTop) internal pure returns (Pointer) {
        assembly ("memory-safe") {
            let length := mul(shr(0x10, operand), 0x20)
            let value := keccak256(stackTop, length)
            stackTop := sub(add(stackTop, length), 0x20)
            mstore(stackTop, value)
        }
        return stackTop;
    }

    function referenceFn(uint256[] memory inputs) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(inputs)));
    }
}
