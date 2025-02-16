// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IChainlinkAggregator {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

/// @title Assetify Protocol Utilities
/// @notice Provides utility functions for price conversion and oracle integration
contract Utils {
    using SafeMath for uint256;

    // 価格履歴を保持する構造体
    struct PricePoint {
        uint256 price;
        uint256 timestamp;
    }

    // アセットごとの価格履歴
    mapping(address => PricePoint[]) private priceHistory;
    uint256 private constant PRICE_HISTORY_LENGTH = 24; // 24時間分の価格履歴
    uint256 private constant PRICE_UPDATE_INTERVAL = 1 hours;

    event PriceUpdated(address indexed asset, uint256 price, uint256 timestamp);
    event SlippageExceeded(address indexed asset, uint256 expectedPrice, uint256 actualPrice);

    /// @notice 暗号資産をステーブルコインに変換
    /// @param cryptoAsset 変換元の暗号資産アドレス
    /// @param cryptoAmount 変換する金額
    /// @return uint256 変換後のステーブルコイン金額
    function convertToStable(
        address cryptoAsset,
        uint256 cryptoAmount
    ) public view returns (uint256) {
        Schema.GlobalState storage $s = Storage.state();
        require($s.initialized, "Utils: not initialized");

        // オラクルから最新価格を取得
        uint256 assetPrice = getLatestPrice(cryptoAsset);

        // スリッページチェック
        uint256 twap = getTWAP(cryptoAsset);
        uint256 slippageTolerance = Storage.getConfig().slippageTolerance;
        require(
            isWithinSlippageTolerance(assetPrice, twap, slippageTolerance),
            "Utils: price outside slippage tolerance"
        );

        return cryptoAmount.mul(assetPrice).div(1e18);
    }

    /// @notice オラクルから最新価格を取得
    /// @param asset 価格を取得する資産のアドレス
    /// @return uint256 資産の最新価格
    function getLatestPrice(address asset) public view returns (uint256) {
        Schema.GlobalState storage $s = Storage.state();
        IChainlinkAggregator oracle = IChainlinkAggregator($s.oracleAddress);

        (
            ,
            int256 answer,
            ,
            uint256 updatedAt,

        ) = oracle.latestRoundData();

        require(answer > 0, "Utils: invalid oracle price");
        require(
            block.timestamp - updatedAt <= PRICE_UPDATE_INTERVAL,
            "Utils: oracle price too old"
        );

        return uint256(answer);
    }

    /// @notice 時間加重平均価格（TWAP）を計算
    /// @param asset TWAPを計算する資産のアドレス
    /// @return uint256 計算されたTWAP
    function getTWAP(address asset) public view returns (uint256) {
        PricePoint[] storage history = priceHistory[asset];
        require(history.length > 0, "Utils: no price history");

        uint256 totalWeight = 0;
        uint256 weightedSum = 0;
        uint256 lastTimestamp = history[history.length - 1].timestamp;

        for (uint256 i = 0; i < history.length; i++) {
            uint256 timeWeight = lastTimestamp - history[i].timestamp;
            weightedSum = weightedSum.add(history[i].price.mul(timeWeight));
            totalWeight = totalWeight.add(timeWeight);
        }

        return weightedSum.div(totalWeight);
    }

    /// @notice 価格がスリッページ許容範囲内かチェック
    /// @param currentPrice 現在の価格
    /// @param basePrice 基準価格
    /// @param tolerance 許容範囲（ベーシスポイント）
    /// @return bool スリッページ許容範囲内ならtrue
    function isWithinSlippageTolerance(
        uint256 currentPrice,
        uint256 basePrice,
        uint256 tolerance
    ) public pure returns (bool) {
        uint256 lowerBound = basePrice.mul(uint256(10000).sub(tolerance)).div(10000);
        uint256 upperBound = basePrice.mul(uint256(10000).add(tolerance)).div(10000);

        return currentPrice >= lowerBound && currentPrice <= upperBound;
    }

    /// @notice 価格履歴を更新
    /// @param asset 更新する資産のアドレス
    /// @param price 新しい価格
    function updatePriceHistory(address asset, uint256 price) internal {
        PricePoint[] storage history = priceHistory[asset];

        if (history.length >= PRICE_HISTORY_LENGTH) {
            // 古い価格を削除
            for (uint256 i = 0; i < history.length - 1; i++) {
                history[i] = history[i + 1];
            }
            history.pop();
        }

        // 新しい価格を追加
        history.push(PricePoint({
            price: price,
            timestamp: block.timestamp
        }));

        emit PriceUpdated(asset, price, block.timestamp);
    }

    /// @notice 緊急時の価格更新停止フラグ
    bool public isPriceUpdatePaused;

    /// @notice 価格更新の一時停止
    function pausePriceUpdate() external {
        Schema.GlobalState storage $s = Storage.state();
        require(msg.sender == $s.oracleAddress, "Utils: not oracle");
        isPriceUpdatePaused = true;
    }

    /// @notice 価格更新の再開
    function unpausePriceUpdate() external {
        Schema.GlobalState storage $s = Storage.state();
        require(msg.sender == $s.oracleAddress, "Utils: not oracle");
        isPriceUpdatePaused = false;
    }
}
