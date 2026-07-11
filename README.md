# BOT_SMC - Smart Money Concept Trading System

## Project Structure

```
BOT_SMC/
├── BOT_SMC.mq5                    # Main Expert Advisor
├── include/                       # Header files
│   ├── Constants/
│   │   └── CProjectConstants.mqh
│   ├── Infrastructure/
│   │   ├── CConfigurationService.mqh
│   │   ├── CPersistenceService.mqh
│   │   ├── CLoggingService.mqh
│   │   ├── CErrorHandlingService.mqh
│   │   ├── CClockTimeService.mqh
│   │   ├── CUtilityService.mqh
│   │   ├── CIdentifierGeneration.mqh
│   │   ├── CVersionManagement.mqh
│   │   ├── CMarketDataAccess.mqh
│   │   └── CStructuralContext.mqh
│   ├── MarketAnalysis/
│   │   ├── CMarketStructureEngine.mqh
│   │   ├── CBOSEngine.mqh
│   │   ├── CCHoCHEngine.mqh
│   │   ├── CLiquidityEngine.mqh
│   │   ├── COrderBlockEngine.mqh
│   │   ├── COrderBlockValidator.mqh
│   │   └── CFVGEngine.mqh
│   ├── TradingIntelligence/
│   │   ├── CTradeContextManager.mqh
│   │   ├── CConfluenceEngine.mqh
│   │   ├── CEntryDecisionEngine.mqh
│   │   ├── CTradeStateMachine.mqh
│   │   ├── CSMCEventObject.mqh
│   │   └── CSMCEventBus.mqh
│   ├── Execution/
│   │   ├── CExecutionFramework.mqh
│   │   ├── CExecutionValidationEngine.mqh
│   │   ├── COrderSubmissionEngine.mqh
│   │   ├── CPositionLifecycleTracker.mqh
│   │   └── CSystemRecoveryEngine.mqh
│   ├── Gates/
│   │   ├── CTerminalGate.mqh
│   │   ├── CBrokerGate.mqh
│   │   ├── CSessionGate.mqh
│   │   ├── CMarketGate.mqh
│   │   ├── CSpreadGate.mqh
│   │   ├── CTickFreshnessGate.mqh
│   │   ├── CBarCompletionGate.mqh
│   │   ├── CRecoveryGate.mqh
│   │   ├── CHALTGate.mqh
│   │   └── CPositionLimitGate.mqh
│   ├── TradeManagement/
│   │   ├── CTradeManagementFramework.mqh
│   │   ├── CBreakEvenEngine.mqh
│   │   ├── CTrailingStopEngine.mqh
│   │   ├── CExitCompletionEngine.mqh
│   │   └── CTradeStatisticsAnalytics.mqh
│   └── Common/
├── src/                           # Source files
│   ├── Infrastructure/
│   ├── MarketAnalysis/
│   ├── TradingIntelligence/
│   ├── Execution/
│   ├── Gates/
│   └── TradeManagement/
├── config/
│   └── config.ini                 # Runtime configuration
├── data/
│   ├── state/                     # Persisted state objects
│   ├── archive/                   # Archived historical data
│   └── logs/                      # Log files
├── tests/
│   ├── Infrastructure/
│   ├── MarketAnalysis/
│   ├── TradingIntelligence/
│   ├── Execution/
│   ├── Gates/
│   ├── TradeManagement/
│   └── Integration/
└── README.md                      # This file
```

## Architecture Layers

### Layer 0: Infrastructure
- **CConfigurationService**: Manage project configuration
- **CPersistenceService**: Persist and recover state
- **CLoggingService**: Centralized logging
- **CErrorHandlingService**: Error classification and recovery
- **CClockTimeService**: Deterministic time services
- **CUtilityService**: Common utility functions
- **CIdentifierGeneration**: Deterministic identifiers
- **CVersionManagement**: Document and code versioning
- **CMarketDataAccess**: Market data access
- **CStructuralContext**: Shared read model

### Layer 2: Market Analysis
- **CMarketStructureEngine**: Swing detection and structure
- **CBOSEngine**: Break of Structure detection
- **CCHoCHEngine**: Change of Character detection
- **CLiquidityEngine**: Liquidity level detection
- **COrderBlockEngine**: Order Block detection
- **COrderBlockValidator**: Order Block validation
- **CFVGEngine**: Fair Value Gap detection

### Layer 3: Gates
- **CTerminalGate**: Terminal connection validation
- **CBrokerGate**: Broker connection validation
- **CSessionGate**: Trading session validation
- **CMarketGate**: Market status validation
- **CSpreadGate**: Spread limit validation
- **CTickFreshnessGate**: Tick freshness validation
- **CBarCompletionGate**: Bar completion validation
- **CRecoveryGate**: Recovery status validation
- **CHALTGate**: HALT state validation
- **CPositionLimitGate**: Position limit validation

### Layer 4: Trading Intelligence
- **CTradeContextManager**: Build trade context
- **CConfluenceEngine**: Confluence validation
- **CEntryDecisionEngine**: Entry decision making
- **CTradeStateMachine**: Trade lifecycle management
- **CSMCEventObject**: SMC event structure
- **CSMCEventBus**: Event distribution

### Layer 5: Execution
- **CExecutionFramework**: Execution pipeline
- **CExecutionValidationEngine**: Execution validation
- **COrderSubmissionEngine**: Order submission
- **CPositionLifecycleTracker**: Position tracking
- **CSystemRecoveryEngine**: System recovery

### Layer 6: Trade Management
- **CTradeManagementFramework**: Trade supervision
- **CBreakEvenEngine**: Break-even application
- **CTrailingStopEngine**: Trailing stop application
- **CExitCompletionEngine**: Exit completion
- **CTradeStatisticsAnalytics**: Trade statistics

## Build Order

1. Infrastructure Layer (Layer 0)
2. Shared Read Model (Layer 1)
3. SMC Event Object (Layer 4)
4. Market Analysis Layer (Layer 2)
5. Trading Intelligence Layer (Layer 4)
6. Execution Layer (Layer 5)
7. Gates Layer (Layer 3)
8. Trade Management Layer (Layer 6)

## Implementation Principles

- **Layer Isolation**: Dependencies flow downward only
- **Event-Driven Communication**: All cross-layer communication via event bus
- **Immutable State**: No mid-flight modification of state objects
- **Single Responsibility**: Each module has one clear purpose
- **Deterministic Execution**: Identical input produces identical output

## Status

**Project Phase**: Skeleton Complete  
**Next Phase**: Infrastructure Implementation (DOC05A)

---

Copyright 2026, BOT_SMC
