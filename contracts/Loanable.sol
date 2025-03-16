// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Bank.sol";

contract Loanable is Bank {
    constructor(address[] memory _tokens) Bank(_tokens) {}

    /// @notice 抵押 `collateralToken` 以借出 `loanToken`
    function borrow(address loanToken, uint256 loanAmount, address collateralToken, uint256 collateralAmount) external {
        require(loanToken == address(0) || isTokenInList[loanToken], "Invalid loan token");
        require(collateralToken == address(0) || isTokenInList[collateralToken], "Invalid collateral token");
        require(loanToken != collateralToken, "Cannot borrow the same token as collateral");

        // 抵押
        if (loanToken == address(0)) {
            require(eth_deposits[msg.sender].amount >= collateralAmount, "Insufficient collateral");
            eth_deposits[msg.sender].amount -= collateralAmount;
            eth_deposits[address(this)].amount += collateralAmount;
        } else {
            require(deposits[collateralToken][msg.sender].amount >= collateralAmount, "Insufficient collateral");
            deposits[collateralToken][msg.sender].amount -= collateralAmount;
            deposits[collateralToken][address(this)].amount += collateralAmount;
        }

        // 记录贷款
        if (loans[msg.sender].length == 0) {
            loanUsers.push(msg.sender);
        }
        loans[msg.sender].push(Loan({
            borrower: msg.sender,
            loanToken: loanToken,
            loanAmount: loanAmount,
            initLoanAmount: loanAmount,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            startTime: getCurrentTimeView(),
            lastActivateTime: getCurrentTimeView(),
            isActive: true
        }));

        // 发送贷款代币
        if (loanToken == address(0)) {
            eth_deposits[address(this)].amount -= loanAmount; // 以 ETH 储蓄为担保
            eth_deposits[msg.sender].amount += loanAmount;
        } else {
            deposits[loanToken][address(this)].amount -= loanAmount;
            deposits[loanToken][msg.sender].amount += loanAmount;
        }

        emit Borrowed(msg.sender, loanToken, loanAmount, collateralToken, collateralAmount);
    }

    /// @notice 归还贷款并取回抵押品
    function repay(uint256 loanIndex) external payable {
        require(loanIndex < loans[msg.sender].length, "Invalid loan index");
        Loan storage loan = loans[msg.sender][loanIndex];
        require(loan.isActive, "Loan already repaid");

        // 归还借款
        if (loan.loanToken == address(0)) {
            require(eth_deposits[msg.sender].amount >= loan.loanAmount, "ETH repayment mismatch");
            eth_deposits[msg.sender].amount -= loan.loanAmount;
            eth_deposits[address(this)].amount += loan.loanAmount;
        } else {
            require(deposits[loan.loanToken][msg.sender].amount >= loan.loanAmount, "Loan repayment mismatch");
            deposits[loan.loanToken][msg.sender].amount -= loan.loanAmount;
            deposits[loan.loanToken][address(this)].amount += loan.loanAmount;
        }

        // 退还抵押品
        deposits[msg.sender][loan.collateralToken].amount += loan.collateralAmount;
        deposits[address(this)][loan.collateralToken].amount -= loan.collateralAmount;
        loan.isActive = false;

        emit Repaid(msg.sender, loanIndex);
    }

    /// @notice 查询所有贷款信息
    function getLoans() external view returns (Loan[] memory) {
        return loans[msg.sender];
    }

}
