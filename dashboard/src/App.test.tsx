import { render, screen } from "@testing-library/react";
import { expect, test, vi } from "vitest";
import { App } from "./App";

vi.mock("./chain", () => ({ loadTreasuryState: vi.fn().mockRejectedValue(new Error("offline")) }));

// Validates the verified deployment and policy simulator remain available without RPC access.
test("renders the treasury proof dashboard from the verified snapshot", () => {
  render(<App />);

  expect(screen.getByRole("heading", { name: "Treasury overview" })).toBeInTheDocument();
  expect(screen.getByRole("heading", { name: "Session key policy" })).toBeInTheDocument();
  expect(screen.getByText("UserOp can proceed")).toBeInTheDocument();
  expect(screen.getByText("Sourcify exact match")).toBeInTheDocument();
});
