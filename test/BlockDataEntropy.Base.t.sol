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
        address user2 = makeAddr("user2");
        vm.deal(user2, 100 ether);

        uint256 salt = 123;

        // First user generates entropy
        vm.prank(user);
        bytes32 entropy1 = blockDataEntropy.getEntropy(salt);

        // Second user generates entropy with same salt
        vm.prank(user2);
        bytes32 entropy2 = blockDataEntropy.getEntropy(salt);

        // Entropy should be different due to different callers
        assertTrue(entropy1 != entropy2, "Entropy should be different with different callers");
    }

    /// ============================================
    /// ============= State Management Tests =======
    /// ============================================

    function test_TransactionCounterIncrement() public {
        vm.startPrank(user);

        for (uint256 i = 1; i <= 5; i++) {
            blockDataEntropy.getEntropy(i);
            assertEq(blockDataEntropy.getTransactionCounter(), i, "Transaction counter should increment correctly");
        }

        vm.stopPrank();
    }

    function test_SegmentIndexCycling() public {
        vm.startPrank(user);

        // Generate entropy 5 times to test cycling (should go 0->1->2->3->0)
        for (uint256 i = 0; i < 5; i++) {
            blockDataEntropy.getEntropy(i);
            uint256 expectedIndex = (i + 1) % 4;
            assertEq(blockDataEntropy.getCurrentSegmentIndex(), expectedIndex, "Segment index should cycle correctly");
        }

        vm.stopPrank();
    }

    function test_BlockHashUpdate() public {
        vm.startPrank(user);

        // Get initial block hash
        blockDataEntropy.getEntropy(123);
        bytes32 initialHash = blockDataEntropy.getCurrentBlockHash();
        uint256 initialBlock = blockDataEntropy.getLastProcessedBlock();

        // Mine a new block
        vm.roll(block.number + 1);

        // Generate entropy again - should update block hash
        blockDataEntropy.getEntropy(456);
        bytes32 newHash = blockDataEntropy.getCurrentBlockHash();
        uint256 newBlock = blockDataEntropy.getLastProcessedBlock();

        // Hash and block should be updated
        assertTrue(newHash != initialHash, "Block hash should update when block changes");
        assertTrue(newBlock > initialBlock, "Last processed block should update");

        vm.stopPrank();
    }

    /// ============================================
    /// ============= Events Tests ================
    /// ============================================

    function test_EntropyGeneratedEvent() public {
        vm.prank(user);

        // Expect entropy generated event
        vm.expectEmit(true, false, false, true);
        emit EntropyGenerated(user, 1, block.number); // Segment index will be 1 after first call

        blockDataEntropy.getEntropy(123);
    }

    function test_BlockHashGeneratedEvent() public {
        vm.prank(user);

        // Expect block hash generated event on first call
        vm.expectEmit(false, false, false, false);
        emit BlockHashGenerated(block.number, bytes32(0)); // We can't predict the hash

        blockDataEntropy.getEntropy(123);
    }

    /// ============================================
    /// ============= Edge Cases Tests ============
    /// ============================================

    function test_ZeroSaltEntropy() public {
        vm.prank(user);
        bytes32 entropy = blockDataEntropy.getEntropy(0);

        assertTrue(entropy != bytes32(0), "Entropy should not be zero even with zero salt");
    }

    function test_MaxUintSaltEntropy() public {
        vm.prank(user);
        bytes32 entropy = blockDataEntropy.getEntropy(type(uint256).max);

        assertTrue(entropy != bytes32(0), "Entropy should work with maximum uint256 salt");
    }

    function test_MultipleCallsSameBlock() public {
        vm.startPrank(user);

        bytes32[] memory entropies = new bytes32[](10);

        // Generate multiple entropy values in the same block
        for (uint256 i = 0; i < 10; i++) {
            entropies[i] = blockDataEntropy.getEntropy(i);
        }

        // All entropy values should be different
        for (uint256 i = 0; i < 10; i++) {
            for (uint256 j = i + 1; j < 10; j++) {
                assertTrue(entropies[i] != entropies[j], "All entropy values should be unique");
            }
        }

        vm.stopPrank();
    }

    /// ============================================
    /// ============= Helper Functions ============
    /// ============================================

    // Events for testing
    event EntropyGenerated(address indexed requester, uint256 segmentIndex, uint256 blockNumber);
    event BlockHashGenerated(uint256 indexed blockNumber, bytes32 hashValue);

    function makeAddr(string memory name) internal pure override returns (address) {
        return vm.addr(uint256(keccak256(bytes(name))));
    }
}