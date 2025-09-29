// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console, Vm} from "forge-std/Test.sol";
import {BlockDataEntropy} from "../src/implementations/BlockDataEntropy.sol";
import {BlockDataEntropyTestProxy} from "./mock/BlockDataEntropyTestProxy.sol";

/**
 * @title Block Data Entropy Segment Test
 * @notice Tests segment extraction mechanics in BlockDataEntropy
 * @dev Focuses on bit operations, segment extraction consistency, and edge cases
 */
contract BlockDataEntropySegmentTest is Test {
    BlockDataEntropyTestProxy public blockDataEntropy;

    // Common addresses
    address public owner;
    address public user;

    // Segment count for reuse in tests
    uint256 internal constant SEGMENT_COUNT = 4;
    uint256 internal constant BITS_PER_SEGMENT = 64;

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
    /// ========= Segment Extraction Tests =========
    /// ============================================

    function test_SegmentExtractionConsistency() public view {
        // Create a hash with a known pattern for verification
        bytes32 testHash = 0x1122334455667788990011223344556677889900112233445566778899001122;

        // Extract all segments using the public function
        bytes8[SEGMENT_COUNT] memory segments = blockDataEntropy.extractAllSegments(testHash);

        // Verify all segments are non-zero
        for (uint256 i = 0; i < SEGMENT_COUNT; i++) {
            assertTrue(segments[i] != bytes8(0), string.concat("Segment ", vm.toString(i), " should not be zero"));
        }

        // Verify segments are different from each other
        for (uint256 i = 0; i < SEGMENT_COUNT; i++) {
            for (uint256 j = i + 1; j < SEGMENT_COUNT; j++) {
                assertTrue(
                    segments[i] != segments[j],
                    string.concat("Segment ", vm.toString(i), " and ", vm.toString(j), " should be different")
                );
            }
        }
    }

    function test_SegmentBitShiftOperations() public view {
        // Create a hash with a known pattern for easier verification
        bytes32 testHash = 0x1111111111111111222222222222222233333333333333334444444444444444;

        // Extract segments using the public function
        bytes8[SEGMENT_COUNT] memory segments = blockDataEntropy.extractAllSegments(testHash);

        // The expected segments based on the bit shift operations
        bytes8 expected0 = bytes8(uint64(0x4444444444444444)); // No shift (rightmost 64 bits)
        bytes8 expected1 = bytes8(uint64(0x3333333333333333)); // Shift by 64 bits
        bytes8 expected2 = bytes8(uint64(0x2222222222222222)); // Shift by 128 bits
        bytes8 expected3 = bytes8(uint64(0x1111111111111111)); // Shift by 192 bits

        // Verify against expected values
        assertEq(segments[0], expected0, "Segment 0 should match expected value");
        assertEq(segments[1], expected1, "Segment 1 should match expected value");
        assertEq(segments[2], expected2, "Segment 2 should match expected value");
        assertEq(segments[3], expected3, "Segment 3 should match expected value");
    }

    function test_SegmentMaskingOperations() public view {
        // Test masking operation with specific hash pattern
        bytes32 testHash = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

        // Extract all segments
        bytes8[SEGMENT_COUNT] memory segments = blockDataEntropy.extractAllSegments(testHash);

        // Expected result is all bits set in each 64-bit segment
        bytes8 expected = bytes8(uint64(0xFFFFFFFFFFFFFFFF));

        // Verify masking worked correctly for all segments
        for (uint256 i = 0; i < SEGMENT_COUNT; i++) {
            assertEq(
                segments[i], expected, string.concat("Segment ", vm.toString(i), " should be all 1's for this hash")
            );
        }
    }

    function test_SegmentExtraction_EdgeCases() public view {
        // Generate a hash we can verify
        bytes32 generatedHash = keccak256(abi.encode("test_segments"));

        // Extract all segments
        bytes8[SEGMENT_COUNT] memory segments = blockDataEntropy.extractAllSegments(generatedHash);

        // Make sure each segment is part of the original hash
        // Extract each segment using bit operations
        uint256 hashVal = uint256(generatedHash);
        bytes8 expected0 = bytes8(uint64(hashVal & 0xFFFFFFFFFFFFFFFF));
        bytes8 expected1 = bytes8(uint64((hashVal >> 64) & 0xFFFFFFFFFFFFFFFF));
        bytes8 expected2 = bytes8(uint64((hashVal >> 128) & 0xFFFFFFFFFFFFFFFF));
        bytes8 expected3 = bytes8(uint64((hashVal >> 192) & 0xFFFFFFFFFFFFFFFF));

        // Verify segments match our expected values
        assertEq(segments[0], expected0, "Segment 0 should match extracted value");
        assertEq(segments[1], expected1, "Segment 1 should match extracted value");
        assertEq(segments[2], expected2, "Segment 2 should match extracted value");
        assertEq(segments[3], expected3, "Segment 3 should match extracted value");
    }

    function test_SegmentExtraction_DifferentHashes() public view {
        // Generate different hashes and check segment extraction
        bytes32 hash1 = keccak256(abi.encode("test1"));
        bytes32 hash2 = keccak256(abi.encode("test2"));

        // Extract segments from both hashes
        bytes8[SEGMENT_COUNT] memory segments1 = blockDataEntropy.extractAllSegments(hash1);
        bytes8[SEGMENT_COUNT] memory segments2 = blockDataEntropy.extractAllSegments(hash2);

        // Verify segments from different hashes are different
        for (uint256 i = 0; i < SEGMENT_COUNT; i++) {
            assertTrue(
                segments1[i] != segments2[i],
                string.concat("Segment ", vm.toString(i), " from different hashes should be different")
            );
        }
    }

    /// ============================================
    /// ========= Pattern Analysis Tests ===========
    /// ============================================

    function test_SegmentDistribution() public view {
        uint256 sampleSize = 10; // Reduced sample size for reasonable test execution time

        // Track total number of non-zero segments
        uint256[SEGMENT_COUNT] memory segmentNonZeroCount;
        uint256 totalNonZeroBytes = 0;

        for (uint256 i = 0; i < sampleSize; i++) {
            // Generate a unique hash for each sample
            bytes32 hash = keccak256(abi.encode("sample", i));

            // Extract segments
            bytes8[SEGMENT_COUNT] memory segments = blockDataEntropy.extractAllSegments(hash);

            // Analyze each segment
            for (uint256 segIdx = 0; segIdx < SEGMENT_COUNT; segIdx++) {
                bytes8 segment = segments[segIdx];

                // Convert to bytes for byte-by-byte analysis
                bytes memory segmentBytes = abi.encodePacked(segment);

                // Track non-zero bytes in each segment
                uint256 nonZeroBytes = 0;

                for (uint256 byteIdx = 0; byteIdx < 8; byteIdx++) {
                    if (uint8(segmentBytes[byteIdx]) != 0) {
                        nonZeroBytes++;
                        totalNonZeroBytes++;
                    }
                }

                // Track segments with at least one non-zero byte
                if (nonZeroBytes > 0) {
                    segmentNonZeroCount[segIdx]++;
                }
            }
        }

        // Basic validation that we have reasonable distribution
        uint256 totalSegmentsWithData =
            segmentNonZeroCount[0] + segmentNonZeroCount[1] + segmentNonZeroCount[2] + segmentNonZeroCount[3];

        // We expect most segments to have data for random hashes
        assertTrue(totalSegmentsWithData > sampleSize * 2, "Should have data in most segments");
        assertTrue(totalNonZeroBytes > sampleSize * 16, "Should have reasonable amount of non-zero bytes");
    }

    /// ============================================
    /// ======== Fallback Segment Tests ============
    /// ============================================

    function test_FallbackSegmentGeneration() public view {
        // Generate fallback segments for different indices using proxy
        bytes8 segment0 = blockDataEntropy.exposedGenerateFallbackSegment(0);
        bytes8 segment1 = blockDataEntropy.exposedGenerateFallbackSegment(1);
        bytes8 segment2 = blockDataEntropy.exposedGenerateFallbackSegment(2);
        bytes8 segment3 = blockDataEntropy.exposedGenerateFallbackSegment(3);

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

    /// ============================================
    /// ======== Integration Tests =================
    /// ============================================

    function test_SegmentExtractionInEntropyGeneration() public {
        // Reset proxy state and set up for clean test
        blockDataEntropy.resetState();

        // Set a valid block hash to avoid zero hash fallback
        blockDataEntropy.forceSetCurrentBlockHash(keccak256(abi.encode("test_block_hash")));
        blockDataEntropy.forceSetLastProcessedBlock(block.number); // Prevent hash updates

        // Set segment index to 0 for predictable testing
        blockDataEntropy.forceSetSegmentIndex(0);

        // Record logs
        vm.recordLogs();

        // Get entropy
        vm.prank(user);
        bytes32 entropy1 = blockDataEntropy.getEntropy(123);

        // Verify entropy was generated (should be non-zero)
        assertTrue(entropy1 != bytes32(0), "Entropy should be generated");

        // Check that segment index was updated
        assertEq(blockDataEntropy.getCurrentSegmentIndex(), 1, "Segment index should be incremented to 1");

        // Get entropy again with a different segment index
        vm.recordLogs();
        vm.prank(user);
        bytes32 entropy2 = blockDataEntropy.getEntropy(123);

        // Verify entropy values are different even with same salt
        assertTrue(entropy1 != entropy2, "Entropy should differ with different segment index");

        // Check segment index progression
        assertEq(blockDataEntropy.getCurrentSegmentIndex(), 2, "Segment index should be incremented to 2");
    }

    function test_SegmentCyclingThroughAllSegments() public {
        // Test that segments cycle correctly through all 4 positions
        vm.startPrank(user);

        // Get initial segment index
        uint256 initialSegmentIndex = blockDataEntropy.getCurrentSegmentIndex();

        // Store entropy values for each segment position
        bytes32[SEGMENT_COUNT] memory entropies;

        // Generate entropy at each segment position
        for (uint256 i = 0; i < SEGMENT_COUNT; i++) {
            entropies[i] = blockDataEntropy.getEntropy(100 + i); // Different salts

            // Verify segment index progression
            uint256 expectedIndex = (initialSegmentIndex + i + 1) % SEGMENT_COUNT;
            assertEq(
                blockDataEntropy.getCurrentSegmentIndex(),
                expectedIndex,
                string.concat(
                    "Segment index should be ", vm.toString(expectedIndex), " after call ", vm.toString(i + 1)
                )
            );
        }

        // Verify all entropy values are different (they should be due to different segments and salts)
        for (uint256 i = 0; i < SEGMENT_COUNT; i++) {
            for (uint256 j = i + 1; j < SEGMENT_COUNT; j++) {
                assertTrue(
                    entropies[i] != entropies[j],
                    string.concat(
                        "Entropy at segment ", vm.toString(i), " and ", vm.toString(j), " should be different"
                    )
                );
            }
        }

        vm.stopPrank();
    }

    function test_SegmentExtractionWithZeroHash() public view {
        // Test with zero hash - should use fallback
        bytes32 zeroHash = bytes32(0);

        // Extract all segments from zero hash
        bytes8[SEGMENT_COUNT] memory segments = blockDataEntropy.extractAllSegments(zeroHash);

        // All segments should be non-zero (using fallback)
        for (uint256 i = 0; i < SEGMENT_COUNT; i++) {
            assertTrue(
                segments[i] != bytes8(0),
                string.concat("Segment ", vm.toString(i), " should not be zero even with zero hash")
            );
        }
    }

    function test_SegmentConsistencyAcrossMultipleCalls() public view {
        // Test that same hash always produces same segments
        bytes32 testHash = keccak256(abi.encode("consistency_test"));

        // Extract segments multiple times
        bytes8[SEGMENT_COUNT] memory segments1 = blockDataEntropy.extractAllSegments(testHash);
        bytes8[SEGMENT_COUNT] memory segments2 = blockDataEntropy.extractAllSegments(testHash);
        bytes8[SEGMENT_COUNT] memory segments3 = blockDataEntropy.extractAllSegments(testHash);

        // Verify consistency across calls
        for (uint256 i = 0; i < SEGMENT_COUNT; i++) {
            assertEq(
                segments1[i],
                segments2[i],
                string.concat("Segment ", vm.toString(i), " should be consistent between calls 1 and 2")
            );
            assertEq(
                segments2[i],
                segments3[i],
                string.concat("Segment ", vm.toString(i), " should be consistent between calls 2 and 3")
            );
        }
    }

    /// ============================================
    /// ========= Boundary Value Tests =============
    /// ============================================

    function test_SegmentExtractionBoundaryValues() public view {
        // Test with minimum and maximum hash values
        bytes32 minHash = bytes32(uint256(1)); // Smallest non-zero value
        bytes32 maxHash = bytes32(type(uint256).max); // Maximum value

        // Extract segments from both boundary values
        bytes8[SEGMENT_COUNT] memory minSegments = blockDataEntropy.extractAllSegments(minHash);
        bytes8[SEGMENT_COUNT] memory maxSegments = blockDataEntropy.extractAllSegments(maxHash);

        // Verify min hash segments
        assertEq(minSegments[0], bytes8(uint64(1)), "Min hash segment 0 should be 1");
        for (uint256 i = 1; i < SEGMENT_COUNT; i++) {
            assertEq(minSegments[i], bytes8(0), string.concat("Min hash segment ", vm.toString(i), " should be 0"));
        }

        // Verify max hash segments (all should be max uint64)
        bytes8 expectedMax = bytes8(type(uint64).max);
        for (uint256 i = 0; i < SEGMENT_COUNT; i++) {
            assertEq(
                maxSegments[i], expectedMax, string.concat("Max hash segment ", vm.toString(i), " should be max uint64")
            );
        }
    }

    function test_SegmentExtractionWithRepeatingPatterns() public view {
        // Test with repeating bit patterns
        bytes32 repeatingHash = 0xAAAAAAAAAAAAAAAABBBBBBBBBBBBBBBBCCCCCCCCCCCCCCCCDDDDDDDDDDDDDDDD;

        bytes8[SEGMENT_COUNT] memory segments = blockDataEntropy.extractAllSegments(repeatingHash);

        // Expected segments based on the pattern
        bytes8 expected0 = bytes8(uint64(0xDDDDDDDDDDDDDDDD));
        bytes8 expected1 = bytes8(uint64(0xCCCCCCCCCCCCCCCC));
        bytes8 expected2 = bytes8(uint64(0xBBBBBBBBBBBBBBBB));
        bytes8 expected3 = bytes8(uint64(0xAAAAAAAAAAAAAAAA));

        assertEq(segments[0], expected0, "Repeating pattern segment 0 should match");
        assertEq(segments[1], expected1, "Repeating pattern segment 1 should match");
        assertEq(segments[2], expected2, "Repeating pattern segment 2 should match");
        assertEq(segments[3], expected3, "Repeating pattern segment 3 should match");
    }

    function test_SegmentUniquenessWithIncrementalHashes() public view {
        // Test segment extraction with incrementally different hashes
        uint256 totalComparisons = 0;
        uint256 differentSegments = 0;

        for (uint256 i = 0; i < 5; i++) {
            bytes32 hash1 = keccak256(abi.encode("incremental", i));
            bytes32 hash2 = keccak256(abi.encode("incremental", i + 1));

            bytes8[SEGMENT_COUNT] memory segments1 = blockDataEntropy.extractAllSegments(hash1);
            bytes8[SEGMENT_COUNT] memory segments2 = blockDataEntropy.extractAllSegments(hash2);

            // Count differences
            for (uint256 j = 0; j < SEGMENT_COUNT; j++) {
                totalComparisons++;
                if (segments1[j] != segments2[j]) {
                    differentSegments++;
                }
            }
        }

        // Most segments should be different for different hashes
        uint256 differencePercentage = (differentSegments * 100) / totalComparisons;
        assertTrue(differencePercentage > 70, "At least 70% of segments should differ between different hashes");
    }

    /// @notice Test first segment extraction function
    function test_ExtractFirstSegment() public {
        // Test the first segment extraction function
        bytes32 testHash = 0x1122334455667788990011223344556677889900112233445566778899001122;
        // Extract the first segment using helper function
        bytes8 firstSegment = blockDataEntropy.exposedExtractFirstSegment(testHash);
        // Verify it matches the expected value
        bytes8 expected = bytes8(uint64(0x5566778899001122));
        assertEq(firstSegment, expected, "First segment extraction should match expected value");
    }

    /// @notice Test segment extraction with out-of-bounds index
    function test_SegmentExtractionWithOutOfBoundsIndex() public {
        // Reset proxy state
        blockDataEntropy.resetState();
        // Set a valid block hash
        blockDataEntropy.forceSetCurrentBlockHash(bytes32(uint256(1)));
        // Set an out-of-bounds segment index
        uint256 outOfBoundsIndex = 100;

        // Record logs
        vm.recordLogs();

        // Try to extract a segment with out-of-bounds index
        bytes8 segment = blockDataEntropy.exposedExtractBlockHashSegment(bytes32(uint256(1)), outOfBoundsIndex);

        // Should return zero segment as fallback
        assertEq(segment, bytes8(0), "Out-of-bounds index should return zero segment");

        // Verify event was emitted for the error condition
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundEvent = false;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("SafetyFallbackTriggered(bytes32,bytes32,uint8,string,string)")) {
                foundEvent = true;
                break;
            }
        }
        assertTrue(foundEvent, "SafetyFallbackTriggered event should be emitted for out-of-bounds index");
    }

    function makeAddr(string memory name) internal pure override returns (address) {
        return vm.addr(uint256(keccak256(bytes(name))));
    }
}
