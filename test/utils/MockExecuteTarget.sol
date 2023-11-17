// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;


contract MockExecuteTarget {
    address public s_to;
    uint public s_id;
    uint public s_amount;
    string public s_str;

    function setSomeValues(address to, uint id, uint amount, string calldata str) external payable {
        s_to = to;
        s_id = id;
        s_amount = amount;
        s_str = str;
    }
}