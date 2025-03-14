// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract MyToken is ERC20, ERC20Permit, Ownable {
    mapping(address => bool) public hasClaimed; // 记录哪些账户已经领取过 Token

    constructor(uint _initialSupply) ERC20("MyToken", "MTK") ERC20Permit("MyToken") Ownable(msg.sender) {
        _mint(msg.sender, _initialSupply * 10 ** decimals());
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function claim() external {
        require(!hasClaimed[msg.sender], "You have already claimed your Token.");
        hasClaimed[msg.sender] = true;
        _mint(msg.sender, 10 * 10 ** decimals()); // 发送 10 个 Token
    }

    function balanceOf() external view returns (uint256) {
        return super.balanceOf(msg.sender) / (10 ** decimals());
    }

    function addressThis() external view returns (address) {
        return address(this);
    }
}

