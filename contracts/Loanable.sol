// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Bank.sol";

contract Loanable is Bank {

    constructor(address _tokenA, address _tokenB, address _tokenC) Bank(_tokenA, _tokenB, _tokenC) {}

    /// @notice 抵押 `collateralToken` 以借出 `loanToken`
    function borrow(address loanToken, uint256 loanAmount, address collateralToken, uint256 collateralAmount) external {
        require(loanToken == address(0) || loanToken == tokenA || loanToken == tokenB || loanToken == tokenC, "Invalid loan token");
        require(collateralToken == address(0) || collateralToken == tokenA || collateralToken == tokenB || collateralToken == tokenC, "Invalid collateral token");
        require(loanToken != collateralToken, "Cannot borrow the same token as collateral");

        // 抵押
        if (loanToken == address(0)) {
            require(eth_deposits[msg.sender].amount >= collateralAmount * 1 ether, "Insufficient collateral");
            eth_deposits[msg.sender].amount -= collateralAmount * 1 ether;
            eth_deposits[address(this)].amount += collateralAmount * 1 ether;
        } else {
            require(deposits[collateralToken][msg.sender].amount >= collateralAmount * 1 ether, "Insufficient collateral");
            deposits[collateralToken][msg.sender].amount -= collateralAmount * 1 ether;
            deposits[collateralToken][address(this)].amount += collateralAmount * 1 ether;
        }

        // 记录贷款
        loans[msg.sender].push(Loan({
            borrower: msg.sender,
            loanToken: loanToken,
            loanAmount: loanAmount * 1 ether,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount * 1 ether,
            isActive: true
        }));

        // 发送贷款代币
        if (loanToken == address(0)) {
            eth_deposits[address(this)].amount -= loanAmount * 1 ether; // 以 ETH 储蓄为担保
            eth_deposits[msg.sender].amount += loanAmount * 1 ether;
        } else {
            deposits[loanToken][address(this)].amount -= loanAmount * 1 ether;
            deposits[loanToken][msg.sender].amount += loanAmount * 1 ether;
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
