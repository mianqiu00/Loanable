// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Bank.sol";

contract Loanable is Bank {
    constructor(address[] memory _tokens) Bank(_tokens) {}

    /// @notice 抵押 `collateralToken` 以借出 `loanToken`
    function borrow(address loanToken, uint256 loanAmount, address collateralToken) external payable {
        updateBank();
        uint256 collateralAmount = loanAmount * tokenPrice[loanToken].currentPrice / tokenPrice[collateralToken].currentPrice * 120 / 100;  // 超量抵押
        require(loanToken == address(0) || isTokenInList[loanToken], "Invalid loan token");
        require(collateralToken == address(0) || isTokenInList[collateralToken], "Invalid collateral token");
        require(loanToken != collateralToken, "Cannot borrow the same token as collateral");

        // 抵押
        require(deposits[collateralToken][msg.sender].amount >= collateralAmount, "Insufficient collateral");
        deposits[collateralToken][msg.sender].amount -= collateralAmount;
        deposits[collateralToken][address(this)].amount += collateralAmount;


        // 记录贷款
        if (loans[msg.sender].length == 0) {
            loanUsers.push(msg.sender);
        }
        uint256 timeNow = getCurrentTimeView();
        loans[msg.sender].push(Loan({
            borrower: msg.sender,
            loanToken: loanToken,
            loanAmount: loanAmount,
            initLoanAmount: loanAmount,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            startTime: timeNow,
            lastActivateTime: timeNow,
            isActive: true
        }));

        // 发送贷款代币
        deposits[loanToken][address(this)].amount -= loanAmount;  // 以储蓄为担保
        deposits[loanToken][msg.sender].amount += loanAmount;
    }

    /// @notice 归还贷款并取回抵押品
    function repay(uint256 loanIndex) external payable {
        updateBank();
        require(loanIndex < loans[msg.sender].length, "Invalid loan index");
        Loan storage loan = loans[msg.sender][loanIndex];
        require(loan.isActive, "Loan already repaid");

        // 归还借款
        require(deposits[loan.loanToken][msg.sender].amount >= loan.loanAmount, "Loan repayment mismatch");
        deposits[loan.loanToken][msg.sender].amount -= loan.loanAmount;
        deposits[loan.loanToken][address(this)].amount += loan.loanAmount;

        // 退还抵押品
        deposits[loan.collateralToken][msg.sender].amount += loan.collateralAmount;
        deposits[loan.collateralToken][address(this)].amount -= loan.collateralAmount;
        loan.isActive = false;
    }

    function appendCollateral(uint256 loanIndex, uint256 amount) external payable {
        updateBank();
        require(loanIndex < loans[msg.sender].length, "Invalid loan index");
        Loan storage loan = loans[msg.sender][loanIndex];
        require(loan.isActive, "Loan already repaid");

        // 增加抵押
        require(deposits[loan.collateralToken][msg.sender].amount >= loan.loanAmount, "Loan repayment mismatch");
        deposits[loan.collateralToken][msg.sender].amount -= loan.loanAmount;
        deposits[loan.collateralToken][address(this)].amount += loan.loanAmount;
        loan.collateralAmount += amount;
    }

    /// @notice 查询所有贷款信息
    function getLoans() external returns (Loan[] memory) {
        updateBank();
        return loans[msg.sender];
    }

}
