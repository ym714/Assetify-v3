// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/P2PMarket.sol";

contract P2PMarketTest is Test {
    P2PMarket market;
    address seller = address(0x123);
    address buyer = address(0x456);

    function setUp() public {
        market = new P2PMarket();
    }

    function testCreateSellOrder() public {
        vm.prank(seller);
        market.createSellOrder(50 ether, 100 ether, 0);

        P2PMarket.Order memory order = market.getOrder(0);
        assertEq(order.arcsAmount, 50 ether);
        assertEq(order.price, 100 ether);
        assertEq(order.seller, seller);
        assertTrue(order.isActive);
    }

    function testExecutePurchase() public {
        // 売り注文を作成
        vm.prank(seller);
        market.createSellOrder(50 ether, 100 ether, 0);

        // 購入を実行
        vm.deal(buyer, 100 ether);
        vm.prank(buyer);
        market.executePurchase{value: 100 ether}(0);

        P2PMarket.Order memory order = market.getOrder(0);
        assertFalse(order.isActive);
    }

    function testFail_ExecutePurchaseWithWrongAmount() public {
        vm.prank(seller);
        market.createSellOrder(50 ether, 100 ether, 0);

        vm.deal(buyer, 50 ether);
        vm.prank(buyer);
        market.executePurchase{value: 50 ether}(0); // 価格が足りないため失敗
    }

    function testFail_ExecuteNonExistentOrder() public {
        vm.prank(buyer);
        market.executePurchase{value: 100 ether}(999); // 存在しない注文
    }

    function testCancelOrder() public {
        vm.prank(seller);
        market.createSellOrder(50 ether, 100 ether, 0);

        vm.prank(seller);
        market.cancelOrder(0);

        P2PMarket.Order memory order = market.getOrder(0);
        assertFalse(order.isActive);
    }

    function testFail_CancelOrderAsNonSeller() public {
        vm.prank(seller);
        market.createSellOrder(50 ether, 100 ether, 0);

        vm.prank(buyer);
        market.cancelOrder(0); // 販売者でないため失敗
    }
}
