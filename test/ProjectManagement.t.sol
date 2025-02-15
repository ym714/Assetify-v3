// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/ProjectManagement.sol";
import "../src/bundleA/storage/Storage.sol";

contract ProjectManagementTest is Test {
    ProjectManagement project;
    address borrower = address(0x123);

    function setUp() public {
        project = new ProjectManagement();
    }

    function testCreateProject() public {
        project.createProject(borrower, 1000 ether, 500, 365 days);
        Schema.GlobalState storage $s = Storage.state();
        assertEq($s.projects[0].targetAmount, 1000 ether);
    }

    function testFail_InvestBeforeFunding() public {
        project.createProject(borrower, 1000 ether, 500, 365 days);
        project.invest(0, address(0xABC), 10 ether); // Funding 状態でないため失敗
    }
}
