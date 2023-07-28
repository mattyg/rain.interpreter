// SPDX-License-Identifier: CAL
pragma solidity =0.8.19;

import "forge-std/Test.sol";
import "test/util/lib/etch/LibEtch.sol";
import "test/util/abstract/RainterpreterExpressionDeployerDeploymentTest.sol";

import "src/concrete/RainterpreterStore.sol";
import "src/concrete/RainterpreterNP.sol";
import "src/concrete/RainterpreterExpressionDeployerNP.sol";

/// @title RainterpreterExpressionDeployerMetaTest
/// Tests that the RainterpreterExpressionDeployer meta is correct. Also tests
/// basic functionality of the `IParserV1` interface implementation.
contract RainterpreterExpressionDeployerMetaTest is RainterpreterExpressionDeployerDeploymentTest {
    /// Test that the authoring meta hash is correct.
    function testRainterpreterExpressionDeployerAuthoringMetaHash() external {
        bytes memory authoringMeta = LibRainterpreterExpressionDeployerNPMeta.authoringMeta();
        bytes32 expectedHash = keccak256(authoringMeta);
        bytes32 actualHash = iDeployer.authoringMetaHash();
        assertEq(actualHash, expectedHash);
    }

    /// Test that the parse meta is correct.
    function testRainterpreterExpressionDeployerParseMeta() external {
        bytes memory parseMeta = iDeployer.parseMeta();
        bytes memory expectedParseMeta = LibRainterpreterExpressionDeployerNPMeta.buildParseMetaFromAuthoringMeta(
            LibRainterpreterExpressionDeployerNPMeta.authoringMeta()
        );
        assertEq(parseMeta, expectedParseMeta);
    }

    /// Test that the deployer agrees with itself for a build and view.
    function testRainterpreterExpressionDeployerBuildAndParse() external {
        bytes memory authoringMeta = LibRainterpreterExpressionDeployerNPMeta.authoringMeta();
        bytes memory builtParseMeta = iDeployer.buildParseMeta(authoringMeta);
        bytes memory parseMeta = iDeployer.parseMeta();
        assertEq(keccak256(builtParseMeta), keccak256(parseMeta));
    }

    /// Test that invalid authoring meta reverts the parse meta builder.
    function testRainterpreterExpressionDeployerBuildParseMetaReverts(bytes memory authoringMeta) external {
        bytes32 expectedHash = iDeployer.authoringMetaHash();
        bytes32 actualHash = keccak256(authoringMeta);
        vm.assume(actualHash != expectedHash);
        vm.expectRevert(abi.encodeWithSelector(AuthoringMetaHashMismatch.selector, expectedHash, actualHash));
        iDeployer.buildParseMeta(authoringMeta);
    }
}
