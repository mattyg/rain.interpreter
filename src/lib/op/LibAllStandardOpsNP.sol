// SPDX-License-Identifier: CAL
pragma solidity ^0.8.19;

import "rain.lib.typecast/LibConvert.sol";

import "../integrity/LibIntegrityCheckNP.sol";
import "../state/LibInterpreterStateNP.sol";
import {AuthoringMeta} from "../parse/LibParseMeta.sol";
import {
    OPERAND_PARSER_OFFSET_DISALLOWED,
    OPERAND_PARSER_OFFSET_SINGLE_FULL,
    OPERAND_PARSER_OFFSET_DOUBLE_PERBYTE_NO_DEFAULT,
    OPERAND_PARSER_OFFSET_M1_M1,
    OPERAND_PARSER_OFFSET_8_M1_M1
} from "../parse/LibParseOperand.sol";

import "./00/LibOpStackNP.sol";
import "./00/LibOpConstantNP.sol";

import "./call/LibOpCallNP.sol";

import "./context/LibOpContextNP.sol";

import "./crypto/LibOpHashNP.sol";

import "./evm/LibOpBlockNumberNP.sol";
import "./evm/LibOpChainIdNP.sol";
import "./evm/LibOpMaxUint256NP.sol";
import "./evm/LibOpTimestampNP.sol";

import "./logic/LibOpAnyNP.sol";
import "./logic/LibOpConditionsNP.sol";
import "./logic/LibOpEnsureNP.sol";
import "./logic/LibOpEqualToNP.sol";
import "./logic/LibOpEveryNP.sol";
import "./logic/LibOpGreaterThanNP.sol";
import "./logic/LibOpGreaterThanOrEqualToNP.sol";
import "./logic/LibOpIfNP.sol";
import "./logic/LibOpIsZeroNP.sol";
import "./logic/LibOpLessThanNP.sol";
import "./logic/LibOpLessThanOrEqualToNP.sol";

import "./math/decimal18/LibOpDecimal18MulNP.sol";
import "./math/decimal18/LibOpDecimal18DivNP.sol";
import "./math/decimal18/LibOpDecimal18Scale18DynamicNP.sol";
import "./math/decimal18/LibOpDecimal18Scale18NP.sol";
import "./math/decimal18/LibOpDecimal18ScaleNNP.sol";

import "./math/int/LibOpIntAddNP.sol";
import "./math/int/LibOpIntDivNP.sol";
import "./math/int/LibOpIntExpNP.sol";
import "./math/int/LibOpIntMaxNP.sol";
import "./math/int/LibOpIntMinNP.sol";
import "./math/int/LibOpIntModNP.sol";
import "./math/int/LibOpIntMulNP.sol";
import "./math/int/LibOpIntSubNP.sol";

import "./store/LibOpGetNP.sol";
import "./store/LibOpSetNP.sol";

import "./uniswap/LibOpUniswapV2AmountIn.sol";
import "./uniswap/LibOpUniswapV2AmountOut.sol";

/// Thrown when a dynamic length array is NOT 1 more than a fixed length array.
/// Should never happen outside a major breaking change to memory layouts.
error BadDynamicLength(uint256 dynamicLength, uint256 standardOpsLength);

/// @dev Number of ops currently provided by `AllStandardOpsNP`.
uint256 constant ALL_STANDARD_OPS_LENGTH = 42;

/// @title LibAllStandardOpsNP
/// @notice Every opcode available from the core repository laid out as a single
/// array to easily build function pointers for `IInterpreterV1`.
library LibAllStandardOpsNP {
    function authoringMeta() internal pure returns (bytes memory) {
        AuthoringMeta memory lengthPlaceholder;
        AuthoringMeta[ALL_STANDARD_OPS_LENGTH + 1] memory wordsFixed = [
            lengthPlaceholder,
            // Stack and constant MUST be in this order for parsing to work.
            AuthoringMeta("stack", OPERAND_PARSER_OFFSET_SINGLE_FULL, "Copies an existing value from the stack."),
            AuthoringMeta("constant", OPERAND_PARSER_OFFSET_SINGLE_FULL, "Copies a constant value onto the stack."),
            // These are all ordered according to how they appear in the file system.
            AuthoringMeta(
                "call",
                OPERAND_PARSER_OFFSET_DOUBLE_PERBYTE_NO_DEFAULT,
                "Calls a source by index in the same Rain bytecode. The inputs to call are copied to the top of the called stack and the outputs specified in the operand are copied back to the calling stack. The first operand is the source index and the second is the number of outputs."
            ),
            AuthoringMeta(
                "context",
                OPERAND_PARSER_OFFSET_DOUBLE_PERBYTE_NO_DEFAULT,
                "Copies a value from the context. The first operand is the context column and second is the context row."
            ),
            AuthoringMeta(
                "hash", OPERAND_PARSER_OFFSET_DISALLOWED, "Hashes all inputs into a single 32 byte value using keccak256."
            ),
            AuthoringMeta("block-number", OPERAND_PARSER_OFFSET_DISALLOWED, "The current block number."),
            AuthoringMeta("chain-id", OPERAND_PARSER_OFFSET_DISALLOWED, "The current chain id."),
            AuthoringMeta(
                "max-int-value",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "The maximum possible non-negative integer value. 2^256 - 1."
            ),
            AuthoringMeta(
                "max-decimal18-value",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "The maximum possible 18 decimal fixed point value. roughly 1.15e77."
            ),
            AuthoringMeta("block-timestamp", OPERAND_PARSER_OFFSET_DISALLOWED, "The current block timestamp."),
            AuthoringMeta(
                "any",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "The first non-zero value out of all inputs, or 0 if every input is 0."
            ),
            AuthoringMeta(
                "conditions",
                OPERAND_PARSER_OFFSET_SINGLE_FULL,
                "Treats inputs as pairwise condition/value pairs. The first nonzero condition's value is used. If no conditions are nonzero, the expression reverts. The operand can be used as an error code to differentiate between multiple conditions in the same expression."
            ),
            AuthoringMeta(
                "ensure",
                OPERAND_PARSER_OFFSET_SINGLE_FULL,
                "Reverts if any input is 0. All inputs are eagerly evaluated there are no outputs. The operand can be used as an error code to differentiate between multiple conditions in the same expression."
            ),
            AuthoringMeta("equal-to", OPERAND_PARSER_OFFSET_DISALLOWED, "1 if all inputs are equal, 0 otherwise."),
            AuthoringMeta(
                "every",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "The last nonzero value out of all inputs, or 0 if any input is 0."
            ),
            AuthoringMeta(
                "greater-than",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "1 if the first input is greater than the second input, 0 otherwise."
            ),
            AuthoringMeta(
                "greater-than-or-equal-to",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "1 if the first input is greater than or equal to the second input, 0 otherwise."
            ),
            AuthoringMeta(
                "if",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "If the first input is nonzero, the second input is used. Otherwise, the third input is used. If is eagerly evaluated."
            ),
            AuthoringMeta("is-zero", OPERAND_PARSER_OFFSET_DISALLOWED, "1 if the input is 0, 0 otherwise."),
            AuthoringMeta(
                "less-than",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "1 if the first input is less than the second input, 0 otherwise."
            ),
            AuthoringMeta(
                "less-than-or-equal-to",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "1 if the first input is less than or equal to the second input, 0 otherwise."
            ),
            AuthoringMeta(
                "decimal18-div",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Divides the first input by all other inputs as fixed point 18 decimal numbers (i.e. 'one' is 1e18). Errors if any divisor is zero."
            ),
            AuthoringMeta(
                "decimal18-mul",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Multiplies all inputs together as fixed point 18 decimal numbers (i.e. 'one' is 1e18). Errors if the multiplication exceeds the maximum value (roughly 1.15e77)."
            ),
            AuthoringMeta(
                "decimal18-scale18-dynamic",
                OPERAND_PARSER_OFFSET_M1_M1,
                "Scales a value from some fixed point decimal scale to 18 decimal fixed point. The first input is the scale to scale from and the second is the value to scale. The two optional operands control rounding and saturation respectively as per `decimal18-scale18`."
            ),
            AuthoringMeta(
                "decimal18-scale18",
                OPERAND_PARSER_OFFSET_8_M1_M1,
                "Scales an input value from some fixed point decimal scale to 18 decimal fixed point. The first operand is the scale to scale from. The second (optional) operand controls rounding where 0 (default) rounds down and 1 rounds up. The third (optional) operand controls saturation where 0 (default) errors on overflow and 1 saturates at max-decimal-value."
            ),
            AuthoringMeta(
                "decimal18-scale-n",
                OPERAND_PARSER_OFFSET_8_M1_M1,
                "Scales an input value from 18 decimal fixed point to some other fixed point scale N. The first operand is the scale to scale to. The second (optional) operand controls rounding where 0 (default) rounds down and 1 rounds up. The third (optional) operand controls saturation where 0 (default) errors on overflow and 1 saturates at max-decimal-value."
            ),
            // int and decimal18 add have identical implementations and point to
            // the same function pointer. This is intentional.
            AuthoringMeta(
                "int-add",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Adds all inputs together as non-negative integers. Errors if the addition exceeds the maximum value (roughly 1.15e77)."
            ),
            AuthoringMeta(
                "decimal18-add",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Adds all inputs together as fixed point 18 decimal numbers (i.e. 'one' is 1e18). Errors if the addition exceeds the maximum value (roughly 1.15e77)."
            ),
            AuthoringMeta(
                "int-div",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Divides the first input by all other inputs as non-negative integers. Errors if any divisor is zero."
            ),
            AuthoringMeta(
                "int-exp",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Raises the first input to the power of all other inputs as non-negative integers. Errors if the exponentiation would exceed the maximum value (roughly 1.15e77)."
            ),
            // int and decimal18 max have identical implementations and point to
            // the same function pointer. This is intentional.
            AuthoringMeta(
                "int-max",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Finds the maximum value from all inputs as non-negative integers."
            ),
            AuthoringMeta(
                "decimal18-max",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Finds the maximum value from all inputs as fixed point 18 decimal numbers (i.e. 'one' is 1e18)."
            ),
            // int and decimal18 min have identical implementations and point to
            // the same function pointer. This is intentional.
            AuthoringMeta(
                "int-min",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Finds the minimum value from all inputs as non-negative integers."
            ),
            AuthoringMeta(
                "decimal18-min",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Finds the minimum value from all inputs as fixed point 18 decimal numbers (i.e. 'one' is 1e18)."
            ),
            AuthoringMeta(
                "int-mod",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Modulos the first input by all other inputs as non-negative integers. Errors if any divisor is zero."
            ),
            AuthoringMeta(
                "int-mul",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Multiplies all inputs together as non-negative integers. Errors if the multiplication exceeds the maximum value (roughly 1.15e77)."
            ),
            // int and decimal18 sub have identical implementations and point to
            // the same function pointer. This is intentional.
            AuthoringMeta(
                "int-sub",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Subtracts all inputs from the first input as non-negative integers. Errors if the subtraction would result in a negative value."
            ),
            AuthoringMeta(
                "decimal18-sub",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Subtracts all inputs from the first input as fixed point 18 decimal numbers (i.e. 'one' is 1e18). Errors if the subtraction would result in a negative value."
            ),
            AuthoringMeta(
                "get",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Gets a value from storage. The first operand is the key to lookup."
            ),
            AuthoringMeta(
                "set",
                OPERAND_PARSER_OFFSET_DISALLOWED,
                "Sets a value in storage. The first operand is the key to set and the second operand is the value to set."
            ),
            AuthoringMeta(
                "uniswap-v2-amount-in",
                OPERAND_PARSER_OFFSET_SINGLE_FULL,
                "Computes the minimum amount of input tokens required to get a given amount of output tokens from a UniswapV2 pair. Input/output token directions are from the perspective of the Uniswap contract. The first input is the factory address, the second is the amount of output tokens, the third is the input token address, and the fourth is the output token address. If the operand is 1 the last time the prices changed will be returned as well."
            ),
            AuthoringMeta(
                "uniswap-v2-amount-out",
                OPERAND_PARSER_OFFSET_SINGLE_FULL,
                "Computes the maximum amount of output tokens received from a given amount of input tokens from a UniswapV2 pair. Input/output token directions are from the perspective of the Uniswap contract. The first input is the factory address, the second is the amount of input tokens, the third is the input token address, and the fourth is the output token address. If the operand is 1 the last time the prices changed will be returned as well."
            )
        ];
        AuthoringMeta[] memory wordsDynamic;
        uint256 length = ALL_STANDARD_OPS_LENGTH;
        assembly ("memory-safe") {
            wordsDynamic := wordsFixed
            mstore(wordsDynamic, length)
        }
        return abi.encode(wordsDynamic);
    }

    function integrityFunctionPointers() internal pure returns (bytes memory) {
        unchecked {
            function(IntegrityCheckStateNP memory, Operand)
                view
                returns (uint256, uint256) lengthPointer;
            uint256 length = ALL_STANDARD_OPS_LENGTH;
            assembly ("memory-safe") {
                lengthPointer := length
            }
            function(IntegrityCheckStateNP memory, Operand)
                view
                returns (uint256, uint256)[ALL_STANDARD_OPS_LENGTH + 1] memory pointersFixed = [
                    lengthPointer,
                    // Stack then constant are the first two ops to match the
                    // field ordering in the interpreter state NOT the lexical
                    // ordering of the file system.
                    LibOpStackNP.integrity,
                    LibOpConstantNP.integrity,
                    // Everything else is alphabetical, including folders.
                    LibOpCallNP.integrity,
                    LibOpContextNP.integrity,
                    LibOpHashNP.integrity,
                    LibOpBlockNumberNP.integrity,
                    LibOpChainIdNP.integrity,
                    // int and decimal18 max have identical implementations and
                    // point to the same function pointer. This is intentional.
                    LibOpMaxUint256NP.integrity,
                    // decimal18 max.
                    LibOpMaxUint256NP.integrity,
                    LibOpTimestampNP.integrity,
                    LibOpAnyNP.integrity,
                    LibOpConditionsNP.integrity,
                    LibOpEnsureNP.integrity,
                    LibOpEqualToNP.integrity,
                    LibOpEveryNP.integrity,
                    LibOpGreaterThanNP.integrity,
                    LibOpGreaterThanOrEqualToNP.integrity,
                    LibOpIfNP.integrity,
                    LibOpIsZeroNP.integrity,
                    LibOpLessThanNP.integrity,
                    LibOpLessThanOrEqualToNP.integrity,
                    LibOpDecimal18DivNP.integrity,
                    LibOpDecimal18MulNP.integrity,
                    LibOpDecimal18Scale18DynamicNP.integrity,
                    LibOpDecimal18Scale18NP.integrity,
                    LibOpDecimal18ScaleNNP.integrity,
                    // int and decimal18 add have identical implementations and
                    // point to the same function pointer. This is intentional.
                    LibOpIntAddNP.integrity,
                    // decimal18 add.
                    LibOpIntAddNP.integrity,
                    LibOpIntDivNP.integrity,
                    LibOpIntExpNP.integrity,
                    // int and decimal18 max have identical implementations and
                    // point to the same function pointer. This is intentional.
                    LibOpIntMaxNP.integrity,
                    // decimal18 max.
                    LibOpIntMaxNP.integrity,
                    // int and decimal18 min have identical implementations and
                    // point to the same function pointer. This is intentional.
                    LibOpIntMinNP.integrity,
                    // decimal18 min.
                    LibOpIntMinNP.integrity,
                    LibOpIntModNP.integrity,
                    LibOpIntMulNP.integrity,
                    // int and decimal18 sub have identical implementations and
                    // point to the same function pointer. This is intentional.
                    LibOpIntSubNP.integrity,
                    // decimal18 sub.
                    LibOpIntSubNP.integrity,
                    LibOpGetNP.integrity,
                    LibOpSetNP.integrity,
                    LibOpUniswapV2AmountIn.integrity,
                    LibOpUniswapV2AmountOut.integrity
                ];
            uint256[] memory pointersDynamic;
            assembly ("memory-safe") {
                pointersDynamic := pointersFixed
            }
            // Sanity check that the dynamic length is correct. Should be an
            // unreachable error.
            if (pointersDynamic.length != ALL_STANDARD_OPS_LENGTH) {
                revert BadDynamicLength(pointersDynamic.length, length);
            }
            return LibConvert.unsafeTo16BitBytes(pointersDynamic);
        }
    }

    /// All function pointers for the standard opcodes. Intended to be used to
    /// build a `IInterpreterV1` instance, specifically the `functionPointers`
    /// method can just be a thin wrapper around this function.
    function opcodeFunctionPointers() internal pure returns (bytes memory) {
        unchecked {
            function(InterpreterStateNP memory, Operand, Pointer)
                view
                returns (Pointer) lengthPointer;
            uint256 length = ALL_STANDARD_OPS_LENGTH;
            assembly ("memory-safe") {
                lengthPointer := length
            }
            function(InterpreterStateNP memory, Operand, Pointer)
                view
                returns (Pointer)[ALL_STANDARD_OPS_LENGTH + 1] memory pointersFixed = [
                    lengthPointer,
                    // Stack then constant are the first two ops to match the
                    // field ordering in the interpreter state NOT the lexical
                    // ordering of the file system.
                    LibOpStackNP.run,
                    LibOpConstantNP.run,
                    // Everything else is alphabetical, including folders.
                    LibOpCallNP.run,
                    LibOpContextNP.run,
                    LibOpHashNP.run,
                    LibOpBlockNumberNP.run,
                    LibOpChainIdNP.run,
                    // int and decimal18 max have identical implementations and
                    // point to the same function pointer. This is intentional.
                    LibOpMaxUint256NP.run,
                    // decimal18 max.
                    LibOpMaxUint256NP.run,
                    LibOpTimestampNP.run,
                    LibOpAnyNP.run,
                    LibOpConditionsNP.run,
                    LibOpEnsureNP.run,
                    LibOpEqualToNP.run,
                    LibOpEveryNP.run,
                    LibOpGreaterThanNP.run,
                    LibOpGreaterThanOrEqualToNP.run,
                    LibOpIfNP.run,
                    LibOpIsZeroNP.run,
                    LibOpLessThanNP.run,
                    LibOpLessThanOrEqualToNP.run,
                    LibOpDecimal18DivNP.run,
                    LibOpDecimal18MulNP.run,
                    LibOpDecimal18Scale18DynamicNP.run,
                    LibOpDecimal18Scale18NP.run,
                    LibOpDecimal18ScaleNNP.run,
                    // int and decimal18 add have identical implementations and
                    // point to the same function pointer. This is intentional.
                    LibOpIntAddNP.run,
                    // decimal18 add.
                    LibOpIntAddNP.run,
                    LibOpIntDivNP.run,
                    LibOpIntExpNP.run,
                    // int and decimal18 max have identical implementations and
                    // point to the same function pointer. This is intentional.
                    LibOpIntMaxNP.run,
                    // decimal18 max.
                    LibOpIntMaxNP.run,
                    // int and decimal18 min have identical implementations and
                    // point to the same function pointer. This is intentional.
                    LibOpIntMinNP.run,
                    // decimal18 min.
                    LibOpIntMinNP.run,
                    LibOpIntModNP.run,
                    LibOpIntMulNP.run,
                    // int and decimal18 sub have identical implementations and
                    // point to the same function pointer. This is intentional.
                    LibOpIntSubNP.run,
                    // decimal18 sub.
                    LibOpIntSubNP.run,
                    LibOpGetNP.run,
                    LibOpSetNP.run,
                    LibOpUniswapV2AmountIn.run,
                    LibOpUniswapV2AmountOut.run
                ];
            uint256[] memory pointersDynamic;
            assembly ("memory-safe") {
                pointersDynamic := pointersFixed
            }
            // Sanity check that the dynamic length is correct. Should be an
            // unreachable error.
            if (pointersDynamic.length != ALL_STANDARD_OPS_LENGTH) {
                revert BadDynamicLength(pointersDynamic.length, length);
            }
            return LibConvert.unsafeTo16BitBytes(pointersDynamic);
        }
    }
}
