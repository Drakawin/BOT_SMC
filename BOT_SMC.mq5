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
#include <Infrastructure\CBootstrapEngine.mqh>
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
//| Global Instances                                                 |
//+------------------------------------------------------------------+
CBootstrapEngine Bootstrap;
CMarketStructureEngine MarketStructure;
CBOSEngine BOSEngine;
CCHoCHEngine CHoCHEngine;
CLiquidityEngine LiquidityEngine;
CFVGEngine FVGEngine;

datetime g_lastBOSTime = 0;
datetime g_lastCHoCHTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("BOT_SMC starting...");
   
   ENUM_BOOTSTRAP_STATUS status = Bootstrap.Initialize();
   
   if(status == BOOTSTRAP_STATUS_SUCCESS)
   {
      Print("Bootstrap initialization successful");
      
      // Initialize Market Structure Engine
      if(!MarketStructure.Initialize(Symbol(), Period(), 5))
      {
         Print("MarketStructure initialization failed");
         return(INIT_FAILED);
      }
      Print("MarketStructure initialized successfully");
      
      // Initialize BOS Engine
      if(!BOSEngine.Initialize(Symbol(), Period(), &MarketStructure))
      {
         Print("BOSEngine initialization failed");
         return(INIT_FAILED);
      }
      Print("BOSEngine initialized successfully");
      
      // Initialize CHoCH Engine
      if(!CHoCHEngine.Initialize(Symbol(), Period(), &MarketStructure, &BOSEngine))
      {
         Print("CHoCHEngine initialization failed");
         return(INIT_FAILED);
      }
      Print("CHoCHEngine initialized successfully");

      // Initialize Liquidity Engine
      if(!LiquidityEngine.Initialize(Symbol(), Period(), &MarketStructure))
      {
         Print("LiquidityEngine initialization failed");
         return(INIT_FAILED);
      }
      Print("LiquidityEngine initialized successfully");
      
      // Initialize FVG Engine
      if(!FVGEngine.Initialize(Symbol(), Period(), 10, 5))
      {
         Print("FVGEngine initialization failed");
         return(INIT_FAILED);
      }
      Print("FVGEngine initialized successfully");
      
      return(INIT_SUCCEEDED);
   }
   else
   {
      Print("Bootstrap initialization failed: ", EnumToString(status));
      return(INIT_FAILED);
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Detect swing points on bar 5 (swingLookback bars back)
   if(MarketStructure.DetectSwingHigh(5))
   {
      LiquidityEngine.ProcessNewSwingHigh();
      
      // Update Dealing Range
      LiquidityEngine.UpdateDealingRange();
   }
   
   if(MarketStructure.DetectSwingLow(5))
   {
      LiquidityEngine.ProcessNewSwingLow();
      
      // Update Dealing Range
      LiquidityEngine.UpdateDealingRange();
   }
   
   // Periodic update of Dealing Range to ensure classifications are fresh
   static datetime lastRangeUpdate = 0;
   if(iTime(Symbol(), Period(), 0) != lastRangeUpdate)
   {
      lastRangeUpdate = iTime(Symbol(), Period(), 0);
      LiquidityEngine.UpdateDealingRange();
      
      // Print nearest internal targets
      double currentPrice = iClose(Symbol(), Period(), 0);
      int nearestBSL = LiquidityEngine.GetNearestInternalBSL(currentPrice);
      int nearestSSL = LiquidityEngine.GetNearestInternalSSL(currentPrice);
      
      if(nearestBSL >= 0)
      {
         PrintFormat("[Liquidity] Nearest Internal BSL | Price=%.5f | Time=%s", 
                     LiquidityEngine.GetLevel(nearestBSL).price,
                     TimeToString(LiquidityEngine.GetLevel(nearestBSL).timestamp, TIME_DATE|TIME_MINUTES));
      }
      if(nearestSSL >= 0)
      {
         PrintFormat("[Liquidity] Nearest Internal SSL | Price=%.5f | Time=%s", 
                     LiquidityEngine.GetLevel(nearestSSL).price,
                     TimeToString(LiquidityEngine.GetLevel(nearestSSL).timestamp, TIME_DATE|TIME_MINUTES));
      }
   }
   
   // Sweep Engine Evaluation on bar 1 (last closed bar)
   // We do this via periodic check on new bar open, or directly every tick checking bar 1.
   // To avoid duplicate checks on the same bar, we use a static timestamp:
   static datetime lastClosedBarTime = 0;
   datetime bar1Time = iTime(Symbol(), Period(), 1);
   if(bar1Time != 0 && bar1Time != lastClosedBarTime)
   {
      lastClosedBarTime = bar1Time;
      
      // Check Liquidity Sweeps
      LiquidityEngine.CheckSweepsAndConsumption(1);
      
      // Detect new FVGs based on the closed pattern ending at bar 1
      FVGEngine.DetectFVG(1);
      
      // Check FVG Fills using the newly closed bar
      FVGEngine.CheckFills(1);
   }

   // Detect BOS on bar 1 (last closed bar)
   if(BOSEngine.DetectBOS(1))
   {
      datetime currentBOSTime = BOSEngine.GetLastBOSTimestamp();
      
      if(currentBOSTime != g_lastBOSTime)
      {
         g_lastBOSTime = currentBOSTime;
         
         BOSEvent event = BOSEngine.GetLastBOS();
         
         string direction = (event.direction == BOS_DIRECTION_BULLISH) ? "Bullish" : "Bearish";
         
         PrintFormat("[BOS] %s detected | Time=%s | Bar=%d | Break=%.5f | Swing=%.5f",
                     direction,
                     TimeToString(event.timestamp, TIME_DATE|TIME_MINUTES),
                     event.barIndex,
                     event.breakPrice,
                     event.swingPrice);
      }
   }
   
   // Detect CHoCH on bar 1 (last closed bar)
   if(CHoCHEngine.DetectCHoCH(1))
   {
      datetime currentCHoCHTime = CHoCHEngine.GetLastCHoCH().timestamp;
      
      if(currentCHoCHTime != g_lastCHoCHTime)
      {
         g_lastCHoCHTime = currentCHoCHTime;
         
         CHoCHEvent event = CHoCHEngine.GetLastCHoCH();
         
         string direction = (event.direction == CHOCH_DIRECTION_BULLISH) ? "Bullish" : "Bearish";
         
         PrintFormat("[CHoCH] %s detected | Time=%s | Bar=%d | Break=%.5f | Swing=%.5f",
                     direction,
                     TimeToString(event.timestamp, TIME_DATE|TIME_MINUTES),
                     event.barIndex,
                     event.breakPrice,
                     event.swingPrice);
      }
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("BOT_SMC shutting down...");
   Print("Total Liquidity Levels generated: ", LiquidityEngine.GetLevelCount());
   Print("BOT_SMC shutdown complete");
}
//+------------------------------------------------------------------+
