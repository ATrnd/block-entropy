// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BlockEntropyConstants} from "../constants/BlockEntropyConstants.sol";

/**
 * @title BlockTimingLibrary
 * @notice Pure utility functions for block timing and temporal calculations
 * @dev Contains temporal logic extracted from BlockDataEntropy with zero modifications
 * @author ATrnd
 */
library BlockTimingLibrary {

    /*//////////////////////////////////////////////////////////////
                         BLOCK CHANGE DETECTION
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if the current block has changed since last processing
    /// @dev Simple helper to improve readability - extracted from _hasBlockChanged
    /// @param currentBlock The current block number
    /// @param lastProcessedBlock The last processed block number
    /// @return True if block has changed
    function hasBlockChanged(uint256 currentBlock, uint256 lastProcessedBlock) internal pure returns (bool) {
        return currentBlock != lastProcessedBlock;
    }

    /*//////////////////////////////////////////////////////////////
                         BLOCK HASH ACCESS
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the blockhash for a given block number
    /// @dev Virtual function to allow overriding in test environments - extracted from _getBlockhash
    /// @param blockNumber The block number to get the hash for
    /// @return The block hash
    function getBlockhash(uint256 blockNumber) internal view returns (bytes32) {
        return blockhash(blockNumber);
    }
}