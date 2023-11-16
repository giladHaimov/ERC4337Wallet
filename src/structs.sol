// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {SignatureMode} from "./SignatureMode.sol";

/**
* @dev Operation object specified in https://eips.ethereum.org/EIPS/eip-4337
*/
struct UserOperation {
   address sender;
   uint256 nonce;
   bytes initCode;
   bytes callData;
   uint256 callGas;
   uint256 verificationGas;
   uint256 preVerificationGas;
   uint256 maxFeePerGas;
   uint256 maxPriorityFeePerGas;
   address paymaster;
   bytes paymasterData;
   bytes signature;
}

/**
 * @dev Signatures layout used by the Paymasters and Wallets internally
 * @param mode whether it is an owner's or a guardian's signature
 * @param values list of signatures value to validate
 */
struct SignatureData {
  SignatureMode mode;
  SignatureValue[] values;
}

/**
 * @dev Signature's value layout used by the Paymasters and Wallets internally
 * @param signer address of the owner or guardian signing the data
 * @param signature data signed
 */
struct SignatureValue {
  address signer;
  bytes signature;
}
