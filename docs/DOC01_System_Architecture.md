# DOC01 — System Architecture
## Software Architecture for the SMC Expert Advisor (XAUUSD, MetaTrader 5)

> **Document status:** AUTHORITATIVE — Official architecture specification for the project.
> **Phase:** Architecture Design (Phase 1). No code, no pseudo-code, no indicators, no trading-rule changes.
> **Relationship to prior documents:**
> - Implements the approved methodology in **DOC00_Strategy_Validation.md**.
> - Conforms to the timeframe architecture in **DOC00_PATCH_001.md** (H4 → H1 → M15).
> - Does **not** modify, contradict, or redefine any DOC00 rule, constant, definition, or terminology.
> **Priority rule:** If any future implementation detail conflicts with DOC00 or PATCH_001, those documents prevail. This document governs only *how* the EA is structured, not *what* it decides.

---

# Reported Inconsistencies (reported, not changed)

Per the standing instruction to *report* inconsistencies rather than silently change them, the following are flagged for the project owner. The architecture is designed to accommodate either resolution without rework.

| # | Inconsistency | Source A | Source B | How this document handles it |
|---|---|---|---|---|
| I-1 | **News Filter Module** is required by the DOC01 brief, but DOC00 *Limitations §10* explicitly states "No news/economic-event handling. The methodology is purely price-action." | DOC01 brief (module list) | DOC00 *Limitations §10* | The **News Filter Module** is included as specified, but implemented as a **switchable, default-OFF** module. With the switch off, it is a pure pass-through and the EA behaves exactly as DOC00 describes. The owner decides whether to enable it; enabling it is the only point where DOC00's "no news handling" stance would be revisited, and that decision belongs to the owner. |
| I-2 | DOC00 describes a **"two-timeframe model"** in places; PATCH_001 supersedes this with a three-timeframe model. | DOC00 (pre-patch wording) | PATCH_001 | PATCH_001 prevails. This architecture uses **H4 (bias) → H1 (structure) → M15 (execution)** throughout. |
| I-3 | DOC00 *Automation Challenges §10* leaves the kill-switch check cadence open ("every tick or every closed bar"). | DOC00 | — | This document fixes it to a **deterministic cadence** (see Trade Management / Risk sections): the equity ratio is evaluated **on every tick** (cheap) AND re-confirmed on every **closed M15 bar**. This removes the ambiguity for implementation without changing DOC00's intent. |

No DOC00 or PATCH_001 content was altered to resolve these. Owner decisions are requested only for I-1.

---

# Design Principles (applied)

| Principle | Where applied |
|---|---|
| Single Responsibility (SRP) | Each engine owns exactly one SMC concern (structure, liquidity, OB, FVG, etc.) |
| Separation of Concerns | Detection, decision, action, and infrastructure are in separate layers |
| Low Coupling | Modules communicate through a shared read-only **Structural Context** + narrow command interfaces; no engine calls another engine directly |
| High Cohesion | All logic for one concept lives in one engine |
| Modular Design | Each module is independently replaceable/testable |
| Event-driven | The EA reacts to two event classes only: **new closed bar** (per timeframe) and **tick** (management only) |
| Deterministic State Machine | A single FSM gates every action; forbidden transitions are physically impossible to reach |
| Defensive Programming | All inputs validated; all broker calls wrapped; no silent failures |

---

# Architectural Overview

The EA is organised in **layers**. Data flows strictly **downward** through the layers per closed bar; control flows through a single orchestrator (Core Engine) driven by the State Machine. Cross-layer communication uses a **shared read-only Structural Context** (the "blackboard" pattern) so that no detection engine ever depends on another detection engine.

```
Layer 6  Orchestration        : Core Engine, State Machine
Layer 5  Action               : Trade Execution Engine, Trade Management Engine
Layer 4  Decision             : Entry Confirmation Engine
Layer 3  Gates / Filters      : Session Engine, News Filter, Spread & Slippage Filter, Risk Management Engine
Layer 2  Detection            : Market Structure Engine, Liquidity Engine, Order Block Engine, Fair Value Gap Engine
Layer 1  Shared Read Model    : Structural Context (immutable per bar)  +  Market Data Access
Layer 0  Infrastructure       : Configuration Manager, Logger, Error Handling Module, Utility Module
```

**Dependency rule:** a module may only depend on modules in the **same layer or a lower layer**. No upward dependencies. This structurally forbids circular dependencies.

**Communication contract:**
- **Detection engines (Layer 2)** are the *only* writers to their own section of the Structural Context.
- **All other modules** are *readers* of the Structural Context.
- No engine reads **and** writes another engine's section. This is the primary circular-dependency and duplicated-calculation safeguard.

---

# Complete Module Structure

Each module is specified below with: Purpose, Responsibilities, Inputs, Outputs, Dependencies, Communicates with, and **Must never directly modify**.

---

## 0. Configuration Manager (Layer 0)

- **Purpose:** Single source of runtime configuration and the locked DOC00 constants.
- **Responsibilities:**
  - Load all input parameters at EA start.
  - Validate every parameter against DOC00/DOC01 constraints (range, type, symbol compatibility).
  - Expose locked constants (lot size, RR, max positions, kill threshold, SMC constants) as read-only values.
  - Persist operational state that must survive restart (HALTED flag, Initial Balance, magic number binding) via the Persistence facility (see Utility Module).
- **Inputs:** EA input parameters; persistence store.
- **Outputs:** A validated, immutable `Config` object consumed by all modules.
- **Dependencies:** Logger, Error Handling, Utility (persistence).
- **Communicates with:** All modules (they read `Config`).
- **Must never directly modify:** Any market data, any Structural Context section, any trade.

## 0. Logger (Layer 0)

- **Purpose:** The single, structured output channel for the entire EA.
- **Responsibilities:** Accept structured log records (level, category, module, timestamp, message, context fields); write to log sinks; enforce log level; never throw.
- **Inputs:** Log records from every module.
- **Outputs:** Log lines (file + terminal + Experts journal as configured).
- **Dependencies:** Utility (time formatting), Configuration Manager (level/path).
- **Communicates with:** All modules (they emit records); not called by market logic.
- **Must never directly modify:** Any state outside the log sinks.
- **Rule:** Every other module depends on Logger; Logger depends on nobody except Utility and Config.

## 0. Error Handling Module (Layer 0)

- **Purpose:** Centralised, categorised error classification and recovery policy lookup.
- **Responsibilities:** Classify errors (trade, broker rejection, invalid data, missing candle, unexpected state, configuration); map each category to a recovery action; never swallow errors silently — unclassified errors escalate to the State Machine.
- **Inputs:** Raw error codes/exceptions from modules and broker calls.
- **Outputs:** A normalised `ErrorDecision` (Retry / Skip / Halt / Escalate) plus a log record.
- **Dependencies:** Logger, Configuration Manager.
- **Communicates with:** Core Engine (escalation), Trade Execution/Management (recovery decisions).
- **Must never directly modify:** Market data, Structural Context, trades (it decides; it does not act).

## 0. Utility Module (Layer 0)

- **Purpose:** Pure, side-effect-free helpers shared across modules.
- **Responsibilities:** Time conversion (broker server time ↔ UTC via BrokerUTCOffset), point/price precision helpers, persistence (save/load state file), bar-index helpers, equality/tolerance math (used by ELT comparisons), guards (closed-bar checks).
- **Inputs:** Primitive values.
- **Outputs:** Primitive values / serialised state.
- **Dependencies:** None (lowest layer) except Configuration Manager for BrokerUTCOffset.
- **Communicates with:** All modules.
- **Must never directly modify:** Market data, Structural Context, trades.

---

## 1. Market Data Access (Layer 1)

- **Purpose:** The only module permitted to read MT5 price/series data. Centralises `CopyRates`/`iClose` access and enforces **closed-bar discipline**.
- **Responsibilities:**
  - Provide closed-bar OHLC for H4, H1, M15 on demand.
  - Guarantee that any bar returned for index 0..n is **closed** (never the forming bar) unless explicitly requested for management tick data (bid/ask only).
  - Detect and report missing/gapped history.
  - Cache the latest bar per timeframe to avoid repeated `CopyRates` calls.
- **Inputs:** Symbol, timeframes, requested depth.
- **Outputs:** Closed-bar series; "new bar" event flags per timeframe.
- **Dependencies:** Utility, Logger, Error Handling.
- **Communicates with:** All Layer 2 engines and Layer 5 management.
- **Must never directly modify:** Structural Context (it provides raw data; engines write context), trades.
- **Why centralised:** A single chokepoint for closed-bar discipline is the strongest defence against repaint/look-ahead (DOC00 *Automation Challenges §1–2*).

## 1. Structural Context (Layer 1 — shared read model)

- **Purpose:** The shared, per-bar, read-only "picture" of the market that detection engines produce and consumers read. Eliminates duplicated calculations and redundant scanning.
- **Responsibilities:** Hold the current results of every detection engine for the current bar: H4 bias, H1 swing list, current structure state (bias/BOS/CHoCH log), active liquidity levels (BSL/SSL), EQH/EQL, sweeps, OB list (with mitigation/invalidation flags), Breaker list, FVG list, current Dealing Range and Premium/Discount equilibrium, and the latest M15 structural events used for entry.
- **Inputs:** Writes from Layer 2 engines only.
- **Outputs:** Read access for Layers 3–5.
- **Dependencies:** Utility (data structures).
- **Communicates with:** Written by detection engines; read by gates, decision, action layers.
- **Must never directly modify:** It is data, not logic. Only its owning engine may write its section.
- **Immutability rule:** Within one bar cycle the context is **frozen** once all engines have run; the action/decision layers read a frozen snapshot. This guarantees a single consistent view per bar.

---

## 2. Market Structure Engine (Layer 2)

- **Purpose:** Detect and maintain the H1 market structure (swings, HH/HL/LH/LL, BOS, CHoCH) and the H4 directional bias. This is the structural backbone; all other engines consume its output.
- **Responsibilities:**
  - Compute **H4 bias** (Primary Trend Timeframe): bullish/bearish/undefined only. No BOS/CHoCH/OB/FVG on H4 (PATCH_001).
  - Compute **H1 swings** with SFS = 2, strict inequality, closed-bar confirmation (DOC00 Swing rules).
  - Maintain the structure state machine (HH/HL → bullish; LH/LL → bearish; flips only on a CHoCH body close).
  - Detect **BOS** and **CHoCH** on H1 using **body-close** confirmation only.
  - Maintain the current **Dealing Range** (the bounding swings of the active leg) and the **Premium/Discount equilibrium** (midpoint).
- **Inputs:** Closed H4 and H1 bars from Market Data Access; previous structure state.
- **Outputs:** Writes the *Structure* section of the Structural Context (bias, swings, structure events, dealing range, equilibrium).
- **Dependencies:** Market Data Access, Utility, Logger, Error Handling.
- **Communicates with:** Produces input for Liquidity, Order Block, FVG, Entry Confirmation, Trade Management (trailing).
- **Must never directly modify:** Any section other than *Structure*; trades; configuration.

## 2. Liquidity Engine (Layer 2)

- **Purpose:** Maintain active liquidity levels (BSL/SSL), Equal Highs/Lows, and liquidity sweeps on H1.
- **Responsibilities:**
  - Derive BSL (above confirmed swing highs / EQH) and SSL (below confirmed swing lows / EQL).
  - Detect EQH/EQL using ELT = 20 points.
  - Detect **liquidity sweeps** (wick beyond a level by > ELT with close back inside), confirm on closed bar, retire the swept level.
  - Keep only the nearest active BSL above and nearest active SSL below as the working targets.
- **Inputs:** H1 closed bars; the *Structure* section of the context (swings).
- **Outputs:** Writes the *Liquidity* section (active BSL/SSL, EQH/EQL pools, sweep events).
- **Dependencies:** Market Data Access (read), Structural Context *Structure* (read), Utility, Logger.
- **Communicates with:** Feeds Entry Confirmation (sweep confluence).
- **Must never directly modify:** *Structure* section, trades, configuration. (It reads structure; it does not write it.)

## 2. Order Block Engine (Layer 2)

- **Purpose:** Detect, qualify, and lifecycle-manage Order Blocks and Breaker Blocks on H1.
- **Responsibilities:**
  - On each confirmed H1 BOS/CHoCH (from *Structure*), identify the **last opposite-body candle** before the impulse → record the OB zone (high–low), tagged bullish/bearish with the confirming-event timestamp.
  - Mark OBs **immutable** after the confirming close (never edited later — DOC00 *Automation Challenges §7*).
  - Track **mitigation** (body enters zone) and **invalidation** (body closes beyond far edge).
  - On invalidation, flag the zone as a Breaker candidate; promote to a **Breaker** on a subsequent opposite BOS/CHoCH (fallback priority only).
- **Inputs:** H1 closed bars; *Structure* section (BOS/CHoCH events, dealing range).
- **Outputs:** Writes the *OrderBlocks* section (OB list, Breaker list, mitigation/invalidation flags).
- **Dependencies:** Market Data Access (read), Structural Context *Structure* (read), Utility, Logger.
- **Communicates with:** Feeds Entry Confirmation (zone selection), Risk (stop distance from OB far edge).
- **Must never directly modify:** *Structure* section, trades, configuration.

## 2. Fair Value Gap Engine (Layer 2)

- **Purpose:** Detect and lifecycle-manage Fair Value Gaps on H1.
- **Responsibilities:**
  - Detect 3-candle FVGs on closed H1 bars (bullish: low3 > high1; bearish: high3 < low1).
  - Record only FVGs with gap ≥ FVG Min Size (10 points); merge overlapping FVGs into one zone (outer bounds).
  - Mark FVGs **filled** when a later closed candle's body fully trades through the gap.
- **Inputs:** H1 closed bars.
- **Outputs:** Writes the *FVG* section (FVG list with fill flags).
- **Dependencies:** Market Data Access (read), Utility, Logger.
- **Communicates with:** Feeds Entry Confirmation (FVG-in-OB overlap test).
- **Must never directly modify:** *Structure*, *OrderBlocks* sections, trades, configuration.

---

## 3. Session Engine (Layer 3 — gate)

- **Purpose:** Decide whether the current time is inside an active trading session.
- **Responsibilities:**
  - Convert broker server time to UTC via BrokerUTCOffset (Utility).
  - Return an **active/inactive** flag plus the current session name for the *current closed bar's time*.
  - Active windows: London 07:00–10:00 UTC, NY AM 12:00–15:00 UTC (DOC00 constants).
- **Inputs:** Current bar close time; BrokerUTCOffset.
- **Outputs:** Session status (read by Entry Confirmation gate).
- **Dependencies:** Utility, Configuration Manager.
- **Communicates with:** Entry Confirmation Engine (provides the session gate).
- **Must never directly modify:** Structural Context, trades.

## 3. News Filter Module (Layer 3 — gate, switchable, default OFF)

> See **Reported Inconsistency I-1**. This module is included per the DOC01 brief but is **default OFF** to remain consistent with DOC00 *Limitations §10* until the owner decides otherwise.
- **Purpose:** Optionally suppress new entries around scheduled high-impact news.
- **Responsibilities (only when enabled):**
  - Maintain a configurable news-blackout window (minutes before/after an event).
  - Return a **blocked/clear** flag for entry.
  - When **disabled** (default), always returns **clear** (pure pass-through; zero effect on behaviour, fully consistent with DOC00).
- **Inputs:** News calendar source (owner-provided; out of scope to specify the feed here), current UTC time, enable flag.
- **Outputs:** News status flag.
- **Dependencies:** Utility, Configuration Manager.
- **Communicates with:** Entry Confirmation Engine.
- **Must never directly modify:** Structural Context, trades, configuration.
- **Owner decision required:** whether to enable and which feed to use. Until decided, OFF.

## 3. Spread & Slippage Filter (Layer 3 — gate)

- **Purpose:** Reject entries when current spread or expected slippage exceeds safe bounds, and cap execution slippage.
- **Responsibilities:**
  - Read current spread; compare to a configurable MaxSpreadPoints.
  - Provide a MaxSlippagePoints cap used by Trade Execution.
  - Return a **clear/blocked** flag for entry (spread side).
- **Inputs:** Current bid/ask/spread (Market Data Access tick data), configured caps.
- **Outputs:** Spread/slippage status; slippage cap value for execution.
- **Dependencies:** Market Data Access (tick), Configuration Manager.
- **Communicates with:** Entry Confirmation (spread gate), Trade Execution (slippage cap).
- **Must never directly modify:** Structural Context, trades (it gates; execution acts).

## 3. Risk Management Engine (Layer 3 — gate)

- **Purpose:** Enforce all DOC00 risk rules and the equity kill switch.
- **Responsibilities:**
  - Enforce **max 1 open position** (check before and after any order send).
  - Enforce **fixed lot 0.01** (no dynamic sizing ever).
  - Enforce **1:2 RR** (TP = entry ± 2 × risk).
  - Compute the OB-based **stop distance**; if it exceeds **MaxRiskPerTradePoints (1500)**, the trade is **skipped** (never resized).
  - Maintain **Initial Balance** and the persisted **HALTED** flag; evaluate the **50% equity kill switch** on a deterministic cadence (every tick + re-confirmed on every closed M15 bar). When tripped, set HALTED = true (persisted); clear only via manual reset (which re-sets Initial Balance).
- **Inputs:** Account equity/balance, open position count, OB far-edge price (from context), entry price.
- **Outputs:** Risk decision (Allow / Skip / HALT); HALTED flag; computed SL/TP levels.
- **Dependencies:** Configuration Manager, Utility (persistence), Logger, Structural Context (read OB).
- **Communicates with:** Entry Confirmation (HALTED gate), Trade Execution (SL/TP/lot), Core Engine (HALT escalation → State Machine).
- **Must never directly modify:** Trades directly (it computes; execution acts), Structural Context.

---

## 4. Entry Confirmation Engine (Layer 4 — decision)

- **Purpose:** Evaluate the DOC00 entry rule as a strict boolean AND of the six conditions, once per **closed M15 bar**.
- **Responsibilities:**
  - Combine, into a single deterministic decision, the following inputs (all read-only):
    1. H4 bias (from *Structure*) is bullish (long) / bearish (short).
    2. A valid, unmitigated OB (or Breaker fallback) exists in the correct Premium/Discount half (from *OrderBlocks* + *Structure* equilibrium).
    3. A qualifying FVG overlaps the OB zone OR the latest liquidity event was an SSL sweep in Discount (BSL sweep in Premium for shorts) — from *FVG* + *Liquidity*.
    4. M15 has produced a **CHoCH in the trade direction** after reaching the OB zone (from Market Data Access M15 structure read).
    5. The session gate (Session Engine) is **active**.
    6. No position is open AND the kill switch is **not** HALTED (Risk Engine) AND spread filter is clear AND (news filter, if enabled) is clear.
  - Return a strict `ENTER_LONG / ENTER_SHORT / NO_ENTRY` decision. No partial scoring, no "almost."
- **Inputs:** Structural Context (read), Session/Spread/News/Risk gate outputs, M15 closed bars.
- **Outputs:** Entry decision + the selected OB zone + intended SL/TP (delegated to Risk for final SL/TP) passed to Trade Execution.
- **Dependencies:** Market Data Access (M15), all gates, Structural Context (read), Risk (for final SL/TP and HALTED check).
- **Communicates with:** Trade Execution Engine (issues the single entry command).
- **Must never directly modify:** Structural Context (it reads), trades (it decides; execution acts).

---

## 5. Trade Execution Engine (Layer 5 — action)

- **Purpose:** Translate a single entry decision into broker orders, safely and idempotently.
- **Responsibilities:**
  - Send the market order with **lot 0.01**, the Risk-computed **SL** (OB far edge ∓ SL Buffer) and **TP** (entry ± 2 × risk), magic number, and the Spread & Slippage Filter's slippage cap.
  - Verify **exactly one position** results (re-check count before and after send; abort/detect duplicates).
  - Wrap all broker calls through Error Handling; apply its recovery decisions.
  - Confirm fill price, actual SL/TP set on broker, and record the realised entry for Trade Management.
- **Inputs:** Entry decision + zone + SL/TP from Entry Confirmation/Risk; slippage cap; Config.
- **Outputs:** A filled position record (entry price, SL, TP, ticket, open time) handed to Trade Management; or a failure handed to Error Handling.
- **Dependencies:** Risk (final SL/TP + position-count guard), Spread & Slippage Filter, Error Handling, Logger, Config.
- **Communicates with:** Trade Management (hands off the position), Risk (position-count updates), State Machine (state transitions).
- **Must never directly modify:** Structural Context, configuration, the kill switch (it can only act on Risk's authority).

## 5. Trade Management Engine (Layer 5 — action)

- **Purpose:** Manage the open position through break-even, trailing, and exit, using only **confirmed** structural levels.
- **Responsibilities:**
  - **Break even:** once favourable excursion ≥ 1R, move SL to entry ± Break-Even Buffer (5 pts), exactly once per trade.
  - **Trailing (structural):** after BE, on each newly **confirmed H1 swing** in the trade direction, move SL to that swing ∓ SL Buffer, only if it improves the current stop.
  - React on **tick** for BE/trail triggers, but read only confirmed H1 swings from *Structure* (never forming bars).
  - Detect natural exit (SL/TP hit) and report trade closure.
  - Never widen the stop; never move against the trade.
- **Inputs:** Open position state; *Structure* (confirmed H1 swings for trailing); 1R distance (entry − original SL).
- **Outputs:** Order-modify requests (SL updates); closure reports.
- **Dependencies:** Market Data Access (tick for triggers + closed H1 bars), Structural Context *Structure* (read), Error Handling, Logger, Config.
- **Communicates with:** Trade Execution (only one of the two is ever active per position), State Machine (IN_TRADE ↔ IDLE on closure).
- **Must never directly modify:** Structural Context, configuration, the entry decision.

---

## 6. Core Engine (Layer 6 — orchestration)

- **Purpose:** The single orchestrator. Wires modules, owns the main loop, and routes events to the State Machine.
- **Responsibilities:**
  - On **OnInit**: load Config, initialise all modules, load persisted state (HALTED, Initial Balance), validate symbol/timeframe availability, transition to IDLE (or HALTED if persisted).
  - On **OnTick**: run tick-scoped work only — Risk kill-switch check, and (if IN_TRADE) Trade Management. Cheap and deterministic.
  - On **new closed bar** (per timeframe, via Market Data Access event flags): run the bar-scoped pipeline (see Data Flow) — H4 bias → H1 structure/liquidity/OB/FVG → freeze Structural Context → gates → entry decision → (if IDLE and decision) execution.
  - On **OnDeinit**: flush logs, persist state.
  - Enforce that no work runs out of order; the State Machine is the final authority on whether each step is permitted.
- **Inputs:** MT5 events (init/tick/deinit); new-bar flags.
- **Outputs:** Sequenced calls into Layer 2–5 modules.
- **Dependencies:** All modules (it wires them); State Machine (it asks permission).
- **Communicates with:** State Machine (every state-changing action), all engines.
- **Must never directly modify:** Structural Context (engines do), trades (execution/management do), configuration. It only sequences.

## 6. State Machine (Layer 6 — control)

- **Purpose:** The deterministic authority that gates every state-changing action so the EA can **never** open duplicate trades, skip validation, enter without confirmation, or run conflicting logic.
- **Responsibilities:** Hold the current state; accept transition requests only from authorised callers (Core Engine); reject forbidden transitions; expose "is action X permitted in current state?" queries.
- **Inputs:** Transition requests + event context.
- **Outputs:** Current state; permission decisions.
- **Dependencies:** Logger only (it must remain dependency-light and trusted).
- **Communicates with:** Core Engine (permission queries), Risk (HALT escalation).
- **Must never directly modify:** Anything except its own state variable. It is a pure authority.

---

# State Machine

The EA has one deterministic finite state machine. Exactly one state is active at any time. State is persisted across restarts where indicated.

### States

#### S1. INITIALIZATION
- **Purpose:** Safe startup; load and validate everything before any market action.
- **Entry conditions:** EA start (OnInit) or post-manual-reset reload.
- **Exit conditions:** Config valid, history available, persistence loaded, symbol/timeframes confirmed.
- **Allowed transitions:** → IDLE (normal), → HALTED (if persisted HALTED = true), → TERMINATION (fatal config/data error).
- **Forbidden transitions:** → any execution state; cannot enter IN_TRADE directly.
- **Failure conditions:** Invalid config, missing M1/H1/H4 history, persistence corruption.
- **Recovery method:** Error Handling escalates; EA remains in INITIALIZATION and logs; owner fixes inputs and reloads.

#### S2. IDLE
- **Purpose:** No open position; scanning for a valid entry on closed bars.
- **Entry conditions:** From INITIALIZATION (normal start), from IN_TRADE (on position closure), from ARMED (signal invalidated before fill), from ERROR_RECOVERY (recovered).
- **Exit conditions:** Entry Confirmation returns ENTER_LONG/SHORT AND all gates clear AND Risk allows AND not HALTED.
- **Allowed transitions:** → ARMED (entry confirmed, preparing order), → HALTED (kill switch), → ERROR_RECOVERY (transient error), → TERMINATION.
- **Forbidden transitions:** → IN_TRADE (must pass through ARMED and Execution), → INITIALIZATION.
- **Failure conditions:** Broker/temporary data error during analysis.
- **Recovery method:** Skip the current signal; remain IDLE; log.

#### S3. ARMED
- **Purpose:** A confirmed entry decision exists; the order is being submitted and confirmed. Guards against duplicate entries.
- **Entry conditions:** From IDLE, after Entry Confirmation decision + Risk approval.
- **Exit conditions:** Order filled and exactly one position confirmed → IN_TRADE; or order failed/rejected/no-fill → back to IDLE.
- **Allowed transitions:** → IN_TRADE (fill confirmed), → IDLE (no fill / rejection), → HALTED, → ERROR_RECOVERY.
- **Forbidden transitions:** → ARMED (no re-arming while armed), → INITIALIZATION, cannot open a second order.
- **Failure conditions:** Broker rejection, timeout, duplicate-position detected post-send.
- **Recovery method:** Error Handling decides Retry (bounded) or abort to IDLE; duplicate → force-close extras (owner-noted) and abort.

#### S4. IN_TRADE
- **Purpose:** A single position is open; management (BE/trail) is active.
- **Entry conditions:** From ARMED after confirmed single fill.
- **Exit conditions:** Position closed (SL/TP/manual) → IDLE.
- **Allowed transitions:** → IDLE (closed), → ERROR_RECOVERY (management error), → HALTED (kill switch; management of the open trade **continues** — only **new** entries are blocked, per DOC00).
- **Forbidden transitions:** → ARMED (no second entry while in trade), → INITIALIZATION, cannot open another position.
- **Failure conditions:** Order-modify failure (BE/trail), broker disconnect.
- **Recovery method:** Retry modify per Error Handling; position remains; if unrecoverable, log and continue attempting on next tick/bar.

#### S5. HALTED
- **Purpose:** Kill switch tripped (equity ≤ 50% of Initial Balance). **Terminal until manual reset.** No new entries, ever, even if equity recovers.
- **Entry conditions:** Risk reports HALTED = true from any state.
- **Exit conditions:** **Manual reset only** (sets HALTED = false, re-records Initial Balance) → INITIALIZATION → IDLE.
- **Allowed transitions:** → INITIALIZATION (manual reset only).
- **Forbidden transitions:** → IDLE/ARMED/IN_TRADE automatically (never auto-resumes).
- **Failure conditions:** Persistence failure (HALTED flag lost) — mitigated by redundant persistence + sanity check on startup.
- **Recovery method:** Human-in-the-loop only. If an open trade exists when HALTED, Trade Management **continues** to manage it (DOC00 Edge Case E12); only new entries are blocked.
- **Persistence:** HALTED flag and Initial Balance are persisted so a restart cannot bypass the kill switch (DOC00 *Automation Challenges §6*, Edge Case E13).

#### S6. ERROR_RECOVERY
- **Purpose:** A transient, recoverable error occurred; attempt bounded recovery without corrupting state.
- **Entry conditions:** A recoverable error from IDLE/ARMED/IN_TRADE.
- **Exit conditions:** Recovery succeeds → return to the **previous** state (IDLE or IN_TRADE); recovery fails → HALTED or TERMINATION.
- **Allowed transitions:** → previous state, → HALTED, → TERMINATION.
- **Forbidden transitions:** → ARMED (cannot enter a trade from recovery), → INITIALIZATION.
- **Failure conditions:** Recovery attempts exhausted.
- **Recovery method:** Bounded retries with backoff; if a trade is open, it is preserved and re-validated on return.

#### S7. TERMINATION
- **Purpose:** Clean or fatal shutdown.
- **Entry conditions:** OnDeinit, or fatal unrecoverable error.
- **Exit conditions:** None (terminal for this run).
- **Allowed transitions:** None (next run starts fresh at INITIALIZATION).
- **Forbidden transitions:** All.
- **Failure conditions:** N/A.
- **Recovery method:** Reloading the EA.

### State Machine Guarantees (how it enforces "never")

| Required guarantee | Enforcement mechanism |
|---|---|
| Never open duplicate trades | IN_TRADE forbids → ARMED; Risk checks position count pre- and post-send; ARMED forbids re-arming. |
| Never skip validation steps | Entry requires the strict AND from Entry Confirmation; the FSM will not accept an → ARMED transition without the decision object and Risk approval. |
| Never enter without confirmation | The only path to IN_TRADE is IDLE → ARMED (decision+approval) → Execution fill. No direct IDLE→IN_TRADE. |
| Never execute conflicting logic | One active state at a time; management and entry are mutually exclusive (entry only in IDLE/ARMED, management only in IN_TRADE); Structural Context is frozen per bar. |

---

# Data Flow

Two flows: a **bar-scoped analysis pipeline** (runs on new closed bars) and a **tick-scoped management pipeline** (runs on ticks). Both are deterministic.

### Bar-scoped pipeline (on each new closed bar, per the relevant timeframe)

```
1. Market Data Access
        │  provides closed H4 / H1 / M15 bars + new-bar flags
        ▼
2. Market Structure Engine
        │  H4 bias  +  H1 swings / structure state / BOS / CHoCH / dealing range / equilibrium
        │  writes Structural Context → Structure
        ▼
3. Liquidity Engine
        │  reads Structure  →  BSL/SSL, EQH/EQL, sweeps
        │  writes Structural Context → Liquidity
        ▼
4. Order Block Engine
        │  reads Structure (BOS/CHoCH)  →  OB zones, mitigation/invalidation, Breakers
        │  writes Structural Context → OrderBlocks
        ▼
5. Fair Value Gap Engine
        │  reads H1 bars  →  FVG zones, fills
        │  writes Structural Context → FVG
        ▼
6. FREEZE Structural Context   (immutable snapshot for this bar)
        ▼
7. Gates (Layer 3)
        │  Session Engine  ·  News Filter (if enabled)  ·  Spread & Slippage Filter  ·  Risk Management (HALTED + position count)
        ▼
8. Entry Confirmation Engine
        │  strict AND of six conditions  →  ENTER_LONG / ENTER_SHORT / NO_ENTRY
        ▼
9. Risk Management Engine (final)
        │  compute SL/TP (OB far edge ∓ SL Buffer; TP = entry ± 2R); skip if distance > MaxRiskPerTradePoints
        ▼
10. (if decision and state IDLE) → State Machine: IDLE → ARMED
        ▼
11. Trade Execution Engine
        │  send order (0.01, SL, TP, slippage cap); verify single fill
        ▼
12. State Machine: ARMED → IN_TRADE  (or → IDLE on no-fill)
        ▼
13. Logger   (every step emits a structured record)
```

**Step-by-step rationale:**
1. Centralised, closed-bar-locked data access prevents repaint/look-ahead.
2. Structure runs first because every other engine consumes swings/BOS/CHoCH.
3–5. Each engine reads only what it needs and writes only its own section — no duplicated scans, no cross-writes.
6. Freezing the context guarantees the decision layer sees one consistent picture, not a moving target.
7. Gates are independent and composable; any one can block.
8. A single strict-AND decision removes discretion.
9. Risk is the final authority on SL/TP and on whether the trade's risk is acceptable.
10–12. The State Machine serialises the transition so duplicates and conflicting actions are impossible.
13. Logging is continuous and reconstructable.

### Tick-scoped pipeline (on every tick)

```
A. Market Data Access      → current bid/ask/spread (tick data only; no bar re-analysis)
B. Risk Management Engine  → equity kill-switch check (deterministic cadence: every tick)
C. if IN_TRADE:
      Trade Management Engine → BE at +1R (once), structural trailing on confirmed H1 swings
D. Logger                  → management/SL-modify records
```

Tick work is intentionally minimal: only the kill switch and (when in trade) management. All heavy analysis is bar-scoped.

---

# Module Communication

### Communication mechanism
- **Shared read-only Structural Context** for analytical data (Layer 2 → Layers 3–5). This is the primary channel.
- **Narrow command/value interfaces** for actions: Entry Confirmation → Trade Execution (one decision object); Risk → Execution (SL/TP/lot); Spread Filter → Execution (slippage cap).
- **State Machine permission queries** from Core Engine before any state-changing action.
- **Logger** as the universal observation sink.

### Rules that prevent coupling pathologies
- **No circular dependencies:** the layer dependency rule (depend only same/lower layer) plus the "engines never call engines" rule make cycles structurally impossible.
- **No duplicated calculations:** each concept is computed by exactly one engine and read by all consumers from the Structural Context. Example: swings are computed once by Market Structure and read by Liquidity, OB, and Management — never recomputed.
- **No redundant market scanning:** Market Data Access is the single reader of MT5 series; it caches the latest bar per timeframe and emits new-bar flags, so engines never call `CopyRates` themselves.
- **No redundant history scanning:** engines process **incrementally** — only the newest closed bar mutates state (see Performance). Full rescans are limited to initialisation.
- **Write ownership table** (who may write each context section):

| Context section | Sole writer | Readers |
|---|---|---|
| Structure (bias, swings, BOS/CHoCH, range, equilibrium) | Market Structure Engine | Liquidity, OB, Entry, Management |
| Liquidity (BSL/SSL, EQH/EQL, sweeps) | Liquidity Engine | Entry |
| OrderBlocks (OB, Breakers, flags) | Order Block Engine | Entry, Risk |
| FVG | Fair Value Gap Engine | Entry |

---

# Performance

Recommendations to minimise CPU, memory, recalculation, and redundant scanning — all while preserving determinism.

1. **Incremental, event-driven processing.** On a new closed bar, each engine processes only the **newest closed bar** against existing state (e.g., one new candidate swing, one new BOS check). Full historical scans happen **only at initialisation** within a bounded lookback.
2. **Throttle OnTick.** Tick handler runs only the cheap kill-switch check and (in trade) management. All structural analysis is deferred to new-bar events. This bounds CPU in fast markets.
3. **Single market-data chokepoint with caching.** Market Data Access caches the last bar per timeframe and only re-reads when a new bar is detected. No engine calls series functions directly.
4. **Bounded, pruned collections.** Swing, OB, Breaker, and FVG lists are pruned to a bounded lookback (e.g., keep only N most recent unmitigated/active zones). Retired/mitigated/invalidated/filled objects are archived to a bounded log and dropped from active memory.
5. **Frozen snapshot per bar.** Freezing the Structural Context once per bar means decision/action layers read pointers, not recomputed values.
6. **Avoid per-tick object allocation.** Reuse buffers for bar data and context nodes; avoid creating arrays on every tick.
7. **Lookback depth limits.** Initialisation scans a fixed, documented depth (enough to establish at least two confirmed H1 swings and the H4 bias). Depth is a constant, not unbounded.
8. **Persistence over recomputation.** HALTED flag, Initial Balance, and (optionally) the active structural snapshot are persisted so a restart does not force a deep rescan.
9. **Cheap kill-switch cadence.** The equity check is a single comparison; running it per tick is negligible.
10. **No indicators.** The methodology is pure price-action; no indicator buffers are maintained, eliminating indicator recalculation cost entirely (DOC00 has no indicator-based rules).

---

# Error Handling

A categorised strategy. Every broker/series call is wrapped; no error is swallowed; unclassified errors escalate to the State Machine.

| Category | Examples | Detection | Recovery strategy |
|---|---|---|---|
| **Trade errors** | Order send/modify fails, timeout, requote | Broker return codes | Bounded retry with backoff (configurable count); on exhaustion, abort to IDLE/IN_TRADE and log; never silently retry indefinitely. |
| **Broker rejection** | Invalid stops, insufficient margin, disabled trading | Broker return codes | Do not retry the same parameters; log and skip the signal; remain in valid state. |
| **Invalid market data** | Zero-volume bar, obviously wrong price, wrong symbol state | Sanity checks in Market Data Access | Skip the bar; do not mutate state; log; resume next bar. |
| **Missing candle / history gap** | H1/H4 bar absent, unsynchronised history | Gap detection vs expected bar sequence | Pause analysis for affected timeframe until history is continuous; log; do not fabricate bars. |
| **Unexpected state** | FSM receives a forbidden transition request; duplicate position detected post-send | FSM guards; position-count re-check | Reject transition; force the system to a safe state (IDLE or IN_TRADE consistent with reality); escalate; if duplicate position, refuse new entries and flag for owner. |
| **Configuration error** | Out-of-range input, wrong symbol, bad BrokerUTCOffset | Config validation at INITIALIZATION | Block transition out of INITIALIZATION; log precisely; require reload. |
| **Persistence error** | State file read/write failure | Persistence checks | Treat HALTED as **true** on read failure (fail-safe: better to halt than to bypass the kill switch); log. |
| **General recovery principle** | — | — | Prefer **skip-and-continue** for analysis errors and **halt/escalate** for safety-critical errors. The EA must never enter an inconsistent state to keep trading. |

**Fail-safe bias:** when in doubt, the system **does not trade** and **does not bypass the kill switch**.

---

# Configuration

### Recommended **configurable** values (operational, not strategy)

| Value | Why configurable |
|---|---|
| BrokerUTCOffset | Broker/season dependent; deploy-time (DOC00). |
| Session windows (London/NY UTC) | DOC00 marks them "fixed at deploy"; keep deploy-configurable with validation, not runtime-editable. |
| Magic number | Standard per-EA/instance identification. |
| MaxSpreadPoints | Broker/market-condition dependent; entry gate. |
| MaxSlippagePoints | Execution cap; broker/condition dependent. |
| News Filter enable + blackout minutes | Switchable (default OFF) per I-1; owner decision. |
| Log level, log path, log retention | Operational/diagnostic. |
| Initialisation lookback depth | Tunable within bounds for performance vs warm-up. |
| Retry counts/backoff (Error Handling) | Operational resilience tuning. |

### Recommended **hardcoded / locked** values (DOC00 strategy constants — must not be runtime-editable)

| Value | Why hardcoded (locked) |
|---|---|
| Lot size = 0.01 | Locked by DOC00; fixed-lot rule. |
| Risk:Reward = 1:2 | Locked by DOC00. |
| Max open positions = 1 | Locked by DOC00. |
| Equity kill threshold = 50% | Locked by DOC00; safety-critical, must not be loosened at runtime. |
| SFS = 2, ELT = 20 pts, FVG Min Size = 10 pts | DOC00 SMC constants; tuning only via documented back-testing and a formal DOC00 change (PATCH_001 rule). |
| SL Buffer = 20 pts, Break-Even Buffer = 5 pts | DOC00 constants; same tuning rule. |
| MaxRiskPerTradePoints = 1500 | DOC00 per-trade sanity cap. |
| Body-close confirmation for BOS/CHoCH | DOC00 definitional decision (Ambiguous Rule A2); not a parameter. |
| Timeframes H4/H1/M15 and their roles | Locked by PATCH_001. |

**Rationale:** anything that changes *what* the EA decides (strategy/risk/SMC constants) is locked to preserve determinism and DOC00 conformance; anything that changes *how it runs in a given environment* (offsets, spread/slippage caps, logging, retries) is configurable.

---

# Logging

A professional, structured, single-channel logging system (all modules emit to the Logger).

### Log levels (severity)
- **TRACE** — finest detail (e.g., each gate evaluation). Off in production.
- **DEBUG** — per-bar analysis detail (swing detected, OB created, FVG merged). Off in production by default.
- **INFO** — normal operational milestones (state transitions, session open/close, order sent/filled, BE applied, trailing move, trade closed).
- **WARN** — recoverable issues (signal skipped due to wide OB, spread gate blocked entry, history gap paused analysis).
- **ERROR** — recoverable-but-important (broker rejection, order-modify failure, persistence read fallback).
- **FATAL** — unrecoverable (config invalid, FSM forbidden-transition attempt, duplicate position). Triggers HALT/TERMINATION.

### Categories (what gets logged)
- **Information logging:** EA start/stop, config summary (with secrets/redactions none here), symbol/timeframe confirmation, BrokerUTCOffset in effect, persisted HALTED status on load.
- **Error logging:** every wrapped call failure with category, code, module, and the ErrorDecision taken.
- **Trade logging:** every order send/modify/close with ticket, direction, lot (0.01), entry, SL, TP, actual fill, realised R-multiple, and the **reason** (which entry conditions / which OB / which session). Must allow full bar-by-bar reconstruction of any back-test.
- **Performance logging:** new-bar event timestamps, analysis duration per engine (DEBUG), tick-processing count, memory/pruning events (WARN if collections exceed bounds).
- **Debug logging:** full gate-by-gate entry evaluation (each of the six conditions true/false), context snapshot identifiers, swing/OB/FVG list diffs per bar.

### Design rules
- **Structured records:** each entry has timestamp (UTC + broker time), level, category, module, message, and key/value context — not free text only.
- **Never throws:** the Logger never propagates exceptions; logging failure degrades to the MT5 journal.
- **Reconstructability:** given the logs, one must be able to reproduce exactly why the EA did or did not trade on any given bar — directly supporting DOC00's "log everything deterministically" final recommendation.
- **Kill-switch audit:** every HALT trip and every manual reset is logged at **FATAL/INFO** respectively with the equity and Initial Balance values.

---

# Self Review Result

The architecture was reviewed against the checklist before finalising. Findings and resolutions:

- **Circular dependencies:** None. The layer rule (same/lower only) + "engines never call engines" + the write-ownership table make cycles structurally impossible. *(Pass)*
- **Overlapping responsibilities:** Checked. Structure owns swings/BOS/CHoCH; Liquidity owns levels/sweeps; OB owns zones; FVG owns gaps; Risk owns SL/TP + kill switch; Execution owns orders; Management owns BE/trail. Each fact computed once. *(Pass)*
- **Modules doing multiple jobs:** None found. Core Engine orchestrates only; State Machine decides permissions only; each engine one concern. *(Pass)*
- **Missing modules:** All 17 required modules present. Added two Layer-1 elements (Market Data Access, Structural Context) as **internal architectural components**, not new concerns — they are the read-model and data chokepoint required to satisfy "no redundant scanning" and "no duplicated calculations." Flagged for owner awareness, not a deviation. *(Pass with note)*
- **Conflicting responsibilities:** Entry Confirmation (decision) vs Trade Execution (action) vs Risk (SL/TP authority) are cleanly separated: decide → compute risk → act. Management and entry are mutually exclusive by FSM. *(Pass)*
- **State machine inconsistencies:** Reviewed all transitions. Every state has defined entry/exit, allowed and forbidden transitions, failure and recovery. No state can reach a forbidden one. Duplicates, unconfirmed entries, and conflicting logic are physically prevented. *(Pass)*
- **Performance risks:** Mitigated via incremental processing, tick throttling, single data chokepoint, bounded/pruned collections, frozen per-bar snapshot, no indicators. Residual risk: unbounded lookback at init — resolved by a fixed lookback constant. *(Pass)*
- **Maintainability issues:** Low coupling + high cohesion + single Logger + central Config make future changes localized. Adding a new detection engine = new Layer-2 module writing its own context section — no existing module changes. *(Pass)*

**Flagged for owner (not auto-resolved):** Reported Inconsistency **I-1** (News Filter vs DOC00 *Limitations §10*) requires an owner decision on whether to enable news filtering at all. The architecture is neutral either way.

**Outcome:** No blocking architectural issues remain. The design is deterministic, modular, low-coupling, and fully conforms to DOC00 and PATCH_001.

---

# Final Notes

1. **This document specifies structure, not decisions.** Every trading decision remains exactly as approved in DOC00 + PATCH_001. If any implementation choice ever appears to conflict with those, those documents win.
2. **Closed-bar discipline is architectural.** It is enforced at the Market Data Access chokepoint (Layer 1), not left to individual engines — the strongest possible guarantee against repaint and look-ahead.
3. **The State Machine is non-negotiable.** No code path may bypass it. It is the single mechanism ensuring no duplicate trades, no skipped validation, no unconfirmed entries, no conflicting logic.
4. **The kill switch is fail-safe and persisted.** HALTED is sticky across restarts, manual-reset-only, and on read failure defaults to HALTED (fail-safe).
5. **News Filter is delivered but dormant.** Until the owner resolves I-1, it stays default OFF and the EA behaves exactly as DOC00 describes.
6. **Configurability is bounded.** Strategy/risk/SMC constants are locked; only environmental values are configurable.
7. **The next phase (detailed design / DOC02 onwards) may refine internal interfaces and data structures but must not alter module responsibilities, the FSM, the layering, or the write-ownership table without a formal change to DOC01.**

This document is now the official architecture specification for the project.
