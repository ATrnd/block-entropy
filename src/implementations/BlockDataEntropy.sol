// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {AbstractBlockEntropy} from "../abstracts/AbstractBlockEntropy.sol";

/**
 * @title BlockDataEntropy
 * @notice Production implementation of block-based entropy generation with segmented extraction
 * @dev Production wrapper for AbstractBlockEntropy with administrative controls
 *      Forms dual-entropy architecture with AddressDataEntropy for comprehensive randomness sources
 * @author ATrnd
 */
contract BlockDataEntropy is AbstractBlockEntropy {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes production block entropy contract with ownership controls
    /// @dev Delegates to AbstractBlockEntropy for segment index and transaction counter initialization
    /// @param _initialOwner Contract owner with administrative control privileges
    constructor(address _initialOwner) AbstractBlockEntropy(_initialOwner) {
        // Constructor logic is handled by AbstractBlockEntropy
        // All functionality is inherited from the abstract base
    }

    /*//////////////////////////////////////////////////////////////
                        INHERITED FUNCTIONALITY
    //////////////////////////////////////////////////////////////*/

    // All functionality inherited from AbstractBlockEntropy
    // Entry point: getEntropy(uint256 salt)
    // State inspection functions moved to BlockDataEntropyTestProxy for security
}
