import { createPublicClient, http } from "viem";
import { baseSepolia } from "viem/chains";
import { ACCOUNT_ADDRESS, treasuryAbi } from "./contracts";
import type { TreasurySnapshot } from "./data";

const client = createPublicClient({
  chain: baseSepolia,
  transport: http("https://sepolia.base.org", { timeout: 6_000 }),
  batch: { multicall: true },
});

export async function loadTreasuryState(): Promise<TreasurySnapshot> {
  const contract = { address: ACCOUNT_ADDRESS, abi: treasuryAbi } as const;
  const [blockNumber, owner, guardian, paused, sessionEpoch] = await Promise.all([
    client.getBlockNumber(),
    client.readContract({ ...contract, functionName: "owner" }),
    client.readContract({ ...contract, functionName: "guardian" }),
    client.readContract({ ...contract, functionName: "paused" }),
    client.readContract({ ...contract, functionName: "sessionEpoch" }),
  ]);

  return {
    blockNumber: new Intl.NumberFormat("en-US").format(blockNumber),
    owner,
    guardian,
    paused,
    sessionEpoch: Number(sessionEpoch),
    source: "live",
  };
}
