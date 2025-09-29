// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BlockEntropyConstants} from "../constants/BlockEntropyConstants.sol";

/**
 * @title BlockFallbackLibrary
 * @notice Pure utility functions for emergency entropy generation and component management
 * @dev Contains fallback logic extracted from BlockDataEntropy with zero modifications
 * @author ATrnd
 */
library BlockFallbackLibrary {
    /*//////////////////////////////////////////////////////////////
                         FALLBACK GENERATION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates emergency entropy when normal entropy generation fails
    /// @dev Falls back to alternative entropy sources - extracted from _generateEmergencyEntropy
    /// @param salt Additional entropy source provided by caller
    /// @param txCounter The current transaction counter
    /// @param zeroHashCount Error count for zero hash errors
    /// @param zeroSegmentCount Error count for zero segment errors
    /// @return Emergency entropy value
    function generateEmergencyEntropy(uint256 salt, uint256 txCounter, uint256 zeroHashCount, uint256 zeroSegmentCount)
        internal
        view
        returns (bytes32)
    {
        // Use a different entropy generation approach as fallback
        return keccak256(
            abi.encode(
                // Use current block data
                block.timestamp,
                block.number,
                block.prevrandao,
                // Include transaction context
                msg.sender,
                salt,
                // Add uniqueness factors
                txCounter,
                address(this),
                // Include most relevant fallback counters directly
                zeroHashCount,
                zeroSegmentCount
            )
        );
    }

    /// @notice Generates a fallback block hash when all else fails
    /// @dev Uses minimal but always-available entropy sources - extracted from _generateFallbackBlockHash
    /// @return A non-zero hash derived from available data
    function generateFallbackBlockHash() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                block.timestamp,
                block.number,
                BlockEntropyConstants.ZERO_UINT // Using extracted constant instead of s_transactionCounter
            )
        );
    }

    /// @notice Generates a fallback segment when extraction fails
    /// @dev Creates a unique segment based on timestamp and index - extracted from _generateFallbackSegment
    /// @param segmentIndex The segment index that was being extracted
    /// @return A non-zero 8-byte segment
    function generateFallbackSegment(uint256 segmentIndex) internal view returns (bytes8) {
        return bytes8(keccak256(abi.encode(block.timestamp, segmentIndex)));
    }

    /*//////////////////////////////////////////////////////////////
                              COMPONENT UTILITIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Converts a component ID to its string name
    /// @dev Extracted from _getComponentName function
    /// @param componentId The component identifier
    /// @return The string name of the component
    function getComponentName(uint8 componentId) internal pure returns (string memory) {
        if (componentId == BlockEntropyConstants.COMPONENT_BLOCK_HASH) {
            return BlockEntropyConstants.COMPONENT_NAME_BLOCK_HASH;
        }
        if (componentId == BlockEntropyConstants.COMPONENT_SEGMENT_EXTRACTION) {
            return BlockEntropyConstants.COMPONENT_NAME_SEGMENT_EXTRACTION;
        }
        if (componentId == BlockEntropyConstants.COMPONENT_ENTROPY_GENERATION) {
            return BlockEntropyConstants.COMPONENT_NAME_ENTROPY_GENERATION;
        }
        if (componentId == BlockEntropyConstants.COMPONENT_ACCESS_CONTROL) {
            return BlockEntropyConstants.COMPONENT_NAME_ACCESS_CONTROL;
        }
        return BlockEntropyConstants.COMPONENT_NAME_UNKNOWN;
    }

    /// @notice Increments the error counter for a specific component and error type
    /// @dev Pure function for error counter calculation - extracted from _incrementComponentErrorCount logic
    /// @param currentCount The current error count
    /// @return The new error count for this component/error combination
    function incrementComponentErrorCount(uint256 currentCount) internal pure returns (uint256) {
        return ++currentCount;
    }
}
