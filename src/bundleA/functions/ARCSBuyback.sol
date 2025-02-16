// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";
import "../utils/Utils.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title ARCS Token Buyback Contract
/// @notice Manages the buyback of ARCS tokens by Assetify at a discounted rate
contract ARCSBuyback is ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    // イベント定義
    event BuybackExecuted(uint256 indexed tokenId, address indexed seller, uint256 amount, uint256 price);
    event BuybackRateUpdated(uint256 newRate);
    event MaxBuybackAmountUpdated(uint256 newAmount);
    event FundsAdded(uint256 amount);
    event FundsWithdrawn(uint256 amount);

    // 買取履歴
    mapping(uint256 => Schema.Buyback) private buybackHistory;
    uint256 private constant BUYBACK_HISTORY_LIMIT = 1000;

    constructor() {
        _pause(); // デプロイ時は一時停止状態で開始
    }

    /// @notice ARCSトークンを買い取る
    /// @param tokenId 買い取るARCSトークンのID
    /// @param amount 買取量
    function sellARCS(
        uint256 tokenId,
        uint256 amount
    ) external whenNotPaused nonReentrant {
        Schema.GlobalState storage $s = Storage.state();
        Schema.ProtocolConfig memory config = Storage.getConfig();
        Schema.ARCS storage arcs = $s.arcsTokens[tokenId];

        require(arcs.holder == msg.sender, "ARCSBuyback: not token owner");
        require(arcs.amount >= amount, "ARCSBuyback: insufficient balance");
        require(arcs.status == Schema.TokenStatus.Active, "ARCSBuyback: token not active");

        // 買取可能額のチェック
        uint256 projectRaisedAmount = $s.projects[arcs.projectId].raisedAmount;
        uint256 maxBuybackAmount = projectRaisedAmount.mul(25).div(1000); // 2.5%
        require(amount <= maxBuybackAmount, "ARCSBuyback: exceeds max buyback amount");

        // 買取価格の計算
        uint256 marketPrice = Utils(address(this)).getTWAP(address(this));
        uint256 buybackPrice = marketPrice.mul(config.buybackRate).div(10000); // 90%
        uint256 totalPayment = buybackPrice.mul(amount).div(1e18);

        require(address(this).balance >= totalPayment, "ARCSBuyback: insufficient contract balance");

        // 買取記録の作成
        uint256 buybackId = $s.nextRedemptionId++;
        buybackHistory[buybackId] = Schema.Buyback({
            buybackId: buybackId,
            tokenId: tokenId,
            amount: amount,
            price: buybackPrice,
            seller: msg.sender,
            timestamp: block.timestamp,
            isProcessed: true
        });

        // トークンの移転
        arcs.amount = arcs.amount.sub(amount);

        // 新しいトークンをAssetifyに発行
        uint256 newTokenId = $s.nextTokenId++;
        $s.arcsTokens[newTokenId] = Schema.ARCS({
            tokenId: newTokenId,
            holder: address(this),
            projectId: arcs.projectId,
            amount: amount,
            issuedAt: arcs.issuedAt,
            maturityDate: arcs.maturityDate,
            annualInterestRate: arcs.annualInterestRate,
            status: Schema.TokenStatus.Active,
            isTransferRestricted: false
        });

        // 支払いの実行
        payable(msg.sender).transfer(totalPayment);

        emit BuybackExecuted(tokenId, msg.sender, amount, buybackPrice);
    }

    /// @notice 買取価格を計算
    /// @param tokenId ARCSトークンID
    /// @param amount 買取量
    /// @return price 買取価格
    function getBuybackPrice(
        uint256 tokenId,
        uint256 amount
    ) external view returns (uint256 price) {
        Schema.GlobalState storage $s = Storage.state();
        Schema.ProtocolConfig memory config = Storage.getConfig();

        uint256 marketPrice = Utils(address(this)).getTWAP(address(this));
        price = marketPrice.mul(config.buybackRate).div(10000).mul(amount).div(1e18);
    }

    /// @notice 買取履歴を取得
    /// @param buybackId 買取ID
    function getBuybackHistory(uint256 buybackId) external view returns (Schema.Buyback memory) {
        return buybackHistory[buybackId];
    }

    /// @notice 総買取量を取得
    function getTotalBuybackedAmount() external view returns (uint256) {
        Schema.GlobalState storage $s = Storage.state();
        uint256 total = 0;

        for (uint256 i = 0; i < $s.nextTokenId; i++) {
            if ($s.arcsTokens[i].holder == address(this)) {
                total = total.add($s.arcsTokens[i].amount);
            }
        }

        return total;
    }

    /// @notice 資金を追加（管理者のみ）
    function addFunds() external payable whenNotPaused {
        Schema.GlobalState storage $s = Storage.state();
        require(msg.sender == $s.oracleAddress, "ARCSBuyback: not oracle");
        emit FundsAdded(msg.value);
    }

    /// @notice 資金を引き出す（管理者のみ）
    /// @param amount 引き出す量
    function withdrawFunds(uint256 amount) external whenNotPaused {
        Schema.GlobalState storage $s = Storage.state();
        require(msg.sender == $s.oracleAddress, "ARCSBuyback: not oracle");
        require(address(this).balance >= amount, "ARCSBuyback: insufficient balance");

        payable(msg.sender).transfer(amount);
        emit FundsWithdrawn(amount);
    }

    /// @notice 一時停止（管理者のみ）
    function pause() external {
        Schema.GlobalState storage $s = Storage.state();
        require(msg.sender == $s.oracleAddress, "ARCSBuyback: not oracle");
        _pause();
    }

    /// @notice 一時停止解除（管理者のみ）
    function unpause() external {
        Schema.GlobalState storage $s = Storage.state();
        require(msg.sender == $s.oracleAddress, "ARCSBuyback: not oracle");
        _unpause();
    }

    receive() external payable {}
}
