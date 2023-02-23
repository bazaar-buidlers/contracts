// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";

import "./Escrow.sol";
import "./Listings.sol";

contract Bazaar is Initializable, OwnableUpgradeable, ERC1155Upgradeable, IERC2981Upgradeable {
    using Listings for Listings.Listing;

    // emitted when vendor is changed
    event TransferVendor(address vendor, uint256 indexed id);
    // emitted when config is changed
    event Configure(uint256 config, uint256 limit, uint256 allow, uint96 royalty, uint256 indexed id);
    // emitted when item price is changed
    event Appraise(uint256 price, address erc20, uint256 indexed id);

    // escrow contract
    Escrow public escrow;
    // mint fee basis points
    uint96 public feeNumerator;
    // mint fee / royalty denominator
    uint96 public constant FEE_DENOMINATOR = 10000;
    
    // product id counter
    uint256 private _counter;
    // mapping of token id to listing
    mapping(uint256 => Listings.Listing) private _listings;
    // mapping of token id to mapping of erc20 to price
    mapping(uint256 => mapping(address => uint256)) _prices;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @dev Initialize a new Bazaar.
    ///
    /// @param _feeNumerator numerator of protocol fee
    /// @param _escrow Escrow contract address
    function initialize(uint96 _feeNumerator, Escrow _escrow) public initializer {
        require(_feeNumerator <= FEE_DENOMINATOR, "invalid protocol fee");

        feeNumerator = _feeNumerator;
        escrow = _escrow;

        __Ownable_init();
        __ERC1155_init("");
    }

    /// @dev List a new item.
    ///
    /// @param config item configuration mask
    /// @param limit maximum supply limit
    /// @param allow root of allow merkle tree
    /// @param royalty numerator of royalty fee
    /// @param tokenURI token metadata URI
    function list(uint256 config, uint256 limit, uint256 allow, uint96 royalty, string calldata tokenURI) external returns (uint256) {
        require(royalty <= FEE_DENOMINATOR, "royalty will exceed sale price");
        
        Listings.Listing memory listing = Listings.Listing({
            vendor: _msgSender(),
            config: config,
            supply: 0,
            limit: limit,
            allow: allow,
            royalty: royalty,
            uri: tokenURI
        });

        uint256 id = _counter;
        _listings[id] = listing;
        ++_counter;

        emit TransferVendor(listing.vendor, id);
        emit Configure(listing.config, listing.limit, listing.allow, listing.royalty, id);
        emit URI(listing.uri, id);

        return id;
    }

    /// @dev Mint tokens in the given currency.
    ///
    /// @param id unique token id
    /// @param to recipient address
    /// @param erc20 currency address (zero address is native tokens)
    /// @param proof proof for allow merkle tree
    function mint(uint256 id, address to, address erc20, bytes32[] calldata proof) external payable {
        Listings.Listing storage listing = _listings[id];
        require(!listing.isPaused(), "minting is paused");

        address owner = owner();
        address sender = _msgSender();

        if (listing.allow != 0) {
            require(listing.isAllowed(sender, proof), "not allowed");
        }
        if (listing.isFree()) {
            require(msg.value == 0, "mint is free");
            return _mint(to, id, 1, "");
        }

        uint256 price = _prices[id][erc20];
        require(price > 0, "invalid currency");
        _mint(to, id, 1, "");

        // fee goes to owner and remainder goes to vendor
        uint256 fee = (price * feeNumerator) / FEE_DENOMINATOR;
        if (erc20 == address(0)) {
            // native token deposit
            require(msg.value == price, "incorrect amount of native tokens sent");
            escrow.deposit{ value: price - fee }(sender, listing.vendor, erc20, price - fee);
            escrow.deposit{ value: fee }(sender, owner, erc20, fee);
        } else {
            // erc20 token deposit
            escrow.deposit(sender, listing.vendor, erc20, price - fee);
            escrow.deposit(sender, owner, erc20, fee);
        }
    }

    /// @dev Update pricing of an item.
    ///
    /// @param id unique token id
    /// @param erc20s list of currencies (zero address is native tokens)
    /// @param prices list of prices
    function appraise(uint256 id, address[] calldata erc20s, uint256[] calldata prices) external onlyVendor(id) {
        require(erc20s.length == prices.length, "mismatched erc20 and price");

        for (uint256 i = 0; i < erc20s.length; ++i) {
            address erc20 = erc20s[i];
            uint256 price = prices[i];

            _prices[id][erc20] = price;
            emit Appraise(price, erc20, id);
        }
    }

    /// @dev Update the configuration of a listing.
    ///
    /// @param id unique token id
    /// @param config configuration mask
    /// @param limit maximum supply limit
    /// @param allow root of allow merkle tree
    /// @param royalty numerator of royalty fee
    function configure(uint256 id, uint256 config, uint256 limit, uint256 allow, uint96 royalty) external onlyVendor(id) {
        Listings.Listing storage listing = _listings[id];

        require(royalty <= FEE_DENOMINATOR, "royalty will exceed sale price");
        require(limit == 0 || limit >= listing.supply, "limit lower than supply");
        require(listing.supply == 0 || listing.isUnlocked(config), "config is locked");

        listing.config = config;
        listing.limit = limit;
        listing.allow = allow;
        listing.royalty = royalty;
        
        emit Configure(config, limit, allow, royalty, id);
    }

    /// @dev Update the metadata URI of a listing.
    ///
    /// @param id unique token id
    /// @param tokenURI token metadata URI
    function update(uint256 id, string calldata tokenURI) external onlyVendor(id) {
        _listings[id].uri = tokenURI;
        emit URI(tokenURI, id);
    }

    /// @dev Transfer a listing to a new vendor.
    ///
    /// @param id unique token id
    /// @param vendor address of new vendor
    function transferVendor(uint256 id, address vendor) external onlyVendor(id) {
        _listings[id].vendor = vendor;
        emit TransferVendor(vendor, id);
    }

    /// @dev Returns the total deposits for an address.
    ///
    /// @param payee address to return balance of
    /// @param erc20 currency address
    function depositsOf(address payee, address erc20) external view returns (uint256) {
        return escrow.depositsOf(payee, erc20);
    }

    /// @dev Returns royalty info for an item.
    ///
    /// @param id unique token id
    /// @param price sale price of item
    function royaltyInfo(uint256 id, uint256 price) external view returns (address, uint256) {
        uint256 amount = (price * _listings[id].royalty) / FEE_DENOMINATOR;
        return (_listings[id].vendor, amount);
    }

    /// @dev Returns the price of an item in the specified currency.
    ///
    /// @param id unique token id
    /// @param erc20 currency address
    function priceInfo(uint256 id, address erc20) external view returns (uint256) {
        return _prices[id][erc20];
    }

    /// @dev Returns listing info.
    ///
    /// @param id unique token id
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

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155Upgradeable, IERC165Upgradeable) returns (bool) {
        return interfaceId == type(IERC2981Upgradeable).interfaceId || super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155Upgradeable) {
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
