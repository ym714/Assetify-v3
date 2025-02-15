// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/P2PMarket.sol";
import "../src/bundleA/storage/Storage.sol";

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

        P2PMarket.Order memory order = market.orders(0);
        assertEq(order.arcsAmount, 50 ether);
        assertEq(order.price, 100 ether);
        assertEq(order.seller, seller);
        assertEq(order.isActive, true);
    }

    function testExecutePurchase() public {
        vm.deal(buyer, 100 ether);
        vm.prank(seller);
        market.createSellOrder(50 ether, 100 ether, 0);

        vm.prank(buyer);
        market.executePurchase{value: 100 ether}(0);

        P2PMarket.Order memory order = market.orders(0);
        assertEq(order.isActive, false);
    }

    function testFail_ExecutePurchaseWithWrongAmount() public {
        vm.deal(buyer, 50 ether);
        vm.prank(seller);
        market.createSellOrder(50 ether, 100 ether, 0);

        vm.prank(buyer);
        market.executePurchase{value: 50 ether}(0); // 価格が足りないため失敗
    }

    function testFail_ExecuteNonExistentOrder() public {
        vm.prank(buyer);
        market.executePurchase{value: 100 ether}(999); // 存在しない注文
    }

    function testFail_CancelOrderAsNonSeller() public {
        vm.prank(seller);
        market.createSellOrder(50 ether, 100 ether, 0);

        vm.prank(buyer);
        market.cancelOrder(0); // 販売者でないため失敗
    }
}
