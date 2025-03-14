// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test} from "forge-std/Test.sol";
import {Operand, OPCODE_EXTERN} from "src/interface/unstable/IInterpreterV2.sol";
import {
    IInterpreterExternV3,
    ExternDispatch,
    EncodedExternDispatch
} from "src/interface/unstable/IInterpreterExternV3.sol";
import {LibSubParse} from "src/lib/parse/LibSubParse.sol";
import {LibExtern} from "src/lib/extern/LibExtern.sol";
import {ExternDispatchConstantsHeightOverflow} from "src/error/ErrSubParse.sol";

contract LibSubParseSubParserExternTest is Test {
    /// Every possible valid extern input will be sub parsed into extern
    /// bytecode.
    function testLibSubParseSubParserExtern(
        IInterpreterExternV3 extern,
        uint8 constantsHeight,
        uint8 inputsByte,
        uint8 outputsByte,
        uint16 operandValue,
        uint8 opcodeIndex
    ) external {
        (bool success, bytes memory bytecode, uint256[] memory constants) = LibSubParse.subParserExtern(
            extern,
            uint256(constantsHeight),
            uint256(inputsByte),
            uint256(outputsByte),
            Operand.wrap(uint256(operandValue)),
            uint256(opcodeIndex)
        );
        assertTrue(success);

        assertEq(bytecode.length, 4);
        assertEq(uint256(uint8(bytecode[0])), OPCODE_EXTERN);
        assertEq(uint8(bytecode[1]), inputsByte);
        assertEq(uint8(bytecode[2]), outputsByte);
        assertEq(uint8(bytecode[3]), constantsHeight);

        assertEq(constants.length, 1);
        (IInterpreterExternV3 externDecoded, ExternDispatch externDispatchDecoded) =
            LibExtern.decodeExternCall(EncodedExternDispatch.wrap(constants[0]));
        assertEq(address(extern), address(externDecoded));
        (uint256 opcodeIndexDecoded, Operand operandDecoded) = LibExtern.decodeExternDispatch(externDispatchDecoded);
        assertEq(opcodeIndexDecoded, opcodeIndex);
        assertEq(Operand.unwrap(operandDecoded), operandValue);
    }

    /// Constants height must be less than 256 or the lib will error.
    function testLibSubParseSubParserExternConstantsHeightOverflow(
        IInterpreterExternV3 extern,
        uint16 constantsHeight,
        uint8 inputsByte,
        uint8 outputsByte,
        uint16 operandValue,
        uint8 opcodeIndex
    ) external {
        constantsHeight = uint16(bound(uint256(constantsHeight), 0x100, 0xFFFF));
        vm.expectRevert(
            abi.encodeWithSelector(ExternDispatchConstantsHeightOverflow.selector, uint256(constantsHeight))
        );
        (bool success, bytes memory bytecode, uint256[] memory constants) = LibSubParse.subParserExtern(
            extern,
            uint256(constantsHeight),
            uint256(inputsByte),
            uint256(outputsByte),
            Operand.wrap(uint256(operandValue)),
            uint256(opcodeIndex)
        );
        (success, bytecode, constants);
    }
}
