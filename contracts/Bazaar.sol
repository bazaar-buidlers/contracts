// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import "./Escrow.sol";
import "./Listings.sol";

contract Bazaar is Ownable2Step, ERC1155, IERC2981 {
    using Listings for Listings.Listing;
    using Counters for Counters.Counter;

    // emitted when vendor is changed
    event Vendor(address vendor, uint256 indexed id);
    // emitted when config is changed
    event Config(uint256 config, uint256 indexed id);
    // emitted when limit is changed
    event Limit(uint256 limit, uint256 indexed id);
    // emitted when royalty is changed
    event Royalty(uint96 fee, uint256 indexed id);
    // emitted when item price is changed
    event Appraise(uint256 price, IERC20 erc20, uint256 indexed id);

    // mint fee basis points
    uint96 public immutable feeNumerator;
    // mint fee / royalty denominator
    uint96 public constant feeDenominator = 10000;
    // escrow contract
    Escrow public escrow;
    
    // product id counter
    Counters.Counter private _counter;
    // mapping of token id to listing
    mapping(uint256 => Listings.Listing) private _listings;
    // mapping of token id to mapping of erc20 to price
    mapping(uint256 => mapping(IERC20 => uint256)) _prices;

    /// @dev Create a new Bazaar.
    ///
    /// @param _escrow address of escrow
    /// @param _feeNumerator mint fee in basis points
    constructor(Escrow _escrow, uint96 _feeNumerator) ERC1155("") {
        require(_feeNumerator <= feeDenominator, "invalid protocol fee");
        feeNumerator = _feeNumerator;
        escrow = _escrow;
    }

    /// @dev List a new item.
    ///
    /// @param config item config mask
    /// @param limit max mint limit
    /// @param royalty numerator of royalty fee
    /// @param tokenURI token metadata URI
    ///
    /// @return unique token id
    function list(uint256 config, uint256 limit, uint96 royalty, string calldata tokenURI) external returns (uint256) {
        require(royalty <= feeDenominator, "fee will exceed sale price");
        Listings.Listing memory listing = Listings.Listing(_msgSender(), config, 0, limit, royalty, tokenURI);

        uint256 id = _counter.current();
        _listings[id] = listing;
        _counter.increment();

        emit Vendor(listing.vendor, id);
        emit Config(listing.config, id);
        emit Limit(listing.limit, id);
        emit Royalty(listing.royalty, id);
        emit URI(listing.uri, id);

        return id;
    }

    /// @dev Mint a token.
    ///
    /// @param to recipient address
    /// @param id unique token id
    /// @param amount quantity to mint
    /// @param erc20 currency address
    function mint(address to, uint256 id, uint256 amount, IERC20 erc20, bytes calldata data) external payable {
        Listings.Listing storage listing = _listings[id];
        require(!listing.isPaused() || _msgSender() == listing.vendor, "minting is paused");

        if (listing.isFree() || _msgSender() == listing.vendor) {
            return _mint(to, id, amount, data);
        }

        uint256 price = _prices[id][erc20] * amount;
        require(price > 0, "invalid currency or amount");

        _mint(to, id, amount, data);

        // deposit fee to owner and remainder to vendor
        uint256 fee = (amount * feeNumerator) / feeDenominator;
        escrow.deposit(listing.vendor, erc20, price - fee);
        escrow.deposit(owner(), erc20, fee);
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

            _prices[id][erc20] = price;
            emit Appraise(price, erc20, id);
        }
    }

    /// @dev Set the config mask for an item.
    ///
    /// @param id unique item id
    /// @param config item config mask
    function setConfig(uint256 id, uint256 config) external onlyVendor(id) {
        _listings[id].config = config;
        emit Config(config, id);
    }

    /// @dev Set the metadata URI for an item.
    ///
    /// @param id unique item id
    /// @param tokenURI token metadata URI
    function setURI(uint256 id, string calldata tokenURI) external onlyVendor(id) {
        _listings[id].uri = tokenURI;
        emit URI(tokenURI, id);
    }

    /// @dev Set the vendor address for an item.
    ///
    /// @param id unique item id
    /// @param vendor address of new vendor
    function setVendor(uint256 id, address vendor) external onlyVendor(id) {
        _listings[id].vendor = vendor;
        emit Vendor(vendor, id);
    }

    /// @dev Set the royalty fee for an item.
    ///
    /// @param id unique token id
    /// @param fee numerator of royalty fee
    function setRoyalty(uint256 id, uint96 fee) external onlyVendor(id) {
        require(fee <= feeDenominator, "fee will exceed sale price");
        _listings[id].royalty = fee;
        emit Royalty(fee, id);
    }

    /// @dev Set item mint limit. Set to 0 for unlimited.
    ///
    /// @param id unique token id
    /// @param limit maximum amount of mints
    function setLimit(uint256 id, uint256 limit) external onlyVendor(id) {
        require(_listings[id].supply <= limit, "limit lower than supply");
        _listings[id].limit = limit;
        emit Limit(limit, id);
    }

    /// @dev Withdraw deposits.
    ///
    /// @param payee address to send funds
    /// @param erc20 currency address
    function withdraw(address payable payee, IERC20 erc20) external {
        escrow.withdraw(_msgSender(), payee, erc20);
    }

    /// @dev Returns the total deposits for an address.
    ///
    /// @param payee address to return balance of
    /// @param erc20 currency address
    ///
    /// @return total deposits
    function depositsOf(address payee, IERC20 erc20) external view returns (uint256) {
        return escrow.depositsOf(payee, erc20);
    }

    /// @dev Returns royalty info for an item.
    ///
    /// @param id unique token id
    /// @param price sale price of item
    ///
    /// @return recipient address and royalty amount
    function royaltyInfo(uint256 id, uint256 price) external view returns (address, uint256) {
        Listings.Listing memory listing = _listings[id];
        uint256 amount = (price * listing.royalty) / feeDenominator;
        return (listing.vendor, amount);
    }

    /// @dev Returns the price of an item in the specified currency.
    ///
    /// @param id unique token id
    /// @param erc20 currency address
    ///
    /// @return price of the listing in the specified currency
    function priceInfo(uint256 id, IERC20 erc20) external view returns (uint256) {
        return _prices[id][erc20];
    }

    /// @dev Returns listing info.
    ///
    /// @param id unique token id
    ///
    /// @return listing config,
    function listingInfo(uint256 id) external view returns (Listings.Listing memory) {
        return _listings[id];
    }

    // modifier to check if sender is vendor
    modifier onlyVendor(uint256 id) {
        require(_listings[id].vendor == _msgSender(), "sender is not vendor");
        _;
    }

    /////////////////
    /// Overrides ///
    /////////////////

    function uri(uint256 id) public view override returns (string memory) {
        return _listings[id].uri;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, IERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId 
            || super.supportsInterface(interfaceId);
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

            Listings.Listing storage listing = _listings[id];
            // increase supply
            if (from == address(0)) {
                listing.supply += amount;
            }
            // check unique
            if (listing.isUnique()) {
                require(balanceOf(to, id) + amount == 1, "token is unique");
            }
            // check soulbound
            if (listing.isSoulbound()) {
                require(from == address(0), "token is soulbound");
            }
            // check limit
            if (listing.limit > 0) {
                require(listing.supply <= listing.limit, "token limit reached");
            }
        }
    }
}
