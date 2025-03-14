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
        require(deposits[msg.sender][collateralToken] >= collateralAmount, "Insufficient collateral");

        // 抵押
        deposits[msg.sender][collateralToken] -= collateralAmount;

        // 记录贷款
        loans[msg.sender].push(Loan({
            borrower: msg.sender,
            loanToken: loanToken,
            loanAmount: loanAmount,
            collateralToken: collateralToken,
            collateralAmount: collateralAmount,
            isActive: true
        }));

        // 发送贷款代币
        if (loanToken == address(0)) {
            payable(msg.sender).transfer(loanAmount);
        } else {
            require(IERC20(loanToken).transfer(msg.sender, loanAmount), "Loan transfer failed");
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
            require(msg.value == loan.loanAmount, "ETH repayment mismatch");
        } else {
            require(IERC20(loan.loanToken).transferFrom(msg.sender, address(this), loan.loanAmount), "Loan repayment failed");
        }

        // 退还抵押品
        deposits[msg.sender][loan.collateralToken] += loan.collateralAmount;
        loan.isActive = false;

        emit Repaid(msg.sender, loanIndex);
    }

    /// @notice 查询所有贷款信息
    function getLoans() external view returns (Loan[] memory) {
        return loans[msg.sender];
    }
}
