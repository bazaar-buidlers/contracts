// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Escrow {
    using Address for address payable;

    // emitted when funds are deposited
    event Deposited(address payee, address erc20, uint256 amount);
    // emitted when funds are withdrawn
    event Withdrawn(address payee, address erc20, uint256 amount);

    // escrow owner should never change because owner is a contract
    address private immutable _owner;
    // mapping of address to mapping of erc20 to deposits
    mapping(address => mapping(address => uint256)) private _deposits;

    /// @dev Creates a new Escrow.
    constructor() {
        _owner = msg.sender;
    }

    /// @dev Deposit funds.
    ///
    /// @param payee owner of funds
    /// @param erc20 currency address
    /// @param amount value to deposit
    function deposit(address payee, address erc20, uint256 amount) external payable onlyOwner {
        require(amount > 0, "nothing to deposit");

        _deposits[payee][erc20] += amount;
        emit Deposited(payee, erc20, amount);

        // zero address is native tokens
        if (erc20 == address(0)) {
            require(msg.value == amount, "value must equal amount");
        } else {
            require(IERC20(erc20).transferFrom(msg.sender, address(this), amount), "transfer failed");
        }
    }

    /// @dev Withdraw funds.
    ///
    /// @param payee owner of funds
    /// @param recipient address send funds to
    /// @param erc20 currency address
    function withdraw(address payee, address payable recipient, address erc20) external onlyOwner {
        uint256 amount = _deposits[payee][erc20];
        require(amount > 0, "nothing to withdraw");

        _deposits[payee][erc20] = 0;
        emit Withdrawn(payee, erc20, amount);

        // zero address is native tokens
        if (erc20 == address(0)) {
            recipient.sendValue(amount);
        } else {
            require(IERC20(erc20).transfer(recipient, amount), "transfer failed");
        }
    }

    /// @dev Returns the total deposits for an address.
    ///
    /// @param payee address to return balance of
    /// @param erc20 currency address
    ///
    /// @return total deposits
    function depositsOf(address payee, address erc20) external view returns (uint256) {
        return _deposits[payee][erc20];
    }

    // modifier to check if sender is owner
    modifier onlyOwner() {
        require(msg.sender == _owner, "sender is not owner");
        _;
    }
}