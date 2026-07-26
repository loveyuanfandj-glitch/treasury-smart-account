import {
  ACCOUNT_ADDRESS,
  ENTRY_POINT_ADDRESS,
  FACTORY_ADDRESS,
  SESSION_KEY_ADDRESS,
  TOKEN_ADDRESS,
} from "./contracts";

export interface TreasurySnapshot {
  blockNumber: string;
  owner: string;
  guardian: string;
  paused: boolean;
  sessionEpoch: number;
  source: "live" | "verified snapshot";
}

export const verifiedSnapshot: TreasurySnapshot = {
  blockNumber: "34,125,902",
  owner: "0x1f444f41a803e3c32B56F1Eb2597914730246A11",
  guardian: "0x1f444f41a803e3c32B56F1Eb2597914730246A11",
  paused: false,
  sessionEpoch: 0,
  source: "verified snapshot",
};

export const addresses = [
  { label: "Smart account", value: ACCOUNT_ADDRESS, tone: "violet" },
  { label: "Factory", value: FACTORY_ADDRESS, tone: "blue" },
  { label: "EntryPoint v0.9", value: ENTRY_POINT_ADDRESS, tone: "lime" },
  { label: "Demo dtUSD", value: TOKEN_ADDRESS, tone: "amber" },
] as const;

export const sessionPolicy = {
  key: SESSION_KEY_ADDRESS,
  target: TOKEN_ADDRESS,
  selector: "0xa9059cbb",
  functionName: "transfer(address,uint256)",
  dailyLimit: 100,
  spent: 25,
  token: "dtUSD",
  validFrom: "24 Jul · 08:17 UTC",
  validUntil: "25 Jul · 08:17 UTC",
};

export const activity = [
  { type: "UserOperation", detail: "Session transfer · 25 dtUSD", state: "Included", time: "24 Jul · 08:23", hash: "0x7aed69b5ed043f804f7a7a3c99b6b8698a65243a21c7f2d9bd86bc8d7dddd6be" },
  { type: "Session configured", detail: "ERC-20 transfer policy", state: "Finalized", time: "24 Jul · 08:17", hash: "0x77fe1a1e191e8346f34fd669ee6773f327e74e7d3a82a6bcdb7d3844763b7e06" },
  { type: "EntryPoint deposit", detail: "Gas sponsorship funded", state: "Finalized", time: "24 Jul · 08:19", hash: "0x0922ca2a41bba090be84db0ebc222c7d117e00a6d1c15ab30a18ac0fa6a1625d" },
  { type: "Owner execution", detail: "DemoTarget setValue(42)", state: "Finalized", time: "24 Jul · 08:14", hash: "0x65c34b81d940a8b317ee3c97ce08005c3717c9c38d5b152f1036695d70f2e55d" },
] as const;

export const lifecycle = [
  { label: "CREATE2 account", meta: "Predicted = deployed" },
  { label: "Scoped session", meta: "Target + selector + cap" },
  { label: "ERC-4337 UserOp", meta: "EntryPoint v0.9" },
  { label: "Daily accounting", meta: "25 / 100 dtUSD" },
] as const;
