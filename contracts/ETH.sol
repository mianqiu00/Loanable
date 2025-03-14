// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract ETH {
    mapping(address => uint256) public balances;

    event ETHTransferred(address indexed from, address indexed to, uint256 amount);
    event ETHSaved(address indexed user, uint256 amount);
    event ETHWithdrawn(address indexed user, uint256 amount);

    function transferETH(address payable _to, uint256 _amount) external payable {
        require(_to != address(0), "Invalid address"); // 检查目标地址是否有效
        require(_amount > 0, "Amount must be greater than 0"); // 检查转账金额是否大于 0
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        balances[msg.sender] -= _amount;
        balances[_to] += _amount;

        emit ETHTransferred(msg.sender, _to, _amount);
    }

    function saveETH() external payable {
        balances[msg.sender] += msg.value / 1 ether;
        emit ETHSaved(msg.sender, msg.value);
    }

    function withdrawETH(uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0"); 
        require(balances[msg.sender] >= _amount, "Insufficient balance"); 

        balances[msg.sender] -= _amount;

        (bool success, ) = payable(msg.sender).call{value: _amount * 1 ether}("");
        require(success, "ETH withdrawal failed");

        emit ETHWithdrawn(msg.sender, _amount);
    }

    function getContractBalance() external view returns (uint256) {
        return address(this).balance / 1 ether;
    }

    function getUserBalance() external view returns (uint256) {
        return balances[msg.sender];
    }
}