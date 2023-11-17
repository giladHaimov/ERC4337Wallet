// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {MockERC20} from "./utils/MockERC20.sol";
import {BaseTest} from "./BaseTest.t.sol";
import {IERC20} from "../src/IERC20.sol";
import {ERC4337Wallet} from "../src/ERC4337Wallet.sol";
import {MockERC4337Wallet} from "./utils/MockERC4337Wallet.sol";
import {MockEntryPoint} from "./utils/MockEntryPoint.sol";
import {UserOperation} from "../src/structs.sol";
import {console} from "forge-std/console.sol";


contract WalletTest is BaseTest  {

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

    function test_nonEntryPointCannotCallIWalletFuncs(address sender_) public { 
        vm.assume(sender_ != address(s_entryPoint));
        UserOperation memory op = _makeOp();
        bytes32 requestId = 0;
        uint requiredPrefund = 0;
        
        hoax(sender_);
        vm.expectRevert(abi.encodePacked("not entryPoint"));
        s_wallet.validateUserOp(op, requestId, requiredPrefund);

        address to = makeAddr("executeUserOp:to");
        uint amount = 0;
        bytes memory data = "";
        
        hoax(sender_);
        vm.expectRevert(abi.encodePacked("not entryPoint"));
        s_wallet.executeUserOp(to, amount, data);
    }

    function test_entryPointCanCallIWalletFuncs() public { 
        UserOperation memory op = _makeOp();
        bytes32 requestId = 0;
        uint requiredPrefund = 0;
        
        hoax(address(s_entryPoint));
        s_wallet.validateUserOp(op, requestId, requiredPrefund);

        address to = makeAddr("executeUserOp:to");
        uint amount = 0;
        bytes memory data = "";
        
        hoax(address(s_entryPoint));
        s_wallet.executeUserOp(to, amount, data);
    }

    function _makeOp() private returns(UserOperation memory) {
        address sender_ = makeAddr("sender");
        address paymaster_ = makeAddr("paymaster");
        UserOperation memory op = UserOperation({
            sender: sender_,
            nonce: 0,
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
        return op;
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


    /*zzzz
    function testFuzz_burn_with_value_and_balance_variations(uint value, uint addedBalance) public {
        value = _limitFunds(value);
        addedBalance =_limitFunds(addedBalance);         
        vm.deal(address(s_burn), addedBalance);
        s_burn.burn{value: value}();
    }

    function testFuzz_burn_with_value_balance_and_cap_variations(uint value, uint addedBalance, uint burnCap) public {
        value = _limitFunds(value);
        addedBalance = _limitFunds(addedBalance); 
        burnCap = _limitFunds(burnCap); 

        _updateBurnCap(burnCap);        

        vm.deal(address(s_burn), addedBalance);
        s_burn.burn{value: value}();
    }
    ***/

    // function testFuzz_burn_with_burnCap_lesser_than_balance_results_in_no_eth_transfer(uint burnCap) public {
    //     burnCap = _limitFunds(burnCap);

    //     if (address(s_burn).balance <= burnCap) {
    //         vm.deal(address(s_burn), burnCap+1); 
    //     }
        
    //     _updateBurnCap(burnCap); zzzzzz OutOfBounds(burnCap, 2851217494792020368862436 [2.851e24], 2851217494792020368862437 

    //     assertTrue( burnCap >= address(s_burn).balance, "bad burnCap value");

    //     address sender = makeAddr("Joe");
        
    //     uint value = burnCap; 
    //     _hoaxWithGas(sender, value); // internally adds ADDITIONAL_GAS_FEES to value

    //     uint preSenderBalance = address(sender).balance;

    //     s_burn.burn{value: value}();

    //     uint postSenderBalance = address(sender).balance;

    //     console.log("preSenderBalance: %s, postSenderBalance: %s", preSenderBalance, postSenderBalance);

    //     assertTrue(postSenderBalance > preSenderBalance - ADDITIONAL_GAS_FEES , "no eth should have been transferred to sender");
    // }


    /*** zzzz

    function test_verify_nonGov_cannot_updateParams() public {
        uint legalBurnCapValue = address(s_burn).balance + 1;
        vm.prank(makeAddr("Joe"));
        vm.expectRevert(abi.encodePacked(ONLY_GOV_ALLOWED_MSG));
        s_burn.updateParam(BURN_CAP_KEY, abi.encodePacked(legalBurnCapValue));
    }

    function testFuzz_updateParams_success_scenario(uint newBurnCap,uint addedBalance) public {
        vm.deal(address(s_burn), addedBalance);
        vm.assume( newBurnCap >= address(s_burn).balance); //@test?? 

        _updateBurnCap(newBurnCap);        

        assertEq(newBurnCap, s_burn.burnCap(), "bad cap value");
    }

    function testFuzz_updateParams_bad_paramName(string memory paramName, uint addedBalance) public {
        vm.assume(!_strEqual(paramName, s_burn.BURN_CAP_KEY())); // else no BAD_PARAM_ERROR_MSG revert
        addedBalance = _limitFunds(addedBalance); 
        uint origBurnCap = s_burn.burnCap();
        vm.deal(address(s_burn), addedBalance);                
        vm.prank(s_addresses.govHub);

        uint legalBurnCapValue = address(s_burn).balance + 1;

        vm.expectRevert(abi.encodePacked(BAD_PARAM_ERROR_MSG));
        s_burn.updateParam(paramName, abi.encodePacked(legalBurnCapValue));

        assertEq(origBurnCap, s_burn.burnCap(), "bad cap value");
    }
    **/

    // function testFuzz_updateParams_with_bad_burnBap(uint newBurnCap, uint addedBalance) public {
    //     addedBalance = _limitFunds(addedBalance); 
    //     vm.deal(address(s_burn), addedBalance);

    //     uint origBurnCap = s_burn.burnCap();
    //     uint origBalance = address(s_burn).balance;

    //     vm.assume( newBurnCap < address(s_burn).balance); // should result in OutOfBounds error
        
    //     vm.expectRevert(
    //         abi.encodeWithSelector(System.OutOfBounds.selector, BURN_CAP_KEY, newBurnCap, origBalance, type(uint256).max)
    //     );
    //     _updateBurnCap(newBurnCap);

    //     assertEq(origBurnCap, s_burn.burnCap(), "bad cap value");zzzzz
    // }


    // function _updateBurnCap(uint newBurnCap) private {
    //     uint origCap = s_burn.burnCap();
    //     vm.prank(s_addresses.govHub);
    //     s_burn.updateParam(BURN_CAP_KEY, abi.encodePacked(newBurnCap));
    //     uint newCap = s_burn.burnCap();
    //     console.log("orig cap: %d, new cap: %d", origCap, newCap);
    //     assertEq(newBurnCap, s_burn.burnCap(), "cap not updated");
    // }

}		
