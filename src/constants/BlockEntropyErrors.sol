// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title BlockEntropyErrors
 * @notice Centralized error definitions for the Block Entropy system
 * @dev Contains all custom errors extracted from BlockDataEntropy contract with zero modifications
 * @author ATrnd
 */
library BlockEntropyErrors {

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    // No custom errors exist in the original BlockDataEntropy contract
    // The original contract uses revert statements and fallback mechanisms
    // without defining custom error types

    /*//////////////////////////////////////////////////////////////
                            IMPLEMENTATION NOTE
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev The original BlockDataEntropy contract does not define any custom errors.
     * All error handling is done through:
     * 1. Revert statements with string messages
     * 2. Safety fallback mechanisms with event emission
     * 3. Component-specific error counting and tracking
     *
     * This library is created for architectural completeness following the
     * AddressEntropy pattern, but contains no error definitions as none
     * exist in the original contract to extract.
     *
     * If custom errors are added to future versions of BlockDataEntropy,
     * they should be centralized here following the same pattern.
     */
}