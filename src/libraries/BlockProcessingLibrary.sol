// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BlockEntropyConstants} from "../constants/BlockEntropyConstants.sol";

/**
 * @title BlockProcessingLibrary
 * @notice Block data processing utility functions for hash generation and segment extraction
 * @dev Bit manipulation and keccak256-based entropy processing algorithms
 * @author ATrnd
 */
library BlockProcessingLibrary {

    /*//////////////////////////////////////////////////////////////
                         BLOCK HASH GENERATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates hash from comprehensive block data
    /// @dev Combines 8 block properties with previous blockhash using keccak256 for maximum entropy density
    /// @return 32-byte hash derived from block.timestamp, block.number, prevrandao, basefee, coinbase, gaslimit, chainid, and previous blockhash
    function generateBlockHash() internal view returns (bytes32) {
        // Collect all available block data for maximum entropy
        return keccak256(abi.encode(
            // Block context - all available properties
            block.timestamp,
            block.number,
            block.prevrandao,
            block.basefee,
            block.coinbase,
            block.gaslimit,
            block.chainid,

            // Include the previous block hash
            blockhash(block.number - BlockEntropyConstants.PREVIOUS_BLOCK_OFFSET),

            // Include contract state for additional uniqueness
            address(this),
            BlockEntropyConstants.ZERO_UINT // Using constant instead of s_transactionCounter for library purity
        ));
    }

    /*//////////////////////////////////////////////////////////////
                         SEGMENT EXTRACTION WITH SHIFT
    //////////////////////////////////////////////////////////////*/

    /// @notice Extracts 64-bit segment from 256-bit hash using bit shifts
    /// @dev Uses right-shift and bitmask operations for O(1) extraction
    /// @param blockHash Source 256-bit hash for segmentation
    /// @param shift Bit position for right-shift operation (0-192, step 64)
    /// @return 8-byte segment from specified bit position
    function extractSegmentWithShift(bytes32 blockHash, uint256 shift) internal pure returns (bytes8) {
        uint256 hashValue = uint256(blockHash);
        uint64 segment = uint64((hashValue >> shift) & BlockEntropyConstants.SEGMENT_BITMASK);
        return bytes8(segment);
    }

    /// @notice Extracts first 64-bit segment as emergency fallback
    /// @dev Isolates lowest 64 bits using SEGMENT_BITMASK when bounds checking fails
    /// @param blockHash Source hash for fallback extraction
    /// @return 8-byte segment from bits 0-63 position
    function extractFirstSegment(bytes32 blockHash) internal pure returns (bytes8) {
        return bytes8(uint64(uint256(blockHash) & BlockEntropyConstants.SEGMENT_BITMASK));
    }
}