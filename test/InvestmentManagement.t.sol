// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/InvestmentManagement.sol";
import "../src/bundleA/storage/Storage.sol";

contract InvestmentManagementTest is Test {
    InvestmentManagement investment;
    address investor = address(0x123);

    function setUp() public {
        investment = new InvestmentManagement();
    }

    function testInvest() public {
        investment.invest(0, address(0xABC), 10 ether);
        Schema.GlobalState storage $s = Storage.state();
        assertEq($s.investments[0].cryptoAmount, 10 ether);
    }

    function testFail_InvalidProjectId() public {
        investment.invest(999, address(0xABC), 10 ether); // 存在しないプロジェクト
    }
}
