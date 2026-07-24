// SPDX-License-Identifier: MIT
pragma solidity 0.8.34;

import { Account } from "@openzeppelin/contracts/account/Account.sol";
import { ERC4337Utils } from "@openzeppelin/contracts/account/utils/draft-ERC4337Utils.sol";
import { IEntryPoint, PackedUserOperation } from "@openzeppelin/contracts/interfaces/draft-IERC4337.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SignatureChecker } from "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TreasurySmartAccount is Account, IERC1271, Pausable, ReentrancyGuard {
    struct Call {
        address target;
        uint256 value;
        bytes data;
    }

    struct SessionConfig {
        address target;
        bytes4 selector;
        address spendToken;
        uint256 dailyLimit;
        uint48 validAfter;
        uint48 validUntil;
    }

    struct Session {
        address target;
        bytes4 selector;
        address spendToken;
        uint256 dailyLimit;
        uint48 validAfter;
        uint48 validUntil;
        uint64 epoch;
        bool active;
    }

    uint8 public constant OWNER_SIGNATURE_MODE = 0;
    uint8 public constant SESSION_SIGNATURE_MODE = 1;
    uint48 public constant OWNER_CHANGE_DELAY = 1 days;
    uint48 public constant RECOVERY_DELAY = 2 days;
    bytes4 public constant ERC1271_MAGIC_VALUE = IERC1271.isValidSignature.selector;

    IEntryPoint private immutable _entryPoint;

    address public owner;
    address public guardian;
    address public pendingOwner;
    uint48 public ownerChangeAvailableAt;
    address public pendingRecoveryOwner;
    uint48 public recoveryAvailableAt;
    uint64 public sessionEpoch;

    mapping(address sessionKey => Session session) private _sessions;
    mapping(address sessionKey => mapping(uint256 day => uint256 amount)) public dailySpent;

    error ZeroAddress();
    error Unauthorized(address caller);
    error InvalidSessionConfiguration();
    error InvalidSessionPolicy();
    error SessionKeyMustBeEoa();
    error SessionLimitExceeded(uint256 spent, uint256 limit);
    error ExternalCallFailed(bytes returnData);
    error OwnerChangeNotReady(uint48 availableAt);
    error InvalidPendingOwner();
    error RecoveryNotReady(uint48 availableAt);
    error NoPendingRecovery();

    event OwnerChangeStarted(address indexed currentOwner, address indexed pendingOwner, uint48 availableAt);
    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event GuardianChanged(address indexed previousGuardian, address indexed newGuardian);
    event SessionConfigured(
        address indexed sessionKey,
        address indexed target,
        bytes4 indexed selector,
        address spendToken,
        uint256 dailyLimit,
        uint48 validAfter,
        uint48 validUntil,
        uint64 epoch
    );
    event SessionRevoked(address indexed sessionKey);
    event SessionExecuted(address indexed sessionKey, address indexed target, uint256 spend, uint256 day);
    event RecoveryStarted(address indexed guardian, address indexed newOwner, uint48 availableAt);
    event RecoveryCancelled(address indexed owner);

    modifier onlyOwnerOrEntryPoint() {
        address caller = msg.sender;
        if (caller != owner && caller != address(entryPoint())) revert Unauthorized(caller);
        _;
    }

    modifier onlyGuardian() {
        if (msg.sender != guardian) revert Unauthorized(msg.sender);
        _;
    }

    constructor(address owner_, address guardian_, IEntryPoint entryPoint_) {
        if (
            owner_ == address(0) || guardian_ == address(0) || address(entryPoint_) == address(0)
                || owner_ == address(this)
        ) revert ZeroAddress();
        owner = owner_;
        guardian = guardian_;
        _entryPoint = entryPoint_;
    }

    function entryPoint() public view override returns (IEntryPoint) {
        return _entryPoint;
    }

    function getSession(address sessionKey) external view returns (Session memory) {
        return _sessions[sessionKey];
    }

    function executeOwner(address target, uint256 value, bytes calldata data)
        external
        whenNotPaused
        nonReentrant
        onlyOwnerOrEntryPoint
        returns (bytes memory)
    {
        return _call(target, value, data);
    }

    function executeBatchOwner(Call[] calldata calls)
        external
        whenNotPaused
        nonReentrant
        onlyOwnerOrEntryPoint
        returns (bytes[] memory results)
    {
        results = new bytes[](calls.length);
        for (uint256 i; i < calls.length; ++i) {
            results[i] = _call(calls[i].target, calls[i].value, calls[i].data);
        }
    }

    function executeSession(address sessionKey, address target, uint256 value, bytes calldata data)
        external
        whenNotPaused
        nonReentrant
        onlyEntryPoint
        returns (bytes memory)
    {
        uint256 spend = _consumeSession(sessionKey, target, value, data);
        bytes memory result = _call(target, value, data);
        emit SessionExecuted(sessionKey, target, spend, block.timestamp / 1 days);
        return result;
    }

    function configureSession(address sessionKey, SessionConfig calldata config) external onlyOwnerOrEntryPoint {
        if (sessionKey == address(0) || config.target == address(0)) revert ZeroAddress();
        if (sessionKey.code.length != 0) revert SessionKeyMustBeEoa();
        if (
            config.selector == bytes4(0) || config.dailyLimit == 0 || config.validUntil <= config.validAfter
                || config.validUntil <= block.timestamp
        ) revert InvalidSessionConfiguration();
        if (
            config.spendToken != address(0)
                && (config.target != config.spendToken || config.selector != IERC20.transfer.selector)
        ) revert InvalidSessionConfiguration();

        _sessions[sessionKey] = Session({
            target: config.target,
            selector: config.selector,
            spendToken: config.spendToken,
            dailyLimit: config.dailyLimit,
            validAfter: config.validAfter,
            validUntil: config.validUntil,
            epoch: sessionEpoch,
            active: true
        });
        emit SessionConfigured(
            sessionKey,
            config.target,
            config.selector,
            config.spendToken,
            config.dailyLimit,
            config.validAfter,
            config.validUntil,
            sessionEpoch
        );
    }

    function revokeSession(address sessionKey) external onlyOwnerOrEntryPoint {
        _sessions[sessionKey].active = false;
        emit SessionRevoked(sessionKey);
    }

    function pause() external {
        if (msg.sender != owner && msg.sender != guardian) revert Unauthorized(msg.sender);
        _pause();
    }

    function unpause() external onlyOwnerOrEntryPoint {
        _unpause();
    }

    function updateGuardian(address newGuardian) external onlyOwnerOrEntryPoint {
        if (newGuardian == address(0)) revert ZeroAddress();
        address previousGuardian = guardian;
        guardian = newGuardian;
        emit GuardianChanged(previousGuardian, newGuardian);
    }

    function startOwnerChange(address newOwner) external onlyOwnerOrEntryPoint {
        if (newOwner == address(0) || newOwner == address(this)) revert ZeroAddress();
        pendingOwner = newOwner;
        ownerChangeAvailableAt = uint48(block.timestamp) + OWNER_CHANGE_DELAY;
        emit OwnerChangeStarted(owner, newOwner, ownerChangeAvailableAt);
    }

    function acceptOwner() external {
        if (msg.sender != pendingOwner) revert InvalidPendingOwner();
        if (block.timestamp < ownerChangeAvailableAt) revert OwnerChangeNotReady(ownerChangeAvailableAt);
        _changeOwner(pendingOwner);
        pendingOwner = address(0);
        ownerChangeAvailableAt = 0;
    }

    function startRecovery(address newOwner) external onlyGuardian whenPaused {
        if (newOwner == address(0) || newOwner == address(this)) revert ZeroAddress();
        pendingRecoveryOwner = newOwner;
        recoveryAvailableAt = uint48(block.timestamp) + RECOVERY_DELAY;
        emit RecoveryStarted(msg.sender, newOwner, recoveryAvailableAt);
    }

    function cancelRecovery() external onlyOwnerOrEntryPoint {
        if (pendingRecoveryOwner == address(0)) revert NoPendingRecovery();
        pendingRecoveryOwner = address(0);
        recoveryAvailableAt = 0;
        emit RecoveryCancelled(owner);
    }

    function completeRecovery() external whenPaused {
        address newOwner = pendingRecoveryOwner;
        if (newOwner == address(0)) revert NoPendingRecovery();
        if (block.timestamp < recoveryAvailableAt) revert RecoveryNotReady(recoveryAvailableAt);

        _changeOwner(newOwner);
        pendingRecoveryOwner = address(0);
        recoveryAvailableAt = 0;
    }

    function isValidSignature(bytes32 hash, bytes calldata signature) external view returns (bytes4) {
        return
            SignatureChecker.isValidSignatureNowCalldata(owner, hash, signature)
                ? ERC1271_MAGIC_VALUE
                : bytes4(0xffffffff);
    }

    function _validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, bytes calldata signature)
        internal
        view
        override
        returns (uint256)
    {
        if (signature.length < 2) return ERC4337Utils.SIG_VALIDATION_FAILED;

        uint8 mode = uint8(signature[0]);
        bytes calldata innerSignature = signature[1:];
        if (mode == OWNER_SIGNATURE_MODE) {
            bool valid = SignatureChecker.isValidSignatureNowCalldata(owner, userOpHash, innerSignature);
            return valid ? ERC4337Utils.SIG_VALIDATION_SUCCESS : ERC4337Utils.SIG_VALIDATION_FAILED;
        }
        if (mode != SESSION_SIGNATURE_MODE || paused()) return ERC4337Utils.SIG_VALIDATION_FAILED;

        (address recovered, ECDSA.RecoverError err,) = ECDSA.tryRecoverCalldata(userOpHash, innerSignature);
        if (err != ECDSA.RecoverError.NoError) return ERC4337Utils.SIG_VALIDATION_FAILED;
        if (userOp.callData.length < 4 || bytes4(userOp.callData[0:4]) != this.executeSession.selector) {
            return ERC4337Utils.SIG_VALIDATION_FAILED;
        }

        (address sessionKey, address target, uint256 value, bytes memory data) =
            abi.decode(userOp.callData[4:], (address, address, uint256, bytes));
        Session storage session = _sessions[sessionKey];
        (bool policyValid, uint256 spend) = _sessionPolicy(session, target, value, data);
        uint256 day = block.timestamp / 1 days;
        uint256 spentToday = dailySpent[sessionKey][day];
        bool limitValid = spentToday <= session.dailyLimit && spend <= session.dailyLimit - spentToday;
        if (recovered != sessionKey || !policyValid || !limitValid) {
            return ERC4337Utils.SIG_VALIDATION_FAILED;
        }

        return ERC4337Utils.packValidationData(true, session.validAfter, session.validUntil);
    }

    function _rawSignatureValidation(bytes32 hash, bytes calldata signature) internal view override returns (bool) {
        return SignatureChecker.isValidSignatureNowCalldata(owner, hash, signature);
    }

    function _consumeSession(address sessionKey, address target, uint256 value, bytes memory data)
        private
        returns (uint256 spend)
    {
        Session storage session = _sessions[sessionKey];
        (bool valid, uint256 policySpend) = _sessionPolicy(session, target, value, data);
        if (!valid) revert InvalidSessionPolicy();

        uint256 day = block.timestamp / 1 days;
        uint256 spentToday = dailySpent[sessionKey][day];
        if (spentToday > session.dailyLimit || policySpend > session.dailyLimit - spentToday) {
            revert SessionLimitExceeded(spentToday, session.dailyLimit);
        }
        uint256 newSpent = spentToday + policySpend;
        dailySpent[sessionKey][day] = newSpent;
        return policySpend;
    }

    function _sessionPolicy(Session storage session, address target, uint256 value, bytes memory data)
        private
        view
        returns (bool valid, uint256 spend)
    {
        if (
            !session.active || session.epoch != sessionEpoch || block.timestamp < session.validAfter
                || block.timestamp > session.validUntil || target != session.target || data.length < 4
        ) return (false, 0);

        bytes4 selector;
        assembly ("memory-safe") {
            selector := mload(add(data, 0x20))
        }
        if (selector != session.selector) return (false, 0);

        if (session.spendToken == address(0)) {
            spend = value;
        } else {
            if (target != session.spendToken || selector != IERC20.transfer.selector || value != 0 || data.length != 68)
            {
                return (false, 0);
            }
            assembly ("memory-safe") {
                spend := mload(add(data, 0x44))
            }
        }

        return (true, spend);
    }

    function _call(address target, uint256 value, bytes memory data) private returns (bytes memory result) {
        if (target == address(0)) revert ZeroAddress();
        (bool success, bytes memory returnData) = target.call{ value: value }(data);
        if (!success) revert ExternalCallFailed(returnData);
        return returnData;
    }

    function _changeOwner(address newOwner) private {
        address previousOwner = owner;
        owner = newOwner;
        sessionEpoch += 1;
        emit OwnerChanged(previousOwner, newOwner);
    }
}
