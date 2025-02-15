// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";

contract InvestmentManagement {
    function invest(uint256 projectId, address cryptoAsset, uint256 cryptoAmount) external {
        Schema.GlobalState storage $s = Storage.state();
        require($s.projects[projectId].status == Schema.ProjectStatus.Funding, "Project not open for investment");

        uint256 usdtAmount = convertToStable(cryptoAsset, cryptoAmount);

        $s.investments[$s.nextInvestmentId] = Schema.Investment({
            investmentId: $s.nextInvestmentId++,
            investor: msg.sender,
            cryptoAsset: cryptoAsset,
            cryptoAmount: cryptoAmount,
            usdtAmount: usdtAmount,
            timestamp: block.timestamp
        });

        issueTokens(msg.sender, usdtAmount, projectId);
    }

    function convertToStable(address cryptoAsset, uint256 cryptoAmount) internal pure returns (uint256) {
        // 仮実装：固定値 1 USDT に変換
        return 1 ether;
    }

    function issueTokens(address investor, uint256 usdtAmount, uint256 projectId) internal {
        // 仮実装：トークン発行処理は後で実装
    }
}
