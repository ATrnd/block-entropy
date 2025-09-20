// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title BlockEntropyEvents
 * @notice Centralized event definitions for the Block Entropy system
 * @dev Contains all events extracted from BlockDataEntropy contract with zero modifications
 * @author ATrnd
 */
library BlockEntropyEvents {

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when a new hash is generated from block data
    /// @param blockNumber The block number that triggered the generation
    /// @param hashValue The generated hash value
    event BlockHashGenerated(
        uint256 indexed blockNumber,
        bytes32 hashValue
    );

    /// @notice Emitted when entropy is generated
    /// @param requester Address that requested entropy
    /// @param segmentIndex The segment index used
    /// @param blockNumber The block number used
    event EntropyGenerated(
        address indexed requester,
        uint256 segmentIndex,
        uint256 blockNumber
    );

    /// @notice Emitted when a safety fallback is used
    /// @param component_hash Hashed component name for filtering
    /// @param function_hash Hashed function name for filtering
    /// @param error_code Numeric code identifying the specific error
    /// @param component Full component name (not indexed)
    /// @param function_name Full function name (not indexed)
    event SafetyFallbackTriggered(
        bytes32 indexed component_hash,  // Hash of component for filtering
        bytes32 indexed function_hash,   // Hash of function name for filtering
        uint8 indexed error_code,        // Error code for severity filtering
        string component,                // Full component name (not indexed)
        string function_name             // Full function name (not indexed)
    );
}