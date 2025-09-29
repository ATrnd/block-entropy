// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IBlockEntropy
 * @notice Interface for block-based entropy generation with segmented extraction
 * @dev Defines entropy generation and fallback monitoring for 256→64bit block hash segmentation
 * @author ATrnd
 */
interface IBlockEntropy {

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice Thrown when trying to call getEntropy before orchestrator is configured
    error BlockEntropy__OrchestratorNotConfigured();

    /// @notice Thrown when unauthorized address attempts to call getEntropy
    error BlockEntropy__UnauthorizedOrchestrator();

    /// @notice Thrown when trying to configure orchestrator more than once
    error BlockEntropy__OrchestratorAlreadyConfigured();

    /// @notice Thrown when trying to set zero address as orchestrator
    error BlockEntropy__InvalidOrchestratorAddress();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Emitted when orchestrator is successfully configured
    /// @param orchestrator Address of the newly configured orchestrator
    event OrchestratorConfigured(address indexed orchestrator);

    /// @notice Emitted when block hash is generated from comprehensive block properties
    /// @param blockNumber Block that triggered hash generation due to block.number change
    /// @param hashValue 256-bit keccak256 hash derived from 8 block properties
    event BlockHashGenerated(
        uint256 indexed blockNumber,
        bytes32 hashValue
    );

    /// @notice Emitted when entropy generation completes successfully
    /// @param requester Address that requested entropy generation
    /// @param segmentIndex Current 64-bit segment position used (0-3)
    /// @param blockNumber Block context for temporal entropy generation
    event EntropyGenerated(
        address indexed requester,
        uint256 segmentIndex,
        uint256 blockNumber
    );

    /// @notice Emitted when fallback mechanism is triggered due to validation failure
    /// @param component_hash Keccak256 hash of component name for efficient event filtering
    /// @param function_hash Keccak256 hash of function name for precise error location
    /// @param error_code Numeric error identifier for categorization (1-9 range)
    /// @param component Human-readable component name for debugging
    /// @param function_name Human-readable function name for debugging
    event SafetyFallbackTriggered(
        bytes32 indexed component_hash,
        bytes32 indexed function_hash,
        uint8 indexed error_code,
        string component,
        string function_name
    );

    /*//////////////////////////////////////////////////////////////
                        ENTROPY GENERATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Generates entropy from current block data with salt
    /// @dev Updates block hash on block changes, cycles through 4×64-bit segments with timing validation
    /// @param salt Additional entropy source for randomness enhancement
    /// @return 32-byte entropy value derived from block hash segment with temporal and transaction context
    function getEntropy(uint256 salt) external returns (bytes32);

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /// @notice Configures the orchestrator address (one-time only)
    /// @dev Can only be called once by the contract owner
    /// @param _orchestrator Address of the orchestrator contract
    function setOrchestratorOnce(address _orchestrator) external;

    /// @notice Gets the current orchestrator address
    /// @return Address of the configured orchestrator
    function getOrchestrator() external view returns (address);

    /// @notice Checks if orchestrator has been configured
    /// @return True if orchestrator is configured and valid
    function isOrchestratorConfigured() external view returns (bool);

    /*//////////////////////////////////////////////////////////////
                        FALLBACK MONITORING
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

    /// @notice Gets the count of orchestrator not configured errors in the access control component
    /// @return The error count
    function getAccessControlOrchestratorNotConfiguredCount() external view returns (uint256);

    /// @notice Gets the count of unauthorized orchestrator errors in the access control component
    /// @return The error count
    function getAccessControlUnauthorizedOrchestratorCount() external view returns (uint256);

    /// @notice Gets the count of orchestrator already configured errors in the access control component
    /// @return The error count
    function getAccessControlOrchestratorAlreadyConfiguredCount() external view returns (uint256);

    /// @notice Gets the count of invalid orchestrator address errors in the access control component
    /// @return The error count
    function getAccessControlInvalidOrchestratorAddressCount() external view returns (uint256);

}
