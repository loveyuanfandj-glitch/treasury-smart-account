// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Test } from "forge-std/Test.sol";

import { IEntryPoint } from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { TreasurySmartAccount } from "../../src/TreasurySmartAccount.sol";
import { MockEntryPoint } from "../mocks/MockEntryPoint.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";

contract TreasurySmartAccountFuzzTest is Test {
    uint256 private constant DAILY_LIMIT = 1_000_000 ether;

    MockEntryPoint private mockEntryPoint;
    TreasurySmartAccount private account;
    MockERC20 private token;
    address private owner = makeAddr("owner");
    address private guardian = makeAddr("guardian");
    address private sessionKey = makeAddr("sessionKey");
    address private recipient = makeAddr("recipient");

    function setUp() public {
        mockEntryPoint = new MockEntryPoint();
        account = new TreasurySmartAccount(owner, guardian, IEntryPoint(address(mockEntryPoint)));
        token = new MockERC20();
        token.mint(address(account), DAILY_LIMIT);
        TreasurySmartAccount.SessionConfig memory config = TreasurySmartAccount.SessionConfig({
            target: address(token),
            selector: IERC20.transfer.selector,
            spendToken: address(token),
            dailyLimit: DAILY_LIMIT,
            validAfter: uint48(block.timestamp),
            validUntil: uint48(block.timestamp + 7 days)
        });
        vm.prank(owner);
        account.configureSession(sessionKey, config);
    }

    // Validates every permitted token amount is transferred exactly and charged once against the daily limit.
    function testFuzz_SessionSpendIsRecordedExactly(uint256 amount) public {
        amount = bound(amount, 1, DAILY_LIMIT);
        mockEntryPoint.executeSession(
            account, sessionKey, address(token), 0, abi.encodeCall(IERC20.transfer, (recipient, amount))
        );

        assertEq(token.balanceOf(recipient), amount);
        assertEq(account.dailySpent(sessionKey, block.timestamp / 1 days), amount);
    }
}
