# DOC05I — Runtime Execution Policy

## Official Runtime Execution Policy

**Document Status:** AUTHORITATIVE  
**Version:** 1.0  
**Last Updated:** 2026-07-10  
**Phase:** Phase 5.5 (Architecture Hardening)

---

## 1. Executive Summary

The Runtime Execution Policy defines the official runtime behavior of BOT_SMC. It specifies HOW the architecture behaves while the Expert Advisor is running, formalizing runtime execution rules before implementation begins.

**Purpose:**
- Define EA lifecycle (initialization, runtime loop, shutdown, recovery)
- Specify event processing model (queue, priority, ordering, lifetime)
- Define tick processing policy (OnTick behavior, closed bar discipline)
- Specify multi-timeframe synchronization (H4/H1/M15 processing order)
- Define gate evaluation policy (execution order, failure behavior)
- Specify runtime state management (transitions, atomic updates)
- Define runtime error handling (recoverable/non-recoverable errors)
- Specify performance rules (tick processing, queue processing)
- Validate runtime behavior (deterministic execution, no race conditions)

**Out of Scope:**
- New business logic
- Implementation code
- Architectural changes

---

## 2. Runtime Model

### 2.1 EA Lifecycle

```
OnInit()
    ↓
Initialize Infrastructure (DOC05A)
    ├─ Configuration Service
    ├─ Persistence Service
    ├─ Logging Service
    ├─ Error Handling Service
    ├─ Clock/Time Service
    └─ Utility Service
    ↓
Load Persisted State (DOC04E)
    ├─ Trade State Objects
    ├─ Position Snapshot Objects
    ├─ Execution Result Objects
    ├─ Break Even State Objects
    ├─ Trailing Stop State Objects
    ├─ Exit State Objects
    └─ Statistics Object
    ↓
Initialize Detection Engines (DOC02A-F)
    ├─ Market Structure Engine
    ├─ BOS Engine
    ├─ CHoCH Engine
    ├─ Liquidity Engine
    ├─ Order Block Engine
    └─ FVG Engine
    ↓
Initialize Trading Intelligence (DOC03A-E)
    ├─ Trade Context Manager
    ├─ Confluence Engine
    ├─ Entry Decision Engine
    ├─ Trade State Machine
    └─ SMC Event Object
    ↓
Initialize Execution (DOC04A-E)
    ├─ Execution Framework
    ├─ Execution Validation Engine
    ├─ Order Submission Engine
    ├─ Position Lifecycle Tracker
    └─ System Recovery Engine
    ↓
Initialize Trade Management (DOC05C-G)
    ├─ Trade Management Framework
    ├─ Break Even Engine
    ├─ Trailing Stop Engine
    ├─ Exit Completion Engine
    └─ Trade Statistics Analytics
    ↓
Runtime Loop
    ↓
OnDeinit()
    ↓
Safe Shutdown
```

### 2.2 Initialization

**OnInit() Responsibilities:**
1. Initialize all infrastructure services (DOC05A)
2. Load configuration from config.ini
3. Load persisted state from disk (DOC04E)
4. Validate state integrity (checksum)
5. If valid, restore state
6. If corrupt, start with clean state, log warning
7. Initialize all detection engines (DOC02A-F)
8. Initialize all trading intelligence modules (DOC03A-E)
9. Initialize all execution modules (DOC04A-E)
10. Initialize all trade management modules (DOC05C-G)
11. Log initialization status
12. Return INIT_SUCCEEDED or INIT_FAILED

**Initialization Order:**
- Infrastructure first (foundation layer)
- Then detection engines (require infrastructure)
- Then trading intelligence (requires detection)
- Then execution (requires trading intelligence)
- Then trade management (requires execution)

### 2.3 Runtime Loop

**OnTick() Responsibilities:**
1. Receive tick from MT5 platform
2. Validate tick freshness (DOC05B Tick Freshness Gate)
3. Check HALT gate (DOC05B HALT Gate)
4. If HALTED, skip processing
5. Check position limit gate (DOC05B Position Limit Gate)
6. If position limit exceeded, skip processing
7. Check if new bar closed (H4/H1/M15)
8. If new bar closed:
   - Process H4 bar (if closed)
   - Process H1 bar (if closed)
   - Process M15 bar (if closed)
9. If tick data available:
   - Update position snapshots (DOC04D)
   - Apply break even (DOC05D)
   - Apply trailing stop (DOC05E)
   - Check exit conditions (DOC05F)
10. Log tick processing status

**Runtime Loop Order:**
- Tick validation first (cheap check)
- Gate evaluation second (operational checks)
- Bar processing third (structural analysis)
- Tick data processing fourth (management actions)

### 2.4 Shutdown

**OnDeinit() Responsibilities:**
1. Stop all processing
2. Persist all state objects (DOC05A)
3. Flush all logs (DOC05A)
4. Close all files
5. Release all resources
6. Log shutdown status

**Shutdown Order:**
- Trade management first (save current state)
- Then execution (save execution state)
- Then trading intelligence (save decision state)
- Then detection engines (save detection state)
- Then infrastructure (save infrastructure state)

### 2.5 Recovery Startup

**Recovery Startup Responsibilities:**
1. Detect recovery scenario (restart, disconnection, crash)
2. Load persisted state from disk (DOC04E)
3. Validate state integrity (checksum)
4. If valid, restore state
5. If corrupt, start with clean state, log warning
6. Verify broker state (DOC04E)
7. Reconcile internal state with broker state
8. Resume normal operation

**Recovery Scenarios:**
- EA restart (manual or automatic)
- Platform restart (MT5 terminal restart)
- System restart (computer restart)
- Disconnection recovery (terminal reconnection)

---

## 3. Event Processing Model

### 3.1 Event Queue

**Event Queue Characteristics:**
- FIFO (First In, First Out) ordering
- Bounded size (configurable, default: 1000 events)
- Thread-safe (single-threaded access)
- Persistent (survives restart)

**Event Queue Operations:**
- Enqueue: Add event to queue
- Dequeue: Remove event from queue
- Peek: View event without removing
- Size: Get queue size
- Clear: Clear all events

### 3.2 Event Priority

**Event Priority Levels:**
- HIGH: Critical events (TRADE_CLOSED, STRUCTURE_SHIFT_CONFIRMED)
- MEDIUM: Important events (BOS_CONFIRMED, CHoCH_CONFIRMED, TRADE_UPDATED)
- LOW: Informational events (STATISTICS_UPDATED, TRADE_ARCHIVED)

**Priority Processing:**
- Events processed in FIFO order within same priority
- Higher priority events processed first when queue is full
- Priority does not override timestamp ordering

### 3.3 Event Ordering

**Event Ordering Rules:**
- Events ordered by timestamp (milliseconds precision)
- Events with same timestamp ordered by event_id (UUID)
- FIFO ordering guaranteed by event bus (DOC05A)

**Ordering Validation:**
- Event bus validates ordering before publishing
- Out-of-order events rejected with error
- Ordering violations logged for investigation

### 3.4 Event Lifetime

**Event Lifetime Rules:**
- Events expire after configured lifetime (see DOC05H)
- Expired events discarded without processing
- Lifetime validated by event bus before processing

**Lifetime by Category:**
- Market Structure Events: 24-72 hours
- Trade Events: Until trade closed
- Lifecycle Events: Until trade closed/archived
- Analytics Events: 365 days

### 3.5 Queue Overflow Policy

**Queue Overflow Handling:**
- When queue reaches 90% capacity, log warning
- When queue reaches 100% capacity, reject new events
- Rejected events logged with rejection reason
- Overflow does not affect existing events

**Overflow Recovery:**
- Process existing events to reduce queue size
- Resume accepting events when queue < 90%
- Log recovery status

### 3.6 Event Deduplication

**Deduplication Rules:**
- Each event processed exactly once per event_id
- Duplicate events (same event_id) ignored
- Deduplication guaranteed by event bus

**Deduplication Validation:**
- Event bus validates event_id uniqueness
- Duplicate events rejected with info log
- Deduplication violations logged for investigation

### 3.7 Event Replay Policy

**Replay Rules:**
- Events can be replayed for backtesting
- Replay preserves original timestamp and event_id
- Replay does not modify event data

**Replay Validation:**
- Replay mode validated by event bus
- Replay events marked with replay flag
- Replay violations logged for investigation

---

## 4. Tick Processing Policy

### 4.1 OnTick Behavior

**OnTick() Processing Order:**
1. Receive tick from MT5 platform
2. Validate tick freshness
3. Check HALT gate
4. Check position limit gate
5. Check if new bar closed
6. Process bar if closed
7. Update position snapshots
8. Apply break even
9. Apply trailing stop
10. Check exit conditions
11. Log tick processing status

**OnTick() Performance:**
- Tick processing < 1 ms
- No blocking operations
- No network calls
- No file I/O

### 4.2 Closed Bar Discipline

**Closed Bar Rules:**
- All detection uses only closed bars
- No forming-bar data used for detection
- Closed bar validated by Market Data Access (DOC01)
- Closed bar timestamp = bar close time

**Closed Bar Validation:**
- Market Data Access validates bar closure
- Forming bars rejected for detection
- Closed bar violations logged for investigation

### 4.3 Tick Filtering

**Tick Filtering Rules:**
- Invalid ticks discarded (negative price, zero volume)
- Stale ticks discarded (tick age > MAX_TICK_AGE_SECONDS)
- Duplicate ticks discarded (same timestamp)

**Tick Filtering Validation:**
- Market Data Access validates tick data
- Invalid ticks rejected with warning
- Tick filtering violations logged for investigation

### 4.4 Tick Freshness

**Tick Freshness Rules:**
- Tick age = Current_Time - Tick_Timestamp
- Tick freshness validated by Tick Freshness Gate (DOC05B)
- Stale ticks discarded (tick age > MAX_TICK_AGE_SECONDS, default: 5 seconds)

**Tick Freshness Validation:**
- Tick Freshness Gate validates tick age
- Stale ticks rejected with warning
- Tick freshness violations logged for investigation

### 4.5 Tick Validation

**Tick Validation Rules:**
- Tick price > 0
- Tick volume >= 0
- Tick timestamp valid
- Tick symbol matches EA symbol

**Tick Validation Validation:**
- Market Data Access validates tick data
- Invalid ticks rejected with error
- Tick validation violations logged for investigation

### 4.6 Tick Discard Conditions

**Tick Discard Conditions:**
- Tick is stale (age > MAX_TICK_AGE_SECONDS)
- Tick is invalid (negative price, zero volume)
- Tick is duplicate (same timestamp)
- Tick symbol mismatch
- HALT gate failed
- Position limit gate failed

**Tick Discard Logging:**
- All discarded ticks logged with discard reason
- Discard rate monitored for performance issues
- Excessive discards trigger investigation

---

## 5. Multi-Timeframe Synchronization

### 5.1 H4 Processing

**H4 Processing Responsibilities:**
- Detect H4 bar close
- Update H4 bias (DOC02A)
- Update H4 structure (DOC02A)
- Generate H4 events (INTERNAL_STRUCTURE, EXTERNAL_STRUCTURE, STRUCTURE_SHIFT, TREND_CONTINUATION)

**H4 Processing Order:**
1. Detect H4 bar close
2. Validate H4 bar closure
3. Update H4 bias
4. Update H4 structure
5. Generate H4 events
6. Publish H4 events to event bus
7. Log H4 processing status

### 5.2 H1 Processing

**H1 Processing Responsibilities:**
- Detect H1 bar close
- Update H1 swings (DOC02A)
- Detect BOS (DOC02B)
- Detect CHoCH (DOC02C)
- Detect liquidity sweeps (DOC02D)
- Detect order blocks (DOC02EB)
- Detect FVGs (DOC02F)
- Generate H1 events (BOS_CONFIRMED, CHoCH_CONFIRMED, LIQUIDITY_SWEEP_CONFIRMED, ORDER_BLOCK_CONFIRMED, FAIR_VALUE_GAP_CONFIRMED)

**H1 Processing Order:**
1. Detect H1 bar close
2. Validate H1 bar closure
3. Update H1 swings
4. Detect BOS
5. Detect CHoCH
6. Detect liquidity sweeps
7. Detect order blocks
8. Detect FVGs
9. Generate H1 events
10. Publish H1 events to event bus
11. Log H1 processing status

### 5.3 M15 Processing

**M15 Processing Responsibilities:**
- Detect M15 bar close
- Build trade context (DOC03A)
- Validate confluence (DOC03B)
- Make entry decision (DOC03C)
- Update trade state machine (DOC03D)
- Generate M15 events (TRADE_STARTED, TRADE_UPDATED, TRADE_CLOSING, TRADE_CLOSED)

**M15 Processing Order:**
1. Detect M15 bar close
2. Validate M15 bar closure
3. Build trade context
4. Validate confluence
5. Make entry decision
6. Update trade state machine
7. Generate M15 events
8. Publish M15 events to event bus
9. Log M15 processing status

### 5.4 Synchronization Order

**Synchronization Order:**
1. H4 processing (if H4 bar closed)
2. H1 processing (if H1 bar closed)
3. M15 processing (if M15 bar closed)

**Synchronization Rationale:**
- H4 provides bias (highest timeframe)
- H1 provides structure (middle timeframe)
- M15 provides execution (lowest timeframe)
- Higher timeframes processed first (dependency order)

### 5.5 Simultaneous Bar Close Handling

**Simultaneous Bar Close Rules:**
- If multiple timeframes close simultaneously, process in order: H4 → H1 → M15
- Each timeframe processed completely before next
- No interleaving of timeframe processing

**Simultaneous Bar Close Validation:**
- Event bus validates processing order
- Interleaving rejected with error
- Processing order violations logged for investigation

### 5.6 Cross-Timeframe Consistency

**Cross-Timeframe Consistency Rules:**
- H4 bias must be consistent with H1 structure
- H1 structure must be consistent with M15 execution
- Inconsistencies logged for investigation

**Cross-Timeframe Consistency Validation:**
- Trade Context Manager validates consistency
- Inconsistencies rejected with warning
- Consistency violations logged for investigation

---

## 6. Gate Evaluation Policy

### 6.1 Evaluation Sequence

**Gate Evaluation Order (per DOC05B):**
1. Terminal Gate
2. Broker Gate
3. Recovery Gate
4. HALT Gate
5. Position Limit Gate
6. Session Gate
7. Market Gate
8. Spread Gate
9. Tick Freshness Gate
10. Bar Completion Gate

**Evaluation Rationale:**
- Cheap gates first (terminal, broker, recovery, halt, position limit)
- Medium gates second (session, market, spread)
- Expensive gates last (tick freshness, bar completion)
- Short-circuit on first failure

### 6.2 Failure Behavior

**Gate Failure Behavior:**
- First gate failure blocks pipeline
- No further gates evaluated
- Failure logged with gate name and reason
- Recovery recommendation logged

**Gate Failure Logging:**
- All gate failures logged at WARN level
- Failure rate monitored for performance issues
- Excessive failures trigger investigation

### 6.3 Recovery Behavior

**Gate Recovery Behavior:**
- Recoverable gates: retry on next tick
- Non-recoverable gates: manual intervention required
- Recovery status logged

**Gate Recovery Logging:**
- All gate recoveries logged at INFO level
- Recovery rate monitored for performance issues
- Excessive recoveries trigger investigation

---

## 7. Runtime State Management

### 7.1 State Transitions

**State Transition Rules:**
- State transitions are atomic
- No partial transitions
- Transition validated before execution
- Failed transitions rolled back

**State Transition Validation:**
- State Manager validates transitions
- Invalid transitions rejected with error
- Transition violations logged for investigation

### 7.2 Atomic Updates

**Atomic Update Rules:**
- All state updates are atomic
- No partial updates
- Update validated before execution
- Failed updates rolled back

**Atomic Update Validation:**
- State Manager validates updates
- Invalid updates rejected with error
- Update violations logged for investigation

### 7.3 State Synchronization

**State Synchronization Rules:**
- State synchronized with broker on every tick
- Inconsistencies logged for investigation
- Reconciliation performed on recovery

**State Synchronization Validation:**
- State Manager validates synchronization
- Inconsistencies rejected with warning
- Synchronization violations logged for investigation

### 7.4 Recovery Synchronization

**Recovery Synchronization Rules:**
- State synchronized with broker on recovery
- Inconsistencies resolved (prefer broker state)
- Reconciliation logged

**Recovery Synchronization Validation:**
- System Recovery Engine validates synchronization
- Inconsistencies resolved with warning
- Recovery synchronization violations logged for investigation

---

## 8. Runtime Error Handling

### 8.1 Recoverable Errors

**Recoverable Error Categories:**
- BROKER_ERROR (timeout, requote)
- MARKET_DATA_ERROR (stale tick)
- PERSISTENCE_ERROR (save failure)
- EXECUTION_ERROR (retry allowed)

**Recoverable Error Handling:**
- Retry with backoff (configurable)
- Max retries: 3
- If retries exhausted, escalate to non-recoverable

**Recoverable Error Logging:**
- All recoverable errors logged at WARN level
- Retry attempts logged
- Escalation logged

### 8.2 Non-Recoverable Errors

**Non-Recoverable Error Categories:**
- CONFIG_ERROR (missing required config)
- SYSTEM_ERROR (out of memory)
- PERSISTENCE_ERROR (corrupt state)
- UNKNOWN_ERROR (unhandled exception)

**Non-Recoverable Error Handling:**
- Immediate shutdown
- Safe shutdown procedure
- Log error with full context

**Non-Recoverable Error Logging:**
- All non-recoverable errors logged at FATAL level
- Full context logged
- Shutdown logged

### 8.3 Retry Policy

**Retry Policy Rules:**
- Max retries: 3 (configurable)
- Backoff: exponential (1s, 2s, 4s)
- Retry only for recoverable errors
- No retry for non-recoverable errors

**Retry Policy Validation:**
- Error Handling Service validates retry policy
- Invalid retries rejected with error
- Retry policy violations logged for investigation

### 8.4 Safe Shutdown

**Safe Shutdown Procedure:**
1. Stop all processing
2. Persist all state objects
3. Flush all logs
4. Close all files
5. Release all resources
6. Log shutdown status

**Safe Shutdown Validation:**
- System Recovery Engine validates shutdown
- Incomplete shutdown logged with error
- Shutdown violations logged for investigation

### 8.5 Emergency Halt

**Emergency Halt Procedure:**
1. Set HALT flag
2. Stop all processing
3. Persist HALT flag
4. Log halt status
5. Wait for manual reset

**Emergency Halt Validation:**
- System Recovery Engine validates halt
- Incomplete halt logged with error
- Halt violations logged for investigation

---

## 9. Performance Rules

### 9.1 Tick Processing

**Tick Processing Performance:**
- Tick processing < 1 ms
- No blocking operations
- No network calls
- No file I/O

**Tick Processing Monitoring:**
- Tick processing time monitored
- Excessive processing time triggers investigation
- Performance metrics logged

### 9.2 Queue Processing

**Queue Processing Performance:**
- Queue processing < 5 ms per event
- No blocking operations
- No network calls
- No file I/O

**Queue Processing Monitoring:**
- Queue processing time monitored
- Queue size monitored
- Excessive processing time or size triggers investigation
- Performance metrics logged

### 9.3 State Updates

**State Update Performance:**
- State update < 10 ms
- Atomic updates
- No blocking operations

**State Update Monitoring:**
- State update time monitored
- Excessive update time triggers investigation
- Performance metrics logged

### 9.4 Event Propagation

**Event Propagation Performance:**
- Event propagation < 1 ms per event
- No blocking operations
- No network calls
- No file I/O

**Event Propagation Monitoring:**
- Event propagation time monitored
- Excessive propagation time triggers investigation
- Performance metrics logged

---

## 10. Runtime Validation

### 10.1 Deterministic Execution

**Deterministic Execution Rules:**
- Identical input produces identical output
- No randomness
- No time-dependent behavior (except timestamps)
- No external dependencies (except broker)

**Deterministic Execution Validation:**
- Runtime Validation Service validates determinism
- Non-deterministic behavior logged with error
- Determinism violations logged for investigation

### 10.2 No Race Conditions

**Race Condition Rules:**
- Single-threaded execution
- No concurrent access to shared state
- No race conditions possible

**Race Condition Validation:**
- Runtime Validation Service validates thread safety
- Race conditions logged with error
- Thread safety violations logged for investigation

### 10.3 No Circular Execution

**Circular Execution Rules:**
- No circular dependencies
- No circular execution paths
- No infinite loops

**Circular Execution Validation:**
- Runtime Validation Service validates execution paths
- Circular execution logged with error
- Circular execution violations logged for investigation

### 10.4 Closed Bar Compliance

**Closed Bar Compliance Rules:**
- All detection uses only closed bars
- No forming-bar data used for detection
- Closed bar validated by Market Data Access

**Closed Bar Compliance Validation:**
- Runtime Validation Service validates closed bar compliance
- Forming bar usage logged with error
- Closed bar violations logged for investigation

### 10.5 Event Ordering Consistency

**Event Ordering Consistency Rules:**
- Events ordered by timestamp
- FIFO ordering guaranteed by event bus
- No out-of-order events

**Event Ordering Consistency Validation:**
- Runtime Validation Service validates event ordering
- Out-of-order events logged with error
- Event ordering violations logged for investigation

---

## Self Review

✅ **No New Business Logic**
- Document formalizes runtime behavior only
- No new trading rules introduced
- No new SMC concepts defined

✅ **No Implementation Code**
- Document is specification only
- No MQL5 code included
- No pseudo-code included

✅ **Runtime Behavior Only**
- Document defines runtime execution rules
- No architectural changes
- No business logic changes

✅ **Consistent with All Approved Documents**
- All contracts consistent with approved documents
- All runtime rules consistent with DOC00-DOC05H
- Verified against PROJECT_MANIFEST.md and ARCHITECTURE_MAP.md

✅ **Ready for Implementation**
- All runtime rules formalized
- All performance rules specified
- All validation rules defined
- Architecture validated

---

## Document End

**DOC05I_Runtime_Execution_Policy.md** — Official Runtime Execution Policy  
**Version:** 1.0  
**Status:** APPROVED  
**Date:** 2026-07-10  
**Phase:** Phase 5.5 (Architecture Hardening) — COMPLETE
