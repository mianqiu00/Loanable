// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./Math.sol";

contract Rates is Ownable, Math, RandomWalk, Time{
    /// 价格相关
    struct priceContainer {
        uint256 initPrice;
        uint256 currentPrice;
        uint256 initTime;
        uint256 lastTime;
        uint256 amount;
    }
    mapping(address => priceContainer) public tokenPrice;

    /// 储蓄相关
    address[] internal tokens;
    address internal immutable bankOwner; 
    uint256 internal immutable startTime;

    struct Deposit {
        uint256 time;
        uint256 amount;
    }

    mapping(address => mapping(address => Deposit)) internal deposits; // 用户存款 (代币地址 => (用户地址 => 存款))
    mapping(address => bool) internal isTokenInList; // 记录 token 存在
    mapping(address => uint8) internal decimals;
    mapping(address => address[]) internal depositUsers;
    mapping(address => mapping(address => bool)) internal isDepositUsers;

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

    event appendCollateralSign(address user, uint index);

    constructor(address[] memory _tokens) Ownable(msg.sender) {
        require(_tokens.length > 0, "At least one token address required");
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(!isTokenInList[_tokens[i]], "Duplicate token");
            tokens.push(_tokens[i]);
            decimals[_tokens[i]] = IERC20Metadata(_tokens[i]).decimals();
            isTokenInList[_tokens[i]] = true; // 记录 token 存在

            tokenPrice[_tokens[i]].initPrice = 1 ether;
            tokenPrice[_tokens[i]].currentPrice = 1 ether;
            tokenPrice[_tokens[i]].initTime = getCurrentTimeView();
            tokenPrice[_tokens[i]].lastTime = tokenPrice[_tokens[i]].initTime;
            tokenPrice[_tokens[i]].amount = 0;
        }

        tokenPrice[address(0)].currentPrice = 1 ether;
        tokenPrice[address(0)].amount = 0;

        bankOwner = msg.sender;
        startTime = getCurrentTimeView();

        for (uint256 i = 0; i < windowLength; i++) {
            for (uint256 j = 0; j < _tokens.length; j++) { 
                tokenPriceWindow[_tokens[j]][i] = 1 ether;
            }
        }
    }

    /// @notice 计算代币利率（手写次方根计算）
    function getRate(address token) internal view returns (uint256) {
        uint256 initPrice = tokenPrice[token].initPrice;
        uint256 currentPrice = tokenPrice[token].currentPrice;
        
        if (currentPrice > initPrice) {
            return 0;
        }
        
        uint256 timeGap = tokenPrice[token].lastTime - tokenPrice[token].initTime;
        uint256 times = timeGap / 60 + 1;
        
        // 计算 (currentPrice / initPrice)^(1/times) - 1
        uint256 ratio = (currentPrice * 1e18) / initPrice; // Solidity 处理定点数
        uint256 root = nthRoot(ratio, times, 1e10); // 计算 `times` 次方根
        uint256 rate = root - 1e18; // 转换为 1e18 格式

        return rate / 1e16; // 1e18 = 1, 0.01e18 = 1%
    }


    /// @notice 更新代币价格
    function updatePrice() internal {
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 lastTime = tokenPrice[token].lastTime;
            uint256 nowTime = getCurrentTimeView();
            uint256 timeGap = nowTime - lastTime;
            uint256 currentPrice = tokenPrice[token].currentPrice;
            if (timeGap > 0) {
                uint256 std = 2 * 1e15;
                currentPrice = walk(token, currentPrice, lastTime, timeGap, std);
                tokenPrice[token].currentPrice = currentPrice;
            }
        }
    }

    /// @notice 更新贷款，计算利息
    function updateLoan() internal {
        for (uint256 i = 0; i < loanUsers.length; i++) {
            address user = loanUsers[i];
            require(loans[user].length > 0, "No loans for this user");
            for (uint256 j = 0; j < loans[user].length; j++) {
                Loan memory loan_t = loans[user][j];
                // 利率计算逻辑
                uint256 loanAmount = loan_t.loanAmount;
                uint256 lastTime = loan_t.lastActivateTime;
                uint256 nowTime = loan_t.lastActivateTime;
                // 更新前提：需要有足够长的时间以产生利息
                uint256 timeGap = nowTime - lastTime;

                uint256 interestRate = 5 + getRate(loan_t.loanToken);  // 基础利率
                uint interval = 60;  // 一分钟计算一次利息
                uint times = timeGap / interval;

                uint256 loanAmountCopy = loanAmount;
                loanAmount = loanAmount * 1e10;
                for (uint time = 0; time < times; time++) {
                    loanAmount = loanAmount * (100 + interestRate) / 100;
                }
                loanAmount = loanAmount / 1e10;
                if (loanAmount - loanAmountCopy > 0) {
                    loan_t.lastActivateTime += interval * times;
                    loan_t.loanAmount = loanAmount;
                }

                // 清算逻辑
                if (((loan_t.loanAmount / tokenPrice[loan_t.loanToken].currentPrice) > (loan_t.collateralAmount / tokenPrice[loan_t.collateralToken].currentPrice) * 110 / 100)) {
                    emit appendCollateralSign(user, j);
                } else if (((loan_t.loanAmount / tokenPrice[loan_t.loanToken].currentPrice) > (loan_t.collateralAmount / tokenPrice[loan_t.collateralToken].currentPrice) * 105 / 100)) {
                    loan_t.isActive = false;
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
                    deposits[token][user].time = getCurrentTimeView();
                    deposits[token][address(this)].amount -= gain;
                    deposits[token][address(this)].time = getCurrentTimeView();
                }
                uint256 ownerGain = surplus * 3 / 10;
                deposits[token][bankOwner].amount += ownerGain;
                deposits[token][bankOwner].time = getCurrentTimeView();
                deposits[token][address(this)].amount -= ownerGain;
                deposits[token][address(this)].amount = getCurrentTimeView();
            }
        }
    }

    function updateBank() internal {
        updatePrice();
        updateLoan();
        updateDeposits();
    }
}