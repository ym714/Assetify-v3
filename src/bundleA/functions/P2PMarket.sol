// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";

contract P2PMarket {
    struct Order {
        uint256 orderId;
        address seller;
        uint256 arcsAmount;
        uint256 price;
        uint256 projectId;
        bool isActive;
    }

    mapping(uint256 => Order) public orders;
    uint256 public nextOrderId;

    function createSellOrder(uint256 arcsAmount, uint256 price, uint256 projectId) external {
        orders[nextOrderId] = Order({
            orderId: nextOrderId,
            seller: msg.sender,
            arcsAmount: arcsAmount,
            price: price,
            projectId: projectId,
            isActive: true
        });

        nextOrderId++;
    }

    function executePurchase(uint256 orderId) external payable {
        Order storage order = orders[orderId];
        require(order.isActive, "Order is not active");
        require(msg.value == order.price, "Incorrect payment amount");

        payable(order.seller).transfer(order.price);
        order.isActive = false;
    }
}
