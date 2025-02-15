// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";

contract ProjectManagement {
    function createProject(
        address borrower,
        uint256 targetAmount,
        uint256 interestRate,
        uint256 duration
    ) external {
        Schema.GlobalState storage $s = Storage.state();
        uint256 projectId = $s.nextProjectId++;

        $s.projects[projectId] = Schema.Project({
            projectId: projectId,
            tokenId: 0,//ai:ここはissuTokenでtokenIdが付く。 プロジェクト作るタイミングでトークンの発行もした方がいいと思う
            borrower: borrower,
            targetAmount: targetAmount,
            interestRate: interestRate,
            duration: duration,
            startTime: block.timestamp,
            status: Schema.ProjectStatus.Draft
        });
    }
}
