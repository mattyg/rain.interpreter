// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "forge-std/Test.sol";

import "rain.solmem/lib/LibPointer.sol";
import "rain.solmem/lib/LibBytes.sol";
import "src/lib/parse/LibParseLiteral.sol";

/// @title LibParseLiteralDecimalTest
/// Tests parsing decimal literal values with the LibParseLiteral library.
contract LibParseLiteralDecimalTest is Test {
    using LibBytes for bytes;

    /// Check that an empty string literal parses to 0.
    function testParseLiteralDecimalEmpty() external {
        bytes memory data = "";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 0);
    }

    /// Check that a "0" parses to the correct value.
    function testParseLiteralDecimalSingleDigit0() external {
        bytes memory data = "0";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 0);
    }

    /// Check that a "1" parses to the correct value.
    function testParseLiteralDecimalSingleDigit1() external {
        bytes memory data = "1";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 1);
    }

    /// Check that a "2" parses to the correct value.
    function testParseLiteralDecimalSingleDigit2() external {
        bytes memory data = "2";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 2);
    }

    /// Check that a "3" parses to the correct value.
    function testParseLiteralDecimalSingleDigit3() external {
        bytes memory data = "3";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 3);
    }

    /// Check that a "4" parses to the correct value.
    function testParseLiteralDecimalSingleDigit4() external {
        bytes memory data = "4";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 4);
    }

    /// Check that a "5" parses to the correct value.
    function testParseLiteralDecimalSingleDigit5() external {
        bytes memory data = "5";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 5);
    }

    /// Check that a "6" parses to the correct value.
    function testParseLiteralDecimalSingleDigit6() external {
        bytes memory data = "6";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 6);
    }

    /// Check that a "7" parses to the correct value.
    function testParseLiteralDecimalSingleDigit7() external {
        bytes memory data = "7";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 7);
    }

    /// Check that a "8" parses to the correct value.
    function testParseLiteralDecimalSingleDigit8() external {
        bytes memory data = "8";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 8);
    }

    /// Check that a "9" parses to the correct value.
    function testParseLiteralDecimalSingleDigit9() external {
        bytes memory data = "9";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 9);
    }

    /// Check that an "e" in 2nd position is processed as a 1 digit exponent.
    /// This tests Xe0 = X for X in [0,10].
    function testParseLiteralDecimalSingleDigitE0() external {
        bytes memory data = "0e0";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 0);

        data = "1e0";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 1);

        data = "2e0";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 2);

        data = "3e0";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 3);

        data = "4e0";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 4);

        data = "5e0";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 5);

        data = "6e0";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 6);

        data = "7e0";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 7);

        data = "8e0";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 8);

        data = "9e0";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 9);

        data = "10e0";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 10);
    }

    /// Check that a "e" in 2nd position is processed as a 1 digit exponent.
    /// This tests Xe1 = X * 10 for X in [0,10].
    function testParseLiteralDecimalSingleDigitE1() external {
        bytes memory data = "0e1";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 0);

        data = "1e1";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 10);

        data = "2e1";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 20);

        data = "3e1";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 30);

        data = "4e1";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 40);

        data = "5e1";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 50);

        data = "6e1";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 60);

        data = "7e1";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 70);

        data = "8e1";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 80);

        data = "9e1";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 90);

        data = "10e1";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 100);
    }

    /// Check that a "e" in 3rd position is processed as a 2 digit exponent.
    /// This tests Xe00 = X for X in [0,10].
    function testParseLiteralDecimalDoubleDigitE0() external {
        bytes memory data = "0e00";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 0);

        data = "1e00";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 1);

        data = "2e00";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 2);

        data = "3e00";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 3);

        data = "4e00";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 4);

        data = "5e00";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 5);

        data = "6e00";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 6);

        data = "7e00";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 7);

        data = "8e00";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 8);

        data = "9e00";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 9);

        data = "10e00";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 10);
    }

    /// Check that a "e" in 3rd position is processed as a 2 digit exponent.
    /// This tests Xe01 = X * 10 for X in [0,10].
    function testParseLiteralDecimalDoubleDigitE1() external {
        bytes memory data = "0e01";
        (uint256 value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 0);

        data = "1e01";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 10);

        data = "2e01";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 20);

        data = "3e01";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 30);

        data = "4e01";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 40);

        data = "5e01";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 50);

        data = "6e01";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 60);

        data = "7e01";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 70);

        data = "8e01";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 80);

        data = "9e01";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 90);

        data = "10e01";
        (value) = LibParseLiteral.parseLiteralDecimal(
            data, Pointer.unwrap(data.dataPointer()), Pointer.unwrap(data.endDataPointer())
        );
        assertEq(value, 100);
    }
}