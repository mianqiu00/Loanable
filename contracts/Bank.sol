// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Rates.sol";

contract Bank is Rates {

    constructor(address[] memory _tokens) Rates(_tokens) {}

    /// @notice 添加 Token 类型
    function addToken(address[] memory _tokens) external onlyOwner {
        updateBank();
        for (uint256 i = 0; i < _tokens.length; i++) {
            tokens.push(_tokens[i]);
            decimals[_tokens[i]] = IERC20Metadata(_tokens[i]).decimals();
            isTokenInList[_tokens[i]] = true; // 记录 token 存在

            tokenPrice[_tokens[i]].initPrice = 1 ether;
            tokenPrice[_tokens[i]].currentPrice = 1 ether;
            tokenPrice[_tokens[i]].initTime = getCurrentTimeView();
            tokenPrice[_tokens[i]].lastTime = tokenPrice[_tokens[i]].initTime;
            tokenPrice[_tokens[i]].amount = 0;
        }
        for (uint256 i = 0; i < windowLength; i++) {
            for (uint256 j = 0; j < _tokens.length; j++) { 
                tokenPriceWindow[_tokens[j]].push(1 ether);
            }
        }
    }

    /// @notice 存入 ETH 或 Token
    function deposit(address token, uint256 amount) external payable {
        updateBank();
        require(isTokenInList[token] || token == address(0), "Invalid token");
        if (!isDepositUsers[token][msg.sender]) {
            depositUsers[token].push(msg.sender);
            isDepositUsers[token][msg.sender] = true;
        }
        if (token == address(0)) {
            deposits[token][msg.sender].amount += msg.value;
        } else {
            require(IERC20(token).transferFrom(msg.sender, address(this), amount), "Transfer failed");
            deposits[token][msg.sender].amount += amount;
            tokenPrice[token].amount += amount;
        }
    }

    /// @notice 取出 ETH 或 Token
    function withdraw(address token, uint256 amount) external payable {
        updateBank();
        require(isTokenInList[token] || token == address(0), "Invalid token");
        require(deposits[token][msg.sender].amount >= amount, "Insufficient balance");
        require(tokenPrice[token].amount >= amount, "Insufficient Credits in Contract");
        tokenPrice[token].amount -= amount;
        deposits[token][msg.sender].amount -= amount;
        if (token == address(0)) {
            (bool success, ) = payable(msg.sender).call{value: amount}("");
            require(success, "ETH transfer failed");
        } else {
            bool sent = IERC20(token).transfer(msg.sender, amount);
            require(sent, "Token transfer failed");
        }
    }

    /// @notice 转账 ETH 或 Token
    function transfer(address token, address payable to, uint256 amount) external payable {
        updateBank();
        require(amount > 0, "Amount must be greater than 0"); 
        require(isTokenInList[token] || token == address(0), "Invalid token");
        require(deposits[token][msg.sender].amount >= amount, "Insufficient balance");
        deposits[token][msg.sender].amount -= amount;
        deposits[token][to].amount += amount;
    }

    /// @notice 购买和售出代币
    function buy(address token, uint256 amount) external payable {
        updateBank();
        uint256 charge = 1; // 手续费（百分比）
        uint256 price = tokenPrice[token].currentPrice;
        require(deposits[address(0)][msg.sender].amount >= amount, "Insufficient balance");
        uint256 tokenAmount = 0;
        for (uint256 j = 0; j < depositUsers[token].length; j++) {
            address user = depositUsers[token][j];
            if (!(user == address(this))) {
                tokenAmount += deposits[token][user].amount;
            }
        }
        require(amount <= tokenAmount, "Insufficient Credits in Contract");

        deposits[address(0)][msg.sender].amount -= amount * price * (100 + charge) / 100;
        deposits[token][msg.sender].amount += amount;

        deposits[address(0)][address(this)].amount += amount * price * (100 + charge) / 100;
        deposits[token][address(this)].amount -= amount;
    }

    function sell(address token, uint256 amount) external payable {
        updateBank();
        uint256 charge = 1; // 手续费（百分比）
        uint256 price = tokenPrice[token].currentPrice;
        require(deposits[token][msg.sender].amount >= amount, "Insufficient balance");
        uint256 ethAmount = 0;
        for (uint256 j = 0; j < depositUsers[address(0)].length; j++) {
            address user = depositUsers[address(0)][j];
            if (!(user == address(this))) {
                ethAmount += deposits[address(0)][user].amount;
            }
        }
        require(ethAmount >= amount * price * (100 - charge) / 100, "Insufficient Credits in Contract");

        deposits[token][msg.sender].amount -= amount;
        deposits[address(0)][msg.sender].amount += amount * price * (100 - charge) / 100;
        
        deposits[token][address(this)].amount += amount;
        deposits[address(0)][address(this)].amount -= amount * price * (100 - charge) / 100;
    }
    
    /// @notice 查询存款余额
    function getDeposit(address token) external returns (uint256) {
        updateBank();
        require(isTokenInList[token] || token == address(0), "Invalid token");
        return deposits[token][msg.sender].amount;
    }

    /// @notice 允许合约接收 ETH
    receive() external payable {}
}
