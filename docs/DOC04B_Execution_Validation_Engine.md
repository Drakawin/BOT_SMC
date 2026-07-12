# DOC04B — Execution Validation Engine
## Official Specification for the Final Pre-Broker Safety Barrier

> **Document status:** AUTHORITATIVE — Official specification for the **Execution Validation Engine**.
> **Phase:** Phase 4 (Execution) — Validation Layer (Part B).
> **This is NOT a coding task.** No MQL5 code, no pseudo-code, no algorithms, no UML, no flowcharts.
> **Purpose:** The Execution Validation Engine performs the final deterministic validation before any Execution Request is allowed to reach the Broker Interface.
> **Scope:** Terminal Validation, Account Validation, Broker Validation, Execution Request Validation, Decision Validation, Trade State Validation, Market Availability Validation, Symbol Validation, Validation Result Object, Auditability, Recovery.
> **Explicitly out of scope:** Market analysis, BUY/SELL decision creation, order placement, risk calculation, position management, trade management.
> **Relationship to prior documents:**
> - Implements the **Validation** step inside the DOC04A Execution Pipeline.
> - Consumes the Execution Request Object and Decision Output Object defined in DOC04A/DOC03C.
> - Reports validation pass/fail status to DOC04A and DOC03D.
> - Conforms to DOC00–DOC04A without redefining any SMC concept.

---

# Design Decision Record (DDR)

## Decision 1: Validation is Separated from Execution

**Decision:** Execution validation is a separate engine between Execution Request creation and Broker Interface submission.

**Reason:**
- Validation is a safety barrier; broker submission is an action.
- Separating them prevents invalid requests from ever reaching the broker layer.
- It improves auditability: a rejected request has a deterministic validation reason, independent of broker response.
- It keeps DOC04A's Broker Interface isolated from business validation concerns.

## Decision 2: Short-Circuit Validation is Used

**Decision:** Validation stops at the first failed validation category.

**Reason:**
- The request cannot be executed if any mandatory validation fails.
- Continuing after failure wastes CPU and may create confusing audit output.
- First failure is deterministic because validation order is fixed.
- Short-circuit behavior is consistent with DOC03B's STRICT AND philosophy.

## Decision 3: Validation Never Performs Execution

**Decision:** The Execution Validation Engine never places orders and never communicates directly with broker order placement functions.

**Reason:**
- It is a validation engine, not an execution engine.
- Order placement belongs exclusively to the Broker Interface defined in DOC04A.
- This preserves separation of responsibilities and prevents duplicate execution paths.

---

# Responsibilities

The Execution Validation Engine owns:

1. **Validation Ownership** — determines whether an Execution Request is safe to submit.
2. **Validation Order** — evaluates validation categories in a fixed deterministic sequence.
3. **Short-Circuit Validation** — stops immediately on first failure.
4. **Failure Handling** — produces a failure reason and recovery recommendation.
5. **Validation Lifecycle** — creates and archives immutable Validation Result Objects.
6. **Validation Freshness** — ensures validation is valid only for the current execution attempt.
7. **Audit Events** — records every pass/fail event.

The Execution Validation Engine does **not** own:
- Decision creation.
- Market analysis.
- Risk calculation.
- Broker order placement.
- Position management.

---

# Inputs

| Input | Source | Purpose |
|---|---|---|
| **Execution Request Object** | DOC04A | Request being validated before broker submission |
| **Decision Output Object** | DOC03C / DOC04A reference | Source decision behind the request |
| **Trade State** | DOC03D | Confirms decision is in correct lifecycle state |
| **Account Status** | Risk / Account service | Account connectivity, margin, drawdown protection, open positions |
| **Terminal Status** | Core Engine / MT5 terminal | Terminal connected, algo trading enabled, EA permissions |
| **Broker Status** | Broker Interface | Broker trading enabled, market open, session tradable |
| **Symbol Status** | Symbol service / MT5 symbol info | Symbol availability, tick freshness, volume support, stop/freeze levels |

All inputs are read-only. The engine must never modify upstream records.

---

# Outputs

| Output | Purpose |
|---|---|
| **Execution Validation Result** | PASS / FAIL / INVALID |
| **Validation Audit** | Full audit trail of validation stages |
| **Failure Reason** | Deterministic reason for failure |
| **Validation Events** | Immutable validation event records |

---

# Validation Order

Validation is performed in the following fixed order:

1. **Terminal Validation**
2. **Account Validation**
3. **Broker Validation**
4. **Symbol Validation**
5. **Trade State Validation**
6. **Decision Validation**
7. **Execution Request Validation**
8. **Market Availability Validation**

This order is chosen so broad environment failures are rejected before request-specific checks. It is deterministic and never changes at runtime.

---

# Short-Circuit Validation

If any validation category fails:

1. Validation stops immediately.
2. A Validation Result Object is created with status = FAIL.
3. The failed validation category is recorded.
4. The failure reason is recorded.
5. A recovery recommendation is recorded.
6. The Execution Request is not allowed to reach the Broker Interface.

If all categories pass, the Validation Result Object status = PASS and the request may proceed to the DOC04A Broker Interface.

---

# Terminal Validation

## Purpose
Verify the local MetaTrader 5 terminal and EA environment are capable of submitting orders.

## Checks

| Check | Required Condition | Failure Result |
|---|---|---|
| **Terminal Connected** | Terminal has active server connection | FAIL: TERMINAL_DISCONNECTED |
| **Trading Enabled** | Terminal trading is enabled | FAIL: TERMINAL_TRADING_DISABLED |
| **Algo Trading Enabled** | Automated trading permission is enabled | FAIL: ALGO_TRADING_DISABLED |
| **EA Permission** | EA has permission to trade | FAIL: EA_TRADE_PERMISSION_DENIED |
| **Platform Ready** | Platform is initialized and not shutting down | FAIL: PLATFORM_NOT_READY |

## Recovery Recommendation
- Wait for reconnection.
- Enable terminal trading / algo trading.
- Restart EA if platform not ready.

---

# Account Validation

## Purpose
Verify the account is connected, allowed to trade, and within project safety boundaries.

## Checks

| Check | Required Condition | Failure Result |
|---|---|---|
| **Account Connected** | Account is connected and authorized | FAIL: ACCOUNT_DISCONNECTED |
| **Margin Available** | Account has sufficient margin for 0.01 lot | FAIL: INSUFFICIENT_MARGIN |
| **Free Margin** | Free margin is positive and sufficient | FAIL: INSUFFICIENT_FREE_MARGIN |
| **Drawdown Protection** | Equity > 50% of Initial Balance and HALTED = false | FAIL: EQUITY_KILL_SWITCH_ACTIVE |
| **Maximum Open Position** | Open position count for symbol/magic = 0 | FAIL: MAX_POSITION_REACHED |
| **Trading Permission** | Account trading permission enabled | FAIL: ACCOUNT_TRADING_DISABLED |

## Recovery Recommendation
- Do not retry automatically if account/risk validation fails.
- If kill switch is active, manual reset is required per DOC00.
- If max position reached, wait until position closes; do not open duplicate trades.

---

# Broker Validation

## Purpose
Verify that the broker environment permits order submission.

## Checks

| Check | Required Condition | Failure Result |
|---|---|---|
| **Market Open** | Broker market for the symbol is open | FAIL: MARKET_CLOSED |
| **Broker Trading Enabled** | Broker permits trading on the account/symbol | FAIL: BROKER_TRADING_DISABLED |
| **Trading Session Active** | Symbol trading session accepts orders | FAIL: SYMBOL_SESSION_CLOSED |
| **Spread Availability** | Bid/Ask available and spread calculable | FAIL: SPREAD_UNAVAILABLE |
| **Symbol Tradable** | Symbol trade mode allows order placement | FAIL: SYMBOL_NOT_TRADABLE |

## Recovery Recommendation
- Wait for broker market/session availability.
- Do not retry while broker trading is disabled.

---

# Symbol Validation

## Purpose
Verify XAUUSD symbol data and trading constraints are available and compatible with the Execution Request.

## Checks

| Check | Required Condition | Failure Result |
|---|---|---|
| **Correct Symbol** | Request symbol = XAUUSD | FAIL: WRONG_SYMBOL |
| **Price Availability** | Valid bid/ask prices exist | FAIL: PRICE_UNAVAILABLE |
| **Tick Freshness** | Latest tick is fresh enough for execution | FAIL: STALE_TICK |
| **Volume Support** | Requested lot 0.01 is supported | FAIL: INVALID_VOLUME |
| **Stop Level Availability** | Broker stop level available and compatible | FAIL: STOP_LEVEL_INVALID |
| **Freeze Level Availability** | Freeze level available and not blocking request | FAIL: FREEZE_LEVEL_BLOCKED |

## Recovery Recommendation
- Refresh symbol data.
- Wait for new tick if tick is stale.
- Do not modify project lot size; fixed 0.01 lot remains locked by DOC00.

---

# Trade State Validation

## Purpose
Verify that the Decision Output Object is in the correct lifecycle state to be executed.

## Checks

| Check | Required Condition | Failure Result |
|---|---|---|
| **Decision READY** | Trade State = READY | FAIL: DECISION_NOT_READY |
| **Not Expired** | Decision has not expired per DOC03D | FAIL: DECISION_EXPIRED |
| **Not Executed** | Decision not already executed | FAIL: DECISION_ALREADY_EXECUTED |
| **Not Cancelled** | Decision not cancelled | FAIL: DECISION_CANCELLED |
| **Context Valid** | Source context still valid for this execution attempt | FAIL: CONTEXT_INVALID |
| **Duplicate Prevention** | No other active execution exists | FAIL: DUPLICATE_EXECUTION_BLOCKED |

## Recovery Recommendation
- If not READY, reject request.
- If expired/cancelled/executed, archive and do not retry.
- If duplicate detected, fail safe and do not submit order.

---

# Decision Validation

## Purpose
Verify the Decision Output Object is internally valid and execution-eligible.

## Checks

| Check | Required Condition | Failure Result |
|---|---|---|
| **Decision Type** | Decision is BUY or SELL, not NO_TRADE/NO_ENTRY | FAIL: NON_EXECUTABLE_DECISION |
| **Decision ID** | Decision ID exists and matches request | FAIL: DECISION_ID_MISMATCH |
| **Decision Timestamp** | Decision timestamp is within lifetime | FAIL: DECISION_STALE |
| **Decision Immutable** | Decision record is immutable and unmodified | FAIL: DECISION_MUTATED |
| **Audit Reference** | Confluence/audit reference exists | FAIL: DECISION_AUDIT_MISSING |

## Recovery Recommendation
- Reject invalid decision.
- Do not attempt to reconstruct market logic inside validation.

---

# Execution Request Validation

## Purpose
Verify that the Execution Request Object is complete and internally consistent before broker submission.

## Checks

| Check | Required Condition | Failure Result |
|---|---|---|
| **Execution ID** | Execution ID exists and is unique | FAIL: EXECUTION_ID_INVALID |
| **Decision Reference** | Request references a valid Decision ID | FAIL: DECISION_REFERENCE_INVALID |
| **Direction** | Direction is BUY or SELL | FAIL: INVALID_DIRECTION |
| **Lot Size** | Lot size = 0.01 | FAIL: INVALID_LOT_SIZE |
| **Stop Loss Present** | Stop Loss exists | FAIL: STOP_LOSS_MISSING |
| **Take Profit Present** | Take Profit exists | FAIL: TAKE_PROFIT_MISSING |
| **SL/TP Directionality** | SL/TP are on valid sides of price for direction | FAIL: INVALID_SL_TP_DIRECTION |
| **Magic Number** | Magic number exists | FAIL: MAGIC_NUMBER_MISSING |
| **Slippage Cap** | Slippage cap exists and is non-negative | FAIL: SLIPPAGE_CAP_INVALID |

## Recovery Recommendation
- Do not submit incomplete or inconsistent requests.
- Return failure to DOC04A and DOC03D.

---

# Market Availability Validation

## Purpose
Verify current execution conditions are available at the final safety barrier.

## Checks

| Check | Required Condition | Failure Result |
|---|---|---|
| **Bid/Ask Available** | Valid bid and ask prices exist | FAIL: BID_ASK_UNAVAILABLE |
| **Spread Valid** | Spread is calculable and within configured limit | FAIL: SPREAD_INVALID_OR_TOO_WIDE |
| **Price Not Frozen** | Symbol not blocked by freeze level | FAIL: PRICE_FROZEN |
| **Execution Window Valid** | Decision still within execution-valid bar | FAIL: EXECUTION_WINDOW_EXPIRED |

## Recovery Recommendation
- If market data unavailable/stale, reject request.
- Do not wait inside validation; future bar may create a new decision.

---

# Validation Result Object

## Purpose
The Validation Result Object is the immutable output of the Execution Validation Engine. It records whether the Execution Request is allowed to proceed to the Broker Interface.

## Creation
- Created once per Execution Request validation attempt.
- Created immediately after validation completes or short-circuits.

## Ownership
- Owned by the Execution Validation Engine.
- Consumed by DOC04A Execution Framework.
- Read by DOC03D Trade State Machine for failure routing when validation fails.

## Fields

| Field | Description |
|---|---|
| **Validation ID** | Unique identifier for the validation attempt |
| **Execution ID** | Related Execution Request ID |
| **Decision ID** | Related Decision Output Object ID |
| **Status** | PASS / FAIL / INVALID |
| **Failed Validation** | Validation category/check that failed (if any) |
| **Failure Reason** | Deterministic failure reason |
| **Recovery Recommendation** | Recommended recovery action |
| **Timestamp** | Validation completion timestamp |
| **Validation Order** | Ordered list of validation categories evaluated |
| **Evaluated Checks** | Checks completed before pass/fail |
| **Audit Snapshot** | Snapshot of inputs used for validation |

## Immutable Fields
All fields are immutable after creation.

## Expiration
- A PASS result is valid only for the current execution attempt.
- A PASS result cannot be reused for a later bar or a different Execution Request.
- FAIL/INVALID results are terminal audit records.

## Historical Storage
Validation Result Objects are archived with FIFO retention.

---

# Auditability

Every failed validation must record:

| Required Field | Description |
|---|---|
| **Validation ID** | Unique validation attempt ID |
| **Execution ID** | Related execution request |
| **Decision ID** | Related decision |
| **Timestamp** | Failure timestamp |
| **Failed Validation** | Exact category/check that failed |
| **Failure Reason** | Deterministic reason code and description |
| **Recovery Recommendation** | Action recommendation (wait, cancel, manual reset, retry not allowed, etc.) |

Every successful validation must also record all checks passed, the timestamp, and the validated request snapshot.

---

# Validation Lifecycle

## States

### CREATED
- Validation attempt has been created for an Execution Request.

### EVALUATING
- Validation categories are being checked in deterministic order.

### PASSED
- All validation categories passed. Request may proceed to Broker Interface.

### FAILED
- A validation check failed. Request is blocked from Broker Interface.

### INVALID
- Validation engine encountered a structural error (missing dependency, inconsistent input). Request is blocked.

### ARCHIVED
- Result has been stored for audit and retention.

## Lifecycle Rules
- CREATED → EVALUATING → PASSED → ARCHIVED.
- CREATED → EVALUATING → FAILED → ARCHIVED.
- CREATED → EVALUATING → INVALID → ARCHIVED.
- PASSED, FAILED, INVALID are terminal result states before archival.

---

# Failure Handling

| Failure Class | Handling |
|---|---|
| Terminal/account/broker unavailable | FAIL; do not submit request; route failure to DOC04A/DOC03D |
| Decision/state invalid | FAIL; cancel/expire decision as appropriate in DOC03D |
| Request malformed | INVALID or FAIL; do not submit; audit error |
| Duplicate execution risk | FAIL; block request; fail safe |
| Kill switch active | FAIL; manual reset required per DOC00 |
| Missing input | INVALID; block request |

Validation failure never triggers order submission.

---

# Recovery Strategy

- **Transient environment failures** (terminal disconnected, market closed, stale tick): wait for future valid conditions; current request fails.
- **Risk/account failures** (kill switch, max position): do not retry automatically.
- **Malformed request / invalid decision:** fail terminally; future bar may produce a new decision.
- **Duplicate prevention failure:** fail safe; never submit duplicate order.
- **Platform restart:** validation does not resume mid-attempt. A new validation attempt is created only if the persisted decision/request remains valid under DOC03D and DOC04A.

---

# Implementation Constraints

## CPU Complexity
- O(V), where V = number of validation checks.
- V is small and fixed, so effective cost is O(1).

## Memory Complexity
- O(1) per validation attempt.
- Archived results bounded by FIFO retention.

## Caching Strategy
- Do not cache PASS results across execution attempts.
- Cache read-only terminal/account/symbol status only within the current validation attempt.

## Synchronization
- Single-threaded validation.
- One validation attempt per Execution Request.
- Inputs immutable during validation.

## Maximum Validation Time
- Validation must complete within the same execution cycle before Broker Interface submission.
- Expected duration: < 1 ms excluding platform status query latency.

## Maximum Validation Lifetime
- A PASS result is valid only for the immediate Broker Interface submission that follows it.
- If submission is delayed past the current execution attempt, validation must be repeated.

---

# Performance

## Worst Case
- All validation categories pass; every check is evaluated.
- Complexity: O(V), effectively constant.
- Expected duration: < 1 ms plus status-query latency.

## Average Case
- Short-circuit occurs early on obvious failures (terminal disconnected, risk halted, wrong state).
- Complexity: O(1) to O(V/2).

## Scalability
- Constant per execution attempt.
- At most one active execution request under DOC00/DOC03D rules, so no scaling pressure in single-symbol mode.
- Future multi-symbol support scales linearly with number of active symbols, with one validation attempt per symbol/request.

---

# Cross-Document Consistency

| Concern | How DOC04B respects it |
|---|---|
| DOC00 | Enforces fixed 0.01 lot, max 1 position, kill switch, no duplicate orders; does not redefine strategy concepts. |
| DOC01 | Maintains separation of concerns, defensive programming, error handling, and low-coupling architecture. |
| DOC03A | Operates downstream of Trading Intelligence; never changes Trade Context or Decision Output semantics. |
| DOC03B | Does not revalidate confluence; consumes only final decision/result status indirectly. |
| DOC03C | Validates Decision Output Object integrity; never creates BUY/SELL decisions. |
| DOC03D | Validates Trade State and routes failures back through the state machine. |
| DOC04A | Implements the Validation step before Broker Interface submission. |

---

# Self Review Result

- **No market analysis:** Pass. The engine validates execution readiness only.
- **No BUY logic:** Pass. It never creates or changes BUY decisions.
- **No SELL logic:** Pass. It never creates or changes SELL decisions.
- **No execution:** Pass. It never places orders; it only permits or blocks broker submission.
- **No order placement:** Pass. Broker Interface remains the only order submission boundary.
- **No risk calculation:** Pass. It reads risk/account status; it does not calculate strategy risk.
- **No circular dependency:** Pass. It consumes DOC04A/DOC03D inputs and returns validation results; it does not feed back into analysis or decision creation.
- **Consistency with DOC04A:** Pass. This document specifies the Validation step in DOC04A's pipeline.
- **Consistency with DOC03D:** Pass. Trade State validation and failure routing respect DOC03D lifecycle states.
- **Consistency with DOC03C/B/A:** Pass. It consumes downstream decision artifacts only; it does not reinterpret them.
- **Implementation feasibility using MQL5 APIs only:** Pass. All validations rely on standard terminal/account/symbol/broker status and immutable request data.

**Outcome:** No blocking issues. DOC04B is internally consistent, deterministic, non-executing, non-analytical, and fully compatible with DOC00–DOC04A.

---

# Final Notes

1. **Final safety barrier.** DOC04B is the last deterministic validation layer before a request reaches the Broker Interface.
2. **No execution.** Passing validation permits broker submission; the validation engine itself never submits orders.
3. **Short-circuit.** Validation stops at the first failure and records a deterministic reason.
4. **Immutable output.** Validation Result Objects are immutable and archived.
5. **Fail safe.** Any missing, stale, inconsistent, or unsafe input blocks execution.
6. **Downstream behavior.** DOC04A consumes PASS results for broker submission and routes FAIL/INVALID results back to DOC03D.

This document is now the official specification for the Execution Validation Engine.
