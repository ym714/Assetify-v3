// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";

contract ARCSResale {
    struct ResaleOrder {
        uint256 resaleId;
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        bool isAvailable;
    }

    mapping(uint256 => ResaleOrder) public resaleOrders;
    uint256 public nextResaleId;
    address public admin;
    uint256 public resaleRate = 9500; // 95% での再販価格

    event ARCSListed(uint256 indexed resaleId, uint256 tokenId, uint256 amount, uint256 price);
    event ARCSSold(uint256 indexed resaleId, address indexed buyer, uint256 amount);
    event ResaleRateChanged(uint256 newRate);

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "ARCSResale: caller is not admin");
        _;
    }

    function listResaleARCS(uint256 tokenId, uint256 amount, uint256 price) external onlyAdmin {
        Schema.GlobalState storage $s = Storage.state();
        Schema.ARCS memory arcs = $s.arcsTokens[tokenId];

        require(arcs.holder == address(this), "ARCSResale: not owned by Assetify");
        require(arcs.amount >= amount, "ARCSResale: insufficient ARCS balance");
        require(arcs.status == Schema.TokenStatus.Active, "ARCSResale: token not active");

        resaleOrders[nextResaleId] = ResaleOrder({
            resaleId: nextResaleId,
            tokenId: tokenId,
            amount: amount,
            price: price,
            isAvailable: true
        });

        emit ARCSListed(nextResaleId, tokenId, amount, price);
        nextResaleId++;
    }

    function executeResalePurchase(uint256 resaleId) external payable {
        ResaleOrder storage order = resaleOrders[resaleId];
        require(order.isAvailable, "ARCSResale: order not available");
        require(msg.value == order.price, "ARCSResale: incorrect payment amount");

        Schema.GlobalState storage $s = Storage.state();
        Schema.ARCS storage arcs = $s.arcsTokens[order.tokenId];

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

        // Assetifyの保有量を減少
        arcs.amount -= order.amount;

        // 注文を完了状態に
        order.isAvailable = false;

        emit ARCSSold(resaleId, msg.sender, order.amount);
    }

    function getResalePrice(uint256 tokenId, uint256 amount) public view returns (uint256) {
        Schema.GlobalState storage $s = Storage.state();
        Schema.ARCS memory arcs = $s.arcsTokens[tokenId];

        // 基本価値（元本 + 経過利息）を計算
        uint256 principal = amount;
        uint256 timeElapsed = block.timestamp - arcs.issuedAt;
        uint256 interest = (principal * arcs.annualInterestRate * timeElapsed) / (365 days * 10000);
        uint256 baseValue = principal + interest;

        // 再販価格（95%）を計算
        return (baseValue * resaleRate) / 10000;
    }

    function getResaleListings() external view returns (ResaleOrder[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < nextResaleId; i++) {
            if (resaleOrders[i].isAvailable) {
                activeCount++;
            }
        }

        ResaleOrder[] memory activeOrders = new ResaleOrder[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < nextResaleId; i++) {
            if (resaleOrders[i].isAvailable) {
                activeOrders[index] = resaleOrders[i];
                index++;
            }
        }

        return activeOrders;
    }

    function setResaleRate(uint256 newRate) external onlyAdmin {
        require(newRate <= 10000, "ARCSResale: invalid rate");
        resaleRate = newRate;
        emit ResaleRateChanged(newRate);
    }

    receive() external payable {}
}
