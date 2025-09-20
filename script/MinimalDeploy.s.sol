// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {BlockDataEntropy} from "../src/implementations/BlockDataEntropy.sol";

contract MinimalDeploy is Script {
    bytes32 private constant DEFAULT_SALT = keccak256("BlockDataEntropy");
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);
        address owner = vm.envOr("OWNER", deployer);
        bytes32 salt = vm.envOr("DEPLOY_SALT", DEFAULT_SALT);

        console.log("[INFO] Starting BlockDataEntropy deployment...");
        console.log("[INFO] Deployer:", deployer);
        console.log("[INFO] Owner:", owner);
        console.log("[INFO] Network:", block.chainid);

        vm.startBroadcast(deployerKey);
        BlockDataEntropy deployed = new BlockDataEntropy{salt: salt}(
            owner
        );
        vm.stopBroadcast();
        require(deployed.owner() == owner, "Deployment verification failed");
        console.log("[SUCCESS] BlockDataEntropy deployed to:", address(deployed));
        console.log("[INFO] Owner verified:", deployed.owner());
        console.log("[INFO] Block entropy segmentation: 256->64bit");
        console.log("[OK] Deployment completed");
    }
}