// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console, Vm} from "forge-std/Test.sol";
import {BlockDataEntropy} from "../src/implementations/BlockDataEntropy.sol";
import {BlockDataEntropyTestProxy} from "./mock/BlockDataEntropyTestProxy.sol";

/**
 * @title Block Data Entropy Safety Test
 * @notice Tests for safety mechanisms and fallback behaviors in BlockDataEntropy
 * @dev Focuses on boundary conditions, error handling, and recovery mechanisms using proxy
 */
contract BlockDataEntropySafetyTest is Test {
    BlockDataEntropy public blockDataEntropy;
    BlockDataEntropyTestProxy public proxy;

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
    uint8 internal constant ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS = 4;
    uint8 internal constant ERROR_SHIFT_OVERFLOW = 5;

    // Function names for error reporting
    string internal constant FUNC_GET_ENTROPY = "getEntropy";
    string internal constant FUNC_UPDATE_BLOCK_HASH = "updateBlockHash";
    string internal constant FUNC_EXTRACT_SEGMENT = "extractSegment";

    function setUp() public {
        // Setup addresses
        owner = makeAddr("owner");
        user = makeAddr("user");

        // Fund user for tests
        vm.deal(user, 100 ether);

        // Deploy contracts
        vm.prank(owner);
        blockDataEntropy = new BlockDataEntropy(owner);

        // Deploy proxy for testing internal functions and forced conditions
        vm.prank(owner);
        proxy = new BlockDataEntropyTestProxy(owner);
    }

    /// ============================================
    /// =========== Safety Fallback Tests ==========
    /// ============================================

    function test_SafetyFallbackEvent() public {
        // Reset proxy state
        proxy.resetState();

        // Record logs
        vm.recordLogs();

        // Force a safety fallback event
        proxy.forceEmitCustomFallback(FUNC_GET_ENTROPY, ERROR_ZERO_BLOCK_HASH);

        // Get the emitted logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Verify we have at least one log entry
        assertTrue(entries.length > 0, "Should have emitted at least one event");

        // The expected event signature
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );

        // Verify the event signature
        assertEq(entries[0].topics[0], expectedEventSignature, "Wrong event signature");

        // Verify error code
        assertEq(uint8(uint256(entries[0].topics[3])), ERROR_ZERO_BLOCK_HASH, "Wrong error code");

        // Decode and verify non-indexed parameters
        (, string memory functionName) = abi.decode(entries[0].data, (string, string));
        assertEq(functionName, FUNC_GET_ENTROPY, "Wrong function name in event");
    }

    /// ============================================
    /// ========= Zero-State Handling Tests ========
    /// ============================================

    function test_ZeroBlockHashHandling() public {
        // Reset proxy state
        proxy.resetState();

        // Force the current block hash to be zero and prevent updates
        proxy.forceSetCurrentBlockHash(bytes32(0));
        proxy.forceSetLastProcessedBlock(block.number); // Prevent block hash update

        // Record initial component error count
        uint256 initialErrorCount = proxy.getEntropyGenerationZeroHashCount();

        // Record logs
        vm.recordLogs();

        // Call getEntropy - should trigger zero block hash fallback
        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(123);

        // Entropy should still be non-zero
        assertTrue(entropy != bytes32(0), "Entropy should be non-zero even with zero block hash");

        // Verify component-specific error counter incremented
        assertEq(
            proxy.getEntropyGenerationZeroHashCount(),
            initialErrorCount + 1,
            "Component error counter should increment"
        );

        // Verify event emission
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundEvent = false;
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );

        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == expectedEventSignature &&
                entries[i].topics[3] == bytes32(uint256(ERROR_ZERO_BLOCK_HASH))) {
                foundEvent = true;
                break;
            }
        }

        assertTrue(foundEvent, "SafetyFallbackTriggered event should be emitted");
    }

    /// ============================================
    /// ========= Boundary Condition Tests =========
    /// ============================================

    function test_SegmentIndexOutOfBounds() public {
        // Reset proxy state
        proxy.resetState();

        // Force a valid block hash
        proxy.forceSetCurrentBlockHash(bytes32(uint256(1)));
        proxy.forceSetLastProcessedBlock(block.number); // Prevent block hash update

        // Force an out-of-bounds segment index
        uint256 outOfBoundsIndex = 5; // Greater than SEGMENT_COUNT (4)
        proxy.forceSetSegmentIndex(outOfBoundsIndex);

        // Record initial component error count
        uint256 initialErrorCount = proxy.getSegmentExtractionOutOfBoundsCount();

        // Record logs
        vm.recordLogs();

        // Call getEntropy - should handle the out-of-bounds index
        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(123);

        // Entropy should be non-zero
        assertTrue(entropy != bytes32(0), "Entropy should be non-zero with out-of-bounds segment index");

        // Segment index should be reset to 0 and then incremented to 1 by the cycle function
        assertEq(proxy.getCurrentSegmentIndex(), 1, "Segment index should be 1 after reset and cycle");

        // Verify component-specific error counter incremented
        assertEq(
            proxy.getSegmentExtractionOutOfBoundsCount(),
            initialErrorCount + 1,
            "Component error counter should increment"
        );
    }

    function test_ParanoidCheck_CycleSegmentIndex() public {
        // Reset proxy state
        proxy.resetState();

        // Set an out-of-bounds segment index
        proxy.forceSetSegmentIndex(100);

        // Call the cycle function directly using proxy
        proxy.exposedCycleSegmentIndex();

        // Segment index should be reset to 0
        assertEq(proxy.getCurrentSegmentIndex(), 0, "Segment index should be reset to 0");

        // Call again from a valid value to verify normal cycling
        proxy.forceSetSegmentIndex(0);
        proxy.exposedCycleSegmentIndex();
        assertEq(proxy.getCurrentSegmentIndex(), 1, "Segment index should be incremented to 1");
    }

    /// ============================================
    /// ============= Fallback Tests ==============
    /// ============================================

    function test_FallbackSegmentGeneration() public view {
        // Generate fallback segments for different indices using proxy
        bytes8 fallback0 = proxy.exposedGenerateFallbackSegment(0);
        bytes8 fallback1 = proxy.exposedGenerateFallbackSegment(1);
        bytes8 fallback2 = proxy.exposedGenerateFallbackSegment(2);
        bytes8 fallback3 = proxy.exposedGenerateFallbackSegment(3);

        // Fallbacks should be non-zero
        assertTrue(fallback0 != bytes8(0), "Fallback segment 0 should not be zero");
        assertTrue(fallback1 != bytes8(0), "Fallback segment 1 should not be zero");
        assertTrue(fallback2 != bytes8(0), "Fallback segment 2 should not be zero");
        assertTrue(fallback3 != bytes8(0), "Fallback segment 3 should not be zero");

        // Fallbacks should be different for different indices
        assertTrue(fallback0 != fallback1, "Fallback segments 0 and 1 should be different");
        assertTrue(fallback0 != fallback2, "Fallback segments 0 and 2 should be different");
        assertTrue(fallback0 != fallback3, "Fallback segments 0 and 3 should be different");
        assertTrue(fallback1 != fallback2, "Fallback segments 1 and 2 should be different");
        assertTrue(fallback1 != fallback3, "Fallback segments 1 and 3 should be different");
        assertTrue(fallback2 != fallback3, "Fallback segments 2 and 3 should be different");
    }

    function test_FallbackBlockHashGeneration() public view {
        // Generate fallback block hash using proxy
        bytes32 fallbackHash = proxy.exposedGenerateFallbackBlockHash();

        // Fallback hash should not be zero
        assertTrue(fallbackHash != bytes32(0), "Fallback block hash should not be zero");
    }

    function test_EmergencyEntropyGeneration() public {
        // Reset state
        proxy.resetState();

        // Generate emergency entropy using proxy
        bytes32 emergencyEntropy = proxy.exposedGenerateEmergencyEntropy(123);

        // Emergency entropy should not be zero
        assertTrue(emergencyEntropy != bytes32(0), "Emergency entropy should not be zero");

        // Generate another emergency entropy with different salt
        bytes32 emergencyEntropy2 = proxy.exposedGenerateEmergencyEntropy(456);

        // Should be different with different salt
        assertTrue(emergencyEntropy != emergencyEntropy2, "Emergency entropy should differ with different salt");
    }

    function test_MultipleSafetyFallbacks() public {
        // Reset state and counters using proxy
        proxy.resetState();
        proxy.resetFallbackCounters();

        // Force zero block hash condition using proxy
        proxy.forceSetCurrentBlockHash(bytes32(0));
        proxy.forceSetLastProcessedBlock(block.number); // Prevent hash update

        vm.startPrank(user);

        // Make multiple calls using proxy
        for (uint256 i = 0; i < 3; i++) {
            bytes32 entropy = proxy.getEntropy(i);
            assertTrue(entropy != bytes32(0), "Entropy should never be zero even with multiple fallbacks");
        }

        // Verify component error counts increased using proxy
        assertTrue(
            proxy.getComponentTotalErrorCount(COMPONENT_ENTROPY_GENERATION) > 0,
            "Component error counters should increase"
        );

        vm.stopPrank();
    }

    /// ============================================
    /// ======= Complex Fallback Scenarios =========
    /// ============================================

    function test_RecoveryFromFailure() public {
        // Reset state using proxy
        proxy.resetState();

        // Force failure - zero block hash using proxy
        proxy.forceSetCurrentBlockHash(bytes32(0));
        proxy.forceSetLastProcessedBlock(block.number); // Prevent hash update

        // Get entropy with failures active using proxy
        vm.prank(user);
        bytes32 entropyWithFailures = proxy.getEntropy(123);

        // Now restore normal operation by allowing block hash update using proxy
        proxy.forceSetLastProcessedBlock(0); // Allow block change detection
        vm.roll(block.number + 1); // Force new block

        // Get entropy again using proxy
        vm.prank(user);
        bytes32 entropyAfterRecovery = proxy.getEntropy(456);

        // Both should be non-zero
        assertTrue(entropyWithFailures != bytes32(0), "Entropy should be non-zero during failures");
        assertTrue(entropyAfterRecovery != bytes32(0), "Entropy should be non-zero after recovery");

        // Entropy values should be different
        assertTrue(entropyWithFailures != entropyAfterRecovery, "Entropy should differ before and after recovery");
    }

    /// ============================================
    /// ========= Additional Safety Tests ==========
    /// ============================================

    function test_ComponentErrorTracking() public {
        // Reset state and counters using proxy
        proxy.resetState();
        proxy.resetFallbackCounters();

        // Verify initial state using proxy
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_BLOCK_HASH), 0, "Initial block hash errors should be 0");
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_SEGMENT_EXTRACTION), 0, "Initial segment errors should be 0");
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_ENTROPY_GENERATION), 0, "Initial entropy errors should be 0");

        // Force some errors manually using proxy
        proxy.forceIncrementComponentErrorCount(COMPONENT_BLOCK_HASH, ERROR_ZERO_BLOCK_HASH);
        proxy.forceIncrementComponentErrorCount(COMPONENT_SEGMENT_EXTRACTION, ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS);
        proxy.forceIncrementComponentErrorCount(COMPONENT_ENTROPY_GENERATION, ERROR_ZERO_SEGMENT);

        // Verify counts using proxy
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_BLOCK_HASH), 1, "Block hash errors should be 1");
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_SEGMENT_EXTRACTION), 1, "Segment errors should be 1");
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_ENTROPY_GENERATION), 1, "Entropy errors should be 1");

        // Verify hasComponentErrors function using proxy
        assertTrue(proxy.hasComponentErrors(COMPONENT_BLOCK_HASH), "Block hash component should have errors");
        assertTrue(proxy.hasComponentErrors(COMPONENT_SEGMENT_EXTRACTION), "Segment component should have errors");
        assertTrue(proxy.hasComponentErrors(COMPONENT_ENTROPY_GENERATION), "Entropy component should have errors");
    }

    function test_ExtremeSegmentIndexValues() public {
        // Test with extreme segment index values using proxy
        proxy.resetState();

        // Test with maximum uint256 value
        proxy.forceSetSegmentIndex(type(uint256).max);
        proxy.exposedCycleSegmentIndex();
        assertEq(proxy.getCurrentSegmentIndex(), 0, "Max uint256 segment index should be reset to 0");

        // Test with very large value
        proxy.forceSetSegmentIndex(1000000);
        proxy.exposedCycleSegmentIndex();
        assertEq(proxy.getCurrentSegmentIndex(), 0, "Large segment index should be reset to 0");

        // Test boundary value (exactly SEGMENT_COUNT)
        proxy.forceSetSegmentIndex(4); // SEGMENT_COUNT = 4
        proxy.exposedCycleSegmentIndex();
        assertEq(proxy.getCurrentSegmentIndex(), 0, "Segment index equal to SEGMENT_COUNT should be reset to 0");
    }

    function test_ConsistentFallbackBehavior() public {
        // Test that fallback behavior is consistent across multiple calls using proxy
        proxy.resetState();
        proxy.resetFallbackCounters();

        // Force the same error condition multiple times
        proxy.forceSetCurrentBlockHash(bytes32(0));
        proxy.forceSetLastProcessedBlock(block.number);

        bytes32[] memory entropies = new bytes32[](5);

        vm.startPrank(user);
        for (uint256 i = 0; i < 5; i++) {
            entropies[i] = proxy.getEntropy(i + 100);
            assertTrue(entropies[i] != bytes32(0), "All fallback entropies should be non-zero");
        }
        vm.stopPrank();

        // Verify that error count incremented consistently
        assertEq(proxy.getEntropyGenerationZeroHashCount(), 5, "Error count should increment with each fallback");

        // Verify all entropy values are different (due to transaction counter and salt differences)
        for (uint256 i = 0; i < 5; i++) {
            for (uint256 j = i + 1; j < 5; j++) {
                assertTrue(entropies[i] != entropies[j],
                    string.concat("Fallback entropy ", vm.toString(i), " and ", vm.toString(j), " should be different"));
            }
        }
    }

    function test_CascadingFailureScenario() public {
        // Test multiple failure conditions simultaneously using proxy
        proxy.resetState();
        proxy.resetFallbackCounters();

        // Force multiple error conditions
        proxy.forceSetCurrentBlockHash(bytes32(0)); // Zero block hash
        proxy.forceSetSegmentIndex(999); // Out of bounds segment index
        proxy.forceSetLastProcessedBlock(block.number); // Prevent hash updates

        // Record logs for multiple fallback events
        vm.recordLogs();

        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(123);

        // Should still generate valid entropy
        assertTrue(entropy != bytes32(0), "Should generate valid entropy even with cascading failures");

        // Check that the zero hash error was handled (this takes precedence over segment issues)
        assertTrue(proxy.getEntropyGenerationZeroHashCount() > 0,
                  "Zero hash error should have been handled");

        // Since zero block hash triggers emergency entropy and bypasses segment extraction,
        // the segment index remains unchanged (this is correct safety behavior)
        assertEq(proxy.getCurrentSegmentIndex(), 999, "Segment index should remain unchanged when emergency entropy is used");

        // Verify events were emitted
        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertTrue(entries.length > 0, "Should have emitted fallback events for cascading failures");
    }

    /// @notice Test zero segment handling safety mechanism
    function test_ZeroSegmentHandling() public {
        // Reset proxy state
        proxy.resetState();
        // Force a non-zero block hash
        proxy.forceSetCurrentBlockHash(bytes32(uint256(1)));
        // Force a zero segment to be returned
        proxy.forceSetReturnZeroSegment(true);
        // Bypass block change check
        proxy.forceBypassBlockChangeCheck(true);

        // Record initial component error count
        uint256 initialErrorCount = proxy.getEntropyGenerationZeroSegmentCount();

        // Record logs
        vm.recordLogs();

        // Call getEntropy - should trigger zero segment fallback
        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(123);

        // Should still generate valid entropy via emergency fallback
        assertTrue(entropy != bytes32(0), "Should generate valid entropy even with zero segment");

        // Verify component error count incremented (cascading errors expected)
        assertEq(proxy.getEntropyGenerationZeroSegmentCount(), initialErrorCount + 2,
                 "Zero segment error count should increment by 2 (cascading errors)");

        // Verify event emission
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundEvent = false;
        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)")) {
                foundEvent = true;
                break;
            }
        }
        assertTrue(foundEvent, "SafetyFallbackTriggered event should be emitted");
    }

    /// @notice Test shift overflow handling safety mechanism
    function test_ShiftOverflowHandling() public {
        // Reset proxy state
        proxy.resetState();
        // Set a valid non-zero block hash so we don't trigger the zero hash fallback
        proxy.forceSetCurrentBlockHash(bytes32(uint256(1)));
        // Force shift overflow behavior
        proxy.forceShiftOverflow(true);
        // Bypass block change check
        proxy.forceBypassBlockChangeCheck(true);

        // Record initial component error count
        uint256 initialErrorCount = proxy.getSegmentExtractionShiftOverflowCount();

        // Record logs
        vm.recordLogs();

        // Call getEntropy - should handle shift overflow
        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(456);

        // Should generate valid entropy
        assertTrue(entropy != bytes32(0), "Should generate valid entropy despite shift overflow");

        // Verify component error count incremented
        assertEq(proxy.getSegmentExtractionShiftOverflowCount(), initialErrorCount + 1,
                 "Shift overflow error count should increment");

        // Verify event emission
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundEvent = false;
        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)")) {
                foundEvent = true;
                break;
            }
        }
        assertTrue(foundEvent, "SafetyFallbackTriggered event should be emitted for shift overflow");
    }

    /// @notice Test cascading fallbacks across multiple components
    function test_CascadingFallbacks() public {
        // Reset state
        proxy.resetState();
        // Force block hash to zero
        proxy.forceGenerateZeroBlockHash(true);
        // Force blockhash to return zero
        proxy.forceZeroBlockhash(true);

        // Record logs
        vm.recordLogs();

        // Force a new block to trigger hash update
        vm.roll(block.number + 1);
        proxy.forceSetLastProcessedBlock(0);

        // Execute
        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(123);

        // Should still generate entropy even with cascading failures
        assertTrue(entropy != bytes32(0), "Should generate entropy despite cascading failures");

        // Verify multiple component errors were handled
        assertTrue(proxy.getBlockHashZeroHashCount() > 0 ||
                  proxy.getBlockHashZeroBlockhashFallbackCount() > 0,
                  "Block hash component should have recorded errors");

        // Verify events were emitted for multiple failures
        Vm.Log[] memory entries = vm.getRecordedLogs();
        uint256 fallbackEventCount = 0;
        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)")) {
                fallbackEventCount++;
            }
        }
        assertTrue(fallbackEventCount > 0, "Should emit multiple fallback events for cascading failures");
    }
}