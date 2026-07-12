# ARCHITECTURE_MAP.md

## Official Architecture Navigation Document

**Document Status:** AUTHORITATIVE  
**Version:** 1.0  
**Last Updated:** 2026-07-10  
**Purpose:** Visual navigation and architectural reference for BOT_SMC

---

## 1. Architecture Overview

BOT_SMC implements a **7-layer deterministic architecture** for algorithmic trading on XAUUSD/MetaTrader 5.

**Core Principles:**
- Deterministic Design: All rules are programmable and reproducible
- Event-Driven Communication: Modules communicate via validated events
- Immutable State Objects: No mid-flight modification
- Single Responsibility: Each module has one clear purpose
- Closed Bar Discipline: All detection uses only closed bars
- Atomic Persistence: All state saves are atomic
- Zero Human Discretion: Identical input = identical output

**Architecture Layers:**
- Layer 0: Infrastructure (DOC05A)
- Layer 1: Shared Read Model (DOC01)
- Layer 2: Market Analysis (DOC02A-F)
- Layer 3: Gates (DOC05B)
- Layer 4: Trading Intelligence (DOC03A-E)
- Layer 5: Execution (DOC04A-E)
- Layer 6: Trade Management (DOC05C-G)

---

## 2. Layer Architecture

### Layer 0: Infrastructure
**Purpose:** Foundational services used by all higher layers  
**Modules:** Configuration, Persistence, Logging, Error Handling, Clock/Time, Utility, Identifier Generation, Project Constants, Version Management  
**Documents:** DOC05A

### Layer 1: Shared Read Model
**Purpose:** Market data access and structural context  
**Modules:** Market Data Access, Structural Context  
**Documents:** DOC01

### Layer 2: Market Analysis
**Purpose:** SMC structure detection and validation  
**Modules:** Market Structure, BOS, CHoCH, Liquidity, Order Block, Fair Value Gap  
**Documents:** DOC02A-F

### Layer 3: Gates
**Purpose:** Operational validation before trading decisions  
**Modules:** Terminal, Broker, Session, Market, Spread, Tick Freshness, Bar Completion, Recovery, HALT, Position Limit  
**Documents:** DOC05B

### Layer 4: Trading Intelligence
**Purpose:** Trading intelligence and entry decisions  
**Modules:** Trade Context Manager, Confluence Engine, Entry Decision Engine, Trade State Machine, SMC Event Object  
**Documents:** DOC03A-E

### Layer 5: Execution
**Purpose:** Order execution and position management  
**Modules:** Execution Framework, Execution Validation, Order Submission, Position Lifecycle Tracker, System Recovery  
**Documents:** DOC04A-E

### Layer 6: Trade Management
**Purpose:** Position lifecycle supervision  
**Modules:** Trade Management Framework, Break Even Engine, Trailing Stop Engine, Exit Completion Engine, Trade Statistics Analytics  
**Documents:** DOC05C-G

---

## 3. Document Dependency Map

### Root Documents (No Dependencies)
- DOC00_Strategy_Validation.md
- DOC00_PATCH_001.md

### Phase 1: System Architecture
- DOC01 → depends on DOC00, DOC00_PATCH_001

### Phase 2: Market Analysis
- DOC02A → depends on DOC01
- DOC02B → depends on DOC02A
- DOC02C → depends on DOC02A
- DOC02D → depends on DOC02A
- DOC02EA → depends on DOC02A
- DOC02EB → depends on DOC02A, DOC02B, DOC02C
- DOC02F → depends on DOC02A

### Phase 3: Trading Intelligence
- DOC03A → depends on DOC01, DOC02A-F
- DOC03B → depends on DOC03A
- DOC03C → depends on DOC03B
- DOC03D → depends on DOC03C
- DOC03E → depends on DOC02A-F

### Phase 4: Execution Layer
- DOC04A → depends on DOC03D
- DOC04B → depends on DOC04A
- DOC04C → depends on DOC04B
- DOC04D → depends on DOC04C
- DOC04E → depends on DOC04A-D

### Phase 5: Specification Completion
- DOC05A → depends on DOC01
- DOC05B → depends on DOC01
- DOC05C → depends on DOC04D
- DOC05D → depends on DOC03E, DOC04D
- DOC05E → depends on DOC03E, DOC04D, DOC05D
- DOC05F → depends on DOC03E, DOC04D
- DOC05G → depends on DOC05C, DOC05F

### Governance Documents
- PAR01 → depends on all DOC00-DOC04E
- ADR01 → depends on PAR01

---

## 4. Module Dependency Map

### Infrastructure Dependencies
All modules depend on Layer 0 (Configuration, Logging, Error Handling, Clock)

### Market Analysis Dependencies
- DOC02B (BOS) → depends on DOC02A (Market Structure)
- DOC02C (CHoCH) → depends on DOC02A
- DOC02D (Liquidity) → depends on DOC02A
- DOC02EB (Order Block) → depends on DOC02A, DOC02B, DOC02C
- DOC02F (FVG) → depends on DOC02A

### Trading Intelligence Dependencies
- DOC03A (Trade Context) → depends on DOC02A-F
- DOC03B (Confluence) → depends on DOC03A
- DOC03C (Entry Decision) → depends on DOC03B
- DOC03D (Trade State Machine) → depends on DOC03C
- DOC03E (SMC Event Object) → depends on DOC02A-F

### Execution Dependencies
- DOC04A (Execution Framework) → depends on DOC03D
- DOC04B (Validation) → depends on DOC04A
- DOC04C (Order Submission) → depends on DOC04B
- DOC04D (Position Lifecycle) → depends on DOC04C
- DOC04E (Recovery) → depends on DOC04A-D

### Trade Management Dependencies
- DOC05C (Trade Management Framework) → depends on DOC04D
- DOC05D (Break Even) → depends on DOC03E, DOC04D
- DOC05E (Trailing Stop) → depends on DOC03E, DOC04D, DOC05D
- DOC05F (Exit Completion) → depends on DOC03E, DOC04D
- DOC05G (Statistics) → depends on DOC05C, DOC05F

---

## 5. Market Data Flow

```
MetaTrader 5 Platform (OHLCV Data)
    ↓
Layer 1: Market Data Access (Closed Bar Validation)
    ↓
Layer 2: Market Analysis (Swing → BOS/CHoCH → Liquidity → OB → FVG)
    ↓
Layer 3: Gates (Terminal → Broker → Session → Market → Spread → ...)
    ↓
Layer 4: Trading Intelligence (Context → Confluence → Decision → State)
    ↓
Layer 5: Execution (Framework → Validation → Submission → Lifecycle)
    ↓
Layer 6: Trade Management (Break Even → Trailing → Exit → Statistics)
```

---

## 6. Trade Lifecycle

### Phase 1: Market Analysis
- Swing Detection (DOC02A)
- BOS Detection (DOC02B)
- CHoCH Detection (DOC02C)
- Liquidity Detection (DOC02D)
- Order Block Detection (DOC02EB)
- FVG Detection (DOC02F)

### Phase 2: Gate Validation
- Terminal Gate
- Broker Gate
- Session Gate
- Market Gate
- Spread Gate
- Tick Freshness Gate
- Bar Completion Gate
- Recovery Gate
- HALT Gate
- Position Limit Gate

### Phase 3: Trading Intelligence
- Trade Context Building (DOC03A)
- Confluence Validation (DOC03B)
- Entry Decision (DOC03C)
- Trade State Machine (DOC03D)

### Phase 4: Execution
- Execution Framework (DOC04A)
- Execution Validation (DOC04B)
- Order Submission (DOC04C)
- Position Lifecycle Tracking (DOC04D)

### Phase 5: Trade Management
- Break Even Application (DOC05D)
- Trailing Stop Application (DOC05E)
- Exit Completion (DOC05F)
- Statistics Collection (DOC05G)

### Phase 6: Recovery (if needed)
- System Recovery & Consistency (DOC04E)

---

## 7. State Object Ownership

### Trade State Object
- **Creator:** DOC05C (Trade Management Framework)
- **Owner:** DOC05C
- **Consumers:** DOC05D, DOC05E, DOC05F, DOC05G, DOC04E
- **Mutability:** Immutable after creation
- **Persistence:** Atomic save via DOC05A
- **Recovery:** DOC04E
- **Lifetime:** Until trade closed and archived

### Position Snapshot Object
- **Creator:** DOC04D (Position Lifecycle Tracker)
- **Owner:** DOC04D
- **Consumers:** DOC04E, DOC05C-G
- **Mutability:** Immutable after creation
- **Persistence:** Atomic save via DOC05A
- **Recovery:** DOC04E
- **Lifetime:** Until position closed

### Execution Result Object
- **Creator:** DOC04A (Execution Framework)
- **Owner:** DOC04A
- **Consumers:** DOC04B-E, DOC05C
- **Mutability:** Immutable after creation
- **Persistence:** Atomic save via DOC05A
- **Recovery:** DOC04E
- **Lifetime:** Until execution finalized

### Break Even State Object
- **Creator:** DOC05D (Break Even Engine)
- **Owner:** DOC05D
- **Consumers:** DOC05C, Audit Trail
- **Mutability:** Mutable (application state)
- **Persistence:** Atomic save via DOC05A
- **Recovery:** DOC04E
- **Lifetime:** Until trade closed

### Trailing Stop State Object
- **Creator:** DOC05E (Trailing Stop Engine)
- **Owner:** DOC05E
- **Consumers:** DOC05C, Audit Trail
- **Mutability:** Mutable (application state)
- **Persistence:** Atomic save via DOC05A
- **Recovery:** DOC04E
- **Lifetime:** Until trade closed

### Exit State Object
- **Creator:** DOC05F (Exit Completion Engine)
- **Owner:** DOC05F
- **Consumers:** DOC05C, Audit Trail
- **Mutability:** Mutable (trigger state)
- **Persistence:** Atomic save via DOC05A
- **Recovery:** DOC04E
- **Lifetime:** Until trade closed

### Statistics Object
- **Creator:** DOC05G (Trade Statistics Analytics)
- **Owner:** DOC05G
- **Consumers:** Audit Trail, Reporting
- **Mutability:** Mutable (accumulated statistics)
- **Persistence:** Atomic save via DOC05A
- **Recovery:** DOC04E
- **Lifetime:** Until statistics period ends

### SMC Event Object
- **Creator:** DOC02A-F (Market Analysis Engines)
- **Owner:** DOC03E (SMC Event Object)
- **Consumers:** DOC03A-F, DOC04A-F, DOC05A-G
- **Mutability:** Immutable after creation
- **Persistence:** Event bus (DOC05A)
- **Recovery:** DOC04E
- **Lifetime:** Until consumed or expired

---

## 8. Event Flow

### Market Structure Events
- DOC02A → INTERNAL_STRUCTURE_CONFIRMED, EXTERNAL_STRUCTURE_CONFIRMED, STRUCTURE_SHIFT_CONFIRMED, TREND_CONTINUATION_CONFIRMED

### Break of Structure Events
- DOC02B → BOS_CONFIRMED

### Change of Character Events
- DOC02C → CHoCH_CONFIRMED

### Liquidity Events
- DOC02D → LIQUIDITY_SWEEP_CONFIRMED

### Order Block Events
- DOC02EB → ORDER_BLOCK_CONFIRMED, MITIGATION_CONFIRMED

### Fair Value Gap Events
- DOC02F → FAIR_VALUE_GAP_CONFIRMED, MITIGATION_CONFIRMED

### Trade Events
- DOC05F → TRADE_CLOSED

### Event Consumers
- All SMC Events → DOC03A, DOC03B, DOC03C, DOC05D, DOC05E, DOC05F
- TRADE_CLOSED → DOC05G

---

## 9. Persistence Architecture

### Persistence Strategy
**Atomic Save Philosophy:**
1. Write to temporary file
2. Flush to disk
3. Rename backup
4. Rename temporary
5. Delete old backup

### Persistence Scope
**Persisted State Objects:**
- Trade State Object
- Position Snapshot Object
- Execution Result Object
- Break Even State Object
- Trailing Stop State Object
- Exit State Object
- Statistics Object

**Not Persisted:**
- Detection engine state (reconstructed from market data)
- Historical decisions (archived for audit)
- Historical executions (archived for audit)
- Historical positions (archived for audit)

### Recovery Process
1. Load persisted state from disk
2. Validate state integrity (checksum)
3. If valid, restore state
4. If corrupt, start with clean state, log warning
5. Log recovery status

---

## 10. Implementation Blueprint

### Implementation Sequence

**Step 1: Infrastructure (DOC05A)**
- Configuration Service
- Persistence Service
- Logging Service
- Error Handling Service
- Clock/Time Service
- Utility Service
- Identifier Generation
- Project Constants
- Version Management

**Step 2: Market Analysis (DOC02A-F)**
- Market Data Access (DOC01)
- Structural Context (DOC01)
- Market Structure Engine (DOC02A)
- BOS Engine (DOC02B)
- CHoCH Engine (DOC02C)
- Liquidity Engine (DOC02D)
- Order Block Engine (DOC02EB)
- FVG Engine (DOC02F)

**Step 3: SMC Event Object (DOC03E)**
- Event communication contract

**Step 4: Trading Intelligence (DOC03A-D)**
- Trade Context Manager (DOC03A)
- Confluence Engine (DOC03B)
- Entry Decision Engine (DOC03C)
- Trade State Machine (DOC03D)

**Step 5: Execution (DOC04A-E)**
- Execution Framework (DOC04A)
- Execution Validation Engine (DOC04B)
- Order Submission Engine (DOC04C)
- Position Lifecycle Tracker (DOC04D)
- System Recovery Engine (DOC04E)

**Step 6: Gates (DOC05B)**
- Terminal Gate
- Broker Gate
- Session Gate
- Market Gate
- Spread Gate
- Tick Freshness Gate
- Bar Completion Gate
- Recovery Gate
- HALT Gate
- Position Limit Gate

**Step 7: Trade Management (DOC05C-G)**
- Trade Management Framework (DOC05C)
- Break Even Engine (DOC05D)
- Trailing Stop Engine (DOC05E)
- Exit Completion Engine (DOC05F)
- Trade Statistics Analytics (DOC05G)

---

## 11. Folder Architecture

### Recommended Folder Structure

```
BOT_SMC/
├── docs/
│   ├── DOC00_Strategy_Validation.md
│   ├── DOC00_PATCH_001.md
│   ├── DOC01_System_Architecture.md
│   ├── DOC02A_MarketStructure_Foundation.md
│   ├── DOC02B_Break_of_Structure_Engine.md
│   ├── DOC02C_Change_of_Character_Engine.md
│   ├── DOC02D_Liquidity_Engine.md
│   ├── DOC02EA_OrderBlock_Reference_Validation.md
│   ├── DOC02EB_OrderBlock_Engine.md
│   ├── DOC02F_FairValueGap_Engine.md
│   ├── DOC03A_Trading_Intelligence_Blueprint.md
│   ├── DOC03B_Confluence_Engine.md
│   ├── DOC03C_Entry_Decision_Engine.md
│   ├── DOC03D_Trade_State_Machine.md
│   ├── DOC03E_SMC_Event_Object.md
│   ├── DOC04A_Execution_Framework.md
│   ├── DOC04B_Execution_Validation_Engine.md
│   ├── DOC04C_Order_Submission_Engine.md
│   ├── DOC04D_Position_Lifecycle_Tracker.md
│   ├── DOC04E_System_Recovery_Consistency_Engine.md
│   ├── DOC05A_Infrastructure_Blueprint.md
│   ├── DOC05B_Layer3_Gate_Framework.md
│   ├── DOC05C_Trade_Management_Framework.md
│   ├── DOC05D_Break_Even_Engine.md
│   ├── DOC05E_Trailing_Stop_Engine.md
│   ├── DOC05F_Exit_Completion_Engine.md
│   ├── DOC05G_Trade_Statistics_Analytics.md
│   ├── PAR01_Project_Architecture_Review.md
│   ├── ADR01_PAR01_Resolution.md
│   ├── PROJECT_MANIFEST.md
│   └── ARCHITECTURE_MAP.md
│
├── src/
│   ├── Infrastructure/
│   ├── MarketAnalysis/
│   ├── TradingIntelligence/
│   ├── Execution/
│   ├── Gates/
│   └── TradeManagement/
│
├── tests/
│   ├── Infrastructure/
│   ├── MarketAnalysis/
│   ├── TradingIntelligence/
│   ├── Execution/
│   ├── Gates/
│   └── TradeManagement/
│
├── config/
│   └── config.ini
│
├── data/
│   ├── state/
│   ├── archive/
│   └── logs/
│
└── README.md
```

---

## 12. Recommended Implementation Order

### Critical Path

1. **Infrastructure (DOC05A)** — Foundation layer (must be implemented first)
2. **Market Data Access (DOC01)** — Data layer (required by all market analysis)
3. **Market Analysis (DOC02A-F)** — Detection layer (produces SMC events)
4. **SMC Event Object (DOC03E)** — Event contract (defines event structure)
5. **Trading Intelligence (DOC03A-D)** — Decision layer (consumes SMC events)
6. **Execution (DOC04A-E)** — Action layer (executes decisions)
7. **Gates (DOC05B)** — Validation layer (validates before execution)
8. **Trade Management (DOC05C-G)** — Supervision layer (manages trade lifecycle)

### Parallel Implementation Opportunities

**Parallel Track 1: Infrastructure**
- Configuration Service
- Logging Service
- Error Handling Service
- Clock/Time Service

**Parallel Track 2: Market Analysis**
- Market Structure Engine
- BOS Engine
- CHoCH Engine
- Liquidity Engine
- Order Block Engine
- FVG Engine

**Parallel Track 3: Trade Management**
- Break Even Engine
- Trailing Stop Engine
- Exit Completion Engine
- Statistics Analytics

---

## 13. Architecture Principles

### Core Principles

1. **Deterministic Design**
   - All rules are programmable, measurable, and reproducible
   - Identical market data always produces identical results
   - Zero human discretion required

2. **Event-Driven Architecture**
   - All trade management modules consume validated SMC Events
   - Modules communicate via immutable event objects
   - Event bus provides centralized event distribution

3. **Immutable Objects**
   - No mid-flight modification of state objects
   - All state objects are immutable after creation
   - Changes create new objects, not modifications

4. **Single Responsibility**
   - Each module has one clear responsibility
   - No module performs multiple unrelated functions
   - Clear ownership boundaries

5. **Closed Bar Discipline**
   - All detection uses only closed bars
   - No forming-bar data used for detection
   - Prevents repaint and look-ahead bias

6. **Atomic Persistence**
   - All state saves are atomic
   - No partial writes possible
   - Recovery guaranteed

7. **Zero Human Discretion**
   - All decisions are deterministic
   - No subjective interpretation
   - Fully auditable

8. **Layer Hierarchy**
   - Strict 7-layer architecture
   - Downward dependencies only
   - No circular dependencies

9. **Event Consumer Role**
   - Trade management modules are event consumers only
   - Never produce SMC events
   - Never perform market analysis

10. **Read-Only Analytics**
    - Statistics engine is completely read-only
    - Never modifies trades
    - Never makes decisions

---

## 14. Architecture Health Assessment

### Architecture Quality Metrics

**Document Completeness:** 100% (28/28 documents approved)  
**Layer Coverage:** 100% (7/7 layers fully specified)  
**Module Coverage:** 100% (30+ modules fully specified)  
**Event Coverage:** 100% (10+ event types defined)  
**State Object Coverage:** 100% (8 state objects defined)  
**Dependency Validation:** 100% (no circular dependencies)  
**PAR01 Resolution:** 100% (all findings addressed)  
**Architecture Freeze:** APPROVED (2026-07-10)

### Risk Assessment

**Repaint Risk:** MITIGATED (closed-bar confirmation, immutable objects)  
**Look-Ahead Bias:** MITIGATED (event-driven architecture, no future data)  
**Circular Dependencies:** MITIGATED (strict layer hierarchy, downward dependencies only)  
**State Corruption:** MITIGATED (atomic persistence, recovery mechanisms)  
**Race Conditions:** MITIGATED (single-threaded design, deterministic order)  
**Memory Leaks:** MITIGATED (FIFO retention, bounded collections)  
**Broker Errors:** MITIGATED (error handling, retry logic, escalation)  
**Kill Switch:** MITIGATED (50% equity threshold, manual reset only)

### Performance Characteristics

**Total System Overhead:** < 20 ms per trade lifecycle  
**Total Memory Footprint:** < 100 KB  
**CPU Usage:** < 5% on modern hardware  
**Latency:** < 10 ms end-to-end (creation to consumption)

---

## 15. Implementation Readiness

### Readiness Checklist

✅ All 28 documents completed  
✅ All PAR01 findings resolved  
✅ All layers fully specified  
✅ All modules have clear ownership  
✅ All interfaces defined  
✅ All events documented  
✅ All state machines specified  
✅ All audit trails defined  
✅ All performance constraints validated  
✅ All risks mitigated  
✅ MQL5 implementation feasible  
✅ No blocking dependencies  
✅ No circular dependencies  
✅ Deterministic design verified  
✅ Event-driven architecture verified  

### Implementation Authorization

**Status:** AUTHORIZED TO PROCEED  
**Next Phase:** Phase 6 (Implementation)  
**Implementation Sequence:** DOC05A → DOC02A-F → DOC03E → DOC03A-D → DOC04A-E → DOC05B → DOC05C-G

### Post-Implementation Requirements

1. Comprehensive unit testing for all modules
2. Integration testing across all layers
3. Backtesting on historical XAUUSD data
4. Forward testing on demo account
5. Performance validation under live market conditions
6. Audit trail validation
7. Recovery testing (restart, disconnection)

---

## Document End

**ARCHITECTURE_MAP.md** — Official Architecture Navigation Document  
**Version:** 1.0  
**Status:** APPROVED  
**Date:** 2026-07-10
