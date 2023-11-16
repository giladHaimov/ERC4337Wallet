// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ERC4337Wallet} from "../src/ERC4337Wallet.sol";
// import {MockEntryPoint} from "../src/test/MockEntryPoint.sol";zzzz


contract Deployer is Script {

    uint public constant MAINNET_CHAINID = 1;
    uint public constant GOERLI_CHAINID = 5;
    uint public constant SEPOLIA_CHAINID = 11155111;

    // TODO: replace with actual addresses
    address public constant MAINNET_ADDRESS = 0x71C7656EC7ab88b098defB751B7401B5f6d8976F; 
    address public constant GOERLI_ADDRESS = 0x71C7656EC7ab88b098defB751B7401B5f6d8976F;
    address public constant SEPOLIA_ADDRESS = 0x71C7656EC7ab88b098defB751B7401B5f6d8976F;


    ERC4337Wallet public wallet;
    //MockEntryPoint public entryPoint;

    function run() external returns(ERC4337Wallet) {
	    // vm.startBroadcast(); 
        if (_isLocalTestnet()) {
            wallet = _performActualDeployment();
        } else {
            wallet = ERC4337Wallet(payable(_usePredeployedContracts()));
        }
        // vm.stopBroadcast();
        return wallet;
    }

    function _performActualDeployment() private returns(ERC4337Wallet) {        
        console.log("deploying on network %s", block.chainid); 
        // entryPoint = new MockEntryPoint();
        address entryPoint = makeAddr("entryPoint");
        return new ERC4337Wallet(entryPoint);                                
    }

    function _usePredeployedContracts() private view returns(address) {  
        console.log("using pre-deployed contracts on network %s", block.chainid);
        if (block.chainid == MAINNET_CHAINID) {
            return MAINNET_ADDRESS;
        } else if (block.chainid == GOERLI_CHAINID) {
            return GOERLI_ADDRESS;
        } else if (block.chainid == SEPOLIA_CHAINID) {
            return SEPOLIA_ADDRESS;
        } else {
            revert("no pre-deployed contracts for this network");
        }
    }

    function _isLocalTestnet() private view returns(bool) {
        return block.chainid != MAINNET_CHAINID && block.chainid != GOERLI_CHAINID && block.chainid != SEPOLIA_CHAINID; 
    }
}