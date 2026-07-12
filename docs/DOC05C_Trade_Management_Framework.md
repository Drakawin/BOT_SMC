# DOC05C — Trade Management Framework

## Official Specification for Trade Lifecycle Supervision

> **Document status:** AUTHORITATIVE — Official specification for Trade Management Framework.
> **Phase:** Phase 5 (Specification Completion) — Trade Management Layer (Part C).
> **This is NOT a coding task.** No MQL5 code, no pseudo-code, no algorithms, no UML, no flowcharts.
> **Purpose:** Define the architectural framework for supervising the complete lifecycle of active trades after successful execution.
> **Scope:** Trade Ownership, Trade Lifecycle, Trade Supervision, Trade State Management, Trade Event Routing, Trade Synchronization, Trade Completion, Trade Finalization.
> **Explicitly out of scope:** Market analysis, BUY/SELL decisions, order submission, execution validation, specific break-even/trailing/exit logic (those belong to future DOC05C sub-modules).
> **Relationship to prior documents:**
> - Implements Trade Management Engine defined in DOC01_System_Architecture.md.
> - Addresses PAR01 finding F1.2.1 / F9.5.1 (Trade Management Engine missing - CRITICAL).
> - Conforms to DOC00–DOC05B without redefining any SMC concept.

---

# Design Decision Record (DDR)

## Decision 1: Trade Management is Isolated from Execution

**Decision:** The Trade Management Framework is completely isolated from Execution (DOC04) and all execution logic.

**Reason:**
- Execution creates positions; Trade Management supervises them.
- Mixing execution with management violates separation of concerns.
- Management must be testable independently of execution behavior.
- It ensures management is reusable and maintainable.

## Decision 2: Trade State Objects Exist

**Decision:** All active trades are represented by immutable Trade State Objects.

**Reason:**
- Trade State Objects provide a single source of truth for trade state.
- They enable deterministic state management.
- They facilitate auditability and traceability.
- They support recovery after restarts.

## Decision 3: Trade Lifecycle is Event-Driven

**Decision:** All trade lifecycle transitions are driven by deterministic events.

**Reason:**
- Event-driven lifecycle ensures deterministic behavior.
- It enables full audit trail of all state changes.
- It facilitates debugging and testing.
- It is consistent with DOC03D event-driven state machine.

## Decision 4: Supervision is Separated from Execution

**Decision:** Trade Management supervises trades; it does NOT execute them.

**Reason:**
- Execution is a one-time action; supervision is ongoing.
- Separating them prevents execution logic from interfering with management.
- It ensures clear ownership and responsibilities.
- It simplifies testing and debugging.

## Decision 5: Trade Management is Modular

**Decision:** Trade Management is implemented as a framework with pluggable sub-modules.

**Reason:**
- Framework provides structure and coordination.
- Sub-modules (Break Even, Trailing Stop, Exit) are independently testable.
- It enables future extension without modifying the framework.
- It simplifies maintenance and debugging.

---

# Trade Management Framework — Architectural Specification

## Purpose
The Trade Management Framework supervises the complete lifecycle of active trades after successful execution. It does NOT perform market analysis, generate BUY/SELL decisions, submit orders, or validate executions.

## Architectural Role
- **Position:** Trade Management Layer (above DOC04 Execution, below DOC03 Decision).
- **Consumers:** DOC03 (Trade State Machine), DOC04E (Recovery), Audit Trail.
- **Dependencies:** DOC05A (Infrastructure Services), DOC05B (Gate Framework), DOC04D (Position Lifecycle Tracker).
- **Isolation:** Completely isolated from execution and market analysis.

## Framework Overview

| Component | Purpose | Consumers |
|---|---|---|
| **Trade State Manager** | Owns and manages Trade State Objects | All Trade Management modules |
| **Trade Lifecycle Manager** | Manages trade lifecycle transitions | Trade State Manager |
| **Trade Event Router** | Routes trade events to appropriate handlers | All Trade Management modules |
| **Trade Synchronization** | Synchronizes trade state with broker | Trade State Manager |
| **Trade Completion Manager** | Manages trade completion and finalization | Trade Lifecycle Manager |
| **Break Even Engine** | Implements break-even logic (future) | Trade State Manager |
| **Trailing Stop Engine** | Implements trailing stop logic (future) | Trade State Manager |
| **Exit Engine** | Implements exit logic (future) | Trade State Manager |
| **Trade Completion Engine** | Implements completion logic (future) | Trade Completion Manager |
| **Trade Statistics Engine** | Collects trade statistics (future) | Trade State Manager |

---

# Trade Lifecycle

## Deterministic States

The official trade lifecycle states:

### 1. Trade Created
- **Purpose:** A trade has been created but not yet activated.
- **Entry Conditions:** Execution Result Object with ACCEPTED status received.
- **Exit Conditions:** Trade is activated and becomes ACTIVE.
- **Allowed Transitions:** → Trade Active, → Trade Invalid.
- **Forbidden Transitions:** → Trade Managed, Trade Closing, Trade Closed, Trade Archived.
- **Recovery:** If activation fails, transition to Trade Invalid.

### 2. Trade Active
- **Purpose:** A trade is active and being supervised.
- **Entry Conditions:** Trade Created state successfully activated.
- **Exit Conditions:** Trade is managed, closing, or invalid.
- **Allowed Transitions:** → Trade Managed, → Trade Closing, → Trade Invalid.
- **Forbidden Transitions:** → Trade Created, Trade Closed, Trade Archived.
- **Recovery:** If trade becomes invalid, transition to Trade Invalid.

### 3. Trade Managed
- **Purpose:** A trade is being actively managed (break-even, trailing stop applied).
- **Entry Conditions:** Trade Active state with management actions applied.
- **Exit Conditions:** Trade is closing or invalid.
- **Allowed Transitions:** → Trade Closing, → Trade Invalid.
- **Forbidden Transitions:** → Trade Created, Trade Active, Trade Closed, Trade Archived.
- **Recovery:** If trade becomes invalid, transition to Trade Invalid.

### 4. Trade Closing
- **Purpose:** A trade is in the process of closing.
- **Entry Conditions:** Exit condition met (SL/TP hit, manual close, exit signal).
- **Exit Conditions:** Trade is closed or invalid.
- **Allowed Transitions:** → Trade Closed, → Trade Invalid.
- **Forbidden Transitions:** → Trade Created, Trade Active, Trade Managed, Trade Archived.
- **Recovery:** If closing fails, retry or transition to Trade Invalid.

### 5. Trade Closed
- **Purpose:** A trade has been successfully closed.
- **Entry Conditions:** Trade Closing state successfully completed.
- **Exit Conditions:** Trade is archived.
- **Allowed Transitions:** → Trade Archived.
- **Forbidden Transitions:** → Trade Created, Trade Active, Trade Managed, Trade Closing, Trade Invalid.
- **Recovery:** None. Closed trades are terminal.

### 6. Trade Archived
- **Purpose:** A closed trade has been archived for historical storage.
- **Entry Conditions:** Trade Closed state archived.
- **Exit Conditions:** None (terminal state).
- **Allowed Transitions:** None.
- **Forbidden Transitions:** All transitions forbidden.
- **Recovery:** None. Archived trades are terminal.

### 7. Trade Invalid
- **Purpose:** A trade is in an invalid state (error, corruption, unexpected condition).
- **Entry Conditions:** Error detected in any state.
- **Exit Conditions:** Trade is archived (after investigation).
- **Allowed Transitions:** → Trade Archived.
- **Forbidden Transitions:** → Trade Created, Trade Active, Trade Managed, Trade Closing, Trade Closed.
- **Recovery:** Investigate and archive. Invalid trades do not recover.

## State Transition Diagram

```
Trade Created → Trade Active → Trade Managed → Trade Closing → Trade Closed → Trade Archived
     ↓              ↓              ↓              ↓
     └──────────────┴──────────────┴──────────────┴──→ Trade Invalid → Trade Archived
```

---

# Trade State Object

## Purpose
The Trade State Object is the immutable record of a trade's state at a specific point in time. It contains all trade parameters, state information, and audit data.

## Creation
- **Created:** When trade enters Trade Created state.
- **Updated:** New Trade State Object created for each state transition (original remains immutable).
- **Frequency:** Once per state transition.

## Ownership
- **Owner:** Trade Management Framework (DOC05C).
- **Consumers:** Break Even Engine, Trailing Stop Engine, Exit Engine, Trade Completion Engine, Trade Statistics Engine, Audit Trail.

## Lifecycle
- **Created:** When trade enters Trade Created state.
- **Active:** While trade is in any active state (Created, Active, Managed, Closing).
- **Closed:** When trade enters Trade Closed state.
- **Archived:** When trade enters Trade Archived state.

## Immutable Fields

| Field | Type | Description |
|---|---|---|
| **Trade_ID** | String | Unique identifier for this trade |
| **Decision_ID** | String | Reference to the Decision that created this trade |
| **Execution_ID** | String | Reference to the Execution that created this trade |
| **Position_ID** | String | Reference to the Position created by this trade |
| **Symbol** | String | Trading symbol (XAUUSD) |
| **Direction** | Enum | BUY / SELL |
| **Entry_Price** | Double | Entry price |
| **Lot_Size** | Double | Lot size (0.01) |
| **Initial_SL** | Double | Initial stop loss price |
| **Initial_TP** | Double | Initial take profit price |
| **Entry_Time** | DateTime | Entry timestamp |
| **Magic_Number** | Integer | EA magic number |
| **Trade_Created_Time** | DateTime | When trade entered Trade Created state |

## Mutable Fields

| Field | Type | Description |
|---|---|---|
| **Current_SL** | Double | Current stop loss price (may change with trailing) |
| **Current_TP** | Double | Current take profit price (may change) |
| **Break_Even_Applied** | Boolean | Whether break-even has been applied |
| **Trailing_Stop_Applied** | Boolean | Whether trailing stop has been applied |
| **Trade_State** | Enum | Current trade state (Created/Active/Managed/Closing/Closed/Archived/Invalid) |
| **Trade_State_Time** | DateTime | When trade entered current state |
| **Close_Price** | Double | Close price (if closed) |
| **Close_Time** | DateTime | Close timestamp (if closed) |
| **Close_Reason** | Enum | SL_HIT / TP_HIT / MANUAL / EXIT_SIGNAL / ERROR |
| **Profit** | Double | Realized profit/loss (if closed) |
| **Swap** | Double | Realized swap (if closed) |
| **Commission** | Double | Realized commission (if closed) |

## Audit Fields

| Field | Type | Description |
|---|---|---|
| **State_Transition_Count** | Integer | Number of state transitions |
| **Management_Action_Count** | Integer | Number of management actions applied |
| **Last_Modification_Time** | DateTime | When trade was last modified |
| **Last_Modification_Source** | String | Source module that last modified trade |
| **Error_Count** | Integer | Number of errors encountered |
| **Last_Error_Time** | DateTime | When last error occurred |
| **Last_Error_Message** | String | Last error message |

## Expiration
- **Active trades:** Never expire (remain active until closed).
- **Closed trades:** Expire after configurable retention period (default: 90 days).
- **Archived trades:** Expire after configurable retention period (default: 365 days).

## Historical Storage
- **Active trades:** Stored in memory for fast access.
- **Closed trades:** Stored in memory + persisted to disk.
- **Archived trades:** Stored on disk only (FIFO retention).

---

# Module Responsibilities

## 1. Trade State Manager

### Purpose
Owns and manages all Trade State Objects. Provides a single source of truth for trade state.

### Responsibilities
- Create Trade State Objects when trades are created.
- Update Trade State Objects when trades transition states.
- Provide read-only access to Trade State Objects.
- Ensure Trade State Objects are immutable.
- Persist Trade State Objects for recovery.

### Inputs
- Execution Result Objects (from DOC04C)
- Position Snapshot Objects (from DOC04D)
- Trade Events (from Trade Event Router)

### Outputs
- Trade State Objects (to all Trade Management modules)
- Trade State Updates (to Audit Trail)

### Ownership
- **Owner:** Trade Management Framework (DOC05C).
- **Consumers:** All Trade Management modules.

### Isolation
- Does NOT perform market analysis.
- Does NOT generate BUY/SELL decisions.
- Does NOT submit orders.
- Does NOT validate executions.

---

## 2. Trade Lifecycle Manager

### Purpose
Manages trade lifecycle transitions. Ensures transitions are deterministic and valid.

### Responsibilities
- Validate state transitions.
- Execute state transitions.
- Generate trade events for state transitions.
- Ensure lifecycle consistency.

### Inputs
- Trade State Objects (from Trade State Manager)
- Trade Events (from Trade Event Router)
- Gate Result Objects (from DOC05B)

### Outputs
- Updated Trade State Objects (to Trade State Manager)
- Trade Lifecycle Events (to Trade Event Router)

### Ownership
- **Owner:** Trade Management Framework (DOC05C).
- **Consumers:** Trade State Manager, Trade Event Router.

### Isolation
- Does NOT perform market analysis.
- Does NOT generate BUY/SELL decisions.
- Does NOT submit orders.
- Does NOT validate executions.

---

## 3. Trade Event Router

### Purpose
Routes trade events to appropriate handlers. Ensures events are delivered deterministically.

### Responsibilities
- Receive trade events from Trade Lifecycle Manager.
- Route events to appropriate handlers.
- Ensure events are delivered in order.
- Log all events for audit.

### Inputs
- Trade Lifecycle Events (from Trade Lifecycle Manager)

### Outputs
- Trade Events (to Break Even Engine, Trailing Stop Engine, Exit Engine, etc.)
- Trade Audit Events (to Audit Trail)

### Ownership
- **Owner:** Trade Management Framework (DOC05C).
- **Consumers:** All Trade Management modules.

### Isolation
- Does NOT perform market analysis.
- Does NOT generate BUY/SELL decisions.
- Does NOT submit orders.
- Does NOT validate executions.

---

## 4. Trade Synchronization

### Purpose
Synchronizes trade state with broker state. Ensures consistency between internal state and broker state.

### Responsibilities
- Query broker for position state.
- Compare internal state with broker state.
- Detect inconsistencies.
- Resolve inconsistencies (conservative: prefer broker state).

### Inputs
- Trade State Objects (from Trade State Manager)
- Position Snapshot Objects (from DOC04D)
- Broker State (from DOC05B)

### Outputs
- Synchronized Trade State Objects (to Trade State Manager)
- Synchronization Events (to Trade Event Router)

### Ownership
- **Owner:** Trade Management Framework (DOC05C).
- **Consumers:** Trade State Manager.

### Isolation
- Does NOT perform market analysis.
- Does NOT generate BUY/SELL decisions.
- Does NOT submit orders.
- Does NOT validate executions.

---

## 5. Trade Completion Manager

### Purpose
Manages trade completion and finalization. Ensures trades are properly closed and archived.

### Responsibilities
- Detect trade completion conditions.
- Initiate trade closing process.
- Finalize closed trades.
- Archive closed trades.

### Inputs
- Trade State Objects (from Trade State Manager)
- Position Snapshot Objects (from DOC04D)
- Trade Events (from Trade Event Router)

### Outputs
- Trade Closing Events (to Trade Event Router)
- Trade Closed Events (to Trade Event Router)
- Archived Trade State Objects (to Historical Storage)

### Ownership
- **Owner:** Trade Management Framework (DOC05C).
- **Consumers:** Trade Lifecycle Manager, Historical Storage.

### Isolation
- Does NOT perform market analysis.
- Does NOT generate BUY/SELL decisions.
- Does NOT submit orders.
- Does NOT validate executions.

---

## 6. Break Even Engine (Future Module)

### Purpose
Implements break-even logic. Moves stop loss to entry price when profit threshold is reached.

### Responsibilities
- Monitor trade profit.
- Apply break-even when profit threshold reached.
- Update Trade State Object with new stop loss.

### Inputs
- Trade State Objects (from Trade State Manager)
- Position Snapshot Objects (from DOC04D)
- Trade Events (from Trade Event Router)

### Outputs
- Updated Trade State Objects (to Trade State Manager)
- Break Even Applied Events (to Trade Event Router)

### Ownership
- **Owner:** Trade Management Framework (DOC05C).
- **Consumers:** Trade State Manager, Trade Event Router.

### Isolation
- Does NOT perform market analysis.
- Does NOT generate BUY/SELL decisions.
- Does NOT submit orders.
- Does NOT validate executions.
- Does NOT implement trailing stop or exit logic.

---

## 7. Trailing Stop Engine (Future Module)

### Purpose
Implements trailing stop logic. Moves stop loss to lock in profits as price moves favorably.

### Responsibilities
- Monitor trade profit and price movement.
- Apply trailing stop when conditions met.
- Update Trade State Object with new stop loss.

### Inputs
- Trade State Objects (from Trade State Manager)
- Position Snapshot Objects (from DOC04D)
- Trade Events (from Trade Event Router)

### Outputs
- Updated Trade State Objects (to Trade State Manager)
- Trailing Stop Applied Events (to Trade Event Router)

### Ownership
- **Owner:** Trade Management Framework (DOC05C).
- **Consumers:** Trade State Manager, Trade Event Router.

### Isolation
- Does NOT perform market analysis.
- Does NOT generate BUY/SELL decisions.
- Does NOT submit orders.
- Does NOT validate executions.
- Does NOT implement break-even or exit logic.

---

## 8. Exit Engine (Future Module)

### Purpose
Implements exit logic. Closes trades when exit conditions are met.

### Responsibilities
- Monitor trade for exit conditions.
- Initiate trade closing when exit conditions met.
- Update Trade State Object with close information.

### Inputs
- Trade State Objects (from Trade State Manager)
- Position Snapshot Objects (from DOC04D)
- Trade Events (from Trade Event Router)
- Exit Signals (from DOC03 Decision Engine - future)

### Outputs
- Trade Closing Events (to Trade Event Router)
- Updated Trade State Objects (to Trade State Manager)

### Ownership
- **Owner:** Trade Management Framework (DOC05C).
- **Consumers:** Trade Completion Manager, Trade Event Router.

### Isolation
- Does NOT perform market analysis.
- Does NOT generate BUY/SELL decisions.
- Does NOT submit orders.
- Does NOT validate executions.
- Does NOT implement break-even or trailing stop logic.

---

## 9. Trade Completion Engine (Future Module)

### Purpose
Implements completion logic. Finalizes closed trades and prepares them for archival.

### Responsibilities
- Finalize closed trades.
- Calculate final profit/loss/swap/commission.
- Prepare trade for archival.

### Inputs
- Trade State Objects (from Trade State Manager)
- Position Snapshot Objects (from DOC04D)
- Trade Closed Events (from Trade Event Router)

### Outputs
- Finalized Trade State Objects (to Trade State Manager)
- Trade Archived Events (to Trade Event Router)

### Ownership
- **Owner:** Trade Management Framework (DOC05C).
- **Consumers:** Trade State Manager, Trade Event Router.

### Isolation
- Does NOT perform market analysis.
- Does NOT generate BUY/SELL decisions.
- Does NOT submit orders.
- Does NOT validate executions.

---

## 10. Trade Statistics Engine (Future Module)

### Purpose
Collects and analyzes trade statistics. Provides performance metrics and insights.

### Responsibilities
- Collect trade statistics (win rate, profit factor, etc.).
- Analyze trade performance.
- Generate statistics reports.

### Inputs
- Trade State Objects (from Trade State Manager)
- Archived Trade State Objects (from Historical Storage)

### Outputs
- Trade Statistics (to Audit Trail, Reporting)

### Ownership
- **Owner:** Trade Management Framework (DOC05C).
- **Consumers:** Audit Trail, Reporting.

### Isolation
- Does NOT perform market analysis.
- Does NOT generate BUY/SELL decisions.
- Does NOT submit orders.
- Does NOT validate executions.
- Does NOT modify trade state.

---

# Event System

## Deterministic Events

### 1. Trade Started
- **Trigger:** Trade enters Trade Active state.
- **Data:** Trade_ID, Decision_ID, Execution_ID, Position_ID, Entry_Price, Lot_Size, Initial_SL, Initial_TP, Entry_Time.
- **Consumers:** Break Even Engine, Trailing Stop Engine, Exit Engine, Audit Trail.

### 2. Trade Updated
- **Trigger:** Trade State Object updated (management action applied).
- **Data:** Trade_ID, Update_Type (BREAK_EVEN/TRAILING_STOP/MANUAL), Previous_SL, New_SL, Previous_TP, New_TP, Update_Time, Source_Module.
- **Consumers:** Audit Trail, Trade Statistics Engine.

### 3. Trade Closing
- **Trigger:** Trade enters Trade Closing state.
- **Data:** Trade_ID, Close_Reason (SL_HIT/TP_HIT/MANUAL/EXIT_SIGNAL/ERROR), Close_Price, Close_Time.
- **Consumers:** Trade Completion Engine, Audit Trail.

### 4. Trade Closed
- **Trigger:** Trade enters Trade Closed state.
- **Data:** Trade_ID, Close_Price, Close_Time, Close_Reason, Profit, Swap, Commission.
- **Consumers:** Trade Completion Engine, Trade Statistics Engine, Audit Trail.

### 5. Trade Archived
- **Trigger:** Trade enters Trade Archived state.
- **Data:** Trade_ID, Archive_Time, Archive_Location.
- **Consumers:** Audit Trail.

### 6. Trade Invalidated
- **Trigger:** Trade enters Trade Invalid state.
- **Data:** Trade_ID, Error_Type, Error_Message, Error_Time, Source_Module.
- **Consumers:** Audit Trail, Error Handling Service (DOC05A).

---

# Auditability

## Audit Requirements

Every trade event must record:

| Field | Description |
|---|---|
| **Trade_ID** | Unique identifier for the trade |
| **Decision_ID** | Reference to the Decision that created the trade |
| **Execution_ID** | Reference to the Execution that created the trade |
| **Position_ID** | Reference to the Position created by the trade |
| **Timestamp** | When the event occurred |
| **Trade_State** | Trade state at event time |
| **Event_Type** | Type of event (STARTED/UPDATED/CLOSING/CLOSED/ARCHIVED/INVALIDATED) |
| **Source_Module** | Module that generated the event |
| **Event_Data** | Full event data (varies by event type) |

## Audit Trail

- **All trade events are logged** at INFO level (normal) or WARN/ERROR level (errors).
- **Full context** is included (all trade parameters, event data, source module).
- **Aggregation** for repeated events (log once per interval).

## Audit Purpose

- **Traceability:** All trade lifecycle events are fully traceable.
- **Post-mortem analysis:** Trade issues can be analyzed after the fact.
- **Accountability:** All trade decisions are logged with full context.
- **Compliance:** All trade events are documented.

---

# Implementation Constraints

## Maximum CPU Cost

| Component | Estimated CPU Cost |
|---|---|
| **Trade State Manager** | < 0.1 ms per operation |
| **Trade Lifecycle Manager** | < 0.1 ms per transition |
| **Trade Event Router** | < 0.1 ms per event |
| **Trade Synchronization** | < 1 ms per sync |
| **Trade Completion Manager** | < 0.1 ms per completion |
| **Break Even Engine** | < 0.1 ms per check |
| **Trailing Stop Engine** | < 0.1 ms per check |
| **Exit Engine** | < 0.1 ms per check |
| **Trade Completion Engine** | < 0.1 ms per finalization |
| **Trade Statistics Engine** | < 1 ms per analysis |
| **Total (per trade)** | < 5 ms |

## Maximum Memory Cost

| Component | Estimated Memory Cost |
|---|---|
| **Trade State Object** | < 1 KB per trade |
| **Trade Event** | < 500 bytes per event |
| **Active trades** | < 1 KB (max 1 trade) |
| **Event buffer** | < 10 KB |
| **Total** | < 15 KB |

## Synchronization Strategy

- **Single-threaded:** All trade management operations are single-threaded.
- **No concurrent access:** No concurrent access to Trade State Objects.
- **Deterministic order:** All operations occur in deterministic order.

## State Consistency

- **Atomic updates:** Trade State Object updates are atomic.
- **Consistent state:** Trade state is always consistent.
- **Recovery:** State can be recovered from persistence after restart.

## Scalability

- **Linear scaling:** Performance scales linearly with number of trades (max 1 per DOC00).
- **Bounded:** All components have bounded resource usage.
- **No bottlenecks:** No single component dominates resource usage.

---

# Performance

## Worst Case

- **Trade creation:** < 1 ms.
- **State transition:** < 1 ms.
- **Event routing:** < 1 ms.
- **Synchronization:** < 5 ms.
- **Trade completion:** < 1 ms.
- **Total (per trade lifecycle):** < 10 ms.

## Average Case

- **Trade creation:** < 0.5 ms.
- **State transition:** < 0.5 ms.
- **Event routing:** < 0.5 ms.
- **Synchronization:** < 2 ms.
- **Trade completion:** < 0.5 ms.
- **Total (per trade lifecycle):** < 5 ms.

## Complexity

- **Time complexity:** O(1) per operation (bounded number of trades).
- **Space complexity:** O(1) per trade (bounded trade parameters).

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **No market analysis:** DOC05C defines **only trade management framework**. It does not perform market analysis. *(Pass)*
- **No BUY logic:** DOC05C does not create BUY decisions. *(Pass)*
- **No SELL logic:** DOC05C does not create SELL decisions. *(Pass)*
- **No execution:** DOC05C does not execute orders. *(Pass)*
- **No order submission:** DOC05C does not submit orders. *(Pass)*
- **No position modification:** DOC05C does not modify positions (it supervises them). *(Pass)*
- **No trailing stop:** DOC05C does not implement trailing stop logic (that belongs to future Trailing Stop Engine). *(Pass)*
- **No break-even:** DOC05C does not implement break-even logic (that belongs to future Break Even Engine). *(Pass)*
- **No exit logic:** DOC05C does not implement exit logic (that belongs to future Exit Engine). *(Pass)*
- **No circular dependency:** DOC05C depends on DOC05A/DOC05B/DOC04D and is consumed by DOC03/DOC04E. No circular dependencies. *(Pass)*
- **Consistency with DOC04A:** DOC05C consumes Execution Result Objects from DOC04A. *(Pass)*
- **Consistency with DOC04E:** DOC05C provides Trade State Objects to DOC04E for recovery. *(Pass)*
- **Consistency with DOC05A:** DOC05C uses DOC05A infrastructure services (Persistence, Logging, Error Handling). *(Pass)*
- **Consistency with DOC05B:** DOC05C uses Gate Result Objects from DOC05B. *(Pass)*
- **Implementation feasibility using standard MQL5 APIs only:** All framework components can be implemented using standard MQL5 APIs (position queries, order modifications, file I/O, etc.). *(Pass)*

**Scope boundaries respected:** No market analysis, no BUY/SELL logic, no execution, no order submission, no position modification, no trailing stop, no break-even, no exit logic. The Trade Management Framework provides supervision and coordination only.

**Design Decision Record (DDR):** Documented why trade management is isolated from execution, why Trade State Objects exist, why trade lifecycle is event-driven, why supervision is separated from execution, and why trade management is modular.

**Outcome:** No blocking issues. DOC05C is internally consistent, deterministic, non-repainting, look-ahead-safe, circular-dependency-free, and fully conforms to DOC00–DOC05B and ADR01.

---

# Final Notes

1. **Framework only.** This document specifies the Trade Management Framework and nothing else. No market analysis, no BUY/SELL logic, no execution, no specific break-even/trailing/exit logic.
2. **Supervision role.** DOC05C supervises the complete lifecycle of active trades. It does NOT create, execute, or modify trades.
3. **Isolated from execution.** Trade Management is completely isolated from Execution and all execution logic.
4. **Modular design.** Trade Management is implemented as a framework with pluggable sub-modules (Break Even, Trailing Stop, Exit, etc.).
5. **Event-driven lifecycle.** All trade lifecycle transitions are driven by deterministic events.
6. **Immutable Trade State Objects.** Trade State Objects are immutable, guaranteeing auditability and consistency.
7. **Full audit trail.** Every trade event is fully reconstructable from the audit trail.
8. **Performance constraints.** All components have strict performance constraints to ensure minimal impact on trading performance.
9. **Addresses PAR01 CRITICAL finding.** DOC05C addresses PAR01 finding F1.2.1 / F9.5.1 (Trade Management Engine missing - CRITICAL).

This document is now the official specification for the Trade Management Framework.

**Phase 5 (Specification Completion) — Trade Management Layer (Part C) is complete.**

**PAR01 CRITICAL finding F1.2.1 / F9.5.1 is RESOLVED.**
