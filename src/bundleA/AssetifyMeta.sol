// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./functions/ProjectManagement.sol";
import "./functions/InvestmentManagement.sol";
import "./functions/TokenManagement.sol";
import "./functions/RepaymentManagement.sol";
import "./functions/EarlyRedemption.sol";
import "./functions/P2PMarket.sol";
import "./utils/Utils.sol";
import "./storage/Storage.sol";

/// @title Assetify Meta Contract
/// @notice This contract serves as the main entry point for the Assetify protocol
/// @dev Integrates all protocol functionalities into a single interface
contract AssetifyMeta {
    address public owner;
    ProjectManagement public projectManagement;
    InvestmentManagement public investmentManagement;
    TokenManagement public tokenManagement;
    RepaymentManagement public repaymentManagement;
    EarlyRedemption public earlyRedemption;
    P2PMarket public p2pMarket;
    Utils public utils;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event ProjectCreated(uint256 indexed projectId, address borrower, uint256 targetAmount);
    event InvestmentMade(uint256 indexed projectId, address investor, uint256 amount);
    event RepaymentProcessed(uint256 indexed projectId, uint256 amount);
    event EarlyRedemptionExecuted(uint256 indexed projectId, address redeemer, uint256 amount);
    event P2PTradeExecuted(uint256 indexed orderId, address buyer, uint256 amount);

    constructor() {
        owner = msg.sender;
        projectManagement = new ProjectManagement();
        investmentManagement = new InvestmentManagement();
        tokenManagement = new TokenManagement();
        repaymentManagement = new RepaymentManagement();
        earlyRedemption = new EarlyRedemption();
        p2pMarket = new P2PMarket();
        utils = new Utils();
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "AssetifyMeta: caller is not the owner");
        _;
    }

    /// @notice Transfer ownership of the contract
    /// @param newOwner Address of the new owner
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "AssetifyMeta: new owner is the zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /// @notice Create a new funding project
    /// @param borrower Address of the borrower
    /// @param targetAmount Total funding amount needed
    /// @param interestRate Annual interest rate (in basis points)
    /// @param duration Project duration in seconds
    function createProject(
        address borrower,
        uint256 targetAmount,
        uint256 interestRate,
        uint256 duration
    ) external onlyOwner {
        projectManagement.createProject(borrower, targetAmount, interestRate, duration);
        emit ProjectCreated(Storage.state().nextProjectId - 1, borrower, targetAmount);
    }

    /// @notice Invest in a project
    /// @param projectId ID of the project
    /// @param cryptoAsset Address of the crypto asset (BTC/ETH)
    /// @param cryptoAmount Amount of crypto to invest
    function invest(
        uint256 projectId,
        address cryptoAsset,
        uint256 cryptoAmount
    ) external payable {
        investmentManagement.invest(projectId, cryptoAsset, msg.value);
        emit InvestmentMade(projectId, msg.sender, cryptoAmount);
    }

    /// @notice Process repayment from borrower
    /// @param projectId ID of the project
    /// @param amount Repayment amount
    function executeRepayment(uint256 projectId, uint256 amount) external {
        repaymentManagement.processRepayment(projectId, amount);
        emit RepaymentProcessed(projectId, amount);
    }

    /// @notice Execute early redemption of ARCS tokens
    /// @param projectId ID of the project
    /// @param amount Amount of ARCS to redeem
    function redeemEarly(uint256 projectId, uint256 amount) external {
        earlyRedemption.executeEarlyRedemption(projectId, amount);
        emit EarlyRedemptionExecuted(projectId, msg.sender, amount);
    }

    /// @notice Execute P2P trade
    /// @param orderId ID of the sell order
    function tradeP2P(uint256 orderId) external payable {
        p2pMarket.executePurchase{value: msg.value}(orderId);
        emit P2PTradeExecuted(orderId, msg.sender, msg.value);
    }

    /// @notice Calculate interest for ARCS tokens
    /// @param projectId ID of the project
    /// @return Interest amount
    function calculateInterest(uint256 projectId) external view returns (uint256) {
        return tokenManagement.calculateInterest(msg.sender, projectId);
    }

    /// @notice Get price of crypto asset in USDT/USDC
    /// @param cryptoAsset Address of the crypto asset
    /// @return Price in USDT/USDC
    function getPrice(address cryptoAsset) external view returns (uint256) {
        return utils.convertToStable(cryptoAsset, 1 ether);
    }

    /// @notice Create sell order in P2P market
    /// @param arcsAmount Amount of ARCS to sell
    /// @param price Selling price
    /// @param projectId ID of the project
    function createSellOrder(
        uint256 arcsAmount,
        uint256 price,
        uint256 projectId
    ) external {
        p2pMarket.createSellOrder(arcsAmount, price, projectId);
    }

    /// @notice Get project details
    /// @param projectId ID of the project
    /// @return Project details
    function getProject(uint256 projectId) external view returns (Schema.Project memory) {
        return Storage.state().projects[projectId];
    }

    /// @notice Get investment details
    /// @param investmentId ID of the investment
    /// @return Investment details
    function getInvestment(uint256 investmentId) external view returns (Schema.Investment memory) {
        return Storage.state().investments[investmentId];
    }
}
