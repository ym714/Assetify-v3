// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/AssetifyMeta.sol";

contract AssetifyMetaTest is Test {
    AssetifyMeta meta;
    address owner = address(0x1);
    address borrower = address(0x2);
    address investor = address(0x3);

    function setUp() public {
        vm.prank(owner);
        meta = new AssetifyMeta();
    }

    function testCreateProject() public {
        vm.prank(owner);
        meta.createProject(borrower, 1000 ether, 1000, 365 days);

        Schema.Project memory project = meta.getProject(0);
        assertEq(project.borrower, borrower);
        assertEq(project.targetAmount, 1000 ether);
    }

    function testInvest() public {
        // プロジェクトを作成
        vm.prank(owner);
        meta.createProject(borrower, 1000 ether, 1000, 365 days);

        // 投資を実行
        vm.prank(investor);
        meta.invest(0, address(0x123), 10 ether);

        Schema.Investment memory investment = meta.getInvestment(0);
        assertEq(investment.investor, investor);
        assertEq(investment.cryptoAmount, 10 ether);
    }

    function testEarlyRedemption() public {
        // プロジェクトを作成
        vm.prank(owner);
        meta.createProject(borrower, 1000 ether, 1000, 365 days);

        // 投資を実行
        vm.prank(investor);
        meta.invest(0, address(0x123), 10 ether);

        // 早期償還を実行
        vm.prank(investor);
        meta.redeemEarly(0, 5 ether);
    }

    function testP2PTrade() public {
        // プロジェクトを作成
        vm.prank(owner);
        meta.createProject(borrower, 1000 ether, 1000, 365 days);

        // 投資を実行
        vm.prank(investor);
        meta.invest(0, address(0x123), 10 ether);

        // 売り注文を作成
        vm.prank(investor);
        meta.createSellOrder(5 ether, 100 ether, 0);

        // 購入を実行
        address buyer = address(0x4);
        vm.deal(buyer, 100 ether);
        vm.prank(buyer);
        meta.tradeP2P{value: 100 ether}(0);
    }

    function testCalculateInterest() public {
        // プロジェクトを作成
        vm.prank(owner);
        meta.createProject(borrower, 1000 ether, 1000, 365 days);

        // 投資を実行
        vm.prank(investor);
        meta.invest(0, address(0x123), 10 ether);

        // 1年後をシミュレート
        vm.warp(block.timestamp + 365 days);

        vm.prank(investor);
        uint256 interest = meta.calculateInterest(0);
        assertGt(interest, 0);
    }

    function testFail_CreateProjectNotOwner() public {
        vm.prank(investor);
        meta.createProject(borrower, 1000 ether, 1000, 365 days);
    }

    function testTransferOwnership() public {
        address newOwner = address(0x5);

        vm.prank(owner);
        meta.transferOwnership(newOwner);

        assertEq(meta.owner(), newOwner);
    }

    function testFail_TransferOwnershipNotOwner() public {
        address newOwner = address(0x5);

        vm.prank(investor);
        meta.transferOwnership(newOwner);
    }
}
