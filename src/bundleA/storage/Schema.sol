// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @title Assetify Protocol Data Structures
/// @notice Defines all data structures used in the Assetify protocol
/// @custom:storage-location erc7201:assetify.globalstate
library Schema {
    struct GlobalState {
        mapping(uint256 => Project) projects;
        mapping(uint256 => Investment) investments;
        mapping(uint256 => ARCS) arcsTokens;
        mapping(uint256 => Redemption) redemptions;
        mapping(uint256 => uint256[]) arcsToProjects; // ARCSのプロジェクト紐付け
        mapping(address => uint256[]) userTokens; // ユーザーごとのトークンID
        uint256 nextProjectId;
        uint256 nextInvestmentId;
        uint256 nextTokenId;
        uint256 nextRedemptionId;
        address usdtAddress;
        address usdcAddress;
        address oracleAddress; // 価格オラクルのアドレス
        ProtocolConfig protocolConfig; // プロトコル設定
        bool initialized;
    }

    enum ProjectStatus {
        Draft,      // プロジェクト作成直後
        ReadyToFund, // 管理者承認後
        Funding,    // 投資受付中
        Active,     // 資金調達完了
        Completed,  // 返済完了
        Defaulted   // デフォルト
    }

    enum TokenStatus {
        Active,    // 通常状態
        Matured,   // 満期到達
        Redeemed   // 償還済み
    }

    struct Project {
        uint256 projectId;
        address borrower;
        uint256 targetAmount;
        uint256 raisedAmount;    // 調達済み金額
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        uint256 fundingDeadline; // 資金調達期限
        ProjectStatus status;
        bool isEmergencyPaused;  // 緊急停止フラグ
    }

    struct Investment {
        uint256 investmentId;
        address investor;
        address cryptoAsset;
        uint256 cryptoAmount;
        uint256 usdtAmount;
        uint256 timestamp;
        bool hasInvested;       // 投資済みフラグ
    }

    struct ARCS {
        uint256 tokenId;
        address holder;
        uint256 projectId;
        uint256 amount;
        uint256 issuedAt;
        uint256 maturityDate;
        uint256 annualInterestRate;
        TokenStatus status;
        bool isTransferRestricted; // 譲渡制限フラグ
    }

    struct Redemption {
        uint256 redemptionId;
        uint256 projectId;
        uint256 redeemedAmount;
        uint256 penaltyAmount;
        address redeemer;
        bool canBeRedeemed;
        uint256 redemptionDeadline; // 償還期限
    }

    // P2P市場用の構造体
    struct Order {
        uint256 orderId;
        address seller;
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        uint256 createdAt;
        uint256 expiresAt;    // 注文有効期限
        bool isActive;
    }

    // 買取用の構造体
    struct Buyback {
        uint256 buybackId;
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        address seller;
        uint256 timestamp;
        bool isProcessed;
    }

    // 再販売用の構造体
    struct Resale {
        uint256 resaleId;
        uint256 tokenId;
        uint256 amount;
        uint256 price;
        uint256 listedAt;
        uint256 expiresAt;    // リスティング有効期限
        bool isActive;
    }

    // プロトコル設定用の構造体
    struct ProtocolConfig {
        uint256 maxTargetAmount;      // 最大調達額
        uint256 minInvestmentAmount;  // 最小投資額
        uint256 fundingDuration;      // 資金調達期間
        uint256 orderExpiration;      // 注文有効期限
        uint256 resaleExpiration;     // 再販売有効期限
        uint256 feeRate;              // 取引手数料率
        uint256 buybackRate;          // 買取価格率
        uint256 resaleRate;           // 再販売価格率
        uint256 slippageTolerance;    // スリッページ許容範囲
        uint256 latePenaltyRate;      // 延滞ペナルティ率
    }
}
