// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console, Vm} from "forge-std/Test.sol";
import {BlockDataEntropy} from "../src/implementations/BlockDataEntropy.sol";
import {BlockDataEntropyTestProxy} from "./mock/BlockDataEntropyTestProxy.sol";

/**
 * @title Block Data Entropy Fallback Test
 * @notice Comprehensive tests for fallback mechanisms in BlockDataEntropy
 * @dev Tests error tracking and fallback scenarios that can be triggered
 */
contract BlockDataEntropyFallbackTest is Test {
    BlockDataEntropyTestProxy public proxy;

    // Common addresses
    address public owner;
    address public user;

    // Component identifiers for verification
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

    // Component name constants
    string internal constant COMPONENT_NAME_BLOCK_HASH = "BlockHash";
    string internal constant COMPONENT_NAME_SEGMENT_EXTRACTION = "SegmentExtraction";
    string internal constant COMPONENT_NAME_ENTROPY_GENERATION = "EntropyGeneration";

    // Setup for each test
    function setUp() public {
        // Setup addresses
        owner = makeAddr("owner");
        user = makeAddr("user");

        // Fund user for tests
        vm.deal(user, 100 ether);

        // Deploy proxy contract
        vm.prank(owner);
        proxy = new BlockDataEntropyTestProxy(owner);
    }

    /*//////////////////////////////////////////////////////////////
                     BASIC FALLBACK SCENARIO TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test zero block hash condition using state manipulation
    function test_ZeroBlockHashInGetEntropy() public {
        // Setup - force zero block hash condition and prevent block hash update
        proxy.resetState();
        proxy.forceSetCurrentBlockHash(bytes32(0));
        proxy.forceSetLastProcessedBlock(block.number); // Prevent hash update

        // Record initial error count
        uint256 initialErrorCount = proxy.getEntropyGenerationZeroHashCount();

        // Record logs
        vm.recordLogs();

        // Execute - this should trigger emergency entropy generation
        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(123);

        // Verify entropy is non-zero (emergency entropy should work)
        assertTrue(entropy != bytes32(0), "Emergency entropy should be non-zero");

        // Verify component-specific error counter incremented
        assertEq(
            proxy.getEntropyGenerationZeroHashCount(),
            initialErrorCount + 1,
            "Component-specific error counter should increment"
        );

        // Verify fallback event was emitted
        Vm.Log[] memory entries = vm.getRecordedLogs();
        verifyFallbackEvent(
            entries,
            COMPONENT_ENTROPY_GENERATION,
            FUNC_GET_ENTROPY,
            ERROR_ZERO_BLOCK_HASH
        );
    }

    /// @notice Test zero segment fallback path
    function test_ZeroSegmentInGetEntropy() public {
        // Setup - ensure we have a valid block hash but force zero segment
        proxy.resetState();
        proxy.forceSetCurrentBlockHash(bytes32(uint256(1))); // Non-zero hash
        proxy.forceSetReturnZeroSegment(true);

        // Record initial component error count
        uint256 initialErrorCount = proxy.getEntropyGenerationZeroSegmentCount();

        // Record logs
        vm.recordLogs();

        // Execute
        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(456);

        // Verify entropy is non-zero
        assertTrue(entropy != bytes32(0), "Emergency entropy should be non-zero");

        // Verify component-specific error counter incremented (cascading errors expected)
        assertEq(
            proxy.getEntropyGenerationZeroSegmentCount(),
            initialErrorCount + 2,
            "Component-specific error counter should increment by 2 (cascading errors)"
        );

        // Verify event emission using our helper
        Vm.Log[] memory entries = vm.getRecordedLogs();
        verifyFallbackEvent(
            entries,
            COMPONENT_ENTROPY_GENERATION,
            FUNC_GET_ENTROPY,
            ERROR_ZERO_SEGMENT
        );
    }

    /// @notice Test segment index out of bounds handling
    function test_SegmentIndexOutOfBounds() public {
        // Setup - force segment index to an out-of-bounds value
        proxy.resetState();
        uint256 outOfBoundsIndex = 99; // Much larger than segment count (4)
        proxy.forceSetSegmentIndex(outOfBoundsIndex);

        // Record initial error count
        uint256 initialErrorCount = proxy.getSegmentExtractionOutOfBoundsCount();

        // Record logs
        vm.recordLogs();

        // Execute
        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(123);

        // Verify entropy is non-zero
        assertTrue(entropy != bytes32(0), "Entropy should be non-zero");

        // Verify segment index was corrected and then cycled
        // Should be reset to 0 and then incremented to 1
        assertEq(proxy.getCurrentSegmentIndex(), 1, "Segment index should be 1 after reset and cycle");

        // Verify component-specific error counter incremented
        assertEq(
            proxy.getSegmentExtractionOutOfBoundsCount(),
            initialErrorCount + 1,
            "Component-specific error counter should increment"
        );

        // Verify event emission
        Vm.Log[] memory entries = vm.getRecordedLogs();
        verifyFallbackEvent(
            entries,
            COMPONENT_SEGMENT_EXTRACTION,
            FUNC_EXTRACT_SEGMENT,
            ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS
        );
    }

    /// @notice Test shift overflow handling
    function test_ShiftOverflow() public {
        // Setup - force shift overflow behavior
        proxy.resetState();
        proxy.forceShiftOverflow(true);

        // Record initial component error count
        uint256 initialErrorCount = proxy.getSegmentExtractionShiftOverflowCount();

        // Record logs
        vm.recordLogs();

        // Execute
        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(123);

        // Verify entropy is non-zero
        assertTrue(entropy != bytes32(0), "Entropy should be non-zero");

        // Verify component-specific error counter incremented
        assertEq(
            proxy.getSegmentExtractionShiftOverflowCount(),
            initialErrorCount + 1,
            "Component-specific error counter should increment"
        );

        // Verify event emission using our helper
        Vm.Log[] memory entries = vm.getRecordedLogs();
        verifyFallbackEvent(
            entries,
            COMPONENT_SEGMENT_EXTRACTION,
            FUNC_EXTRACT_SEGMENT,
            ERROR_SHIFT_OVERFLOW
        );
    }

    /// @notice Test the complex case of zero block hash + zero blockhash fallback
    function test_ZeroBlockHashAndZeroBlockhash() public {
        // Setup
        proxy.resetState();

        // Force _updateBlockHashIfNeeded to run by setting lastProcessedBlock to 0
        proxy.forceSetLastProcessedBlock(0);

        // Force _generateBlockHash to return zero
        proxy.forceGenerateZeroBlockHash(true);

        // advance the block number enough that blockhash returns 0 naturally
        // (blockhash returns 0 for blocks older than 256 blocks)
        vm.roll(block.number + 257);

        // Record initial component error counts
        uint256 initialZeroHashCount = proxy.getBlockHashZeroHashCount();
        uint256 initialZeroBlockhashCount = proxy.getBlockHashZeroBlockhashFallbackCount();

        // Record logs
        vm.recordLogs();

        // Execute
        vm.prank(user);
        bytes32 entropy = proxy.getEntropy(123);

        // Verify entropy is non-zero
        assertTrue(entropy != bytes32(0), "Final fallback entropy should be non-zero");

        // Component-specific error counters should be incremented
        assertTrue(
            proxy.getBlockHashZeroHashCount() > initialZeroHashCount ||
            proxy.getBlockHashZeroBlockhashFallbackCount() > initialZeroBlockhashCount,
            "At least one component-specific error counter should increment"
        );

        // Verify SafetyFallbackTriggered events were emitted
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // This test is more complex as we expect multiple events
        // We'll check that at least one event exists with the expected pattern
        bool foundUpdateBlockHashEvent = false;
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );
        bytes32 updateBlockHashFunction = keccak256(bytes(FUNC_UPDATE_BLOCK_HASH));

        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == expectedEventSignature &&
                entries[i].topics[2] == updateBlockHashFunction) {
                foundUpdateBlockHashEvent = true;
                break;
            }
        }

        assertTrue(foundUpdateBlockHashEvent, "updateBlockHash fallback event should be emitted");
    }

    /// @notice Test multiple fallback events in sequence
    function test_MultipleFallbackEvents() public {
        // Setup to force multiple fallbacks
        proxy.resetState();
        proxy.forceGenerateZeroBlockHash(true);

        // Record logs
        vm.recordLogs();

        // Execute
        vm.prank(user);
        proxy.getEntropy(123);

        // Get the logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Count fallback events
        uint fallbackEventCount = 0;
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );

        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == expectedEventSignature) {
                fallbackEventCount++;
            }
        }

        // Verify we have at least one fallback event
        assertTrue(fallbackEventCount > 0, "At least one fallback event should be emitted");
    }

    /*//////////////////////////////////////////////////////////////
                      FALLBACK UTILITY FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test fallback segment generation consistency
    function test_FallbackSegmentGeneration() public view {
        // Generate fallback segments for different indices
        bytes8 segment0 = proxy.exposedGenerateFallbackSegment(0);
        bytes8 segment1 = proxy.exposedGenerateFallbackSegment(1);
        bytes8 segment2 = proxy.exposedGenerateFallbackSegment(2);
        bytes8 segment3 = proxy.exposedGenerateFallbackSegment(3);

        // Verify all segments are non-zero
        assertTrue(segment0 != bytes8(0), "Fallback segment 0 should not be zero");
        assertTrue(segment1 != bytes8(0), "Fallback segment 1 should not be zero");
        assertTrue(segment2 != bytes8(0), "Fallback segment 2 should not be zero");
        assertTrue(segment3 != bytes8(0), "Fallback segment 3 should not be zero");

        // Verify segments are different from each other
        assertTrue(segment0 != segment1, "Fallback segments 0 and 1 should be different");
        assertTrue(segment0 != segment2, "Fallback segments 0 and 2 should be different");
        assertTrue(segment0 != segment3, "Fallback segments 0 and 3 should be different");
        assertTrue(segment1 != segment2, "Fallback segments 1 and 2 should be different");
        assertTrue(segment1 != segment3, "Fallback segments 1 and 3 should be different");
        assertTrue(segment2 != segment3, "Fallback segments 2 and 3 should be different");
    }

    /// @notice Test emergency entropy generation
    function test_EmergencyEntropyGeneration() public {
        // Setup
        proxy.resetState();

        // Record initial transaction counter
        uint256 initialTxCounter = proxy.getTransactionCounter();

        // Generate emergency entropy with different salt values
        bytes32 entropy1 = proxy.exposedGenerateEmergencyEntropy(123);
        bytes32 entropy2 = proxy.exposedGenerateEmergencyEntropy(456);

        // Verify entropy values are non-zero
        assertTrue(entropy1 != bytes32(0), "Emergency entropy 1 should not be zero");
        assertTrue(entropy2 != bytes32(0), "Emergency entropy 2 should not be zero");

        // Verify entropy values are different from each other
        assertTrue(entropy1 != entropy2, "Different salt values should produce different entropy");

        // Transaction counter should not change with exposed function
        assertEq(
            proxy.getTransactionCounter(),
            initialTxCounter,
            "Transaction counter should not change with exposed function"
        );
    }

    /// @notice Test fallback block hash generation
    function test_FallbackBlockHashGeneration() public view {
        // Generate fallback block hash
        bytes32 fallbackHash = proxy.exposedGenerateFallbackBlockHash();

        // Verify hash is non-zero
        assertTrue(fallbackHash != bytes32(0), "Fallback block hash should not be zero");
    }

    /*//////////////////////////////////////////////////////////////
                      COMPONENT ERROR TRACKING TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test component-specific error counting
    function test_ComponentSpecificErrorCounting() public {
        // Setup
        proxy.resetState();

        // Verify initial state
        assertEq(proxy.getComponentErrorCount(COMPONENT_BLOCK_HASH, ERROR_ZERO_BLOCK_HASH), 0, "Initial count should be 0");
        assertEq(proxy.getComponentErrorCount(COMPONENT_SEGMENT_EXTRACTION, ERROR_SHIFT_OVERFLOW), 0, "Initial count should be 0");
        assertEq(proxy.getComponentErrorCount(COMPONENT_ENTROPY_GENERATION, ERROR_ZERO_SEGMENT), 0, "Initial count should be 0");

        // Force specific component error increments
        proxy.forceIncrementComponentErrorCount(COMPONENT_BLOCK_HASH, ERROR_ZERO_BLOCK_HASH);
        proxy.forceIncrementComponentErrorCount(COMPONENT_BLOCK_HASH, ERROR_ZERO_BLOCK_HASH);
        proxy.forceIncrementComponentErrorCount(COMPONENT_SEGMENT_EXTRACTION, ERROR_SHIFT_OVERFLOW);
        proxy.forceIncrementComponentErrorCount(COMPONENT_ENTROPY_GENERATION, ERROR_ZERO_SEGMENT);

        // Verify counts
        assertEq(proxy.getComponentErrorCount(COMPONENT_BLOCK_HASH, ERROR_ZERO_BLOCK_HASH), 2, "Count should be 2");
        assertEq(proxy.getComponentErrorCount(COMPONENT_SEGMENT_EXTRACTION, ERROR_SHIFT_OVERFLOW), 1, "Count should be 1");
        assertEq(proxy.getComponentErrorCount(COMPONENT_ENTROPY_GENERATION, ERROR_ZERO_SEGMENT), 1, "Count should be 1");

        // Verify total component errors
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_BLOCK_HASH), 2, "Total block hash errors should be 2");
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_SEGMENT_EXTRACTION), 1, "Total segment extraction errors should be 1");
        assertEq(proxy.getComponentTotalErrorCount(COMPONENT_ENTROPY_GENERATION), 1, "Total entropy generation errors should be 1");

        // Verify hasComponentErrors function
        assertTrue(proxy.hasComponentErrors(COMPONENT_BLOCK_HASH), "Block hash component should have errors");
        assertTrue(proxy.hasComponentErrors(COMPONENT_SEGMENT_EXTRACTION), "Segment extraction component should have errors");
        assertTrue(proxy.hasComponentErrors(COMPONENT_ENTROPY_GENERATION), "Entropy generation component should have errors");

        // Reset fallback counters
        proxy.resetFallbackCounters();

        // Verify all counts are reset
        assertEq(proxy.getComponentErrorCount(COMPONENT_BLOCK_HASH, ERROR_ZERO_BLOCK_HASH), 0, "Count should be reset to 0");
        assertEq(proxy.getComponentErrorCount(COMPONENT_SEGMENT_EXTRACTION, ERROR_SHIFT_OVERFLOW), 0, "Count should be reset to 0");
        assertEq(proxy.getComponentErrorCount(COMPONENT_ENTROPY_GENERATION, ERROR_ZERO_SEGMENT), 0, "Count should be reset to 0");
    }

    /*//////////////////////////////////////////////////////////////
                      FALLBACK EVENT TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test the details of fallback events
    function test_FallbackEventDetails() public {
        // Setup
        proxy.resetState();

        // Record logs
        vm.recordLogs();

        // Generate custom fallback events with different error codes
        proxy.forceEmitCustomFallback(FUNC_GET_ENTROPY, ERROR_ZERO_BLOCK_HASH);
        proxy.forceEmitCustomFallback(FUNC_UPDATE_BLOCK_HASH, ERROR_ZERO_BLOCKHASH_FALLBACK);
        proxy.forceEmitCustomFallback(FUNC_EXTRACT_SEGMENT, ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS);

        // Get logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Map to track which error codes we've found
        bool[6] memory foundErrorCodes; // Index 0 unused, codes are 1-5

        // Verify each event
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );

        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == expectedEventSignature) {
                uint8 errorCode = uint8(uint256(entries[i].topics[3]));
                if (errorCode > 0 && errorCode <= 5) {
                    foundErrorCodes[errorCode] = true;
                }
            }
        }

        // Verify we found all the error codes we emitted
        assertTrue(foundErrorCodes[ERROR_ZERO_BLOCK_HASH], "ERROR_ZERO_BLOCK_HASH event should be found");
        assertTrue(foundErrorCodes[ERROR_ZERO_BLOCKHASH_FALLBACK], "ERROR_ZERO_BLOCKHASH_FALLBACK event should be found");
        assertTrue(foundErrorCodes[ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS], "ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS event should be found");
    }

    /// @notice Test indexed event format
    function test_IndexedEventFormat() public {
        // Setup
        proxy.resetState();

        // Record logs
        vm.recordLogs();

        // Emit a specific event
        proxy.forceEmitCustomFallback("testFunction", ERROR_ZERO_SEGMENT);

        // Verify using our helper
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // The componentId will be determined by the forceEmitCustomFallback function
        // which assigns COMPONENT_ENTROPY_GENERATION for unknown function names
        verifyFallbackEvent(
            entries,
            COMPONENT_ENTROPY_GENERATION,
            "testFunction",
            ERROR_ZERO_SEGMENT
        );
    }

    /// @notice Test paranoid check in cycle segment index
    function test_ParanoidCheckInCycleSegment() public {
        // Get the segment count constant (4)
        uint256 segmentCount = 4;

        // Setup - set segment index to trigger the paranoid check
        proxy.resetState();
        proxy.forceSetSegmentIndex(segmentCount); // Equal to SEGMENT_COUNT

        // Execute the cycle function directly
        proxy.exposedCycleSegmentIndex();

        // Verify segment index was reset to 0 by the paranoid check
        assertEq(proxy.getCurrentSegmentIndex(), 0, "Segment index should be reset to 0 by paranoid check");
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Helper to verify fallback events with correct parameters
    /// @param logs Array of logs to search for events
    /// @param componentId Expected component ID in the event
    /// @param expectedFunction Expected function name in the event
    /// @param expectedErrorCode Expected error code in the event
    function verifyFallbackEvent(
        Vm.Log[] memory logs,
        uint8 componentId,
        string memory expectedFunction,
        uint8 expectedErrorCode
    ) internal view {
        bool foundEvent = false;
        bytes32 expectedEventSignature = keccak256(
            "SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)"
        );

        // Get the expected component name based on component ID
        string memory expectedComponentName = proxy.exposedGetComponentName(componentId);
        bytes32 expectedComponentHash = keccak256(bytes(expectedComponentName));
        bytes32 expectedFunctionHash = keccak256(bytes(expectedFunction));

        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == expectedEventSignature) {
                // Check if this event matches our expected parameters
                if (logs[i].topics[3] == bytes32(uint256(expectedErrorCode))) {
                    foundEvent = true;

                    // Verify indexed parameters
                    assertEq(logs[i].topics[1], expectedComponentHash, "Component hash should match");
                    assertEq(logs[i].topics[2], expectedFunctionHash, "Function hash should match");
                    assertEq(uint8(uint256(logs[i].topics[3])), expectedErrorCode, "Error code should match");

                    // Decode and verify non-indexed parameters
                    (string memory component, string memory functionName) = abi.decode(logs[i].data, (string, string));
                    assertEq(component, expectedComponentName, "Component name should match");
                    assertEq(functionName, expectedFunction, "Function name should match");

                    break;
                }
            }
        }

        assertTrue(foundEvent, "SafetyFallbackTriggered event should be emitted with expected parameters");
    }

    function makeAddr(string memory name) internal pure override returns (address) {
        return vm.addr(uint256(keccak256(bytes(name))));
    }
}