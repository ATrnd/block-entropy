// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title BlockEntropyConstants
 * @notice Centralized constants for block-based entropy generation system
 * @dev Configuration constants for 256→64bit segmentation and component identification
 * @author ATrnd
 */
library BlockEntropyConstants {

    /*//////////////////////////////////////////////////////////////
                        SEGMENT CONFIGURATION CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Block hash segmentation count for 256→64bit extraction
    /// @dev 256-bit hash ÷ 4 segments = 64 bits each, optimal entropy density for block data
    uint256 internal constant SEGMENT_COUNT = 4;

    /// @notice Segment size in bytes for 64-bit extraction
    /// @dev 8 bytes = 64 bits, mathematical basis: 256 bits ÷ 4 segments = 64 bits per segment
    uint256 internal constant BYTES_PER_SEGMENT = 8;

    /// @notice Bit count per segment for shift calculations
    /// @dev 64 bits for shifts: 0, 64, 128, 192 bit positions
    uint256 internal constant BITS_PER_SEGMENT = 64;

    /// @notice Total bit width of keccak256 hash for bounds validation
    /// @dev 256 bits maximum for bounds validation
    uint256 internal constant TOTAL_HASH_BITS = 256;

    /// @notice Bitmask for 64-bit segment isolation after right-shift
    /// @dev 0xFFFFFFFFFFFFFFFF masks lower 64 bits
    uint256 internal constant SEGMENT_BITMASK = 0xFFFFFFFFFFFFFFFF;

    /*//////////////////////////////////////////////////////////////
                            ZERO VALUE CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Zero uint constant
    uint256 internal constant ZERO_UINT = 0;

    /// @notice Zero bytes32 constant
    bytes32 internal constant ZERO_BYTES32 = bytes32(0);

    /// @notice Zero bytes8 constant
    bytes8 internal constant ZERO_BYTES8 = bytes8(0);

    /// @notice Zero address constant for access control validation
    address internal constant ZERO_ADDRESS = address(0);

    /*//////////////////////////////////////////////////////////////
                            BLOCK PROCESSING CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Block offset for accessing previous block hash
    /// @dev EVM can only access the 256 most recent block hashes, with block.number - 1 being the most recent available
    uint256 internal constant PREVIOUS_BLOCK_OFFSET = 1;

    /*//////////////////////////////////////////////////////////////
                            COMPONENT IDENTIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Component identifiers for fallback tracking
    uint8 internal constant COMPONENT_BLOCK_HASH = 1;
    uint8 internal constant COMPONENT_SEGMENT_EXTRACTION = 2;
    uint8 internal constant COMPONENT_ENTROPY_GENERATION = 3;
    uint8 internal constant COMPONENT_ACCESS_CONTROL = 4;

    /*//////////////////////////////////////////////////////////////
                            INCREMENT CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Constant for incrementing indices
    uint256 internal constant INDEX_INCREMENT = 1;

    /*//////////////////////////////////////////////////////////////
                            ERROR CODES
    //////////////////////////////////////////////////////////////*/

    /// @notice Error codes for safety fallbacks
    uint8 internal constant ERROR_ZERO_BLOCK_HASH = 1;
    uint8 internal constant ERROR_ZERO_BLOCKHASH_FALLBACK = 2;
    uint8 internal constant ERROR_ZERO_SEGMENT = 3;
    uint8 internal constant ERROR_SEGMENT_INDEX_OUT_OF_BOUNDS = 4;
    uint8 internal constant ERROR_SHIFT_OVERFLOW = 5;
    uint8 internal constant ERROR_ORCHESTRATOR_NOT_CONFIGURED = 6;
    uint8 internal constant ERROR_UNAUTHORIZED_ORCHESTRATOR = 7;
    uint8 internal constant ERROR_ORCHESTRATOR_ALREADY_CONFIGURED = 8;
    uint8 internal constant ERROR_INVALID_ORCHESTRATOR_ADDRESS = 9;

    /*//////////////////////////////////////////////////////////////
                            FUNCTION NAME CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Function names for error reporting
    string internal constant FUNC_GET_ENTROPY = "getEntropy";
    string internal constant FUNC_UPDATE_BLOCK_HASH = "updateBlockHash";
    string internal constant FUNC_EXTRACT_SEGMENT = "extractSegment";
    string internal constant FUNC_SET_ORCHESTRATOR_ONCE = "setOrchestratorOnce";
    string internal constant FUNC_GET_ENTROPY_ACCESS_CONTROLLED = "getEntropy";

    /*//////////////////////////////////////////////////////////////
                            COMPONENT NAME CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Component name constants
    string internal constant COMPONENT_NAME_BLOCK_HASH = "BlockHash";
    string internal constant COMPONENT_NAME_SEGMENT_EXTRACTION = "SegmentExtraction";
    string internal constant COMPONENT_NAME_ENTROPY_GENERATION = "EntropyGeneration";
    string internal constant COMPONENT_NAME_ACCESS_CONTROL = "AccessControl";
    string internal constant COMPONENT_NAME_UNKNOWN = "Unknown";
}
