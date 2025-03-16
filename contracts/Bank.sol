// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Rates.sol";

contract Bank is Rates {

    constructor(address[] memory _tokens) Rates(_tokens) {}

    /// @notice 添加 Token 类型
    function addToken(address[] memory _tokens) external onlyOwner {
        require(_tokens.length > 0, "At least one token address required");
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(!isTokenInList[_tokens[i]], "Duplicate token");
            tokens.push(_tokens[i]);
            decimals[_tokens[i]] = IERC20Metadata(_tokens[i]).decimals();
            isTokenInList[_tokens[i]] = true; // 记录 token 存在
        }
    }

    /// @notice 存入 ETH 或 Token
    function deposit(address token, uint256 amount) external payable {
        if (token == address(0)) {
            if (!isDepositUsers[token][msg.sender]) {
                depositUsers[token].push(msg.sender);
                isDepositUsers[token][msg.sender] = true;
            }
            eth_deposits[msg.sender].amount += msg.value;
            eth_deposits[msg.sender].time = getCurrentTimeView();
            emit ETHSaved(msg.sender, msg.value);
        } else {
            require(isTokenInList[token], "Invalid token");
            require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
            deposits[token][msg.sender].amount += amount;
            deposits[token][msg.sender].time += getCurrentTimeView();
            emit Deposited(msg.sender, token, amount);
        }
    }

    /// @notice 取出 ETH 或 Token
    function withdraw(address token, uint256 amount) external {
        if (token == address(0)) {
            require(amount > 0, "Amount must be greater than 0"); 
            require(eth_deposits[msg.sender].amount >= amount, "Insufficient balance"); 
            eth_deposits[msg.sender].amount -= amount;
            eth_deposits[msg.sender].time = getCurrentTimeView();
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "ETH withdrawal failed");
            emit ETHWithdrawn(msg.sender, amount);
        } else {
            require(isTokenInList[token], "Invalid token");
            require(deposits[token][msg.sender].amount >= amount, "Insufficient balance");
            deposits[token][msg.sender].amount -= amount;
            require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");
            emit Withdrawn(msg.sender, token, amount);
        }
    }

    /// @notice 转账 ETH 或 Token
    function transfer(address token, address payable to, uint256 amount) external payable {
        require(amount > 0, "Amount must be greater than 0"); 
        if (token == address(0)) {
            require(eth_deposits[msg.sender].amount >= amount, "Insufficient balance");
            eth_deposits[msg.sender].amount -= amount;
            eth_deposits[to].amount += amount;
            emit ETHTransferred(msg.sender, to, amount);
        } else {
            require(isTokenInList[token], "Invalid token");
            require(deposits[token][msg.sender].amount >= amount, "Insufficient balance");
            deposits[token][msg.sender].amount -= amount;
            deposits[token][to].amount += amount;
            emit Deposited(msg.sender, token, amount);
        }
    }
    
    /// @notice 查询存款余额
    function getDeposit(address token) external view returns (uint256) {
        if (token == address(0)) {
            return eth_deposits[msg.sender].amount;
        } else {
            require(isTokenInList[token], "Invalid token");
            return deposits[token][msg.sender].amount;
        }
    }

    /// @notice 允许合约接收 ETH
    receive() external payable {}
}
