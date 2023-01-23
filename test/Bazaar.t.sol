pragma solidity ^0.8.9;

import "forge-std/Test.sol";
import "../contracts/Bazaar.sol";

contract BazaarTest is Test {
    uint96 constant FEE_NUMERATOR = 300;

    Bazaar bazaar;
    Escrow escrow;

    function setUp() public {
        escrow = new Escrow();
        bazaar = new Bazaar(false);

        escrow.transferOwnership(address(bazaar));
        bazaar.initialize(FEE_NUMERATOR, escrow);
    }

    function testOwner() public {
        assertEq(bazaar.owner(), address(this));
    }

    function testFeeNumerator() public {
        assertEq(bazaar.feeNumerator(), FEE_NUMERATOR);
    }
}