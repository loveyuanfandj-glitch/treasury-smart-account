# Base Sepolia Deployment

Deployed and exercised on 2026-07-24 against EntryPoint v0.9.

| Item | Value |
| --- | --- |
| Network | Base Sepolia |
| Chain ID | `84532` |
| Owner and guardian | [`0x1f444f41a803e3c32B56F1Eb2597914730246A11`](https://sepolia.basescan.org/address/0x1f444f41a803e3c32B56F1Eb2597914730246A11) |
| EntryPoint v0.9 | [`0x433709009B8330FDa32311DF1C2AFA402eD8D009`](https://sepolia.basescan.org/address/0x433709009B8330FDa32311DF1C2AFA402eD8D009) |
| Solidity | `0.8.34` |
| Verification | Sourcify `exact_match` |

## Contracts

| Contract | Address |
| --- | --- |
| `TreasurySmartAccountFactory` | [`0x9754CF5265c93138e673b75Fd4E28bB9Ed6b8165`](https://sepolia.basescan.org/address/0x9754CF5265c93138e673b75Fd4E28bB9Ed6b8165) |
| `TreasurySmartAccount` | [`0x60EB2d8272104f93180B37748D157EF92F019c9B`](https://sepolia.basescan.org/address/0x60EB2d8272104f93180B37748D157EF92F019c9B) |
| Demo token (`dtUSD`) | [`0x4216f9cD40f5c81b2cbfA6Dec0C37F52EFBdf1D1`](https://sepolia.basescan.org/address/0x4216f9cD40f5c81b2cbfA6Dec0C37F52EFBdf1D1) |
| `DemoTarget` | [`0x20088aA50844b4ffCBD19E5006E045EC45D82064`](https://sepolia.basescan.org/address/0x20088aA50844b4ffCBD19E5006E045EC45D82064) |
| Demo session key | `0xA72C95CE64D9e78de925c05D0657e5B589e8485c` |

The factory's `getAddress` result exactly matches the deployed CREATE2 account.

## Lifecycle Transactions

| Action | Transaction |
| --- | --- |
| Deploy factory | [`0x23357fe7ccb87ab371618b76f87a5da653bf827c93ab1e726a69cb032858e2fa`](https://sepolia.basescan.org/tx/0x23357fe7ccb87ab371618b76f87a5da653bf827c93ab1e726a69cb032858e2fa) |
| CREATE2 account | [`0xb9b594a1809e016fa6adacad416a2b24ede951e925f004351be901b2ea8c7881`](https://sepolia.basescan.org/tx/0xb9b594a1809e016fa6adacad416a2b24ede951e925f004351be901b2ea8c7881) |
| Direct owner execution | [`0x65c34b81d940a8b317ee3c97ce08005c3717c9c38d5b152f1036695d70f2e55d`](https://sepolia.basescan.org/tx/0x65c34b81d940a8b317ee3c97ce08005c3717c9c38d5b152f1036695d70f2e55d) |
| Configure session | [`0x77fe1a1e191e8346f34fd669ee6773f327e74e7d3a82a6bcdb7d3844763b7e06`](https://sepolia.basescan.org/tx/0x77fe1a1e191e8346f34fd669ee6773f327e74e7d3a82a6bcdb7d3844763b7e06) |
| EntryPoint deposit | [`0x0922ca2a41bba090be84db0ebc222c7d117e00a6d1c15ab30a18ac0fa6a1625d`](https://sepolia.basescan.org/tx/0x0922ca2a41bba090be84db0ebc222c7d117e00a6d1c15ab30a18ac0fa6a1625d) |
| Session UserOperation | [`0x7aed69b5ed043f804f7a7a3c99b6b8698a65243a21c7f2d9bd86bc8d7dddd6be`](https://sepolia.basescan.org/tx/0x7aed69b5ed043f804f7a7a3c99b6b8698a65243a21c7f2d9bd86bc8d7dddd6be) |
| Withdraw EntryPoint remainder | [`0x611bd14e1274887db4c5ad43945dacf8e81eddf4ac7ad3591053393e8ebdd8a2`](https://sepolia.basescan.org/tx/0x611bd14e1274887db4c5ad43945dacf8e81eddf4ac7ad3591053393e8ebdd8a2) |

The first outer `handleOps` broadcast used an undersized transaction gas limit and reverted with EntryPoint `AA95`.
It did not consume the account nonce or change account state. The same signed UserOperation was then rebroadcast with
the required outer gas headroom and succeeded. The documented Foundry command uses
`--gas-estimate-multiplier 400` to make future runs reproducible.

## Verified State

- Owner execution set `DemoTarget.value` to `42`.
- Account nonce after the UserOperation: `1`.
- Session transfer: `25 dtUSD`.
- Account token balance: `75 dtUSD`.
- Recorded daily session spend: `25 dtUSD`.
- EntryPoint deposit after cleanup: `0`.

The deterministic demo session key is public and must never be reused for real assets.
