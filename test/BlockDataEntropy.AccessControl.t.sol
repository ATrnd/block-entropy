// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BlockDataEntropy} from "../src/implementations/BlockDataEntropy.sol";
import {BlockDataEntropyTestProxy} from "./mock/BlockDataEntropyTestProxy.sol";

/**
 * @title BlockDataEntropy Access Control Test
 * @notice Comprehensive tests for orchestrator pattern implementation
 * @dev Tests orchestrator configuration, access control, and error tracking
 */
contract BlockDataEntropyAccessControlTest is Test {
    BlockDataEntropy public blockEntropy;
    BlockDataEntropyTestProxy public proxy;

    // Test addresses
    address public owner;
    address public orchestrator;
    address public unauthorizedUser;
    address public anotherUser;

    // Events for testing
    event OrchestratorConfigured(address indexed orchestrator);

    function setUp() public {
        // Setup addresses
        owner = makeAddr("owner");
        orchestrator = makeAddr("orchestrator");
        unauthorizedUser = makeAddr("unauthorizedUser");
        anotherUser = makeAddr("anotherUser");

        // Fund addresses for gas
        vm.deal(owner, 100 ether);
        vm.deal(orchestrator, 100 ether);
        vm.deal(unauthorizedUser, 100 ether);
        vm.deal(anotherUser, 100 ether);

        // Deploy contracts
        vm.prank(owner);
        blockEntropy = new BlockDataEntropy(owner);

        vm.prank(owner);
        proxy = new BlockDataEntropyTestProxy(owner);
    }

    /*//////////////////////////////////////////////////////////////
                    ORCHESTRATOR CONFIGURATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SuccessfulOrchestratorConfiguration() public {
        // Initial state should be unconfigured
        assertEq(blockEntropy.getOrchestrator(), address(0));
        assertFalse(blockEntropy.isOrchestratorConfigured());

        // Expect OrchestratorConfigured event
        vm.expectEmit(true, false, false, false);
        emit OrchestratorConfigured(orchestrator);

        // Configure orchestrator as owner
        vm.prank(owner);
        blockEntropy.setOrchestratorOnce(orchestrator);

        // Verify configuration
        assertEq(blockEntropy.getOrchestrator(), orchestrator);
        assertTrue(blockEntropy.isOrchestratorConfigured());
    }

    function test_PreventMultipleConfigurations() public {
        // Configure orchestrator first time
        vm.prank(owner);
        blockEntropy.setOrchestratorOnce(orchestrator);

        // Attempt to configure again should fail
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("BlockEntropy__OrchestratorAlreadyConfigured()"));
        blockEntropy.setOrchestratorOnce(anotherUser);

        // Verify original configuration unchanged
        assertEq(blockEntropy.getOrchestrator(), orchestrator);
        assertTrue(blockEntropy.isOrchestratorConfigured());
    }

    function test_InvalidOrchestratorAddressRejection() public {
        // Attempt to configure zero address should fail
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("BlockEntropy__InvalidOrchestratorAddress()"));
        blockEntropy.setOrchestratorOnce(address(0));

        // Verify still unconfigured
        assertEq(blockEntropy.getOrchestrator(), address(0));
        assertFalse(blockEntropy.isOrchestratorConfigured());
    }

    function test_OwnerOnlyConfigurationRequirement() public {
        // Non-owner attempts to configure should fail
        vm.prank(unauthorizedUser);
        vm.expectRevert();
        blockEntropy.setOrchestratorOnce(orchestrator);

        // Verify still unconfigured
        assertEq(blockEntropy.getOrchestrator(), address(0));
        assertFalse(blockEntropy.isOrchestratorConfigured());
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AuthorizedOrchestratorCanCallGetEntropy() public {
        // Configure orchestrator
        vm.prank(owner);
        blockEntropy.setOrchestratorOnce(orchestrator);

        // Orchestrator should be able to call getEntropy
        vm.prank(orchestrator);
        bytes32 entropy = blockEntropy.getEntropy(123);

        // Verify entropy was generated (should not be zero)
        assertTrue(entropy != bytes32(0));
    }

    function test_UnauthorizedCallersAreRejected() public {
        // Configure orchestrator
        vm.prank(owner);
        blockEntropy.setOrchestratorOnce(orchestrator);

        // Unauthorized user should be rejected
        vm.prank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSignature("BlockEntropy__UnauthorizedOrchestrator()"));
        blockEntropy.getEntropy(123);

        // Even the owner should be rejected (only orchestrator allowed)
        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("BlockEntropy__UnauthorizedOrchestrator()"));
        blockEntropy.getEntropy(123);
    }

    function test_UnconfiguredOrchestratorScenario() public {
        // Without configuring orchestrator, any call should fail
        vm.prank(orchestrator);
        vm.expectRevert(abi.encodeWithSignature("BlockEntropy__OrchestratorNotConfigured()"));
        blockEntropy.getEntropy(123);

        vm.prank(unauthorizedUser);
        vm.expectRevert(abi.encodeWithSignature("BlockEntropy__OrchestratorNotConfigured()"));
        blockEntropy.getEntropy(123);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("BlockEntropy__OrchestratorNotConfigured()"));
        blockEntropy.getEntropy(123);
    }

    /*//////////////////////////////////////////////////////////////
                        ERROR TRACKING TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ErrorCountingFunctionsExist() public view {
        // Test that all error counting functions exist and return zero initially
        // NOTE: Access control errors cause reverts, which rollback error counter increments
        // This is expected behavior - we test function existence, not increment counting

        assertEq(blockEntropy.getAccessControlOrchestratorNotConfiguredCount(), 0);
        assertEq(blockEntropy.getAccessControlUnauthorizedOrchestratorCount(), 0);
        assertEq(blockEntropy.getAccessControlOrchestratorAlreadyConfiguredCount(), 0);
        assertEq(blockEntropy.getAccessControlInvalidOrchestratorAddressCount(), 0);
    }

    function test_ErrorCountingUsingProxy() public {
        // Use proxy to force increment error counters (like address-entropy pattern)

        // Force increment access control errors using proxy
        proxy.forceIncrementComponentErrorCount(4, 6); // Component 4, Error 6 (not configured)
        proxy.forceIncrementComponentErrorCount(4, 7); // Component 4, Error 7 (unauthorized)

        // Verify counts incremented
        assertEq(proxy.getAccessControlOrchestratorNotConfiguredCount(), 1);
        assertEq(proxy.getAccessControlUnauthorizedOrchestratorCount(), 1);

        // Test component total error count
        assertEq(proxy.getComponentTotalErrorCount(4), 2);
    }

    function test_ComponentErrorCountGenericFunction() public {
        // Test generic component error count function for access control
        uint8 accessControlComponent = 4;
        uint8 notConfiguredError = 6;
        uint8 unauthorizedError = 7;

        // Use proxy to force errors
        proxy.forceIncrementComponentErrorCount(accessControlComponent, notConfiguredError);
        proxy.forceIncrementComponentErrorCount(accessControlComponent, unauthorizedError);

        // Check generic error count function
        assertEq(proxy.getComponentErrorCount(accessControlComponent, notConfiguredError), 1);
        assertEq(proxy.getComponentErrorCount(accessControlComponent, unauthorizedError), 1);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OrchestratorFunctionalityWithExistingEntropyGeneration() public {
        // Configure orchestrator
        vm.prank(owner);
        blockEntropy.setOrchestratorOnce(orchestrator);

        // Generate multiple entropy values as orchestrator
        vm.startPrank(orchestrator);

        bytes32 entropy1 = blockEntropy.getEntropy(123);
        bytes32 entropy2 = blockEntropy.getEntropy(456);
        bytes32 entropy3 = blockEntropy.getEntropy(789);

        vm.stopPrank();

        // All entropy values should be non-zero and different
        assertTrue(entropy1 != bytes32(0));
        assertTrue(entropy2 != bytes32(0));
        assertTrue(entropy3 != bytes32(0));
        assertTrue(entropy1 != entropy2);
        assertTrue(entropy2 != entropy3);
        assertTrue(entropy1 != entropy3);

        // Test with proxy to check state changes
        vm.prank(owner);
        proxy.setOrchestratorOnce(orchestrator);

        vm.startPrank(orchestrator);

        uint256 initialTxCounter = proxy.getTransactionCounter();
        proxy.getEntropy(999);
        uint256 finalTxCounter = proxy.getTransactionCounter();

        vm.stopPrank();

        // Transaction counter should increment
        assertEq(finalTxCounter, initialTxCounter + 1);
    }

    function test_ErrorTrackingIntegrationWithExistingComponents() public {
        // Test that access control errors don't interfere with other component errors

        // Force some regular entropy generation errors using proxy
        proxy.forceGenerateZeroBlockHash(true);
        proxy.forceSetLastProcessedBlock(0);

        vm.prank(owner);
        proxy.setOrchestratorOnce(orchestrator);

        vm.prank(orchestrator);
        proxy.getEntropy(123);

        // Check that block hash component has errors
        assertGt(proxy.getBlockHashZeroHashCount(), 0);

        // Access control component should still have zero errors (successful call)
        assertEq(proxy.getAccessControlOrchestratorNotConfiguredCount(), 0);
        assertEq(proxy.getAccessControlUnauthorizedOrchestratorCount(), 0);

        // Manually force access control error using proxy (can't test actual reverts)
        proxy.forceIncrementComponentErrorCount(4, 7); // Component 4, Error 7 (unauthorized)

        // Access control should have errors now
        assertEq(proxy.getAccessControlUnauthorizedOrchestratorCount(), 1);

        // Block hash errors should be unchanged
        assertGt(proxy.getBlockHashZeroHashCount(), 0);

        // Reset proxy state and try again
        proxy.resetFallbackCounters();
        proxy.forceGenerateZeroBlockHash(false);

        vm.prank(orchestrator);
        proxy.getEntropy(789);

        // Both error types should be reset to zero
        assertEq(proxy.getBlockHashZeroHashCount(), 0);
        assertEq(proxy.getAccessControlUnauthorizedOrchestratorCount(), 0);
    }

    function test_AccessControlWithMultipleContractInstances() public {
        // Deploy second contract instance
        vm.prank(owner);
        BlockDataEntropy secondContract = new BlockDataEntropy(owner);

        // Configure different orchestrators
        vm.prank(owner);
        blockEntropy.setOrchestratorOnce(orchestrator);

        vm.prank(owner);
        secondContract.setOrchestratorOnce(anotherUser);

        // Each contract should only accept its own orchestrator
        vm.prank(orchestrator);
        bytes32 entropy1 = blockEntropy.getEntropy(123);

        vm.prank(anotherUser);
        bytes32 entropy2 = secondContract.getEntropy(456);

        // Cross-contract calls should fail
        vm.prank(orchestrator);
        vm.expectRevert(abi.encodeWithSignature("BlockEntropy__UnauthorizedOrchestrator()"));
        secondContract.getEntropy(789);

        vm.prank(anotherUser);
        vm.expectRevert(abi.encodeWithSignature("BlockEntropy__UnauthorizedOrchestrator()"));
        blockEntropy.getEntropy(999);

        // Successful calls should produce different entropy
        assertTrue(entropy1 != entropy2);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_OrchestratorConfigurationAfterOwnershipTransfer() public {
        // Transfer ownership to another address
        address newOwner = makeAddr("newOwner");
        vm.deal(newOwner, 100 ether);

        vm.prank(owner);
        blockEntropy.transferOwnership(newOwner);

        // Old owner should not be able to configure orchestrator
        vm.prank(owner);
        vm.expectRevert();
        blockEntropy.setOrchestratorOnce(orchestrator);

        // New owner should be able to configure orchestrator
        vm.prank(newOwner);
        blockEntropy.setOrchestratorOnce(orchestrator);

        // Verify configuration worked
        assertEq(blockEntropy.getOrchestrator(), orchestrator);
        assertTrue(blockEntropy.isOrchestratorConfigured());
    }

    function test_ComponentErrorCountQueries() public {
        // Test generic component error count function for access control
        uint8 accessControlComponent = 4;
        uint8 notConfiguredError = 6;
        uint8 unauthorizedError = 7;

        // Use proxy to force increment error counters
        proxy.forceIncrementComponentErrorCount(accessControlComponent, notConfiguredError);

        // Check generic error count function
        assertEq(proxy.getComponentErrorCount(accessControlComponent, notConfiguredError), 1);
        assertEq(proxy.getComponentErrorCount(accessControlComponent, unauthorizedError), 0);

        // Force unauthorized error
        proxy.forceIncrementComponentErrorCount(accessControlComponent, unauthorizedError);

        // Check both error types
        assertEq(proxy.getComponentErrorCount(accessControlComponent, notConfiguredError), 1);
        assertEq(proxy.getComponentErrorCount(accessControlComponent, unauthorizedError), 1);
    }
}