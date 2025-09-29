// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BlockDataEntropy} from "../../src/implementations/BlockDataEntropy.sol";
import {BlockEntropyConstants} from "../../src/constants/BlockEntropyConstants.sol";
import {BlockFallbackLibrary} from "../../src/libraries/BlockFallbackLibrary.sol";
import {BlockProcessingLibrary} from "../../src/libraries/BlockProcessingLibrary.sol";
import {BlockValidationLibrary} from "../../src/libraries/BlockValidationLibrary.sol";

/**
 * @title BlockDataEntropyTestProxy
 * @notice Test-only proxy providing state inspection capabilities for BlockDataEntropy
 * @dev Extends production contract with security-sensitive functions for comprehensive testing
 *      Enables full system validation without compromising production security
 * @author ATrnd
 */
contract BlockDataEntropyTestProxy is BlockDataEntropy {
    /*//////////////////////////////////////////////////////////////
                           TESTING STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Flag to force zero block hash generation
    bool private forceZeroBlockHash;

    /// @notice Flag to force zero segment return
    bool private forceZeroSegment;

    /// @notice Flag to bypass block change check
    bool private bypassBlockChangeCheck;

    /// @notice Flag to force shift overflow
    bool private forceShiftOverflowEnabled;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address _initialOwner) BlockDataEntropy(_initialOwner) {
        // All functionality inherited from production contract
    }

    /*//////////////////////////////////////////////////////////////
                         TESTING CONTROL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Reset state for testing
    function resetState() external {
        s_currentSegmentIndex = 0;
        s_transactionCounter = 0;
        s_lastProcessedBlock = 0;
        s_currentBlockHash = bytes32(0);
    }

    /*//////////////////////////////////////////////////////////////
                         STATE MANIPULATION METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Force set the current block hash for testing
    /// @param hash The hash to set
    function forceSetCurrentBlockHash(bytes32 hash) external {
        s_currentBlockHash = hash;
    }

    /// @notice Force set the last processed block for testing
    /// @param blockNumber The block number to set
    function forceSetLastProcessedBlock(uint256 blockNumber) external {
        s_lastProcessedBlock = blockNumber;
    }

    /// @notice Force set the current segment index for testing
    /// @param index The segment index to set
    function forceSetSegmentIndex(uint256 index) external {
        s_currentSegmentIndex = index;
    }

    /// @notice Force increment a component error count for testing
    /// @param componentId The component ID
    /// @param errorCode The error code
    function forceIncrementComponentErrorCount(uint8 componentId, uint8 errorCode) external {
        _incrementComponentErrorCount(componentId, errorCode);
    }

    /// @notice Reset all fallback counters for testing
    function resetFallbackCounters() external {
        // Reset all component error counts (now includes component 4 for access control)
        for (uint8 componentId = 1; componentId <= 4; componentId++) {
            for (uint8 errorCode = 1; errorCode <= 9; errorCode++) {
                s_componentErrorCounts[componentId][errorCode] = 0;
            }
        }
    }

    /// @notice Force zero block hash generation for testing (alias for consistency)
    /// @param force Whether to force zero block hash
    function forceGenerateZeroBlockHash(bool force) external {
        forceZeroBlockHash = force;
    }

    /// @notice Force zero segment extraction for testing (alias for consistency)
    /// @param force Whether to force zero segment
    function forceSetReturnZeroSegment(bool force) external {
        forceZeroSegment = force;
    }

    /// @notice Force shift overflow for testing
    /// @param force Whether to force shift overflow
    function forceShiftOverflow(bool force) external {
        forceShiftOverflowEnabled = force;
    }

    /// @notice Force bypass block change check for testing
    /// @param bypass Whether to bypass block change checks
    function forceBypassBlockChangeCheck(bool bypass) external {
        bypassBlockChangeCheck = bypass;
    }

    /*//////////////////////////////////////////////////////////////
                         EXPOSED INTERNAL METHODS
    //////////////////////////////////////////////////////////////*/

    /// @notice Exposed version of _cycleSegmentIndex for testing
    function exposedCycleSegmentIndex() external {
        _cycleSegmentIndex();
    }

    /// @notice Exposed version of _generateEmergencyEntropy for testing
    /// @param salt Salt value for entropy generation
    /// @return Emergency entropy bytes32
    function exposedGenerateEmergencyEntropy(uint256 salt) external view returns (bytes32) {
        return _generateEmergencyEntropy(salt, s_transactionCounter);
    }

    /// @notice Expose _generateBlockHash for testing
    /// @return The generated block hash
    function exposedGenerateBlockHash() external view returns (bytes32) {
        if (forceZeroBlockHash) {
            return bytes32(0);
        }
        return _generateBlockHash();
    }

    /// @notice Exposed version of getComponentName for testing
    /// @param componentId The component ID
    /// @return Component name string
    function exposedGetComponentName(uint8 componentId) external pure returns (string memory) {
        return BlockFallbackLibrary.getComponentName(componentId);
    }

    /// @notice Generate a fallback segment for testing
    /// @param segmentIndex The segment index
    /// @return Fallback segment as bytes8
    function exposedGenerateFallbackSegment(uint256 segmentIndex) external view returns (bytes8) {
        return bytes8(keccak256(abi.encode(block.timestamp, segmentIndex)));
    }

    /// @notice Generate a fallback block hash for testing
    /// @return Fallback block hash
    function exposedGenerateFallbackBlockHash() external view returns (bytes32) {
        return keccak256(abi.encode(block.timestamp, block.number, s_transactionCounter));
    }

    /// @notice Force emit a custom fallback event for testing
    /// @param functionName Function name for the event
    /// @param errorCode Error code for the event
    function forceEmitCustomFallback(string memory functionName, uint8 errorCode) external {
        // Determine component ID based on function name
        uint8 componentId = BlockEntropyConstants.COMPONENT_ENTROPY_GENERATION; // Default
        if (keccak256(bytes(functionName)) == keccak256(bytes("updateBlockHash"))) {
            componentId = BlockEntropyConstants.COMPONENT_BLOCK_HASH;
        } else if (keccak256(bytes(functionName)) == keccak256(bytes("extractSegment"))) {
            componentId = BlockEntropyConstants.COMPONENT_SEGMENT_EXTRACTION;
        }

        _handleFallback(componentId, functionName, errorCode);
    }

    /// @notice Expose _extractFirstSegment for testing
    /// @param blockHash The block hash to extract from
    /// @return The first segment (segment 0)
    function exposedExtractFirstSegment(bytes32 blockHash) external returns (bytes8) {
        return _extractBlockHashSegment(blockHash, 0);
    }

    /// @notice Expose _extractBlockHashSegment for testing with bounds checking
    /// @param blockHash The block hash to extract from
    /// @param segmentIndex The segment index
    /// @return The extracted segment
    function exposedExtractBlockHashSegment(bytes32 blockHash, uint256 segmentIndex) external returns (bytes8) {
        if (segmentIndex >= BlockEntropyConstants.SEGMENT_COUNT) {
            // Trigger out-of-bounds error
            _handleFallback(
                BlockEntropyConstants.COMPONENT_SEGMENT_EXTRACTION,
                "extractSegment",
                BlockEntropyConstants.ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS
            );
            return bytes8(0);
        }
        return _extractBlockHashSegment(blockHash, segmentIndex);
    }

    /// @notice Force blockhash() to return zero for testing
    /// @param force Whether to force zero blockhash
    function forceZeroBlockhash(bool force) external {
        // This would need to be implemented in base contract to override blockhash calls
        // For now, this is a placeholder that sets a flag
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL METHOD OVERRIDES
    //////////////////////////////////////////////////////////////*/

    /// @notice Override _generateBlockHash to support forcing zero hash
    function _generateBlockHash() internal view override returns (bytes32) {
        if (forceZeroBlockHash) {
            return bytes32(0);
        }
        return super._generateBlockHash();
    }

    /// @notice Override _extractBlockHashSegment to support forced behaviors
    function _extractBlockHashSegment(bytes32 blockHash, uint256 segmentIndex) internal override returns (bytes8) {
        // Force shift overflow behavior
        if (forceShiftOverflowEnabled) {
            _handleFallback(
                BlockEntropyConstants.COMPONENT_SEGMENT_EXTRACTION,
                "extractSegment",
                BlockEntropyConstants.ERROR_SHIFT_OVERFLOW
            );
            // Return a fallback segment
            return bytes8(keccak256(abi.encode(block.timestamp, segmentIndex)));
        }

        // Call parent implementation
        bytes8 segment = super._extractBlockHashSegment(blockHash, segmentIndex);

        // Force zero segment behavior
        if (forceZeroSegment) {
            _handleFallback(
                BlockEntropyConstants.COMPONENT_ENTROPY_GENERATION,
                "getEntropy",
                BlockEntropyConstants.ERROR_ZERO_SEGMENT
            );
            return bytes8(0);
        }

        return segment;
    }

    /// @notice Override getEntropy to support bypassing block change check
    function getEntropy(uint256 salt) external override returns (bytes32) {
        // If bypassing block change check, skip the update
        if (!bypassBlockChangeCheck) {
            _updateBlockHashIfNeeded();
        }

        // Increment transaction counter
        uint256 currentTx = _incrementTransactionCounter();

        // Get current hash (may be stale if bypassed)
        if (s_currentBlockHash == bytes32(0)) {
            // Handle fallback with specific component ID
            _handleFallback(
                BlockEntropyConstants.COMPONENT_ENTROPY_GENERATION,
                "getEntropy",
                BlockEntropyConstants.ERROR_ZERO_BLOCK_HASH
            );

            // Generate emergency entropy
            return _generateEmergencyEntropy(salt, currentTx);
        }

        // Extract the current segment of the block hash
        bytes8 currentSegment = _extractBlockHashSegment(s_currentBlockHash, s_currentSegmentIndex);

        // Validate the extracted segment
        if (currentSegment == bytes8(0)) {
            // Handle fallback with specific component ID
            _handleFallback(
                BlockEntropyConstants.COMPONENT_ENTROPY_GENERATION,
                "getEntropy",
                BlockEntropyConstants.ERROR_ZERO_SEGMENT
            );

            // Generate emergency entropy
            return _generateEmergencyEntropy(salt, currentTx);
        }

        // Cycle to next segment index
        _cycleSegmentIndex();

        // Generate entropy using current segment and transaction data
        bytes32 entropy = keccak256(
            abi.encode(
                currentSegment, s_currentSegmentIndex, block.timestamp, block.number, msg.sender, salt, currentTx
            )
        );

        // Emit event for successful entropy generation
        emit EntropyGenerated(msg.sender, s_currentSegmentIndex, block.number);

        return entropy;
    }

    /*//////////////////////////////////////////////////////////////
                    TEST-ONLY STATE INSPECTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice TEST ONLY - Gets the last processed block number
    /// @dev SECURITY REMOVED from production - only available in test proxy
    /// @return The block number when the current hash was generated
    function getLastProcessedBlock() external view returns (uint256) {
        return s_lastProcessedBlock;
    }

    /// @notice TEST ONLY - Gets the current segment index
    /// @dev SECURITY REMOVED from production - only available in test proxy
    /// @return The current segment index in the cycle
    function getCurrentSegmentIndex() external view returns (uint256) {
        return s_currentSegmentIndex;
    }

    /// @notice TEST ONLY - Gets the transaction counter
    /// @dev SECURITY REMOVED from production - only available in test proxy
    /// @return The total number of entropy requests processed
    function getTransactionCounter() external view returns (uint256) {
        return s_transactionCounter;
    }

    /// @notice TEST ONLY - Gets the current block hash
    /// @dev SECURITY REMOVED from production - only available in test proxy
    /// @return The current block hash being used for entropy
    function getCurrentBlockHash() external view returns (bytes32) {
        return s_currentBlockHash;
    }

    /// @notice TEST ONLY - Extracts all segments from a block hash for analysis
    /// @dev SECURITY REMOVED from production - only available in test proxy
    /// @param blockHash The block hash to extract segments from
    /// @return An array of all segments from the block hash
    function extractAllSegments(bytes32 blockHash) external view returns (bytes8[4] memory) {
        bytes8[4] memory segments;

        for (uint256 i = BlockEntropyConstants.ZERO_UINT; i < BlockEntropyConstants.SEGMENT_COUNT; i++) {
            // For view function, we need to use a simplified version without state changes
            if (BlockValidationLibrary.isZeroHash(blockHash)) {
                segments[i] = BlockFallbackLibrary.generateFallbackSegment(i);
                continue;
            }

            uint256 shift = i * BlockEntropyConstants.BITS_PER_SEGMENT;
            if (shift >= BlockEntropyConstants.TOTAL_HASH_BITS) {
                segments[i] = BlockProcessingLibrary.extractFirstSegment(blockHash);
                continue;
            }

            segments[i] = BlockProcessingLibrary.extractSegmentWithShift(blockHash, shift);
        }

        return segments;
    }
}
