// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../storage/Schema.sol";

library Storage {
    function state() internal pure returns (Schema.GlobalState storage s) {
        assembly {
            s.slot := 0x123456789abcdef123456789abcdef123456789abcdef12345678
        }
    }
}
