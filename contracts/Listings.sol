// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

library Listings {
    // config flag pauses minting
    uint256 constant CONFIG_PAUSED = 1 << 0;
    // config flag enables free mints
    uint256 constant CONFIG_FREE = 1 << 1;
    // config flag disables transfers
    uint256 constant CONFIG_SOULBOUND = 1 << 2;
    // config flag enforces one item per address
    uint256 constant CONFIG_UNIQUE = 1 << 3;
    
    struct Listing {
        // vendor address
        address vendor;
        // config mask
        uint256 config;
        // total number of mints
        uint256 supply;
        // maximum supply limit
        uint256 limit;
        // allow merkle root
        uint256 allow;
        // royalty fee basis points
        uint96 royalty;
        // metadata uri
        string uri;
    }

    function isPaused(Listing storage listing) internal view returns (bool) {
        return listing.config & CONFIG_PAUSED != 0;
    }

    function isFree(Listing storage listing) internal view returns (bool) {
        return listing.config & CONFIG_FREE != 0;
    }

    function isSoulbound(Listing storage listing) internal view returns (bool) {
        return listing.config & CONFIG_SOULBOUND != 0;
    }

    function isUnique(Listing storage listing) internal view returns (bool) {
        return listing.config & CONFIG_UNIQUE != 0;
    }

    function isAllowed(Listing storage listing, address sender, bytes32[] calldata proof) internal view returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(sender))));
        return MerkleProof.verifyCalldata(proof, bytes32(listing.allow), leaf);
    }
}