// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library Items {
    // config flag pauses minting
    uint256 constant CONFIG_PAUSED = 1 << 0;
    // config flag enables free mints
    uint256 constant CONFIG_FREE = 1 << 1;
    // config flag disables transfers
    uint256 constant CONFIG_SOULBOUND = 1 << 2;
    // config flag enforces one item per address
    uint256 constant CONFIG_UNIQUE = 1 << 3;

    
    struct Item {
        // vendor address
        address vendor;
        // config mask
        uint256 config;
        // metadata uri
        string uri;
    }

    function isPaused(Item memory item) public pure returns (bool) {
        return item.config & CONFIG_PAUSED != 0;
    }

    function isFree(Item memory item) public pure returns (bool) {
        return item.config & CONFIG_FREE != 0;
    }

    function isSoulbound(Item memory item) public pure returns (bool) {
        return item.config & CONFIG_SOULBOUND != 0;
    }

    function isUnique(Item memory item) public pure returns (bool) {
        return item.config & CONFIG_UNIQUE != 0;
    }
}