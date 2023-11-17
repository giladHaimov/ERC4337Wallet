// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {MockERC20} from "./utils/MockERC20.sol";
import {BaseTest} from "./BaseTest.t.sol";
import {IERC20} from "../src/IERC20.sol";
import {ERC4337Wallet} from "../src/ERC4337Wallet.sol";
import {MockERC4337Wallet} from "./utils/MockERC4337Wallet.sol";
import {MockEntryPoint} from "./utils/MockEntryPoint.sol";
import {MockExecuteTarget} from "./utils/MockExecuteTarget.sol";
import {UserOperation} from "../src/structs.sol";
import {console} from "forge-std/console.sol";


contract WalletTest is BaseTest  {

    uint private constant LARGE_ETH_VALUE = 100000 ether;

    MockERC4337Wallet private s_wallet;
    MockEntryPoint private s_entryPoint;

    address public s_token;
    IERC20[] private s_tokenArr;
    address[] private  s_receiverArr;
    uint[] private  s_amountArr;

    event EtherDeposited(address indexed sender, uint value, uint newBalance);

    constructor() BaseTest(ACCEPT_PAYMENTS) {} // accept eth else burn() will fail on transfering the remaining funds back to the caller

	function setUp() public override {
	    //BaseTest.setUp();
        s_entryPoint = new MockEntryPoint();
        s_wallet = new MockERC4337Wallet(address(s_entryPoint));
        s_entryPoint.setWallet(s_wallet);
        s_token = address(new MockERC20());
	}

    function testFuzz_nonEntryPoint_cannot_callIWalletFuncs(address sender_) public { 
        vm.assume(sender_ != address(s_entryPoint));
        UserOperation memory op = _makeOp(0);
        bytes32 requestId = 0;
        uint requiredPrefund_ = 0;
        
        hoax(sender_);
        vm.expectRevert(abi.encodePacked("not entryPoint"));
        s_wallet.validateUserOp(op, requestId, requiredPrefund_);

        address to = makeAddr("executeUserOp:to");
        uint amount = 0;
        bytes memory data = "";
        
        hoax(sender_);
        vm.expectRevert(abi.encodePacked("not entryPoint"));
        s_wallet.executeUserOp(to, amount, data);
    }

    function test_entryPointCanCallIWalletFuncs() public { 
        UserOperation memory op = _makeOp(0);
        bytes32 requestId = 0;
        uint requiredPrefund_ = 0;
        
        hoax(address(s_entryPoint));
        s_wallet.validateUserOp(op, requestId, requiredPrefund_);

        address to = makeAddr("executeUserOp:to");
        uint amount = 0;
        bytes memory data = "";
        
        hoax(address(s_entryPoint));
        s_wallet.executeUserOp(to, amount, data);
    }

    function testFuzz_validateUserOp_failsOnInvalidNonce(uint nonce, uint opNonce) public {         
        nonce= bound(nonce, 0, type(uint256).max-1);
        vm.assume(nonce != opNonce); // else no BadNonceValue error
        s_wallet.setNonce(nonce);

        UserOperation memory op = _makeOp(opNonce);
        bytes32 requestId = 0;
        uint requiredPrefund_ = 0;
        
        vm.expectRevert( abi.encodeWithSelector(ERC4337Wallet.BadNonceValue.selector, nonce+1, opNonce));
        hoax(address(s_entryPoint));
        s_wallet.validateUserOp(op, requestId, requiredPrefund_);
    }

    function testFuzz_validateUserOp_verifyPrefundTransferred(uint requiredPrefund) public {         
        requiredPrefund = bound(requiredPrefund, 0, LARGE_ETH_VALUE);
        uint nonce = 100;
        s_wallet.setNonce(nonce);

        UserOperation memory op = _makeOp(nonce);
        bytes32 requestId = 0;
        uint requiredPrefund_ = 0;
        
        hoax(address(s_entryPoint));
        
        uint pre_balance = address(s_entryPoint).balance;
        s_wallet.validateUserOp(op, requestId, requiredPrefund_);    
        uint post_balance = address(s_entryPoint).balance;

        assertEq(pre_balance + requiredPrefund_, post_balance, "validateUserOp failed: requiredPrefund");
    }

    function testFuzz_executeUserOp_validateFunctionCallMode(address addr, uint id, uint amount, string calldata str) public {         
        amount = bound(amount, 0, LARGE_ETH_VALUE);
        MockExecuteTarget target = new MockExecuteTarget();
        bytes memory data = _getFunctionCallData(addr, id, amount, str);

        assertEq(target.s_to(), address(0), "target: to");
        assertEq(target.s_id(), 0, "target: id");
        assertEq(target.s_amount(), 0, "target: amount");
        assertTrue(_eq(target.s_str(), ""), "target: str");

        vm.deal(address(s_wallet), amount); // verify sufficiengt balance in wallet

        hoax(address(s_entryPoint));
        s_wallet.executeUserOp(address(target), amount, data);
        
        assertEq(target.s_to(), addr, "post target: to");
        assertEq(target.s_id(), id, "post target: id");
        assertEq(target.s_amount(), amount, "post target: amount");
        assertTrue(_eq(target.s_str(), str), "post target: str");

        assertEq(address(target).balance, amount, "post target: balance"); // verify eth transfer
    }

    function _getFunctionCallData(address to, uint id, uint amount, string calldata str) private pure returns (bytes memory) {
        string memory funcSignature = "setSomeValues(address,uint256,uint256,string)";
        bytes4 funcSelector = bytes4(keccak256(bytes(funcSignature)));
        bytes memory data = abi.encodeWithSelector(funcSelector, to, id, amount, str); // ABI-encoded parameters
        return data;
    }

    function _makeOp(uint nonce_) private returns(UserOperation memory op) {
        address sender_ = makeAddr("sender");
        address paymaster_ = makeAddr("paymaster");
        op = UserOperation({
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
    }

    function testFuzz_explicitDepositEther(uint value_) public { 
        value_ = _limitFunds(value_);
        address sender = address(this);
        s_wallet.depositEther{ value: value_}();
        uint newBalance = s_wallet.etherBalance(sender);
        assertEq(newBalance, value_, "failed deposit");
    }

    function testFuzz_batch_trasferEther(uint value1, uint value2, uint value3) public {
        value1 = _limitFunds(value1);
        value2 = _limitFunds(value2);
        value3 = _limitFunds(value3);

        uint totalValue = value1 + value2 + value3;
        
        address receiver1 = makeAddr("eth-receiver1");
        address receiver2 = makeAddr("eth-receiver2");
        address receiver3 = makeAddr("eth-receiver3");

        address sender = address(this);
        s_wallet.depositEther{ value: totalValue}();

        s_receiverArr = [receiver1,receiver2,receiver3];
        s_amountArr = [value1,value2,value3];

        uint pre_senderBalanc = s_wallet.etherBalance(sender);

        s_wallet.batch_trasferEther(s_receiverArr, s_amountArr);

        uint post_senderBalanc = s_wallet.etherBalance(sender);

        assertEq(pre_senderBalanc, post_senderBalanc + totalValue, "batch_trasferEther failed: sender");

        assertEq(receiver1.balance, value1, "batch_trasferEther failed: receiver1");
        assertEq(receiver2.balance, value2, "batch_trasferEther failed: receiver2");
        assertEq(receiver3.balance, value3, "batch_trasferEther failed: receiver3");
    }


    function testFuzz_directDepositEther(uint value_) public {
        // direct deposit to the wallet
        value_ = _limitFunds(value_);
        address sender = address(this);
        (bool ok,) = address(s_wallet).call{ value: value_}("");
        require(ok, "failed deposit");
        uint newBalance = s_wallet.etherBalance(sender);
        assertEq(newBalance, value_, "failed deposit");
    }

    function testFuzz_depositTokens(uint amount) public {
        amount = _depositTokensIntoWallet(amount);
        uint newBalance = s_wallet.myTokenBalance(s_token);
        assertEq(newBalance, amount, "token deposit failed");
    }

    function testFuzz_transferTokens(uint amount) public {
        amount = _depositTokensIntoWallet(amount);
        address receiver = makeAddr("erc20-receiver");
        s_wallet.transferTokens(IERC20(s_token), receiver, amount);
        uint newBalance = IERC20(s_token).balanceOf(receiver);
        //console.log("amount: %s , new-balance; %s", amount, newBalance); 
        assertEq(newBalance, amount, "token transfer failed");
    }

    function testFuzz_batch_transferTokens(uint amount1, uint amount2, uint amount3) public {
        amount1 = _depositTokensIntoWallet(amount1);
        amount2 = _depositTokensIntoWallet(amount2);
        amount3 = _depositTokensIntoWallet(amount3);
        address receiver1 = makeAddr("erc20-receiver-1");
        address receiver2 = makeAddr("erc20-receiver-2");
        address receiver3 = makeAddr("erc20-receiver-3");

        IERC20 token = IERC20(s_token);

        s_tokenArr = [token,token,token];
        s_receiverArr = [receiver1,receiver2,receiver3];
        s_amountArr = [amount1,amount2,amount3];

        s_wallet.batch_trasferTokens(s_tokenArr, s_receiverArr, s_amountArr);

        uint newBalance1 = token.balanceOf(receiver1);
        assertEq(newBalance1, amount1, "token transfer failed-1");

        uint newBalance2 = token.balanceOf(receiver2);
        assertEq(newBalance2, amount2, "token transfer failed-2");

        uint newBalance3 = token.balanceOf(receiver3);
        assertEq(newBalance3, amount3, "token transfer failed-3");
    }

    function testFuzz_gettersNeverThrow(string memory str) public {
        address addr = makeAddr(str);
        address tokenAddress = makeAddr("tokenAddress");
        hoax(addr);
        s_wallet.myEtherBalance();
        s_wallet.myTokenBalance(addr);
        s_wallet.getTokenBalance(addr, tokenAddress);
    }


    function _depositTokensIntoWallet(uint amount) private returns(uint) { 
        amount = _limitFunds(amount);
        address sender = address(this);
        deal(s_token, sender, amount);
        IERC20(s_token).approve(address(s_wallet), amount);
        s_wallet.depositTokens(IERC20(s_token), amount);
        return amount;
    }   

    function _eq(string memory str1, string memory str2) private pure returns (bool) {
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }
}		
