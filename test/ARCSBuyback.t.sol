// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/ARCSBuyback.sol";
import "../src/bundleA/storage/Storage.sol";

contract ARCSBuybackTest is Test {
    ARCSBuyback buyback;
    address admin = address(0x1);
    address investor = address(0x2);
    uint256 tokenId;

    function setUp() public {
        vm.startPrank(admin);
        buyback = new ARCSBuyback();

        // テスト用のARCSトークンを設定
        Schema.GlobalState storage $s = Storage.state();
        tokenId = $s.nextTokenId++;

        $s.arcsTokens[tokenId] = Schema.ARCS({
            tokenId: tokenId,
            holder: investor,
            projectId: 0,
            amount: 100 ether,
            issuedAt: block.timestamp,
            maturityDate: block.timestamp + 365 days,
            annualInterestRate: 1000, // 10%
            status: Schema.TokenStatus.Active
        });

        // コントラクトに資金を提供
        vm.deal(address(buyback), 1000 ether);
        vm.stopPrank();
    }

    function testBuybackPrice() public {
        uint256 price = buyback.getBuybackPrice(tokenId, 50 ether);
        assertGt(price, 0, "Buyback price should be greater than 0");
        assertLt(price, 50 ether, "Buyback price should be less than principal");
    }

    function testSellARCS() public {
        vm.startPrank(investor);

        uint256 initialBalance = investor.balance;
        uint256 sellAmount = 50 ether;
        uint256 expectedPrice = buyback.getBuybackPrice(tokenId, sellAmount);

        buyback.sellARCS(tokenId, sellAmount);

        // 投資家の残高が増加していることを確認
        assertEq(investor.balance, initialBalance + expectedPrice);

        // Assetifyが新しいトークンを保有していることを確認
        Schema.GlobalState storage $s = Storage.state();
        uint256 newTokenId = tokenId + 1;
        assertEq($s.arcsTokens[newTokenId].holder, address(buyback));
        assertEq($s.arcsTokens[newTokenId].amount, sellAmount);

        vm.stopPrank();
    }

    function testWithdrawFunds() public {
        vm.prank(admin);
        uint256 withdrawAmount = 10 ether;
        uint256 initialBalance = admin.balance;

        buyback.withdrawFunds(admin, withdrawAmount);

        assertEq(admin.balance, initialBalance + withdrawAmount);
    }

    function testSetBuybackRate() public {
        vm.prank(admin);
        uint256 newRate = 8500; // 85%

        buyback.setBuybackRate(newRate);

        assertEq(buyback.buybackRate(), newRate);
    }

    function testGetTotalBuybackedARCS() public {
        // 初期状態では0
        assertEq(buyback.getTotalBuybackedARCS(), 0);

        // ARCSを売却
        vm.prank(investor);
        buyback.sellARCS(tokenId, 50 ether);

        // 買い取り後のトータル量を確認
        assertEq(buyback.getTotalBuybackedARCS(), 50 ether);
    }

    function testFail_SellARCSInsufficientBalance() public {
        vm.prank(investor);
        buyback.sellARCS(tokenId, 200 ether); // 保有量以上を売却しようとする
    }

    function testFail_WithdrawFundsNotAdmin() public {
        vm.prank(investor);
        buyback.withdrawFunds(investor, 10 ether);
    }

    function testFail_SetBuybackRateNotAdmin() public {
        vm.prank(investor);
        buyback.setBuybackRate(8500);
    }

    function testFail_SetInvalidBuybackRate() public {
        vm.prank(admin);
        buyback.setBuybackRate(11000); // 110% は無効
    }
}
