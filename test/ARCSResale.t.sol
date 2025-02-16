// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/ARCSResale.sol";
import "../src/bundleA/storage/Storage.sol";
import "../src/bundleA/utils/Utils.sol";

contract ARCSResaleTest is Test {
    ARCSResale resale;
    Utils utils;
    address admin = address(0x1);
    address buyer = address(0x2);
    uint256 tokenId;
    uint256 projectId;

    function setUp() public {
        vm.startPrank(admin);

        // コントラクトのデプロイ
        resale = new ARCSResale();
        utils = new Utils();

        // テスト用のデータを設定
        Schema.GlobalState storage $s = Storage.state();

        // プロトコル設定の初期化
        Storage.initialize(
            address(0x1234), // USDT
            address(0x5678), // USDC
            admin            // Oracle
        );

        // テストプロジェクトの作成
        projectId = $s.nextProjectId++;
        $s.projects[projectId] = Schema.Project({
            projectId: projectId,
            borrower: address(0x3),
            targetAmount: 1000 ether,
            raisedAmount: 1000 ether,
            interestRate: 1000, // 10%
            duration: 365 days,
            startTime: block.timestamp,
            fundingDeadline: block.timestamp + 30 days,
            status: Schema.ProjectStatus.Active,
            isEmergencyPaused: false
        });

        // Assetifyが保有するテストトークンの作成
        tokenId = $s.nextTokenId++;
        $s.arcsTokens[tokenId] = Schema.ARCS({
            tokenId: tokenId,
            holder: address(resale),
            projectId: projectId,
            amount: 100 ether,
            issuedAt: block.timestamp,
            maturityDate: block.timestamp + 365 days,
            annualInterestRate: 1000, // 10%
            status: Schema.TokenStatus.Active,
            isTransferRestricted: false
        });

        resale.unpause();
        vm.stopPrank();
    }

    function testListResaleARCS() public {
        vm.startPrank(admin);

        uint256 amount = 50 ether;
        uint256 price = 95 ether; // 95%の価格
        resale.listResaleARCS(tokenId, amount, price);

        Schema.Resale memory listing = resale.getActiveListings()[0];
        assertEq(listing.tokenId, tokenId);
        assertEq(listing.amount, amount);
        assertEq(listing.price, price);
        assertTrue(listing.isActive);

        vm.stopPrank();
    }

    function testExecuteResalePurchase() public {
        // リスティングを作成
        vm.prank(admin);
        uint256 amount = 50 ether;
        uint256 price = 95 ether;
        resale.listResaleARCS(tokenId, amount, price);

        // 購入を実行
        vm.deal(buyer, price);
        vm.prank(buyer);
        resale.executeResalePurchase{value: price}(0);

        // 購入後の状態を確認
        Schema.GlobalState storage $s = Storage.state();
        uint256 newTokenId = tokenId + 1;

        // 新しいトークンが購入者に発行されていることを確認
        assertEq($s.arcsTokens[newTokenId].holder, buyer);
        assertEq($s.arcsTokens[newTokenId].amount, amount);

        // Assetifyの保有量が減少していることを確認
        assertEq($s.arcsTokens[tokenId].amount, 50 ether);

        // リスティングが無効化されていることを確認
        Schema.Resale[] memory activeListings = resale.getActiveListings();
        assertEq(activeListings.length, 0);
    }

    function testBatchListResale() public {
        vm.startPrank(admin);

        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory amounts = new uint256[](2);
        uint256[] memory prices = new uint256[](2);

        tokenIds[0] = tokenId;
        amounts[0] = 30 ether;
        prices[0] = 57 ether;

        tokenIds[1] = tokenId;
        amounts[1] = 20 ether;
        prices[1] = 38 ether;

        resale.batchListResale(tokenIds, amounts, prices);

        Schema.Resale[] memory listings = resale.getActiveListings();
        assertEq(listings.length, 2);
        assertEq(listings[0].amount, 30 ether);
        assertEq(listings[1].amount, 20 ether);

        vm.stopPrank();
    }

    function testGetResalePrice() public {
        uint256 amount = 50 ether;
        uint256 price = resale.getResalePrice(tokenId, amount);

        // 価格が95%になっていることを確認
        uint256 marketPrice = utils.getTWAP(address(this));
        uint256 expectedPrice = (marketPrice * 9500 / 10000) * amount / 1e18;
        assertEq(price, expectedPrice);
    }

    function testCleanupExpiredListings() public {
        vm.startPrank(admin);
        resale.listResaleARCS(tokenId, 50 ether, 95 ether);
        vm.stopPrank();

        // 7日後にスキップ
        vm.warp(block.timestamp + 8 days);
        resale.cleanupExpiredListings();

        Schema.Resale[] memory listings = resale.getActiveListings();
        assertEq(listings.length, 0);
    }

    function testFail_ListResaleARCSNotAdmin() public {
        vm.prank(buyer);
        resale.listResaleARCS(tokenId, 50 ether, 95 ether);
    }

    function testFail_ExecuteResalePurchaseExpiredListing() public {
        vm.prank(admin);
        resale.listResaleARCS(tokenId, 50 ether, 95 ether);

        // 7日後にスキップ
        vm.warp(block.timestamp + 8 days);

        vm.deal(buyer, 95 ether);
        vm.prank(buyer);
        resale.executeResalePurchase{value: 95 ether}(0);
    }

    function testFail_ExecuteResalePurchaseInvalidAmount() public {
        vm.prank(admin);
        resale.listResaleARCS(tokenId, 50 ether, 95 ether);

        vm.deal(buyer, 90 ether);
        vm.prank(buyer);
        resale.executeResalePurchase{value: 90 ether}(0);
    }

    function testPause() public {
        vm.prank(admin);
        resale.pause();

        vm.prank(admin);
        vm.expectRevert("Pausable: paused");
        resale.listResaleARCS(tokenId, 50 ether, 95 ether);
    }

    receive() external payable {}
}
