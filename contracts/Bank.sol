// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Bank is Ownable {
    
    address[] private tokens;
    address private immutable ownner; 
    uint256 private immutable startTime;

    struct Deposit {
        uint256 time;
        uint256 amount;
    }

    mapping(address => mapping(address => Deposit)) public deposits; // 用户存款 (代币地址 => (用户地址 => 存款))
    mapping(address => Deposit) public eth_deposits; // 用户 ETH 存款 (用户地址 => 存款)
    mapping(address => bool) public isTokenInList; // 记录 token 存在
    mapping(address => uint8) public decimals;
    
    
    event ETHTransferred(address indexed from, address indexed to, uint256 amount);
    event ETHSaved(address indexed user, uint256 amount);
    event ETHWithdrawn(address indexed user, uint256 amount);

    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);

    function getCurrentTimeView() internal view returns (uint256) {
        return block.timestamp;
    }

    constructor(address[] memory _tokens) Ownable(msg.sender) {
        require(_tokens.length > 0, "At least one token address required");
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(!isTokenInList[_tokens[i]], "Duplicate token");
            tokens.push(_tokens[i]);
            decimals[_tokens[i]] = IERC20Metadata(_tokens[i]).decimals();
            isTokenInList[_tokens[i]] = true; // 记录 token 存在
        }
        ownner = msg.sender;
        startTime = getCurrentTimeView();
    }

    /// @notice 存入 ETH 或 Token
    function deposit(address token, uint256 amount) external payable {
        if (token == address(0)) {
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
            require(eth_deposits[msg.sender].amount / 1 ether >= amount, "Insufficient balance"); 
            eth_deposits[msg.sender].amount -= amount * 1 ether;
            eth_deposits[msg.sender].time = getCurrentTimeView();
            (bool success, ) = payable(msg.sender).call{value: amount * 1 ether}("");
            require(success, "ETH withdrawal failed");
            emit ETHWithdrawn(msg.sender, amount);
        } else {
            require(isTokenInList[token], "Invalid token");
            require(deposits[token][msg.sender].amount / 1 ether >= amount, "Insufficient balance");
            deposits[token][msg.sender].amount -= amount * 1 ether;
            require(IERC20(token).transfer(msg.sender, amount), "Transfer failed");
            emit Withdrawn(msg.sender, token, amount);
        }
    }

    /// @notice 转账 ETH 或 Token
    function transfer(address token, address payable to, uint256 amount) external payable {
        require(amount > 0, "Amount must be greater than 0"); 
        if (token == address(0)) {
            require(eth_deposits[msg.sender].amount >= amount * 1 ether, "Insufficient balance");
            eth_deposits[msg.sender].amount -= amount * 1 ether;
            eth_deposits[to].amount += amount * 1 ether;
            emit ETHTransferred(msg.sender, to, amount);
        } else {
            require(isTokenInList[token], "Invalid token");
            require(deposits[token][msg.sender].amount >= amount * 1 ether, "Insufficient balance");
            deposits[token][msg.sender].amount -= amount * 1 ether;
            deposits[token][to].amount += amount * 1 ether;
            emit Deposited(msg.sender, token, amount);
        }
    }
    
    /// @notice 查询存款余额
    function getDeposit(address token) external view returns (uint256) {
        if (token == address(0)) {
            return eth_deposits[msg.sender].amount / 1 ether;
        } else {
            require(isTokenInList[token], "Invalid token");
            return deposits[token][msg.sender].amount / 1 ether;
        }
    }

    /// @notice 允许合约接收 ETH
    receive() external payable {}
}
