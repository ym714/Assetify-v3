// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";
import "../../ARCSToken.sol";

contract InvestmentManagement {
    function invest(uint256 projectId, address cryptoAsset, uint256 cryptoAmount) payable external {
        Schema.GlobalState storage $s = Storage.state();
        require($s.projects[projectId].status == Schema.ProjectStatus.Funding, "Project not open for investment");

        uint256 usdtAmount = convertToStable(cryptoAsset, cryptoAmount);
        address tokenAddress = $s.arcsTokens[$s.projects[projectId].tokenId].contractAddress;

        require(usdtAmount == msg.value,"InvestmentManagement: insufficient send amount");
        require(tokenAddress!=address(0), "this project do not have token");

        $s.investments[$s.nextInvestmentId] = Schema.Investment({
            investmentId: $s.nextInvestmentId++,
            investor: msg.sender,
            cryptoAsset: cryptoAsset,
            cryptoAmount: cryptoAmount,
            usdtAmount: usdtAmount,
            timestamp: block.timestamp
        });
        issueTokens(msg.sender, usdtAmount, tokenAddress);
    }

    function convertToStable(address cryptoAsset, uint256 cryptoAmount) internal pure returns (uint256) {
        // 仮実装：固定値 1 USDT に変換
        return cryptoAmount;
    }

    function issueTokens(address investor, uint256 usdtAmount, address tokenAddress) internal {
        ARCS(tokenAddress).mint(investor, usdtAmount);
    }
}
