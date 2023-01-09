// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "./Catalog.sol";
import "./Escrow.sol";
import "./Items.sol";

contract Bazaar is Ownable2Step, ERC1155, IERC2981 {
    using Items for Items.Item;

    // emitted when item price is changed
    event Appraise(uint256 price, IERC20 erc20, uint256 indexed id);

    struct Listing {
        // total number of mints
        uint256 supply;
        // maximum supply limit
        uint256 limit;
        // royalty fee basis points
        uint96 royalty;
        // mapping of erc20 to price
        mapping(IERC20 => uint256) prices;
    }

    // mint fee basis points
    uint96 public immutable feeNumerator;
    // mint fee / royalty denominator
    uint96 constant feeDenominator = 10000;
    // catalog of items
    Catalog private _catalog;
    // escrow contract
    Escrow private _escrow;
    // mapping of token id to listing
    mapping(uint256 => Listing) private _listings;

    /// @dev Create a new Bazaar.
    ///
    /// @param catalog address of item catalog
    /// @param fee mint fee in basis points
    constructor(Catalog catalog, uint96 fee) ERC1155("") {
        require(fee <= feeDenominator, "invalid protocol fee");
        feeNumerator = fee;

        _catalog = catalog;
        _escrow = new Escrow();
    }

    /// @dev Mint an item.
    ///
    /// @param to recipient address
    /// @param id unique token id
    /// @param amount quantity to mint
    /// @param erc20 currency address
    function mint(address to, uint256 id, uint256 amount, IERC20 erc20) external payable {
        Items.Item memory item = _catalog.itemInfo(id);
        require(!item.isPaused(), "minting is paused");

        if (item.isFree() || _msgSender() == item.vendor) {
            return _mint(to, id, amount, "");
        }

        uint256 price = _listings[id].prices[erc20] * amount;
        require(price > 0, "invalid currency or amount");

        _mint(to, id, amount, "");

        // deposit fee to owner and remainder to vendor
        uint256 fee = (amount * feeNumerator) / feeDenominator;
        _escrow.deposit(item.vendor, erc20, price - fee);
        _escrow.deposit(owner(), erc20, fee);
    }

    /// @dev Update pricing of an item.
    ///
    /// @param id unique token id
    /// @param erc20s list of currencies
    /// @param prices list of prices
    function appraise(uint256 id, IERC20[] calldata erc20s, uint256[] calldata prices) external onlyVendor(id) {
        require(erc20s.length == prices.length, "mismatched erc20 and price");

        for (uint256 i = 0; i < erc20s.length; ++i) {
            IERC20 erc20 = erc20s[i];
            uint256 price = prices[i];

            _listings[id].prices[erc20] = price;
            emit Appraise(price, erc20, id);
        }
    }

    /// @dev Withdraw deposits.
    ///
    /// @param payee address to send funds
    /// @param erc20 currency address
    function withdraw(address payable payee, IERC20 erc20) external {
        _escrow.withdraw(_msgSender(), payee, erc20);
    }

    /// @dev Set the royalty fee for an item.
    ///
    /// @param id unique token id
    /// @param fee numerator of royalty fee
    function setRoyalty(uint256 id, uint96 fee) external onlyVendor(id) {
        require(fee <= feeDenominator, "fee will exceed sale price");
        _listings[id].royalty = fee;
    }

    /// @dev Set item mint limit. Set to 0 for unlimited.
    ///
    /// @param id unique token id
    /// @param limit maximum amount of mints
    function setLimit(uint256 id, uint256 limit) external onlyVendor(id) {
        require(_listings[id].supply <= limit, "limit lower than supply");
        _listings[id].limit = limit;
    }

    /// @dev Returns royalty info for an item.
    ///
    /// @param id unique token id
    /// @param price sale price of item
    ///
    /// @return recipient address and royalty amount
    function royaltyInfo(uint256 id, uint256 price) external view returns (address, uint256) {
        uint256 amount = (price * _listings[id].royalty) / feeDenominator;
        return (_catalog.itemInfo(id).vendor, amount);
    }

    /// @dev Returns the price of an item in the specified currency.
    ///
    /// @param id unique token id
    /// @param erc20 currency address
    ///
    /// @return price of the item in the specified currency
    function priceInfo(uint256 id, IERC20 erc20) external view returns (uint256) {
        return _listings[id].prices[erc20];
    }

    /// @dev Returns the total limit of the specified item.
    ///
    /// @param id unique token id
    ///
    /// @return total minted item limit
    function totalLimit(uint256 id) external view returns (uint256) {
        return _listings[id].limit;
    }

    /// @dev Returns the total supply of the specified item.
    ///
    /// @param id unique token id
    ///
    /// @return total number of minted items
    function totalSupply(uint256 id) external view returns (uint256) {
        return _listings[id].supply;
    }

    // modifier to check if sender is vendor
    modifier onlyVendor(uint256 id) {
        require(_catalog.itemInfo(id).vendor == _msgSender(), "sender is not vendor");
        _;
    }

    /////////////////
    /// Overrides ///
    /////////////////

    function uri(uint256 id) public view override returns (string memory) {
        return _catalog.itemInfo(id).uri;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
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

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            Items.Item memory item = _catalog.itemInfo(id);
            require(!item.isUnique() || balanceOf(to, id) + amount == 1, "item is unique");
            require(from == address(0) || !item.isSoulbound(), "item is soulbound");

            if (from == address(0)) {
                uint256 supply = _listings[id].supply;
                uint256 limit = _listings[id].limit;

                require(limit == 0 || supply + amount <= limit, "item limit reached");
                _listings[id].supply = supply + amount;
            }
        }
    }
}
