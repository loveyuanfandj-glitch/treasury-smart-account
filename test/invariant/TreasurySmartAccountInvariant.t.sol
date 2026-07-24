// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { StdInvariant } from "forge-std/StdInvariant.sol";
import { Test } from "forge-std/Test.sol";

import { IEntryPoint } from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { TreasurySmartAccount } from "../../src/TreasurySmartAccount.sol";
import { SessionHandler } from "./SessionHandler.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

contract TreasurySmartAccountInvariantTest is StdInvariant, Test {
    uint256 private constant DAILY_LIMIT = 1_000_000 ether;

    TreasurySmartAccount private account;
    MockERC20 private token;
    SessionHandler private handler;
    address private owner = makeAddr("owner");
    address private guardian = makeAddr("guardian");
    address private sessionKey = makeAddr("sessionKey");
    address private recipient = makeAddr("recipient");

    function setUp() public {
        token = new MockERC20();
        handler = new SessionHandler(token, sessionKey, recipient);
        account = new TreasurySmartAccount(owner, guardian, IEntryPoint(address(handler)));
        handler.setAccount(account);
        token.mint(address(account), DAILY_LIMIT);

        TreasurySmartAccount.SessionConfig memory config = TreasurySmartAccount.SessionConfig({
            target: address(token),
            selector: IERC20.transfer.selector,
            spendToken: address(token),
            dailyLimit: DAILY_LIMIT,
            validAfter: uint48(block.timestamp),
            validUntil: uint48(block.timestamp + 30 days)
        });
        vm.prank(owner);
        account.configureSession(sessionKey, config);
        targetContract(address(handler));
        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = SessionHandler.spend.selector;
        targetSelector(FuzzSelector({ addr: address(handler), selectors: selectors }));
    }

    // Validates all randomized session executions remain at or below the configured daily cap.
    function invariant_SessionNeverExceedsDailyLimit() public view {
        assertLe(account.dailySpent(sessionKey, block.timestamp / 1 days), DAILY_LIMIT);
    }

    // Validates session transfers only redistribute the smart account's initially funded token balance.
    function invariant_TokenBalanceIsConserved() public view {
        assertEq(token.balanceOf(address(account)) + token.balanceOf(recipient), DAILY_LIMIT);
    }
}
