// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {UnifiedVault} from "../src/core/UnifiedVault.sol";
import {MockERC20} from "../test/mocks/TestMocks.t.sol";

/// @title DeployUnifiedVault
/// @notice Deployment script for UnifiedVault contract
contract DeployUnifiedVault is Script {
    struct DeploymentConfig {
        address owner;
        address asset;
        string deploymentName;
        uint256 chainId;
    }

    string constant OUTPUT_FILE = "./broadcast/deployments.json";

    function run() external virtual returns (UnifiedVault) {
        DeploymentConfig memory config = _getDeploymentConfig();
        return _deploy(config);
    }

    function deployCustom(
        address owner,
        address asset,
        string calldata deploymentName
    ) external returns (UnifiedVault) {
        DeploymentConfig memory config = DeploymentConfig({
            owner: owner,
            asset: asset,
            deploymentName: deploymentName,
            chainId: block.chainid
        });
        return _deploy(config);
    }

    function _deploy(DeploymentConfig memory config) internal returns (UnifiedVault vault) {
        vm.startBroadcast(config.owner);

        vault = new UnifiedVault();
        vault.registerAsset(config.asset);

        vm.stopBroadcast();

        _saveDeployment(config, vault);
        return vault;
    }

    function _getDeploymentConfig() internal view returns (DeploymentConfig memory) {
        address owner = _getEnvAddress("DEPLOYER_ADDRESS", msg.sender);
        address asset = _getEnvAddress("ASSET_ADDRESS", address(0));
        string memory deploymentName = _getEnvString("DEPLOYMENT_NAME", "UnifiedVault-Mainnet");

        return DeploymentConfig({
            owner: owner,
            asset: asset,
            deploymentName: deploymentName,
            chainId: block.chainid
        });
    }

    function _getEnvAddress(string memory envVar, address defaultValue) internal view returns (address) {
        try vm.envString(envVar) returns (string memory value) {
            if (bytes(value).length == 0) return defaultValue;
            return vm.parseAddress(value);
        } catch {
            return defaultValue;
        }
    }

    function _getEnvString(string memory envVar, string memory defaultValue) internal view returns (string memory) {
        try vm.envString(envVar) returns (string memory value) {
            if (bytes(value).length == 0) return defaultValue;
            return value;
        } catch {
            return defaultValue;
        }
    }

    function _saveDeployment(DeploymentConfig memory config, UnifiedVault vault) internal {
        string memory output = string(abi.encodePacked(
            '{"vault":"', vm.toString(address(vault)),
            '","owner":"', vm.toString(config.owner),
            '","asset":"', vm.toString(config.asset),
            '","chainId":"', vm.toString(config.chainId),
            '","name":"', config.deploymentName,
            '"}'
        ));

        vm.writeJson(OUTPUT_FILE, output);
    }
}

