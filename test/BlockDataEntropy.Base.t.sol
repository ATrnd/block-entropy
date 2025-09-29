// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BlockDataEntropy} from "../src/implementations/BlockDataEntropy.sol";
import {BlockDataEntropyTestProxy} from "./mock/BlockDataEntropyTestProxy.sol";

contract BlockDataEntropyBaseTest is Test {
    // Use proxy for both entropy generation AND state inspection (same as address-entropy-engine pattern)
    BlockDataEntropyTestProxy public blockDataEntropy;

    // Common addresses
    address public owner;
    address public user;

    function setUp() public virtual {
        // Setup addresses
        owner = makeAddr("owner");
        user = makeAddr("user");

        // Fund user for tests
        vm.deal(user, 100 ether);

        // Deploy proxy - this IS our main contract for testing (inherits all functionality)
        vm.prank(owner);
        blockDataEntropy = new BlockDataEntropyTestProxy(owner);
    }

    /// ============================================
    /// ============= Constructor Tests ===========
    /// ============================================

    function test_ConstructorSetup() public view {
        // Verify initial state variables are set correctly using proxy (which IS the main contract)
        assertEq(blockDataEntropy.getCurrentSegmentIndex(), 0, "Initial segment index should be 0");
        assertEq(blockDataEntropy.getTransactionCounter(), 0, "Initial transaction counter should be 0");
        assertEq(blockDataEntropy.getLastProcessedBlock(), 0, "Initial last processed block should be 0");

        // Check component-specific error counters are initialized to zero
        assertEq(blockDataEntropy.getBlockHashZeroHashCount(), 0, "Block hash zero count should be 0");
        assertEq(blockDataEntropy.getEntropyGenerationZeroSegmentCount(), 0, "Entropy zero segment count should be 0");
        assertEq(blockDataEntropy.getComponentErrorCount(1, 1), 0, "Component error count should be 0");
    }

    function test_OwnershipSetup() public view {
        assertEq(blockDataEntropy.owner(), owner, "Owner should be set correctly");
    }

    /// ============================================
    /// ============= Basic Entropy Tests ==========
    /// ============================================

    function test_FirstEntropyCall() public {
        vm.prank(user);
        uint256 salt = 123;
        bytes32 entropy = blockDataEntropy.getEntropy(salt);

        // Since entropy is non-deterministic, we just verify it's not zero
        assertTrue(entropy != bytes32(0), "Entropy should not be zero");

        // Check state changes
        assertEq(blockDataEntropy.getTransactionCounter(), 1, "Transaction counter should increment");
        assertEq(blockDataEntropy.getCurrentSegmentIndex(), 1, "Segment index should increment");
        assertTrue(blockDataEntropy.getLastProcessedBlock() > 0, "Last processed block should be updated");
    }

    function test_MultipleEntropyCalls() public {
        vm.startPrank(user);
        uint256 salt = 123;

        // First call
        bytes32 entropy1 = blockDataEntropy.getEntropy(salt);

        // Second call
        bytes32 entropy2 = blockDataEntropy.getEntropy(salt);

        // Entropy should be different even with the same salt
        assertTrue(entropy1 != entropy2, "Entropy values should be different even with same salt");

        // Check state changes
        assertEq(blockDataEntropy.getTransactionCounter(), 2, "Transaction counter should increment twice");
        assertEq(blockDataEntropy.getCurrentSegmentIndex(), 2, "Segment index should increment twice");

        vm.stopPrank();
    }

    function test_DifferentSaltValues() public {
        vm.startPrank(user);

        // Generate entropy with different salts
        bytes32 entropy1 = blockDataEntropy.getEntropy(123);
        bytes32 entropy2 = blockDataEntropy.getEntropy(456);

        // Entropy should be different with different salts
        assertTrue(entropy1 != entropy2, "Entropy should be different with different salts");

        vm.stopPrank();
    }

    function test_DifferentCallers() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");

        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);

        // Generate entropy from different callers with same salt
        vm.prank(alice);
        bytes32 entropyAlice = blockDataEntropy.getEntropy(123);

        vm.prank(bob);
        bytes32 entropyBob = blockDataEntropy.getEntropy(123);

        // Entropy should be different with different callers
        assertTrue(entropyAlice != entropyBob, "Entropy should be different with different callers");
    }

    function test_SegmentCycling() public {
        vm.startPrank(user);

        // Call getEntropy 5 times to cycle through all segments (0-3) and back to 0
        for (uint256 i = 0; i < 5; i++) {
            blockDataEntropy.getEntropy(i);
            assertEq(
                blockDataEntropy.getCurrentSegmentIndex(),
                (i + 1) % 4,
                string.concat("Segment index should be ", vm.toString((i + 1) % 4), " after call #", vm.toString(i + 1))
            );
        }

        vm.stopPrank();
    }

    /// ========== Component Error Tracking ========
    /// ============================================

    function test_ComponentErrorTracking() public {
        // Use the proxy to test the error tracking mechanism

        // First, force a block hash error
        blockDataEntropy.forceGenerateZeroBlockHash(true);
        blockDataEntropy.forceSetLastProcessedBlock(0); // Force block hash update

        vm.prank(user);
        blockDataEntropy.getEntropy(123);

        // Check that the block hash error was tracked
        assertEq(blockDataEntropy.getBlockHashZeroHashCount(), 1, "Block hash zero count should be 1");

        // Reset the counters
        blockDataEntropy.resetFallbackCounters();

        // Now force a segment error
        blockDataEntropy.forceSetReturnZeroSegment(true);

        vm.prank(user);
        blockDataEntropy.getEntropy(456);

        // Check that the segment error was tracked
        assertEq(
            blockDataEntropy.getEntropyGenerationZeroSegmentCount(),
            2,
            "Entropy zero segment count should be 2 (cascading errors)"
        );

        // Verify total error count for entropy generation component (cascading errors)
        assertEq(
            blockDataEntropy.getComponentTotalErrorCount(3),
            2,
            "Total entropy generation errors should be 2 (cascading errors)"
        );

        // Check error counts instead of boolean function
        assertGt(blockDataEntropy.getComponentTotalErrorCount(3), 0, "Component should have errors");
        assertEq(blockDataEntropy.getComponentTotalErrorCount(2), 0, "Component should not have errors");
    }

    /// ============================================
    /// ============= View Functions ==============
    /// ============================================

    function test_ExtractAllSegments() public view {
        // Create a known hash to test with
        bytes32 testHash = keccak256(abi.encode("test"));

        // Extract all segments
        bytes8[4] memory segments = blockDataEntropy.extractAllSegments(testHash);

        // Verify segments are not zero
        for (uint256 i = 0; i < 4; i++) {
            assertTrue(segments[i] != bytes8(0), "Extracted segment should not be zero");
        }

        // Verify segments are different from each other
        assertTrue(segments[0] != segments[1], "Segments should be different from each other");
        assertTrue(segments[0] != segments[2], "Segments should be different from each other");
        assertTrue(segments[0] != segments[3], "Segments should be different from each other");
    }

    function test_ExtractAllSegments_ZeroHash() public view {
        // Test with zero hash
        bytes32 zeroHash = bytes32(0);

        // Extract all segments
        bytes8[4] memory segments = blockDataEntropy.extractAllSegments(zeroHash);

        // Verify all segments are non-zero (should use fallback)
        for (uint256 i = 0; i < 4; i++) {
            assertTrue(segments[i] != bytes8(0), "Segments from zero hash should still be non-zero");
        }
    }
}
