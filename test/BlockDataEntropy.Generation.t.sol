// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {BlockDataEntropy} from "../src/implementations/BlockDataEntropy.sol";
import {BlockDataEntropyTestProxy} from "./mock/BlockDataEntropyTestProxy.sol";
import {BlockEntropyEvents} from "../src/constants/BlockEntropyEvents.sol";

contract BlockDataEntropyGenerationTest is Test {
    // Use proxy for both entropy generation AND state inspection (same as address-entropy-engine pattern)
    BlockDataEntropyTestProxy public blockDataEntropy;

    // Event declarations for testing
    event BlockHashGenerated(uint256 indexed blockNumber, bytes32 hashValue);
    event EntropyGenerated(address indexed requester, uint256 segmentIndex, uint256 blockNumber);

    // Common addresses
    address public owner;
    address public user;

    // Component identifiers for fallback tracking
    uint8 internal constant COMPONENT_BLOCK_HASH = 1;
    uint8 internal constant COMPONENT_SEGMENT_EXTRACTION = 2;
    uint8 internal constant COMPONENT_ENTROPY_GENERATION = 3;

    // Error code constants for verification
    uint8 internal constant ERROR_ZERO_BLOCK_HASH = 1;
    uint8 internal constant ERROR_ZERO_BLOCKHASH_FALLBACK = 2;
    uint8 internal constant ERROR_ZERO_SEGMENT = 3;

    function setUp() public {
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
    /// =========== Entropy Generation Tests =======
    /// ============================================

    function test_EntropyAcrossBlocks() public {
        vm.startPrank(user);

        // Get entropy in the current block
        bytes32 entropy1 = blockDataEntropy.getEntropy(123);

        // Move to the next block
        vm.roll(block.number + 1);

        // Get entropy in the new block with same salt
        bytes32 entropy2 = blockDataEntropy.getEntropy(123);

        // Entropy should be different across blocks
        assertTrue(entropy1 != entropy2, "Entropy should be different across blocks");

        // Check that last processed block was updated
        assertEq(blockDataEntropy.getLastProcessedBlock(), block.number, "Last processed block should be updated");

        vm.stopPrank();
    }

    function test_BlockHashGeneration() public {
        vm.startPrank(user);

        // We'll use vm.expectEmit to check for the BlockHashGenerated event
        vm.expectEmit(true, false, false, false);
        emit BlockHashGenerated(block.number, bytes32(0)); // We don't know the hash value

        // Call getEntropy which should generate a new block hash
        blockDataEntropy.getEntropy(123);

        vm.stopPrank();
    }

    function test_EntropyGenerated() public {
        vm.startPrank(user);

        // We'll use vm.expectEmit to check for the EntropyGenerated event
        vm.expectEmit(true, false, false, false);
        emit EntropyGenerated(user, 0, block.number);

        // Call getEntropy which should emit EntropyGenerated
        blockDataEntropy.getEntropy(123);

        vm.stopPrank();
    }

    /// ============================================
    /// ======== Multiple Calls Tests =============
    /// ============================================

    function test_ManyEntropyCallsSameBlock() public {
        vm.startPrank(user);

        uint256 initialTxCounter = blockDataEntropy.getTransactionCounter();
        bytes32[] memory entropyValues = new bytes32[](10);

        // Generate 10 entropy values in the same block
        for (uint256 i = 0; i < 10; i++) {
            entropyValues[i] = blockDataEntropy.getEntropy(i + 1); // Use i+1 to avoid reusing salt 0
        }

        // Verify all values are different
        for (uint256 i = 0; i < 10; i++) {
            for (uint256 j = i + 1; j < 10; j++) {
                assertTrue(entropyValues[i] != entropyValues[j],
                    string.concat("Entropy values ", vm.toString(i), " and ", vm.toString(j), " should be different"));
            }
        }

        // Verify state
        assertEq(blockDataEntropy.getTransactionCounter(), initialTxCounter + 10, "Transaction counter should increment 10 times");
        assertEq(blockDataEntropy.getCurrentSegmentIndex(), 10 % 4, "Segment index should be correctly updated");

        vm.stopPrank();
    }

    function test_CompleteSegmentCycle() public {
        vm.startPrank(user);

        // Store entropy values for a complete cycle (4 calls)
        bytes32[4] memory cycleEntropy;

        // Initial segment index should be 0
        uint256 initialSegmentIndex = blockDataEntropy.getCurrentSegmentIndex();

        // Generate entropy for a complete cycle
        for (uint256 i = 0; i < 4; i++) {
            cycleEntropy[i] = blockDataEntropy.getEntropy(123);
            assertEq(blockDataEntropy.getCurrentSegmentIndex(), (initialSegmentIndex + i + 1) % 4,
                string.concat("Segment index after call ", vm.toString(i), " should be ", vm.toString((initialSegmentIndex + i + 1) % 4)));

            // Verify each segment was used by checking the block hash hasn't changed
            assertTrue(blockDataEntropy.getCurrentBlockHash() != bytes32(0), "Block hash should not be zero");
        }

        // After a complete cycle, segment index should be back to initial
        assertEq(blockDataEntropy.getCurrentSegmentIndex(), initialSegmentIndex, "Segment index should cycle back to initial");

        // Now generate entropy for a second cycle
        bytes32[4] memory secondCycleEntropy;
        for (uint256 i = 0; i < 4; i++) {
            secondCycleEntropy[i] = blockDataEntropy.getEntropy(123);
        }

        // Each entropy value in second cycle should be different from the first cycle
        // (Should be true since transaction counter increments)
        for (uint256 i = 0; i < 4; i++) {
            assertTrue(cycleEntropy[i] != secondCycleEntropy[i],
                string.concat("Entropy from different cycles at index ", vm.toString(i), " should be different"));
        }

        vm.stopPrank();
    }

    /// ============================================
    /// =========== Transaction Counting ==========
    /// ============================================

    function test_TransactionCounterIncrement() public {
        vm.startPrank(user);

        // Test increment through getEntropy function
        uint256 initialCount = blockDataEntropy.getTransactionCounter();
        blockDataEntropy.getEntropy(123);
        assertEq(blockDataEntropy.getTransactionCounter(), initialCount + 1, "getEntropy should increment counter exactly once");

        // Another call should increment again
        blockDataEntropy.getEntropy(456);
        assertEq(blockDataEntropy.getTransactionCounter(), initialCount + 2, "Second getEntropy should increment counter again");

        vm.stopPrank();
    }

    function test_TransactionCounterAcrossUsers() public {
        uint256 initialCount = blockDataEntropy.getTransactionCounter();

        // First user makes a call
        vm.prank(user);
        blockDataEntropy.getEntropy(123);
        assertEq(blockDataEntropy.getTransactionCounter(), initialCount + 1, "Transaction counter should increment after first user");

        // Second user makes a call
        address user2 = makeAddr("user2");
        vm.deal(user2, 1 ether);
        vm.prank(user2);
        blockDataEntropy.getEntropy(456);
        assertEq(blockDataEntropy.getTransactionCounter(), initialCount + 2, "Transaction counter should increment after second user");
    }

    /// ============================================
    /// ======== Multi-Block Tests ===============
    /// ============================================

    function test_EntropyAcrossManyBlocks() public {
        vm.startPrank(user);
        blockDataEntropy.resetState();

        bytes32[] memory entropyValues = new bytes32[](5);
        bytes32[] memory blockHashes = new bytes32[](5);

        // Generate entropy in 5 different blocks
        for (uint256 i = 0; i < 5; i++) {
            // Set block number and timestamp to create variation
            vm.roll(block.number + 10 + i); // Bigger jumps in block numbers
            vm.warp(block.timestamp + 100 + i * 50); // Add timestamp variation
            blockDataEntropy.forceSetLastProcessedBlock(0); // Force block change detection

            // Get entropy with same salt
            entropyValues[i] = blockDataEntropy.getEntropy(123);

            // Store block hash for verification
            blockHashes[i] = blockDataEntropy.getCurrentBlockHash();

            // Verify block processed is updated
            assertEq(blockDataEntropy.getLastProcessedBlock(), block.number, "Last processed block should match current block");
        }

        // Verify all values are different
        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = i + 1; j < 5; j++) {
                assertTrue(entropyValues[i] != entropyValues[j],
                    string.concat("Entropy in blocks ", vm.toString(i), " and ", vm.toString(j), " should be different"));
                assertTrue(blockHashes[i] != blockHashes[j],
                    string.concat("Block hashes ", vm.toString(i), " and ", vm.toString(j), " should be different"));
            }
        }

        vm.stopPrank();
    }

    /// ============================================
    /// ====== Block Hash Behavior Tests =======
    /// ============================================

    function test_BlockHashConsistencyAcrossBlocks() public {
        vm.startPrank(user);

        // Get entropy to generate initial block hash
        blockDataEntropy.getEntropy(123);
        bytes32 firstBlockHash = blockDataEntropy.getCurrentBlockHash();

        // Should not be zero
        assertTrue(firstBlockHash != bytes32(0), "Block hash should not be zero");

        // Change block number
        vm.roll(block.number + 1);

        // Get entropy again - should generate new block hash
        blockDataEntropy.getEntropy(123);
        bytes32 secondBlockHash = blockDataEntropy.getCurrentBlockHash();

        // Should be different with different block
        assertTrue(firstBlockHash != secondBlockHash, "Block hash should be different in different blocks");

        vm.stopPrank();
    }

    /// ============================================
    /// ======= Emergency Entropy Generation ======
    /// ============================================

    function test_EmergencyEntropyGeneration() public {
        vm.startPrank(user);
        blockDataEntropy.resetState();

        // Generate emergency entropy with same salt but different component error counts
        bytes32 entropy1 = blockDataEntropy.exposedGenerateEmergencyEntropy(123);

        // Increment some component error counters to change emergency entropy
        blockDataEntropy.forceIncrementComponentErrorCount(COMPONENT_BLOCK_HASH, ERROR_ZERO_BLOCK_HASH);
        blockDataEntropy.forceIncrementComponentErrorCount(COMPONENT_ENTROPY_GENERATION, ERROR_ZERO_SEGMENT);

        // Generate emergency entropy again
        bytes32 entropy2 = blockDataEntropy.exposedGenerateEmergencyEntropy(123);

        // Should be different due to component error counts
        assertTrue(entropy1 != entropy2, "Emergency entropy should change with component error counts");

        // Different salt with same error counts
        bytes32 entropy3 = blockDataEntropy.exposedGenerateEmergencyEntropy(456);

        // Should be different with different salt
        assertTrue(entropy2 != entropy3, "Emergency entropy should be different with different salt");

        vm.stopPrank();
    }

    /// ============================================
    /// ======= Component Error Integration =======
    /// ============================================

    function test_ComponentErrorsInEntropyGeneration() public {
        vm.startPrank(user);
        blockDataEntropy.resetState();

        // Setup to force component errors - set zero hash and prevent updates
        blockDataEntropy.forceSetCurrentBlockHash(bytes32(0)); // Will trigger ZERO_BLOCK_HASH error
        blockDataEntropy.forceSetLastProcessedBlock(block.number); // Prevent block hash update

        // Get initial component error counts
        uint256 initialErrorCount = blockDataEntropy.getEntropyGenerationZeroHashCount();

        // Call getEntropy
        bytes32 entropy = blockDataEntropy.getEntropy(123);

        // Verify entropy is valid
        assertTrue(entropy != bytes32(0), "Entropy should be non-zero even with errors");

        // Verify component error count incremented
        assertEq(
            blockDataEntropy.getEntropyGenerationZeroHashCount(),
            initialErrorCount + 1,
            "Component error counter should increment"
        );

        vm.stopPrank();
    }

    /// @notice Test block changes and hash caching behavior
    function test_BlockChangesAndCaching() public {
        // Using proxy for more control
        vm.startPrank(user);
        // Set initial state
        blockDataEntropy.resetState();
        // Get entropy to set initial block hash
        blockDataEntropy.getEntropy(123);
        uint256 firstProcessedBlock = blockDataEntropy.getLastProcessedBlock();
        bytes32 firstBlockHash = blockDataEntropy.getCurrentBlockHash();
        // Store segment and transaction counter
        uint256 firstSegmentIndex = blockDataEntropy.getCurrentSegmentIndex();
        uint256 firstTransactionCounter = blockDataEntropy.getTransactionCounter();

        // Force bypass of block change check to ensure we use cached hash
        blockDataEntropy.forceBypassBlockChangeCheck(true);

        // Call again in "same block" - should use cached hash
        blockDataEntropy.getEntropy(456);

        // Verify hash didn't change
        assertEq(blockDataEntropy.getCurrentBlockHash(), firstBlockHash, "Block hash should be cached and not change");
        assertEq(blockDataEntropy.getLastProcessedBlock(), firstProcessedBlock, "Processed block should not update when bypassed");

        // Verify segment index cycled and transaction counter incremented
        assertEq(blockDataEntropy.getCurrentSegmentIndex(), (firstSegmentIndex + 1) % 4, "Segment index should cycle");
        assertEq(blockDataEntropy.getTransactionCounter(), firstTransactionCounter + 1, "Transaction counter should increment");

        vm.stopPrank();
    }

    /// @notice Test direct block hash generation
    function test_DirectBlockHashGeneration() public {
        vm.startPrank(user);
        blockDataEntropy.resetState();

        // Generate a block hash directly
        bytes32 generatedHash = blockDataEntropy.exposedGenerateBlockHash();

        // Should not be zero
        assertTrue(generatedHash != bytes32(0), "Generated block hash should not be zero");

        // Should include all the expected components
        // We can't test exactly what's inside due to the hash, but we can verify consistency
        // Generate another with same block parameters
        bytes32 generatedHash2 = blockDataEntropy.exposedGenerateBlockHash();

        // Should be the same with same block parameters
        assertEq(generatedHash, generatedHash2, "Block hash generation should be deterministic within same block");

        // Change block number
        vm.roll(block.number + 1);

        // Generate hash with different block
        bytes32 generatedHash3 = blockDataEntropy.exposedGenerateBlockHash();

        // Should be different now
        assertTrue(generatedHash != generatedHash3, "Block hash should change with different block parameters");

        vm.stopPrank();
    }

    /// ============================================
    /// ========= Additional Generation Tests ======
    /// ============================================

    function test_EntropyVariationWithSameSalt() public {
        vm.startPrank(user);

        // Generate entropy multiple times with same salt
        bytes32 entropy1 = blockDataEntropy.getEntropy(123);
        bytes32 entropy2 = blockDataEntropy.getEntropy(123);
        bytes32 entropy3 = blockDataEntropy.getEntropy(123);

        // All should be different due to transaction counter and segment changes
        assertTrue(entropy1 != entropy2, "Entropy should vary even with same salt");
        assertTrue(entropy2 != entropy3, "Entropy should continue to vary");
        assertTrue(entropy1 != entropy3, "All entropy values should be unique");

        vm.stopPrank();
    }

    function test_EntropyWithDifferentSalts() public {
        vm.startPrank(user);

        // Generate entropy with different salts
        bytes32 entropy1 = blockDataEntropy.getEntropy(123);
        bytes32 entropy2 = blockDataEntropy.getEntropy(456);
        bytes32 entropy3 = blockDataEntropy.getEntropy(789);

        // All should be different
        assertTrue(entropy1 != entropy2, "Different salts should produce different entropy");
        assertTrue(entropy2 != entropy3, "Different salts should produce different entropy");
        assertTrue(entropy1 != entropy3, "Different salts should produce different entropy");

        vm.stopPrank();
    }

    function test_SegmentIndexProgression() public {
        vm.startPrank(user);

        // Track segment progression through multiple calls
        uint256 initialSegmentIndex = blockDataEntropy.getCurrentSegmentIndex();

        for (uint256 i = 0; i < 8; i++) { // Test 2 full cycles
            uint256 expectedIndex = (initialSegmentIndex + i + 1) % 4;
            blockDataEntropy.getEntropy(i);

            assertEq(
                blockDataEntropy.getCurrentSegmentIndex(),
                expectedIndex,
                string.concat("Segment index should progress correctly at step ", vm.toString(i))
            );
        }

        vm.stopPrank();
    }

    function test_BlockHashConsistencyWithinBlock() public {
        vm.startPrank(user);

        // Get initial block hash
        blockDataEntropy.getEntropy(123);
        bytes32 firstBlockHash = blockDataEntropy.getCurrentBlockHash();

        // Make several calls within same block
        for (uint256 i = 0; i < 5; i++) {
            blockDataEntropy.getEntropy(i + 200);
            assertEq(
                blockDataEntropy.getCurrentBlockHash(),
                firstBlockHash,
                "Block hash should remain consistent within same block"
            );
        }

        vm.stopPrank();
    }

    function test_TransactionCounterConsistency() public {
        vm.startPrank(user);

        uint256 initialCounter = blockDataEntropy.getTransactionCounter();

        // Make multiple calls and verify counter increments correctly
        for (uint256 i = 1; i <= 5; i++) {
            blockDataEntropy.getEntropy(i * 100);
            assertEq(
                blockDataEntropy.getTransactionCounter(),
                initialCounter + i,
                string.concat("Transaction counter should be ", vm.toString(initialCounter + i), " after ", vm.toString(i), " calls")
            );
        }

        vm.stopPrank();
    }

    function makeAddr(string memory name) internal pure override returns (address) {
        return vm.addr(uint256(keccak256(bytes(name))));
    }
}