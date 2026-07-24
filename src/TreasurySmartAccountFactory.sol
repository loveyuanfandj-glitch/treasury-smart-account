// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { IEntryPoint } from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";

import { TreasurySmartAccount } from "./TreasurySmartAccount.sol";

contract TreasurySmartAccountFactory {
    IEntryPoint public immutable entryPoint;

    error ZeroAddress();

    event AccountCreated(address indexed account, address indexed owner, address indexed guardian, bytes32 salt);

    constructor(IEntryPoint entryPoint_) {
        if (address(entryPoint_) == address(0)) revert ZeroAddress();
        entryPoint = entryPoint_;
    }

    function createAccount(address owner, address guardian, bytes32 salt)
        external
        returns (TreasurySmartAccount account)
    {
        bytes32 deploymentSalt = keccak256(abi.encode(owner, guardian, salt));
        account = new TreasurySmartAccount{ salt: deploymentSalt }(owner, guardian, entryPoint);
        emit AccountCreated(address(account), owner, guardian, salt);
    }

    function getAddress(address owner, address guardian, bytes32 salt) external view returns (address) {
        bytes32 deploymentSalt = keccak256(abi.encode(owner, guardian, salt));
        bytes memory creationCode =
            abi.encodePacked(type(TreasurySmartAccount).creationCode, abi.encode(owner, guardian, entryPoint));
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), deploymentSalt, keccak256(creationCode)));
        return address(uint160(uint256(hash)));
    }
}
