// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/TokenManagement.sol";
import "../src/bundleA/storage/Storage.sol";

contract TokenManagementTest is Test {
    TokenManagement token;
    address investor = address(0x123);

    function setUp() public {
        token = new TokenManagement();
    }

    function testIssueTokens() public {
        token.issueTokens(investor, 100 ether, 0);
        Schema.GlobalState storage $s = Storage.state();
        assertEq($s.arcsTokens[0].amount, 100 ether);
    }

    function testCalculateInterest() public {
        token.issueTokens(investor, 100 ether, 0);

        // 1年後をシミュレート
        vm.warp(block.timestamp + 365 days);

        uint256 interest = token.calculateInterest(investor, 0);
        assertEq(interest, 10 ether); // 10%の利回り
    }

    function testFail_RedeemBeforeMaturity() public {
        token.issueTokens(investor, 100 ether, 0);
        token.burnTokens(investor, 100 ether); // 満期前に償還しようとして失敗
    }
}
