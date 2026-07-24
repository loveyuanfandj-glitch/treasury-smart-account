# Threat model

## Protected assets and properties

- Native currency and tokens held by the account.
- Owner authority.
- Session-key scope, validity, and daily limits.
- Recovery availability.

## Considered threats

- Compromised session key: target, selector, validity, token mode, and daily cap limit damage.
- UserOperation replay: delegated to ERC-4337 EntryPoint nonce management.
- Session reuse after owner recovery: epoch invalidation.
- Malicious arbitrary calldata disguised as ERC-20 transfer: exact selector and calldata-length checks.
- Daily-limit overflow: subtraction-based capacity checks avoid arithmetic overflow.
- Reentrant target: owner and session execution paths use `ReentrancyGuard`.
- Guardian response: immediate pause and delayed owner recovery.
- Factory address mismatch: CREATE2 prediction is covered by unit tests.

## Trust assumptions

| Actor/component | Assumption |
| --- | --- |
| Owner | Protects the root signing authority and configures sessions correctly |
| Guardian | Freezes/recoveries only when authorized |
| EntryPoint | Correctly validates returned data and executes only validated UserOperations |
| Session target | Behaves according to its selected function ABI |

## Residual risks

- Owner compromise before guardian pause.
- Malicious guardian recovery after the delay.
- Timestamp manipulation around validity/day boundaries.
- Protocols that give nonstandard meaning to an allowed selector.
- ERC-1271 owner signatures may be revocable and change validity over time.
- No social recovery quorum or multi-guardian threshold.
