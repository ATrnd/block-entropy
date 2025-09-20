// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BlockEntropyConstants} from "../constants/BlockEntropyConstants.sol";

/**
 * @title BlockValidationLibrary
 * @notice Pure utility functions for validation predicates and safety checks
 * @dev Contains validation logic extracted from BlockDataEntropy with zero modifications
 * @author ATrnd
 */
library BlockValidationLibrary {

    /*//////////////////////////////////////////////////////////////
                         HASH VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if a hash is zero (all zeros)
    /// @dev Simple helper to improve readability - extracted from _isZeroHash
    /// @param hash The hash to check
    /// @return True if hash is all zeros
    function isZeroHash(bytes32 hash) internal pure returns (bool) {
        return hash == BlockEntropyConstants.ZERO_BYTES32;
    }

    /*//////////////////////////////////////////////////////////////
                         SEGMENT VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Checks if a segment is zero (all zeros)
    /// @dev Simple helper to improve readability - extracted from _isZeroSegment
    /// @param segment The segment to check
    /// @return True if segment is all zeros
    function isZeroSegment(bytes8 segment) internal pure returns (bool) {
        return segment == BlockEntropyConstants.ZERO_BYTES8;
    }
}