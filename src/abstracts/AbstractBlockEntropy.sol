// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBlockEntropy} from "../interfaces/IBlockEntropy.sol";
import {IBlockFallbackHandler} from "../interfaces/IBlockFallbackHandler.sol";
import {BlockEntropyConstants} from "../constants/BlockEntropyConstants.sol";
import {BlockProcessingLibrary} from "../libraries/BlockProcessingLibrary.sol";
import {BlockValidationLibrary} from "../libraries/BlockValidationLibrary.sol";
import {BlockTimingLibrary} from "../libraries/BlockTimingLibrary.sol";
import {BlockFallbackLibrary} from "../libraries/BlockFallbackLibrary.sol";

/**
 * @title AbstractBlockEntropy
 * @notice Abstract base implementation for block-based entropy generation with temporal cycling
 * @dev Template implementation with 256→64bit block hash segmentation and timing-based updates
 *      Complements AddressDataEntropy for temporal-based vs identity-based entropy requirements
 * @author ATrnd
 */
abstract contract AbstractBlockEntropy is
    IBlockEntropy,
    IBlockFallbackHandler,
    Ownable
{
    using BlockValidationLibrary for bytes32;
    using BlockValidationLibrary for bytes8;
    using BlockTimingLibrary for uint256;
    using BlockFallbackLibrary for uint8;

    /*//////////////////////////////////////////////////////////////
                           MUTABLE STATE
    //////////////////////////////////////////////////////////////*/

    /// @notice Current 256-bit block hash for entropy generation
    /// @dev Updated when block.number changes, derived from comprehensive block properties via keccak256
    bytes32 internal s_currentBlockHash;

    /// @notice Block number checkpoint for hash update detection
    /// @dev Compared against block.number to trigger hash regeneration
    uint256 internal s_lastProcessedBlock;

    /// @notice Current 64-bit segment position within block hash
    /// @dev Cycles 0→1→2→3→0 for bit shifts: 0, 64, 128, 192 bits with each entropy request
    uint256 internal s_currentSegmentIndex;

    /// @notice Monotonic counter for entropy request uniqueness
    /// @dev Increments once per getEntropy() call
    uint256 internal s_transactionCounter;

    /// @notice Granular error tracking for fallback monitoring and debugging
    /// @dev Nested mapping: componentId(1-3) → errorCode(1-5) → count
    mapping(uint8 => mapping(uint8 => uint256)) internal s_componentErrorCounts;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes abstract block entropy with temporal state and ownership controls
    /// @dev Initializes segment index, transaction counter to zero and forces hash generation on first call
    /// @param _initialOwner Contract owner for OpenZeppelin Ownable inheritance
    constructor(address _initialOwner) Ownable(_initialOwner) {
        // Initialize segment index and transaction counter
        s_currentSegmentIndex = BlockEntropyConstants.ZERO_UINT;
        s_transactionCounter = BlockEntropyConstants.ZERO_UINT;

        // Initialize with current block data
        s_lastProcessedBlock = BlockEntropyConstants.ZERO_UINT; // Force hash generation on first call
    }

    /*//////////////////////////////////////////////////////////////
                        ENTROPY FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates entropy from current block data with salt
    /// @dev Updates block hash on block changes, cycles through 4×64-bit segments with timing validation
    /// @param salt Additional entropy source for randomness enhancement
    /// @return 32-byte entropy value derived from block hash segment with temporal and transaction context
    function getEntropy(uint256 salt) external virtual override returns (bytes32) {
        // Always increment transaction counter exactly once per call
        uint256 currentTx = _incrementTransactionCounter();

        _updateBlockHashIfNeeded();

        // Validate the current hash
        if (BlockValidationLibrary.isZeroHash(s_currentBlockHash)) {
            // Handle fallback with specific component ID
            _handleFallback(
                BlockEntropyConstants.COMPONENT_ENTROPY_GENERATION,
                BlockEntropyConstants.FUNC_GET_ENTROPY,
                BlockEntropyConstants.ERROR_ZERO_BLOCK_HASH
            );

            // Generate emergency entropy
            return _generateEmergencyEntropy(salt, currentTx);
        }

        // Extract the current segment of the block hash
        bytes8 currentSegment = _extractBlockHashSegment(
            s_currentBlockHash,
            s_currentSegmentIndex
        );

        // Validate the extracted segment
        if (BlockValidationLibrary.isZeroSegment(currentSegment)) {
            // Handle fallback with specific component ID
            _handleFallback(
                BlockEntropyConstants.COMPONENT_ENTROPY_GENERATION,
                BlockEntropyConstants.FUNC_GET_ENTROPY,
                BlockEntropyConstants.ERROR_ZERO_SEGMENT
            );

            // Generate emergency entropy
            return _generateEmergencyEntropy(salt, currentTx);
        }

        // Generate entropy by combining segment with other sources
        bytes32 entropy = keccak256(abi.encode(
            // Extracted segment
            currentSegment,
            s_currentSegmentIndex,

            // Block context for additional entropy
            block.timestamp,
            block.number,

            // Transaction context
            msg.sender,
            salt,
            currentTx
        ));

        emit EntropyGenerated(
            msg.sender,
            s_currentSegmentIndex,
            block.number
        );

        // Update segment index for next call
        _cycleSegmentIndex();

        return entropy;
    }

    /*//////////////////////////////////////////////////////////////
                       PRIMARY INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Increments the transaction counter and returns the new value
    /// @dev Uses pre-increment for gas efficiency and to return the new value
    /// @return The new transaction counter value
    function _incrementTransactionCounter() internal returns (uint256) {
        return ++s_transactionCounter;
    }

    /// @notice Updates the block hash if the block has changed
    /// @dev Generates a new hash from current block data
    function _updateBlockHashIfNeeded() internal {
        // Only update if block has changed
        if (BlockTimingLibrary.hasBlockChanged(block.number, s_lastProcessedBlock)) {
            // Generate hash from block data
            bytes32 newBlockHash = _generateBlockHash();

            // Validate the generated hash
            if (BlockValidationLibrary.isZeroHash(newBlockHash)) {
                _handleFallback(
                    BlockEntropyConstants.COMPONENT_BLOCK_HASH,
                    BlockEntropyConstants.FUNC_UPDATE_BLOCK_HASH,
                    BlockEntropyConstants.ERROR_ZERO_BLOCK_HASH
                );

                // Use block hash as fallback
                newBlockHash = _getBlockhash(block.number - BlockEntropyConstants.PREVIOUS_BLOCK_OFFSET);

                // If still zero, use a derived value
                if (BlockValidationLibrary.isZeroHash(newBlockHash)) {
                    _handleFallback(
                        BlockEntropyConstants.COMPONENT_BLOCK_HASH,
                        BlockEntropyConstants.FUNC_UPDATE_BLOCK_HASH,
                        BlockEntropyConstants.ERROR_ZERO_BLOCKHASH_FALLBACK
                    );
                    newBlockHash = BlockFallbackLibrary.generateFallbackBlockHash();
                }
            }

            // Update state
            s_currentBlockHash = newBlockHash;
            s_lastProcessedBlock = block.number;

            emit BlockHashGenerated(block.number, newBlockHash);
        }
    }

    /// @notice Handles a fallback event with consistent tracking and event emission
    /// @dev Increments component-specific error counter and emits event
    /// @param componentId The component where the fallback occurred
    /// @param functionName The function where the fallback occurred
    /// @param errorCode The specific error code
    function _handleFallback(
        uint8 componentId,
        string memory functionName,
        uint8 errorCode
    ) internal {
        // Increment the specific error counter for this component
        _incrementComponentErrorCount(componentId, errorCode);

        // Get component name for the event
        string memory componentName = BlockFallbackLibrary.getComponentName(componentId);

        // Emit the event
        emit SafetyFallbackTriggered(
            keccak256(bytes(componentName)),
            keccak256(bytes(functionName)),
            errorCode,
            componentName,
            functionName
        );
    }

    /// @notice Extracts a specific segment from a hash with enhanced safety
    /// @dev Divides the 32-byte hash into 4 segments of 8 bytes each
    /// @param blockHash The hash to extract from
    /// @param segmentIndex Which segment to extract (0-3)
    /// @return The extracted 8-byte segment
    function _extractBlockHashSegment(bytes32 blockHash, uint256 segmentIndex) internal virtual returns (bytes8) {
        // Ensure hash is not zero
        if (BlockValidationLibrary.isZeroHash(blockHash)) {
            // Handle fallback with specific component ID
            _handleFallback(
                BlockEntropyConstants.COMPONENT_SEGMENT_EXTRACTION,
                BlockEntropyConstants.FUNC_EXTRACT_SEGMENT,
                BlockEntropyConstants.ERROR_ZERO_BLOCK_HASH
            );
            return BlockFallbackLibrary.generateFallbackSegment(segmentIndex);
        }

        // Ensure index is within bounds (explicit check)
        uint256 safeIndex;
        if (segmentIndex < BlockEntropyConstants.SEGMENT_COUNT) {
            safeIndex = segmentIndex;
        } else {
            // Handle fallback with specific component ID
            _handleFallback(
                BlockEntropyConstants.COMPONENT_SEGMENT_EXTRACTION,
                BlockEntropyConstants.FUNC_EXTRACT_SEGMENT,
                BlockEntropyConstants.ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS
            );
            // Also fix the global segment index
            s_currentSegmentIndex = BlockEntropyConstants.ZERO_UINT;
            safeIndex = BlockEntropyConstants.ZERO_UINT;
        }

        // Calculate bit shift based on segment index
        uint256 shift = safeIndex * BlockEntropyConstants.BITS_PER_SEGMENT;

        // Safety check - ensure shift doesn't exceed hash size
        if (shift >= BlockEntropyConstants.TOTAL_HASH_BITS) {
            // Handle fallback with specific component ID
            _handleFallback(
                BlockEntropyConstants.COMPONENT_SEGMENT_EXTRACTION,
                BlockEntropyConstants.FUNC_EXTRACT_SEGMENT,
                BlockEntropyConstants.ERROR_SHIFT_OVERFLOW
            );
            return BlockProcessingLibrary.extractFirstSegment(blockHash);
        }

        // Extract the segment using bit operations
        return BlockProcessingLibrary.extractSegmentWithShift(blockHash, shift);
    }

    /*//////////////////////////////////////////////////////////////
                       UTILITY INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Updates the segment index to the next in cycle
    /// @dev Cycles through 0 to SEGMENT_COUNT-1 with additional safety
    function _cycleSegmentIndex() internal {
        unchecked {
            // First check if the current index is already out of bounds
            if (s_currentSegmentIndex >= BlockEntropyConstants.SEGMENT_COUNT) {
                // Reset it to 0 if it is
                s_currentSegmentIndex = BlockEntropyConstants.ZERO_UINT;
            } else {
                // Otherwise, increment and apply modulo
                s_currentSegmentIndex = (s_currentSegmentIndex + BlockEntropyConstants.INDEX_INCREMENT) % BlockEntropyConstants.SEGMENT_COUNT;
            }
        }
    }

    /// @notice Increments the error counter for a specific component and error type
    /// @dev Used for tracking specific fallback scenarios
    /// @param componentId The component ID where the error occurred
    /// @param errorCode The specific error code
    /// @return The new error count for this component/error combination
    function _incrementComponentErrorCount(uint8 componentId, uint8 errorCode) internal returns (uint256) {
        s_componentErrorCounts[componentId][errorCode] = BlockFallbackLibrary.incrementComponentErrorCount(
            s_componentErrorCounts[componentId][errorCode]
        );
        return s_componentErrorCounts[componentId][errorCode];
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates a hash from current block data
    /// @dev Combines multiple block properties for entropy
    /// @return A 32-byte hash representing the current block
    function _generateBlockHash() internal virtual view returns (bytes32) {
        return BlockProcessingLibrary.generateBlockHash();
    }

    /// @notice Gets the blockhash for a given block number
    /// @dev Virtual function to allow overriding in test environments
    /// @param blockNumber The block number to get the hash for
    /// @return The block hash
    function _getBlockhash(uint256 blockNumber) internal virtual view returns (bytes32) {
        return BlockTimingLibrary.getBlockhash(blockNumber);
    }

    /// @notice Generates emergency entropy when normal entropy generation fails
    /// @dev Falls back to alternative entropy sources
    /// @param salt Additional entropy source provided by caller
    /// @param txCounter The current transaction counter
    /// @return Emergency entropy value
    function _generateEmergencyEntropy(uint256 salt, uint256 txCounter) internal view returns (bytes32) {
        return BlockFallbackLibrary.generateEmergencyEntropy(
            salt,
            txCounter,
            s_componentErrorCounts[BlockEntropyConstants.COMPONENT_BLOCK_HASH][BlockEntropyConstants.ERROR_ZERO_BLOCK_HASH],
            s_componentErrorCounts[BlockEntropyConstants.COMPONENT_ENTROPY_GENERATION][BlockEntropyConstants.ERROR_ZERO_SEGMENT]
        );
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the count for a specific error in a specific component
    /// @param componentId The component to check
    /// @param errorCode The error code to check
    /// @return The count of this specific error in this component
    function getComponentErrorCount(uint8 componentId, uint8 errorCode) external view virtual override(IBlockEntropy, IBlockFallbackHandler) returns (uint256) {
        return s_componentErrorCounts[componentId][errorCode];
    }

    /// @notice Gets the total errors for a specific component
    /// @param componentId The component to check
    /// @return Total error count for the component
    function getComponentTotalErrorCount(uint8 componentId) external view virtual override(IBlockEntropy, IBlockFallbackHandler) returns (uint256) {
        uint256 total = BlockEntropyConstants.ZERO_UINT;
        // We avoid loops and use direct access since we know exactly which error codes exist
        total += s_componentErrorCounts[componentId][BlockEntropyConstants.ERROR_ZERO_BLOCK_HASH];
        total += s_componentErrorCounts[componentId][BlockEntropyConstants.ERROR_ZERO_BLOCKHASH_FALLBACK];
        total += s_componentErrorCounts[componentId][BlockEntropyConstants.ERROR_ZERO_SEGMENT];
        total += s_componentErrorCounts[componentId][BlockEntropyConstants.ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS];
        total += s_componentErrorCounts[componentId][BlockEntropyConstants.ERROR_SHIFT_OVERFLOW];
        return total;
    }

    /// @notice Checks if a component has experienced any errors
    /// @param componentId The component to check
    /// @return Whether the component has experienced any errors
    function hasComponentErrors(uint8 componentId) external view virtual override(IBlockEntropy, IBlockFallbackHandler) returns (bool) {
        // Direct check of each error code without loops
        return s_componentErrorCounts[componentId][BlockEntropyConstants.ERROR_ZERO_BLOCK_HASH] > BlockEntropyConstants.ZERO_UINT ||
               s_componentErrorCounts[componentId][BlockEntropyConstants.ERROR_ZERO_BLOCKHASH_FALLBACK] > BlockEntropyConstants.ZERO_UINT ||
               s_componentErrorCounts[componentId][BlockEntropyConstants.ERROR_ZERO_SEGMENT] > BlockEntropyConstants.ZERO_UINT ||
               s_componentErrorCounts[componentId][BlockEntropyConstants.ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS] > BlockEntropyConstants.ZERO_UINT ||
               s_componentErrorCounts[componentId][BlockEntropyConstants.ERROR_SHIFT_OVERFLOW] > BlockEntropyConstants.ZERO_UINT;
    }

    function getBlockHashZeroHashCount() external view virtual override(IBlockEntropy, IBlockFallbackHandler) returns (uint256) {
        return s_componentErrorCounts[BlockEntropyConstants.COMPONENT_BLOCK_HASH][BlockEntropyConstants.ERROR_ZERO_BLOCK_HASH];
    }

    function getBlockHashZeroBlockhashFallbackCount() external view virtual override(IBlockEntropy, IBlockFallbackHandler) returns (uint256) {
        return s_componentErrorCounts[BlockEntropyConstants.COMPONENT_BLOCK_HASH][BlockEntropyConstants.ERROR_ZERO_BLOCKHASH_FALLBACK];
    }

    function getSegmentExtractionOutOfBoundsCount() external view virtual override(IBlockEntropy, IBlockFallbackHandler) returns (uint256) {
        return s_componentErrorCounts[BlockEntropyConstants.COMPONENT_SEGMENT_EXTRACTION][BlockEntropyConstants.ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS];
    }

    function getSegmentExtractionShiftOverflowCount() external view virtual override(IBlockEntropy, IBlockFallbackHandler) returns (uint256) {
        return s_componentErrorCounts[BlockEntropyConstants.COMPONENT_SEGMENT_EXTRACTION][BlockEntropyConstants.ERROR_SHIFT_OVERFLOW];
    }

    function getEntropyGenerationZeroHashCount() external view virtual override(IBlockEntropy, IBlockFallbackHandler) returns (uint256) {
        return s_componentErrorCounts[BlockEntropyConstants.COMPONENT_ENTROPY_GENERATION][BlockEntropyConstants.ERROR_ZERO_BLOCK_HASH];
    }

    function getEntropyGenerationZeroSegmentCount() external view virtual override(IBlockEntropy, IBlockFallbackHandler) returns (uint256) {
        return s_componentErrorCounts[BlockEntropyConstants.COMPONENT_ENTROPY_GENERATION][BlockEntropyConstants.ERROR_ZERO_SEGMENT];
    }
}