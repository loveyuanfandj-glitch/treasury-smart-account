import { useEffect, useMemo, useState } from "react";
import {
  Activity, ArrowUpRight, BadgeCheck, Blocks, Check, ChevronDown, CircleDollarSign,
  Clock3, Code2, Copy, ExternalLink, Fingerprint, Gauge, GitBranch, History,
  KeyRound, LockKeyhole, Network, Pause, RefreshCw, ScanLine, ShieldCheck,
  ShieldEllipsis, Sparkles, TimerReset, UserRoundCheck, Vault, WalletCards, Zap,
} from "lucide-react";
import { loadTreasuryState } from "./chain";
import { ACCOUNT_ADDRESS } from "./contracts";
import { activity, addresses, lifecycle, sessionPolicy, verifiedSnapshot, type TreasurySnapshot } from "./data";
import { evaluateSessionPolicy } from "./policy";

function compactAddress(address: string, leading = 8): string {
  return `${address.slice(0, leading)}…${address.slice(-6)}`;
}

function explorerUrl(path: "address" | "tx", value: string): string {
  return `https://sepolia.basescan.org/${path}/${value}`;
}

function CopyButton({ value, label }: { value: string; label: string }) {
  const [copied, setCopied] = useState(false);
  async function copy() {
    await navigator.clipboard?.writeText(value);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1200);
  }
  return <button type="button" className="copy-button" onClick={() => void copy()} aria-label={`Copy ${label}`}>{copied ? <Check size={13} /> : <Copy size={13} />}</button>;
}

export function App() {
  const [chainState, setChainState] = useState<TreasurySnapshot>(verifiedSnapshot);
  const [refreshing, setRefreshing] = useState(false);
  const [amount, setAmount] = useState(25);
  const [targetMatches, setTargetMatches] = useState(true);
  const [selectorMatches, setSelectorMatches] = useState(true);
  const evaluation = useMemo(
    () => evaluateSessionPolicy(amount, sessionPolicy.spent, sessionPolicy.dailyLimit, targetMatches, selectorMatches),
    [amount, targetMatches, selectorMatches],
  );

  async function refresh() {
    setRefreshing(true);
    try { setChainState(await loadTreasuryState()); }
    catch { setChainState(verifiedSnapshot); }
    finally { setRefreshing(false); }
  }

  useEffect(() => { void refresh(); }, []);

  const utilization = (sessionPolicy.spent / sessionPolicy.dailyLimit) * 100;
  const simulationUsage = ((sessionPolicy.spent + amount) / sessionPolicy.dailyLimit) * 100;

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand"><span className="brand-icon"><Vault size={19} /></span><div><strong>VAULT<span>//</span>4337</strong><small>TREASURY CONTROL PLANE</small></div></div>
        <div className="workspace-picker"><span className="workspace-logo">VS</span><div><small>WORKSPACE</small><strong>Verified treasury</strong></div><ChevronDown size={14} /></div>
        <nav aria-label="Primary navigation">
          <a href="#overview" className="nav-item active"><Gauge size={17} />Overview</a>
          <a href="#assets" className="nav-item"><WalletCards size={17} />Assets<span>$75</span></a>
          <a href="#sessions" className="nav-item"><KeyRound size={17} />Session keys<span>1</span></a>
          <a href="#userops" className="nav-item"><Zap size={17} />UserOperations</a>
          <a href="#recovery" className="nav-item"><ShieldEllipsis size={17} />Recovery</a>
        </nav>
        <div className="nav-section"><span>PROTOCOL</span><a href="#contracts" className="nav-item"><Blocks size={17} />Contracts</a><a href="#audit" className="nav-item"><History size={17} />Audit log</a></div>
        <div className="sidebar-foot">
          <div className="network-card"><div><span className="network-pulse" />Base Sepolia</div><strong>Chain 84532</strong><small>{chainState.source === "live" ? "Live RPC connected" : "Verified deployment snapshot"}</small></div>
          <a className="repo-link" href="https://github.com/loveyuanfandj-glitch/treasury-smart-account" target="_blank" rel="noreferrer"><GitBranch size={15} />View source<ExternalLink size={13} /></a>
        </div>
      </aside>

      <main>
        <header className="topbar">
          <div className="account-selector"><span className="identicon"><ScanLine size={17} /></span><div><small>SMART ACCOUNT</small><strong>{compactAddress(ACCOUNT_ADDRESS, 10)}</strong></div><CopyButton value={ACCOUNT_ADDRESS} label="smart account address" /><ChevronDown size={13} /></div>
          <div className="top-actions"><span className="sync-state"><span />BLOCK {chainState.blockNumber}</span><button className="icon-button" type="button" onClick={() => void refresh()} aria-label="Refresh chain state"><RefreshCw size={16} className={refreshing ? "spin" : ""} /></button><a className="primary-button" href={explorerUrl("address", ACCOUNT_ADDRESS)} target="_blank" rel="noreferrer">Open explorer<ArrowUpRight size={14} /></a></div>
        </header>

        <section className="workspace" id="overview">
          <div className="page-heading"><div><div className="eyebrow">CONTROL SURFACE <span>/</span> ERC-4337 ACCOUNT</div><h1>Treasury overview</h1><p>Scoped automation, observable policy, recoverable ownership.</p></div><div className="verification-stack"><span><BadgeCheck size={14} />Sourcify exact match</span><span><ShieldCheck size={14} />EntryPoint v0.9</span></div></div>
          <div className="metric-grid">
            <article className="metric-card asset-card"><div className="metric-label"><span>VERIFIED ASSETS</span><CircleDollarSign size={17} /></div><strong>$75.00</strong><p><span className="token-dot" />75 dtUSD on Base Sepolia</p></article>
            <article className="metric-card"><div className="metric-label"><span>SESSION ALLOWANCE</span><KeyRound size={17} /></div><strong>$100<span>/ day</span></strong><div className="mini-progress"><i style={{ width: `${utilization}%` }} /></div><p>25 dtUSD consumed</p></article>
            <article className="metric-card"><div className="metric-label"><span>ACCOUNT NONCE</span><Zap size={17} /></div><strong>1</strong><p>1 successful UserOperation</p></article>
            <article className="metric-card"><div className="metric-label"><span>SECURITY STATE</span><ShieldCheck size={17} /></div><strong className="security-value"><span className={chainState.paused ? "warn-dot" : "ok-dot"} />{chainState.paused ? "Paused" : "Protected"}</strong><p>Guardian + 48h recovery delay</p></article>
          </div>

          <div className="primary-grid">
            <article className="panel session-panel" id="sessions">
              <div className="panel-heading"><div><span className="panel-kicker">DELEGATED AUTHORITY</span><h2>Session key policy</h2></div><span className="expired-badge"><Clock3 size={12} />proof completed</span></div>
              <div className="session-identity"><div className="session-avatar"><Fingerprint size={22} /></div><div><small>SESSION SIGNER</small><strong>{compactAddress(sessionPolicy.key, 12)}</strong></div><CopyButton value={sessionPolicy.key} label="session key" /></div>
              <div className="policy-layout"><div className="limit-ring" style={{ "--progress": `${utilization * 3.6}deg` } as React.CSSProperties}><div><strong>{utilization}%</strong><span>USED</span></div></div><dl className="policy-facts"><div><dt>Permitted call</dt><dd><Code2 size={13} />{sessionPolicy.functionName}</dd></div><div><dt>Target contract</dt><dd><span className="address-dot amber" />{compactAddress(sessionPolicy.target)}</dd></div><div><dt>Daily spend</dt><dd><span className="mono">25.00 / 100.00 dtUSD</span></dd></div><div><dt>Validity window</dt><dd><TimerReset size={13} />{sessionPolicy.validFrom} → {sessionPolicy.validUntil}</dd></div></dl></div>
              <div className="boundary-strip"><div><ShieldCheck size={14} /><span>Target locked</span></div><div><Code2 size={14} /><span>Selector locked</span></div><div><Clock3 size={14} /><span>Time bounded</span></div><div><Gauge size={14} /><span>Cap enforced</span></div></div>
            </article>

            <article className={`panel simulator-panel ${evaluation.approved ? "approved" : "blocked"}`}>
              <div className="panel-heading"><div><span className="panel-kicker">POLICY ENGINE</span><h2>Simulate transfer</h2></div><span className="simulation-state">{evaluation.approved ? <><Check size={12} />approved</> : <><Pause size={12} />blocked</>}</span></div>
              <label className="amount-field"><span>TRANSFER AMOUNT</span><div><input aria-label="Transfer amount" type="number" min="1" max="120" value={amount} onChange={(event) => setAmount(Number(event.target.value))} /><strong>dtUSD</strong></div></label>
              <input className="amount-slider" aria-label="Transfer amount slider" type="range" min="1" max="120" value={amount} onChange={(event) => setAmount(Number(event.target.value))} />
              <div className="simulation-bar"><i style={{ width: `${Math.min(100, simulationUsage)}%` }} /></div><div className="simulation-copy"><span>Daily utilization after call</span><strong>{Math.round(simulationUsage)}%</strong></div>
              <div className="toggle-row"><button className={targetMatches ? "enabled" : ""} type="button" onClick={() => setTargetMatches(!targetMatches)}><span />Target match</button><button className={selectorMatches ? "enabled" : ""} type="button" onClick={() => setSelectorMatches(!selectorMatches)}><span />Selector match</button></div>
              <ul className="check-list">{evaluation.checks.map((check) => <li className={check.passed ? "passed" : "failed"} key={check.label}>{check.passed ? <Check size={13} /> : <Pause size={13} />}<span>{check.label}</span><em>{check.passed ? "PASS" : "FAIL"}</em></li>)}</ul>
              <div className="decision"><span><Sparkles size={15} />VALIDATION RESULT</span><strong>{evaluation.approved ? "UserOp can proceed" : "Signature rejected"}</strong><small>{evaluation.remaining.toFixed(2)} dtUSD remains after simulation</small></div>
            </article>
          </div>

          <div className="secondary-grid">
            <article className="panel assets-panel" id="assets"><div className="panel-heading compact"><div><span className="panel-kicker">DEPLOYED SURFACE</span><h2>Verified contracts</h2></div><a href="https://sourcify.dev" target="_blank" rel="noreferrer">Exact-match source<ExternalLink size={12} /></a></div><div className="address-table">{addresses.map((item) => <div className="address-row" key={item.label}><span className={`address-mark ${item.tone}`}><Network size={14} /></span><div><strong>{item.label}</strong><small>{compactAddress(item.value, 12)}</small></div><span className="chain-tag">84532</span><CopyButton value={item.value} label={item.label} /><a href={explorerUrl("address", item.value)} target="_blank" rel="noreferrer" aria-label={`Open ${item.label} on explorer`}><ArrowUpRight size={14} /></a></div>)}</div></article>
            <article className="panel lifecycle-panel" id="userops"><div className="panel-heading compact"><div><span className="panel-kicker">ONCHAIN PROOF</span><h2>Verified lifecycle</h2></div><span className="proof-count">4 / 4</span></div><ol>{lifecycle.map((step, index) => <li key={step.label}><span className="step-index">0{index + 1}</span><div><strong>{step.label}</strong><small>{step.meta}</small></div><BadgeCheck size={16} /></li>)}</ol></article>
          </div>

          <div className="tertiary-grid">
            <article className="panel activity-panel" id="audit"><div className="panel-heading compact"><div><span className="panel-kicker">IMMUTABLE ACTIVITY</span><h2>Recent operations</h2></div><button type="button" className="text-button">View all <ArrowUpRight size={13} /></button></div><div className="activity-table"><div className="activity-head"><span>OPERATION</span><span>DETAIL</span><span>STATUS</span><span>TIME</span><span>TRANSACTION</span></div>{activity.map((item) => <div className="activity-row" key={item.hash}><span><span className="activity-icon"><Activity size={14} /></span>{item.type}</span><span>{item.detail}</span><span className="included"><Check size={11} />{item.state}</span><span className="muted">{item.time}</span><a href={explorerUrl("tx", item.hash)} target="_blank" rel="noreferrer">{compactAddress(item.hash, 6)}<ExternalLink size={11} /></a></div>)}</div></article>
            <article className="panel recovery-panel" id="recovery"><div className="panel-heading compact"><div><span className="panel-kicker">BREAK-GLASS PATH</span><h2>Guardian recovery</h2></div><LockKeyhole size={18} /></div><div className="recovery-visual"><div className="recovery-node guardian"><ShieldEllipsis size={17} /><span>Guardian</span></div><div className="recovery-line"><span>48H</span></div><div className="recovery-node owner"><UserRoundCheck size={17} /><span>New owner</span></div></div><p>Pause immediately, nominate a new owner, wait two days, then rotate the session epoch.</p><div className="recovery-facts"><span><Pause size={13} />Asset calls blocked</span><span><TimerReset size={13} />Timelock enforced</span><span><KeyRound size={13} />Sessions invalidated</span></div></article>
          </div>
        </section>
      </main>
    </div>
  );
}
