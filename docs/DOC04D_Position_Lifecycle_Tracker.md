# DOC04D — Position Lifecycle Tracker

## Official Specification for Passive Position Observation

> **Document status:** AUTHORITATIVE — Official specification for the **Position Lifecycle Tracker**.
> **Phase:** Phase 4 (Execution) — Position Tracking Layer (Part D).
> **This is NOT a coding task.** No MQL5 code, no pseudo-code, no algorithms, no UML, no flowcharts.
> **Purpose:** The Position Lifecycle Tracker observes and records the complete lifecycle of broker positions. It is a passive observer that maintains an accurate representation of broker position state.
> **Scope:** Position Detection, Identification, Snapshot Creation, State Tracking, Event Generation, Synchronization, Broker Monitoring, Recovery Support, Audit Support.
> **Explicitly out of scope:** Position creation, modification, closure, market analysis, trade management (break-even, trailing, SL/TP modification), risk calculation.
> **Relationship to prior documents:**
> - Observes positions created by DOC04C (Order Submission Engine).
> - Reports position state to DOC04A (Execution Framework) and DOC03D (Trade State Machine).
> - Provides position snapshots to DOC04B+ (Trade Management) for management decisions.
> - Conforms to DOC00–DOC04C without redefining any SMC concept.

---

# Design Decision Record (DDR)

## Decision 1: Position Tracking is Separated from Position Management

**Decision:** The Position Lifecycle Tracker is a separate engine from Trade Management (DOC04B+). DOC04D observes; DOC04B+ manages.

**Reason:**
- Observation is passive; management is active.
- Separating them prevents the observer from making management decisions (break-even, trailing, closure).
- It improves auditability: the observer records what happened; the manager decides what to do.
- It keeps DOC04D single-purpose: observe and report.

## Decision 2: Position Snapshots are Immutable

**Decision:** The Position Snapshot Object is immutable after creation.

**Reason:**
- Immutability guarantees auditability (the exact position state at a point in time is preserved).
- It prevents mid-flight modification of position records.
- It ensures reproducibility in backtests.
- It is consistent with DOC04A/DOC04C immutability principle.

## Decision 3: Position Lifecycle is Event-Driven

**Decision:** The Position Lifecycle Tracker uses an event-driven model to track position state changes.

**Reason:**
- Event-driven tracking is deterministic and auditable.
- Each state change generates an immutable event record.
- It allows full reconstruction of position history.
- It is consistent with DOC03D event-driven state machine.

---

# Position Lifecycle Tracker — Architectural Specification

## Purpose
The Position Lifecycle Tracker observes broker positions and maintains an accurate, immutable record of their lifecycle from creation to closure.

It does NOT create positions. It does NOT modify positions. It does NOT close positions. It does NOT perform market analysis. It does NOT manage trades.

## Architectural Role
- **Input:** Submission Result Objects (from DOC04C), Broker Position Information, Trade State (from DOC03D), Terminal Status, Account Status.
- **Output:** Position Snapshot Objects, Position Events, Lifecycle Events, Audit Events, Position Status.
- **Position:** Passive observer in DOC04A execution layer.
- **Relationship with DOC04C:** DOC04C creates positions; DOC04D observes them after creation.
- **Relationship with DOC04B+ (Trade Management):** DOC04D provides position snapshots to DOC04B+ for management decisions; DOC04B+ does not modify DOC04D records.
- **Relationship with DOC03D:** DOC04D reports position state to DOC03D for lifecycle management.

---

# Inputs

| Input | Source | Purpose |
|---|---|---|
| **Submission Result Object** | DOC04C | Confirms a position was created (ACCEPTED status) |
| **Trade State** | DOC03D | Confirms decision is in EXECUTED state |
| **Broker Position Information** | MT5 Broker Interface | Current position state (ticket, volume, entry price, SL, TP, etc.) |
| **Terminal Status** | Core Engine / MT5 terminal | Terminal connected, algo trading enabled |
| **Account Status** | Risk / Account service | Account connected, trading enabled |

## Input Rules
- All inputs are read-only; DOC04D never modifies them.
- Broker position information is queried periodically or on-demand.
- Terminal and account status are checked before each synchronization.

---

# Outputs

| Output | Consumer | Purpose |
|---|---|---|
| **Position Snapshot Object** | DOC04B+ (Trade Management), Audit trail | Immutable record of position state at a point in time |
| **Position Events** | DOC04A, DOC03D, Audit trail | Events for position lifecycle changes |
| **Lifecycle Events** | DOC03D | Position lifecycle state transitions |
| **Audit Events** | Audit trail, Logger | Full audit information per position event |
| **Position Status** | DOC04A, DOC03D | Current position state (ACTIVE / CLOSED / MISSING / UNKNOWN) |

---

# Responsibilities

| Responsibility | Description |
|---|---|
| **Position Detection** | Detect when a new position appears in the broker account. |
| **Position Identification** | Match detected positions to Submission Result Objects (via ticket, magic number, decision ID). |
| **Position Snapshot Creation** | Create immutable Position Snapshot Objects for each detected position. |
| **Position State Tracking** | Track position state changes (ACTIVE → MODIFIED → CLOSED). |
| **Position Event Generation** | Generate immutable Position Events for each state change. |
| **Position Synchronization** | Synchronize position state with broker on each check. |
| **Broker State Monitoring** | Monitor broker connection and account status. |
| **Recovery Support** | Support recovery after terminal/platform restart. |
| **Audit Support** | Record full audit trail for all position events. |

---

# Position Lifecycle

The official position lifecycle states:

## Position Created
- **Trigger:** DOC04C reports ACCEPTED submission result.
- **Action:** DOC04D begins monitoring for the position.
- **State:** CREATED (awaiting confirmation).

## Position Confirmed
- **Trigger:** Broker position information matches the Submission Result Object (ticket, magic number, decision ID).
- **Action:** DOC04D creates the first Position Snapshot Object.
- **State:** CONFIRMED (position exists and is tracked).

## Position Active
- **Trigger:** Position is open and no modifications have occurred.
- **Action:** DOC04D continues monitoring.
- **State:** ACTIVE (position is open and stable).

## Position Modified
- **Trigger:** Position SL, TP, or volume changes (detected via broker position information).
- **Action:** DOC04D creates a new Position Snapshot Object reflecting the modification.
- **State:** MODIFIED (position has been modified by DOC04B+ or broker).

## Position Closed
- **Trigger:** Position no longer exists in broker account (closed by SL/TP, manual closure, or broker).
- **Action:** DOC04D creates a final Position Snapshot Object with closure details.
- **State:** CLOSED (position is closed; lifecycle complete).

## Position Missing
- **Trigger:** Position was CONFIRMED/ACTIVE but is no longer found in broker account (unexpected disappearance).
- **Action:** DOC04D reports MISSING state; queries broker for closure details.
- **State:** MISSING (position disappeared unexpectedly; requires investigation).

## Position Recovered
- **Trigger:** A MISSING position is found again (e.g., after terminal restart).
- **Action:** DOC04D resumes tracking; creates a new Position Snapshot Object.
- **State:** RECOVERED (position is back under tracking).

## Unknown Position State
- **Trigger:** Position state cannot be determined (broker connection lost, data inconsistent).
- **Action:** DOC04D reports UNKNOWN state; waits for broker reconnection.
- **State:** UNKNOWN (state cannot be determined; requires investigation).

---

# Position Snapshot Object

## Purpose
The Position Snapshot Object is the immutable record of a position's state at a specific point in time. It is created whenever a position state change is detected.

## Creation
- Created at position CONFIRMED (first snapshot).
- Created at each MODIFIED event (new snapshot reflecting modification).
- Created at CLOSED event (final snapshot with closure details).
- Created at RECOVERED event (new snapshot after recovery).

## Ownership
- **Owner:** Position Lifecycle Tracker (DOC04D).
- **Consumers:** DOC04B+ (Trade Management), Audit trail, DOC04A, DOC03D.

## Lifecycle
- **Created:** on position state change detection.
- **Consumed:** by DOC04B+ for management decisions.
- **Archived:** for audit (FIFO retention).

## Immutable Fields
All fields are immutable after creation:

| Field | Type | Description |
|---|---|---|
| **Snapshot ID** | Unique ID | Unique identifier for this snapshot |
| **Position ID** | Reference | Reference to the position (ticket + magic number) |
| **Ticket** | Integer | Broker position ticket |
| **Magic Number** | Integer | EA magic number |
| **Execution ID** | Reference | Reference to the source Execution Request Object |
| **Decision ID** | Reference | Reference to the source Decision Output Object |
| **Symbol** | String | Trading symbol (XAUUSD) |
| **Direction** | Enum | BUY / SELL |
| **Volume** | Decimal | Position volume (lot size) |
| **Entry Price** | Price | Position entry price |
| **Stop Loss** | Price | Current stop loss |
| **Take Profit** | Price | Current take profit |
| **Open Time** | DateTime | Position open time |
| **Snapshot Time** | DateTime | When this snapshot was created |
| **Position State** | Enum | CONFIRMED / ACTIVE / MODIFIED / CLOSED / RECOVERED |
| **Closure Price** | Price | (If CLOSED) Closure price |
| **Closure Time** | DateTime | (If CLOSED) Closure time |
| **Closure Reason** | String | (If CLOSED) SL / TP / MANUAL / BROKER / UNKNOWN |
| **Profit** | Decimal | Current or final profit |
| **Swap** | Decimal | Current or final swap |
| **Commission** | Decimal | Current or final commission |

## Historical Storage
- Archived Position Snapshot Objects are retained for audit (bounded FIFO retention).
- Each position may have multiple snapshots (one per state change).

## Audit Fields
- Snapshot ID, Position ID, Ticket, Execution ID, Decision ID, snapshot time, all position parameters, and the full broker position state are recorded for audit.

## Synchronization
- Position Snapshots are synchronized with broker position information on each check.
- If broker data differs from the last snapshot, a new snapshot is created.

---

# Position Events

The official position events:

## Position Opened
- **Trigger:** Position CONFIRMED (first snapshot created).
- **Event Data:** Snapshot ID, Position ID, Ticket, Execution ID, Decision ID, timestamp, volume, entry price, SL, TP.
- **Action:** Report to DOC04A, DOC03D, audit trail.

## Position Updated
- **Trigger:** Position MODIFIED (new snapshot created due to SL/TP/volume change).
- **Event Data:** Snapshot ID, Position ID, Ticket, timestamp, new SL, new TP, new volume, previous snapshot ID.
- **Action:** Report to DOC04A, DOC03D, audit trail.

## Position Closed
- **Trigger:** Position CLOSED (final snapshot created).
- **Event Data:** Snapshot ID, Position ID, Ticket, timestamp, closure price, closure time, closure reason, final profit/swap/commission.
- **Action:** Report to DOC04A, DOC03D, audit trail.

## Position Lost
- **Trigger:** Position MISSING (position disappeared unexpectedly).
- **Event Data:** Position ID, Ticket, timestamp, last known snapshot ID, reason (if known).
- **Action:** Report to DOC04A, DOC03D, audit trail; flag for investigation.

## Position Recovered
- **Trigger:** Position RECOVERED (missing position found again).
- **Event Data:** Snapshot ID, Position ID, Ticket, timestamp, recovery snapshot ID, last known snapshot ID.
- **Action:** Report to DOC04A, DOC03D, audit trail.

## Unexpected Position
- **Trigger:** Position detected that does not match any Submission Result Object (no matching ticket, magic number, or decision ID).
- **Event Data:** Position ID, Ticket, timestamp, symbol, direction, volume, entry price, SL, TP.
- **Action:** Report to DOC04A, DOC03D, audit trail; flag for investigation (may be manual trade or system error).

## Duplicate Position
- **Trigger:** Multiple positions detected with the same Decision ID (violates DOC00 max 1 position rule).
- **Event Data:** Position IDs, Tickets, timestamp, Decision ID.
- **Action:** Report to DOC04A, DOC03D, audit trail; flag for investigation (critical error).

---

# Position Synchronization

## Broker Synchronization
- **Frequency:** On each check cycle (configurable, e.g., every tick or every N seconds).
- **Process:**
  1. Query broker for all open positions.
  2. Match positions to tracked positions (via ticket + magic number).
  3. Detect new positions (not previously tracked).
  4. Detect closed positions (previously tracked, no longer in broker).
  5. Detect modified positions (SL/TP/volume changed).
  6. Create Position Snapshot Objects for each detected change.
  7. Generate Position Events for each change.

## Terminal Synchronization
- **Frequency:** On terminal restart or reconnection.
- **Process:**
  1. Query broker for all open positions.
  2. Match positions to persisted position records (via ticket + magic number).
  3. Detect positions that were tracked before restart.
  4. Resume tracking for matched positions.
  5. Report MISSING for positions that were tracked but not found.
  6. Report Unexpected Position for positions that were not tracked before restart.

## Recovery Synchronization
- **Frequency:** On recovery after terminal/platform restart.
- **Process:**
  1. Load persisted position records.
  2. Query broker for all open positions.
  3. Match broker positions to persisted records.
  4. Resume tracking for matched positions.
  5. Report MISSING for positions not found.
  6. Report Unexpected Position for positions not in persisted records.

## Restart Synchronization
- **Frequency:** On EA restart.
- **Process:**
  1. Load persisted position records and snapshots.
  2. Query broker for all open positions.
  3. Match broker positions to persisted records.
  4. Resume tracking for matched positions.
  5. Report MISSING for positions not found.
  6. Report Unexpected Position for positions not in persisted records.

## Consistency Verification
- **Frequency:** On each synchronization.
- **Process:**
  1. Verify that all tracked positions exist in broker account.
  2. Verify that all broker positions are tracked (or flagged as Unexpected).
  3. Verify that position parameters match last snapshot (or flag as MODIFIED).
  4. Report inconsistencies via Position Events.

---

# Auditability

Every position event must be recorded with the following audit fields:

| Field | Description |
|---|---|
| **Position ID** | Unique identifier for the position (ticket + magic number) |
| **Ticket** | Broker position ticket |
| **Execution ID** | Reference to the source Execution Request Object |
| **Decision ID** | Reference to the source Decision Output Object |
| **Timestamp** | When the event occurred |
| **Position State** | Current position state (CONFIRMED / ACTIVE / MODIFIED / CLOSED / RECOVERED / MISSING / UNKNOWN) |
| **Volume** | Position volume (lot size) |
| **Entry Price** | Position entry price |
| **Stop Loss** | Current stop loss |
| **Take Profit** | Current take profit |
| **Broker Status** | Broker connection status at event time |
| **Snapshot ID** | Reference to the Position Snapshot Object (if applicable) |
| **Event Type** | OPENED / UPDATED / CLOSED / LOST / RECOVERED / UNEXPECTED / DUPLICATE |
| **Event Data** | Full event data (varies by event type) |

## Audit Purpose
- **Reconstruction:** any position lifecycle can be fully reconstructed from the audit trail.
- **Debugging:** position issues can be traced to specific events and broker states.
- **Backtesting:** historical position lifecycles can be replayed exactly.
- **Compliance:** all position events are fully documented.

---

# Implementation Constraints

## Maximum CPU Cost
- **Per synchronization:** O(P) where P = number of open positions (typically 0 or 1 per DOC00 max 1 position rule).
- **Per check cycle:** O(P) (query broker, match positions, detect changes).
- **Worst case:** O(P) per cycle.

## Maximum Memory Cost
- **Active:** O(P) (at most P positions tracked; typically 1 per DOC00).
- **Archived:** O(N) where N = retention cap (bounded, FIFO).
- **Snapshots:** O(S) where S = total snapshots across all positions (bounded by retention).

## Update Frequency
- **Synchronization:** configurable (e.g., every tick, every N seconds, every bar close).
- **Snapshot creation:** on each detected state change.
- **Event generation:** on each detected state change.

## Synchronization Strategy
- **Broker synchronization:** query broker for all open positions; match to tracked positions; detect changes.
- **Terminal synchronization:** on restart/reconnection, load persisted records and match to broker positions.
- **Recovery synchronization:** on recovery, load persisted records and match to broker positions.
- **Restart synchronization:** on EA restart, load persisted records and match to broker positions.

## Recovery Strategy
- **Persisted state:** position records and snapshots are persisted for restart recovery.
- **On restart:** load persisted records; query broker; match positions; resume tracking.
- **Missing positions:** report MISSING for positions not found in broker.
- **Unexpected positions:** report Unexpected Position for positions not in persisted records.

## Scalability
- **Constant scaling:** performance scales linearly with number of open positions (typically 1 per DOC00).
- **Bounded:** at most 1 active position per DOC00 max 1 position rule.
- **Future multi-symbol support:** scales linearly with number of active symbols.

---

# Performance

## Worst Case
- **Synchronization:** O(P) where P = number of open positions (typically 1).
- **Time:** typically < 10 ms per synchronization (broker query + matching).
- **Memory:** O(P) active + O(N) archived.

## Average Case
- **Synchronization:** O(1) (typically 0 or 1 position).
- **Time:** typically < 5 ms per synchronization.
- **Memory:** O(1) active + O(N) archived.

## Complexity
- **Time complexity:** O(P) per synchronization where P = number of positions (typically 1).
- **Space complexity:** O(P + N) where P = active positions, N = archived records.

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **No market analysis:** DOC04D **never** reads market structure, performs analysis, or evaluates conditions. It only observes broker positions. *(Pass)*
- **No BUY logic:** DOC04D does not create decisions; it observes positions created by DOC04C. *(Pass)*
- **No SELL logic:** Same as above. *(Pass)*
- **No position modification:** DOC04D does not modify positions; it only observes and records. *(Pass)*
- **No trailing stop:** DOC04D does not manage positions; that is DOC04B+. *(Pass)*
- **No break-even:** Same as above. *(Pass)*
- **No risk management:** DOC04D does not calculate or manage risk; it only observes position state. *(Pass)*
- **No execution logic:** DOC04D does not execute orders; it only observes execution results from DOC04C. *(Pass)*
- **No circular dependency:** DOC04D consumes from DOC04C (downstream) and reports to DOC04A/DOC03D. It does not feed into DOC02 (Market Analysis) or DOC03 (Trading Intelligence) decision logic. *(Pass)*
- **Consistency with DOC04A:** DOC04D is part of the Execution Framework; it observes positions created by DOC04C and reports to DOC04A. *(Pass)*
- **Consistency with DOC04B:** DOC04D provides position snapshots to DOC04B+ for management decisions; DOC04B+ does not modify DOC04D records. *(Pass)*
- **Consistency with DOC04C:** DOC04D observes positions created by DOC04C; it never modifies them. *(Pass)*
- **Consistency with DOC03D:** DOC04D reports position state to DOC03D for lifecycle management. *(Pass)*
- **Implementation feasibility using standard MQL5 APIs only:** All operations are standard MT5 position queries (PositionSelect, PositionGetTicket, PositionGetDouble, etc.); O(P) complexity; bounded memory; single-threaded; persisted for recovery. *(Pass)*

**Scope boundaries respected:** No market analysis, no BUY/SELL logic, no position modification, no trailing stop, no break-even, no risk management, no execution logic. The Position Lifecycle Tracker is a passive observer only.

**Design Decision Record (DDR):** Documented why position tracking is separated from position management, why Position Snapshots are immutable, and why the position lifecycle is event-driven.

**Outcome:** No blocking issues. DOC04D is internally consistent, deterministic, non-repainting, look-ahead-safe, circular-dependency-free, and fully conforms to DOC00–DOC04C.

---

# Final Notes

1. **Observation only.** This document specifies the Position Lifecycle Tracker and nothing else. No trading rules, no BUY/SELL logic, no position modification, no trade management, no market analysis.
2. **Isolated from management.** DOC04D observes positions; DOC04B+ manages them. The observer never modifies positions.
3. **Immutable snapshots.** Position Snapshot Objects are immutable after creation, guaranteeing auditability and reproducibility.
4. **Event-driven lifecycle.** Each position state change generates an immutable event record, allowing full reconstruction of position history.
5. **Passive observer.** DOC04D never creates, modifies, or closes positions; it only observes and records.
6. **Full audit trail.** Every position event is fully reconstructable from the audit trail.
7. **Downstream consumers** (DOC04B+ Trade Management, DOC04A Execution Framework, DOC03D Trade State Machine) consume position snapshots and events; they must not redefine the position tracking architecture or mutate position records.

This document is now the official specification for the Position Lifecycle Tracker.
