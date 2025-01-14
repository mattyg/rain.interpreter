// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Operand} from "../../../../interface/unstable/IInterpreterV2.sol";
import {LibSubParse} from "../../../parse/LibSubParse.sol";
import {IInterpreterExternV3} from "../../../../interface/unstable/IInterpreterExternV3.sol";

/// @title LibExternOpStackOperandNPE2
/// This op copies its operand value to the stack by copying it to the constants
/// array at parse time. This means that it doesn't exist as an externed opcode,
/// the interpreter will run it directly, therefore it has no `run` or
/// `integrity` logic, only a sub parser. This demonstrates both how to
/// implement constants, and handling operands in the sub parser.
library LibExternOpStackOperandNPE2 {
    //slither-disable-next-line dead-code
    function subParser(uint256 constantsHeight, uint256, Operand operand)
        internal
        pure
        returns (bool, bytes memory, uint256[] memory)
    {
        //slither-disable-next-line unused-return
        return LibSubParse.subParserConstant(constantsHeight, Operand.unwrap(operand));
    }
}
