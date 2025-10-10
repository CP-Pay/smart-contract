// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {LibERC20} from "../libraries/LibERC20.sol";

contract ERC20Facet {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function name() external view returns (string memory) {
        return LibERC20.erc20Storage().name;
    }

    function symbol() external view returns (string memory) {
        return LibERC20.erc20Storage().symbol;
    }

    function decimals() external view returns (uint8) {
        return LibERC20.erc20Storage().decimals;
    }

    function totalSupply() external view returns (uint256) {
        return LibERC20._totalSupply();
    }

    function balanceOf(address account) external view returns (uint256) {
        return LibERC20._balanceOf(account);
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return LibERC20.erc20Storage().allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        LibERC20._approve(msg.sender, spender, amount);
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        LibERC20._transfer(msg.sender, to, amount);
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        LibERC20._spendAllowance(from, msg.sender, amount);
        LibERC20._transfer(from, to, amount);
        emit Transfer(from, to, amount);
        return true;
    }
}
