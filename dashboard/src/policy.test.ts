import { expect, test } from "vitest";
import { evaluateSessionPolicy } from "./policy";

// Validates a transfer inside the remaining allowance passes every stored session boundary.
test("approves a transfer inside the scoped daily allowance", () => {
  const result = evaluateSessionPolicy(25, 25, 100);

  expect(result.approved).toBe(true);
  expect(result.remaining).toBe(50);
  expect(result.checks.every((check) => check.passed)).toBe(true);
});

// Validates the simulator rejects overspend and selector mismatches through independent policy paths.
test("blocks overspend or selector mismatch", () => {
  expect(evaluateSessionPolicy(76, 25, 100).approved).toBe(false);
  expect(evaluateSessionPolicy(25, 25, 100, true, false).approved).toBe(false);
});
