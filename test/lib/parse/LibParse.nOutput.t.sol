// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import {Test} from "forge-std/Test.sol";
import {LibMetaFixture} from "test/util/lib/parse/LibMetaFixture.sol";

import {LibParse} from "src/lib/parse/LibParse.sol";
import {LibBytecode} from "src/lib/bytecode/LibBytecode.sol";
import {ExcessLHSItems, ExcessRHSItems} from "src/error/ErrParse.sol";
import {ParseState} from "src/lib/parse/LibParseState.sol";

/// @title LibParseNOutputTest
/// Test that the parser can handle multi and zero outputs for RHS items when
/// they are singular on a line, and mandates individual items otherwise.
contract LibParseNOutputTest is Test {
    using LibParse for ParseState;

    /// A single RHS item MAY have 0 outputs.
    function testParseNOutputExcessRHS0() external {
        (bytes memory bytecode, uint256[] memory constants) = LibMetaFixture.newState(":a();").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 1 ops
            hex"01"
            // 0 stack allocation
            hex"00"
            // 0 input
            hex"00"
            // 0 outputs
            hex"00"
            // a
            hex"02000000"
        );
        assertEq(constants.length, 0);
    }

    /// Multiple RHS items MUST NOT have 0 outputs. Tests two RHS items and zero
    /// LHS items.
    function testParseNOutputExcessRHS1() external {
        vm.expectRevert(abi.encodeWithSelector(ExcessRHSItems.selector, 8));
        LibMetaFixture.newState(":a() b();").parse();
    }

    /// Multiple RHS items MUST NOT have 0 outputs. Tests two RHS items and one
    /// LHS item.
    function testParseNOutputExcessRHS2() external {
        vm.expectRevert(abi.encodeWithSelector(ExcessRHSItems.selector, 9));
        LibMetaFixture.newState("_:a() b();").parse();
    }

    /// A single RHS item can have multiple outputs. This RHS item has nesting.
    function testParseNOutputNestedRHS() external {
        (bytes memory bytecode, uint256[] memory constants) = LibMetaFixture.newState(":,_ _:a(b());").parse();
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 2 ops
            hex"02"
            // 2 stack allocation
            hex"02"
            // 0 inputs
            hex"00"
            // 2 outputs
            hex"02"
            // b
            hex"03000000"
            // a 1 input
            hex"02010000"
        );
        assertEq(constants.length, 0);
    }

    /// Multiple RHS items MUST NOT have multiple outputs. Tests two RHS items
    /// and three LHS items.
    function testParseNOutputExcessRHS3() external {
        vm.expectRevert(abi.encodeWithSelector(ExcessLHSItems.selector, 13));
        LibMetaFixture.newState("_ _ _:a() b();").parse();
    }

    /// Multiple output RHS items MAY be followed by single output RHS items,
    /// on a new line.
    function testParseBalanceStackOffsetsInputs() external {
        (bytes memory bytecode, uint256[] memory constants) = LibMetaFixture.newState("_ _:a(), _:b();").parse();
        assertEq(LibBytecode.sourceCount(bytecode), 1);
        assertEq(constants.length, 0);
        // a and b should be parsed and inputs are just ignored in the output
        // source.
        assertEq(
            bytecode,
            // 1 source
            hex"01"
            // 0 offset
            hex"0000"
            // 2 ops
            hex"02"
            // 3 stack allocation
            hex"03"
            // 0 inputs
            hex"00"
            // 3 outputs
            hex"03"
            // a
            hex"02000000"
            // b
            hex"03000000"
        );

        uint256 sourceIndex = 0;
        assertEq(LibBytecode.sourceRelativeOffset(bytecode, sourceIndex), 0);
        assertEq(LibBytecode.sourceOpsCount(bytecode, sourceIndex), 2);
        assertEq(LibBytecode.sourceStackAllocation(bytecode, sourceIndex), 3);
        (uint256 inputs, uint256 outputs) = LibBytecode.sourceInputsOutputsLength(bytecode, sourceIndex);
        assertEq(inputs, 0);
        assertEq(outputs, 3);
    }
}
