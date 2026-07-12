# DOC04A — Execution Framework
## Official Specification for the Execution Layer (Layer 5)

> **Document status:** AUTHORITATIVE — Official specification for the **Execution Framework**.
> **Phase:** Phase 4 (Execution) — Framework (Part A).
> **This is NOT a coding task.** No MQL5 code, no pseudo-code, no algorithms, no UML, no flowcharts. Architecture only.
> **Scope of this document:** Execution Pipeline, Execution Request Object, Execution Result Object, Broker Interface, Execution Event Flow, Failure Routing, Auditability, Recovery Interface.
> **Explicitly out of scope:** Market analysis, BUY/SELL logic, position management, trailing stop, risk management, order placement rules (specific SL/TP/lot calculations come from DOC00/DOD04B+).
> **Relationship to prior documents:**
> - **Implements** the Trade Execution Engine (Layer 5) defined in **DOC01_System_Architecture.md**.
> - **Consumes** READY Decision Output Objects from **DOC03D_Trade_State_Machine.md**.
> - **Interfaces with** the MetaTrader 5 Broker (Exness Standard, XAUUSD).
> - **Reports** Execution Status back to the Trade State Machine (DOC03D).
> - **Conforms** to DOC00 (strategy constants: fixed 0.01 lot, 1:2 RR, max 1 position), DOC00_PATCH_001 (M15 execution), DOC01 (layering, immutability, Error Handling), DOC02A–F (no interaction), DOC03A–D.
> **Priority rule:** If anything here appears to conflict with DOC00–DOC03D, those documents prevail. DOC04A governs only the Execution Framework architecture.

---

# Design Decision Record (DDR)

## Decision 1: Execution is Isolated from Decision Logic

**Decision:** The Execution Framework is a **separate layer** from the Trading Intelligence Layer (DOC03). The Execution Framework receives READY decisions; it never creates, modifies, or re-evaluates decisions.

**Reason:** Single Responsibility — the Trading Intelligence Layer decides; the Execution Layer acts. Mixing the two violates SRP, makes debugging harder, and introduces the risk of the execution layer second-guessing validated decisions. Consistent with DOC01's layer separation (Layer 4 = Decision, Layer 5 = Action).

## Decision 2: Broker Communication is Isolated

**Decision:** All broker communication is encapsulated behind a **Broker Interface** boundary. No other module communicates directly with MT5 order functions.

**Reason:** Isolation allows the broker communication layer to be tested, mocked, and replaced independently. It centralises error handling, timeout strategy, and retry logic in one place. It prevents broker-specific quirks from leaking into the execution workflow.

## Decision 3: Execution Objects are Immutable

**Decision:** The Execution Request Object and Execution Result Object are **immutable** after creation.

**Reason:** Immutability guarantees auditability (the exact request and result are preserved), prevents mid-flight modification, and ensures reproducibility in backtests. Consistent with DOC01's immutability principle.

---

# Execution Framework — Architectural Specification

## Purpose
The Execution Framework bridges the Trading Intelligence Layer and the Broker Execution Layer. It consumes READY Decision Output Objects and coordinates the execution workflow — from request creation, through validation, to broker submission and result routing back to the Trade State Machine.

It does NOT perform market analysis, does NOT generate decisions, and does NOT manage open positions (position management is DOC04B+).

## Architectural Role
- **Input:** Decision Output Object in READY state (from DOC03D), Account Status, Terminal Status, Broker Status.
- **Output:** Execution Request, Execution Status, Execution Result, Execution Events, Audit Events.
- **Position:** DOC01 Layer 5 (Action), expanded for Phase 4.
- **Relationship with DOC03D:** The Trade State Machine transitions a decision to READY → EXECUTING when the Execution Framework accepts it. The Execution Framework reports the result back, causing EXECUTING → EXECUTED or EXECUTING → FAILED.

---

# Inputs

| Input | Source | Purpose |
|---|---|---|
| **Decision Output Object (READY)** | DOC03D (Trade State Machine) | The validated decision to execute (ENTER_LONG / ENTER_SHORT) |
| **Trade State Machine** | DOC03D | Lifecycle coordination (state transitions) |
| **Account Status** | Risk Management Engine | Equity, balance, HALTED flag, open position count |
| **Terminal Status** | Core Engine / Error Handling | Terminal connection state (connected/disconnected) |
| **Broker Status** | Broker Interface | Broker availability, trading enabled/disabled |

## Input Rules
- Only READY decisions are accepted (DOC03D).
- NO_ENTRY decisions never reach the Execution Framework.
- All inputs are event-based, not continuous market polling.

---

# Outputs

| Output | Consumer | Purpose |
|---|---|---|
| **Execution Request** | Broker Interface | The order request to submit to the broker |
| **Execution Status** | DOC03D (Trade State Machine) | Current execution state (submitting, filled, failed, timed out) |
| **Execution Result** | DOC03D (Trade State Machine) | Final result (filled / rejected / timeout / broker error) |
| **Execution Events** | Audit trail, Logger | Every execution attempt and its outcome |
| **Audit Events** | Audit trail, Logger | Full audit information per execution attempt |

---

# Responsibilities

| Responsibility | Description |
|---|---|
| **Execution Ownership** | The Execution Framework owns the execution workflow from request creation to result routing. It does NOT own the decision (DOC03C owns that) or the position (DOC04B+ owns that). |
| **Execution Lifecycle** | Manages the execution lifecycle: request creation → validation → broker submission → result → routing back to State Machine. |
| **Execution Request Creation** | Creates an Execution Request Object from a READY Decision Output Object. |
| **Execution Validation Interface** | Validates the request before submission (symbol, lot, SL/TP presence, position count, account state). |
| **Broker Communication Interface** | Encapsulates all MT5 order submission, modification, and query operations. |
| **Execution Event Flow** | Produces events for every step (request created, validated, submitted, filled, rejected, timed out, retried). |
| **Execution Result Routing** | Routes the final result back to the Trade State Machine for state transition. |
| **Failure Routing** | Routes failures (rejection, timeout, broker error) to the Trade State Machine as FAILED, with full audit context. |
| **Recovery Interface** | Provides hooks for restart recovery (verify position with broker on reconnect). |
| **Synchronization Strategy** | Ensures exactly-one-execution (no duplicate orders) under all conditions. |

---

# Execution Pipeline

The official execution pipeline, from READY Decision to Trade State Machine notification:

```
1. READY Decision (from DOC03D)
        │
        ▼
2. Execution Request Creation
        │  Build Execution Request Object from Decision Output Object
        │  (direction, lot 0.01, SL, TP, magic number, slippage cap)
        ▼
3. Validation
        │  Validate: symbol available, lot valid, SL/TP present,
        │  position count = 0, account not HALTED, terminal connected,
        │  broker trading enabled, spread within limits
        │  → If validation fails: route FAILURE to State Machine
        ▼
4. Broker Interface
        │  Submit order to MT5 broker (via isolated Broker Interface)
        │  Wait for broker response (with timeout)
        │  → If timeout: route TIMEOUT to State Machine
        │  → If broker error: route BROKER_ERROR to State Machine
        │  → If rejected: route REJECTED to State Machine
        │  → If filled: proceed to step 5
        ▼
5. Execution Result
        │  Create Execution Result Object (FILLED)
        │  Record: fill price, actual SL/TP, ticket, latency
        ▼
6. Trade State Machine
        │  Route result to DOC03D
        │  State Machine transitions: EXECUTING → EXECUTED (filled)
        │  or EXECUTING → FAILED (rejection/timeout/error)
        ▼
7. Audit Events
        │  Record full audit trail for every attempt
```

## Pipeline Properties
1. **Sequential:** each step completes before the next begins.
2. **Deterministic:** given the same inputs, the pipeline follows the same path.
3. **Short-circuiting:** any validation or broker failure routes to Failure Routing; remaining steps are skipped.
4. **Auditable:** every step produces events for the audit trail.
5. **No market analysis:** the pipeline never reads market structure or evaluates conditions.

---

# Broker Interface — Architectural Specification

## Purpose
The Broker Interface is the **sole communication boundary** between the Execution Framework and the MetaTrader 5 broker (Exness Standard, XAUUSD). All order operations go through this interface; no other module communicates directly with MT5 order functions.

## Ownership
- **Owner:** The Execution Framework owns the Broker Interface.
- **Consumers:** Only the Execution Pipeline (step 4) calls the Broker Interface.
- **Isolation:** The Broker Interface is the only module that touches MT5 order APIs.

## Responsibilities
1. Submit market orders (BUY/SELL) with specified lot, SL, TP, magic number, and slippage cap.
2. Query order status (pending, filled, rejected, partially filled).
3. Query position existence (for duplicate prevention and restart recovery).
4. Report broker responses (success, rejection, error, timeout).
5. **Never** make trading decisions; it only executes what the Execution Framework tells it.

## Isolation
- The Broker Interface is a **thin wrapper** around MT5 order functions.
- It adds: timeout management, retry logic (bounded), error classification, and audit logging.
- It does **not** add: decision logic, position management, or market analysis.
- All broker-specific behavior (Exness, XAUUSD contract specs, `_Point`, `_Digits`) is encapsulated here.

## Failure Handling
| Failure Type | Broker Interface Action | Result Routed |
|---|---|---|
| **Order rejected** (invalid stops, insufficient margin, disabled trading) | Classify error; return REJECTED | REJECTED |
| **Broker error** (server error, connection loss mid-request) | Classify error; return BROKER_ERROR | BROKER_ERROR |
| **Timeout** (no response within timeout window) | Return TIMEOUT; do NOT assume fill | TIMEOUT |
| **Partial fill** (rare for 0.01 lot) | Report as filled (0.01 is minimum; partial fills at this size are negligible per DOC00 Assumption §9) | FILLED |
| **Requote** | Retry once within slippage cap; if still requoted, return REJECTED | REJECTED (after 1 retry) |

## Timeout Strategy
- **Timeout window:** a fixed, configured duration (e.g., a few seconds) for broker response.
- On timeout: the Broker Interface does **not** assume the order filled or failed. It queries the broker for the order/position status before declaring a result.
- If the query confirms a fill → FILLED.
- If the query confirms no position → FAILED.
- If the query itself fails (connection lost) → BROKER_ERROR; the system verifies on reconnect (Recovery Interface).

## Retry Philosophy
- **Bounded retries:** at most 1 retry for requotes (within the slippage cap).
- **No retries for:** rejections (invalid parameters — retrying with the same parameters would fail again), broker errors (may indicate a systemic issue), timeouts (may have already filled — retrying risks a duplicate).
- **Rationale:** unbounded retries risk duplicate orders. DOC00's "max 1 position" rule means duplicate prevention is paramount. Fail safe: if execution is uncertain, report TIMEOUT/BROKER_ERROR and let the Recovery Interface resolve it.

## Communication Boundaries
- **Inbound:** the Broker Interface receives execution requests from the Execution Pipeline only.
- **Outbound:** the Broker Interface returns execution results to the Execution Pipeline only.
- **No direct communication** with DOC03 (Trading Intelligence), DOC02 (Market Analysis), or any detection engine.
- **No market data reading:** the Broker Interface reads only order/position status, not price data (price data is the domain of Market Data Access, DOC01 Layer 1).

---

# Execution Request Object

## Purpose
The Execution Request Object is the **immutable record** of what the Execution Framework asked the broker to do. It is created from a READY Decision Output Object and is never modified after creation.

## Creation
- Created at Pipeline Step 2 (Execution Request Creation).
- Built from the Decision Output Object + DOC00 constants (lot 0.01, SL = OB far edge ± SL Buffer, TP = entry ± 2 × risk) + DOC01 config (magic number, slippage cap).
- **Note:** the specific SL/TP/lot calculation rules come from DOC00 §23–§24; the Execution Framework uses the values, it does not recalculate them.

## Structural Slots

| Field | Type | Description |
|---|---|---|
| **Execution ID** | Unique ID | Unique identifier for this execution request |
| **Decision ID** | Reference | Reference to the source Decision Output Object |
| **Symbol** | String | XAUUSD |
| **Direction** | Enum | BUY / SELL |
| **Lot Size** | Decimal | 0.01 (fixed, DOC00) |
| **Stop Loss** | Price | OB far edge ± SL Buffer (from Decision/Object Block context) |
| **Take Profit** | Price | Entry ± 2 × risk (DOC00 1:2 RR) |
| **Magic Number** | Integer | EA magic number (from Config) |
| **Slippage Cap** | Integer | Max slippage in points (from Spread & Slippage Filter) |
| **Creation Timestamp** | DateTime | When the request was created |
| **State Machine Reference** | Reference | Reference to the Trade State Machine decision being executed |

## Ownership
- **Owner:** Execution Framework.
- **Consumer:** Broker Interface (reads the request to submit the order).

## Lifecycle
- **Created:** at Pipeline Step 2.
- **Consumed:** by the Broker Interface at Step 4.
- **Archived:** for audit (FIFO retention).

## Immutable Fields
- All fields are immutable after creation. No field can be modified.

## Audit Fields
- Execution ID, Decision ID, creation timestamp, all request parameters, and the full request context are recorded for audit.

## Expiration
- The Execution Request Object does not have its own expiration; it follows the Decision Output Object's lifetime (DOC03D: one M15 bar). If the decision expires before execution completes, the request is archived as EXPIRED.

## Historical Storage
- Archived Execution Request Objects are retained for audit (bounded FIFO retention).

---

# Execution Result Object

## Purpose
The Execution Result Object is the **immutable record** of what the broker did with the execution request. It is the final output of the Execution Pipeline and is routed back to the Trade State Machine.

## Creation
- Created at Pipeline Step 5 (for FILLED) or at the failure routing step (for REJECTED/TIMEOUT/BROKER_ERROR).

## Structural Slots

| Field | Type | Description |
|---|---|---|
| **Execution ID** | Unique ID | Same as the Execution Request Object |
| **Decision ID** | Reference | Reference to the source Decision Output Object |
| **Result** | Enum | FILLED / REJECTED / TIMEOUT / BROKER_ERROR |
| **Fill Price** | Price | (If FILLED) The actual fill price |
| **Actual Stop Loss** | Price | (If FILLED) The SL set on the broker |
| **Actual Take Profit** | Price | (If FILLED) The TP set on the broker |
| **Ticket / Position ID** | Integer | (If FILLED) The broker order/position ticket |
| **Failure Reason** | String | (If not FILLED) The reason for failure |
| **Broker Response Code** | Integer | (If available) The MT5 return code |
| **Latency** | Integer | Time from request submission to result (ms) |
| **Result Timestamp** | DateTime | When the result was produced |

## Ownership
- **Owner:** Execution Framework.
- **Consumer:** Trade State Machine (DOC03D) for state transitions.

## Result Types

### FILLED
- The order was successfully filled.
- A position is now open.
- The Result Object contains: fill price, actual SL/TP, ticket.
- Routed to State Machine → EXECUTING → EXECUTED.

### REJECTED
- The broker rejected the order (invalid stops, insufficient margin, trading disabled).
- No position was opened.
- The Result Object contains: failure reason, broker response code.
- Routed to State Machine → EXECUTING → FAILED.

### TIMEOUT
- The broker did not respond within the timeout window.
- A position may or may not have been opened (uncertain).
- The Result Object contains: timeout reason.
- Routed to State Machine → EXECUTING → FAILED.
- The Recovery Interface verifies position existence on reconnect.

### BROKER_ERROR
- A broker/server error occurred during execution.
- A position may or may not have been opened (uncertain).
- The Result Object contains: error details, broker response code.
- Routed to State Machine → EXECUTING → FAILED.
- The Recovery Interface verifies position existence on reconnect.

## Consumers
- Trade State Machine (DOC03D): consumes the result for state transition.
- Audit trail: consumes the result for audit logging.
- Logger: consumes the result for logging.

## Lifecycle
- **Created:** at Pipeline Step 5 (FILLED) or failure routing.
- **Consumed:** by Trade State Machine.
- **Archived:** for audit (FIFO retention).

## Immutability
- All fields are immutable after creation.

---

# Auditability

Every execution attempt must be recorded with the following audit fields:

| Field | Description |
|---|---|
| **Execution ID** | Unique identifier for the execution request |
| **Decision ID** | Reference to the source Decision Output Object |
| **Timestamp** | When the execution attempt occurred |
| **Broker Response** | The raw broker response (return code, message) |
| **Execution Result** | FILLED / REJECTED / TIMEOUT / BROKER_ERROR |
| **Failure Reason** | (If not FILLED) Detailed reason for failure |
| **Latency** | Time from request submission to result (ms) |
| **Request Snapshot** | Full Execution Request Object (all parameters) |
| **Result Snapshot** | Full Execution Result Object |
| **State Machine Transition** | The state transition triggered (e.g., EXECUTING → EXECUTED) |

## Audit Purpose
- **Reconstruction:** any execution can be fully reconstructed from the audit trail.
- **Debugging:** failures can be traced to specific broker responses and failure reasons.
- **Backtesting:** historical executions can be replayed exactly.
- **Compliance:** all execution attempts are fully documented.

---

# Implementation Constraints

## Maximum CPU Cost
- **Per execution:** O(1) (a single broker call + result processing).
- **Per bar:** O(1) (at most one execution per bar; most bars have no execution).
- **Worst case:** O(1) + retry overhead (bounded: at most 1 retry).

## Maximum Memory Cost
- **Active:** O(1) (at most one active execution at any time).
- **Archived:** O(N) where N = retention cap (bounded, FIFO).

## Synchronization
- **Single-threaded:** the Execution Framework is single-threaded (no concurrent executions).
- **Exactly-one-execution:** enforced by the duplicate prevention rule (at most one active decision → at most one execution).
- **No concurrent order submission:** the pipeline is sequential.

## Caching
- **Broker connection:** cached (the MT5 terminal connection is maintained by the platform).
- **Execution Request/Result:** not cached (each is unique and immutable); archived for audit.

## Retry Policy
- **Requotes:** 1 retry within the slippage cap.
- **Rejections:** no retry (same parameters would fail again).
- **Broker errors:** no retry (may indicate systemic issue).
- **Timeouts:** no retry (may have already filled; retrying risks a duplicate).
- **Rationale:** bounded retries prevent duplicate orders. Fail safe.

## Timeout Policy
- **Timeout window:** a fixed, configured duration for broker response.
- **On timeout:** do NOT assume fill or failure; query broker for order/position status.
- **If query confirms fill:** FILLED.
- **If query confirms no position:** FAILED.
- **If query fails:** BROKER_ERROR; verify on reconnect (Recovery Interface).

## Recovery Strategy
- **On EA/platform restart with an EXECUTING decision:** the Recovery Interface queries the broker for position existence.
  - If position exists → report FILLED to State Machine.
  - If no position → report FAILED to State Machine.
  - If query fails → wait for reconnect, then retry.
- **On terminal reconnect during EXECUTING:** same as above.
- **Persistence:** the active Execution Request Object is persisted for restart recovery.

---

# Performance

## Worst Case
- **Execution + 1 retry:** O(1) + broker latency (typically < 1 second).
- **Memory:** O(1) active + O(N) archived.

## Average Case
- **Single execution, no retry:** O(1) + broker latency (typically < 500 ms).
- **Memory:** O(1) active + O(N) archived.

## Complexity
- **Time complexity:** O(1) per execution (excluding broker latency, which is external).
- **Space complexity:** O(1) active + O(N) archived (N = retention cap).

## Scalability
- **Constant scaling:** performance is constant regardless of market conditions or bar count.
- **Bounded:** at most one active execution at any time (DOC00: max 1 position).

---

# Cross-Document Consistency

| Concern | How DOC04A respects it |
|---|---|
| DOC00 (strategy rules) | DOC04A defines **no trading rules**; it uses DOC00's constants (0.01 lot, 1:2 RR, max 1 position) as given values. It does not recalculate them. |
| DOC00_PATCH_001 (timeframes) | Execution is triggered by READY decisions on the M15 timeframe. |
| DOC01 (architecture) | DOC04A implements the Trade Execution Engine (Layer 5) and uses the Error Handling Module and the Broker Interface isolation principle. |
| DOC02A–F (detection engines) | DOC04A has **no interaction** with detection engines; it receives only READY decisions. |
| DOC03A (Trading Intelligence Blueprint) | DOC04A consumes the Decision Output Object defined in DOC03A. |
| DOC03B (Confluence Engine) | DOC04A has no direct interaction with DOC03B. |
| DOC03C (Entry Decision Engine) | DOC04A consumes Decision Output Objects from DOC03C (via DOC03D). |
| DOC03D (Trade State Machine) | DOC04A receives READY decisions from DOC03D and reports Execution Results back, causing state transitions (EXECUTING → EXECUTED / EXECUTING → FAILED). |
| DOC01 (immutability) | Execution Request and Result Objects are immutable after creation. |
| DOC01 (Error Handling) | Broker errors are classified and routed through the Error Handling strategy. |

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **No market analysis:** DOC04A **never** reads market structure, performs analysis, or evaluates conditions. It only executes decisions. *(Pass)*
- **No BUY logic:** DOC04A does not create decisions; it executes READY decisions from DOC03D. *(Pass)*
- **No SELL logic:** Same as above. *(Pass)*
- **No position management:** DOC04A does not manage open positions (break-even, trailing, SL/TP modification of open positions). That is DOC04B+. *(Pass)*
- **No trailing stop:** Not included. *(Pass)*
- **No risk management:** DOC04A does not compute risk; it uses DOC00's constants as given values. *(Pass)*
- **No circular dependency:** DOC04A consumes from DOC03D (downstream) and reports back to DOC03D. It does not feed into DOC02 (Market Analysis) or DOC03 (Trading Intelligence) decision logic. The feedback to DOC03D is a result event, not a decision input. *(Pass)*
- **Consistency with DOC03D:** DOC04A receives READY decisions and reports results back, triggering state transitions (EXECUTING → EXECUTED / EXECUTING → FAILED). *(Pass)*
- **Consistency with DOC03C:** DOC04A consumes Decision Output Objects (via DOC03D); it never modifies them. *(Pass)*
- **Consistency with DOC03B:** No direct interaction. *(Pass)*
- **Consistency with DOC03A:** DOC04A consumes the Decision Output Object defined in DOC03A. *(Pass)*
- **Implementation feasibility:** All operations are standard MT5 order functions; O(1) complexity; bounded memory; single-threaded; persisted for recovery. *(Pass)*

**Scope boundaries respected:** No market analysis, no BUY/SELL logic, no position management, no trailing stop, no risk management. The Execution Framework bridges Decision and Broker only.

**Design Decision Record (DDR):** Documented why execution is isolated from decision logic, why broker communication is isolated, and why Execution Objects are immutable.

**Outcome:** No blocking issues. DOC04A is internally consistent, deterministic, non-repainting, look-ahead-safe, circular-dependency-free, and fully conforms to DOC00–DOC03D.

---

# Final Notes

1. **Execution only.** This document specifies the Execution Framework and nothing else. No trading rules, no BUY/SELL logic, no position management, no market analysis.
2. **Isolated from decisions.** The Execution Framework receives READY decisions; it never creates, modifies, or re-evaluates them.
3. **Broker isolation.** All broker communication goes through the Broker Interface; no other module touches MT5 order functions.
4. **Immutable objects.** Execution Request and Result Objects are immutable after creation.
5. **Bounded retries.** At most 1 retry (requotes only); no retries for rejections, broker errors, or timeouts (fail safe to prevent duplicates).
6. **Recovery Interface.** On restart/reconnect, the system verifies position existence with the broker and reconciles the state.
7. **Full audit trail.** Every execution attempt is fully reconstructable from the audit trail.
8. **Downstream consumers** (DOC04B+ Trade Management) manage positions after execution; they must not redefine the execution framework or mutate execution objects.

This document is now the official specification for the Execution Framework.
