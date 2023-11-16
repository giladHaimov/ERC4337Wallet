// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {console} from "forge-std/console.sol";
import {Ownable} from "./Ownable.sol";
import {IERC4337Wallet} from "./IERC4337Wallet.sol";
import {ECDSA} from "./ECDSA.sol";
import {IERC20} from "./IERC20.sol";
import {ReentrancyGuard} from "./ReentrancyGuard.sol";
import {UserOperation} from "./structs.sol";


/**
* @dev an ERC4337-supporting ownership-changing wallet
*/
contract ERC4337Wallet is IERC4337Wallet, Ownable, ReentrancyGuard {

  address public immutable entryPoint;

  mapping(address => mapping(address/*IERC20*/ => uint)) public tokenBalance;
  mapping(address => uint) public etherBalance;

  uint256 public nonce;

  using ECDSA for bytes32;

  event EtherDeposited(address indexed sender, uint indexed value, uint newBalance);
  event EtherTransferred(address indexed from, address indexed to, uint value, uint newBalance);
  event TokenDeposited(address indexed sender, address indexed tokenAddress, uint amount);
  event TokenTransferred(address indexed from, address indexed tokenAddress, address indexed to, uint amount);

  modifier onlyEntryPoint() {
    require(msg.sender == address(entryPoint), "not entryPoint");
    _;
  }

  /*
   * @dev Wallet's constructor
   * @param entryPoint reference that will be hardcoded in the implementation contract
   */
  constructor(address entryPoint_) Ownable(msg.sender) {
    entryPoint = entryPoint_;
  }

  receive() external payable {
    _depositEther(msg.value);
  }

  function depositEther() external payable {    
    _depositEther(msg.value);
  }

  function _depositEther(uint sum) private nonReentrant {
    etherBalance[msg.sender] += sum;
    emit EtherDeposited(msg.sender, sum, etherBalance[msg.sender]);
  }

  function transferEther(address to, uint amount) external nonReentrant {
    _transferEther(to, amount);
  }

  function _transferEther(address to, uint amount) private {
    //checks-effects-interactions
    require(to != address(0), "cannot transfer to zero address");
    require(etherBalance[msg.sender] >= amount, "insufficient eth balance");
    etherBalance[msg.sender] -= amount;
    // if (etherBalance[to] > 0) {
    //     update wallet balance without eth transfer
    // }
    _safeTransferEther(to, amount);
    emit EtherTransferred(msg.sender, to, amount, etherBalance[msg.sender]);
  }

  //getEtherBalance, getTokenBalance -> use default getters

  function myEtherBalance() external view returns(uint) {
    return etherBalance[msg.sender];
  }

  function myTokenBalance(address tokenAddress) external view returns(uint) {
    return tokenBalance[msg.sender][tokenAddress];
  }

  function getTokenBalance(address tokenOwner, address tokenAddress) external view returns(uint) {
    return tokenBalance[tokenOwner][tokenAddress];
  }

  function depositTokens(IERC20 token, uint amount) external nonReentrant {
    tokenBalance[msg.sender][address(token)] += amount;
    _safeTransferTokenFrom(token, msg.sender, address(this), amount);
    emit TokenDeposited(msg.sender, address(token), amount);
  }

  function transferTokens(IERC20 token, address to, uint amount) external nonReentrant {
    _transferTokens(token, to, amount);
  }

  function _transferTokens(IERC20 token, address to, uint amount) private {
    require(to != address(0), "cannot transfer to zero address");
    require(tokenBalance[msg.sender][address(token)] >= amount, "insufficient token balance");
    tokenBalance[msg.sender][address(token)] -= amount;
    // if (tokenBalance[to][address(token)] > 0) {
    //     update wallet balance without eth transfer
    // }
    _safeTransferToken(token, to, amount);  
    emit TokenTransferred(msg.sender, address(token), to, amount);
  }

  function _safeTransferToken(IERC20 token, address to, uint amount) private {
    // called by token owner
    bool success = token.transfer(to, amount); 
    require(success, "token transfer failed");
  }

  function _safeTransferTokenFrom(IERC20 token, address from, address to, uint amount) private {
    // called by a non-owner with allowance
    token.transferFrom(from, to, amount); // revert on error
  }

  function batch_trasferEther(address[] calldata to, uint[] calldata amount) external nonReentrant { //DoS?
    require(to.length == amount.length, "inconsistent array length");
    for (uint i = 0; i < to.length; i++) {
        _transferEther(to[i], amount[i]); // internally emits event
    }
  }

  function batch_trasferTokens(IERC20[] calldata token, address[] calldata to, uint[] calldata amount) external nonReentrant { //DoS?
    require(token.length == to.length && token.length == amount.length, "inconsistent array length");
    for (uint i = 0; i < token.length; i++) {
        _transferTokens(token[i], to[i], amount[i]);
    }
  }


  // --- IWallet impl ---

  /**
   * @dev Verifies the operation’s signature, and pays the fee if the wallet considers the operation valid
   * @param op operation to be validated
   * @param requestId identifier computed as keccak256(op, entryPoint, chainId)
   * @param requiredPrefund amount to be paid to the entry point in wei, or zero if there is a paymaster involved
   */    
  function validateUserOp(UserOperation calldata op, bytes32 requestId, uint256 requiredPrefund) external override onlyEntryPoint {
    // impl notes: https://blog.openzeppelin.com/eth-foundation-account-abstraction-audit
    
    // validate (and incrementy) nonce
    require(nonce++ == op.nonce, "invalid nonce value");

    // validate signature
    _validateSignature(op, requestId);

    // transfer prefunds to entryPoint
    if (requiredPrefund > 0) {
        (bool success,) = payable(entryPoint).call{ value: requiredPrefund }("");
        (success); // do not revert on failure (its EntryPoint's job to verify, not wallet.)
    }
  }

  function _validateSignature(UserOperation calldata op, bytes32 requestId) internal virtual view {
    bytes32 hash = requestId.toEthSignedMessageHash();
    require(owner() == hash.recover(op.signature), "bad signature");
  }

  function executeUserOp(address to, uint256 amount, bytes calldata data) external override onlyEntryPoint {
    require(address(this).balance >= amount, "insufficient balance");
    if (data.length > 0) { 
      // call function
      _safeCallFunction(to, amount, data);
    } else {
      // no function data, transfer eth to address
      _safeTransferEther(to, amount);
    }
  }

  function _safeCallFunction(address target, uint256 amount, bytes memory data) private {
    (bool success,) = payable(target).call{ value: amount }(data);
    require(success, "function call failed");
  }  

  function _safeTransferEther(address to, uint amount) private {
    (bool success,) = payable(to).call{ value: amount }("");
    require(success, "eth transfer failed");
  }
}
