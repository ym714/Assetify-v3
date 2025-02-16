// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";

/// @title Assetify Protocol Storage Management
/// @notice Manages the protocol's storage using ERC-7201 namespaced storage pattern
/// @dev Uses keccak256 for storage slot calculation to prevent storage collisions
library Storage {
    /// @dev Storage slot for the global state
    /// @notice Calculated using ERC-7201 namespaced storage pattern
    bytes32 private constant STORAGE_SLOT = bytes32(uint256(
        keccak256("assetify.storage.globalstate")) - 1
    );

    /// @dev Returns the global state storage
    /// @return s The GlobalState struct stored at the calculated slot
    function state() internal pure returns (Schema.GlobalState storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }

    /// @dev Initializes the global state
    /// @param usdtAddress The address of the USDT contract
    /// @param usdcAddress The address of the USDC contract
    /// @param oracleAddress The address of the price oracle
    function initialize(
        address usdtAddress,
        address usdcAddress,
        address oracleAddress
    ) internal {
        Schema.GlobalState storage $s = state();
        require(!$s.initialized, "Storage: already initialized");

        $s.usdtAddress = usdtAddress;
        $s.usdcAddress = usdcAddress;
        $s.oracleAddress = oracleAddress;

        // プロトコル設定の初期化
        $s.protocolConfig = Schema.ProtocolConfig({
            maxTargetAmount: 1_000_000 ether,     // 最大調達額: 100万USDT
            minInvestmentAmount: 100 ether,       // 最小投資額: 100USDT
            fundingDuration: 30 days,             // 資金調達期間: 30日
            orderExpiration: 7 days,              // 注文有効期限: 7日
            resaleExpiration: 7 days,             // 再販売有効期限: 7日
            feeRate: 50,                          // 取引手数料: 0.5%
            buybackRate: 9000,                    // 買取価格: 90%
            resaleRate: 9500,                     // 再販売価格: 95%
            slippageTolerance: 150,              // スリッページ許容範囲: ±15%
            latePenaltyRate: 500                 // 延滞ペナルティ: 5%
        });

        $s.initialized = true;
    }

    /// @dev Checks if the contract is initialized
    /// @return bool True if initialized, false otherwise
    function isInitialized() internal view returns (bool) {
        return state().initialized;
    }

    /// @dev Gets the protocol configuration
    /// @return Schema.ProtocolConfig The current protocol configuration
    function getConfig() internal view returns (Schema.ProtocolConfig storage) {
        return state().protocolConfig;
    }

    /// @dev Updates the protocol configuration
    /// @param newConfig The new configuration to set
    function updateConfig(Schema.ProtocolConfig memory newConfig) internal {
        Schema.GlobalState storage $s = state();
        require($s.initialized, "Storage: not initialized");

        $s.protocolConfig = newConfig;
    }

    /// @dev Gets the user's token IDs
    /// @param user The address of the user
    /// @return uint256[] Array of token IDs owned by the user
    function getUserTokens(address user) internal view returns (uint256[] storage) {
        return state().userTokens[user];
    }

    /// @dev Gets the project IDs associated with an ARCS token
    /// @param tokenId The ID of the ARCS token
    /// @return uint256[] Array of project IDs associated with the token
    function getTokenProjects(uint256 tokenId) internal view returns (uint256[] storage) {
        return state().arcsToProjects[tokenId];
    }
}
