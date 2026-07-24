// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Test } from "forge-std/Test.sol";

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { TreasurySmartAccount } from "../../src/TreasurySmartAccount.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

contract SessionHandler is Test {
    MockERC20 public immutable token;
    address public immutable sessionKey;
    address public immutable recipient;
    TreasurySmartAccount public account;

    constructor(MockERC20 token_, address sessionKey_, address recipient_) {
        token = token_;
        sessionKey = sessionKey_;
        recipient = recipient_;
    }

    function setAccount(TreasurySmartAccount account_) external {
        if (address(account) != address(0)) return;
        account = account_;
    }

    function spend(uint256 seed) external {
        if (address(account) == address(0)) return;
        TreasurySmartAccount.Session memory session = account.getSession(sessionKey);
        uint256 day = block.timestamp / 1 days;
        uint256 spent = account.dailySpent(sessionKey, day);
        if (spent >= session.dailyLimit || token.balanceOf(address(account)) == 0) return;

        uint256 remaining = session.dailyLimit - spent;
        uint256 amount = bound(seed, 1, remaining);
        account.executeSession(sessionKey, address(token), 0, abi.encodeCall(IERC20.transfer, (recipient, amount)));
    }
}
