// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "./Items.sol";

/// @title The digital bazaar
contract Bazaar is Ownable2Step, ERC1155, ERC2981 {
    using Address for address payable;
    using Counters for Counters.Counter;
    using Items for Items.Item;

    // emitted when item vendor is changed
    event VendorChanged(uint256 id, address vendor);
    // emitted when item limit is changed
    event LimitChanged(uint256 id, uint256 limit);
    // emitted when item config is changed
    event ConfigChanged(uint256 id, uint256 config);
    // emitted when token URI is changed
    event URIChanged(uint256 id, string uri);
    // emitted when item price is changed
    event PriceChanged(uint256 id, IERC20 erc20, uint256 price);
    // emitted when funds are deposited
    event Deposited(address payee, IERC20 erc20, uint256 amount);
    // emitted when funds are withdrawn
    event Withdrawn(address payee, IERC20 erc20, uint256 amount);

    // protocol fee basis points numerator
    uint96 public immutable feeNumerator;
    // protocol fee basis points denominator
    uint96 public immutable feeDenominator;

    // token id counter
    Counters.Counter private _counter;
    // mapping of token ids to item settings
    mapping(uint256 => Items.Item) private _items;
    // mapping of token ids to mapping of erc20 to prices
    mapping(uint256 => mapping(IERC20 => uint256)) private _prices;
    // mapping of address to mapping of erc20 to deposits
    mapping(address => mapping(IERC20 => uint256)) private _deposits;

    /// @dev Creates a new Bazaar.
    ///
    /// @param numerator protocol fee numerator
    /// @param denominator protocol fee denominator
    constructor(uint96 numerator, uint96 denominator) ERC1155("") {
        require(numerator <= denominator, "invalid protocol fee");
        feeNumerator = numerator;
        feeDenominator = denominator;
    }

    /// @dev List an item for sale.
    ///
    /// @param limit maximum number of mints
    /// @param config item configuration mask
    /// @param tokenURI metadata storage location
    ///
    /// @return unique token id
    function list(uint256 limit, uint256 config, string calldata tokenURI) external returns (uint256) {
        Items.Item memory item = Items.Item(_msgSender(), 0, limit, config, tokenURI);

        uint256 id = _counter.current();
        _items[id] = item;
        _counter.increment();

        emit VendorChanged(id, item.vendor);
        emit LimitChanged(id, item.limit);
        emit ConfigChanged(id, item.config);
        emit URIChanged(id, item.uri);

        return id;
    }

    /// @dev Mint an item.
    ///
    /// @param to recipient address
    /// @param id unique token id
    /// @param erc20 currency address
    function mint(address to, uint256 id, IERC20 erc20) external payable {
        Items.Item storage item = _items[id];

        require(!item.isPaused(), "minting is paused");
        require(!item.isUnique() || balanceOf(to, id) == 0, "item is unique");

        if (item.isFree() || _msgSender() == item.vendor) {
            return _mint(to, id, 1, "");
        }

        uint256 price = _prices[id][erc20];
        require(price > 0, "invalid currency");

        uint256 fee = (price * feeNumerator) / feeDenominator;
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
    ///
    /// @param payee address to withdraw to
    /// @param erc20 currency address
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

    /// @dev Update pricing of an item.
    ///
    /// @param id unique token id
    /// @param erc20s list of currencies
    /// @param prices list of prices
    function appraise(uint256 id, IERC20[] calldata erc20s, uint256[] calldata prices) external onlyVendor(id) {
        require(erc20s.length == prices.length, "mismatched erc20 and price");

        for (uint256 i = 0; i < erc20s.length; ++i) {
            _appraise(id, erc20s[i], prices[i]);
        }
    }

    /// @dev Set the config mask for an item.
    ///
    /// @param id unique token id
    /// @param config configuration mask
    function setConfig(uint256 id, uint256 config) external onlyVendor(id) {
        _items[id].setConfig(config);
        emit ConfigChanged(id, config);
    }

    /// @dev Set the token URI for an item.
    ///
    /// @param id unique token id
    /// @param tokenURI token URI
    function setURI(uint256 id, string calldata tokenURI) external onlyVendor(id) {
        _items[id].setURI(tokenURI);
        emit URIChanged(id, tokenURI);
    }

    /// @dev Set the maximum number of mints of an item.
    ///
    /// @param id unique token id
    /// @param limit maximum mint limit
    function setLimit(uint256 id, uint256 limit) external onlyVendor(id) {
        _items[id].setLimit(limit);
        emit LimitChanged(id, limit);
    }

    /// @dev Set the vendor address for an item.
    ///
    /// @param id unique token id
    /// @param vendor new vendor address
    function setVendor(uint256 id, address vendor) external onlyVendor(id) {
        _items[id].setVendor(vendor);
        emit VendorChanged(id, vendor);
    }

    /// @dev Set the royalty receiver and fee for an item.
    ///
    /// @param id unique token id
    /// @param receiver address of royalty recipient
    /// @param fee numerator of royalty fee
    function setRoyalty(uint256 id, address receiver, uint96 fee) external onlyVendor(id) {
        _setTokenRoyalty(id, receiver, fee);
    }

    /// @dev Returns the price of an item in the specified currency.
    ///
    /// @param id unique token id
    /// @param erc20 currency address
    ///
    /// @return price of the item in the specified currency
    function priceInfo(uint256 id, IERC20 erc20) external view returns (uint256) {
        return _prices[id][erc20];
    }

    /// @dev Returns info about the specified item.
    ///
    /// @param id unique token id
    ///
    /// @return item config, limit, supply, and vendor
    function itemInfo(uint256 id) external view returns (Items.Item memory) {
        return _items[id];
    }

    /// @dev Returns the total supply of the specified item.
    ///
    /// @param id unique token id
    ///
    /// @return total number of minted items
    function totalSupply(uint256 id) external view returns (uint256) {
        return _items[id].supply;
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

    function _appraise(uint256 id, IERC20 erc20, uint256 price) internal {
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

    function uri(uint256 id) public view override returns (string memory) {
        return _items[id].uri;
    }

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
            // update supply when minting
            for (uint256 i = 0; i < ids.length; ++i) {
                Items.Item storage item = _items[ids[i]];
                item.addSupply(amounts[i]);
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
