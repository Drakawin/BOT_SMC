//+------------------------------------------------------------------+
//|                                              CRiskEngine.mqh     |
//|                                        Copyright 2026, BOT_SMC   |
//| Document: Extends DOC00 §23 Stop Loss & Money Management         |
//+------------------------------------------------------------------+
#ifndef CRISKENGINE_MQH
#define CRISKENGINE_MQH

#include "CEntryDecisionEngine.mqh"
#include "CTradeContextManager.mqh"

struct SValidatedEntry
{
   bool              isValid;
   string            rejectReason;
   
   double            entryPrice;
   double            stopLoss;
   double            takeProfit;
   double            lotSize;
};

class CRiskEngine
{
private:
   bool              m_initialized;
   string            m_symbol;
   
   // Constants per DOC00
   int               m_slBufferPoints;
   int               m_maxRiskPoints;
   double            m_lotSize;
   double            m_rrRatio;

public:
                     CRiskEngine();
                    ~CRiskEngine();
                    
   bool              Initialize(string symbol, int slBufferPts = 20, int maxRiskPts = 1500, double fixedLot = 0.01, double rr = 2.0);
   
   SValidatedEntry   ValidateAndCalculate(const SDecisionOutput &decision, const STradeContextSnapshot &context);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskEngine::CRiskEngine()
{
   m_initialized = false;
   m_slBufferPoints = 20;
   m_maxRiskPoints = 1500;
   m_lotSize = 0.01;
   m_rrRatio = 2.0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskEngine::~CRiskEngine()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CRiskEngine::Initialize(string symbol, int slBufferPts, int maxRiskPts, double fixedLot, double rr)
{
   if(StringLen(symbol) == 0) return false;
   
   m_symbol = symbol;
   m_slBufferPoints = slBufferPts;
   m_maxRiskPoints = maxRiskPts;
   m_lotSize = fixedLot;
   m_rrRatio = rr;
   
   m_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Validate and Calculate (Stage 5 / Pre-Execution)                 |
//+------------------------------------------------------------------+
SValidatedEntry CRiskEngine::ValidateAndCalculate(const SDecisionOutput &decision, const STradeContextSnapshot &context)
{
   SValidatedEntry output;
   output.isValid = false;
   output.rejectReason = "Unknown";
   output.entryPrice = 0.0;
   output.stopLoss = 0.0;
   output.takeProfit = 0.0;
   output.lotSize = m_lotSize;
   
   if(!m_initialized || context.obEngine == NULL)
   {
      output.rejectReason = "Engine not initialized or Context null";
      return output;
   }
   
   if(decision.decision == DECISION_NO_ENTRY)
   {
      output.rejectReason = "No Entry decision passed to Risk Engine";
      return output;
   }
   
   // 1. Get Far Edge from the Institutional Reference used by Confluence
   double farEdge = 0.0;
   int obIdx = decision.confluenceReference.selectedObIndex;
   int bbIdx = decision.confluenceReference.selectedBreakerIndex;
   
   if(obIdx != -1)
   {
      farEdge = context.obEngine.GetOB(obIdx).farEdge;
   }
   else if(bbIdx != -1)
   {
      // A Bullish Breaker acts as Support, far edge is the Low.
      // A Bearish Breaker acts as Resistance, far edge is the High.
      SBreakerRecord bb = context.obEngine.GetBB(bbIdx);
      farEdge = (bb.direction == BB_DIRECTION_BULLISH) ? bb.lowerBoundary : bb.upperBoundary;
   }
   else
   {
      output.rejectReason = "No valid OrderBlock or BreakerBlock reference found";
      return output;
   }
   
   // Conversion factor
   double pointValue = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double pointBuffer = m_slBufferPoints * pointValue;
   
   // 2. Calculate Entry, SL, and TP
   if(decision.direction == DIRECTION_LONG)
   {
      output.entryPrice = context.ask; // Buy at Ask
      
      // Stop Loss = Far Edge (Low) - SL Buffer
      output.stopLoss = farEdge - pointBuffer;
      
      // Distance calculation
      double riskDistance = output.entryPrice - output.stopLoss;
      
      // Sanity Cap
      if(riskDistance > (m_maxRiskPoints * pointValue))
      {
         output.rejectReason = StringFormat("Risk distance %.5f exceeds Sanity Cap %d points", riskDistance, m_maxRiskPoints);
         return output;
      }
      if(riskDistance <= 0)
      {
         output.rejectReason = "Negative or zero risk distance. Invalid parameters.";
         return output;
      }
      
      // Take Profit = Entry + (Risk * RR)
      output.takeProfit = output.entryPrice + (riskDistance * m_rrRatio);
      output.isValid = true;
      output.rejectReason = "OK";
   }
   else if(decision.direction == DIRECTION_SHORT)
   {
      output.entryPrice = context.bid; // Sell at Bid
      
      // Stop Loss = Far Edge (High) + SL Buffer
      output.stopLoss = farEdge + pointBuffer;
      
      // Distance calculation
      double riskDistance = output.stopLoss - output.entryPrice;
      
      // Sanity Cap
      if(riskDistance > (m_maxRiskPoints * pointValue))
      {
         output.rejectReason = StringFormat("Risk distance %.5f exceeds Sanity Cap %d points", riskDistance, m_maxRiskPoints);
         return output;
      }
      if(riskDistance <= 0)
      {
         output.rejectReason = "Negative or zero risk distance. Invalid parameters.";
         return output;
      }
      
      // Take Profit = Entry - (Risk * RR)
      output.takeProfit = output.entryPrice - (riskDistance * m_rrRatio);
      output.isValid = true;
      output.rejectReason = "OK";
   }
   
   return output;
}

#endif