# Loanable - A Blockchain-Based Lending and Borrowing System

## Overview

Loanable is a decentralized lending and borrowing system built on the Ethereum blockchain. It allows users to deposit, withdraw, and transfer tokens, as well as borrow tokens by providing collateral. The system supports multiple ERC20 tokens and includes features such as interest rate calculation, price updates, and loan management.

## Contracts

### 1. **Math.sol**
   - Contains mathematical functions such as `nthRoot` and `power` for calculating roots and exponents.
   - Includes a `RandomWalk` contract for generating random numbers and simulating price movements.

### 2. **Rates.sol**
   - Manages token prices, interest rates, and deposit/loan calculations.
   - Implements functions for updating token prices, calculating interest rates, and managing deposits and loans.

### 3. **Bank.sol**
   - Implements core banking functionalities such as depositing, withdrawing, and transferring tokens.
   - Allows users to buy and sell tokens within the system.

### 4. **Loanable.sol**
   - Extends the `Bank` contract to provide lending and borrowing functionalities.
   - Users can borrow tokens by providing collateral and repay loans to retrieve their collateral.

### 5. **MyToken.sol**
   - An ERC20 token contract with additional features such as minting and claiming tokens.
   - Inherits from OpenZeppelin's `ERC20`, `ERC20Permit`, and `Ownable` contracts.

### 6. **TokenA.sol, TokenB.sol, TokenC.sol**
   - These are specific ERC20 token contracts that inherit from `MyToken`.
   - Each token has a unique name and can be used within the Loanable system.

## Deployment

To deploy the Loanable system, you need to compile and deploy the following contracts:

1. **TokenA.sol**
2. **TokenB.sol**
3. **TokenC.sol**
4. **Loanable.sol**

You can deploy these contracts using Remix IDE or any other Ethereum development environment.

### Steps for Deployment:

1. **Compile Contracts**:
   - Compile `TokenA.sol`, `TokenB.sol`, `TokenC.sol`, and `Loanable.sol` in Remix IDE.

2. **Deploy Tokens**:
   - Deploy `TokenA`, `TokenB`, and `TokenC` contracts. These will be the ERC20 tokens used in the system.

3. **Deploy Loanable**:
   - Deploy the `Loanable` contract, passing the addresses of the deployed tokens (`TokenA`, `TokenB`, `TokenC`) as constructor arguments.

4. **Interact with the System**:
   - Once deployed, you can interact with the `Loanable` contract to deposit, withdraw, transfer, borrow, and repay tokens.

## Features

### Deposit and Withdraw
- Users can deposit and withdraw ETH or ERC20 tokens.
- The system tracks user balances and updates them accordingly.

### Transfer
- Users can transfer tokens to other users within the system.

### Borrow and Repay
- Users can borrow tokens by providing collateral in the form of other tokens.
- Loans accrue interest over time, and users must repay the loan to retrieve their collateral.

### Token Price Updates
- The system periodically updates token prices based on a random walk algorithm.
- Interest rates are calculated based on the price changes.

### Interest Calculation
- Interest rates are calculated using a custom algorithm that takes into account the time gap and price changes.
- Loans accrue interest over time, and users must repay the loan with interest.

### Dividend Distribution
- The system distributes dividends to users based on their deposit amounts when the total surplus exceeds a certain threshold.

## GitHub Repository

The source code for this project is available on GitHub:  
[https://github.com/mianqiu00/Loanable](https://github.com/mianqiu00/Loanable)

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request on the GitHub repository.

## Author

This project was developed by [Yitian Wang](https://github.com/mianqiu00).