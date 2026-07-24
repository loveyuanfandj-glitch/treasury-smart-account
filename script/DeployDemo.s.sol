// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import {
    IEntryPoint,
    IEntryPointStake,
    PackedUserOperation
} from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Script } from "forge-std/Script.sol";
import { console2 } from "forge-std/console2.sol";

import { TreasurySmartAccount } from "../src/TreasurySmartAccount.sol";
import { TreasurySmartAccountFactory } from "../src/TreasurySmartAccountFactory.sol";

interface IEntryPointHash {
    function getUserOpHash(PackedUserOperation calldata userOp) external view returns (bytes32);
}

contract DemoTreasuryToken is ERC20, Ownable {
    constructor(address owner_) ERC20("Demo Treasury USD", "dtUSD") Ownable(owner_) { }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }
}

contract DemoTarget {
    uint256 public value;

    function setValue(uint256 value_) external {
        value = value_;
    }
}

contract DeployDemo is Script {
    uint256 private constant SESSION_PRIVATE_KEY =
        uint256(keccak256("TREASURY_SMART_ACCOUNT_PUBLIC_TESTNET_DEMO_SESSION_KEY"));
    uint128 private constant VERIFICATION_GAS_LIMIT = 500_000;
    uint128 private constant CALL_GAS_LIMIT = 500_000;
    uint128 private constant MAX_PRIORITY_FEE_PER_GAS = 1_000_000;
    uint128 private constant MAX_FEE_PER_GAS = 100_000_000;
    uint256 private constant ENTRY_POINT_DEPOSIT = 0.001 ether;
    uint256 private constant SESSION_TRANSFER = 25 ether;

    function run()
        external
        returns (
            TreasurySmartAccountFactory factory,
            TreasurySmartAccount account,
            DemoTreasuryToken token,
            DemoTarget target
        )
    {
        address deployer = vm.envAddress("DEMO_DEPLOYER");
        IEntryPoint entryPoint = IEntryPoint(vm.envAddress("ENTRY_POINT"));
        address sessionKey = vm.addr(SESSION_PRIVATE_KEY);

        vm.startBroadcast();

        factory = new TreasurySmartAccountFactory(entryPoint);
        account = factory.createAccount(deployer, deployer, keccak256("BASE_SEPOLIA_DEMO"));
        token = new DemoTreasuryToken(deployer);
        target = new DemoTarget();

        account.executeOwner(address(target), 0, abi.encodeCall(DemoTarget.setValue, (42)));

        token.mint(address(account), 100 ether);
        account.configureSession(
            sessionKey,
            TreasurySmartAccount.SessionConfig({
                target: address(token),
                selector: IERC20.transfer.selector,
                spendToken: address(token),
                dailyLimit: 50 ether,
                validAfter: 0,
                validUntil: uint48(block.timestamp + 1 days)
            })
        );

        bytes32 userOpHash = _submitSessionUserOp(entryPoint, account, token, deployer, sessionKey);
        _withdrawEntryPointDeposit(entryPoint, account, deployer);

        vm.stopBroadcast();

        _assertDemo(entryPoint, account, token, target, deployer, sessionKey);
        _logDemo(factory, account, token, target, sessionKey, userOpHash);
    }

    function _submitSessionUserOp(
        IEntryPoint entryPoint,
        TreasurySmartAccount account,
        DemoTreasuryToken token,
        address deployer,
        address sessionKey
    ) private returns (bytes32 userOpHash) {
        entryPoint.depositTo{ value: ENTRY_POINT_DEPOSIT }(address(account));
        PackedUserOperation memory userOp = _buildSessionUserOp(account, token, deployer, sessionKey);
        userOpHash = IEntryPointHash(address(entryPoint)).getUserOpHash(userOp);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SESSION_PRIVATE_KEY, userOpHash);
        userOp.signature = abi.encodePacked(uint8(account.SESSION_SIGNATURE_MODE()), r, s, v);

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        entryPoint.handleOps(userOps, payable(deployer));
    }

    function _withdrawEntryPointDeposit(IEntryPoint entryPoint, TreasurySmartAccount account, address deployer)
        private
    {
        uint256 depositRemainder = entryPoint.balanceOf(address(account));
        account.executeOwner(
            address(entryPoint), 0, abi.encodeCall(IEntryPointStake.withdrawTo, (payable(deployer), depositRemainder))
        );
    }

    function _assertDemo(
        IEntryPoint entryPoint,
        TreasurySmartAccount account,
        DemoTreasuryToken token,
        DemoTarget target,
        address deployer,
        address sessionKey
    ) private view {
        uint256 day = block.timestamp / 1 days;
        require(target.value() == 42, "owner execution failed");
        require(token.balanceOf(address(account)) == 75 ether, "account token balance mismatch");
        require(token.balanceOf(deployer) == SESSION_TRANSFER, "session transfer failed");
        require(account.dailySpent(sessionKey, day) == SESSION_TRANSFER, "session spend not recorded");
        require(entryPoint.balanceOf(address(account)) == 0, "entry point deposit remains");
    }

    function _logDemo(
        TreasurySmartAccountFactory factory,
        TreasurySmartAccount account,
        DemoTreasuryToken token,
        DemoTarget target,
        address sessionKey,
        bytes32 userOpHash
    ) private pure {
        console2.log("TreasurySmartAccountFactory", address(factory));
        console2.log("TreasurySmartAccount", address(account));
        console2.log("DemoTreasuryToken", address(token));
        console2.log("DemoTarget", address(target));
        console2.log("DemoSessionKey", sessionKey);
        console2.logBytes32(userOpHash);
    }

    function _buildSessionUserOp(
        TreasurySmartAccount account,
        DemoTreasuryToken token,
        address recipient,
        address sessionKey
    ) private view returns (PackedUserOperation memory) {
        bytes memory transferData = abi.encodeCall(IERC20.transfer, (recipient, SESSION_TRANSFER));
        bytes memory callData =
            abi.encodeCall(TreasurySmartAccount.executeSession, (sessionKey, address(token), 0, transferData));

        return PackedUserOperation({
            sender: address(account),
            nonce: account.getNonce(),
            initCode: "",
            callData: callData,
            accountGasLimits: bytes32((uint256(VERIFICATION_GAS_LIMIT) << 128) | uint256(CALL_GAS_LIMIT)),
            preVerificationGas: 100_000,
            gasFees: bytes32((uint256(MAX_PRIORITY_FEE_PER_GAS) << 128) | uint256(MAX_FEE_PER_GAS)),
            paymasterAndData: "",
            signature: ""
        });
    }
}
