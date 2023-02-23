// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Escrow is Ownable, ReentrancyGuard {
    using Address for address payable;

    // emitted when funds are deposited
    event Deposited(address payee, address erc20, uint256 amount);
    // emitted when funds are withdrawn
    event Withdrawn(address payee, address erc20, uint256 amount);

    // mapping of address to mapping of erc20 to deposits
    mapping(address => mapping(address => uint256)) private _deposits;

    /// @dev Deposit funds to the given address.
    ///
    /// @param from spender address
    /// @param to recipient address
    /// @param erc20 currency address (zero address is native tokens)
    /// @param amount value to deposit
    function deposit(address from, address to, address erc20, uint256 amount) external payable onlyOwner nonReentrant {
        address self = address(this);
        IERC20 token = IERC20(erc20);
        
        // zero address is native tokens
        if (erc20 == address(0)) {
            require(msg.value == amount, "value must equal amount");
        } else if (amount > 0) {
            uint256 balance = token.balanceOf(self);
            SafeERC20.safeTransferFrom(token, from, address(this), amount);
            amount = token.balanceOf(self) - balance;
        }

        // this does not follow checks effects interactions pattern,
        // but function has reentrancy guard so this should be okay
        _deposits[to][erc20] += amount;
        emit Deposited(to, erc20, amount);
    }

    /// @dev Withdraw funds to the given address.
    ///
    /// @param to recipient address
    /// @param erc20 currency address (zero address is native tokens)
    function withdraw(address payable to, address erc20) external {
        address from = _msgSender();

        uint256 amount = _deposits[from][erc20];
        require(amount > 0, "nothing to withdraw");

        _deposits[from][erc20] = 0;
        emit Withdrawn(from, erc20, amount);

        // zero address is native tokens
        if (erc20 == address(0)) {
            to.sendValue(amount);
        } else {
            SafeERC20.safeTransfer(IERC20(erc20), to, amount);
        }
    }

    /// @dev Returns the total deposits for an address.
    ///
    /// @param payee address to return balance of
    /// @param erc20 currency address
    function depositsOf(address payee, address erc20) external view returns (uint256) {
        return _deposits[payee][erc20];
    }
}