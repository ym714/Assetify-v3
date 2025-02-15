// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

contract Utils {
    function convertToStable(address cryptoAsset, uint256 cryptoAmount) public pure returns (uint256) {
        if (cryptoAsset == address(0x123)) { // BTC
            return cryptoAmount * 50000; // BTC/USD の例
        } else if (cryptoAsset == address(0x456)) { // ETH
            return cryptoAmount * 3000; // ETH/USD の例
        }
        return 0;
    }
}
