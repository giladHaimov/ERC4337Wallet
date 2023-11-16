// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {ERC4337Wallet} from "../../src/ERC4337Wallet.sol";
import {UserOperation} from "../../src/structs.sol";

contract MockERC4337Wallet is ERC4337Wallet {
    constructor(address entryPoint_) ERC4337Wallet(entryPoint_) {}

    function _validateSignature(UserOperation calldata op, bytes32 requestId) internal override view {
        // no-op
    }
}
