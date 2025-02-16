// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";
import "../utils/Utils.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title P2P Market for ARCS Token Trading
/// @notice Provides a decentralized marketplace for ARCS token trading
contract P2PMarket is ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    // イベント定義
    event OrderCreated(uint256 indexed orderId, address indexed seller, uint256 tokenId, uint256 amount, uint256 price);
    event OrderExecuted(uint256 indexed orderId, address indexed buyer, uint256 amount);
    event OrderCancelled(uint256 indexed orderId, string reason);
    event FeeRateUpdated(uint256 newFeeRate);
    event BatchOrdersExecuted(uint256[] orderIds, address indexed buyer);

    // 注文履歴
    mapping(uint256 => Schema.Order) private orderHistory;
    uint256 private constant ORDER_HISTORY_LIMIT = 1000;

    constructor() {
        _pause(); // デプロイ時は一時停止状態で開始
    }

    /// @notice 売り注文を作成
    /// @param tokenId ARCSトークンID
    /// @param amount 売却量
    /// @param price 売却価格
    function createSellOrder(
        uint256 tokenId,
        uint256 amount,
        uint256 price
    ) external whenNotPaused nonReentrant {
        Schema.GlobalState storage $s = Storage.state();
        Schema.ProtocolConfig memory config = Storage.getConfig();

        require($s.arcsTokens[tokenId].holder == msg.sender, "P2PMarket: not token owner");
        require($s.arcsTokens[tokenId].amount >= amount, "P2PMarket: insufficient balance");
        require($s.arcsTokens[tokenId].status == Schema.TokenStatus.Active, "P2PMarket: token not active");

        // 市場価格の取得とスリッページチェック
        uint256 marketPrice = Utils(address(this)).getTWAP(address(this));
        require(
            Utils(address(this)).isWithinSlippageTolerance(
                price,
                marketPrice,
                config.slippageTolerance
            ),
            "P2PMarket: price outside allowed range"
        );

        uint256 orderId = $s.nextOrderId++;
        Schema.Order memory order = Schema.Order({
            orderId: orderId,
            seller: msg.sender,
            tokenId: tokenId,
            amount: amount,
            price: price,
            createdAt: block.timestamp,
            expiresAt: block.timestamp + config.orderExpiration,
            isActive: true
        });

        orderHistory[orderId] = order;
        emit OrderCreated(orderId, msg.sender, tokenId, amount, price);
    }

    /// @notice 売り注文を購入
    /// @param orderId 注文ID
    function executePurchase(
        uint256 orderId
    ) external payable whenNotPaused nonReentrant {
        Schema.GlobalState storage $s = Storage.state();
        Schema.Order storage order = orderHistory[orderId];
        Schema.ProtocolConfig memory config = Storage.getConfig();

        require(order.isActive, "P2PMarket: order not active");
        require(block.timestamp <= order.expiresAt, "P2PMarket: order expired");
        require(msg.value == order.price, "P2PMarket: incorrect payment");
        require(msg.sender != order.seller, "P2PMarket: cannot buy own order");

        // 手数料の計算
        uint256 fee = order.price.mul(config.feeRate).div(10000);
        uint256 sellerAmount = order.price.sub(fee);

        // トークンの移転
        $s.arcsTokens[order.tokenId].holder = msg.sender;

        // 支払いの実行
        payable(order.seller).transfer(sellerAmount);

        order.isActive = false;
        emit OrderExecuted(orderId, msg.sender, order.amount);
    }

    /// @notice 売り注文をキャンセル
    /// @param orderId 注文ID
    function cancelOrder(uint256 orderId) external whenNotPaused {
        Schema.Order storage order = orderHistory[orderId];
        require(order.seller == msg.sender, "P2PMarket: not seller");
        require(order.isActive, "P2PMarket: order not active");

        order.isActive = false;
        emit OrderCancelled(orderId, "Cancelled by seller");
    }

    /// @notice 期限切れの注文を一括キャンセル
    function cleanupExpiredOrders() external {
        Schema.GlobalState storage $s = Storage.state();
        uint256 count = 0;

        for (uint256 i = 0; i < $s.nextOrderId && count < 50; i++) {
            Schema.Order storage order = orderHistory[i];
            if (order.isActive && block.timestamp > order.expiresAt) {
                order.isActive = false;
                emit OrderCancelled(i, "Order expired");
                count++;
            }
        }
    }

    /// @notice アクティブな注文を取得
    /// @return orders アクティブな注文の配列
    function getActiveOrders() external view returns (Schema.Order[] memory) {
        Schema.GlobalState storage $s = Storage.state();
        uint256 activeCount = 0;

        // アクティブな注文数をカウント
        for (uint256 i = 0; i < $s.nextOrderId; i++) {
            if (orderHistory[i].isActive && block.timestamp <= orderHistory[i].expiresAt) {
                activeCount++;
            }
        }

        Schema.Order[] memory activeOrders = new Schema.Order[](activeCount);
        uint256 index = 0;

        // アクティブな注文を配列に格納
        for (uint256 i = 0; i < $s.nextOrderId && index < activeCount; i++) {
            if (orderHistory[i].isActive && block.timestamp <= orderHistory[i].expiresAt) {
                activeOrders[index] = orderHistory[i];
                index++;
            }
        }

        return activeOrders;
    }

    /// @notice 注文履歴を取得
    /// @param orderId 注文ID
    function getOrderHistory(uint256 orderId) external view returns (Schema.Order memory) {
        return orderHistory[orderId];
    }

    /// @notice 一時停止（管理者のみ）
    function pause() external {
        Schema.GlobalState storage $s = Storage.state();
        require(msg.sender == $s.oracleAddress, "P2PMarket: not oracle");
        _pause();
    }

    /// @notice 一時停止解除（管理者のみ）
    function unpause() external {
        Schema.GlobalState storage $s = Storage.state();
        require(msg.sender == $s.oracleAddress, "P2PMarket: not oracle");
        _unpause();
    }

    receive() external payable {}
}
