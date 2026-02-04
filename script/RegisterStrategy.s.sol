// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {UnifiedVault} from "../src/core/UnifiedVault.sol";
import {AaveStrategyV3} from "../src/strategy/AaveStrategyV3.sol";
import {MorphoStrategy} from "../src/strategy/MorphoStrategy.sol";

/// @title RegisterStrategy
/// @notice Script to deploy and register strategies with UnifiedVault
contract RegisterStrategy is Script {
    struct StrategyConfig {
        uint256 assetId;
        address vault;
        address asset;
        address aavePoolProvider;
        address morpho;
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        address lltv;
    }

    function deployAaveStrategy() external returns (AaveStrategyV3) {
        StrategyConfig memory config = _getStrategyConfig();
        require(config.aavePoolProvider != address(0), "AAVE_POOL_PROVIDER not set");
        require(config.asset != address(0), "ASSET_ADDRESS not set");

        vm.startBroadcast(config.vault);

        AaveStrategyV3 strategy = new AaveStrategyV3(
            config.vault,
            config.asset,
            config.aavePoolProvider
        );

        UnifiedVault vault = UnifiedVault(config.vault);
        vault.addStrategy(config.assetId, address(strategy));
        vault.setActiveStrategy(config.assetId, 0);

        vm.stopBroadcast();

        _saveStrategy("AaveV3", address(strategy), config.assetId);
        return strategy;
    }

    function deployMorphoStrategy() external returns (MorphoStrategy) {
        StrategyConfig memory config = _getStrategyConfig();
        require(config.morpho != address(0), "MORPHO_ADDRESS not set");
        require(config.asset != address(0), "ASSET_ADDRESS not set");

        vm.startBroadcast(config.vault);

        MorphoStrategy strategy = new MorphoStrategy(
            config.vault,
            config.asset,
            config.morpho,
            config.loanToken,
            config.collateralToken,
            config.oracle,
            config.irm,
            config.lltv
        );

        UnifiedVault vault = UnifiedVault(config.vault);
        vault.addStrategy(config.assetId, address(strategy));

        vm.stopBroadcast();

        _saveStrategy("Morpho", address(strategy), config.assetId);
        return strategy;
    }

    function setActiveStrategy(address vault, uint256 assetId, uint256 strategyIndex) external {
        vm.startBroadcast();
        UnifiedVault(vault).setActiveStrategy(assetId, strategyIndex);
        vm.stopBroadcast();
    }

    function removeStrategy(address vault, uint256 assetId, uint256 strategyIndex) external {
        vm.startBroadcast();
        UnifiedVault(vault).removeStrategy(assetId, strategyIndex);
        vm.stopBroadcast();
    }

    function _getStrategyConfig() internal view returns (StrategyConfig memory) {
        address vault = _parseAddressEnv("VAULT_ADDRESS");
        address asset = _parseAddressEnv("ASSET_ADDRESS");

        return StrategyConfig({
            assetId: _parseUintEnv("ASSET_ID", 0),
            vault: vault,
            asset: asset,
            aavePoolProvider: _parseAddressEnv("AAVE_POOL_PROVIDER"),
            morpho: _parseAddressEnv("MORPHO_ADDRESS"),
            loanToken: _parseAddressEnv("LOAN_TOKEN"),
            collateralToken: _parseAddressEnv("COLLATERAL_TOKEN"),
            oracle: _parseAddressEnv("ORACLE"),
            irm: _parseAddressEnv("IRM"),
            lltv: _parseAddressEnv("LLTV")
        });
    }

    function _parseAddressEnv(string memory envVar) internal view returns (address) {
        try vm.envString(envVar) returns (string memory value) {
            if (bytes(value).length == 0) return address(0);
            return vm.parseAddress(value);
        } catch {
            return address(0);
        }
    }

    function _parseUintEnv(string memory envVar, uint256 defaultValue) internal view returns (uint256) {
        try vm.envString(envVar) returns (string memory value) {
            if (bytes(value).length == 0) return defaultValue;
            return vm.parseUint(value);
        } catch {
            return defaultValue;
        }
    }

    function _saveStrategy(
        string memory strategyType,
        address strategyAddress,
        uint256 assetId
    ) internal {
        string memory json = string(abi.encodePacked(
            '{"strategyType":"', strategyType,
            '","strategyAddress":"', vm.toString(strategyAddress),
            '","assetId":"', vm.toString(assetId),
            '"}'
        ));

        string memory filename = string(abi.encodePacked("./broadcast/", strategyType, "-deployment.json"));
        vm.writeJson(filename, json);
    }
}
