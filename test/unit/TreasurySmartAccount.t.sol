// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Test } from "forge-std/Test.sol";

import { IEntryPoint, PackedUserOperation } from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { TreasurySmartAccount } from "../../src/TreasurySmartAccount.sol";
import { TreasurySmartAccountFactory } from "../../src/TreasurySmartAccountFactory.sol";
import { MockEntryPoint } from "../mocks/MockEntryPoint.sol";
import { MockERC20 } from "../mocks/MockERC20.sol";
import { MockTarget } from "../mocks/MockTarget.sol";

contract TreasurySmartAccountTest is Test {
    uint256 private constant OWNER_KEY = 0xA11CE;
    uint256 private constant SESSION_KEY = 0xB0B;

    MockEntryPoint private mockEntryPoint;
    TreasurySmartAccount private account;
    MockERC20 private token;
    MockTarget private target;
    address private owner;
    address private sessionKey;
    address private guardian = makeAddr("guardian");
    address private recipient = makeAddr("recipient");

    function setUp() public {
        owner = vm.addr(OWNER_KEY);
        sessionKey = vm.addr(SESSION_KEY);
        mockEntryPoint = new MockEntryPoint();
        account = new TreasurySmartAccount(owner, guardian, _asEntryPoint(address(mockEntryPoint)));
        token = new MockERC20();
        target = new MockTarget();
        token.mint(address(account), 10_000 ether);
        vm.deal(address(account), 10 ether);
    }

    // Validates the owner can directly execute an arbitrary token transfer from the smart account.
    function test_OwnerExecutesDirectCall() public {
        vm.prank(owner);
        account.executeOwner(address(token), 0, abi.encodeCall(IERC20.transfer, (recipient, 100 ether)));

        assertEq(token.balanceOf(recipient), 100 ether);
        assertEq(token.balanceOf(address(account)), 9_900 ether);
    }

    // Validates arbitrary callers cannot use the unrestricted owner execution path.
    function test_RevertWhen_NonOwnerExecutesOwnerCall() public {
        vm.prank(makeAddr("attacker"));
        vm.expectRevert();
        account.executeOwner(address(target), 0, abi.encodeCall(MockTarget.setValue, (1)));
    }

    // Validates an ERC-4337 owner-mode signature produces successful validation data.
    function test_ValidateOwnerUserOperation() public {
        bytes memory callData =
            abi.encodeCall(account.executeOwner, (address(target), 0, abi.encodeCall(MockTarget.setValue, (42))));
        bytes32 userOpHash = keccak256("owner-user-operation");
        PackedUserOperation memory userOp = _userOp(callData, _modeSignature(OWNER_KEY, 0, userOpHash));

        uint256 validationData = mockEntryPoint.validate(account, userOp, userOpHash);
        assertEq(validationData, 0);
    }

    // Validates a session signature, token transfer policy, validity range, and daily accounting end to end.
    function test_SessionKeyValidatesAndExecutesTokenTransfer() public {
        _configureTokenSession(500 ether);
        bytes memory transferData = abi.encodeCall(IERC20.transfer, (recipient, 400 ether));
        bytes memory callData = abi.encodeCall(account.executeSession, (sessionKey, address(token), 0, transferData));
        bytes32 userOpHash = keccak256("session-user-operation");
        PackedUserOperation memory userOp =
            _userOp(callData, _modeSignature(SESSION_KEY, account.SESSION_SIGNATURE_MODE(), userOpHash));

        uint256 validationData = mockEntryPoint.validate(account, userOp, userOpHash);
        assertEq(validationData & type(uint160).max, 0);
        mockEntryPoint.executeSession(account, sessionKey, address(token), 0, transferData);

        assertEq(token.balanceOf(recipient), 400 ether);
        assertEq(account.dailySpent(sessionKey, block.timestamp / 1 days), 400 ether);
    }

    // Validates a session signature cannot authorize a different target or selector than its configured policy.
    function test_InvalidSessionTargetReturnsSignatureFailure() public {
        _configureTokenSession(500 ether);
        bytes memory callData = abi.encodeCall(
            account.executeSession, (sessionKey, address(target), 0, abi.encodeCall(MockTarget.setValue, (7)))
        );
        bytes32 userOpHash = keccak256("invalid-session-target");
        PackedUserOperation memory userOp =
            _userOp(callData, _modeSignature(SESSION_KEY, account.SESSION_SIGNATURE_MODE(), userOpHash));

        uint256 validationData = mockEntryPoint.validate(account, userOp, userOpHash);
        assertEq(validationData & type(uint160).max, 1);
    }

    // Validates multiple executions in the same day cannot exceed the configured token spend limit.
    function test_RevertWhen_SessionExceedsDailyLimit() public {
        _configureTokenSession(500 ether);
        bytes memory firstTransfer = abi.encodeCall(IERC20.transfer, (recipient, 400 ether));
        mockEntryPoint.executeSession(account, sessionKey, address(token), 0, firstTransfer);

        bytes memory secondTransfer = abi.encodeCall(IERC20.transfer, (recipient, 101 ether));
        vm.expectRevert();
        mockEntryPoint.executeSession(account, sessionKey, address(token), 0, secondTransfer);
        assertEq(account.dailySpent(sessionKey, block.timestamp / 1 days), 400 ether);
    }

    // Validates the owner batch path executes calls in order and forwards native value.
    function test_OwnerBatchExecution() public {
        TreasurySmartAccount.Call[] memory calls = new TreasurySmartAccount.Call[](2);
        calls[0] = TreasurySmartAccount.Call({
            target: address(target), value: 1 ether, data: abi.encodeCall(MockTarget.setValue, (1))
        });
        calls[1] = TreasurySmartAccount.Call({
            target: address(target), value: 2 ether, data: abi.encodeCall(MockTarget.setValue, (2))
        });

        vm.prank(owner);
        account.executeBatchOwner(calls);

        assertEq(target.value(), 2);
        assertEq(target.received(), 3 ether);
    }

    // Validates ERC-1271 exposes the current owner's raw signature for integrations with other protocols.
    function test_ERC1271OwnerSignature() public view {
        bytes32 hash = keccak256("treasury-approval");
        bytes memory signature = _rawSignature(OWNER_KEY, hash);

        assertEq(account.isValidSignature(hash, signature), account.ERC1271_MAGIC_VALUE());
    }

    // Validates guardian recovery requires a pause and delay, then changes the owner and invalidates old sessions.
    function test_GuardianRecoveryInvalidatesSessions() public {
        _configureTokenSession(500 ether);
        address recoveredOwner = makeAddr("recoveredOwner");

        vm.startPrank(guardian);
        account.pause();
        account.startRecovery(recoveredOwner);
        vm.stopPrank();
        vm.warp(block.timestamp + account.RECOVERY_DELAY());
        account.completeRecovery();

        assertEq(account.owner(), recoveredOwner);
        assertEq(account.sessionEpoch(), 1);
        vm.expectRevert();
        mockEntryPoint.executeSession(
            account, sessionKey, address(token), 0, abi.encodeCall(IERC20.transfer, (recipient, 1 ether))
        );
    }

    // Validates voluntary ownership transfer is two-step, delayed, and accepted only by the nominated owner.
    function test_DelayedOwnerChange() public {
        address newOwner = makeAddr("newOwner");
        vm.prank(owner);
        account.startOwnerChange(newOwner);

        vm.prank(newOwner);
        vm.expectRevert();
        account.acceptOwner();

        vm.warp(block.timestamp + account.OWNER_CHANGE_DELAY());
        vm.prank(newOwner);
        account.acceptOwner();
        assertEq(account.owner(), newOwner);
        assertEq(account.sessionEpoch(), 1);
    }

    // Validates CREATE2 address prediction exactly matches the account deployed by the factory.
    function test_FactoryCreatesPredictedAddress() public {
        TreasurySmartAccountFactory factory = new TreasurySmartAccountFactory(_asEntryPoint(address(mockEntryPoint)));
        bytes32 salt = keccak256("portfolio-account");
        address predicted = factory.getAddress(owner, guardian, salt);

        TreasurySmartAccount deployed = factory.createAccount(owner, guardian, salt);
        assertEq(address(deployed), predicted);
    }

    function _configureTokenSession(uint256 dailyLimit) private {
        TreasurySmartAccount.SessionConfig memory config = TreasurySmartAccount.SessionConfig({
            target: address(token),
            selector: IERC20.transfer.selector,
            spendToken: address(token),
            dailyLimit: dailyLimit,
            validAfter: uint48(block.timestamp),
            validUntil: uint48(block.timestamp + 7 days)
        });
        vm.prank(owner);
        account.configureSession(sessionKey, config);
    }

    function _userOp(bytes memory callData, bytes memory signature) private view returns (PackedUserOperation memory) {
        return PackedUserOperation({
            sender: address(account),
            nonce: 0,
            initCode: "",
            callData: callData,
            accountGasLimits: bytes32(0),
            preVerificationGas: 0,
            gasFees: bytes32(0),
            paymasterAndData: "",
            signature: signature
        });
    }

    function _modeSignature(uint256 privateKey, uint8 mode, bytes32 hash) private pure returns (bytes memory) {
        return abi.encodePacked(mode, _rawSignature(privateKey, hash));
    }

    function _rawSignature(uint256 privateKey, bytes32 hash) private pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, hash);
        return abi.encodePacked(r, s, v);
    }

    function _asEntryPoint(address entryPointAddress) private pure returns (IEntryPoint) {
        return IEntryPoint(entryPointAddress);
    }
}
