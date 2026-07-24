// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Script } from "forge-std/Script.sol";

import { IEntryPoint } from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";

import { TreasurySmartAccount } from "../src/TreasurySmartAccount.sol";
import { TreasurySmartAccountFactory } from "../src/TreasurySmartAccountFactory.sol";

contract Deploy is Script {
    function run() external returns (TreasurySmartAccountFactory factory, TreasurySmartAccount account) {
        IEntryPoint entryPoint = IEntryPoint(vm.envAddress("ENTRY_POINT"));
        address owner = vm.envAddress("ACCOUNT_OWNER");
        address guardian = vm.envAddress("ACCOUNT_GUARDIAN");
        bytes32 salt = vm.envBytes32("ACCOUNT_SALT");

        vm.startBroadcast();
        factory = new TreasurySmartAccountFactory(entryPoint);
        account = factory.createAccount(owner, guardian, salt);
        vm.stopBroadcast();
    }
}
