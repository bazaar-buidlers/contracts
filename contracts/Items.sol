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

    // item settings
    struct Item {
        // vendor address
        address vendor;
        // count of minted items
        uint256 supply;
        // maximum mint limit
        uint256 limit;
        // config mask
        uint256 config;
        // token uri
        string uri;
    }

    function setConfig(Item storage item, uint256 config) internal {
        item.config = config;
    }

    function setURI(Item storage item, string memory uri) internal {
        item.uri = uri;
    }

    function setVendor(Item storage item, address vendor) internal {
        require(vendor != address(0), "invalid vendor address");
        item.vendor = vendor;
    }

    function setLimit(Item storage item, uint256 limit) internal {
        require(limit >= item.supply, "limit too low");
        item.limit = limit;
    }

    function addSupply(Item storage item, uint256 amount) internal {
        require(item.supply + amount <= item.limit, "limit reached");
        item.supply += amount;
    }

    function isPaused(Item storage item) internal view returns (bool) {
        return item.config & CONFIG_PAUSED != 0;
    }

    function isFree(Item storage item) internal view returns (bool) {
        return item.config & CONFIG_FREE != 0;
    }

    function isSoulbound(Item storage item) internal view returns (bool) {
        return item.config & CONFIG_SOULBOUND != 0;
    }

    function isUnique(Item storage item) internal view returns (bool) {
        return item.config & CONFIG_UNIQUE != 0;
    }
}