export const ACCOUNT_ADDRESS = "0x60EB2d8272104f93180B37748D157EF92F019c9B" as const;
export const FACTORY_ADDRESS = "0x9754CF5265c93138e673b75Fd4E28bB9Ed6b8165" as const;
export const ENTRY_POINT_ADDRESS = "0x433709009B8330FDa32311DF1C2AFA402eD8D009" as const;
export const TOKEN_ADDRESS = "0x4216f9cD40f5c81b2cbfA6Dec0C37F52EFBdf1D1" as const;
export const SESSION_KEY_ADDRESS = "0xA72C95CE64D9e78de925c05D0657e5B589e8485c" as const;

export const treasuryAbi = [
  {
    type: "function",
    name: "owner",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
  },
  {
    type: "function",
    name: "guardian",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
  },
  {
    type: "function",
    name: "paused",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "bool" }],
  },
  {
    type: "function",
    name: "sessionEpoch",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint64" }],
  },
] as const;
