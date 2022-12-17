// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./Items.sol";

contract Bazaar is Ownable2Step, ERC1155URIStorage, ERC2981 {
    using Address for address payable;
    using Counters for Counters.Counter;
    using Items for Items.Item;

    // protocol fee basis points numerator
    uint96 constant FEE_NUMERATOR = 250;
    // protocol fee basis points denominator
    uint96 constant FEE_DENOMINATOR = 10000;

    // emitted when item vendor is changed
    event VendorChanged(uint256 id, address vendor);
    // emitted when item limit is changed
    event LimitChanged(uint256 id, uint256 limit);
    // emitted when item config is changed
    event ConfigChanged(uint256 id, uint256 config);
    // emitted when item price is changed
    event PriceChanged(uint256 id, IERC20 erc20, uint256 price);
    // emitted when funds are deposited
    event Deposited(address payee, IERC20 erc20, uint256 amount);
    // emitted when funds are withdrawn
    event Withdrawn(address payee, IERC20 erc20, uint256 amount);

    // token id counter
    Counters.Counter private _counter;
    // mapping of token ids to item settings
    mapping(uint256 => Items.Item) private _items;
    // mapping of token ids to mapping of erc20 to prices
    mapping(uint256 => mapping(IERC20 => uint256)) private _prices;
    // mapping of address to mapping of erc20 to deposits
    mapping(address => mapping(IERC20 => uint256)) private _deposits;

    constructor() ERC1155("") {}

    /// @dev List an item for sale.
    function list(uint256 limit, uint256 config, string calldata tokenURI) external returns (uint256) {
        Items.Item memory item = Items.Item(_msgSender(), 0, limit, config);

        uint256 id = _counter.current();
        _items[id] = item;
        _setURI(id, tokenURI);
        _counter.increment();

        emit VendorChanged(id, item.vendor);
        emit LimitChanged(id, item.limit);
        emit ConfigChanged(id, item.config);

        return id;
    }

    /// @dev Mint an item.
    function mint(address to, uint256 id, IERC20 erc20) external payable {
        Items.Item storage item = _items[id];

        require(!item.isPaused(), "minting is paused");
        require(!item.isUnique() || balanceOf(to, id) == 0, "item is unique");
        require(item.supply < item.limit, "mint limit reached");

        if (item.isFree() || _msgSender() == item.vendor) {
            return _mint(to, id, 1, "");
        }

        uint256 price = _prices[id][erc20];
        require(price > 0, "invalid currency");

        uint256 fee = (price * FEE_NUMERATOR) / FEE_DENOMINATOR;
        _deposit(item.vendor, erc20, price - fee);
        _deposit(owner(), erc20, fee);
        _mint(to, id, 1, "");

        if (address(erc20) == address(0)) {
            require(msg.value >= price, "value too low");
        } else {
            require(erc20.transferFrom(_msgSender(), address(this), price), "transfer failed");
        }
    }

    /// @dev Withdraw deposits.
    function withdraw(address payable payee, IERC20 erc20) external {
        uint256 amount = _deposits[_msgSender()][erc20];
        require(amount > 0, "nothing to withdraw");

        _deposits[_msgSender()][erc20] = 0;
        emit Withdrawn(_msgSender(), erc20, amount);

        if (address(erc20) == address(0)) {
            payee.sendValue(amount);
        } else {
            require(erc20.transfer(payee, amount), "transfer failed");
        }
    }

    /// @dev Set the config mask for an item.
    function setConfig(uint256 id, uint256 config) external onlyVendor(id) {
        _items[id].setConfig(config);
        emit ConfigChanged(id, config);
    }

    /// @dev Set the limit for maximum number of mints of an item.
    function setLimit(uint256 id, uint256 limit) external onlyVendor(id) {
        _items[id].setLimit(limit);
        emit LimitChanged(id, limit);
    }

    /// @dev Set the vendor address for an item.
    function setVendor(uint256 id, address vendor) external onlyVendor(id) {
        _items[id].setVendor(vendor);
        emit VendorChanged(id, vendor);
    }

    /// @dev Set the mint price in the specified currency.
    function setPrice(uint256 id, IERC20 erc20, uint256 price) external onlyVendor(id) {
        _setPrice(id, erc20, price);
        emit PriceChanged(id, erc20, price);
    }

    /// @dev Set the URI for an item.
    function setURI(uint256 id, string calldata tokenURI) external onlyVendor(id) {
        _setURI(id, tokenURI);
    }

    /// @dev Set the royalty receiver and basis points for an item.
    function setRoyalty(uint256 id, address receiver, uint96 fee) external onlyVendor(id) {
        _setTokenRoyalty(id, receiver, fee);
    }

    /// @dev Returns the price of an item in the specified currency.
    function priceInfo(uint256 id, IERC20 erc20) external view returns (uint256) {
        return _prices[id][erc20];
    }

    /// @dev Returns info about the specified item.
    function itemInfo(uint256 id) external view returns (Items.Item memory) {
        return _items[id];
    }

    /////////////////
    /// Modifiers ///
    /////////////////

    modifier onlyVendor(uint256 id) {
        require(_items[id].vendor == _msgSender(), "sender is not vendor");
        _;
    }

    ////////////////
    /// Internal ///
    ////////////////

    function _setPrice(uint256 id, IERC20 erc20, uint256 price) internal {
        _prices[id][erc20] = price;
        emit PriceChanged(id, erc20, price);
    }

    function _deposit(address payee, IERC20 erc20, uint256 amount) internal {
        _deposits[payee][erc20] += amount;
        emit Deposited(payee, erc20, amount);
    }

    /////////////////
    /// Overrides ///
    /////////////////

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        if (from == address(0)) {
            // update supplies when minting
            for (uint256 i = 0; i < ids.length; ++i) {
                Items.Item storage item = _items[ids[i]];
                unchecked { item.supply += amounts[i]; }
            }
        } else {
            // check if soulbound when transferring
            for (uint256 i = 0; i < ids.length; ++i) {
                Items.Item storage item = _items[ids[i]];
                require(!item.isSoulbound(), "item is soulbound");
            }
        }
    }
}
