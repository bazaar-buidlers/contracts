// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Escrow {
    using Address for address payable;

    // emitted when funds are deposited
    event Deposited(address payee, IERC20 erc20, uint256 amount);
    // emitted when funds are withdrawn
    event Withdrawn(address payee, IERC20 erc20, uint256 amount);

    // escrow owner should never change because owner is a contract
    address private _owner;
    // mapping of address to mapping of erc20 to deposits
    mapping(address => mapping(IERC20 => uint256)) private _deposits;

    /// @dev Creates a new Escrow.
    constructor() {
        _owner = msg.sender;
    }

    /// @dev Withdraw funds.
    ///
    /// @param owner address to withdraw from
    /// @param payee address send funds to
    /// @param erc20 currency address
    function withdraw(address owner, address payable payee, IERC20 erc20) external onlyOwner {
        uint256 amount = _deposits[owner][erc20];
        require(amount > 0, "nothing to withdraw");

        _deposits[owner][erc20] = 0;

        // zero address is native tokens
        if (address(erc20) == address(0)) {
            payee.sendValue(amount);
        } else {
            require(erc20.transfer(payee, amount), "transfer failed");
        }

        emit Withdrawn(msg.sender, erc20, amount);
    }

    /// @dev Deposit funds.
    ///
    /// @param owner address of owner
    /// @param erc20 currency address
    /// @param amount value to deposit
    function deposit(address owner, IERC20 erc20, uint256 amount) external payable onlyOwner {
        require(amount > 0, "nothing to deposit");

        _deposits[owner][erc20] += amount;

        // zero address is native tokens
        if (address(erc20) == address(0)) {
            require(msg.value == amount, "value must equal amount");
        } else {
            require(erc20.transferFrom(msg.sender, address(this), amount), "transfer failed");
        }

        emit Deposited(owner, erc20, amount);
    }

    // modifier to check if sender is owner
    modifier onlyOwner() {
        require(msg.sender == _owner, "sender is not owner");
        _;
    }
}