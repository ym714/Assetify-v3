// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";

contract EarlyRedemption {
    function executeEarlyRedemption(uint256 projectId, uint256 amount) external {
        Schema.GlobalState storage $s = Storage.state();
        uint256 tokenId = findInvestorTokenId(msg.sender);

        require(tokenId != 0, "Token not found");
        require($s.arcsTokens[tokenId].amount >= amount, "Insufficient ARCS balance");

        uint256 penalty = (amount * 10) / 100; // 10%のペナルティ
        uint256 redemptionAmount = amount - penalty;

        $s.redemptions[$s.nextRedemptionId++] = Schema.Redemption({
            redemptionId: $s.nextRedemptionId,
            projectId: projectId,
            redeemedAmount: redemptionAmount,
            penaltyAmount: penalty,
            redeemer: msg.sender,
            canBeRedeemed: true
        });

        payable(msg.sender).transfer(redemptionAmount);
    }

    function findInvestorTokenId(address investor) internal view returns (uint256) {
        Schema.GlobalState storage $s = Storage.state();
        for (uint256 i = 0; i < $s.nextTokenId; i++) {
            if ($s.arcsTokens[i].holder == investor) {
                return i;
            }
        }
        return 0;
    }
}
