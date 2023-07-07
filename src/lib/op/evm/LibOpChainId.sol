// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "sol.lib.memory/LibStackPointer.sol";
import "../LibOp.sol";
import "../../state/LibInterpreterState.sol";
import "../../integrity/LibIntegrityCheck.sol";

/// @title LibOpChainId
/// @notice An opcode which pushes the current chain ID to the stack.
library LibOpChainId {
    using LibStackPointer for Pointer;
    using LibIntegrityCheck for IntegrityCheckState;
    using LibOp for Pointer;

    function integrity(
        IntegrityCheckState memory integrityCheckState_,
        Operand,
        Pointer stackTop_
    ) internal pure returns (Pointer) {
        return integrityCheckState_.push(stackTop_);
    }

    function run(
        InterpreterState memory,
        Operand,
        Pointer stackTop_
    ) internal view returns (Pointer) {
        return stackTop_.unsafePush(block.chainid);
    }
}
