// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBlockEntropy} from "../../src/interfaces/IBlockEntropy.sol";

/**
 * @title IBlockDataEntropyTestProxy
 * @notice Test-only interface providing state inspection capabilities for BlockDataEntropy
 * @dev Defines security-sensitive functions removed from production interfaces for testing isolation
 *      Enables comprehensive test coverage without compromising production security model
 * @author ATrnd
 */
interface IBlockDataEntropyTestProxy is IBlockEntropy {

    /*//////////////////////////////////////////////////////////////
                         TEST-ONLY STATE QUERIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the last processed block number
    /// @dev TEST ONLY - Returns the block number when the current hash was generated
    /// @return The block number when the current hash was generated
    function getLastProcessedBlock() external view returns (uint256);

    /// @notice Gets the current segment index
    /// @dev TEST ONLY - Returns the current segment index in the cycle
    /// @return The current segment index in the cycle
    function getCurrentSegmentIndex() external view returns (uint256);

    /// @notice Gets the transaction counter
    /// @dev TEST ONLY - Returns the total number of entropy requests processed
    /// @return The total number of entropy requests processed
    function getTransactionCounter() external view returns (uint256);

    /// @notice Gets the current block hash
    /// @dev TEST ONLY - Returns the current block hash being used for entropy
    /// @return The current block hash being used for entropy
    function getCurrentBlockHash() external view returns (bytes32);

    /// @notice Extracts all segments from a block hash for analysis
    /// @dev TEST ONLY - View function that extracts all segments without state modification
    /// @param blockHash The block hash to extract segments from
    /// @return An array of all segments from the block hash
    function extractAllSegments(bytes32 blockHash) external view returns (bytes8[4] memory);
}