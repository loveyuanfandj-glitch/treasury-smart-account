// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { PackedUserOperation } from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";

import { TreasurySmartAccount } from "../../src/TreasurySmartAccount.sol";

contract MockEntryPoint {
    function validate(TreasurySmartAccount account, PackedUserOperation calldata userOp, bytes32 userOpHash)
        external
        returns (uint256)
    {
        return account.validateUserOp(userOp, userOpHash, 0);
    }

    function executeSession(
        TreasurySmartAccount account,
        address sessionKey,
        address target,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory) {
        return account.executeSession(sessionKey, target, value, data);
    }

    function executeOwner(TreasurySmartAccount account, address target, uint256 value, bytes calldata data)
        external
        returns (bytes memory)
    {
        return account.executeOwner(target, value, data);
    }
}
