// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/bundleA/functions/ARCSResale.sol";
import "../src/bundleA/storage/Storage.sol";

contract ARCSResaleTest is Test {
    ARCSResale resale;
    address admin = address(0x1);
    address buyer = address(0x2);
    uint256 tokenId;

    function setUp() public {
        vm.startPrank(admin);
        resale = new ARCSResale();

        // テスト用のARCSトークンを設定（Assetifyが保有）
        Schema.GlobalState storage $s = Storage.state();
        tokenId = $s.nextTokenId++;

        $s.arcsTokens[tokenId] = Schema.ARCS({
            tokenId: tokenId,
            holder: address(resale),
            projectId: 0,
            amount: 100 ether,
            issuedAt: block.timestamp,
            maturityDate: block.timestamp + 365 days,
            annualInterestRate: 1000, // 10%
            status: Schema.TokenStatus.Active
        });

        vm.stopPrank();
    }

    function testListResaleARCS() public {
        vm.startPrank(admin);

        uint256 amount = 50 ether;
        uint256 price = resale.getResalePrice(tokenId, amount);
        resale.listResaleARCS(tokenId, amount, price);

        // リスティングを確認
        (uint256 resaleId, uint256 listingTokenId, uint256 listingAmount, uint256 listingPrice, bool isAvailable) = resale.resaleOrders(0);
        assertEq(listingTokenId, tokenId);
        assertEq(listingAmount, amount);
        assertEq(listingPrice, price);
        assertTrue(isAvailable);

        vm.stopPrank();
    }

    function testExecuteResalePurchase() public {
        // リスティングを作成
        vm.prank(admin);
        uint256 amount = 50 ether;
        uint256 price = 95 ether; // 95% of principal
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

        // リスティングが無効化されていることを確認
        (, , , , bool isAvailable) = resale.resaleOrders(0);
        assertFalse(isAvailable);
    }

    function testGetResalePrice() public {
        uint256 amount = 50 ether;
        uint256 price = resale.getResalePrice(tokenId, amount);

        // 価格が元本の95%程度であることを確認
        assertGt(price, 45 ether); // > 90%
        assertLt(price, 50 ether); // < 100%
    }

    function testGetResaleListings() public {
        // 複数のリスティングを作成
        vm.startPrank(admin);

        uint256 amount1 = 30 ether;
        uint256 price1 = resale.getResalePrice(tokenId, amount1);
        resale.listResaleARCS(tokenId, amount1, price1);

        uint256 amount2 = 20 ether;
        uint256 price2 = resale.getResalePrice(tokenId, amount2);
        resale.listResaleARCS(tokenId, amount2, price2);

        vm.stopPrank();

        // アクティブなリスティングを取得
        ARCSResale.ResaleOrder[] memory listings = resale.getResaleListings();
        assertEq(listings.length, 2);
    }

    function testSetResaleRate() public {
        vm.prank(admin);
        uint256 newRate = 9000; // 90%

        resale.setResaleRate(newRate);

        assertEq(resale.resaleRate(), newRate);
    }

    function testFail_ListResaleARCSNotAdmin() public {
        vm.prank(buyer);
        resale.listResaleARCS(tokenId, 50 ether, 95 ether);
    }

    function testFail_ExecuteResalePurchaseInvalidAmount() public {
        // リスティングを作成
        vm.prank(admin);
        resale.listResaleARCS(tokenId, 50 ether, 95 ether);

        // 誤った金額で購入を試みる
        vm.deal(buyer, 90 ether);
        vm.prank(buyer);
        resale.executeResalePurchase{value: 90 ether}(0);
    }

    function testFail_SetResaleRateNotAdmin() public {
        vm.prank(buyer);
        resale.setResaleRate(9000);
    }

    function testFail_SetInvalidResaleRate() public {
        vm.prank(admin);
        resale.setResaleRate(11000); // 110% は無効
    }
}
