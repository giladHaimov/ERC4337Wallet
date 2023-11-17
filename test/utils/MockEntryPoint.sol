// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {MockERC4337Wallet} from "./MockERC4337Wallet.sol";
import {UserOperation} from "../../src/structs.sol";

contract MockEntryPoint {
    MockERC4337Wallet private s_wallet;
    bytes32 private s_requestId;
    bytes private s_data;
    
    function setWallet(MockERC4337Wallet wallet) external {
        s_wallet = wallet;
    }

    function validate(uint requiredPrefund_, uint nonce_, address sender_, address paymaster_) external {
        UserOperation memory op_ = UserOperation({
            sender: sender_,
            nonce: nonce_,
            initCode: "",
            callData: "",
            callGas: 100,
            verificationGas: 100,
            preVerificationGas: 100,
            maxFeePerGas: 100,
            maxPriorityFeePerGas: 100,
            paymaster: paymaster_,
            paymasterData: "",
            signature: ""
        });
        s_wallet.validateUserOp(op_, s_requestId, requiredPrefund_);    
    }

    function executeEthTransferOnly(address to, uint amount) external {
        require(s_data.length == 0, "data not empty");
        s_wallet.executeUserOp(to, amount, s_data);
    }
}
