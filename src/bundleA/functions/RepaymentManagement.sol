// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";

contract RepaymentManagement {
    function processRepayment(uint256 projectId, uint256 amount) external {
        Schema.GlobalState storage $s = Storage.state();
        Schema.Project storage project = $s.projects[projectId];

        require(project.status == Schema.ProjectStatus.Active, "Project is not active");

        distributeInterest(projectId, amount);

        if (amount >= project.targetAmount) {
            project.status = Schema.ProjectStatus.Completed;
        }
    }

    function distributeInterest(uint256 projectId, uint256 amount) internal {
        Schema.GlobalState storage $s = Storage.state();

        for (uint256 i = 0; i < $s.nextTokenId; i++) {
            Schema.ARCS storage arcs = $s.arcsTokens[i];
            if (arcs.projectId == projectId && arcs.status == Schema.TokenStatus.Active) {
                uint256 share = (arcs.amount * amount) / $s.projects[projectId].targetAmount;
                payable(arcs.holder).transfer(share);
            }
        }
    }
}
