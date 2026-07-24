// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

contract MockTarget {
    uint256 public value;
    uint256 public received;

    function setValue(uint256 value_) external payable {
        value = value_;
        received += msg.value;
    }
}
