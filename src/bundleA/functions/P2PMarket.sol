// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";

contract P2PMarket {
    struct Order {
        uint256 orderId;
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        bool isActive;
    }

    mapping(uint256 => Order) public orders;
    uint256 public nextOrderId;
    uint256 public feeRate = 50; // 0.5% 手数料
    address public admin;

    event OrderCreated(uint256 indexed orderId, address indexed seller, uint256 tokenId, uint256 amount, uint256 price);
    event OrderCanceled(uint256 indexed orderId);
    event OrderExecuted(uint256 indexed orderId, address indexed buyer, uint256 amount);
    event FeeRateChanged(uint256 newRate);

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "P2PMarket: caller is not admin");
        _;
    }

    function createSellOrder(uint256 tokenId, uint256 amount, uint256 price) external {
        Schema.GlobalState storage $s = Storage.state();
        Schema.ARCS memory arcs = $s.arcsTokens[tokenId];

        require(arcs.holder == msg.sender, "P2PMarket: not the owner");
        require(arcs.amount >= amount, "P2PMarket: insufficient ARCS balance");
        require(arcs.status == Schema.TokenStatus.Active, "P2PMarket: token not active");
        require(price > 0, "P2PMarket: invalid price");

        orders[nextOrderId] = Order({
            orderId: nextOrderId,
            seller: msg.sender,
            tokenId: tokenId,
            amount: amount,
            price: price,
            isActive: true
        });

        emit OrderCreated(nextOrderId, msg.sender, tokenId, amount, price);
        nextOrderId++;
    }

    function cancelSellOrder(uint256 orderId) external {
        Order storage order = orders[orderId];
        require(order.seller == msg.sender, "P2PMarket: not the seller");
        require(order.isActive, "P2PMarket: order not active");

        order.isActive = false;
        emit OrderCanceled(orderId);
    }

    function executePurchase(uint256 orderId) external payable {
        Order storage order = orders[orderId];
        require(order.isActive, "P2PMarket: order not active");
        require(msg.value == order.price, "P2PMarket: incorrect payment amount");
        require(msg.sender != order.seller, "P2PMarket: cannot buy own order");

        Schema.GlobalState storage $s = Storage.state();
        Schema.ARCS storage arcs = $s.arcsTokens[order.tokenId];

        // 手数料を計算
        uint256 fee = (order.price * feeRate) / 10000;
        uint256 sellerAmount = order.price - fee;

        // 新しいトークンを購入者に発行
        uint256 newTokenId = $s.nextTokenId++;
        $s.arcsTokens[newTokenId] = Schema.ARCS({
            tokenId: newTokenId,
            holder: msg.sender,
            projectId: arcs.projectId,
            amount: order.amount,
            issuedAt: arcs.issuedAt,
            maturityDate: arcs.maturityDate,
            annualInterestRate: arcs.annualInterestRate,
            status: Schema.TokenStatus.Active
        });

        // 売り手のトークン残高を減少
        arcs.amount -= order.amount;

        // 支払いを実行
        payable(order.seller).transfer(sellerAmount);
        payable(admin).transfer(fee);

        order.isActive = false;
        emit OrderExecuted(orderId, msg.sender, order.amount);
    }

    function getOrder(uint256 orderId) external view returns (Order memory) {
        return orders[orderId];
    }

    function getActiveOrders() external view returns (Order[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < nextOrderId; i++) {
            if (orders[i].isActive) {
                activeCount++;
            }
        }

        Order[] memory activeOrders = new Order[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < nextOrderId; i++) {
            if (orders[i].isActive) {
                activeOrders[index] = orders[i];
                index++;
            }
        }

        return activeOrders;
    }

    function setFeeRate(uint256 newRate) external onlyAdmin {
        require(newRate <= 1000, "P2PMarket: fee rate too high"); // 最大10%
        feeRate = newRate;
        emit FeeRateChanged(newRate);
    }
}
