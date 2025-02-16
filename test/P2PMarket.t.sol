// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/P2PMarket.sol";
import "../src/bundleA/storage/Storage.sol";

contract P2PMarketTest is Test {
    P2PMarket market;
    address admin = address(0x1);
    address seller = address(0x2);
    address buyer = address(0x3);
    uint256 tokenId;

    function setUp() public {
        vm.startPrank(admin);
        market = new P2PMarket();

        // テスト用のARCSトークンを設定
        Schema.GlobalState storage $s = Storage.state();
        tokenId = $s.nextTokenId++;

        $s.arcsTokens[tokenId] = Schema.ARCS({
            tokenId: tokenId,
            holder: seller,
            projectId: 0,
            amount: 100 ether,
            issuedAt: block.timestamp,
            maturityDate: block.timestamp + 365 days,
            annualInterestRate: 1000, // 10%
            status: Schema.TokenStatus.Active
        });

        vm.stopPrank();
    }

    function testCreateSellOrder() public {
        vm.startPrank(seller);

        uint256 amount = 50 ether;
        uint256 price = 100 ether;
        market.createSellOrder(tokenId, amount, price);

        P2PMarket.Order memory order = market.getOrder(0);
        assertEq(order.seller, seller);
        assertEq(order.tokenId, tokenId);
        assertEq(order.amount, amount);
        assertEq(order.price, price);
        assertTrue(order.isActive);

        vm.stopPrank();
    }

    function testCancelSellOrder() public {
        vm.startPrank(seller);

        market.createSellOrder(tokenId, 50 ether, 100 ether);
        market.cancelSellOrder(0);

        P2PMarket.Order memory order = market.getOrder(0);
        assertFalse(order.isActive);

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
        P2PMarket.Order memory order = market.getOrder(0);
        assertFalse(order.isActive);
    }

    function testGetActiveOrders() public {
        vm.startPrank(seller);

        // 複数の注文を作成
        market.createSellOrder(tokenId, 30 ether, 60 ether);
        market.createSellOrder(tokenId, 20 ether, 40 ether);

        // 1つをキャンセル
        market.cancelSellOrder(0);

        vm.stopPrank();

        // アクティブな注文のみ取得
        P2PMarket.Order[] memory orders = market.getActiveOrders();
        assertEq(orders.length, 1);
        assertEq(orders[0].amount, 20 ether);
    }

    function testSetFeeRate() public {
        vm.prank(admin);
        uint256 newRate = 100; // 1%

        market.setFeeRate(newRate);

        assertEq(market.feeRate(), newRate);
    }

    function testFail_CreateSellOrderNotOwner() public {
        vm.prank(buyer);
        market.createSellOrder(tokenId, 50 ether, 100 ether);
    }

    function testFail_CancelSellOrderNotSeller() public {
        vm.prank(seller);
        market.createSellOrder(tokenId, 50 ether, 100 ether);

        vm.prank(buyer);
        market.cancelSellOrder(0);
    }

    function testFail_ExecutePurchaseInvalidAmount() public {
        vm.prank(seller);
        market.createSellOrder(tokenId, 50 ether, 100 ether);

        vm.deal(buyer, 90 ether);
        vm.prank(buyer);
        market.executePurchase{value: 90 ether}(0);
    }

    function testFail_SetFeeRateNotAdmin() public {
        vm.prank(seller);
        market.setFeeRate(100);
    }

    function testFail_SetInvalidFeeRate() public {
        vm.prank(admin);
        market.setFeeRate(1100); // 11% は無効
    }
}
