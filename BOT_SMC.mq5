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
#include <MarketAnalysis\CPremiumDiscountEngine.mqh>
#include <MarketAnalysis\CHTFSyncEngine.mqh>
#include <MarketAnalysis\COrderBlockValidator.mqh>
#include <MarketAnalysis\CFVGEngine.mqh>

//+------------------------------------------------------------------+
//| Trading Intelligence (Layer 4)                                   |
//+------------------------------------------------------------------+
#include <TradingIntelligence\CSMCEventObject.mqh>
#include <TradingIntelligence\CSMCEventBus.mqh>
#include <TradingIntelligence\CTradeContextManager.mqh>
#include <TradingIntelligence\CConfluenceEngine.mqh>
#include <TradingIntelligence\CConfluenceRules.mqh>
#include <TradingIntelligence\CEntryDecisionEngine.mqh>
#include <TradingIntelligence\CRiskEngine.mqh>
#include <TradingIntelligence\CTradeStateMachine.mqh>

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
COrderBlockEngine OrderBlockEngine;
CPremiumDiscountEngine PremiumDiscountEngine;
CHTFSyncEngine HTFSyncEngine;

// --- M15 Execution Engines ---
CMarketStructureEngine M15Structure;
CBOSEngine M15Bos; // M15 CHoCH needs a BOS engine dependency
CCHoCHEngine M15Choch;

// --- Layer 4 Engines ---
CSMCEventBus EventBus;
CTradeContextManager ContextManager;
CConfluenceEngine ConfluenceEngine;
CEntryDecisionEngine EntryDecisionEngine;
CRiskEngine RiskEngine;
CTradeStateMachine TradeStateMachine;

datetime g_lastBOSTime = 0;
datetime g_lastCHoCHTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("BOT_SMC starting...");
   MathSrand(GetTickCount()); // Initialize pseudo-random seed once for UUIDs
   
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
      
      // Initialize Order Block Engine
      if(!OrderBlockEngine.Initialize(Symbol(), Period()))
      {
         Print("OrderBlockEngine initialization failed");
         return(INIT_FAILED);
      }
      Print("OrderBlockEngine initialized successfully");
      
      // Initialize Premium Discount Engine
      if(!PremiumDiscountEngine.Initialize())
      {
         Print("PremiumDiscountEngine initialization failed");
         return(INIT_FAILED);
      }
      Print("PremiumDiscountEngine initialized successfully");
      
      // Initialize HTF Bias & MTF Sync Engine
      if(!HTFSyncEngine.Initialize(Symbol(), PERIOD_H4, 2))
      {
         Print("HTFSyncEngine initialization failed");
         return(INIT_FAILED);
      }
      Print("HTFSyncEngine initialized successfully");
      
      // Initialize M15 Execution Engines
      if(!M15Structure.Initialize(Symbol(), PERIOD_M15, 2))
      {
         Print("M15Structure initialization failed");
         return(INIT_FAILED);
      }
      if(!M15Bos.Initialize(Symbol(), PERIOD_M15, &M15Structure))
      {
         Print("M15Bos initialization failed");
         return(INIT_FAILED);
      }
      if(!M15Choch.Initialize(Symbol(), PERIOD_M15, &M15Structure, &M15Bos))
      {
         Print("M15Choch initialization failed");
         return(INIT_FAILED);
      }
      Print("M15 Execution Engines initialized successfully");
      
      // Initialize Trading Intelligence Foundation (Layer 4)
      if(!ContextManager.Initialize())
      {
         Print("ContextManager initialization failed");
         return(INIT_FAILED);
      }
      EventBus.Subscribe(&ContextManager);
      Print("EventBus & ContextManager initialized successfully");
      
      if(!ConfluenceEngine.Initialize())
      {
         Print("ConfluenceEngine initialization failed");
         return(INIT_FAILED);
      }
      
      // Register the 6 Rules of Confluence
      ConfluenceEngine.AddCondition(new CConditionDirectionalBias());
      ConfluenceEngine.AddCondition(new CConditionRetracement());
      ConfluenceEngine.AddCondition(new CConditionInstitutionalReference());
      ConfluenceEngine.AddCondition(new CConditionImbalance());
      ConfluenceEngine.AddCondition(new CConditionLiquiditySweep());
      ConfluenceEngine.AddCondition(new CConditionLTFTrigger());
      
      Print("ConfluenceEngine initialized successfully (Stage 3 Pipeline Ready with 6 Rules)");
      
      if(!EntryDecisionEngine.Initialize())
      {
         Print("EntryDecisionEngine initialization failed");
         return(INIT_FAILED);
      }
      Print("EntryDecisionEngine initialized successfully (Stage 4 Ready)");
      
      if(!RiskEngine.Initialize(Symbol(), 20, 15.0, 0.01, 2.0))
      {
         Print("RiskEngine initialization failed");
         return(INIT_FAILED);
      }
      Print("RiskEngine initialized successfully");
      PrintFormat("Broker _Point Value for %s is: %f", Symbol(), SymbolInfoDouble(Symbol(), SYMBOL_POINT));
      
      if(!TradeStateMachine.Initialize())
      {
         Print("TradeStateMachine initialization failed");
         return(INIT_FAILED);
      }
      Print("TradeStateMachine initialized successfully (Layer 6 Lifecycle Ready)");
      
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
      LiquidityEngine.UpdateDealingRange();
      PremiumDiscountEngine.UpdateRange(MarketStructure.GetLastSwingHighPrice(), MarketStructure.GetLastSwingLowPrice());
      if(false)
      {
         PrintFormat("[Spatial] Dealing Range Updated | High: %.5f | Low: %.5f | Equilibrium: %.5f", 
                     PremiumDiscountEngine.GetRangeHigh(), PremiumDiscountEngine.GetRangeLow(), PremiumDiscountEngine.GetEquilibrium());
      }
   }
   
   if(MarketStructure.DetectSwingLow(5))
   {
      LiquidityEngine.ProcessNewSwingLow();
      LiquidityEngine.UpdateDealingRange();
      PremiumDiscountEngine.UpdateRange(MarketStructure.GetLastSwingHighPrice(), MarketStructure.GetLastSwingLowPrice());
      if(false)
      {
         PrintFormat("[Spatial] Dealing Range Updated | High: %.5f | Low: %.5f | Equilibrium: %.5f", 
                     PremiumDiscountEngine.GetRangeHigh(), PremiumDiscountEngine.GetRangeLow(), PremiumDiscountEngine.GetEquilibrium());
      }
   }
   
   // Evaluate Multi-Timeframe Synchronization
   HTFSyncEngine.Update(&MarketStructure);
   
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
      
      // Evaluate Order Block Mitigations and Invalidations
      OrderBlockEngine.CheckMitigationAndInvalidation(1);
      
      // Evaluate Breaker Block Mitigations
      OrderBlockEngine.CheckBreakerMitigation(1);

      
   }
   
   // --- M15 Execution Timeframe Checks ---
   // To keep M15 accurate, we evaluate M15 structure on M15 bar closes.
   static datetime lastM15BarTime = 0;
   datetime currentM15Time = iTime(Symbol(), PERIOD_M15, 1);
   if(currentM15Time != 0 && currentM15Time != lastM15BarTime)
   {
      lastM15BarTime = currentM15Time;
      M15Structure.DetectSwingHigh(5); // Detect swings with SFS=2
      M15Structure.DetectSwingLow(5);
      M15Bos.DetectBOS(1);
      if(M15Choch.DetectCHoCH(1)) { PrintFormat("[M15 Trigger] CHoCH Detected! Direction: %s", EnumToString(M15Choch.GetPrevailingDirection())); }

      // Build Layer 4 Context Snapshot at the end of the M15 closed bar evaluation
      // This mixes the static H1 Structural Context with the fresh M15 Trigger Context
      ContextManager.BuildSnapshot(&MarketStructure, &BOSEngine, &CHoCHEngine, &LiquidityEngine, &OrderBlockEngine, &FVGEngine, &PremiumDiscountEngine, &HTFSyncEngine, &M15Choch);
      
      // Pass the frozen snapshot to the Confluence Engine (Stage 3)
      SConfluenceResult confResult = ConfluenceEngine.EvaluateContext(ContextManager.GetSnapshot());
      
      // Pass the Confluence Result to the Entry Decision Engine (Stage 4)
      SDecisionOutput decision = EntryDecisionEngine.EvaluateDecision(confResult, currentM15Time);
      
      if(decision.decision != DECISION_NO_ENTRY)
      {
         // Pre-Execution Risk Calculation
         SValidatedEntry validEntry = RiskEngine.ValidateAndCalculate(decision, ContextManager.GetSnapshot());
         
         if(validEntry.isValid)
         {
                        
            // Hand over to Trade State Machine
            TradeStateMachine.ProcessNewDecision(decision);
            PrintFormat("[Stage 4 Final Decision] SIGNAL GENERATED: %s | Entry: %.5f | SL: %.5f | TP: %.5f | Lot: %.2f | ID: %s", 
                        EnumToString(decision.decision), validEntry.entryPrice, validEntry.stopLoss, validEntry.takeProfit, validEntry.lotSize, TradeStateMachine.GetActiveRecord().decisionId);
         }
         else
         {
            PrintFormat("[Risk Engine] Trade REJECTED | Reason: %s", validEntry.rejectReason);
         }
      }
      else
      {
         // Optional: Print rejection reason for debugging
         PrintFormat("[Decision Pipeline] Rejected at: %s", confResult.failedConditionName);
      }
   }

   // --- H1 Detection Block ---
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
                     
         // Trigger OB Detection on the breakout bar
         OrderBlockEngine.DetectOrderBlock(event.barIndex, (event.direction == BOS_DIRECTION_BULLISH) ? OB_DIRECTION_BULLISH : OB_DIRECTION_BEARISH);
         
         // Trigger Breaker Promotion check (Opposite BOS vs Invalidated OB)
         OrderBlockEngine.DetectBreakerBlock(event.barIndex, (event.direction == BOS_DIRECTION_BULLISH) ? OB_DIRECTION_BULLISH : OB_DIRECTION_BEARISH);
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
                     
         // Trigger OB Detection on the breakout bar
         OrderBlockEngine.DetectOrderBlock(event.barIndex, (event.direction == CHOCH_DIRECTION_BULLISH) ? OB_DIRECTION_BULLISH : OB_DIRECTION_BEARISH);
         
         // Trigger Breaker Promotion check (Opposite CHoCH vs Invalidated OB)
         OrderBlockEngine.DetectBreakerBlock(event.barIndex, (event.direction == CHOCH_DIRECTION_BULLISH) ? OB_DIRECTION_BULLISH : OB_DIRECTION_BEARISH);
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
