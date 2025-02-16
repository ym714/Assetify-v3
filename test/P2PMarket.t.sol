// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/P2PMarket.sol";
import "../src/bundleA/storage/Storage.sol";
import "../src/bundleA/utils/Utils.sol";

contract P2PMarketTest is Test {
    P2PMarket market;
    Utils utils;
    address admin = address(0x1);
    address seller = address(0x2);
    address buyer = address(0x3);
    uint256 tokenId;

    function setUp() public {
        vm.startPrank(admin);

        // コントラクトのデプロイ
        market = new P2PMarket();
        utils = new Utils();

        // テスト用のARCSトークンを設定
        Schema.GlobalState storage $s = Storage.state();

        // プロトコル設定の初期化
        Storage.initialize(
            address(0x1234), // USDT
            address(0x5678), // USDC
            admin            // Oracle
        );

        // テストトークンの作成
        tokenId = $s.nextTokenId++;
        $s.arcsTokens[tokenId] = Schema.ARCS({
            tokenId: tokenId,
            holder: seller,
            projectId: 0,
            amount: 100 ether,
            issuedAt: block.timestamp,
            maturityDate: block.timestamp + 365 days,
            annualInterestRate: 1000, // 10%
            status: Schema.TokenStatus.Active,
            isTransferRestricted: false
        });

        market.unpause();
        vm.stopPrank();
    }

    function testCreateSellOrder() public {
        vm.startPrank(seller);

        uint256 amount = 50 ether;
        uint256 price = 100 ether;
        market.createSellOrder(tokenId, amount, price);

        Schema.Order memory order = market.getOrderHistory(0);
        assertEq(order.seller, seller);
        assertEq(order.tokenId, tokenId);
        assertEq(order.amount, amount);
        assertEq(order.price, price);
        assertTrue(order.isActive);

        vm.stopPrank();
    }

    function testExecutePurchase() public {
        // 売り注文を作成
        vm.prank(seller);
        uint256 amount = 50 ether;
        uint256 price = 100 ether;
        market.createSellOrder(tokenId, amount, price);

        // 購入を実行
        vm.deal(buyer, price);
        vm.prank(buyer);
        market.executePurchase{value: price}(0);

        // 購入後の状態を確認
        Schema.GlobalState storage $s = Storage.state();
        uint256 newTokenId = tokenId + 1;

        // 新しいトークンが購入者に発行されていることを確認
        assertEq($s.arcsTokens[newTokenId].holder, buyer);
        assertEq($s.arcsTokens[newTokenId].amount, amount);

        // 売り注文が無効化されていることを確認
        Schema.Order memory order = market.getOrderHistory(0);
        assertFalse(order.isActive);
    }

    function testCancelOrder() public {
        vm.startPrank(seller);

        market.createSellOrder(tokenId, 50 ether, 100 ether);
        market.cancelOrder(0);

        Schema.Order memory order = market.getOrderHistory(0);
        assertFalse(order.isActive);

        vm.stopPrank();
    }

    function testGetActiveOrders() public {
        vm.startPrank(seller);

        // 複数の注文を作成
        market.createSellOrder(tokenId, 30 ether, 60 ether);
        market.createSellOrder(tokenId, 20 ether, 40 ether);

        // 1つをキャンセル
        market.cancelOrder(0);

        vm.stopPrank();

        // アクティブな注文のみ取得
        Schema.Order[] memory orders = market.getActiveOrders();
        assertEq(orders.length, 1);
        assertEq(orders[0].amount, 20 ether);
    }

    function testCleanupExpiredOrders() public {
        vm.startPrank(seller);
        market.createSellOrder(tokenId, 50 ether, 100 ether);
        vm.stopPrank();

        // 7日後にスキップ
        vm.warp(block.timestamp + 8 days);
        market.cleanupExpiredOrders();

        Schema.Order memory order = market.getOrderHistory(0);
        assertFalse(order.isActive);
    }

    function testFail_CreateSellOrderNotOwner() public {
        vm.prank(buyer);
        market.createSellOrder(tokenId, 50 ether, 100 ether);
    }

    function testFail_CancelOrderNotSeller() public {
        vm.prank(seller);
        market.createSellOrder(tokenId, 50 ether, 100 ether);

        vm.prank(buyer);
        market.cancelOrder(0);
    }

    function testFail_ExecutePurchaseExpiredOrder() public {
        vm.prank(seller);
        market.createSellOrder(tokenId, 50 ether, 100 ether);

        // 7日後にスキップ
        vm.warp(block.timestamp + 8 days);

        vm.deal(buyer, 100 ether);
        vm.prank(buyer);
        market.executePurchase{value: 100 ether}(0);
    }

    function testFail_ExecutePurchaseInvalidAmount() public {
        vm.prank(seller);
        market.createSellOrder(tokenId, 50 ether, 100 ether);

        vm.deal(buyer, 90 ether);
        vm.prank(buyer);
        market.executePurchase{value: 90 ether}(0);
    }

    function testPause() public {
        vm.prank(admin);
        market.pause();

        vm.prank(seller);
        vm.expectRevert("Pausable: paused");
        market.createSellOrder(tokenId, 50 ether, 100 ether);
    }

    receive() external payable {}
}
