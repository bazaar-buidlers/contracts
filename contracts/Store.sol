// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Store is Ownable, ERC1155URIStorage, ERC2981 {
    using Address for address payable;

    // config flag enables free mints
    uint256 constant CONFIG_FREE = 1 << 0;
    // config flag disables transfers
    uint256 constant CONFIG_SOULBOUND = 1 << 1;
    // config flag enforces one item per address
    uint256 constant CONFIG_UNIQUE = 1 << 2;

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

    // mapping of token ids to item settings
    mapping(uint256 => Item) private _items;
    // mapping of token ids to mapping of erc20 to prices
    mapping(uint256 => mapping(IERC20 => uint256)) private _prices;
    // mapping of address to mapping of erc20 to deposits
    mapping(address => mapping(IERC20 => uint256)) private _deposits;

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
    }

    constructor() ERC1155("") {}

    /**
     * @dev List an item.
     */
    function list(
        uint256 id,
        uint256 limit,
        uint256 config,
        string calldata tokenURI
    ) external {
        require(_items[id].vendor == address(0), "id is taken");
        _setVendor(id, _msgSender());
        _setURI(id, tokenURI);
        _setLimit(id, limit);
        _setConfig(id, config);
    }

    /**
     * @dev Mint an item.
     */
    function mint(
        address to,
        uint256 id,
        IERC20 erc20,
        address affiliate
    ) external payable {
        Item memory item = _items[id];
        uint256 price = _prices[id][erc20];

        require(item.supply < item.limit, "supply limit reached");
        require(item.config & CONFIG_FREE != 0 || price > 0, "invalid currency");
        require(item.config & CONFIG_UNIQUE == 0 || balanceOf(to, id) == 0, "item is unique");

        if (price > 0) {
            uint256 feeHalf = (price * 250) / 10000;
            // split fee between protocol and affiliate
            _deposit(owner(), erc20, feeHalf);
            _deposit(affiliate, erc20, feeHalf);
            // remainder of sale price goes to vendor
            _deposit(item.vendor, erc20, price - (feeHalf * 2));    
        }

        _mint(to, id, 1, "");

        if (address(erc20) == address(0)) {
            require(msg.value >= price, "value too low");
        } else if (price > 0) {
            require(erc20.transferFrom(_msgSender(), address(this), price), "transfer failed");
        }
    }

    /**
     * @dev Withdraw deposits.
     */
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

    /**
     * @dev Airdrop an item.
     */
    function airdrop(address to, uint256 id) external onlyVendor(id) {
        Item memory item = _items[id];
        
        require(item.supply < item.limit, "supply limit reached");
        require(item.config & CONFIG_UNIQUE == 0 || balanceOf(to, id) == 0, "item is unique");
        
        _mint(to, id, 1, "");
    }

    /**
     * @dev Set the config mask for an item.
     */
    function setConfig(uint256 id, uint256 config) external onlyVendor(id) {
        _setConfig(id, config);
    }

    /**
     * @dev Set the limit for maximum number of mints of an item.
     */
    function setLimit(uint256 id, uint256 limit) external onlyVendor(id) {
        require(limit >= _items[id].supply, "limit too low");
        _setLimit(id, limit);
    }

    /**
     * @dev Set the vendor address for an item.
     */
    function setVendor(uint256 id, address vendor) external onlyVendor(id) {
        _setVendor(id, vendor);
    }

    /**
     * @dev Set the URI for an item.
     */
    function setURI(uint256 id, string calldata tokenURI) external onlyVendor(id) {
        _setURI(id, tokenURI);
    }

    /**
     * @dev Set the mint price in the specified currency.
     */
    function setPrice(uint256 id, IERC20 erc20, uint256 price) external onlyVendor(id) {
        _setPrice(id, erc20, price);
    }

    /**
     * @dev Set the royalty receiver and basis points for an item.
     */
    function setRoyalty(uint256 id, address receiver, uint96 fee) external onlyVendor(id) {
        _setTokenRoyalty(id, receiver, fee);
    }

    /**
     * @dev Returns the price of an item in the specified currency.
     */
    function priceInfo(uint256 id, IERC20 erc20) external view returns (uint256) {
        return _prices[id][erc20];
    }

    /**
     * @dev Returns info about the specified item.
     */
    function itemInfo(uint256 id) external view returns (Item memory) {
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

    function _setConfig(uint256 id, uint256 config) internal {
        _items[id].config = config;
        emit ConfigChanged(id, config);
    }

    function _setVendor(uint256 id, address vendor) internal {
        _items[id].vendor = vendor;
        emit VendorChanged(id, vendor);
    }

    function _setLimit(uint256 id, uint256 limit) internal {
        _items[id].limit = limit;
        emit LimitChanged(id, limit);
    }

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

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC1155, ERC2981) returns (bool) {
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
                Item storage item = _items[ids[i]];
                unchecked { item.supply += amounts[i]; }
            }
        } else {
            // check if soulbound when transferring
            for (uint256 i = 0; i < ids.length; ++i) {
                Item memory item = _items[ids[i]];
                require(item.config & CONFIG_SOULBOUND == 0, "item is soulbound");
            }
        }
    }
}
