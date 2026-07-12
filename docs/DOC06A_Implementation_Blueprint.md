# DOC06A — Implementation Blueprint

## Official Implementation Blueprint for BOT_SMC

**Document Status:** AUTHORITATIVE  
**Version:** 1.0  
**Last Updated:** 2026-07-10  
**Phase:** Phase 6 (Implementation Mapping) — Part A  
**Purpose:** Translate approved architecture into implementation-ready blueprint for MetaTrader 5

---

## 1. Executive Summary

DOC06A_Implementation_Blueprint.md is the final architectural document before coding begins. It translates the approved BOT_SMC architecture (DOC00-DOC05J) into an implementation-ready blueprint for MetaTrader 5, mapping every approved document into future implementation components.

**Purpose:**
- Provide clear implementation roadmap for all 32 approved documents
- Define MT5 project structure and folder organization
- Map architecture modules to future MQL5 classes and files
- Establish bootstrap architecture for EA startup/shutdown
- Define build strategy and dependency order
- Summarize implementation principles derived from architecture
- Confirm readiness for skeleton project creation

**Out of Scope:**
- New business logic
- MQL5 implementation code
- Architectural changes
- Testing implementation

---

## 2. Project Structure

### 2.1 Root Folder Structure

```
BOT_SMC/
├── docs/                    # All approved documentation
├── src/                     # Source code (MQL5 implementation)
├── include/                 # Header files (.mqh)
├── config/                  # Configuration files
├── data/                    # Runtime data
├── tests/                   # Test implementation
└── README.md                # Project documentation
```

### 2.2 Source Folder Structure

```
src/
├── Infrastructure/          # Layer 0 (DOC05A)
├── MarketAnalysis/          # Layer 2 (DOC02A-F)
├── TradingIntelligence/     # Layer 4 (DOC03A-E)
├── Execution/               # Layer 5 (DOC04A-E)
├── Gates/                   # Layer 3 (DOC05B)
└── TradeManagement/         # Layer 6 (DOC05C-G)
```

**Responsibilities:**
- **Infrastructure/**: Foundational services (Configuration, Persistence, Logging, Error Handling, Clock/Time, Utility, Identifier Generation, Project Constants, Version Management)
- **MarketAnalysis/**: SMC structure detection (Market Structure, BOS, CHoCH, Liquidity, Order Block, Fair Value Gap)
- **TradingIntelligence/**: Trading decisions (Trade Context, Confluence, Entry Decision, Trade State Machine, SMC Event Object)
- **Execution/**: Order execution (Execution Framework, Validation, Order Submission, Position Lifecycle, System Recovery)
- **Gates/**: Operational validation (10 gates: Terminal, Broker, Session, Market, Spread, Tick Freshness, Bar Completion, Recovery, HALT, Position Limit)
- **TradeManagement/**: Position lifecycle (Trade Management Framework, Break Even, Trailing Stop, Exit Completion, Statistics)

### 2.3 Include Folder Structure

```
include/
├── Infrastructure/          # Layer 0 headers
├── MarketAnalysis/          # Layer 2 headers
├── TradingIntelligence/     # Layer 4 headers
├── Execution/               # Layer 5 headers
├── Gates/                   # Layer 3 headers
├── TradeManagement/         # Layer 6 headers
├── Common/                  # Shared utilities
└── Constants/               # Project constants
```

**Responsibilities:**
- **Infrastructure/**: Header files for infrastructure services
- **MarketAnalysis/**: Header files for detection engines
- **TradingIntelligence/**: Header files for decision modules
- **Execution/**: Header files for execution modules
- **Gates/**: Header files for gate modules
- **TradeManagement/**: Header files for trade management modules
- **Common/**: Shared utility headers
- **Constants/**: Project constant definitions

### 2.4 Configuration Folder

```
config/
└── config.ini               # Runtime configuration
```

**Responsibilities:**
- Store runtime configuration parameters
- Define broker settings (BrokerUTCOffset, magic number, slippage cap)
- Define logging settings (log level, log path, log retention)
- Define persistence settings (persistence path, auto-save interval, max archive size)

### 2.5 Data Folder Structure

```
data/
├── state/                   # Persisted state objects
├── archive/                 # Archived historical data
└── logs/                    # Log files
```

**Responsibilities:**
- **state/**: Store persisted state objects (Trade State, Position Snapshot, Execution Result, Break Even State, Trailing Stop State, Exit State, Statistics)
- **archive/**: Store archived historical data (completed trades, execution history)
- **logs/**: Store log files (ea.log, ea.log.1, ea.log.2, etc.)

### 2.6 Tests Folder Structure

```
tests/
├── Infrastructure/          # Layer 0 tests
├── MarketAnalysis/          # Layer 2 tests
├── TradingIntelligence/     # Layer 4 tests
├── Execution/               # Layer 5 tests
├── Gates/                   # Layer 3 tests
├── TradeManagement/         # Layer 6 tests
└── Integration/             # Integration tests
```

**Responsibilities:**
- **Infrastructure/**: Unit tests for infrastructure services
- **MarketAnalysis/**: Unit tests for detection engines
- **TradingIntelligence/**: Unit tests for decision modules
- **Execution/**: Unit tests for execution modules
- **Gates/**: Unit tests for gate modules
- **TradeManagement/**: Unit tests for trade management modules
- **Integration/**: Integration tests across all layers

---

## 3. Implementation Mapping

### 3.1 Phase 0: Strategy Validation (DOC00, DOC00_PATCH_001)

**DOC00_Strategy_Validation.md**
- **Future Class/Module**: CProjectConstants
- **Folder Location**: include/Constants/
- **Responsibility**: Define all locked project constants (SFS=2, ELT=20, FVG Min Size=10, SL Buffer=20, Break-Even Buffer=5, MaxRiskPerTradePoints=1500, LOT_SIZE=0.01, RISK_REWARD_RATIO=1:2, MAX_OPEN_POSITIONS=1, EQUITY_KILL_THRESHOLD=0.50)
- **Dependencies**: None

**DOC00_PATCH_001.md**
- **Future Class/Module**: CProjectConstants (extended)
- **Folder Location**: include/Constants/
- **Responsibility**: Define timeframe constants (PRIMARY_TREND_TIMEFRAME=H4, MARKET_STRUCTURE_TIMEFRAME=H1, EXECUTION_TIMEFRAME=M15) and session constants (LONDON_SESSION_START=07:00, LONDON_SESSION_END=10:00, NEW_YORK_AM_SESSION_START=12:00, NEW_YORK_AM_SESSION_END=15:00)
- **Dependencies**: CProjectConstants

### 3.2 Phase 1: System Architecture (DOC01)

**DOC01_System_Architecture.md**
- **Future Class/Module**: CMarketDataAccess, CStructuralContext
- **Folder Location**: src/Infrastructure/, include/Infrastructure/
- **Responsibility**: 
  - CMarketDataAccess: Provide closed-bar OHLC for H4/H1/M15, enforce closed-bar discipline, cache latest bar per timeframe
  - CStructuralContext: Maintain shared per-bar read-only snapshot of market structure
- **Dependencies**: CConfigurationService, CLoggingService, CErrorHandlingService

### 3.3 Phase 2: Market Analysis (DOC02A-F)

**DOC02A_MarketStructure_Foundation.md**
- **Future Class/Module**: CMarketStructureEngine
- **Folder Location**: src/MarketAnalysis/, include/MarketAnalysis/
- **Responsibility**: Detect swing highs/lows (SFS=2, strict inequality, closed-bar confirmation), maintain structure state (INITIAL/UNKNOWN/BULLISH/BEARISH/INVALID)
- **Dependencies**: CMarketDataAccess, CStructuralContext

**DOC02B_Break_of_Structure_Engine.md**
- **Future Class/Module**: CBOSEngine
- **Folder Location**: src/MarketAnalysis/, include/MarketAnalysis/
- **Responsibility**: Detect BOS events (body-close confirmation, continuation only), generate BOS_CONFIRMED events
- **Dependencies**: CMarketStructureEngine, CStructuralContext

**DOC02C_Change_of_Character_Engine.md**
- **Future Class/Module**: CCHoCHEngine
- **Folder Location**: src/MarketAnalysis/, include/MarketAnalysis/
- **Responsibility**: Detect CHoCH events (body-close confirmation, reversal only), generate CHoCH_CONFIRMED events, maintain Prevailing Direction
- **Dependencies**: CMarketStructureEngine, CStructuralContext

**DOC02D_Liquidity_Engine.md**
- **Future Class/Module**: CLiquidityEngine
- **Folder Location**: src/MarketAnalysis/, include/MarketAnalysis/
- **Responsibility**: Detect liquidity levels (BSL/SSL), detect liquidity sweeps (wick beyond ELT, close back inside), generate LIQUIDITY_SWEEP_CONFIRMED events
- **Dependencies**: CMarketStructureEngine, CStructuralContext

**DOC02EA_OrderBlock_Reference_Validation.md**
- **Future Class/Module**: COrderBlockValidator
- **Folder Location**: src/MarketAnalysis/, include/MarketAnalysis/
- **Responsibility**: Validate Order Block candidates against DOC00 §14 criteria
- **Dependencies**: CMarketStructureEngine, CBOSEngine, CCHoCHEngine

**DOC02EB_OrderBlock_Engine.md**
- **Future Class/Module**: COrderBlockEngine
- **Folder Location**: src/MarketAnalysis/, include/MarketAnalysis/
- **Responsibility**: Detect Order Blocks (last opposite-body candle before BOS/CHoCH impulse), manage OB lifecycle (CANDIDATE/CONFIRMED/ACTIVE/MITIGATED/INVALIDATED/EXPIRED/ARCHIVED), generate ORDER_BLOCK_CONFIRMED and MITIGATION_CONFIRMED events
- **Dependencies**: CMarketStructureEngine, CBOSEngine, CCHoCHEngine, COrderBlockValidator

**DOC02F_FairValueGap_Engine.md**
- **Future Class/Module**: CFVGEngine
- **Folder Location**: src/MarketAnalysis/, include/MarketAnalysis/
- **Responsibility**: Detect FVGs (3-candle imbalance pattern, FVG Min Size=10), manage FVG lifecycle (CANDIDATE/CONFIRMED/ACTIVE/PARTIALLY_FILLED/FILLED/INVALIDATED/EXPIRED/ARCHIVED), generate FAIR_VALUE_GAP_CONFIRMED and MITIGATION_CONFIRMED events
- **Dependencies**: CMarketStructureEngine, CStructuralContext

### 3.4 Phase 3: Trading Intelligence (DOC03A-E)

**DOC03A_Trading_Intelligence_Blueprint.md**
- **Future Class/Module**: CTradeContextManager
- **Folder Location**: src/TradingIntelligence/, include/TradingIntelligence/
- **Responsibility**: Build Trade Context Object from Structural Context + Market Data + Account State
- **Dependencies**: CStructuralContext, CMarketDataAccess, CAccountInfo

**DOC03B_Confluence_Engine.md**
- **Future Class/Module**: CConfluenceEngine
- **Folder Location**: src/TradingIntelligence/, include/TradingIntelligence/
- **Responsibility**: Validate confluence using STRICT AND mechanism (all conditions must be met)
- **Dependencies**: CTradeContextManager

**DOC03C_Entry_Decision_Engine.md**
- **Future Class/Module**: CEntryDecisionEngine
- **Folder Location**: src/TradingIntelligence/, include/TradingIntelligence/
- **Responsibility**: Make entry decision (ENTER_LONG/ENTER_SHORT/NO_ENTRY) based on confluence validation
- **Dependencies**: CConfluenceEngine

**DOC03D_Trade_State_Machine.md**
- **Future Class/Module**: CTradeStateMachine
- **Folder Location**: src/TradingIntelligence/, include/TradingIntelligence/
- **Responsibility**: Manage trade lifecycle state transitions (NEW/VALIDATED/READY/EXECUTING/EXECUTED/FAILED/EXPIRED/CANCELLED/ARCHIVED)
- **Dependencies**: CEntryDecisionEngine

**DOC03E_SMC_Event_Object.md**
- **Future Class/Module**: CSMCEventObject, CSMCEventBus
- **Folder Location**: src/TradingIntelligence/, include/TradingIntelligence/
- **Responsibility**: 
  - CSMCEventObject: Define immutable SMC event structure (event_id, source_module, event_type, timestamp, timeframe, symbol, validation_status, dependencies, priority, version, audit, payload)
  - CSMCEventBus: Manage event distribution, FIFO ordering, idempotency, replay
- **Dependencies**: None (foundation for event-driven communication)

### 3.5 Phase 4: Execution Layer (DOC04A-E)

**DOC04A_Execution_Framework.md**
- **Future Class/Module**: CExecutionFramework
- **Folder Location**: src/Execution/, include/Execution/
- **Responsibility**: Manage execution pipeline (decision → validation → submission → result)
- **Dependencies**: CTradeStateMachine

**DOC04B_Execution_Validation_Engine.md**
- **Future Class/Module**: CExecutionValidationEngine
- **Folder Location**: src/Execution/, include/Execution/
- **Responsibility**: Validate execution requests (terminal, broker, session, market, spread, tick freshness, bar completion, position limit, recovery, halt)
- **Dependencies**: CExecutionFramework

**DOC04C_Order_Submission_Engine.md**
- **Future Class/Module**: COrderSubmissionEngine
- **Folder Location**: src/Execution/, include/Execution/
- **Responsibility**: Submit orders to broker (OrderSend), handle broker responses (ACCEPTED/REJECTED/TIMEOUT/ERROR)
- **Dependencies**: CExecutionValidationEngine

**DOC04D_Position_Lifecycle_Tracker.md**
- **Future Class/Module**: CPositionLifecycleTracker
- **Folder Location**: src/Execution/, include/Execution/
- **Responsibility**: Track position lifecycle (CREATED/CONFIRMED/ACTIVE/MODIFIED/CLOSED/ARCHIVED), generate position snapshots
- **Dependencies**: COrderSubmissionEngine

**DOC04E_System_Recovery_Consistency_Engine.md**
- **Future Class/Module**: CSystemRecoveryEngine
- **Folder Location**: src/Execution/, include/Execution/
- **Responsibility**: Handle system recovery (restart, disconnection, crash), reconcile internal state with broker state
- **Dependencies**: CPositionLifecycleTracker, CPersistenceService

### 3.6 Phase 5: Specification Completion (DOC05A-G)

**DOC05A_Infrastructure_Blueprint.md**
- **Future Class/Module**: CConfigurationService, CPersistenceService, CLoggingService, CErrorHandlingService, CClockTimeService, CUtilityService, CIdentifierGeneration, CProjectConstants, CVersionManagement
- **Folder Location**: src/Infrastructure/, include/Infrastructure/
- **Responsibility**: 
  - CConfigurationService: Manage project configuration (load from config.ini, validate, provide read-only access)
  - CPersistenceService: Persist and recover state (atomic save philosophy, recovery mechanisms)
  - CLoggingService: Centralized logging (6 levels: TRACE/DEBUG/INFO/WARN/ERROR/FATAL, log rotation, retention)
  - CErrorHandlingService: Error classification and recovery (recoverable/non-recoverable, retry policy, safe shutdown)
  - CClockTimeService: Deterministic time services (broker time, UTC time, session time)
  - CUtilityService: Common utility functions (math, string, validation, conversion)
  - CIdentifierGeneration: Deterministic identifiers (event_id, trade_id, execution_id, etc.)
  - CProjectConstants: Locked project constants (SFS, ELT, buffers, limits)
  - CVersionManagement: Document and code versioning
- **Dependencies**: None (foundation layer)

**DOC05B_Layer3_Gate_Framework.md**
- **Future Class/Module**: CGateFramework (10 gate classes)
- **Folder Location**: src/Gates/, include/Gates/
- **Responsibility**: 
  - CTerminalGate: Verify terminal connection
  - CBrokerGate: Verify broker connection
  - CSessionGate: Verify trading session (London/NY)
  - CMarketGate: Verify market open
  - CSpreadGate: Verify spread limits
  - CTickFreshnessGate: Verify tick freshness
  - CBarCompletionGate: Verify bar complete
  - CRecoveryGate: Verify no active recovery
  - CHALTGate: Verify not halted
  - CPositionLimitGate: Verify position limit
- **Dependencies**: CConfigurationService, CClockTimeService, CMarketDataAccess

**DOC05C_Trade_Management_Framework.md**
- **Future Class/Module**: CTradeManagementFramework
- **Folder Location**: src/TradeManagement/, include/TradeManagement/
- **Responsibility**: Supervise trade lifecycle (CREATED/ACTIVE/MANAGED/CLOSING/CLOSED/ARCHIVED), coordinate Break Even, Trailing Stop, Exit Completion, Statistics
- **Dependencies**: CPositionLifecycleTracker

**DOC05D_Break_Even_Engine.md**
- **Future Class/Module**: CBreakEvenEngine
- **Folder Location**: src/TradeManagement/, include/TradeManagement/
- **Responsibility**: Apply break-even (one-time SL adjustment when profit ≥ 1R), consume validated SMC Events
- **Dependencies**: CTradeManagementFramework, CSMCEventBus

**DOC05E_Trailing_Stop_Engine.md**
- **Future Class/Module**: CTrailingStopEngine
- **Folder Location**: src/TradeManagement/, include/TradeManagement/
- **Responsibility**: Apply trailing stop (continuous SL adjustment based on structural levels), consume validated SMC Events
- **Dependencies**: CTradeManagementFramework, CSMCEventBus, CBreakEvenEngine

**DOC05F_Exit_Completion_Engine.md**
- **Future Class/Module**: CExitCompletionEngine
- **Folder Location**: src/TradeManagement/, include/TradeManagement/
- **Responsibility**: Trigger position closure based on structural signals (CHoCH, BOS against position, liquidity sweep, structure shift), consume validated SMC Events
- **Dependencies**: CTradeManagementFramework, CSMCEventBus

**DOC05G_Trade_Statistics_Analytics.md**
- **Future Class/Module**: CTradeStatisticsAnalytics
- **Folder Location**: src/TradeManagement/, include/TradeManagement/
- **Responsibility**: Collect and calculate trade statistics (total trades, win rate, profit factor, drawdown, duration), read-only analytics
- **Dependencies**: CTradeManagementFramework

### 3.7 Phase 5.5: Architecture Hardening (DOC05H-J)

**DOC05H_Integration_Contract_Registry.md**
- **Future Class/Module**: CIntegrationContractRegistry
- **Folder Location**: src/Infrastructure/, include/Infrastructure/
- **Responsibility**: Formalize integration contracts (event contracts, state object contracts, interface ownership, integration rules)
- **Dependencies**: None (registry document)

**DOC05I_Runtime_Execution_Policy.md**
- **Future Class/Module**: CRuntimeExecutionPolicy
- **Folder Location**: src/Infrastructure/, include/Infrastructure/
- **Responsibility**: Define runtime behavior (EA lifecycle, event processing, tick processing, multi-timeframe synchronization, gate evaluation, state management, error handling, performance rules)
- **Dependencies**: None (policy document)

**DOC05J_Implementation_Readiness_Standard.md**
- **Future Class/Module**: CImplementationReadinessStandard
- **Folder Location**: src/Infrastructure/, include/Infrastructure/
- **Responsibility**: Define implementation standards (non-functional requirements, coding standards, architecture compliance rules, implementation constraints, quality standards, testing readiness)
- **Dependencies**: None (standard document)

### 3.8 Architecture Artifacts

**ARCHITECTURE_MAP.md**
- **Future Class/Module**: None (navigation document)
- **Folder Location**: docs/
- **Responsibility**: Provide visual navigation and architectural reference
- **Dependencies**: None

---

## 4. Bootstrap Architecture

### 4.1 EA Startup (OnInit)

**Initialization Order:**

```
1. Initialize Infrastructure (DOC05A)
   ├─ CConfigurationService (load config.ini, validate)
   ├─ CPersistenceService (initialize persistence)
   ├─ CLoggingService (initialize logging)
   ├─ CErrorHandlingService (initialize error handling)
   ├─ CClockTimeService (initialize time services)
   ├─ CUtilityService (initialize utilities)
   ├─ CIdentifierGeneration (initialize identifier generation)
   ├─ CProjectConstants (initialize constants)
   └─ CVersionManagement (initialize versioning)
   ↓
2. Load Persisted State (DOC04E)
   ├─ Load Trade State Objects
   ├─ Load Position Snapshot Objects
   ├─ Load Execution Result Objects
   ├─ Load Break Even State Objects
   ├─ Load Trailing Stop State Objects
   ├─ Load Exit State Objects
   └─ Load Statistics Object
   ↓
3. Initialize Detection Engines (DOC02A-F)
   ├─ CMarketStructureEngine
   ├─ CBOSEngine
   ├─ CCHoCHEngine
   ├─ CLiquidityEngine
   ├─ COrderBlockEngine
   └─ CFVGEngine
   ↓
4. Initialize Trading Intelligence (DOC03A-E)
   ├─ CTradeContextManager
   ├─ CConfluenceEngine
   ├─ CEntryDecisionEngine
   ├─ CTradeStateMachine
   └─ CSMCEventBus
   ↓
5. Initialize Execution (DOC04A-E)
   ├─ CExecutionFramework
   ├─ CExecutionValidationEngine
   ├─ COrderSubmissionEngine
   ├─ CPositionLifecycleTracker
   └─ CSystemRecoveryEngine
   ↓
6. Initialize Trade Management (DOC05C-G)
   ├─ CTradeManagementFramework
   ├─ CBreakEvenEngine
   ├─ CTrailingStopEngine
   ├─ CExitCompletionEngine
   └─ CTradeStatisticsAnalytics
   ↓
7. Runtime Loop (OnTick)
```

### 4.2 Module Registration

**Registration Order:**
1. Infrastructure services register first (foundation layer)
2. Detection engines register second (require infrastructure)
3. Trading intelligence modules register third (require detection)
4. Execution modules register fourth (require trading intelligence)
5. Trade management modules register fifth (require execution)

### 4.3 Shutdown Sequence (OnDeinit)

**Shutdown Order:**

```
1. Stop All Processing
   ↓
2. Persist All State Objects (DOC05A)
   ├─ Save Trade State Objects
   ├─ Save Position Snapshot Objects
   ├─ Save Execution Result Objects
   ├─ Save Break Even State Objects
   ├─ Save Trailing Stop State Objects
   ├─ Save Exit State Objects
   └─ Save Statistics Object
   ↓
3. Flush All Logs (DOC05A)
   ↓
4. Close All Files
   ↓
5. Release All Resources
   ↓
6. Log Shutdown Status
```

---

## 5. Build Strategy

### 5.1 Build Order

**Recommended Build Order:**

```
1. Infrastructure Layer (DOC05A)
   ├─ CConfigurationService
   ├─ CPersistenceService
   ├─ CLoggingService
   ├─ CErrorHandlingService
   ├─ CClockTimeService
   ├─ CUtilityService
   ├─ CIdentifierGeneration
   ├─ CProjectConstants
   └─ CVersionManagement
   ↓
2. Shared Read Model (DOC01)
   ├─ CMarketDataAccess
   └─ CStructuralContext
   ↓
3. SMC Event Object (DOC03E)
   ├─ CSMCEventObject
   └─ CSMCEventBus
   ↓
4. Market Analysis Layer (DOC02A-F)
   ├─ CMarketStructureEngine
   ├─ CBOSEngine
   ├─ CCHoCHEngine
   ├─ CLiquidityEngine
   ├─ COrderBlockEngine
   └─ CFVGEngine
   ↓
5. Trading Intelligence Layer (DOC03A-D)
   ├─ CTradeContextManager
   ├─ CConfluenceEngine
   ├─ CEntryDecisionEngine
   └─ CTradeStateMachine
   ↓
6. Execution Layer (DOC04A-E)
   ├─ CExecutionFramework
   ├─ CExecutionValidationEngine
   ├─ COrderSubmissionEngine
   ├─ CPositionLifecycleTracker
   └─ CSystemRecoveryEngine
   ↓
7. Gates Layer (DOC05B)
   ├─ CTerminalGate
   ├─ CBrokerGate
   ├─ CSessionGate
   ├─ CMarketGate
   ├─ CSpreadGate
   ├─ CTickFreshnessGate
   ├─ CBarCompletionGate
   ├─ CRecoveryGate
   ├─ CHALTGate
   └─ CPositionLimitGate
   ↓
8. Trade Management Layer (DOC05C-G)
   ├─ CTradeManagementFramework
   ├─ CBreakEvenEngine
   ├─ CTrailingStopEngine
   ├─ CExitCompletionEngine
   └─ CTradeStatisticsAnalytics
```

### 5.2 Dependency Order

**Dependency Resolution:**
- Infrastructure services have no dependencies (foundation)
- Detection engines depend on infrastructure
- Trading intelligence depends on detection
- Execution depends on trading intelligence
- Gates depend on infrastructure
- Trade management depends on execution

### 5.3 Shared Services

**Shared Services:**
- CConfigurationService (used by all modules)
- CLoggingService (used by all modules)
- CErrorHandlingService (used by all modules)
- CClockTimeService (used by all modules)
- CUtilityService (used by all modules)
- CIdentifierGeneration (used by all modules)
- CPersistenceService (used by state management)
- CSMCEventBus (used by event-driven communication)

### 5.4 Common Utilities

**Common Utilities:**
- Math operations (min, max, clamp, abs, round, floor, ceil)
- String formatting (timestamp, price, volume, percentage)
- Data validation (price, volume, timestamp, symbol)
- Type conversion (int, double, string, bool)

---

## 6. Implementation Principles

### 6.1 Layer Isolation

**Principle:** All dependencies flow downward through layers. No upward dependencies. No circular dependencies.

**Implementation:**
- Each module can only depend on same or lower layers
- No module can directly access modules in other layers
- All cross-layer communication via event bus

### 6.2 Event-Driven Communication

**Principle:** All cross-layer communication via event bus. No direct module-to-module communication.

**Implementation:**
- Producer owns event until published
- DOC03E owns event contract specification
- DOC05A owns event archival
- Event bus provides centralized event distribution

### 6.3 Immutable State

**Principle:** State objects immutable after creation. No mid-flight modification. Changes create new objects, not modifications.

**Implementation:**
- All state objects immutable after creation
- Atomic persistence required
- No partial writes possible

### 6.4 Single Responsibility

**Principle:** Each module has exactly one responsibility. No module performs multiple unrelated functions.

**Implementation:**
- Clear module boundaries
- No overlapping responsibilities
- One responsibility per module

### 6.5 Deterministic Execution

**Principle:** Identical input produces identical output. No randomness. No time-dependent behavior (except timestamps). No external dependencies (except broker).

**Implementation:**
- All rules deterministic
- All decisions reproducible
- All events replayable
- All state transitions verifiable

---

## 7. Readiness Assessment

### 7.1 Architecture Completeness

✅ **Architecture Complete:**
- All 32 approved documents completed
- All PAR01 findings resolved
- Architecture frozen and approved
- Production-grade specification achieved

### 7.2 Implementation Readiness

✅ **Implementation Ready:**
- All integration contracts formalized (DOC05H)
- All runtime policies defined (DOC05I)
- All implementation standards established (DOC05J)
- All quality requirements specified
- All readiness criteria validated

### 7.3 Additional Architecture Documents

✅ **No Additional Architecture Required:**
- All architectural aspects covered
- All integration contracts defined
- All runtime policies specified
- All implementation standards established
- Ready for implementation

### 7.4 Next Deliverable

**Next Deliverable:** Skeleton Project

**Skeleton Project Scope:**
- Create MT5 project structure
- Implement infrastructure layer (DOC05A)
- Implement shared read model (DOC01)
- Implement SMC event object (DOC03E)
- Create stub implementations for all modules
- Establish build system
- Create basic test framework

**Skeleton Project Authorization:** GRANTED (2026-07-10)

---

## Self Review

✅ **No Business Logic Added**
- Document describes implementation mapping only
- No new trading rules introduced
- No new SMC concepts defined

✅ **No Code Generated**
- Document is blueprint only
- No MQL5 code included
- No pseudo-code included

✅ **No Architecture Modified**
- All mappings consistent with approved documents
- All principles derived from approved architecture
- Verified against PROJECT_MANIFEST.md and ARCHITECTURE_MAP.md

✅ **Ready to Begin Skeleton Project**
- All implementation mappings defined
- All build strategies specified
- All readiness criteria validated
- Skeleton project authorized

---

## Document End

**DOC06A_Implementation_Blueprint.md** — Official Implementation Blueprint  
**Version:** 1.0  
**Status:** APPROVED  
**Date:** 2026-07-10  
**Phase:** Phase 6 (Implementation Mapping) — Part A — COMPLETE

**Next Deliverable:** Skeleton Project — AUTHORIZED
