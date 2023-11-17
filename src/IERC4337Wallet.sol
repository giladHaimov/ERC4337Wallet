// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {UserOperation} from "./structs.sol";

/**
 * @dev Wallet interface specified in https://eips.ethereum.org/EIPS/eip-4337
 */
interface IERC4337Wallet {
  function validateUserOp(UserOperation memory op, bytes32 requestId, uint256 requiredPrefund) external;
  function executeUserOp(address to, uint256 value, bytes calldata data) external;
}

