// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";
import "../../ARCSToken.sol";

contract TokenManagement {
    event TokenIssued(uint256 tokenId, address tokenAddress, address investor, uint256 amount);

    function issueTokens(
        address investor,
        uint256 usdtAmount,
        uint256 projectId
    ) external payable {
        require(msg.value > 0, "Native token payment required");
        require(usdtAmount >= msg.value, "usdtAmount must be equal or greater than native token value sent");

        Schema.GlobalState storage $s = Storage.state();
        uint256 tokenId = $s.nextTokenId++;
        $s.projects[projectId].tokenId = tokenId;
        require($s.projects[projectId].tokenId==0,"there is already token");

        ARCS token = new ARCS("ARCS", "ARCS");//発行されるtokenとnameは企業が決めたらいいと思う
        token.mint(investor, usdtAmount);

        uint256 interestRate = $s.projects[projectId].interestRate;

        $s.arcsTokens[tokenId] = Schema.ARCS({
            tokenId: tokenId,
            projectId: projectId,
            amount: usdtAmount,
            issuedAt: block.timestamp,
            maturityDate: block.timestamp + 365 days, // 1年満期
            annualInterestRate: interestRate,
            status: Schema.TokenStatus.Active,
            contractAddress: address(token)
        });

        emit TokenIssued(tokenId, address(token), investor, usdtAmount);
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
        address tokenAddress = $s.arcsTokens[tokenId].contractAddress;
        ARCS(tokenAddress).burn(investor, amount);

        $s.arcsTokens[tokenId].amount -= amount;
        if ($s.arcsTokens[tokenId].amount == 0) {
            $s.arcsTokens[tokenId].status = Schema.TokenStatus.Redeemed;
        }
    }

    function findInvestorTokenId(address investor) internal view returns (uint256 tokenId) {
        Schema.GlobalState storage $s = Storage.state();
        
        for (uint256 i = 0; i < $s.nextTokenId; i++) {
            address tokenAddress = $s.arcsTokens[i].contractAddress;
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
