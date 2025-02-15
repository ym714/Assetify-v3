// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/utils/Utils.sol";

contract UtilsTest is Test {
    Utils utils;
    address btcAddress = address(0x123);
    address ethAddress = address(0x456);
    address invalidAsset = address(0x999);

    function setUp() public {
        utils = new Utils();
    }

    function testConvertBTCtoUSDT() public {
        uint256 result = utils.convertToStable(btcAddress, 1 ether);
        assertEq(result, 50000 ether); // BTC 1ETH = 50,000 USDT
    }

    function testConvertETHtoUSDT() public {
        uint256 result = utils.convertToStable(ethAddress, 1 ether);
        assertEq(result, 3000 ether); // ETH 1ETH = 3,000 USDT
    }

    function testInvalidAsset() public {
        uint256 result = utils.convertToStable(invalidAsset, 1 ether);
        assertEq(result, 0); // 無効なアセットアドレスは 0 を返す
    }
}
