// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPoolAddressesProvider  {
    /**
     * @notice Returns the address of the Pool contract
     */
    function getPool() external view returns (address);
}
