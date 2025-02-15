// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/RepaymentManagement.sol";
import "../src/bundleA/storage/Storage.sol";

contract RepaymentManagementTest is Test {
    RepaymentManagement repayment;
    address company = address(0xABC);
    address investor1 = address(0x123);
    address investor2 = address(0x456);

    function setUp() public {
        repayment = new RepaymentManagement();

        // テスト用のプロジェクトとトークンを設定
        Schema.GlobalState storage $s = Storage.state();
        $s.projects[0] = Schema.Project({
            projectId: 0,
            borrower: company,
            targetAmount: 1000 ether,
            interestRate: 1000, // 10%
            duration: 365 days,
            startTime: block.timestamp,
            status: Schema.ProjectStatus.Active
        });

        // 2人の投資家にトークンを発行
        $s.arcsTokens[0] = Schema.ARCS({
            tokenId: 0,
            holder: investor1,
            projectId: 0,
            amount: 600 ether, // 60%
            issuedAt: block.timestamp,
            maturityDate: block.timestamp + 365 days,
            annualInterestRate: 1000,
            status: Schema.TokenStatus.Active
        });

        $s.arcsTokens[1] = Schema.ARCS({
            tokenId: 1,
            holder: investor2,
            projectId: 0,
            amount: 400 ether, // 40%
            issuedAt: block.timestamp,
            maturityDate: block.timestamp + 365 days,
            annualInterestRate: 1000,
            status: Schema.TokenStatus.Active
        });
    }

    function testProcessRepayment() public {
        vm.deal(address(this), 100 ether); // テスト用の資金を準備

        repayment.processRepayment(0, 100 ether);

        Schema.GlobalState storage $s = Storage.state();
        assertEq($s.projects[0].status, uint(Schema.ProjectStatus.Active));
    }

    function testCompleteRepayment() public {
        vm.deal(address(this), 1000 ether);

        repayment.processRepayment(0, 1000 ether);

        Schema.GlobalState storage $s = Storage.state();
        assertEq($s.projects[0].status, uint(Schema.ProjectStatus.Completed));
    }

    function testFail_ProcessRepaymentInactiveProject() public {
        Schema.GlobalState storage $s = Storage.state();
        $s.projects[0].status = Schema.ProjectStatus.Completed;

        repayment.processRepayment(0, 100 ether);
    }
}
