# ERC4337Wallet Contract Documentation

## Overview
`ERC4337Wallet` is an implementation of an ERC4337-enabled simple ownership-changing wallet. This wallet contract manages Ether and ERC20-compatible token balances, supports executing transactions, batch operations and handles ownership. It is basically a small test-app I created to learn the complexities of making a contract (here: a wallet) ERC4337-enabled. It's main value for the reader would probably be due it being small and focused on enabling ERC4337 and batch operations. <br>In developing this project I have reviewed several projects and articles, the ones I relied on the most were (1) The [Stackup ERC4337 implementation](https://github.com/derekchiang/stackup/blob/7956b8d51001761b2d982e95d79331e83c6612a1/apps/contracts/contracts/wallet/Wallet.sol) by @derekchiang (2) The [official EIP documentation](https://eips.ethereum.org/EIPS/eip-4337) and (3) Several YouTube resources e.g. [this short video](https://www.youtube.com/watch?v=r3ZSk4PeqxQ) by Block Explorer.<br>


## Contract Inheritance
- **`IERC4337Wallet`**: Interface for ERC4337 compliant wallets.
- **`Ownable`**: Basic authorization control functions.
- **`ReentrancyGuard`**: Protection against reentrant calls.

## State Variables
- **`entryPoint`**: Immutable address of the entry point contract.
- **`tokenBalance`**: Mapping of token addresses to user balances.
- **`etherBalance`**: Mapping of user addresses to their Ether balances.
- **`nonce`**: Counter for operation validation.
- **`ECDSA`**: ECDSA operations library.

## Events
- **`EtherDeposited`**: Triggered when Ether is deposited.
- **`EtherTransferred`**: Triggered when Ether is transferred.
- **`TokenDeposited`**: Triggered when tokens are deposited.
- **`TokenTransferred`**: Triggered when tokens are transferred.

## Modifiers
- **`onlyEntryPoint`**: Restricts function access to the entry point.

## Constructor
Initializes the contract setting the `entryPoint` address and establishing the contract creator as the owner.

## Functions

### Ether Management
- **`receive()`**: Allows the contract to accept Ether directly.
- **`depositEther()`**: Enables Ether deposits.
- **`_depositEther(uint sum)`**: Internal Ether deposit handler.
- **`transferEther(address to, uint amount)`**: Enables Ether transfers.
- **`_transferEther(address to, uint amount)`**: Internal Ether transfer handler.

### Token Management
- **`myEtherBalance()`**: Returns the caller's Ether balance.
- **`myTokenBalance(address tokenAddress)`**: Returns the caller's token balance for a specified token.
- **`depositTokens(IERC20 token, uint amount)`**: Enables token deposits.
- **`transferTokens(IERC20 token, address to, uint amount)`**: Enables token transfers.
- **`_transferTokens(IERC20 token, address to, uint amount)`**: Internal token transfer handler.
- **`_safeTransferToken(IERC20 token, address from, address to, uint amount)`**: Safely transfers tokens.

### Batch Operations
- **`batch_transferEther(address[] calldata to, uint[] calldata amount)`**: Batch Ether transfer.
- **`batch_transferTokens(IERC20[] calldata token, address[] calldata to, uint[] calldata amount)`**: Batch token transfer.

### IWallet Implementation
- **`validateUserOp(UserOperation calldata op, bytes32 requestId, uint256 requiredPrefund)`**: Validates and executes user operations.
- **`_validateSignature(UserOperation calldata op, bytes32 requestId)`**: Internal signature validation.
- **`executeUserOp(address to, uint256 amount, bytes calldata data)`**: Executes a user operation.
- **`_safeCallFunction(address target, uint256 amount, bytes memory data)`**: Safely calls a function on another contract.
- **`_safeTransferEther(address to, uint amount)`**: Safely transfers Ether.

## Security Considerations
- The contract includes checks for zero addresses and insufficient balances to prevent common vulnerabilities.
- `nonReentrant` modifier is used to safeguard against reentrancy attacks in critical functions.
- Proper error handling is ensured with `require` statements throughout the contract.

## Additional Notes
- The contract aims to comply fully with the ERC4337 standard for smart contract wallets, providing robust functionality for managing digital assets.
- It balances public and private functions for both flexibility and security.
