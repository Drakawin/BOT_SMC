//+------------------------------------------------------------------+
//|                                                  BOT_SMC.mq5     |
//|                                        Copyright 2026, BOT_SMC   |
//|                                     https://github.com/BOT_SMC   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, BOT_SMC"
#property link      "https://github.com/BOT_SMC"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Constants                                                         |
//+------------------------------------------------------------------+
#include <Constants\CProjectConstants.mqh>

//+------------------------------------------------------------------+
//| Infrastructure (Layer 0)                                         |
//+------------------------------------------------------------------+
#include <Infrastructure\CConfigurationService.mqh>
#include <Infrastructure\CPersistenceService.mqh>
#include <Infrastructure\CLoggingService.mqh>
#include <Infrastructure\CErrorHandlingService.mqh>
#include <Infrastructure\CClockTimeService.mqh>
#include <Infrastructure\CUtilityService.mqh>
#include <Infrastructure\CIdentifierGeneration.mqh>
#include <Infrastructure\CVersionManagement.mqh>
#include <Infrastructure\CMarketDataAccess.mqh>
#include <Infrastructure\CStructuralContext.mqh>

//+------------------------------------------------------------------+
//| Market Analysis (Layer 2)                                        |
//+------------------------------------------------------------------+
#include <MarketAnalysis\CMarketStructureEngine.mqh>
#include <MarketAnalysis\CBOSEngine.mqh>
#include <MarketAnalysis\CCHoCHEngine.mqh>
#include <MarketAnalysis\CLiquidityEngine.mqh>
#include <MarketAnalysis\COrderBlockEngine.mqh>
#include <MarketAnalysis\COrderBlockValidator.mqh>
#include <MarketAnalysis\CFVGEngine.mqh>

//+------------------------------------------------------------------+
//| Trading Intelligence (Layer 4)                                   |
//+------------------------------------------------------------------+
#include <TradingIntelligence\CTradeContextManager.mqh>
#include <TradingIntelligence\CConfluenceEngine.mqh>
#include <TradingIntelligence\CEntryDecisionEngine.mqh>
#include <TradingIntelligence\CTradeStateMachine.mqh>
#include <TradingIntelligence\CSMCEventObject.mqh>
#include <TradingIntelligence\CSMCEventBus.mqh>

//+------------------------------------------------------------------+
//| Execution (Layer 5)                                              |
//+------------------------------------------------------------------+
#include <Execution\CExecutionFramework.mqh>
#include <Execution\CExecutionValidationEngine.mqh>
#include <Execution\COrderSubmissionEngine.mqh>
#include <Execution\CPositionLifecycleTracker.mqh>
#include <Execution\CSystemRecoveryEngine.mqh>

//+------------------------------------------------------------------+
//| Gates (Layer 3)                                                  |
//+------------------------------------------------------------------+
#include <Gates\CTerminalGate.mqh>
#include <Gates\CBrokerGate.mqh>
#include <Gates\CSessionGate.mqh>
#include <Gates\CMarketGate.mqh>
#include <Gates\CSpreadGate.mqh>
#include <Gates\CTickFreshnessGate.mqh>
#include <Gates\CBarCompletionGate.mqh>
#include <Gates\CRecoveryGate.mqh>
#include <Gates\CHALTGate.mqh>
#include <Gates\CPositionLimitGate.mqh>

//+------------------------------------------------------------------+
//| Trade Management (Layer 6)                                       |
//+------------------------------------------------------------------+
#include <TradeManagement\CTradeManagementFramework.mqh>
#include <TradeManagement\CBreakEvenEngine.mqh>
#include <TradeManagement\CTrailingStopEngine.mqh>
#include <TradeManagement\CExitCompletionEngine.mqh>
#include <TradeManagement\CTradeStatisticsAnalytics.mqh>

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}
//+------------------------------------------------------------------+
