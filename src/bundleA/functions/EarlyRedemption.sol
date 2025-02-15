// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";
import "../../ARCSToken.sol";



contract EarlyRedemption {
    function executeEarlyRedemption(uint256 projectId, uint256 amount) external {
        Schema.GlobalState storage $s = Storage.state();
        uint256 tokenId = findInvestorTokenId(msg.sender, projectId);

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


    function findInvestorTokenId(address investor, uint256 projectId) internal view returns (uint256 tokenId) {
        Schema.GlobalState storage $s = Storage.state();
        uint256 projectTokenId = $s.projects[projectId].tokenId;
        address tokenAddress = $s.arcsTokens[projectTokenId].contractAddress;
        
        for (uint256 i = 0; i < $s.nextTokenId; i++) {
            ARCS arcsToken = ARCS(tokenAddress);
            address[] memory holders = arcsToken.getHolders();
            
            for (uint256 j = 0; j < holders.length; j++) {
                if (holders[j] == investor) {
                    return i;
                }
            }
        }
        revert("Token not found");
    }
}
