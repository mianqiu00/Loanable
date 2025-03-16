// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./Math.sol";
import "./Time.sol";

contract Rates is Ownable, FixedPointMath, Time{
    /// 储蓄相关
    address[] internal tokens;
    address internal immutable bankOwner; 
    uint256 internal immutable startTime;

    struct Deposit {
        uint256 time;
        uint256 amount;
    }

    mapping(address => mapping(address => Deposit)) internal deposits; // 用户存款 (代币地址 => (用户地址 => 存款))
    mapping(address => Deposit) internal eth_deposits; // 用户 ETH 存款 (用户地址 => 存款)
    mapping(address => bool) internal isTokenInList; // 记录 token 存在
    mapping(address => uint8) internal decimals;
    mapping(address => address[]) internal depositUsers;
    mapping(address => mapping(address => bool)) internal isDepositUsers;
    
    
    event ETHTransferred(address indexed from, address indexed to, uint256 amount);
    event ETHSaved(address indexed user, uint256 amount);
    event ETHWithdrawn(address indexed user, uint256 amount);

    event Deposited(address indexed user, address indexed token, uint256 amount);
    event Withdrawn(address indexed user, address indexed token, uint256 amount);

    /// 贷款相关
    struct Loan {
        address borrower;
        address loanToken;
        uint256 loanAmount;
        uint256 initLoanAmount;
        address collateralToken;
        uint256 collateralAmount;
        uint256 startTime;
        uint256 lastActivateTime;
        bool isActive;
    }
    mapping(address => Loan[]) internal loans; // 用户贷款信息 (用户地址 => 贷款数组)
    address[] internal loanUsers;

    event Borrowed(
        address indexed user,
        address indexed loanToken,
        uint256 loanAmount,
        address indexed collateralToken,
        uint256 collateralAmount
    );
    event Repaid(address indexed user, uint256 loanIndex);

    constructor(address[] memory _tokens) Ownable(msg.sender) {
        require(_tokens.length > 0, "At least one token address required");
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(!isTokenInList[_tokens[i]], "Duplicate token");
            tokens.push(_tokens[i]);
            decimals[_tokens[i]] = IERC20Metadata(_tokens[i]).decimals();
            isTokenInList[_tokens[i]] = true; // 记录 token 存在
        }
        bankOwner = msg.sender;
        startTime = getCurrentTimeView();
    }

    /// @notice 更新贷款，计算利息
    function updateLoan() internal {
        for (uint256 i = 0; i < loanUsers.length; i++) {
            address user = loanUsers[i];
            require(loans[user].length > 0, "No loans for this user");
            for (uint256 j = 0; j < loans[user].length; j++) {
                // 利率计算逻辑
                uint256 loanAmount = loans[user][j].loanAmount;
                uint256 lastTime = loans[user][j].lastActivateTime;
                uint256 nowTime = loans[user][j].lastActivateTime;
                // 更新前提：需要有足够长的时间以产生利息
                // loans[user][j].lastActivateTime = getCurrentTimeView();
                uint256 timeGap = nowTime - lastTime;

                uint interestRate = 5;  // 利率
                uint interval = 60;  // 一分钟计算一次利息
                uint times = timeGap / interval;

                uint256 loanAmountCopy = loanAmount;
                loanAmount = toFixed(loanAmount);
                for (uint time = 0; time < times; time++) {
                    loanAmount = loanAmount * (100 + interestRate) / 100;
                }
                loanAmount = fromFixed(loanAmount);
                if (loanAmount - loanAmountCopy > 0) {
                    loans[user][j].lastActivateTime += interval * times;
                    loans[user][j].loanAmount = loanAmount;
                }
            }
        }
    }

    // @notice 分红
    function updateDeposits() internal {
        uint bar = 10;  // 分红阈值（百分比）
        uint precision = 1e10;
        bar = precision * bar / 100;

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 tokenAmount = 0;
            // 计算总金额
            for (uint256 j = 0; j < depositUsers[token].length; j++) {
                address user = depositUsers[token][j];
                if (!(user == address(this))) {
                    tokenAmount += deposits[token][user].amount;
                }
            }
            if (tokenAmount + deposits[token][address(this)].amount > tokenAmount * (precision + bar) / precision) {
                uint256 surplus = (tokenAmount + deposits[token][address(this)].amount - tokenAmount * (precision + bar) / precision) * 5 / 10;
                for (uint256 j = 0; j < depositUsers[token].length; j++) {
                    address user = depositUsers[token][j];
                    uint256 proportion = deposits[token][user].amount * precision / tokenAmount * 7 / 10;
                    uint256 gain = surplus * proportion / precision;
                    deposits[token][user].amount += gain;
                    deposits[token][address(this)].amount -= gain;
                }
                uint256 ownerGain = surplus * 3 / 10;
                deposits[token][bankOwner].amount += ownerGain;
                deposits[token][address(this)].amount -= ownerGain;
            }
        }
    }
}