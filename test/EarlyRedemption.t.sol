// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/EarlyRedemption.sol";
import "../src/bundleA/storage/Storage.sol";

contract EarlyRedemptionTest is Test {
    EarlyRedemption redemption;
    address investor = address(0x123);

    function setUp() public {
        redemption = new EarlyRedemption();

        // テスト用のトークンを設定
        Schema.GlobalState storage $s = Storage.state();
        $s.arcsTokens[0] = Schema.ARCS({
            tokenId: 0,
            holder: investor,
            projectId: 0,
            amount: 100 ether,
            issuedAt: block.timestamp,
            maturityDate: block.timestamp + 365 days,
            annualInterestRate: 1000,
            status: Schema.TokenStatus.Active
        });
    }

    function testExecuteEarlyRedemption() public {
        vm.deal(address(this), 100 ether);
        vm.prank(investor);

        redemption.executeEarlyRedemption(0, 50 ether);

        Schema.GlobalState storage $s = Storage.state();
        Schema.Redemption memory red = $s.redemptions[0];

        assertEq(red.redeemedAmount, 45 ether); // 10%のペナルティ適用後
        assertEq(red.penaltyAmount, 5 ether);
        assertEq(red.redeemer, investor);
        assertTrue(red.canBeRedeemed);
    }

    function testFail_InsufficientBalance() public {
        vm.prank(investor);
        redemption.executeEarlyRedemption(0, 200 ether); // 保有量以上を償還しようとする
    }

    function testFail_NonExistentToken() public {
        vm.prank(address(0x456)); // 別のアドレス
        redemption.executeEarlyRedemption(0, 50 ether); // トークンを持っていないアドレス
    }
}
