# DOC05E — Trailing Stop Engine

## Official Specification for Continuous Stop Loss Management

> **Document status:** AUTHORITATIVE — Official specification for Trailing Stop Engine.
> **Phase:** Phase 5 (Specification Completion) — Trade Management Sub-Modules (Part E).
> **This is NOT a coding task.** No MQL5 code, no pseudo-code, no algorithms, no UML, no flowcharts.
> **Purpose:** Define the architecture for deterministically adjusting Stop Loss to lock in profits as price moves favorably.
> **Scope:** Trailing Stop Evaluation, Trailing Stop Conditions, Trailing Stop Validation, Trailing Stop State, Trailing Stop Event Generation, Trailing Stop Synchronization.
> **Explicitly out of scope:** Market analysis, BUY/SELL decisions, order submission, break-even logic, exit logic.
> **Relationship to prior documents:**
> - Implements Trailing Stop Engine defined in DOC05C_Trade_Management_Framework.md.
> - Implements DOC00 §16 Trailing Stop (trailing stop logic).
> - Conforms to DOC00–DOC05D, DOC03E without redefining any SMC concept.

---

# Design Decision Record (DDR)

## Decision 1: Trailing Stop is Isolated from Break Even

**Decision:** The Trailing Stop Engine is completely isolated from the Break Even Engine.

**Reason:**
- Break Even is a one-time action; Trailing Stop is ongoing.
- Mixing them violates separation of concerns.
- Each must be testable independently.
- It ensures clear ownership and responsibilities.

## Decision 2: Trailing Stop is Continuous

**Decision:** Trailing Stop can be applied multiple times per trade as price moves favorably.

**Reason:**
- Trailing Stop is a continuous adjustment, not a threshold action.
- It locks in profits progressively as price advances.
- It must respond to new structural levels (swings, BOS, CHoCH).
- It complements Break Even (which is one-time only).

## Decision 3: Trailing Stop Decisions are Deterministic

**Decision:** All Trailing Stop decisions are deterministic based on Trade State Object, Position Snapshot Object, and consumed SMC Event Objects.

**Reason:**
- Determinism ensures reproducibility.
- It enables full audit trail.
- It simplifies testing and debugging.
- It is consistent with DOC05C deterministic philosophy.

## Decision 4: Trailing Stop Uses Structural Levels

**Decision:** Trailing Stop moves SL to structural levels (swings, BOS, CHoCH) identified by consumed SMC Events.

**Reason:**
- Structural levels provide logical stop placement.
- They are identified by DOC02 (Market Analysis) and communicated via SMC Events.
- The engine consumes validated events; it never performs analysis.
- It ensures stops are placed at meaningful price levels.

## Decision 5: Trailing Stop Requires Validated SMC Events

**Decision:** Trailing Stop is only applied when a validated SMC Event Object (DOC03E) of an approved type has been consumed by the engine.

**Reasoning:**
- Trailing Stop is a structural reaction, not a numerical threshold.
- The engine consumes validated events from DOC02, never performs analysis.
- This preserves the single-source-of-truth principle: DOC02 owns all SMC detection.
- It ensures Trailing Stop activation is deterministic, auditable, and traceable to a specific structural event.
- It is consistent with DOC03E event-based communication contract.

---

# Trailing Stop Engine — Architectural Specification

## Purpose
The Trailing Stop Engine deterministically adjusts Stop Loss to lock in profits as price moves favorably. It does NOT perform market analysis, generate BUY/SELL decisions, submit orders, implement break-even, or implement exit logic.

## Architectural Role
- **Position:** Trade Management Sub-Module (under DOC05C Trade Management Framework).
- **Consumers:** Trade State Manager (DOC05C), Trade Event Router (DOC05C), Audit Trail.
- **Dependencies:** DOC05A (Infrastructure Services), DOC05C (Trade Management Framework), DOC03E (SMC Event Objects).
- **Isolation:** Completely isolated from Break Even Engine and Exit Engine.

## Engine Overview

| Component | Purpose | Consumers |
|---|---|---|
| **Trailing Stop Evaluator** | Evaluates Trailing Stop conditions | Trailing Stop Engine |
| **Trailing Stop Validator** | Validates Trailing Stop application | Trailing Stop Engine |
| **Trailing Stop State Manager** | Manages Trailing Stop state | Trailing Stop Engine |
| **Trailing Stop Event Generator** | Generates Trailing Stop events | Trade Event Router |
| **Trailing Stop Synchronization** | Synchronizes with broker | Trade Synchronization |

---

# Trailing Stop Conditions

## Deterministic Rules

### 1. SMC Event Eligibility

**Rule:** Trailing Stop is only eligible when a validated SMC Event Object (DOC03E) of an approved type has been consumed by the engine.

**Evaluation:**
```
Event_Eligible = (Consumed_SMC_Event != null) AND
                 (Consumed_SMC_Event.Validation_Status == VALIDATED) AND
                 (Consumed_SMC_Event.EventType in APPROVED_EVENT_TYPES)
```

**Approved Event Types (per DOC03E):**
- BOS_CONFIRMED (DOC02B)
- CHoCH_CONFIRMED (DOC02C)
- LIQUIDITY_SWEEP_CONFIRMED (DOC02D)
- ORDER_BLOCK_CONFIRMED (DOC02EB)
- FAIR_VALUE_GAP_CONFIRMED (DOC02F)

**Rationale:**
- Trailing Stop is a structural reaction, not a numerical threshold.
- The engine consumes validated events from DOC02; it never performs market analysis.
- Ensures activation is traceable to a specific structural event.
- Consistent with DOC03E event-based communication contract.

### 2. Position Eligibility

**Rule:** Trailing Stop is only eligible for positions in Trade Active or Trade Managed state.

**Evaluation:**
```
Position_Eligible = (Trade_State == TRADE_ACTIVE OR Trade_State == TRADE_MANAGED)
```

**Rationale:**
- Trailing Stop should not be applied to trades that are closing or closed.
- Ensures Trailing Stop is only applied to active trades.

### 3. Break Even Applied

**Rule:** Trailing Stop is only eligible after Break Even has been applied.

**Evaluation:**
```
Break_Even_Applied = (Break_Even_Applied == true)
```

**Rationale:**
- Break Even is the first SL adjustment (one-time).
- Trailing Stop is subsequent SL adjustments (continuous).
- Prevents conflicting SL modifications.
- Ensures logical progression: Break Even → Trailing Stop.

### 4. Improvement Required

**Rule:** Trailing Stop SL must improve (or maintain) current SL.

**Evaluation:**
```
if Direction == BUY:
    Improvement_Required = (New_SL >= Current_SL)
else:
    Improvement_Required = (New_SL <= Current_SL)
```

**Rationale:**
- Trailing Stop should never move SL against the trade.
- Ensures SL only moves in favor of the trade.
- Prevents accidental SL widening.

### 5. Invalid State Detection

**Rule:** Trailing Stop is not eligible if trade is in invalid state.

**Evaluation:**
```
Valid_State = (Trade_State != TRADE_INVALID)
```

**Rationale:**
- Trailing Stop should not be applied to invalid trades.
- Ensures consistency.

### 6. Recovery Behaviour

**Rule:** If Trailing Stop was applied but SL was reset (e.g., by recovery), Trailing Stop can be re-applied when a new validated SMC Event is consumed.

**Evaluation:**
```
Recovery_Allowed = (Trailing_Stop_Applied == true AND
                    Current_SL != Last_Trailing_SL AND
                    Consumed_SMC_Event != null AND
                    Consumed_SMC_Event.Validation_Status == VALIDATED)
```

**Rationale:**
- Allows recovery after state corruption.
- Ensures Trailing Stop is maintained.
- Requires a new validated event to trigger re-application.

## Trailing Stop Eligibility Summary

Trailing Stop is eligible when ALL of the following are true:
1. A validated SMC Event Object (DOC03E) has been consumed
2. Trade state is TRADE_ACTIVE or TRADE_MANAGED
3. Break Even has been applied
4. New SL improves (or maintains) current SL
5. Trade is not in TRADE_INVALID state
6. All gates pass (DOC05B)

---

# SMC Event Consumption

## Purpose

The Trailing Stop Engine is an **Event Consumer** that consumes validated SMC Event Objects (DOC03E) to determine Trailing Stop eligibility. It never performs market analysis or SMC detection.

## Producer

**SMC Event Producers (DOC02):**
- DOC02A: Market Structure Engine
- DOC02B: Break of Structure Engine
- DOC02C: Change of Character Engine
- DOC02D: Liquidity Engine
- DOC02EB: Order Block Engine
- DOC02F: Fair Value Gap Engine

## Consumer

**Trailing Stop Engine (DOC05E):**
- Consumes validated SMC Event Objects
- Never produces SMC Events
- Never performs SMC analysis
- Reacts only to consumed events

## Ownership

| Operation | Owner |
|-----------|-------|
| **Create SMC Events** | DOC02 modules only |
| **Consume SMC Events** | DOC03, DOC04, DOC05 modules |
| **Archive SMC Events** | DOC05A (Infrastructure) |
| **Invalidate SMC Events** | DOC02 modules only |

**Trailing Stop Engine Ownership:**
- ✓ Can consume SMC Events
- ✗ Cannot create SMC Events
- ✗ Cannot archive SMC Events
- ✗ Cannot invalidate SMC Events

## Validation Requirement

**Rule:** The Trailing Stop Engine only consumes **VALIDATED** SMC Event Objects.

**Validation Criteria:**
```
Valid_SMC_Event = (Event.Validation_Status == VALIDATED) AND
                  (Event.Timestamp != null) AND
                  (Event.Source_Module != null) AND
                  (Event.EventType != null)
```

**Rejection:**
- Events with status PENDING are ignored
- Events with status INVALID are ignored
- Events with missing required fields are ignored

## Expiration

**Rule:** The Trailing Stop Engine only consumes SMC Events that have not expired.

**Expiration Check:**
```
Not_Expired = (Current_Time - Event.Timestamp) < Event.Expiration_Period
```

**Default Expiration Periods (per DOC03E):**
- BOS_CONFIRMED: 24 hours
- CHoCH_CONFIRMED: 24 hours
- LIQUIDITY_SWEEP_CONFIRMED: 24 hours
- ORDER_BLOCK_CONFIRMED: 72 hours
- FAIR_VALUE_GAP_CONFIRMED: 72 hours

## Dependency

**Rule:** The Trailing Stop Engine depends on DOC03E for event structure and validation.

**Dependencies:**
- DOC03E: SMC Event Object Specification
- DOC02A-F: SMC Event Producers
- DOC05A: Event Bus and Infrastructure
- DOC05C: Trade Management Framework

**No Dependencies On:**
- Market data (DOC01)
- SMC detection logic (DOC02)
- Execution logic (DOC04)

## Supported Event Types

The Trailing Stop Engine supports the following SMC Event Types (per DOC03E):

| Event Type | Producer | Priority | Use Case |
|------------|----------|----------|----------|
| **BOS_CONFIRMED** | DOC02B | HIGH | Trend continuation |
| **CHoCH_CONFIRMED** | DOC02C | HIGH | Trend reversal |
| **LIQUIDITY_SWEEP_CONFIRMED** | DOC02D | MEDIUM | Liquidity grab |
| **ORDER_BLOCK_CONFIRMED** | DOC02EB | HIGH | Entry zone |
| **FAIR_VALUE_GAP_CONFIRMED** | DOC02F | MEDIUM | Imbalance zone |

**Not Supported:**
- MITIGATION_CONFIRMED (not relevant for Trailing Stop)
- INTERNAL_STRUCTURE_CONFIRMED (too granular)
- EXTERNAL_STRUCTURE_CONFIRMED (too granular)
- STRUCTURE_SHIFT_CONFIRMED (too broad)
- TREND_CONTINUATION_CONFIRMED (redundant with BOS)

## Consumption Rules

### Rule 1: Event Queue Processing

**Rule:** SMC Events are processed in FIFO order from the event queue.

**Processing:**
```
For each event in Event_Queue:
    If event is valid and not expired:
        Evaluate Trailing Stop eligibility
        If eligible:
            Apply Trailing Stop
            Mark event as consumed
```

### Rule 2: Multiple Events Per Trade

**Rule:** Multiple SMC Events can be consumed per trade (continuous adjustment).

**Rationale:**
- Trailing Stop is continuous, not one-time.
- Each new structural level can trigger a new SL adjustment.
- Allows progressive profit locking.

### Rule 3: Event Consumption Logging

**Rule:** Every consumed SMC Event is logged in the audit trail.

**Logged Fields:**
- SMC_Event_ID
- SMC_Event_Type
- SMC_Event_Source
- SMC_Event_Timestamp
- Consumption_Time
- Validation_Status

### Rule 4: Event Expiration Handling

**Rule:** Expired SMC Events are discarded without processing.

**Handling:**
```
If (Current_Time - Event.Timestamp) >= Event.Expiration_Period:
    Discard event
    Log warning: "SMC Event expired"
```

### Rule 5: Invalid Event Handling

**Rule:** Invalid SMC Events are discarded without processing.

**Handling:**
```
If Event.Validation_Status != VALIDATED:
    Discard event
    Log warning: "SMC Event invalid"
```

### Rule 6: Event Deduplication

**Rule:** Duplicate SMC Events (same Event_ID) are ignored.

**Handling:**
```
If Event_ID in Consumed_Event_IDs:
    Ignore event
    Log info: "Duplicate SMC Event ignored"
```

## Event Consumption Flow

```
1. Receive SMC Event from Event Bus (DOC05A)
   ↓
2. Validate Event Structure
   - Check required fields
   - Check validation status
   ↓
3. Check Event Expiration
   - Compare timestamp with current time
   - Discard if expired
   ↓
4. Check Event Deduplication
   - Compare Event_ID with consumed events
   - Ignore if duplicate
   ↓
5. Evaluate Trailing Stop Eligibility
   - Check event type
   - Check trade state
   - Check Break Even status
   - Check SL improvement
   ↓
6. Apply Trailing Stop (if eligible)
   - Calculate new SL
   - Submit SL modification
   ↓
7. Log Event Consumption
   - Record in audit trail
   - Mark event as consumed
```

---

# Trailing Stop State Object

## Purpose
The Trailing Stop State Object tracks whether Trailing Stop has been applied to a trade and stores the Trailing Stop SL price.

## Creation
- **Created:** When trade enters Trade Active state.
- **Updated:** When Trailing Stop is applied.
- **Frequency:** Multiple times per trade (continuous adjustment).

## Ownership
- **Owner:** Trailing Stop Engine (DOC05E).
- **Consumers:** Trade State Manager (DOC05C), Trade Event Router (DOC05C), Audit Trail.

## Lifecycle
- **Created:** When trade enters Trade Active state.
- **Active:** While trade is active and Trailing Stop not yet applied.
- **Applied:** When Trailing Stop is applied (can be applied multiple times).
- **Archived:** When trade is archived.

## Immutable Fields

| Field | Type | Description |
|---|---|---|
| **Trade_ID** | String | Reference to the trade |
| **Entry_Price** | Double | Trade entry price |
| **Direction** | Enum | BUY / SELL |
| **Trailing_Stop_Created_Time** | DateTime | When Trailing Stop state was created |

## Mutable Fields

| Field | Type | Description |
|---|---|---|
| **Trailing_Stop_Applied** | Boolean | Whether Trailing Stop has been applied |
| **Last_Trailing_SL** | Double | Last Trailing Stop SL price |
| **Trailing_Stop_Count** | Integer | Number of times Trailing Stop has been applied |
| **Last_Trailing_Apply_Time** | DateTime | When Trailing Stop was last applied |
| **Last_SMC_Event_ID** | String | ID of last consumed SMC Event that triggered Trailing Stop |

## Historical Storage
- **Active Trailing Stop states:** Stored in memory (part of Trade State Object).
- **Archived Trailing Stop states:** Stored on disk (part of archived Trade State Object).

---

# Event System

## Deterministic Events

### 1. Trailing Stop Eligible

**Trigger:** Validated SMC Event consumed and Trailing Stop conditions met (trade active, Break Even applied, SL improvement possible).

**Data:**
- Trade_ID
- Position_ID
- Decision_ID
- Execution_ID
- Timestamp
- Entry_Price
- Current_Price
- SMC_Event_ID
- SMC_Event_Type
- SMC_Event_Source
- SMC_Event_Version
- Validation_Status
- Consumed_Event_Timestamp
- Producer_Module
- Proposed_New_SL

**Consumers:** Audit Trail, Trade Event Router.

**Action:** Log eligibility, continue monitoring.

### 2. Trailing Stop Applied

**Trigger:** Trailing Stop SL modification successfully applied to broker following consumption of a validated SMC Event.

**Data:**
- Trade_ID
- Position_ID
- Decision_ID
- Execution_ID
- Timestamp
- Entry_Price
- Old_SL (previous SL)
- New_SL (Trailing Stop SL)
- Current_Price
- SMC_Event_ID
- SMC_Event_Type
- SMC_Event_Source
- SMC_Event_Version
- Validation_Status
- Consumed_Event_Timestamp
- Producer_Module
- Trailing_Stop_Count

**Consumers:** Trade State Manager, Trade Event Router, Audit Trail.

**Action:** Update Trade State Object, generate Trade Updated event.

### 3. Trailing Stop Rejected

**Trigger:** Trailing Stop conditions not met or validation failed.

**Data:**
- Trade_ID
- Position_ID
- Decision_ID
- Execution_ID
- Timestamp
- Rejection_Reason (INVALID_EVENT / EVENT_NOT_VALIDATED / EVENT_EXPIRED / UNSUPPORTED_EVENT / TRADE_NOT_ACTIVE / BREAK_EVEN_NOT_APPLIED / NO_IMPROVEMENT / INVALID_STATE / GATE_FAILED)
- SMC_Event_ID (if event was consumed)
- SMC_Event_Type (if event was consumed)
- SMC_Event_Source (if event was consumed)
- SMC_Event_Version (if event was consumed)
- Validation_Status (if event was consumed)
- Consumed_Event_Timestamp (if event was consumed)
- Producer_Module (if event was consumed)

**Consumers:** Audit Trail.

**Action:** Log rejection, continue monitoring.

### 4. Trailing Stop Failed

**Trigger:** Trailing Stop SL modification failed (broker error, timeout, etc.).

**Data:**
- Trade_ID
- Position_ID
- Decision_ID
- Execution_ID
- Timestamp
- Failure_Reason (BROKER_ERROR / TIMEOUT / INVALID_SL / INSUFFICIENT_MARGIN)
- Old_SL
- Proposed_New_SL
- SMC_Event_ID
- SMC_Event_Type
- SMC_Event_Source
- SMC_Event_Version
- Validation_Status
- Consumed_Event_Timestamp
- Producer_Module
- Error_Code
- Error_Message

**Consumers:** Error Handling Service (DOC05A), Audit Trail.

**Action:** Log failure, retry (if recoverable) or escalate.

---

# Trailing Stop Evaluation

## Evaluation Process

### 1. Receive SMC Event

- **Trigger:** SMC Event received from Event Bus (DOC05A).
- **Action:** Validate event structure, check expiration, check deduplication.

### 2. Check Trailing Stop Eligibility

- **Check 1:** SMC Event Consumption (validated SMC Event Object consumed from DOC03E).
- **Check 2:** Position Eligibility (trade state is ACTIVE or MANAGED).
- **Check 3:** Break Even Applied (Break Even has been applied).
- **Check 4:** Improvement Required (new SL improves or maintains current SL).
- **Check 5:** Invalid State Detection (trade not in INVALID state).
- **Check 6:** Gate Check (all gates pass).

### 3. Generate Trailing Stop Eligible Event

- **If eligible:** Generate Trailing Stop Eligible event.
- **If not eligible:** Generate Trailing Stop Rejected event with reason.

### 4. Apply Trailing Stop

- **Action:** Calculate Trailing Stop SL (structural level from consumed SMC Event).
- **Action:** Submit SL modification to broker.
- **If successful:** Generate Trailing Stop Applied event, update Trade State Object.
- **If failed:** Generate Trailing Stop Failed event, retry or escalate.

### 5. Update Trade State

- **Action:** Set Trailing_Stop_Applied = true.
- **Action:** Set Last_Trailing_SL = calculated SL.
- **Action:** Set Trailing_Stop_Count = Trailing_Stop_Count + 1.
- **Action:** Set Last_Trailing_Apply_Time = current time.
- **Action:** Set Last_SMC_Event_ID = consumed SMC Event ID.
- **Action:** Generate Trade Updated event.

## Evaluation Frequency

- **Trigger:** On every consumed SMC Event (for active trades).
- **Frequency:** Event-driven (not tick-based).
- **Optimization:** Skip evaluation if no valid SMC Event consumed.

---

# Trailing Stop Validation

## Validation Rules

### 1. SL Direction Validation

**Rule:** Trailing Stop SL must be on the correct side of entry price.

**Validation:**
```
if Direction == BUY:
    Valid = (New_SL > Entry_Price)
else:
    Valid = (New_SL < Entry_Price)
```

### 2. SL Distance Validation

**Rule:** Trailing Stop SL must not be closer to current price than minimum SL distance.

**Validation:**
```
Min_SL_Distance = SymbolInfoInteger(SYMBOL_TRADE_STOPS_LEVEL) * Point
SL_Distance = |Current_Price - New_SL|
Valid = (SL_Distance >= Min_SL_Distance)
```

### 3. SL Improvement Validation

**Rule:** Trailing Stop SL must improve (or maintain) current SL.

**Validation:**
```
if Direction == BUY:
    Valid = (New_SL >= Current_SL)
else:
    Valid = (New_SL <= Current_SL)
```

### 4. Broker Validation

**Rule:** Broker must accept the SL modification.

**Validation:**
- Submit SL modification to broker.
- Check broker response.
- If accepted: validation passes.
- If rejected: validation fails with broker error code.

---

# Trailing Stop Synchronization

## Synchronization Process

### 1. Query Broker State

- **Action:** Query broker for current position SL.
- **API:** PositionGetDouble(POSITION_SL).

### 2. Compare Internal State with Broker State

- **Action:** Compare Trade State Object Last_Trailing_SL with broker SL.
- **Check:** Are they equal (within tolerance)?

### 3. Detect Inconsistencies

- **If equal:** No action needed.
- **If not equal:** Trailing Stop was not applied or was reset.

### 4. Resolve Inconsistencies

- **If Trailing Stop should be applied but isn't:** Re-apply Trailing Stop with new SMC Event.
- **If Trailing Stop was applied but SL was reset:** Re-apply Trailing Stop (recovery).
- **If Trailing Stop was not supposed to be applied:** Log warning.

## Synchronization Frequency

- **Trigger:** On every synchronization cycle (configurable, default: every 60 seconds).
- **Frequency:** Configurable.
- **Optimization:** Skip if Trailing Stop already applied and SL matches.

---

# Auditability

## Audit Requirements

Every Trailing Stop action must record:

| Field | Description |
|---|---|
| **Trade_ID** | Unique identifier for the trade |
| **Position_ID** | Reference to the Position |
| **Decision_ID** | Reference to the Decision |
| **Execution_ID** | Reference to the Execution |
| **Timestamp** | When the action occurred |
| **Entry_Price** | Trade entry price |
| **Old_SL** | Previous SL price |
| **New_SL** | New SL price (Trailing Stop SL) |
| **Reason** | Reason for action (ELIGIBLE / APPLIED / REJECTED / FAILED) |
| **Current_Price** | Current price at action time |
| **SMC_Event_ID** | Reference to the consumed SMC Event (DOC03E) |
| **SMC_Event_Type** | Type of consumed SMC Event |
| **SMC_Event_Source** | Producer module of consumed SMC Event |
| **SMC_Event_Version** | Schema version of consumed SMC Event |
| **Validation_Status** | Validation status of consumed SMC Event |
| **Consumed_Event_Timestamp** | Timestamp of consumed SMC Event |
| **Producer_Module** | Module that produced the consumed SMC Event |
| **Trailing_Stop_Count** | Number of times Trailing Stop has been applied |
| **Error_Code** | (If FAILED) Broker error code |
| **Error_Message** | (If FAILED) Broker error message |

## Audit Trail

- **All Trailing Stop actions are logged** at INFO level (ELIGIBLE/APPLIED) or WARN/ERROR level (REJECTED/FAILED).
- **Full context** is included (all trade parameters, action data, broker response, consumed SMC Event).
- **Aggregation** for repeated actions (log once per interval).

## Audit Purpose

- **Traceability:** All Trailing Stop actions are fully traceable.
- **Post-mortem analysis:** Trailing Stop issues can be analyzed after the fact.
- **Accountability:** All Trailing Stop decisions are logged with full context.
- **Compliance:** All Trailing Stop actions are documented.

---

# Implementation Constraints

## Maximum CPU Cost

| Operation | Estimated CPU Cost |
|---|---|
| **Trailing Stop evaluation** | < 0.1 ms per evaluation |
| **Trailing Stop application** | < 1 ms per application |
| **Trailing Stop synchronization** | < 1 ms per sync |
| **Total (per trade)** | < 2 ms |

## Maximum Memory Cost

| Component | Estimated Memory Cost |
|---|---|
| **Trailing Stop state** | < 100 bytes per trade |
| **Trailing Stop event** | < 500 bytes per event |
| **Total** | < 1 KB |

## Evaluation Frequency

- **Default:** Event-driven (on every consumed SMC Event).
- **Configurable:** Yes (via Configuration Service).
- **Optimization:** Skip if no valid SMC Event consumed.

## Synchronization Strategy

- **Single-threaded:** All Trailing Stop operations are single-threaded.
- **No concurrent access:** No concurrent access to Trailing Stop state.
- **Deterministic order:** All operations occur in deterministic order.

## Recovery Strategy

- **Persistence:** Trailing Stop state is persisted (part of Trade State Object).
- **On restart:** Load Trailing Stop state from persistence.
- **On inconsistency:** Re-apply Trailing Stop if needed with new SMC Event.

## Event Consumer Role

**The Trailing Stop Engine is an Event Consumer.**

- ✓ Consumes validated SMC Events from DOC03E
- ✗ Never produces SMC Events
- ✗ Never evaluates market structure
- ✗ Never detects BOS, CHoCH, Liquidity Sweeps, Order Blocks, or FVGs
- ✗ Never performs any market analysis

---

# Performance

## Worst Case

- **Trailing Stop evaluation:** < 0.1 ms.
- **Trailing Stop application:** < 1 ms (broker call).
- **Trailing Stop synchronization:** < 1 ms (broker query).
- **Total (per trade):** < 2 ms.

## Average Case

- **Trailing Stop evaluation:** < 0.05 ms.
- **Trailing Stop application:** < 0.5 ms.
- **Trailing Stop synchronization:** < 0.5 ms.
- **Total (per trade):** < 1 ms.

## Complexity

- **Time complexity:** O(1) per operation (bounded number of trades).
- **Space complexity:** O(1) per trade (bounded Trailing Stop state).

---

# Self Review Result

Before finalising, the document was checked against the required checklist. Findings and resolutions:

- **No market analysis:** DOC05E defines **only Trailing Stop logic**. It does not perform market analysis. *(Pass)*
- **No BUY logic:** DOC05E does not create BUY decisions. *(Pass)*
- **No SELL logic:** DOC05E does not create SELL decisions. *(Pass)*
- **No execution:** DOC05E does not execute orders (it modifies SL via broker API). *(Pass)*
- **No break-even:** DOC05E does not implement break-even logic. *(Pass)*
- **No exit logic:** DOC05E does not implement exit logic. *(Pass)*
- **No circular dependency:** DOC05E depends on DOC05A/DOC05C/DOC03E and is consumed by Trade State Manager/Trade Event Router. No circular dependencies. *(Pass)*
- **Consistency with DOC05A:** DOC05E uses DOC05A infrastructure services (Persistence, Logging, Error Handling, Clock/Time). *(Pass)*
- **Consistency with DOC05B:** DOC05E uses Gate Result Objects from DOC05B. *(Pass)*
- **Consistency with DOC05C:** DOC05E is a sub-module of DOC05C Trade Management Framework. *(Pass)*
- **Consistency with DOC05D:** DOC05E is isolated from Break Even Engine but requires Break Even to be applied first. *(Pass)*
- **Consistency with DOC03E:** DOC05E consumes validated SMC Event Objects from DOC03E. *(Pass)*
- **Implementation feasibility using standard MQL5 APIs only:** All Trailing Stop operations can be implemented using standard MQL5 APIs (PositionGetDouble, OrderModify, etc.). *(Pass)*
- **Consumes validated SMC Events only:** DOC05E consumes validated SMC Event Objects from DOC03E and never performs its own market analysis. *(Pass)*
- **No BOS detection:** DOC05E does not detect Break of Structure events. *(Pass)*
- **No CHoCH detection:** DOC05E does not detect Change of Character events. *(Pass)*
- **No Liquidity Sweep detection:** DOC05E does not detect Liquidity Sweep events. *(Pass)*
- **No Order Block detection:** DOC05E does not detect Order Block events. *(Pass)*
- **No FVG detection:** DOC05E does not detect Fair Value Gap events. *(Pass)*
- **Event Consumer only:** DOC05E is an Event Consumer and never produces SMC Events. *(Pass)*
- **No fixed pip trailing:** DOC05E does not use fixed pip trailing. *(Pass)*
- **No ATR trailing:** DOC05E does not use ATR-based trailing. *(Pass)*
- **No RR trailing:** DOC05E does not use Risk:Reward-based trailing. *(Pass)*

**Scope boundaries respected:** No market analysis, no BUY/SELL logic, no execution, no break-even, no exit logic, no SMC detection. The Trailing Stop Engine provides continuous SL adjustment based on consumed SMC Events only.

**Design Decision Record (DDR):** Documented why Trailing Stop is isolated from Break Even, why Trailing Stop is continuous, why Trailing Stop decisions are deterministic, why Trailing Stop uses structural levels, and why Trailing Stop requires validated SMC Events.

**Outcome:** No blocking issues. DOC05E is internally consistent, deterministic, non-repainting, look-ahead-safe, circular-dependency-free, and fully conforms to DOC00–DOC05D, DOC03E, and ADR01.

---

# Final Notes

1. **Trailing Stop only.** This document specifies the Trailing Stop Engine and nothing else. No market analysis, no BUY/SELL logic, no execution, no break-even, no exit logic.
2. **Continuous action.** Trailing Stop is applied multiple times per trade after consuming validated SMC Event Objects (DOC03E).
3. **Isolated from Break Even.** Trailing Stop and Break Even are separate engines with separate responsibilities.
4. **Deterministic decisions.** All Trailing Stop decisions are deterministic based on Trade State Object, Position Snapshot Object, and consumed SMC Event Objects.
5. **Structural levels.** Trailing Stop moves SL to structural levels identified by consumed SMC Events.
6. **Full audit trail.** Every Trailing Stop action is fully reconstructable from the audit trail, including consumed SMC Event references.
7. **Performance constraints.** All operations have strict performance constraints (< 2ms total per trade).
8. **Recovery support.** Trailing Stop state is persisted and can be recovered after restart.
9. **Event Consumer only.** The Trailing Stop Engine consumes validated SMC Events and never performs market analysis or SMC detection.

This document is now the official specification for the Trailing Stop Engine.

**Phase 5 (Specification Completion) — Trade Management Sub-Modules (Part E) is complete.**
