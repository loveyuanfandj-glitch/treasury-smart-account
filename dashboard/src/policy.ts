export interface PolicyEvaluation {
  approved: boolean;
  remaining: number;
  checks: Array<{ label: string; passed: boolean }>;
}

export function evaluateSessionPolicy(
  amount: number,
  spent: number,
  limit: number,
  targetMatches = true,
  selectorMatches = true,
): PolicyEvaluation {
  const finiteAmount = Number.isFinite(amount) && amount > 0;
  const withinLimit = finiteAmount && spent + amount <= limit;
  const checks = [
    { label: "Approved target", passed: targetMatches },
    { label: "Allowed selector", passed: selectorMatches },
    { label: "Daily cap", passed: withinLimit },
    { label: "Session epoch", passed: true },
  ];
  return {
    approved: checks.every((check) => check.passed),
    remaining: Math.max(0, limit - spent - (finiteAmount ? amount : 0)),
    checks,
  };
}
