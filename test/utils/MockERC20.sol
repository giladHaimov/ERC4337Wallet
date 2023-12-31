// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {ERC20} from "./ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Name", "SYM") {
        this;
    }
}