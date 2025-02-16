// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";
import "../storage/Storage.sol";

contract ARCSBuyback {
    uint256 public buybackRate = 9000; // 90% 買取価格
    address public admin;

    event ARCSBought(uint256 indexed tokenId, address indexed seller, uint256 amount, uint256 price);
    event FundsWithdrawn(address indexed to, uint256 amount);
    event BuybackRateChanged(uint256 newRate);

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "ARCSBuyback: caller is not admin");
        _;
    }

    function sellARCS(uint256 tokenId, uint256 amount) external {
        Schema.GlobalState storage $s = Storage.state();
        require($s.arcsTokens[tokenId].holder == msg.sender, "ARCSBuyback: not the owner");
        require($s.arcsTokens[tokenId].amount >= amount, "ARCSBuyback: insufficient ARCS balance");
        require($s.arcsTokens[tokenId].status == Schema.TokenStatus.Active, "ARCSBuyback: token not active");

        uint256 buybackPrice = getBuybackPrice(tokenId, amount);
        require(address(this).balance >= buybackPrice, "ARCSBuyback: insufficient contract balance");

        // トークンの所有権を Assetify に移転
        $s.arcsTokens[tokenId].amount -= amount;

        // 新しいトークンを Assetify 用に発行
        uint256 newTokenId = $s.nextTokenId++;
        $s.arcsTokens[newTokenId] = Schema.ARCS({
            tokenId: newTokenId,
            holder: address(this),
            projectId: $s.arcsTokens[tokenId].projectId,
            amount: amount,
            issuedAt: $s.arcsTokens[tokenId].issuedAt,
            maturityDate: $s.arcsTokens[tokenId].maturityDate,
            annualInterestRate: $s.arcsTokens[tokenId].annualInterestRate,
            status: Schema.TokenStatus.Active
        });

        // 支払いを実行
        payable(msg.sender).transfer(buybackPrice);

        emit ARCSBought(tokenId, msg.sender, amount, buybackPrice);
    }

    function getBuybackPrice(uint256 tokenId, uint256 amount) public view returns (uint256) {
        Schema.GlobalState storage $s = Storage.state();
        Schema.ARCS memory arcs = $s.arcsTokens[tokenId];

        // 基本価値（元本 + 経過利息）を計算
        uint256 principal = amount;
        uint256 timeElapsed = block.timestamp - arcs.issuedAt;
        uint256 interest = (principal * arcs.annualInterestRate * timeElapsed) / (365 days * 10000);
        uint256 baseValue = principal + interest;

        // 買取価格（90%）を計算
        return (baseValue * buybackRate) / 10000;
    }

    function withdrawFunds(address to, uint256 amount) external onlyAdmin {
        require(to != address(0), "ARCSBuyback: invalid address");
        require(amount <= address(this).balance, "ARCSBuyback: insufficient balance");

        payable(to).transfer(amount);
        emit FundsWithdrawn(to, amount);
    }

    function setBuybackRate(uint256 newRate) external onlyAdmin {
        require(newRate <= 10000, "ARCSBuyback: invalid rate");
        buybackRate = newRate;
        emit BuybackRateChanged(newRate);
    }

    function getTotalBuybackedARCS() external view returns (uint256) {
        Schema.GlobalState storage $s = Storage.state();
        uint256 total = 0;

        for (uint256 i = 0; i < $s.nextTokenId; i++) {
            if ($s.arcsTokens[i].holder == address(this)) {
                total += $s.arcsTokens[i].amount;
            }
        }

        return total;
    }

    receive() external payable {}
}
