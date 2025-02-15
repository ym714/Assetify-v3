// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";

contract TokenManagement {
    function issueTokens(address investor, uint256 usdtAmount, uint256 projectId) internal {
        Schema.GlobalState storage $s = Storage.state();
        uint256 tokenId = $s.nextTokenId++;

        $s.arcsTokens[tokenId] = Schema.ARCS({
            tokenId: tokenId,
            holder: investor,
            projectId: projectId,
            amount: usdtAmount,
            issuedAt: block.timestamp,
            maturityDate: block.timestamp + 365 days, // 1年満期
            annualInterestRate: 1000, // 10% の利回り
            status: Schema.TokenStatus.Active
        });
    }

    function calculateInterest(address investor, uint256 projectId) public view returns (uint256) {
        Schema.GlobalState storage $s = Storage.state();
        Schema.ARCS memory arcs = $s.arcsTokens[projectId];

        uint256 timeElapsed = block.timestamp - arcs.issuedAt;
        uint256 interest = (arcs.amount * arcs.annualInterestRate * timeElapsed) / (365 days * 10000);
        return interest;
    }

    function burnTokens(address investor, uint256 amount) internal {
        Schema.GlobalState storage $s = Storage.state();
        uint256 tokenId = findInvestorTokenId(investor);
        require(tokenId != 0, "Token not found");

        $s.arcsTokens[tokenId].amount -= amount;
        if ($s.arcsTokens[tokenId].amount == 0) {
            $s.arcsTokens[tokenId].status = Schema.TokenStatus.Redeemed;
        }
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
