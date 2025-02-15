// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/// @custom:storage-location erc7201:assetify.globalstate
library Schema {
    struct GlobalState {
        mapping(uint256 => Project) projects;
        mapping(uint256 => Investment) investments;
        mapping(uint256 => ARCS) arcsTokens;
        mapping(uint256 => Redemption) redemptions;
        uint256 nextProjectId;
        uint256 nextInvestmentId;
        uint256 nextTokenId;
        uint256 nextRedemptionId;
        address usdtAddress;
        address usdcAddress;
        bool initialized;
    }

    enum ProjectStatus { Draft, ReadyToFund, Funding, Active, Completed, Defaulted }
    enum TokenStatus { Active, Matured, Redeemed }

    struct Project {
        uint256 projectId;
        uint256 tokenId;
        address borrower;
        uint256 targetAmount;
        uint256 interestRate;
        uint256 duration;
        uint256 startTime;
        ProjectStatus status;
    }

    struct Investment {
        uint256 investmentId;
        address investor;
        address cryptoAsset;
        uint256 cryptoAmount;
        uint256 usdtAmount;
        uint256 timestamp;
    }

    struct ARCS {
        uint256 tokenId;
        uint256 projectId;
        uint256 amount;
        uint256 issuedAt;
        uint256 maturityDate;
        uint256 annualInterestRate;
        address contractAddress;
        TokenStatus status;
    }

    struct Redemption {
        uint256 redemptionId;
        uint256 projectId;
        uint256 redeemedAmount;
        uint256 penaltyAmount;
        address redeemer;
        bool canBeRedeemed;
    }
}
