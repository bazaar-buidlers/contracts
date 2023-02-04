// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Escrow is Ownable {
    using Address for address payable;

    // emitted when funds are deposited
    event Deposited(address payee, address erc20, uint256 amount);
    // emitted when funds are withdrawn
    event Withdrawn(address payee, address erc20, uint256 amount);

    // mapping of address to mapping of erc20 to deposits
    mapping(address => mapping(address => uint256)) private _deposits;

    /// @dev Deposit funds.
    ///
    /// @param from spender address
    /// @param to recipient address
    /// @param erc20 currency address
    /// @param amount value to deposit
    function deposit(address from, address to, address erc20, uint256 amount) external payable onlyOwner {
        require(amount > 0, "nothing to deposit");

        _deposits[to][erc20] += amount;
        emit Deposited(to, erc20, amount);

        // zero address is native tokens
        if (erc20 == address(0)) {
            require(msg.value == amount, "value must equal amount");
        } else {
            require(IERC20(erc20).transferFrom(from, address(this), amount), "transfer failed");
        }
    }

    /// @dev Withdraw funds.
    ///
    /// @param from spender address
    /// @param to recipient address
    /// @param erc20 currency address
    function withdraw(address from, address payable to, address erc20) external onlyOwner {
        uint256 amount = _deposits[from][erc20];
        require(amount > 0, "nothing to withdraw");

        _deposits[from][erc20] = 0;
        emit Withdrawn(from, erc20, amount);

        // zero address is native tokens
        if (erc20 == address(0)) {
            to.sendValue(amount);
        } else {
            require(IERC20(erc20).transfer(to, amount), "transfer failed");
        }
    }

    /// @dev Returns the total deposits for an address.
    ///
    /// @param payee address to return balance of
    /// @param erc20 currency address
    ///
    /// @return total deposits
    function depositsOf(address payee, address erc20) external view onlyOwner returns (uint256) {
        return _deposits[payee][erc20];
    }
}