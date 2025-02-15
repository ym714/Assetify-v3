// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";
import "../../ARCSToken.sol";



contract RepaymentManagement {
    function processRepayment(uint256 projectId, uint256 amount) external {
        Schema.GlobalState storage $s = Storage.state();
        Schema.Project storage project = $s.projects[projectId];
        require(project.borrower == msg.sender,"wrong sender");
        //ai: 返済額を実際に支払う処理がいる
        //ai: 利率を加味したamountであるかを計算する処理も！

        require(project.status == Schema.ProjectStatus.Active, "Project is not active");

        distributeInterest(projectId, amount);

        if (amount >= project.targetAmount) {
            project.status = Schema.ProjectStatus.Completed;
        }
    }

    function distributeInterest(uint256 projectId, uint256 amount) internal {
        Schema.GlobalState storage $s = Storage.state();
        Schema.Project storage project = $s.projects[projectId];
        Schema.ARCS storage arcs = $s.arcsTokens[project.tokenId];
        
        ARCS arcsToken = ARCS(arcs.contractAddress);
        address[] memory holders = arcsToken.getHolders();
        
        uint256 totalSupply = arcsToken.totalSupply();
        require(totalSupply > 0, "No token holders");
        
        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            uint256 balance = arcsToken.balanceOf(holder);
            uint256 share = (arcs.amount * balance) / project.targetAmount;
            
            payable(holder).transfer(share);
        }
    }
}
