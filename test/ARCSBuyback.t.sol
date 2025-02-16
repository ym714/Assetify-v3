// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/ARCSBuyback.sol";
import "../src/bundleA/storage/Storage.sol";
import "../src/bundleA/utils/Utils.sol";

contract ARCSBuybackTest is Test {
    ARCSBuyback buyback;
    Utils utils;
    address admin = address(0x1);
    address seller = address(0x2);
    uint256 tokenId;
    uint256 projectId;

    function setUp() public {
        vm.startPrank(admin);

        // コントラクトのデプロイ
        buyback = new ARCSBuyback();
        utils = new Utils();

        // テスト用のデータを設定
        Schema.GlobalState storage $s = Storage.state();

        // プロトコル設定の初期化
        Storage.initialize(
            address(0x1234), // USDT
            address(0x5678), // USDC
            admin            // Oracle
        );

        // テストプロジェクトの作成
        projectId = $s.nextProjectId++;
        $s.projects[projectId] = Schema.Project({
            projectId: projectId,
            borrower: address(0x3),
            targetAmount: 1000 ether,
            raisedAmount: 1000 ether,
            interestRate: 1000, // 10%
            duration: 365 days,
            startTime: block.timestamp,
            fundingDeadline: block.timestamp + 30 days,
            status: Schema.ProjectStatus.Active,
            isEmergencyPaused: false
        });

        // テストトークンの作成
        tokenId = $s.nextTokenId++;
        $s.arcsTokens[tokenId] = Schema.ARCS({
            tokenId: tokenId,
            holder: seller,
            projectId: projectId,
            amount: 100 ether,
            issuedAt: block.timestamp,
            maturityDate: block.timestamp + 365 days,
            annualInterestRate: 1000, // 10%
            status: Schema.TokenStatus.Active,
            isTransferRestricted: false
        });

        // バイバックコントラクトに資金を提供
        vm.deal(address(buyback), 1000 ether);
        buyback.unpause();

        vm.stopPrank();
    }

    function testSellARCS() public {
        vm.startPrank(seller);

        uint256 amount = 25 ether; // 2.5%の上限内
        uint256 initialBalance = seller.balance;

        buyback.sellARCS(tokenId, amount);

        // 売却後の状態を確認
        Schema.GlobalState storage $s = Storage.state();

        // 元のトークンの残高が減少していることを確認
        assertEq($s.arcsTokens[tokenId].amount, 75 ether);

        // 新しいトークンがAssetifyに発行されていることを確認
        uint256 newTokenId = tokenId + 1;
        assertEq($s.arcsTokens[newTokenId].holder, address(buyback));
        assertEq($s.arcsTokens[newTokenId].amount, amount);

        // 支払いが行われていることを確認
        assertTrue(seller.balance > initialBalance);

        vm.stopPrank();
    }

    function testGetBuybackPrice() public {
        uint256 amount = 25 ether;
        uint256 price = buyback.getBuybackPrice(tokenId, amount);

        // 価格が90%になっていることを確認
        uint256 marketPrice = utils.getTWAP(address(this));
        uint256 expectedPrice = (marketPrice * 9000 / 10000) * amount / 1e18;
        assertEq(price, expectedPrice);
    }

    function testGetTotalBuybackedAmount() public {
        // 初期状態では0
        assertEq(buyback.getTotalBuybackedAmount(), 0);

        // ARCSを売却
        vm.prank(seller);
        buyback.sellARCS(tokenId, 25 ether);

        // 買い取り後のトータル量を確認
        assertEq(buyback.getTotalBuybackedAmount(), 25 ether);
    }

    function testAddAndWithdrawFunds() public {
        uint256 initialBalance = address(buyback).balance;

        // 資金を追加
        vm.prank(admin);
        buyback.addFunds{value: 100 ether}();
        assertEq(address(buyback).balance, initialBalance + 100 ether);

        // 資金を引き出し
        vm.prank(admin);
        buyback.withdrawFunds(50 ether);
        assertEq(address(buyback).balance, initialBalance + 50 ether);
    }

    function testFail_SellARCSExceedingMaxAmount() public {
        vm.prank(seller);
        buyback.sellARCS(tokenId, 30 ether); // 2.5%を超える量
    }

    function testFail_SellARCSInsufficientBalance() public {
        vm.prank(seller);
        buyback.sellARCS(tokenId, 150 ether); // 保有量以上
    }

    function testFail_WithdrawFundsNotAdmin() public {
        vm.prank(seller);
        buyback.withdrawFunds(50 ether);
    }

    function testFail_WithdrawFundsInsufficientBalance() public {
        vm.prank(admin);
        buyback.withdrawFunds(2000 ether); // コントラクトの残高以上
    }

    function testPause() public {
        vm.prank(admin);
        buyback.pause();

        vm.prank(seller);
        vm.expectRevert("Pausable: paused");
        buyback.sellARCS(tokenId, 25 ether);
    }

    function testBuybackHistory() public {
        vm.prank(seller);
        buyback.sellARCS(tokenId, 25 ether);

        Schema.Buyback memory history = buyback.getBuybackHistory(0);
        assertEq(history.seller, seller);
        assertEq(history.amount, 25 ether);
        assertTrue(history.isProcessed);
    }

    receive() external payable {}
}
