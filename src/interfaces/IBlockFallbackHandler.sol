// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IBlockFallbackHandler
 * @notice Interface for handling fallback scenarios in block-based entropy generation
 * @dev Defines the contract for error tracking, fallback coordination, and component monitoring
 * @author ATrnd
 */
interface IBlockFallbackHandler {
    /*//////////////////////////////////////////////////////////////
                         ERROR TRACKING
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the count for a specific error in a specific component
    /// @param componentId The component to check
    /// @param errorCode The error code to check
    /// @return The count of this specific error in this component
    function getComponentErrorCount(uint8 componentId, uint8 errorCode) external view returns (uint256);

    /// @notice Gets the total errors for a specific component
    /// @param componentId The component to check
    /// @return Total error count for the component
    function getComponentTotalErrorCount(uint8 componentId) external view returns (uint256);

    /*//////////////////////////////////////////////////////////////
                    COMPONENT-SPECIFIC ERROR QUERIES
    //////////////////////////////////////////////////////////////*/

    /// @notice Gets the count of zero block hash errors in the block hash component
    /// @return The error count
    function getBlockHashZeroHashCount() external view returns (uint256);

    /// @notice Gets the count of zero blockhash fallback errors in the block hash component
    /// @return The error count
    function getBlockHashZeroBlockhashFallbackCount() external view returns (uint256);

    /// @notice Gets the count of out of bounds errors in the segment extraction component
    /// @return The error count
    function getSegmentExtractionOutOfBoundsCount() external view returns (uint256);

    /// @notice Gets the count of shift overflow errors in the segment extraction component
    /// @return The error count
    function getSegmentExtractionShiftOverflowCount() external view returns (uint256);

    /// @notice Gets the count of zero hash errors in the entropy generation component
    /// @return The error count
    function getEntropyGenerationZeroHashCount() external view returns (uint256);

    /// @notice Gets the count of zero segment errors in the entropy generation component
    /// @return The error count
    function getEntropyGenerationZeroSegmentCount() external view returns (uint256);
}
