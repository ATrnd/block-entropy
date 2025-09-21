# BlockEntropy

![Banner](https://github.com/ATrnd/block-entropy-engine/blob/main/img/block-entropy-banner.jpg?raw=true)

![Solidity](https://img.shields.io/badge/Solidity-0.8.28-363636?style=flat&logo=solidity)
![Foundry](https://img.shields.io/badge/Foundry-Latest-000000?style=flat)
![License](https://img.shields.io/badge/License-MIT-green?style=flat)
![Build](https://img.shields.io/badge/Build-Passing-success?style=flat)

**[⚡] Block-based entropy engine // 256→64bit segmentation // Crash-immune design**

## Table of Contents

- [Overview](#overview)
- [Engine Mechanics](#engine-mechanics)
  - [Block Hash Segmentation](#block-hash-segmentation)
  - [Cycling System](#cycling-system)
  - [Entropy Combination](#entropy-combination)
  - [Fallback Chain](#fallback-chain)
- [Protection Mechanics](#protection-mechanics)
  - [Invalid Data Handling](#invalid-data-handling)
  - [Fallback Architecture](#fallback-architecture)
- [Core Architecture](#core-architecture)
- [Function Reference](#function-reference)
  - [Public Functions](#public-functions)
  - [Internal Functions](#internal-functions)
  - [Library Functions](#library-functions)
- [Deployments](#deployments)
- [Quick Start](#quick-start)

## Overview

Generates entropy by extracting 64-bit segments from block hashes and combining with transaction context, cycling state, and temporal data.

## Engine Mechanics

### Block Hash Segmentation
- **256-bit block hashes** split into **4x64-bit segments**
- **Bit shifting**: `(hash >> shift) & 0xFFFFFFFFFFFFFFFF`
- **Shifts**: 0, 64, 128, 192 bits for segments 0-3

### Cycling System
- **Block hash cycling**: Updates on new block numbers
- **Segment cycling**: 4 segments → index % 4
- **Transaction counter**: Increments per entropy request
- **Temporal progression**: Block-by-block hash evolution

### Entropy Combination
```
keccak256(
  currentSegment,     // 64-bit from current block hash segment[j]
  segmentIndex,       // Which segment (0-3)
  block.timestamp,    // Block context
  block.number,
  block.prevrandao,
  msg.sender,         // Caller context
  salt,               // User input
  txCounter,          // Request number
  blockHash           // Current block hash
)
```

### Fallback Chain
1. **Zero block hash** → Use previous block hash
2. **Zero segment** → Generate `keccak256(timestamp, number, index)`
3. **Index overflow** → Reset to 0, continue with fallback
4. **Emergency entropy** → Pure block/transaction data combination

## Protection Mechanics

### Invalid Data Handling
| Scenario | Detection | Response | Error Tracking |
|----------|-----------|----------|----------------|
| **Zero Block Hash** | `blockhash == bytes32(0)` | Use previous block hash | Component ID 1, Error 1 |
| **Segment Index OOB** | `index >= 4` | Reset to 0, use fallback | Component ID 2, Error 4 |
| **Zero Segment Extract** | `segment == 0` | Generate deterministic fallback | Component ID 2, Error 3 |
| **Shift Overflow** | `shift >= 256` | Use emergency entropy | Component ID 2, Error 5 |
| **Extraction Failure** | Try-catch on segment ops | Emergency entropy path | Component ID varies |

### Fallback Architecture
```
getEntropy() → ALWAYS returns bytes32
    │
    ├── Normal Path: Extract → Combine → Return
    │
    └── Failure Path: Emergency → Combine → Return
        │
        └── Uses: block.timestamp + block.number +
                  msg.sender + salt + error_counts
```

## Core Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Block Hash    │    │  Segment Extract │    │    Entropy      │
│   256→64bit     │───▶│  (4x64-bit segs) │───▶│   Generation    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                       │
         ▼                        ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Update on Block │    │  Fallback Safety │    │   bytes32       │
│ Auto-cycling    │    │  Zero Protection │    │   Output        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Function Reference

### Public Functions

#### Core Entropy Generation
- `getEntropy(uint256 salt) external returns (bytes32)` - Primary entropy generation function with user-provided salt

#### Error Monitoring & Health Checks
- `getComponentErrorCount(uint8 componentId, uint8 errorCode) external view returns (uint256)` - Get specific error count for component/error pair
- `getComponentTotalErrorCount(uint8 componentId) external view returns (uint256)` - Get total error count for a component
- `hasComponentErrors(uint8 componentId) external view returns (bool)` - Check if component has any errors

#### Component-Specific Error Queries
- `getBlockHashZeroHashCount() external view returns (uint256)` - Zero hash errors in block hash processing
- `getBlockHashZeroBlockhashFallbackCount() external view returns (uint256)` - Zero blockhash fallback errors
- `getSegmentExtractionZeroSegmentCount() external view returns (uint256)` - Zero segment errors in segment extraction
- `getSegmentExtractionOutOfBoundsCount() external view returns (uint256)` - Out of bounds errors in segment extraction
- `getSegmentExtractionShiftOverflowCount() external view returns (uint256)` - Shift overflow errors in segment extraction
- `getEntropyGenerationZeroSegmentCount() external view returns (uint256)` - Zero segment errors in entropy generation

#### Ownership (Inherited from OpenZeppelin)
- `owner() external view returns (address)` - Get current contract owner
- `transferOwnership(address newOwner) external` - Transfer ownership to new address
- `renounceOwnership() external` - Renounce ownership (sets owner to zero address)

### Internal Functions

#### Core Processing
- `_extractSegment(bytes32 blockHash, uint256 segmentIndex) internal returns (bytes8)` - Extract specific 64-bit segment from block hash
- `_updateBlockHash() internal` - Update current block hash if needed
- `_updateSegmentIndex() internal` - Update cycling segment index
- `_incrementTransactionCounter() internal returns (uint256)` - Increment and return transaction counter

#### Fallback & Error Handling
- `_handleFallback(uint8 componentId, string memory functionName, uint8 errorCode) internal` - Handle fallback events with tracking
- `_incrementComponentErrorCount(uint8 componentId, uint8 errorCode) internal returns (uint256)` - Increment error counters
- `_generateEmergencyEntropy(uint256 salt, uint256 txCounter) internal view returns (bytes32)` - Generate emergency entropy when normal flow fails
- `_getComponentName(uint8 componentId) internal pure returns (string memory)` - Convert component ID to name string

### Library Functions

#### BlockProcessingLibrary
- `extractSegmentWithShift(bytes32 blockHash, uint256 segmentIndex) internal pure returns (bytes8)` - Core bit-shifting segment extraction
- `generateFallbackSegment(uint256 segmentIndex) internal view returns (bytes8)` - Generate deterministic fallback segment
- `generateFallbackSegments() internal view returns (bytes8[4] memory)` - Generate all fallback segments for zero hash
- `isSegmentIndexValid(uint256 segmentIndex) internal pure returns (bool)` - Validate segment index (0-3)
- `isZeroSegment(bytes8 segment) internal pure returns (bool)` - Check if extracted segment is zero
- `isZeroHash(bytes32 hash) internal pure returns (bool)` - Check if block hash is zero

#### BlockTimingLibrary
- `cycleSegmentIndex(uint256 currentIndex) internal pure returns (uint256)` - Cycle through segment indices
- `incrementTransactionCounter(uint256 currentCounter) internal pure returns (uint256)` - Increment transaction counter
- `shouldUpdateBlockHash(uint256 currentBlock, uint256 lastProcessedBlock) internal pure returns (bool)` - Check if block hash needs updating

#### BlockValidationLibrary
- `isZeroHash(bytes32 hash) internal pure returns (bool)` - Check if block hash is zero
- `isZeroValue(uint256 value) internal pure returns (bool)` - Check if uint256 value is zero
- `isShiftOverflow(uint256 shift) internal pure returns (bool)` - Check if bit shift exceeds 256 bits
- `shouldHandleExtractionError(bool success) internal pure returns (bool)` - Determine if extraction error needs handling

#### BlockFallbackLibrary
- `getComponentName(uint8 componentId) internal pure returns (string memory)` - Get component name from ID
- `incrementComponentErrorCount(uint256 currentCount) internal pure returns (uint256)` - Safely increment error count
- `generateEmergencyEntropy(uint256 salt, uint256 txCounter, uint256 zeroHashCount, uint256 zeroSegmentCount) internal view returns (bytes32)` - Generate emergency entropy with error counts

## Deployments

| Network | Address | Explorer |
|---------|---------|----------|
| Sepolia | `0xe84f3D433076c5567e2E975da6b720EBF0155eB7` | [View](https://sepolia.etherscan.io/address/0xe84f3D433076c5567e2E975da6b720EBF0155eB7) |
| Shape Mainnet | `0xe84f3D433076c5567e2E975da6b720EBF0155eB7` | [View](https://shapescan.xyz/address/0xe84f3D433076c5567e2E975da6b720EBF0155eB7) |

## Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- [Git](https://git-scm.com/) installed
- Solidity 0.8.28+

### Installation

#### Clone the Repository
```bash
git clone https://github.com/Fragment-Protocol/block-entropy.git
cd block-entropy
```

#### Install Dependencies
```bash
forge install
```

#### Build the Project
```bash
forge build
```

#### Run Tests
```bash
forge test
```