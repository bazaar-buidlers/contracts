// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./Items.sol";

contract Catalog is Context {
    using Counters for Counters.Counter;

    // emitted when vendor is changed
    event Vendor(address vendor, uint256 indexed id);
    // emitted when config is changed
    event Config(uint256 config, uint256 indexed id);
    // emitted when uri is changed
    event URI(string uri, uint256 indexed id);

    // product id counter
    Counters.Counter private _counter;
    // mapping of ids to items
    mapping(uint256 => Items.Item) private _items;

    /// @dev List a new item.
    ///
    /// @param config item config mask
    /// @param uri metadata storage location
    ///
    /// @return unique token id
    function list(uint256 config, string calldata uri) external returns (uint256) {
        Items.Item memory item = Items.Item(_msgSender(), config, uri);

        uint256 id = _counter.current();
        _items[id] = item;
        _counter.increment();

        emit Vendor(item.vendor, id);
        emit Config(item.config, id);
        emit URI(item.uri, id);

        return id;
    }

    /// @dev Set the config mask for an item.
    ///
    /// @param id unique item id
    /// @param config item config mask
    function setConfig(uint256 id, uint256 config) external onlyVendor(id) {
        _items[id].config = config;
        emit Config(config, id);
    }

    /// @dev Set the metadata URI for an item.
    ///
    /// @param id unique item id
    /// @param uri item metadata uri
    function setURI(uint256 id, string calldata uri) external onlyVendor(id) {
        _items[id].uri = uri;
        emit URI(uri, id);
    }

    /// @dev Set the vendor address for an item.
    ///
    /// @param id unique item id
    /// @param vendor address of new vendor
    function setVendor(uint256 id, address vendor) external onlyVendor(id) {
        _items[id].vendor = vendor;
        emit Vendor(vendor, id);
    }

    function itemInfo(uint256 id) external view returns (Items.Item memory) {
        return _items[id];
    }

    // modifier to check if sender is vendor
    modifier onlyVendor(uint256 id) {
        require(_items[id].vendor == _msgSender(), "sender is not vendor");
        _;
    }
}