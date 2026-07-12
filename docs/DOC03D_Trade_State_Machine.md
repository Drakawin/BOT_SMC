# DOC03D — Trade State Machine
## Official Specification for Decision Lifecycle Management

> **Document status:** AUTHORITATIVE — Official specification for the **Trade State Machine**.
> **Phase:** Phase 3 (Trading Intelligence) — Lifecycle Management (Part D).
> **This is NOT a trading-rule document.** This document defines the **lifecycle state machine** that governs Decision Output Objects from creation to terminal archival. It does NOT perform market analysis, does NOT create decisions, and does NOT execute trades.
> **Scope of this document:** Trade States (NEW/VALIDATED/READY/EXECUTING/EXECUTED/FAILED/EXPIRED/CANCELLED/ARCHIVED), Transition Rules, Expiration Policy, Error Handling, Auditability, Recovery.
> **Explicitly out of scope:** Market analysis, BUY/SELL logic, execution logic, risk management, position management, order placement.
> **Relationship to prior documents:**
> - **Consumes** the Decision Output Object (from DOC03C Entry Decision Engine).
> - **Interfaces with** DOC04 (Execution) via Execution Status — the State Machine receives execution results but does not perform execution.
> - **Conforms** to DOC00, DOC00_PATCH_001, DOC01 (State Machine module, Layer 6), DOC02A–F, DOC03A–C.
> **Priority rule:** If anything here appears to conflict with DOC00–DOC03C, those documents prevail. DOC03D governs only the Trade State Machine.

---

# Design Decision Record (DDR)

## Decision 1: Lifecycle Management is Separated from Decision Logic

**Decision:** The Trade State Machine is a **separate module** from the Entry Decision Engine (DOC03C). The State Machine manages lifecycle states and transitions; the Entry Decision Engine produces the decision.

**Reason:**
1. **Single Responsibility** — the Entry Decision Engine decides; the State Machine governs lifecycle. Mixing the two violates SRP and makes debugging harder.
2. **Testability** — lifecycle transitions can be tested independently of decision logic.
3. **Auditability** — every transition is traceable to a specific event (execution result, expiration, cancellation), separate from the decision itself.
4. **Consistency with DOC01** — DOC01 separates the Entry Confirmation Engine (Layer 4) from the State Machine (Layer 6). DOC03D honours that separation.

## Decision 2: State Transitions are Deterministic

**Decision:** All state transitions are **deterministic**: given the same current state and the same transition trigger, the resulting state is always the same.

**Reason:**
1. **Reproducibility** — backtests and forward tests produce identical results from identical data.
2. **Auditability** — every transition is fully reconstructable.
3. **No ambiguity** — there is never a question of "which state should this be in?"
4. **Consistency** — deterministic transitions are consistent with DOC00's deterministic philosophy and DOC03B's STRICT AND.

## Decision 3: State Machine Never Performs Market Analysis

**Decision:** The Trade State Machine **never** reads market data, performs structural analysis, or evaluates confluence conditions.

**Reason:**
1. **Separation of concerns** — market analysis is the responsibility of DOC02A–F and DOC03B. Lifecycle management is a control-flow concern, not an analytical one.
2. **Determinism** — the State Machine's behavior depends only on its inputs (Decision Output Object, Execution Status, Account Status, System Status), all of which are deterministic events, not market data.
3. **No repaint / no look-ahead** — since the State Machine never reads market data, it can never introduce repaint or look-ahead bias.
4. **Consistency with DOC01** — DOC01's State Machine is a pure authority that "never directly modifies anything except its own state variable."

---

# Trade State Machine — Architectural Specification

## Purpose
The Trade State Machine manages the complete lifecycle of a Decision Output Object. It controls decision states and transitions from creation to terminal archival. It NEVER performs market analysis, NEVER creates decisions, and NEVER executes trades.

## Architectural Role
- **Input:** Decision Output Object (from DOC03C), Execution Status (from DOC04), Account Status, System Status.
- **Output:** Updated Decision State, Lifecycle Status, Transition Events, Audit Events.
- **Lifetime:** One active Decision Output Object under management at a time (DOC00: max 1 open position).
- **Position in Architecture:** DOC01 Layer 6 (State Machine), expanded for the DOC03 Trading Intelligence phase.

## Responsibilities
1. **Track** the lifecycle state of each Decision Output Object.
2. **Enforce** transition rules (allowed and forbidden transitions).
3. **Expire** decisions that exceed their maximum lifetime.
4. **Archive** terminal decisions for audit.
5. **Emit** transition events and audit events.
6. **Never** perform market analysis, create decisions, or execute trades.

---

# Inputs

| Input | Source | Purpose |
|---|---|---|
| **Decision Output Object** | DOC03C (Entry Decision Engine) | The decision to lifecycle-manage |
| **Execution Status** | DOC04 (Execution) | Fill confirmation, rejection, timeout, error |
| **Account Status** | Risk Management Engine | HALTED flag, equity, open positions |
| **System Status** | Core Engine / Error Handling | EA shutdown, platform restart, terminal disconnect |

## Input Rules
- All inputs are **event-based** (a decision was created, an execution result arrived, a shutdown occurred).
- All inputs are **discrete** (not continuous market data).
- The State Machine **never** polls market data.

---

# Outputs

| Output | Consumer | Purpose |
|---|---|---|
| **Updated Decision State** | DOC04 (Execution), Core Engine | Current lifecycle state of the decision |
| **Lifecycle Status** | Core Engine, Logger | Whether a decision is active, expired, terminal |
| **Transition Events** | Audit trail, Logger | Every state change with full context |
| **Audit Events** | Audit trail, Logger | Full audit information per transition |

---

# Official States

The Trade State Machine has nine official states. Each Decision Output Object is in exactly one state at any time.

## State: NEW
- **Purpose:** A Decision Output Object has been created by DOC03C but has not yet been validated for lifecycle management.
- **Entry Conditions:** DOC03C produces a Decision Output Object with decision ≠ NO_ENTRY (i.e., ENTER_LONG or ENTER_SHORT).
- **Exit Conditions:** The decision passes lifecycle validation → VALIDATED; or the decision is NO_ENTRY → no state machine entry (NO_ENTRY decisions bypass the state machine).
- **Allowed Transitions:** → VALIDATED, → CANCELLED (if pre-validated cancellation), → INVALID (defensive, not a user-facing state but handled via FAILED).
- **Forbidden Transitions:** → READY, EXECUTING, EXECUTED, EXPIRED, ARCHIVED (must pass validation first).
- **Recovery:** If validation fails, the decision moves to FAILED or CANCELLED.
- **Lifetime:** Transient (resolved within the same bar evaluation).

## State: VALIDATED
- **Purpose:** The decision has passed lifecycle validation (system not halted, risk allows, no duplicate decision, inputs consistent).
- **Entry Conditions:** From NEW, after lifecycle validation passes.
- **Exit Conditions:** All gates cleared (session, spread, risk) → READY; or validation gate fails → CANCELLED.
- **Allowed Transitions:** → READY, → CANCELLED, → EXPIRED.
- **Forbidden Transitions:** → NEW, → EXECUTING, → EXECUTED, → ARCHIVED.
- **Recovery:** If a gate fails, the decision is CANCELLED with the reason recorded.
- **Lifetime:** Transient (resolved within the same bar evaluation, immediately after READY check).

## State: READY
- **Purpose:** The decision is validated and ready for execution. It is handed to DOC04 (Execution).
- **Entry Conditions:** From VALIDATED, after all gates pass.
- **Exit Conditions:** Execution Engine accepts the order → EXECUTING; or execution is refused/timeout → FAILED; or decision expires → EXPIRED; or manual cancellation → CANCELLED.
- **Allowed Transitions:** → EXECUTING, → FAILED, → EXPIRED, → CANCELLED.
- **Forbidden Transitions:** → NEW, → VALIDATED, → EXECUTED, → ARCHIVED.
- **Recovery:** If execution fails, follow the Failure Flow (→ FAILED or retry per Error Handling).
- **Lifetime:** Bounded by the Maximum Decision Lifetime (see Expiration Policy).

## State: EXECUTING
- **Purpose:** The Execution Engine has accepted the order and is processing it. Waiting for fill confirmation.
- **Entry Conditions:** From READY, when DOC04 accepts the order for execution.
- **Exit Conditions:** Order filled → EXECUTED; or order rejected/timeout/broker error → FAILED; or manual cancellation → CANCELLED.
- **Allowed Transitions:** → EXECUTED, → FAILED, → CANCELLED.
- **Forbidden Transitions:** → NEW, → VALIDATED, → READY, → EXPIRED (an executing order is not expired; it either fills or fails), → ARCHIVED.
- **Recovery:** If execution fails, follow the Error Handling strategy for the specific failure type.
- **Lifetime:** Bounded by the execution timeout (see Error Handling).

## State: EXECUTED
- **Purpose:** The order has been filled. A position is now open. The decision lifecycle is complete from the State Machine's perspective; DOC04 (Trade Management) manages the position.
- **Entry Conditions:** From EXECUTING, when DOC04 confirms the order was filled.
- **Exit Conditions:** Position closed (by SL/TP/BE/trail/manual) → ARCHIVED.
- **Allowed Transitions:** → ARCHIVED.
- **Forbidden Transitions:** → NEW, → VALIDATED, → READY, → EXECUTING, → FAILED, → EXPIRED, → CANCELLED (an executed decision cannot be cancelled; the position must be managed by DOC04).
- **Recovery:** None (executed is terminal within the state machine).
- **Lifetime:** Until the position is closed.

## State: FAILED
- **Purpose:** The decision failed at some stage (validation gate failure, execution rejection, broker error, timeout). Terminal state.
- **Entry Conditions:** From READY (execution refusal), EXECUTING (rejection/timeout/error), or NEW/VALIDATED (gate failure → maps to FAILED or CANCELLED depending on type; validation gate failures are CANCELLED, execution-level failures are FAILED).
- **Exit Conditions:** → ARCHIVED (after audit).
- **Allowed Transitions:** → ARCHIVED.
- **Forbidden Transitions:** → any active state (a failed decision never recovers within the same instance; a new decision on a new bar is a new lifecycle).
- **Recovery:** None within this instance. The system may produce a new decision on the next bar.
- **Lifetime:** Until archived.

## State: EXPIRED
- **Purpose:** The decision exceeded its Maximum Decision Lifetime without being executed (e.g., not filled in time, or a new bar arrived making the context stale). Terminal state.
- **Entry Conditions:** From READY (or VALIDATED) when the Maximum Decision Lifetime is exceeded.
- **Exit Conditions:** → ARCHIVED.
- **Allowed Transitions:** → ARCHIVED.
- **Forbidden Transitions:** → any active state (an expired decision never recovers).
- **Recovery:** None within this instance.
- **Lifetime:** Until archived.

## State: CANCELLED
- **Purpose:** The decision was cancelled (manual cancellation, pre-execution gate failure, duplicate prevention). Terminal state.
- **Entry Conditions:** From NEW, VALIDATED, READY, or EXECUTING, when a cancellation event occurs.
- **Exit Conditions:** → ARCHIVED.
- **Allowed Transitions:** → ARCHIVED.
- **Forbidden Transitions:** → any active state (a cancelled decision never recovers).
- **Recovery:** None within this instance.
- **Lifetime:** Until archived.

## State: ARCHIVED
- **Purpose:** Terminal storage for EXECUTED, FAILED, EXPIRED, and CANCELLED decisions. Retained for audit. Subject to FIFO retention pruning.
- **Entry Conditions:** From EXECUTED, FAILED, EXPIRED, or CANCELLED.
- **Exit Conditions:** None (terminal), except removal by retention pruning.
- **Allowed Transitions:** → (removed by retention pruning).
- **Forbidden Transitions:** → any active state (archived records never return).
- **Recovery:** None.
- **Lifetime:** Until pruned (FIFO, bounded retention cap).

---

# Transition Rules

## Normal Flow
```
NEW → VALIDATED → READY → EXECUTING → EXECUTED → ARCHIVED
```
A decision is created, validated, made ready, executed, the position is opened, and eventually the decision is archived when the position closes.

## Failure Flow
```
NEW/VALIDATED → CANCELLED (gate failure) → ARCHIVED
READY/EXECUTING → FAILED (execution failure) → ARCHIVED
```
A decision fails at some stage and is archived.

## Expired Flow
```
READY → EXPIRED (lifetime exceeded) → ARCHIVED
VALIDATED → EXPIRED (context stale) → ARCHIVED
```
A decision expires without being executed and is archived.

## Restart Flow
- **EA restart with an ACTIVE decision (READY/EXECUTING):** The decision is reconstructed from persisted state. If it was in READY, it is checked for expiration; if the Maximum Decision Lifetime was exceeded during the downtime, it transitions to EXPIRED. If it was in EXECUTING, the position is verified; if the order filled during downtime, it transitions to EXECUTED; if not, it is treated according to the execution timeout policy.
- **EA restart with an EXECUTED decision:** The position is verified with the broker. If the position is still open, the decision remains EXECUTED. If the position was closed during downtime, the decision transitions to ARCHIVED.

## Recovery Flow
- The State Machine does not "recover" a decision from a terminal state (FAILED/EXPIRED/CANCELLED/ARCHIVED are terminal).
- Recovery means: the system produces a **new** decision on a subsequent bar, which starts a **new** lifecycle.
- For non-terminal states (READY/EXECUTING) after a restart, the recovery flow (above) applies.

## Terminal States
- **EXECUTED:** terminal within the state machine (position managed by DOC04; archived when position closes).
- **FAILED:** terminal.
- **EXPIRED:** terminal.
- **CANCELLED:** terminal.
- **ARCHIVED:** terminal (subject to retention pruning).

---

# Expiration Policy

## Maximum Decision Lifetime
- A decision's lifetime is **one M15 bar** (the bar on which it was created).
- If a decision is not executed (filled) by the close of the **next** M15 bar after its creation bar, it is **EXPIRED**.
- Rationale: DOC00's Entry Confirmation is evaluated once per closed M15 bar; a decision is tied to the structural picture of its creation bar. A new bar means a new structural picture; the old decision is stale.

## Expired Decisions
- An expired decision transitions READY → EXPIRED → ARCHIVED.
- The expiration timestamp is recorded in the audit trail.

## New Candle Handling
- When a new M15 bar closes, any decision in READY or VALIDATED state from the previous bar is transitioned to EXPIRED.
- A new bar means a new Trade Context Object, a new confluence evaluation, and (potentially) a new decision.

## Context Change Handling
- The State Machine does not re-evaluate market context (it never reads market data). Context change is handled indirectly: a new bar produces a new Trade Context Object, which may produce a new Confluence Result, which may produce a new Decision. The old decision expires per the New Candle Handling rule.

## Duplicate Decision Prevention
- At most **one active decision** (non-terminal) exists at any time (DOC00: max 1 open position).
- A new decision cannot be created while a non-terminal decision exists.
- If DOC03C produces a new decision while a non-terminal decision exists, the new decision is **CANCELLED** (duplicate prevention), and the reason is recorded.
- Exception: if the existing decision is in a terminal state (FAILED/EXPIRED/CANCELLED/EXECUTED/ARCHIVED), a new decision can be created.

---

# Error Handling

The State Machine handles errors deterministically based on the input event (Execution Status, System Status). It does not diagnose errors; it reacts to reported statuses.

| Error Scenario | State Transition | Reason |
|---|---|---|
| **Terminal disconnected** | EXECUTING → FAILED → ARCHIVED (if in EXECUTING); READY → EXPIRED (if in READY and lifetime exceeded on reconnect) | Terminal disconnect means execution cannot complete; order may or may not have filled. On reconnect, verify position; if filled → EXECUTED; if not → FAILED. |
| **Trade context lost** | Any active state → CANCELLED → ARCHIVED | If the Trade Context Object cannot be reconstructed (e.g., after a crash without persistence), the decision is cancelled (cannot be validated against its context). |
| **Execution timeout** | EXECUTING → FAILED → ARCHIVED | If the execution timeout is exceeded, the order is considered failed. The system verifies with the broker whether the order filled; if not → FAILED. |
| **Execution rejected** | READY → FAILED → ARCHIVED | If DOC04 rejects the order (e.g., invalid stops, insufficient margin), the decision is FAILED. |
| **Broker error** | EXECUTING → FAILED → ARCHIVED | A broker error during execution transitions the decision to FAILED. |
| **Manual cancellation** | READY/EXECUTING → CANCELLED → ARCHIVED | A user-initiated cancellation transitions the decision to CANCELLED. If a position was already opened (EXECUTED), it cannot be cancelled via the State Machine (the position must be closed via DOC04). |
| **EA shutdown** | State is **persisted**; no transition occurs during shutdown. On restart, the Restart Flow applies. | The current state is saved to persistence; on restart, it is reconstructed and evaluated. |
| **Platform restart** | Same as EA shutdown — state is persisted; Restart Flow applies on restart. | Persistence ensures the state survives restarts. |

## Persistence Requirement
- The current state of any active decision MUST be persisted so that EA/platform restarts do not lose state.
- On restart, the state is reconstructed and the Restart Flow is applied.
- Persistence includes: Decision ID, current state, creation timestamp, related references.

---

# Auditability

Every state transition must be recorded as a **Transition Event** with the following fields:

| Field | Description |
|---|---|
| **Previous State** | The state before the transition |
| **New State** | The state after the transition |
| **Timestamp** | When the transition occurred |
| **Reason** | Why the transition occurred (e.g., "execution confirmed", "lifetime exceeded", "manual cancellation", "broker error") |
| **Related Decision ID** | The unique ID of the Decision Output Object |
| **Related Execution ID** | (If available) The broker order/position ID, if the transition is related to an execution event |
| **Input Event** | The input that triggered the transition (e.g., "ExecutionStatus: FILLED", "SystemStatus: SHUTDOWN", "ExpirationPolicy: LIFETIME_EXCEEDED") |

## Audit Purpose
- **Reconstruction:** any decision's lifecycle can be fully reconstructed from the transition events.
- **Debugging:** failures can be traced to specific transitions and reasons.
- **Backtesting:** historical lifecycles can be replayed exactly.
- **Compliance:** all transitions are fully documented.

---

# Implementation Constraints

## CPU Complexity
- **Per transition:** O(1) (a single state lookup and transition check).
- **Per bar:** O(1) (at most one active decision; at most a few transitions per bar).
- **Worst case:** O(1).

## Memory Complexity
- **Active decisions:** O(1) (at most one active decision at any time).
- **Archived decisions:** O(N) where N = retention cap (bounded, FIFO).
- **Transition events:** O(T) where T = total transitions (bounded by retention cap).

## Caching
- **Current state:** cached in memory (single variable for the active decision).
- **Transition history:** cached in a bounded ring/log for audit.

## Update Frequency
- **On events:** transitions occur when input events arrive (decision created, execution result, system status change).
- **On bar close:** expiration check runs on each closed M15 bar.
- **Never on ticks** for lifecycle logic (tick-based checking is limited to the execution timeout, if applicable).

## Synchronization
- **Single-threaded:** the State Machine is single-threaded (no concurrent transitions).
- **Immutable transition events:** once recorded, a transition event is never modified.

## Recovery
- **Persistence:** active decision state is persisted; reconstructed on restart.
- **Rebuild:** if persisted state is corrupted, the system rebuilds from the last known-good state; if unrecoverable, the decision is CANCELLED (fail-safe).

---

# Performance

## Worst Case
- **Transitions per bar:** O(1) (at most a few transitions per bar).
- **Time:** typically < 0.1 ms per transition.
- **Memory:** O(1) active + O(N) archived.

## Average Case
- **Transitions per bar:** 0 or 1 (most bars have no decision or a single decision lifecycle).
- **Time:** typically < 0.1 ms.
- **Memory:** O(1) active + O(N) archived.

## Complexity
- **Time complexity:** O(1) per transition.
- **Space complexity:** O(1) active + O(N) archived (N = retention cap).

## Scalability
- **Constant scaling:** performance is constant regardless of market conditions or bar count.
- **Bounded:** at most one active decision at any time; archived decisions bounded by retention.

---

# Cross-Document Consistency

| Concern | How DOC03D respects it |
|---|---|
| DOC00 (strategy rules) | DOC03D defines **no trading rules**; it manages the lifecycle of decisions produced by DOC03C. Max 1 open position is enforced by the duplicate prevention rule. |
| DOC00_PATCH_001 (timeframes) | Expiration is aligned to the M15 bar (Execution Timeframe). |
| DOC01 (architecture) | DOC03D implements the State Machine module (DOC01 Layer 6). It "never directly modifies anything except its own state variable." |
| DOC02A–F (detection engines) | DOC03D never reads DOC02A–F outputs; it only manages decision lifecycle. |
| DOC03A (Trading Intelligence Blueprint) | DOC03D manages the lifecycle of the Decision Output Object defined in DOC03A. |
| DOC03B (Confluence Engine) | DOC03D does not interact with DOC03B; it receives decisions after confluence is already evaluated. |
| DOC03C (Entry Decision Engine) | DOC03D consumes Decision Output Objects from DOC03C; it never modifies them. |
| DOC01 (immutability) | Transition events are immutable; Decision Output Objects are not modified by the State Machine (only their lifecycle state is tracked separately). |

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **No market analysis:** DOC03D **never** reads market data, performs structural analysis, or evaluates confluence conditions. It only manages lifecycle states. *(Pass)*
- **No BUY logic:** DOC03D does not create decisions. *(Pass)*
- **No SELL logic:** DOC03D does not create decisions. *(Pass)*
- **No execution logic:** DOC03D does not execute trades; it receives execution status from DOC04. *(Pass)*
- **No repaint:** Eliminated. The State Machine never reads market data; transitions are event-based and immutable after recording. *(Pass)*
- **No look-ahead bias:** Eliminated. The State Machine never reads market data; it reacts only to discrete events (decision created, execution result, system status). *(Pass)*
- **No circular dependency:** DOC03D consumes Decision Output Objects (from DOC03C) and Execution Status (from DOC04); it produces transition events and updated state. It does not feed back into market analysis or decision logic. *(Pass)*
- **Consistency with DOC03A:** DOC03D manages the lifecycle of the Decision Output Object defined in DOC03A. *(Pass)*
- **Consistency with DOC03B:** DOC03D does not interact with DOC03B; decisions are already validated before reaching the State Machine. *(Pass)*
- **Consistency with DOC03C:** DOC03D consumes Decision Output Objects from DOC03C; it never modifies them (lifecycle state is tracked separately). *(Pass)*
- **Consistency with DOC02:** DOC03D never reads DOC02A–F outputs. *(Pass)*
- **Consistency with DOC01:** DOC03D implements the State Machine module (DOC01 Layer 6) and "never directly modifies anything except its own state variable." *(Pass)*
- **Implementation feasibility:** O(1) complexity; bounded memory; single-threaded; deterministic; persisted state for restart recovery. *(Pass)*

**Scope boundaries respected:** No market analysis, no BUY/SELL logic, no execution logic, no risk management, no position management, no order placement.

**Design Decision Record (DDR):** Documented why lifecycle management is separated from decision logic, why transitions are deterministic, and why the State Machine never performs market analysis.

**Outcome:** No blocking issues. DOC03D is internally consistent, deterministic, non-repainting, look-ahead-safe, circular-dependency-free, and fully conforms to DOC00–DOC03C.

---

# Final Notes

1. **Lifecycle only.** This document specifies the Trade State Machine and nothing else. No trading rules, no BUY/SELL logic, no execution logic, no market analysis.
2. **Separated from decision logic.** The State Machine manages lifecycle; the Entry Decision Engine (DOC03C) creates decisions. These are separate concerns.
3. **Deterministic transitions.** All transitions are deterministic: given the same state and trigger, the result is always the same.
4. **Never reads market data.** The State Machine never performs market analysis; it reacts only to discrete events. This eliminates repaint and look-ahead bias by construction.
5. **Persistence.** Active decision state is persisted for restart recovery.
6. **Full audit trail.** Every transition is recorded with previous state, new state, timestamp, reason, related IDs, and input event.
7. **Terminal states are terminal.** FAILED, EXPIRED, CANCELLED, and ARCHIVED are terminal; a new decision on a new bar starts a new lifecycle.
8. **Downstream consumers** (DOC04 Execution, Core Engine) consume the updated decision state; they must not redefine the state machine or mutate transition events.

This document is now the official specification for the Trade State Machine.
