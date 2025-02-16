// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";
import "../utils/Utils.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/// @title ARCS Token Resale Contract
/// @notice Manages the resale of bought back ARCS tokens by Assetify
contract ARCSResale is ReentrancyGuard, Pausable {
    using SafeMath for uint256;

    // イベント定義
    event TokenListed(uint256 indexed resaleId, uint256 indexed tokenId, uint256 amount, uint256 price);
    event TokenSold(uint256 indexed resaleId, address indexed buyer, uint256 amount);
    event ListingCancelled(uint256 indexed resaleId, string reason);
    event BatchListingExecuted(uint256[] resaleIds);
    event ResaleRateUpdated(uint256 newRate);

    // 再販売履歴
    mapping(uint256 => Schema.Resale) private resaleHistory;
    uint256 private constant RESALE_HISTORY_LIMIT = 1000;

    constructor() {
        _pause(); // デプロイ時は一時停止状態で開始
    }

    /// @notice 買い戻したARCSトークンを再販売リストに追加
    /// @param tokenId ARCSトークンID
    /// @param amount 販売量
    /// @param price 販売価格
    function listResaleARCS(
        uint256 tokenId,
        uint256 amount,
        uint256 price
    ) external whenNotPaused nonReentrant {
        Schema.GlobalState storage $s = Storage.state();
        Schema.ProtocolConfig memory config = Storage.getConfig();
        Schema.ARCS storage arcs = $s.arcsTokens[tokenId];

        require(arcs.holder == address(this), "ARCSResale: not owned by Assetify");
        require(arcs.amount >= amount, "ARCSResale: insufficient balance");
        require(arcs.status == Schema.TokenStatus.Active, "ARCSResale: token not active");

        // 市場価格の取得とスリッページチェック
        uint256 marketPrice = Utils(address(this)).getTWAP(address(this));
        uint256 minPrice = marketPrice.mul(config.resaleRate).div(10000); // 95%
        require(price >= minPrice, "ARCSResale: price too low");

        uint256 resaleId = $s.nextRedemptionId++;
        Schema.Resale memory resale = Schema.Resale({
            resaleId: resaleId,
            tokenId: tokenId,
            amount: amount,
            price: price,
            listedAt: block.timestamp,
            expiresAt: block.timestamp + config.resaleExpiration,
            isActive: true
        });

        resaleHistory[resaleId] = resale;
        emit TokenListed(resaleId, tokenId, amount, price);
    }

    /// @notice 再販売リストのARCSトークンを購入
    /// @param resaleId 再販売ID
    function executeResalePurchase(
        uint256 resaleId
    ) external payable whenNotPaused nonReentrant {
        Schema.GlobalState storage $s = Storage.state();
        Schema.Resale storage resale = resaleHistory[resaleId];

        require(resale.isActive, "ARCSResale: listing not active");
        require(block.timestamp <= resale.expiresAt, "ARCSResale: listing expired");
        require(msg.value == resale.price, "ARCSResale: incorrect payment");

        Schema.ARCS storage arcs = $s.arcsTokens[resale.tokenId];
        require(arcs.amount >= resale.amount, "ARCSResale: insufficient balance");

        // 新しいトークンを購入者に発行
        uint256 newTokenId = $s.nextTokenId++;
        $s.arcsTokens[newTokenId] = Schema.ARCS({
            tokenId: newTokenId,
            holder: msg.sender,
            projectId: arcs.projectId,
            amount: resale.amount,
            issuedAt: arcs.issuedAt,
            maturityDate: arcs.maturityDate,
            annualInterestRate: arcs.annualInterestRate,
            status: Schema.TokenStatus.Active,
            isTransferRestricted: false
        });

        // Assetifyの保有量を減少
        arcs.amount = arcs.amount.sub(resale.amount);

        // リスティングを無効化
        resale.isActive = false;

        emit TokenSold(resaleId, msg.sender, resale.amount);
    }

    /// @notice 一括再販売リスト追加
    /// @param tokenIds ARCSトークンIDの配列
    /// @param amounts 販売量の配列
    /// @param prices 販売価格の配列
    function batchListResale(
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        uint256[] calldata prices
    ) external whenNotPaused nonReentrant {
        require(
            tokenIds.length == amounts.length && amounts.length == prices.length,
            "ARCSResale: array length mismatch"
        );

        uint256[] memory resaleIds = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            listResaleARCS(tokenIds[i], amounts[i], prices[i]);
            resaleIds[i] = Schema.GlobalState(Storage.state()).nextRedemptionId - 1;
        }

        emit BatchListingExecuted(resaleIds);
    }

    /// @notice アクティブな再販売リストを取得
    function getActiveListings() external view returns (Schema.Resale[] memory) {
        Schema.GlobalState storage $s = Storage.state();
        uint256 activeCount = 0;

        // アクティブなリスティング数をカウント
        for (uint256 i = 0; i < $s.nextRedemptionId; i++) {
            if (resaleHistory[i].isActive && block.timestamp <= resaleHistory[i].expiresAt) {
                activeCount++;
            }
        }

        Schema.Resale[] memory activeListings = new Schema.Resale[](activeCount);
        uint256 index = 0;

        // アクティブなリスティングを配列に格納
        for (uint256 i = 0; i < $s.nextRedemptionId && index < activeCount; i++) {
            if (resaleHistory[i].isActive && block.timestamp <= resaleHistory[i].expiresAt) {
                activeListings[index] = resaleHistory[i];
                index++;
            }
        }

        return activeListings;
    }

    /// @notice 期限切れのリスティングを一括キャンセル
    function cleanupExpiredListings() external {
        Schema.GlobalState storage $s = Storage.state();
        uint256 count = 0;

        for (uint256 i = 0; i < $s.nextRedemptionId && count < 50; i++) {
            Schema.Resale storage resale = resaleHistory[i];
            if (resale.isActive && block.timestamp > resale.expiresAt) {
                resale.isActive = false;
                emit ListingCancelled(i, "Listing expired");
                count++;
            }
        }
    }

    /// @notice 再販売価格を計算
    /// @param tokenId ARCSトークンID
    /// @param amount 販売量
    function getResalePrice(
        uint256 tokenId,
        uint256 amount
    ) external view returns (uint256 price) {
        Schema.ProtocolConfig memory config = Storage.getConfig();
        uint256 marketPrice = Utils(address(this)).getTWAP(address(this));
        price = marketPrice.mul(config.resaleRate).div(10000).mul(amount).div(1e18);
    }

    /// @notice 一時停止（管理者のみ）
    function pause() external {
        Schema.GlobalState storage $s = Storage.state();
        require(msg.sender == $s.oracleAddress, "ARCSResale: not oracle");
        _pause();
    }

    /// @notice 一時停止解除（管理者のみ）
    function unpause() external {
        Schema.GlobalState storage $s = Storage.state();
        require(msg.sender == $s.oracleAddress, "ARCSResale: not oracle");
        _unpause();
    }

    receive() external payable {}
}
