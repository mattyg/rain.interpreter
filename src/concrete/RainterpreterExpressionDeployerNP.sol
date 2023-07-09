// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

import "sol.lib.memory/LibPointer.sol";
import "sol.lib.memory/LibStackPointer.sol";
import "rain.datacontract/LibDataContract.sol";
import "rain.factory/src/lib/LibIERC1820.sol";

import "../interface/IExpressionDeployerV1.sol";
import "../interface/unstable/IDebugExpressionDeployerV1.sol";
import "../interface/unstable/IDebugInterpreterV1.sol";

import "../lib/integrity/LibIntegrityCheck.sol";
import "../lib/state/LibInterpreterStateDataContract.sol";
import "../lib/op/LibAllStandardOpsNP.sol";
import "../lib/parse/LibParse.sol";

/// @dev Thrown when the pointers known to the expression deployer DO NOT match
/// the interpreter it is constructed for. This WILL cause undefined expression
/// behaviour so MUST REVERT.
/// @param actualPointers The actual function pointers found at the interpreter
/// address upon construction.
error UnexpectedPointers(bytes actualPointers);

/// Thrown when the `RainterpreterExpressionDeployer` is constructed with unknown
/// interpreter bytecode.
/// @param actualBytecodeHash The bytecode hash that was found at the interpreter
/// address upon construction.
error UnexpectedInterpreterBytecodeHash(bytes32 actualBytecodeHash);

/// @dev There are more entrypoints defined by the minimum stack outputs than
/// there are provided sources. This means the calling contract WILL attempt to
/// eval a dangling reference to a non-existent source at some point, so this
/// MUST REVERT.
error MissingEntrypoint(uint256 expectedEntrypoints, uint256 actualEntrypoints);

/// Thrown when the `Rainterpreter` is constructed with unknown store bytecode.
/// @param actualBytecodeHash The bytecode hash that was found at the store
/// address upon construction.
error UnexpectedStoreBytecodeHash(bytes32 actualBytecodeHash);

/// Thrown when the `Rainterpreter` is constructed with unknown opMeta.
error UnexpectedOpMetaHash(bytes32 actualOpMeta);

/// @dev The function pointers known to the expression deployer. These are
/// immutable for any given interpreter so once the expression deployer is
/// constructed and has verified that this matches what the interpreter reports,
/// it can use this constant value to compile and serialize expressions.
bytes constant OPCODE_FUNCTION_POINTERS = hex"09ec";

/// @dev Hash of the known interpreter bytecode.
bytes32 constant INTERPRETER_BYTECODE_HASH = bytes32(0xda69fab45680e6c6ea401753eff6a96472f30126e7c8fc6ccae147ab68e36776);

/// @dev Hash of the known store bytecode.
bytes32 constant STORE_BYTECODE_HASH = bytes32(0xd6130168250d3957ae34f8026c2bdbd7e21d35bb202e8540a9b3abcbc232ddb6);

/// @dev Hash of the known op meta.
bytes32 constant OP_META_HASH = bytes32(0x2cf73adad61aae49cfe0a38448ca982e30a16b18fe56c294e51104f9148d94da);

/// All config required to construct a `Rainterpreter`.
/// @param store The `IInterpreterStoreV1`. MUST match known bytecode.
/// @param opMeta All opmeta as binary data. MAY be compressed bytes etc. The
/// opMeta describes the opcodes for this interpreter to offchain tooling.
struct RainterpreterExpressionDeployerConstructionConfig {
    address interpreter;
    address store;
    bytes meta;
}

/// @title RainterpreterExpressionDeployer
/// @notice Minimal binding of the `IExpressionDeployerV1` interface to the
/// `LibIntegrityCheck.ensureIntegrity` loop and `AllStandardOps`.
contract RainterpreterExpressionDeployerNP is IExpressionDeployerV1, IDebugExpressionDeployerV1, ERC165 {
    using LibStackPointer for Pointer;
    using LibUint256Array for uint256[];

    /// The config of the deployed expression including uncompiled sources. Will
    /// only be emitted after the config passes the integrity check.
    /// @param sender The caller of `deployExpression`.
    /// @param sources As per `IExpressionDeployerV1`.
    /// @param constants As per `IExpressionDeployerV1`.
    /// @param minOutputs As per `IExpressionDeployerV1`.
    event NewExpression(address sender, bytes[] sources, uint256[] constants, uint256[] minOutputs);

    /// The address of the deployed expression. Will only be emitted once the
    /// expression can be loaded and deserialized into an evaluable interpreter
    /// state.
    /// @param sender The caller of `deployExpression`.
    /// @param expression The address of the deployed expression.
    event ExpressionAddress(address sender, address expression);

    IInterpreterV1 public immutable iInterpreter;
    IInterpreterStoreV1 public immutable iStore;

    /// THIS IS NOT A SECURITY CHECK. IT IS AN INTEGRITY CHECK TO PREVENT HONEST
    /// MISTAKES. IT CANNOT PREVENT EITHER A MALICIOUS INTERPRETER OR DEPLOYER
    /// FROM BEING EXECUTED.
    constructor(RainterpreterExpressionDeployerConstructionConfig memory config) {
        IInterpreterV1 interpreter = IInterpreterV1(config.interpreter);
        // Guard against serializing incorrect function pointers, which would
        // cause undefined runtime behaviour for corrupted opcodes.
        bytes memory functionPointers = interpreter.functionPointers();
        if (keccak256(functionPointers) != keccak256(OPCODE_FUNCTION_POINTERS)) {
            revert UnexpectedPointers(functionPointers);
        }
        // Guard against an interpreter with unknown bytecode.
        bytes32 interpreterHash;
        assembly ("memory-safe") {
            interpreterHash := extcodehash(interpreter)
        }
        if (interpreterHash != INTERPRETER_BYTECODE_HASH) {
            /// THIS IS NOT A SECURITY CHECK. IT IS AN INTEGRITY CHECK TO PREVENT
            /// HONEST MISTAKES.
            revert UnexpectedInterpreterBytecodeHash(interpreterHash);
        }

        // Guard against an store with unknown bytecode.
        IInterpreterStoreV1 store = IInterpreterStoreV1(config.store);
        bytes32 storeHash;
        assembly ("memory-safe") {
            storeHash := extcodehash(store)
        }
        if (storeHash != STORE_BYTECODE_HASH) {
            /// THIS IS NOT A SECURITY CHECK. IT IS AN INTEGRITY CHECK TO PREVENT
            /// HONEST MISTAKES.
            revert UnexpectedStoreBytecodeHash(storeHash);
        }

        /// This IS a security check. This prevents someone making an exact
        /// bytecode copy of the interpreter and shipping different meta for
        /// the copy to lie about what each op does in the interpreter.
        bytes32 opMetaHash = keccak256(config.meta);
        if (opMetaHash != OP_META_HASH) {
            revert UnexpectedOpMetaHash(opMetaHash);
        }

        iInterpreter = interpreter;
        iStore = store;

        emit DISpair(msg.sender, address(this), config.interpreter, config.store, config.meta);

        IERC1820_REGISTRY.setInterfaceImplementer(
            address(this), IERC1820_REGISTRY.interfaceHash(IERC1820_NAME_IEXPRESSION_DEPLOYER_V1), address(this)
        );
    }

    // @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId_) public view virtual override returns (bool) {
        return interfaceId_ == type(IExpressionDeployerV1).interfaceId || interfaceId_ == type(IERC165).interfaceId;
    }

    /// Defines all the function pointers to integrity checks. This is the
    /// expression deployer's equivalent of the opcode function pointers and
    /// follows a near identical dispatch process. These are never compiled into
    /// source and are instead indexed into directly by the integrity check. The
    /// indexing into integrity pointers (which has an out of bounds check) is a
    /// proxy for enforcing that all opcode pointers exist at runtime, so the
    /// length of the integrity pointers MUST match the length of opcode function
    /// pointers. This function is `virtual` so that it can be overridden
    /// pairwise with overrides to `functionPointers` on `Rainterpreter`.
    /// @return The list of integrity function pointers.
    function integrityFunctionPointers()
        internal
        view
        virtual
        returns (
            function(IntegrityCheckState memory, Operand, Pointer)
                                                                        view
                                                                        returns (Pointer)[] memory
        )
    {
        return LibAllStandardOpsNP.integrityFunctionPointers();
    }

    /// @inheritdoc IDebugExpressionDeployerV1
    function offchainDebugEval(
        bytes[] memory sources_,
        uint256[] memory constants_,
        FullyQualifiedNamespace namespace_,
        uint256[][] memory context_,
        SourceIndex sourceIndex_,
        uint256[] memory initialStack_,
        uint256 minOutputs_
    ) external view returns (uint256[] memory, uint256[] memory) {
        IntegrityCheckState memory integrityCheckState_ =
            LibIntegrityCheck.newState(sources_, constants_, integrityFunctionPointers());
        Pointer stackTop_ = integrityCheckState_.stackBottom;
        stackTop_ = LibIntegrityCheck.push(integrityCheckState_, stackTop_, initialStack_.length);
        LibIntegrityCheck.ensureIntegrity(integrityCheckState_, sourceIndex_, stackTop_, minOutputs_);
        uint256[] memory stack_;
        {
            uint256 stackLength_ = integrityCheckState_.stackBottom.unsafeToIndex(integrityCheckState_.stackMaxTop);
            for (uint256 i_; i_ < sources_.length; i_++) {
                LibCompile.unsafeCompile(sources_[i_], OPCODE_FUNCTION_POINTERS);
            }
            stack_ = new uint256[](stackLength_);
            LibMemCpy.unsafeCopyWordsTo(initialStack_.dataPointer(), stack_.dataPointer(), initialStack_.length);
        }

        return IDebugInterpreterV1(address(iInterpreter)).offchainDebugEval(
            iStore, namespace_, sources_, constants_, context_, stack_, sourceIndex_
        );
    }

    function parse(bytes memory data) external pure returns (bytes[] memory, uint256[] memory) {
        bytes32[] memory words = new bytes32[](1);
        words[0] = "chain-id";
        return LibParse.parse(data, LibParseMeta.buildMetaExpander(words, 2));
    }

    function integrityCheck(bytes[] memory sources, uint256[] memory constants, uint256[] memory minOutputs)
        internal
        view
        returns (uint256)
    {
        // Ensure that we are not missing any entrypoints expected by the calling
        // contract.
        if (minOutputs.length > sources.length) {
            revert MissingEntrypoint(minOutputs.length, sources.length);
        }

        // Build the initial state of the integrity check.
        IntegrityCheckState memory integrityCheckState =
            LibIntegrityCheck.newState(sources, constants, integrityFunctionPointers());
        // Loop over each possible entrypoint as defined by the calling contract
        // and check the integrity of each. At the least we need to be sure that
        // there are no out of bounds stack reads/writes and to know the total
        // memory to allocate when later deserializing an associated interpreter
        // state for evaluation.
        Pointer initialStackBottom = integrityCheckState.stackBottom;
        Pointer initialStackHighwater = integrityCheckState.stackHighwater;
        for (uint16 i_ = 0; i_ < minOutputs.length; i_++) {
            // Reset the top, bottom and highwater between each entrypoint as
            // every external eval MUST have a fresh stack, but retain the max
            // stack height as the latter is used for unconditional memory
            // allocation so MUST be the max height across all possible
            // entrypoints.
            integrityCheckState.stackBottom = initialStackBottom;
            integrityCheckState.stackHighwater = initialStackHighwater;
            LibIntegrityCheck.ensureIntegrity(
                integrityCheckState, SourceIndex.wrap(i_), INITIAL_STACK_BOTTOM, minOutputs[i_]
            );
        }

        return integrityCheckState.stackBottom.unsafeToIndex(integrityCheckState.stackMaxTop);
    }

    /// @inheritdoc IExpressionDeployerV1
    function deployExpression(bytes[] memory sources_, uint256[] memory constants_, uint256[] memory minOutputs_)
        external
        returns (IInterpreterV1, IInterpreterStoreV1, address)
    {
        uint256 stackLength_ = integrityCheck(sources_, constants_, minOutputs_);

        // Emit the config of the expression _before_ we serialize it, as the
        // serialization process itself is destructive of the sources in memory.
        emit NewExpression(msg.sender, sources_, constants_, minOutputs_);

        (DataContractMemoryContainer container_, Pointer pointer_) =
            LibDataContract.newContainer(LibInterpreterStateDataContract.serializeSize(sources_, constants_));

        // Serialize the state config into bytes that can be deserialized later
        // by the interpreter. This will compile the sources according to the
        // provided function pointers.
        LibInterpreterStateDataContract.unsafeSerialize(
            pointer_, sources_, constants_, stackLength_, OPCODE_FUNCTION_POINTERS
        );

        // Deploy the serialized expression onchain.
        address expression = LibDataContract.write(container_);

        // Emit and return the address of the deployed expression.
        emit ExpressionAddress(msg.sender, expression);

        return (iInterpreter, iStore, expression);
    }
}
