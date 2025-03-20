// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IStaking.sol";

/// @title MyToken - 一个基于 ERC20 标准的代币合约
contract kkToken is ERC20Permit, Ownable, IToken {
    constructor(string memory name, string memory symbol, uint256 initialSupply)
        ERC20Permit(name) // 初始化 ERC20Permit 合约
        ERC20(name, symbol)
        Ownable(msg.sender)  // 设置合约的所有者
    {
        // _mint(msg.sender, initialSupply * 10 ** decimals()); // 初始铸造代币
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}