# Account specification

## ERC-4337 validation

`validateUserOp` can only be called by the configured EntryPoint through the OpenZeppelin `Account` base contract.

### Owner mode

`signature[0] == 0x00`. The remaining bytes must be a current-owner signature of `userOpHash`. Both EOA and ERC-1271 owners are supported through `SignatureChecker`.

### Session mode

`signature[0] == 0x01`. The remaining bytes must recover to the session key. Validation additionally requires:

- account is not paused;
- call selector is `executeSession`;
- encoded session key equals the recovered key;
- session is active and belongs to the current epoch;
- timestamp is inside the configured validity range;
- target and inner selector match;
- spend plus same-day spend does not exceed the daily limit.

Successful session validation returns ERC-4337 timestamp validation data containing the session validity range.

## Session spending

### Native-value session

When `spendToken == address(0)`, spend equals the native value passed to the target.

### ERC-20 session

The target must equal `spendToken`, the selector must be `IERC20.transfer.selector`, native value must be zero, calldata length must be exactly 68 bytes, and spend is decoded from the transfer amount.

Daily buckets use:

```text
day = block.timestamp / 1 days
```

## Pause and recovery

- Owner or guardian may pause.
- Only owner or a validated owner UserOperation may unpause.
- Guardian starts recovery only while paused.
- Anyone may complete recovery after the delay.
- Owner may cancel recovery before completion.
- Recovery changes owner and increments `sessionEpoch`.

## Voluntary owner change

The current owner nominates a pending owner. The pending owner accepts after `OWNER_CHANGE_DELAY`. Acceptance increments `sessionEpoch`.

## Factory

The factory derives deployment salt from owner, guardian, and user-provided salt, then deploys with CREATE2. `getAddress` uses the same creation code and salt derivation.
