# DOC04C — Order Submission Engine
## Official Specification for Broker Order Submission

> **Document status:** AUTHORITATIVE — Official specification for the **Order Submission Engine**.
> **Phase:** Phase 4 (Execution) — Submission Layer (Part C).
> **This is NOT a coding task.** No MQL5 code, no pseudo-code, no algorithms, no UML, no flowcharts.
> **Purpose:** The Order Submission Engine submits validated Execution Requests to the MetaTrader 5 Broker Interface. It consumes only validated requests (DOC04B PASS), never performs market analysis, never creates BUY/SELL decisions, never validates requests, and never manages positions.
> **Scope:** Submission Pipeline, Broker Communication, Response Routing, Failure Routing, Retry Philosophy, Timeout Handling, Duplicate Prevention, Submission Audit.
> **Explicitly out of scope:** Market analysis, BUY/SELL decision creation, execution validation (DOC04B), position management, trade management, risk calculation.
> **Relationship to prior documents:**
> - Implements the **Broker Interface** step inside the DOC04A Execution Pipeline.
> - Consumes validated Execution Requests (DOC04B PASS results).
> - Reports Submission Results to DOC04A and DOC03D.
> - Conforms to DOC00–DOC04B without redefining any SMC concept.

---

# Design Decision Record (DDR)

## Decision 1: Submission is Separated from Validation

**Decision:** The Order Submission Engine is a separate engine from the Execution Validation Engine (DOC04B). DOC04B validates; DOC04C submits only after PASS.

**Reason:**
- Validation is a safety barrier; submission is an action.
- Separating them prevents invalid requests from ever reaching the broker.
- It improves auditability: a rejected request has a deterministic validation reason (DOC04B), independent of broker response (DOC04C).
- It keeps DOC04C focused on broker communication, not business validation.

## Decision 2: Submission is Separated from Position Management

**Decision:** The Order Submission Engine never manages open positions. Position management (break-even, trailing, SL/TP modification) belongs to DOC04B+ (Trade Management).

**Reason:**
- Submission is a one-shot action: submit order, receive result, report back.
- Position management is ongoing: monitor position, apply BE/trail, close on SL/TP.
- Separating them prevents the submission engine from holding state across the position lifecycle.
- It keeps DOC04C single-purpose: submit and report.

## Decision 3: Submission Result Objects are Immutable

**Decision:** The Submission Result Object is immutable after creation.

**Reason:**
- Immutability guarantees auditability (the exact submission result is preserved).
- It prevents mid-flight modification of submission outcomes.
- It ensures reproducibility in backtests.
- It is consistent with DOC04A's immutability principle for Execution Request/Result Objects.

---

# Order Submission Engine — Architectural Specification

## Purpose
The Order Submission Engine submits validated Execution Requests to the MetaTrader 5 Broker Interface and reports the result back to the Execution Framework (DOC04A) and Trade State Machine (DOC03D).

It does NOT validate requests (DOC04B does that). It does NOT perform market analysis. It does NOT create decisions. It does NOT manage positions.

## Architectural Role
- **Input:** Validated Execution Request (DOC04B PASS), Trade State (DOC03D), Terminal Status, Broker Interface (DOC04A).
- **Output:** Submission Result Object, Submission Events, Execution Events, Audit Events.
- **Position:** DOC04A Execution Pipeline, step 4 (Broker Interface).
- **Relationship with DOC04B:** DOC04B validates; DOC04C submits only after PASS. DOC04C never re-validates.
- **Relationship with DOC03D:** DOC04C reports submission results to DOC03D, causing state transitions (EXECUTING → EXECUTED / EXECUTING → FAILED).

---

# Inputs

| Input | Source | Purpose |
|---|---|---|
| **Validated Execution Request** | DOC04B (PASS) | The request to submit to the broker |
| **Validation Result Object (PASS)** | DOC04B | Confirms the request passed validation |
| **Trade State** | DOC03D | Confirms decision is in EXECUTING state |
| **Terminal Status** | Core Engine / MT5 terminal | Terminal connected, algo trading enabled |
| **Broker Interface** | DOC04A | The broker communication boundary |

## Input Rules
- Only PASS-validated requests are accepted (DOC04B).
- The Trade State must be EXECUTING (DOC03D).
- Terminal must be connected and algo trading enabled.
- All inputs are read-only; DOC04C never modifies them.

---

# Outputs

| Output | Consumer | Purpose |
|---|---|---|
| **Submission Result Object** | DOC04A, DOC03D | The result of the broker submission (ACCEPTED / REJECTED / TIMEOUT / ERROR) |
| **Submission Events** | Audit trail, Logger | Every submission attempt and its outcome |
| **Execution Events** | DOC04A | Execution lifecycle events |
| **Audit Events** | Audit trail, Logger | Full audit information per submission attempt |

---

# Responsibilities

| Responsibility | Description |
|---|---|
| **Submission Ownership** | DOC04C owns the submission workflow: request → broker → result. It does NOT own validation (DOC04B) or position management (DOC04B+). |
| **Submission Lifecycle** | Manages the submission lifecycle: request received → broker submission → broker response → result routing. |
| **Submission Flow** | Executes the submission pipeline (see below). |
| **Broker Communication** | Submits the order to the MT5 broker via the Broker Interface (DOC04A). |
| **Response Routing** | Routes the broker response to the Submission Result Object. |
| **Failure Routing** | Routes failures (rejection, timeout, error) to DOC04A and DOC03D as FAILED. |
| **Retry Philosophy** | Applies the bounded retry policy (1 retry for requotes only; no retries for rejections/timeouts/errors). |
| **Timeout Handling** | Manages submission timeout; queries broker for position status on timeout. |
| **Duplicate Prevention** | Ensures exactly-one-execution (no duplicate orders) under all conditions. |
| **Submission Audit** | Records every submission attempt with full audit trail. |

---

# Order Submission Pipeline

The official submission pipeline:

```
1. Validation PASS (from DOC04B)
        │
        ▼
2. Submission Request Creation
        │  Build Submission Request Object from Execution Request
        │  (direction, lot 0.01, SL, TP, magic number, slippage cap)
        ▼
3. Broker Interface Submission
        │  Submit order to MT5 broker (via DOC04A Broker Interface)
        │  Wait for broker response (with timeout)
        │  → If timeout: query broker for position status
        │  → If broker error: route ERROR
        │  → If rejected: route REJECTED
        │  → If accepted: proceed to step 4
        ▼
4. Broker Response Handling
        │  Parse broker response (return code, message, fill price, ticket)
        │  → If filled: create Submission Result (ACCEPTED)
        │  → If rejected: create Submission Result (REJECTED)
        │  → If timeout: query broker, then create Submission Result (TIMEOUT / ACCEPTED)
        │  → If error: create Submission Result (ERROR)
        ▼
5. Submission Result Object
        │  Create immutable Submission Result Object
        │  Record: fill price, ticket, latency, broker response
        ▼
6. Trade State Machine
        │  Route result to DOC03D
        │  State Machine transitions: EXECUTING → EXECUTED (accepted)
        │  or EXECUTING → FAILED (rejected/timeout/error)
        ▼
7. Audit Events
        │  Record full audit trail for every attempt
```

## Pipeline Properties
1. **Sequential:** each step completes before the next begins.
2. **Deterministic:** given the same inputs, the pipeline follows the same path.
3. **Short-circuiting:** any broker failure routes to Failure Routing; remaining steps are skipped.
4. **Auditable:** every step produces events for the audit trail.
5. **No validation:** DOC04C does NOT re-validate the request; it trusts DOC04B's PASS result.
6. **No position management:** DOC04C does NOT manage the position after submission; that is DOC04B+.

---

# Broker Response — Deterministic Handling

## Accepted
- The broker accepted the order and filled it.
- DOC04C creates a Submission Result Object with status = ACCEPTED.
- Records: fill price, ticket, actual SL/TP, latency.
- Routes to DOC03D → EXECUTING → EXECUTED.

## Rejected
- The broker rejected the order (invalid stops, insufficient margin, trading disabled).
- DOC04C creates a Submission Result Object with status = REJECTED.
- Records: failure reason, broker response code.
- Routes to DOC03D → EXECUTING → FAILED.
- **No retry:** rejection means invalid parameters; retrying with the same parameters would fail again.

## Timeout
- The broker did not respond within the timeout window.
- DOC04C queries the broker for order/position status.
  - If position exists → Submission Result = ACCEPTED (filled during timeout).
  - If no position → Submission Result = TIMEOUT.
- Routes to DOC03D → EXECUTING → EXECUTED (if accepted) or EXECUTING → FAILED (if timeout).
- **No retry:** timeout may have already filled; retrying risks a duplicate.

## Connection Lost
- The terminal lost connection to the broker during submission.
- DOC04C queries the broker for order/position status on reconnect.
  - If position exists → Submission Result = ACCEPTED.
  - If no position → Submission Result = ERROR.
- Routes to DOC03D → EXECUTING → EXECUTED (if accepted) or EXECUTING → FAILED (if error).
- **No retry:** connection loss may have already filled; retrying risks a duplicate.

## Unknown Response
- The broker returned an unrecognized response code.
- DOC04C queries the broker for order/position status.
  - If position exists → Submission Result = ACCEPTED.
  - If no position → Submission Result = ERROR.
- Routes to DOC03D → EXECUTING → EXECUTED (if accepted) or EXECUTING → FAILED (if error).
- **No retry:** unknown response may have already filled; retrying risks a duplicate.

## Duplicate Submission
- DOC04C detects that a submission for the same Decision ID already exists.
- DOC04C blocks the duplicate submission and creates a Submission Result with status = ERROR (duplicate prevented).
- Routes to DOC03D → EXECUTING → FAILED.
- **No retry:** duplicate prevention is fail-safe.

## Broker Error
- A broker/server error occurred during submission (e.g., server error, internal broker error).
- DOC04C queries the broker for order/position status.
  - If position exists → Submission Result = ACCEPTED.
  - If no position → Submission Result = ERROR.
- Routes to DOC03D → EXECUTING → EXECUTED (if accepted) or EXECUTING → FAILED (if error).
- **No retry:** broker error may have already filled; retrying risks a duplicate.

## Unexpected Result
- The broker returned a result that does not match any expected case (e.g., partial fill for 0.01 lot, which is rare per DOC00 Assumption §9).
- DOC04C treats partial fills as ACCEPTED (0.01 is minimum; partial fills at this size are negligible).
- Creates Submission Result = ACCEPTED.
- Routes to DOC03D → EXECUTING → EXECUTED.
- **No retry:** partial fill is treated as success.

---

# Submission Result Object

## Purpose
The Submission Result Object is the immutable record of what the broker did with the submission request. It is the final output of the Order Submission Engine and is routed to DOC04A and DOC03D.

## Creation
- Created at Pipeline Step 5 (after broker response handling).
- Built from the broker response (return code, fill price, ticket, latency).

## Ownership
- **Owner:** Order Submission Engine (DOC04C).
- **Consumers:** DOC04A (Execution Framework), DOC03D (Trade State Machine), Audit trail.

## Lifecycle
- **Created:** at Pipeline Step 5.
- **Consumed:** by DOC04A and DOC03D for state transitions.
- **Archived:** for audit (FIFO retention).

## Immutable Fields
All fields are immutable after creation:

| Field | Type | Description |
|---|---|---|
| **Submission ID** | Unique ID | Unique identifier for this submission attempt |
| **Execution ID** | Reference | Reference to the source Execution Request Object |
| **Decision ID** | Reference | Reference to the source Decision Output Object |
| **Status** | Enum | ACCEPTED / REJECTED / TIMEOUT / ERROR |
| **Fill Price** | Price | (If ACCEPTED) The actual fill price |
| **Ticket / Position ID** | Integer | (If ACCEPTED) The broker order/position ticket |
| **Actual Stop Loss** | Price | (If ACCEPTED) The SL set on the broker |
| **Actual Take Profit** | Price | (If ACCEPTED) The TP set on the broker |
| **Broker Response Code** | Integer | The MT5 return code |
| **Broker Response Message** | String | The broker response message |
| **Latency** | Integer | Time from submission to result (ms) |
| **Failure Reason** | String | (If not ACCEPTED) The reason for failure |
| **Creation Timestamp** | DateTime | When the result was created |

## Audit Fields
- Submission ID, Execution ID, Decision ID, creation timestamp, all result parameters, and the full broker response are recorded for audit.

## Expiration
- The Submission Result Object does not have its own expiration; it follows the Execution Request Object's lifetime (DOC04A: one M15 bar). If the decision expires before submission completes, the result is archived as EXPIRED.

## Historical Storage
- Archived Submission Result Objects are retained for audit (bounded FIFO retention).

---

# Retry Philosophy

## When Retry is Allowed
- **Requotes only:** 1 retry for requotes (within the slippage cap).
- **Rationale:** requotes are transient price movements; retrying within the slippage cap is safe.

## When Retry is Forbidden
- **Rejections:** no retry (invalid parameters; retrying with the same parameters would fail again).
- **Timeouts:** no retry (may have already filled; retrying risks a duplicate).
- **Broker errors:** no retry (may indicate a systemic issue; may have already filled).
- **Connection lost:** no retry (may have already filled; retrying risks a duplicate).
- **Unknown response:** no retry (may have already filled; retrying risks a duplicate).
- **Duplicate submission:** no retry (fail-safe).
- **Rationale:** unbounded retries risk duplicate orders. DOC00's "max 1 position" rule means duplicate prevention is paramount. Fail safe: if execution is uncertain, report TIMEOUT/ERROR and let the Recovery Interface (DOC04A) resolve it.

## How Duplicate Orders are Prevented
- **Exactly-one-execution:** at most one active Execution Request at any time (DOC00: max 1 position).
- **Duplicate detection:** DOC04C checks for existing submissions for the same Decision ID before submitting.
- **Fail-safe:** if a duplicate is detected, the submission is blocked and reported as ERROR.

## How Failed Submissions are Handled
- **Rejection:** Submission Result = REJECTED; routed to DOC03D → EXECUTING → FAILED.
- **Timeout:** Submission Result = TIMEOUT (or ACCEPTED if position exists); routed to DOC03D → EXECUTING → FAILED (or EXECUTED).
- **Broker error:** Submission Result = ERROR (or ACCEPTED if position exists); routed to DOC03D → EXECUTING → FAILED (or EXECUTED).
- **All failures:** full audit trail recorded; no automatic retry.

## How Timeout Differs from Rejection
- **Timeout:** the broker did not respond within the timeout window. The order may or may not have been filled. DOC04C queries the broker for position status to determine the actual outcome.
- **Rejection:** the broker explicitly rejected the order (invalid parameters). The order was NOT filled. No query needed.
- **Rationale:** timeout is uncertain (may have filled); rejection is certain (did not fill).

---

# Auditability

Every submission attempt must be recorded with the following audit fields:

| Field | Description |
|---|---|
| **Submission ID** | Unique identifier for the submission attempt |
| **Execution ID** | Reference to the source Execution Request Object |
| **Decision ID** | Reference to the source Decision Output Object |
| **Timestamp** | When the submission attempt occurred |
| **Broker Response** | The raw broker response (return code, message) |
| **Submission Status** | ACCEPTED / REJECTED / TIMEOUT / ERROR |
| **Latency** | Time from submission to result (ms) |
| **Failure Reason** | (If not ACCEPTED) Detailed reason for failure |
| **Fill Price** | (If ACCEPTED) The actual fill price |
| **Ticket** | (If ACCEPTED) The broker order/position ticket |
| **Retry Count** | Number of retries (0 or 1 for requotes) |
| **Request Snapshot** | Full Execution Request Object (all parameters) |
| **Result Snapshot** | Full Submission Result Object |
| **State Machine Transition** | The state transition triggered (e.g., EXECUTING → EXECUTED) |

## Audit Purpose
- **Reconstruction:** any submission can be fully reconstructed from the audit trail.
- **Debugging:** failures can be traced to specific broker responses and failure reasons.
- **Backtesting:** historical submissions can be replayed exactly.
- **Compliance:** all submission attempts are fully documented.

---

# Implementation Constraints

## Maximum CPU Cost
- **Per submission:** O(1) (a single broker call + result processing).
- **Per bar:** O(1) (at most one submission per bar; most bars have no submission).
- **Worst case:** O(1) + retry overhead (bounded: at most 1 retry for requotes).

## Maximum Memory Cost
- **Active:** O(1) (at most one active submission at any time).
- **Archived:** O(N) where N = retention cap (bounded, FIFO).

## Synchronization
- **Single-threaded:** the Order Submission Engine is single-threaded (no concurrent submissions).
- **Exactly-one-execution:** enforced by the duplicate prevention rule (at most one active Execution Request → at most one submission).
- **No concurrent order submission:** the pipeline is sequential.

## Submission Timeout
- **Timeout window:** a fixed, configured duration for broker response (e.g., a few seconds).
- **On timeout:** query broker for order/position status before declaring a result.
- **If query confirms fill:** ACCEPTED.
- **If query confirms no position:** TIMEOUT.
- **If query fails:** ERROR; verify on reconnect (Recovery Interface, DOC04A).

## Broker Communication Strategy
- **Single broker call:** submit order via DOC04A Broker Interface.
- **Wait for response:** block until response or timeout.
- **Parse response:** extract return code, fill price, ticket, message.
- **Route result:** create Submission Result Object and route to DOC04A/DOC03D.

## Scalability
- **Constant scaling:** performance is constant regardless of market conditions or bar count.
- **Bounded:** at most one active submission at any time (DOC00: max 1 position).
- **Future multi-symbol support:** scales linearly with number of active symbols, with one submission per symbol/request.

---

# Performance

## Worst Case
- **Submission + 1 retry (requote):** O(1) + broker latency (typically < 1 second).
- **Memory:** O(1) active + O(N) archived.

## Average Case
- **Single submission, no retry:** O(1) + broker latency (typically < 500 ms).
- **Memory:** O(1) active + O(N) archived.

## Complexity
- **Time complexity:** O(1) per submission (excluding broker latency, which is external).
- **Space complexity:** O(1) active + O(N) archived (N = retention cap).

## Scalability
- **Constant scaling:** performance is constant regardless of market conditions or bar count.
- **Bounded:** at most one active submission at any time (DOC00: max 1 position).

---

# Cross-Document Consistency

| Concern | How DOC04C respects it |
|---|---|
| DOC00 (strategy rules) | DOC04C defines **no trading rules**; it uses DOC00's constants (0.01 lot, max 1 position) as given values. It does not recalculate them. |
| DOC00_PATCH_001 (timeframes) | Submission is triggered by validated Execution Requests on the M15 timeframe. |
| DOC01 (architecture) | DOC04C implements the Broker Interface step (DOC04A Pipeline Step 4) and uses the Error Handling Module. |
| DOC02A–F (detection engines) | DOC04C has **no interaction** with detection engines; it receives only validated Execution Requests. |
| DOC03A (Trading Intelligence Blueprint) | DOC04C has no direct interaction with DOC03A. |
| DOC03B (Confluence Engine) | DOC04C has no direct interaction with DOC03B. |
| DOC03C (Entry Decision Engine) | DOC04C has no direct interaction with DOC03C; it consumes Execution Requests (which are derived from decisions). |
| DOC03D (Trade State Machine) | DOC04C receives validated Execution Requests from DOC03D (via DOC04A) and reports Submission Results back, causing state transitions (EXECUTING → EXECUTED / EXECUTING → FAILED). |
| DOC04A (Execution Framework) | DOC04C implements the Broker Interface step in DOC04A's pipeline; it consumes the Broker Interface defined in DOC04A. |
| DOC04B (Execution Validation Engine) | DOC04C consumes only PASS-validated Execution Requests from DOC04B; it never re-validates. |
| DOC01 (immutability) | Submission Result Objects are immutable after creation. |
| DOC01 (Error Handling) | Broker errors are classified and routed through the Error Handling strategy. |

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **No market analysis:** DOC04C **never** reads market structure, performs analysis, or evaluates conditions. It only submits validated requests. *(Pass)*
- **No BUY logic:** DOC04C does not create decisions; it submits validated Execution Requests from DOC04B. *(Pass)*
- **No SELL logic:** Same as above. *(Pass)*
- **No execution validation:** DOC04C does not validate requests; DOC04B does that. DOC04C only accepts PASS-validated requests. *(Pass)*
- **No position management:** DOC04C does not manage open positions (break-even, trailing, SL/TP modification). That is DOC04B+ (Trade Management). *(Pass)*
- **No trade management:** Same as above. *(Pass)*
- **No circular dependency:** DOC04C consumes from DOC04B (downstream) and reports back to DOC04A/DOC03D. It does not feed into DOC02 (Market Analysis) or DOC03 (Trading Intelligence) decision logic. The feedback to DOC03D is a result event, not a decision input. *(Pass)*
- **Consistency with DOC04A:** DOC04C implements the Broker Interface step in DOC04A's pipeline; it uses the Broker Interface defined in DOC04A. *(Pass)*
- **Consistency with DOC04B:** DOC04C consumes only PASS-validated Execution Requests from DOC04B; it never re-validates. *(Pass)*
- **Consistency with DOC03D:** DOC04C receives validated Execution Requests from DOC03D (via DOC04A) and reports Submission Results back, causing state transitions (EXECUTING → EXECUTED / EXECUTING → FAILED). *(Pass)*
- **Implementation feasibility using standard MQL5 APIs only:** All operations are standard MT5 order functions (OrderSend, OrderCheck, PositionSelect); O(1) complexity; bounded memory; single-threaded; persisted for recovery. *(Pass)*

**Scope boundaries respected:** No market analysis, no BUY/SELL logic, no execution validation, no position management, no trade management, no risk calculation. The Order Submission Engine bridges DOC04B (validation) and DOC04A (Broker Interface) only.

**Design Decision Record (DDR):** Documented why submission is separated from validation, why submission is separated from position management, and why Submission Result Objects are immutable.

**Outcome:** No blocking issues. DOC04C is internally consistent, deterministic, non-repainting, look-ahead-safe, circular-dependency-free, and fully conforms to DOC00–DOC04B.

---

# Final Notes

1. **Submission only.** This document specifies the Order Submission Engine and nothing else. No trading rules, no BUY/SELL logic, no validation, no position management, no market analysis.
2. **Isolated from validation.** DOC04C consumes only PASS-validated Execution Requests from DOC04B; it never re-validates.
3. **Isolated from position management.** DOC04C does not manage open positions; that is DOC04B+.
4. **Bounded retries.** At most 1 retry (requotes only); no retries for rejections/timeouts/errors (fail safe to prevent duplicates).
5. **Timeout handling.** On timeout, query broker for position status; do not assume fill or failure.
6. **Immutable objects.** Submission Result Objects are immutable after creation.
7. **Full audit trail.** Every submission attempt is fully reconstructable from the audit trail.
8. **Downstream consumers** (DOC04A, DOC03D) consume Submission Result Objects; they must not redefine the submission engine or mutate submission results.

This document is now the official specification for the Order Submission Engine.
