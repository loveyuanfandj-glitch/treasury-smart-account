# Treasury Control Plane

The control plane presents the verified Base Sepolia deployment as an
operator-facing product without widening the contract's authority surface. It
is deliberately split into two trust domains:

- **read-only chain state** comes from `https://sepolia.base.org` through
  `viem`; and
- **policy simulation** runs locally in the browser and never signs or submits
  a transaction.

## Displayed state

The live reader queries these public contract functions:

| Function | Purpose |
| --- | --- |
| `owner()` | Current unrestricted authority |
| `guardian()` | Break-glass recovery authority |
| `paused()` | Whether asset execution is blocked |
| `sessionEpoch()` | Epoch used to invalidate old sessions |

The block number comes from the same Base Sepolia public client. If the RPC is
unavailable, the interface explicitly reports a **verified deployment
snapshot** and uses the evidence captured in
[`deployments/base-sepolia.md`](../deployments/base-sepolia.md). It does not
silently claim stale state is live.

## Policy simulator

The simulator mirrors the main decisions enforced by
`TreasurySmartAccount._sessionPolicy` and `_consumeSession`:

1. target address matches the configured target;
2. selector matches the configured selector;
3. proposed amount plus recorded daily spend does not exceed the daily limit;
4. session epoch remains valid.

It is an explanatory preflight, not an alternative validator. Final authority
always remains in the Solidity contract and ERC-4337 EntryPoint.

## Local development

```bash
cd dashboard
npm ci
npm run dev
```

The control plane is available at `http://127.0.0.1:4183/`.

## Build and tests

```bash
# Contracts
forge fmt --check
forge build
forge test -vvv
forge lint

# Control plane
cd dashboard
npm run check
npm run test
npm run build
```

Unit tests cover both policy acceptance and independent overspend/selector
rejection paths. The application test verifies that the verified deployment,
session policy, and simulator remain available when RPC access fails.

## Security boundaries

- No wallet connector or private-key input is included.
- Explorer links are read-only and point to documented Base Sepolia evidence.
- The fallback snapshot is static, labelled, and based on exact-match verified
  contracts and recorded lifecycle transactions.
- The frontend cannot pause, recover, configure a session, or execute a
  UserOperation.
- The portfolio demo remains educational and does not imply a production
  security audit.

## Screenshot provenance

- `docs/images/dashboard-overview.jpg` is the default portfolio cover.
- `docs/images/policy-simulator-blocked.jpg` shows the daily-cap rejection path
  after changing the proposed transfer to `90 dtUSD`.

Both images were captured from the running Vite application at a 1920×936
browser viewport.
