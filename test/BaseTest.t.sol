// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {Deployer} from "../script/Deployer.s.sol";
import {ERC4337Wallet} from "../src/ERC4337Wallet.sol";

abstract contract BaseTest is Test {
    
    uint constant internal MAX_ETH_VALUE = 10_000_000 ether; // or any other reasonable cap
    uint constant internal ADDITIONAL_GAS_FEES = 100 ether; // or any other reasonable value

    bool constant internal ACCEPT_PAYMENTS = true; // test EOAs/eth-accepting contracts
    bool constant internal REJECT_PAYMENTS = false;  // test eth-rejecting (hostile?) contracts

    Deployer internal deployer;
    ERC4337Wallet internal wallet;
    
    bool internal acceptPayment; // mutable by design. to be set by a derived test on demand

    constructor(bool accept) {
        acceptPayment = accept;
    }

    receive() external payable {
        if (!acceptPayment) { 
            revert("payment rejected");
        }
    } 

    function setUp() public virtual {
        deployer = new Deployer();
        wallet = deployer.run();
    }

    function _hoaxWithGas(address impersonateTo) internal {
        _hoaxWithGas(impersonateTo, 0);
    }

    function _hoaxWithGas(address impersonateTo, uint value) internal {
        hoax(impersonateTo, value + ADDITIONAL_GAS_FEES);
    }

    function _limitFunds(uint value) internal view returns(uint) { 
        return bound(value, 0, MAX_ETH_VALUE); // avoiding OutOfFund error
        //vm.assume( value < MAX_ETH_VALUE); 
    }

    function _strEqual(string memory str1, string memory str2) internal pure returns (bool) {
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }
}		