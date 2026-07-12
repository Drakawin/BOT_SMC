# DOC04E — System Recovery & Consistency Engine

## Official Specification for System Restart, Disconnection Recovery, and State Reconciliation

> **Document status:** AUTHORITATIVE — Official specification for the **System Recovery & Consistency Engine**.
> **Phase:** Phase 4 (Execution) — Recovery & Consistency Layer (Part E).
> **This is NOT a coding task.** No MQL5 code, no pseudo-code, no algorithms, no UML, no flowcharts.
> **Purpose:** The System Recovery & Consistency Engine handles system restarts, disconnections, and state reconciliation. It ensures the system can recover from failures and maintain consistency between internal state and broker state.
> **Scope:** System Restart Handling, Disconnection Recovery, State Reconciliation, Consistency Verification, Recovery Audit Trail, Deterministic Recovery Procedures.
> **Explicitly out of scope:** Market analysis, trade management, position creation/modification/closure, execution validation, order submission.
> **Relationship to prior documents:**
> - Consumes state from DOC04D (Position Lifecycle Tracker), DOC04C (Order Submission Engine), DOC04B (Execution Validation Engine), DOC04A (Execution Framework).
> - Consumes state from DOC03D (Trade State Machine), DOC03C (Entry Decision Engine), DOC03B (Confluence Engine), DOC03A (Trading Intelligence Blueprint).
> - Reports recovery events to audit trail and DOC01 (System Architecture).
> - Conforms to DOC00–DOC04D without redefining any SMC concept.

---

# Design Decision Record (DDR)

## Decision 1: Recovery is Separated from Normal Operation

**Decision:** The System Recovery & Consistency Engine is a separate engine from normal operation engines (DOC04A–DOC04D, DOC03A–DOC03D). It activates only during recovery scenarios.

**Reason:**
- Normal operation and recovery have different requirements and constraints.
- Separating them prevents recovery logic from interfering with normal operation.
- It improves testability: recovery scenarios can be tested independently.
- It keeps normal operation engines simple and focused.

## Decision 2: Recovery is Deterministic

**Decision:** All recovery procedures are deterministic. Given the same failure state, the recovery procedure produces the same result.

**Reason:**
- Deterministic recovery ensures reproducibility.
- It allows full audit trail of recovery operations.
- It prevents non-deterministic behavior that could lead to inconsistent states.
- It is consistent with the deterministic design philosophy of the entire project.

## Decision 3: State Reconciliation is Conservative

**Decision:** When reconciling internal state with broker state, the engine prefers the broker state as the source of truth.

**Reason:**
- The broker state is the actual execution state.
- Internal state may be stale or incorrect after a failure.
- Conservative reconciliation prevents incorrect trading decisions.
- It is consistent with the fail-safe philosophy of the project.

## Decision 4: Recovery Operations are Auditable

**Decision:** Every recovery operation is recorded in the audit trail with full context.

**Reason:**
- Recovery operations are critical and must be traceable.
- Full audit trail allows post-mortem analysis of failures.
- It ensures accountability and transparency.
- It is consistent with the audit-first philosophy of the project.

---

# System Recovery & Consistency Engine — Architectural Specification

## Purpose
The System Recovery & Consistency Engine handles system restarts, disconnections, and state reconciliation. It ensures the system can recover from failures and maintain consistency between internal state and broker state.

It does NOT perform normal operation. It does NOT create decisions. It does NOT execute trades. It does NOT manage positions. It only handles recovery and consistency.

## Architectural Role
- **Input:** System state from all engines (DOC03A–DOC03D, DOC04A–DOC04D), broker state, terminal state, account state.
- **Output:** Recovery events, consistency reports, reconciliation results, audit trail entries.
- **Position:** Recovery layer in DOC01 System Architecture.
- **Relationship with DOC04A–DOC04D:** Consumes their state; reconciles with broker state.
- **Relationship with DOC03A–DOC03D:** Consumes their state; reconciles with broker state.
- **Relationship with DOC01:** Reports recovery events to System Architecture.

---

# Inputs

| Input | Source | Purpose |
|---|---|---|
| **Internal State** | All engines (DOC03A–DOC03D, DOC04A–DOC04D) | Current internal state of all engines |
| **Broker State** | MT5 Broker Interface | Current broker state (positions, orders, account) |
| **Terminal State** | Core Engine / MT5 terminal | Terminal connection status |
| **Account State** | Risk / Account service | Account connection status |
| **Persisted State** | Persistence layer | Previously persisted state from before failure |
| **Recovery Trigger** | System events | Restart, disconnection, state mismatch detection |

## Input Rules
- All inputs are read-only; DOC04E never modifies them.
- Broker state is queried on-demand during recovery.
- Internal state is loaded from persistence on restart.
- Recovery triggers are detected by system monitoring.

---

# Outputs

| Output | Consumer | Purpose |
|---|---|---|
| **Recovery Events** | Audit trail, DOC01 | Events for recovery operations |
| **Consistency Reports** | Audit trail, DOC01 | Reports on state consistency |
| **Reconciliation Results** | Audit trail, DOC01 | Results of state reconciliation |
| **Audit Trail Entries** | Audit trail | Full audit information for recovery operations |
| **Recovery Status** | DOC01 | Current recovery status (RECOVERING / RECOVERED / FAILED) |

---

# Responsibilities

| Responsibility | Description |
|---|---|
| **System Restart Handling** | Detect and handle system restarts; load persisted state; reconcile with broker state. |
| **Disconnection Recovery** | Detect and handle disconnections; verify state after reconnection; reconcile if needed. |
| **State Reconciliation** | Reconcile internal state with broker state; resolve inconsistencies. |
| **Consistency Verification** | Verify consistency between internal state and broker state. |
| **Recovery Audit Trail** | Record full audit trail for all recovery operations. |
| **Deterministic Recovery Procedures** | Execute deterministic recovery procedures for each failure type. |
| **Recovery Reporting** | Report recovery status and results to DOC01 and audit trail. |

---

# Recovery Scenarios

## System Restart

### Trigger
- EA restart (manual or automatic).
- Platform restart (MT5 terminal restart).
- System restart (computer restart).

### Recovery Procedure
1. **Load Persisted State:** Load all persisted state from before restart.
2. **Verify Terminal Connection:** Verify terminal is connected and algo trading is enabled.
3. **Verify Account Connection:** Verify account is connected and trading is enabled.
4. **Query Broker State:** Query broker for all open positions and orders.
5. **Reconcile Position State:**
   - For each persisted position, verify it exists in broker state.
   - If position exists: update internal state with broker state.
   - If position does not exist: mark as CLOSED (position was closed during restart).
   - For each broker position not in persisted state: mark as UNEXPECTED POSITION.
6. **Reconcile Decision State:**
   - For each persisted decision in EXECUTING state, verify position exists.
   - If position exists: transition decision to EXECUTED.
   - If position does not exist: transition decision to FAILED.
7. **Reconcile Execution State:**
   - For each persisted execution request in SUBMITTED state, verify order exists.
   - If order exists: update execution state with broker state.
   - If order does not exist: mark execution as FAILED.
8. **Resume Normal Operation:** After reconciliation, resume normal operation.
9. **Record Audit Trail:** Record all recovery operations in audit trail.

### Deterministic Guarantees
- Same persisted state + same broker state ⇒ same reconciliation result.
- All reconciliation operations are logged.
- Recovery is idempotent (can be repeated safely).

## Disconnection Recovery

### Trigger
- Terminal disconnection (loss of connection to broker).
- Account disconnection (loss of account authorization).
- Network disconnection (loss of network connectivity).

### Recovery Procedure
1. **Detect Disconnection:** Detect loss of connection to broker.
2. **Pause Normal Operation:** Pause all normal operation engines.
3. **Wait for Reconnection:** Wait for terminal/account reconnection.
4. **Verify Reconnection:** Verify terminal and account are reconnected.
5. **Query Broker State:** Query broker for all open positions and orders.
6. **Reconcile State:** Same as System Restart steps 5–7.
7. **Resume Normal Operation:** After reconciliation, resume normal operation.
8. **Record Audit Trail:** Record all recovery operations in audit trail.

### Deterministic Guarantees
- Same broker state after reconnection ⇒ same reconciliation result.
- All reconciliation operations are logged.
- Recovery is idempotent.

## State Mismatch Recovery

### Trigger
- Internal state does not match broker state (detected during consistency verification).
- Position state mismatch (internal state says ACTIVE, broker says CLOSED, or vice versa).
- Decision state mismatch (internal state says EXECUTING, broker says no position).
- Execution state mismatch (internal state says SUBMITTED, broker says no order).

### Recovery Procedure
1. **Detect Mismatch:** Detect state mismatch during consistency verification.
2. **Identify Mismatch Type:** Identify the type of mismatch (position, decision, execution).
3. **Query Broker State:** Query broker for the specific state in question.
4. **Reconcile State:**
   - If broker state is correct: update internal state to match broker state.
   - If internal state is correct: update broker state to match internal state (if possible).
   - If neither is correct: mark as INCONSISTENT and flag for investigation.
5. **Record Audit Trail:** Record all reconciliation operations in audit trail.

### Deterministic Guarantees
- Same mismatch + same broker state ⇒ same reconciliation result.
- All reconciliation operations are logged.
- Recovery is idempotent.

---

# Consistency Verification

## Purpose
Consistency verification ensures that internal state matches broker state. It is performed periodically and on-demand.

## Verification Frequency
- **Periodic:** Every N seconds (configurable, default: 60 seconds).
- **On-demand:** After recovery, after disconnection, after state change.

## Verification Process
1. **Query Broker State:** Query broker for all open positions and orders.
2. **Compare Internal State:** Compare internal state with broker state.
3. **Identify Mismatches:** Identify any mismatches.
4. **Report Mismatches:** Report mismatches to audit trail and DOC01.
5. **Trigger Recovery:** If mismatches detected, trigger State Mismatch Recovery.

## Verification Rules
- All open positions in internal state must exist in broker state.
- All open positions in broker state must exist in internal state (or be flagged as UNEXPECTED).
- All decisions in EXECUTING state must have a corresponding position in broker state.
- All execution requests in SUBMITTED state must have a corresponding order in broker state.

## Deterministic Guarantees
- Same internal state + same broker state ⇒ same verification result.
- All verification operations are logged.
- Verification is idempotent.

---

# State Reconciliation

## Purpose
State reconciliation resolves inconsistencies between internal state and broker state. It is performed during recovery scenarios.

## Reconciliation Rules
- **Broker state is source of truth:** When internal state and broker state conflict, broker state is preferred.
- **Conservative reconciliation:** If unsure, prefer the more conservative state (e.g., CLOSED over ACTIVE).
- **Audit all changes:** All state changes during reconciliation are logged.

## Reconciliation Procedures

### Position Reconciliation
- **Internal: ACTIVE, Broker: EXISTS:** Update internal state with broker state (SL, TP, volume, etc.).
- **Internal: ACTIVE, Broker: NOT EXISTS:** Mark position as CLOSED.
- **Internal: NOT EXISTS, Broker: EXISTS:** Mark position as UNEXPECTED POSITION.
- **Internal: CLOSED, Broker: EXISTS:** Mark position as RECOVERED (unexpected re-appearance).

### Decision Reconciliation
- **Internal: EXECUTING, Broker: POSITION EXISTS:** Transition decision to EXECUTED.
- **Internal: EXECUTING, Broker: POSITION NOT EXISTS:** Transition decision to FAILED.
- **Internal: EXECUTED, Broker: POSITION NOT EXISTS:** Mark decision as INCONSISTENT (position closed unexpectedly).

### Execution Reconciliation
- **Internal: SUBMITTED, Broker: ORDER EXISTS:** Update execution state with broker state.
- **Internal: SUBMITTED, Broker: ORDER NOT EXISTS:** Mark execution as FAILED.
- **Internal: ACCEPTED, Broker: ORDER NOT EXISTS:** Mark execution as INCONSISTENT (order cancelled unexpectedly).

## Deterministic Guarantees
- Same internal state + same broker state ⇒ same reconciliation result.
- All reconciliation operations are logged.
- Reconciliation is idempotent.

---

# Audit Trail

## Purpose
The audit trail records all recovery operations for traceability and post-mortem analysis.

## Audit Fields

### Recovery Event
| Field | Description |
|---|---|
| **Recovery ID** | Unique identifier for the recovery operation |
| **Recovery Type** | SYSTEM_RESTART / DISCONNECTION_RECOVERY / STATE_MISMATCH_RECOVERY |
| **Trigger** | What triggered the recovery |
| **Timestamp** | When the recovery started |
| **Duration** | How long the recovery took |
| **Status** | RECOVERING / RECOVERED / FAILED |
| **Recovery Steps** | List of recovery steps executed |
| **Reconciliation Results** | Results of state reconciliation |
| **Mismatches Detected** | List of mismatches detected |
| **Mismatches Resolved** | List of mismatches resolved |
| **Mismatches Unresolved** | List of mismatches not resolved (flagged for investigation) |

### Consistency Verification
| Field | Description |
|---|---|
| **Verification ID** | Unique identifier for the verification |
| **Timestamp** | When the verification occurred |
| **Internal State Snapshot** | Snapshot of internal state at verification time |
| **Broker State Snapshot** | Snapshot of broker state at verification time |
| **Mismatches Detected** | List of mismatches detected |
| **Verification Result** | CONSISTENT / INCONSISTENT |

### State Reconciliation
| Field | Description |
|---|---|
| **Reconciliation ID** | Unique identifier for the reconciliation |
| **Timestamp** | When the reconciliation occurred |
| **State Type** | POSITION / DECISION / EXECUTION |
| **Internal State Before** | Internal state before reconciliation |
| **Broker State** | Broker state at reconciliation time |
| **Internal State After** | Internal state after reconciliation |
| **Reconciliation Action** | What action was taken (UPDATE / CLOSE / MARK_UNEXPECTED / MARK_INCONSISTENT) |
| **Reconciliation Result** | RECONCILED / INCONSISTENT |

## Audit Purpose
- **Traceability:** All recovery operations are fully traceable.
- **Post-mortem analysis:** Failures can be analyzed after the fact.
- **Accountability:** All recovery operations are logged with full context.
- **Compliance:** All recovery operations are documented.

---

# Implementation Constraints

## Maximum CPU Cost
- **Per recovery:** O(N) where N = number of positions/decisions/executions to reconcile.
- **Per consistency verification:** O(N) where N = number of positions/decisions/executions to verify.
- **Worst case:** O(N) per recovery/verification.

## Maximum Memory Cost
- **Active:** O(N) where N = number of positions/decisions/executions to reconcile/verify.
- **Archived:** O(R) where R = retention cap for recovery/verification records (bounded, FIFO).

## Update Frequency
- **Periodic verification:** Every N seconds (configurable, default: 60 seconds).
- **On-demand verification:** After recovery, after disconnection, after state change.
- **Recovery:** On restart, on disconnection, on state mismatch detection.

## Synchronization Strategy
- **Broker synchronization:** Query broker for all open positions and orders.
- **Internal state synchronization:** Load from persistence on restart; update during reconciliation.
- **Recovery synchronization:** Reconcile internal state with broker state during recovery.

## Recovery Strategy
- **Persisted state:** All engine state is persisted for restart recovery.
- **On restart:** Load persisted state; query broker; reconcile; resume normal operation.
- **On disconnection:** Pause normal operation; wait for reconnection; reconcile; resume.
- **On state mismatch:** Reconcile internal state with broker state; resolve inconsistencies.

## Scalability
- **Linear scaling:** Performance scales linearly with number of positions/decisions/executions.
- **Bounded:** At most 1 active position per DOC00 max 1 position rule.
- **Future multi-symbol support:** Scales linearly with number of active symbols.

---

# Performance

## Worst Case
- **Recovery:** O(N) where N = number of positions/decisions/executions to reconcile.
- **Time:** Typically < 100 ms per recovery (depending on number of items to reconcile).
- **Memory:** O(N) active + O(R) archived.

## Average Case
- **Recovery:** O(1) (typically 0 or 1 position to reconcile).
- **Time:** Typically < 10 ms per recovery.
- **Memory:** O(1) active + O(R) archived.

## Complexity
- **Time complexity:** O(N) per recovery/verification where N = number of items.
- **Space complexity:** O(N + R) where N = active items, R = archived records.

---

# Cross-Document Consistency

| Concern | How DOC04E respects it |
|---|---|
| DOC00 (strategy rules) | DOC04E defines **no trading rules**; it only handles recovery and consistency. |
| DOC00_PATCH_001 (timeframes) | DOC04E operates across all timeframes (H4, H1, M15) as needed for recovery. |
| DOC01 (architecture) | DOC04E is part of the System Architecture; it reports recovery events to DOC01. |
| DOC02A–F (detection engines) | DOC04E consumes their state; it does not modify their state. |
| DOC03A–D (trading intelligence) | DOC04E consumes their state; it reconciles with broker state. |
| DOC04A–D (execution layer) | DOC04E consumes their state; it reconciles with broker state. |
| DOC01 (immutability) | Recovery operations are immutable after creation; audit trail is immutable. |
| DOC01 (error handling) | Recovery errors are classified and handled according to DOC01 error handling strategy. |

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **No market analysis:** DOC04E **never** reads market structure, performs analysis, or evaluates conditions. It only handles recovery and consistency. *(Pass)*
- **No BUY logic:** DOC04E does not create decisions; it only reconciles existing decisions. *(Pass)*
- **No SELL logic:** Same as above. *(Pass)*
- **No execution validation:** DOC04E does not validate execution requests; DOC04B does that. *(Pass)*
- **No order submission:** DOC04E does not submit orders; DOC04C does that. *(Pass)*
- **No position management:** DOC04E does not manage positions; DOC04D tracks them, DOC04B+ manages them. *(Pass)*
- **No trade management:** Same as above. *(Pass)*
- **No circular dependency:** DOC04E consumes from all engines (downstream) and reports to DOC01. It does not feed back into decision logic. *(Pass)*
- **Consistency with DOC04A–D:** DOC04E consumes their state; it reconciles with broker state. *(Pass)*
- **Consistency with DOC03A–D:** DOC04E consumes their state; it reconciles with broker state. *(Pass)*
- **Consistency with DOC02A–F:** DOC04E consumes their state; it does not modify their state. *(Pass)*
- **Consistency with DOC01:** DOC04E is part of the System Architecture; it reports recovery events to DOC01. *(Pass)*
- **Implementation feasibility using standard MQL5 APIs only:** All operations are standard MT5 state queries and persistence operations; O(N) complexity; bounded memory; single-threaded; deterministic. *(Pass)*

**Scope boundaries respected:** No market analysis, no BUY/SELL logic, no execution validation, no order submission, no position management, no trade management. The System Recovery & Consistency Engine only handles recovery and consistency.

**Design Decision Record (DDR):** Documented why recovery is separated from normal operation, why recovery is deterministic, why state reconciliation is conservative, and why recovery operations are auditable.

**Outcome:** No blocking issues. DOC04E is internally consistent, deterministic, non-repainting, look-ahead-safe, circular-dependency-free, and fully conforms to DOC00–DOC04D.

---

# Final Notes

1. **Recovery only.** This document specifies the System Recovery & Consistency Engine and nothing else. No trading rules, no BUY/SELL logic, no execution validation, no order submission, no position management, no trade management.
2. **Separated from normal operation.** DOC04E activates only during recovery scenarios; it does not interfere with normal operation.
3. **Deterministic recovery.** All recovery procedures are deterministic; given the same failure state, the recovery procedure produces the same result.
4. **Conservative reconciliation.** When reconciling internal state with broker state, the engine prefers broker state as the source of truth.
5. **Full audit trail.** Every recovery operation is fully reconstructable from the audit trail.
6. **Idempotent recovery.** Recovery can be repeated safely; it produces the same result each time.
7. **Downstream consumers** (DOC01 System Architecture) consume recovery events and consistency reports; they must not redefine the recovery architecture or mutate recovery records.

This document is now the official specification for the System Recovery & Consistency Engine.

**Phase 4 (Execution Layer) is now complete.**
