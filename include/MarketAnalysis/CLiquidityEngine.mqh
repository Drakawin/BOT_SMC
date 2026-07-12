//+------------------------------------------------------------------+
//|                                             CLiquidityEngine.mqh |
//|                                        Copyright 2026, BOT_SMC   |
//| Document: DOC02D (Liquidity Engine)                              |
//+------------------------------------------------------------------+
#ifndef CLIQUIDITYENGINE_MQH
#define CLIQUIDITYENGINE_MQH

#include "CMarketStructureEngine.mqh"

enum ENUM_LIQUIDITY_STATE
{
   LIQUIDITY_STATE_UNKNOWN = 0,
   LIQUIDITY_STATE_BUILDING = 1,
   LIQUIDITY_STATE_ACTIVE = 2,
   LIQUIDITY_STATE_SWEPT = 3,
   LIQUIDITY_STATE_CONSUMED = 4,
   LIQUIDITY_STATE_INVALID = 5
};

enum ENUM_LIQUIDITY_ROLE
{
   LIQUIDITY_ROLE_BSL = 0,
   LIQUIDITY_ROLE_SSL = 1
};

enum ENUM_LIQUIDITY_CLASSIFICATION
{
   LIQUIDITY_CLASS_UNKNOWN = 0,
   LIQUIDITY_CLASS_INTERNAL = 1,
   LIQUIDITY_CLASS_EXTERNAL = 2
};

struct SLiquidityLevel
{
   double                           price;
   datetime                         timestamp;
   int                              barIndex;
   ENUM_LIQUIDITY_ROLE              role;
   ENUM_LIQUIDITY_CLASSIFICATION    classification;
   ENUM_LIQUIDITY_STATE             state;
   bool                             isPool;
};

class CLiquidityEngine
{
private:
   bool                     m_initialized;
   CMarketStructureEngine*  m_structureEngine;
   string                   m_symbol;
   ENUM_TIMEFRAMES          m_timeframe;
   
   SLiquidityLevel          m_levels[];
   int                      m_levelCount;
   
   double                   m_dealingRangeHigh;
   double                   m_dealingRangeLow;
   double                   m_elt; // Equal-Level Tolerance in price terms
   
   datetime                 GetBarTime(int barIndex) const;
   void                     UpdateClassifications();

public:
                     CLiquidityEngine();
                    ~CLiquidityEngine();
                    
   bool              Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CMarketStructureEngine* structureEngine, int eltPoints = 20);
   bool              IsInitialized() const;
   
   // We call these when a new swing is detected to add it to our tracking
   void              ProcessNewSwingHigh();
   void              ProcessNewSwingLow();
   
   // Update Dealing Range (e.g. at bar close or when structure shifts)
   void              UpdateDealingRange();
   
   // Retrieval
   int               GetLevelCount() const { return m_levelCount; }
   SLiquidityLevel   GetLevel(int index) const;
   
   // Nearest Active Targets (Internal)
   int               GetNearestInternalBSL(double currentPrice) const;
   int               GetNearestInternalSSL(double currentPrice) const;
   
   // Sweep & Consumption evaluation (called on closed bar)
   void              CheckSweepsAndConsumption(int barIndex);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLiquidityEngine::CLiquidityEngine()
{
   m_initialized = false;
   m_structureEngine = NULL;
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_levelCount = 0;
   m_dealingRangeHigh = 0.0;
   m_dealingRangeLow = 0.0;
   ArrayResize(m_levels, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLiquidityEngine::~CLiquidityEngine()
{
   ArrayResize(m_levels, 0);
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CLiquidityEngine::Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CMarketStructureEngine* structureEngine, int eltPoints)
{
   if(StringLen(symbol) == 0 || structureEngine == NULL)
      return false;
      
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_structureEngine = structureEngine;
   m_elt = eltPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
   m_initialized = true;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if initialized                                             |
//+------------------------------------------------------------------+
bool CLiquidityEngine::IsInitialized() const
{
   return m_initialized;
}

//+------------------------------------------------------------------+
//| Helper: Get bar time                                             |
//+------------------------------------------------------------------+
datetime CLiquidityEngine::GetBarTime(int barIndex) const
{
   return iTime(m_symbol, m_timeframe, barIndex);
}

//+------------------------------------------------------------------+
//| Update Dealing Range                                             |
//+------------------------------------------------------------------+
void CLiquidityEngine::UpdateDealingRange()
{
   if(!m_initialized || m_structureEngine == NULL) return;
   m_dealingRangeHigh = m_structureEngine.GetLastSwingHighPrice();
   m_dealingRangeLow = m_structureEngine.GetLastSwingLowPrice();
   UpdateClassifications();
}

//+------------------------------------------------------------------+
//| Process New Swing High -> Add BSL or update EQH pool             |
//+------------------------------------------------------------------+
void CLiquidityEngine::ProcessNewSwingHigh()
{
   if(!m_initialized || m_structureEngine == NULL) return;
   
   double price = m_structureEngine.GetLastSwingHighPrice();
   int barIndex = m_structureEngine.GetLastSwingHighBar();
   
   if(price <= 0) return;
   
   datetime barTime = GetBarTime(barIndex);
   
   // Check for duplicate and find last active BSL for EQH check
   int lastActiveBslIndex = -1;
   for(int i = m_levelCount - 1; i >= 0; i--)
   {
      if(m_levels[i].role == LIQUIDITY_ROLE_BSL)
      {
         if(m_levels[i].timestamp == barTime)
            return; // Already recorded
            
         if(lastActiveBslIndex == -1 && m_levels[i].state == LIQUIDITY_STATE_ACTIVE)
         {
            lastActiveBslIndex = i;
         }
      }
   }
   
   // Check EQH condition
   if(lastActiveBslIndex >= 0)
   {
      if(MathAbs(price - m_levels[lastActiveBslIndex].price) <= m_elt)
      {
         // Forms an EQH Pool
         m_levels[lastActiveBslIndex].price = MathMax(price, m_levels[lastActiveBslIndex].price);
         m_levels[lastActiveBslIndex].barIndex = barIndex;
         m_levels[lastActiveBslIndex].timestamp = barTime;
         m_levels[lastActiveBslIndex].isPool = true;
         
         PrintFormat("[Liquidity] EQH Pool formed at %.5f (Time=%s)", m_levels[lastActiveBslIndex].price, TimeToString(barTime, TIME_DATE|TIME_MINUTES));
         UpdateClassifications();
         return; // We consumed/updated the previous level, no need to create a new one
      }
   }
   
   // Create new standalone BSL level
   int newIndex = m_levelCount;
   m_levelCount++;
   ArrayResize(m_levels, m_levelCount);
   
   m_levels[newIndex].price = price;
   m_levels[newIndex].barIndex = barIndex;
   m_levels[newIndex].timestamp = barTime;
   m_levels[newIndex].role = LIQUIDITY_ROLE_BSL;
   m_levels[newIndex].state = LIQUIDITY_STATE_ACTIVE;
   m_levels[newIndex].isPool = false;
   m_levels[newIndex].classification = LIQUIDITY_CLASS_UNKNOWN;
   
   UpdateClassifications();
}

//+------------------------------------------------------------------+
//| Process New Swing Low -> Add SSL or update EQL pool              |
//+------------------------------------------------------------------+
void CLiquidityEngine::ProcessNewSwingLow()
{
   if(!m_initialized || m_structureEngine == NULL) return;
   
   double price = m_structureEngine.GetLastSwingLowPrice();
   int barIndex = m_structureEngine.GetLastSwingLowBar();
   
   if(price <= 0) return;
   
   datetime barTime = GetBarTime(barIndex);
   
   // Check for duplicate and find last active SSL for EQL check
   int lastActiveSslIndex = -1;
   for(int i = m_levelCount - 1; i >= 0; i--)
   {
      if(m_levels[i].role == LIQUIDITY_ROLE_SSL)
      {
         if(m_levels[i].timestamp == barTime)
            return; // Already recorded
            
         if(lastActiveSslIndex == -1 && m_levels[i].state == LIQUIDITY_STATE_ACTIVE)
         {
            lastActiveSslIndex = i;
         }
      }
   }
   
   // Check EQL condition
   if(lastActiveSslIndex >= 0)
   {
      if(MathAbs(price - m_levels[lastActiveSslIndex].price) <= m_elt)
      {
         // Forms an EQL Pool
         m_levels[lastActiveSslIndex].price = MathMin(price, m_levels[lastActiveSslIndex].price);
         m_levels[lastActiveSslIndex].barIndex = barIndex;
         m_levels[lastActiveSslIndex].timestamp = barTime;
         m_levels[lastActiveSslIndex].isPool = true;
         
         PrintFormat("[Liquidity] EQL Pool formed at %.5f (Time=%s)", m_levels[lastActiveSslIndex].price, TimeToString(barTime, TIME_DATE|TIME_MINUTES));
         UpdateClassifications();
         return; // We consumed/updated the previous level, no need to create a new one
      }
   }
   
   // Create new standalone SSL level
   int newIndex = m_levelCount;
   m_levelCount++;
   ArrayResize(m_levels, m_levelCount);
   
   m_levels[newIndex].price = price;
   m_levels[newIndex].barIndex = barIndex;
   m_levels[newIndex].timestamp = barTime;
   m_levels[newIndex].role = LIQUIDITY_ROLE_SSL;
   m_levels[newIndex].state = LIQUIDITY_STATE_ACTIVE;
   m_levels[newIndex].isPool = false;
   m_levels[newIndex].classification = LIQUIDITY_CLASS_UNKNOWN;
   
   UpdateClassifications();
}

//+------------------------------------------------------------------+
//| Update Classifications based on Dealing Range                    |
//+------------------------------------------------------------------+
void CLiquidityEngine::UpdateClassifications()
{
   if(m_dealingRangeHigh == 0.0 || m_dealingRangeLow == 0.0)
   {
      // Range not established -> default to External per DOC02D
      for(int i = 0; i < m_levelCount; i++)
      {
         if(m_levels[i].state == LIQUIDITY_STATE_ACTIVE)
         {
            m_levels[i].classification = LIQUIDITY_CLASS_EXTERNAL;
         }
      }
      return;
   }
   
   for(int i = 0; i < m_levelCount; i++)
   {
      if(m_levels[i].state != LIQUIDITY_STATE_ACTIVE)
         continue; // Only classify active levels
         
      if(m_levels[i].role == LIQUIDITY_ROLE_BSL)
      {
         // A BSL is Internal iff its price is strictly less than the range-bounding swing high
         if(m_levels[i].price < m_dealingRangeHigh)
            m_levels[i].classification = LIQUIDITY_CLASS_INTERNAL;
         else
            m_levels[i].classification = LIQUIDITY_CLASS_EXTERNAL;
      }
      else if(m_levels[i].role == LIQUIDITY_ROLE_SSL)
      {
         // An SSL is Internal iff its price is strictly greater than the range-bounding swing low
         if(m_levels[i].price > m_dealingRangeLow)
            m_levels[i].classification = LIQUIDITY_CLASS_INTERNAL;
         else
            m_levels[i].classification = LIQUIDITY_CLASS_EXTERNAL;
      }
   }
}

//+------------------------------------------------------------------+
//| Get Level by Index                                               |
//+------------------------------------------------------------------+
SLiquidityLevel CLiquidityEngine::GetLevel(int index) const
{
   SLiquidityLevel emptyLevel;
   ZeroMemory(emptyLevel);
   
   if(index >= 0 && index < m_levelCount)
      return m_levels[index];
      
   return emptyLevel;
}

//+------------------------------------------------------------------+
//| Get Nearest Internal BSL (above currentPrice)                    |
//| Returns index, or -1 if none found                               |
//+------------------------------------------------------------------+
int CLiquidityEngine::GetNearestInternalBSL(double currentPrice) const
{
   int bestIndex = -1;
   double minDistance = -1.0;
   
   for(int i = 0; i < m_levelCount; i++)
   {
      if(m_levels[i].state == LIQUIDITY_STATE_ACTIVE && 
         m_levels[i].role == LIQUIDITY_ROLE_BSL && 
         m_levels[i].classification == LIQUIDITY_CLASS_INTERNAL)
      {
         // BSL must be above price (or equal for boundary)
         if(m_levels[i].price >= currentPrice)
         {
            double dist = m_levels[i].price - currentPrice;
            if(bestIndex == -1 || dist < minDistance)
            {
               minDistance = dist;
               bestIndex = i;
            }
         }
      }
   }
   
   return bestIndex;
}

//+------------------------------------------------------------------+
//| Get Nearest Internal SSL (below currentPrice)                    |
//| Returns index, or -1 if none found                               |
//+------------------------------------------------------------------+
int CLiquidityEngine::GetNearestInternalSSL(double currentPrice) const
{
   int bestIndex = -1;
   double minDistance = -1.0;
   
   for(int i = 0; i < m_levelCount; i++)
   {
      if(m_levels[i].state == LIQUIDITY_STATE_ACTIVE && 
         m_levels[i].role == LIQUIDITY_ROLE_SSL && 
         m_levels[i].classification == LIQUIDITY_CLASS_INTERNAL)
      {
         // SSL must be below price (or equal for boundary)
         if(m_levels[i].price <= currentPrice)
         {
            double dist = currentPrice - m_levels[i].price;
            if(bestIndex == -1 || dist < minDistance)
            {
               minDistance = dist;
               bestIndex = i;
            }
         }
      }
   }
   
   return bestIndex;
}

//+------------------------------------------------------------------+
//| Sweep and Consumption Evaluation                                 |
//+------------------------------------------------------------------+
void CLiquidityEngine::CheckSweepsAndConsumption(int barIndex)
{
   if(!m_initialized || barIndex < 0) return;
   
   double high = iHigh(m_symbol, m_timeframe, barIndex);
   double low = iLow(m_symbol, m_timeframe, barIndex);
   double close = iClose(m_symbol, m_timeframe, barIndex);
   datetime barTime = GetBarTime(barIndex);
   
   if(high == 0.0 || low == 0.0 || close == 0.0) return;
   
   for(int i = 0; i < m_levelCount; i++)
   {
      if(m_levels[i].state != LIQUIDITY_STATE_ACTIVE)
         continue; // Only check active levels
         
      if(m_levels[i].role == LIQUIDITY_ROLE_BSL)
      {
         // 1. Check Supersession (Body close beyond the level)
         // A body close beyond is a structural event (BOS/CHoCH), not resting liquidity anymore
         if(close > m_levels[i].price)
         {
            m_levels[i].state = LIQUIDITY_STATE_CONSUMED;
            continue;
         }
         
         // 2. Check Sweep (Wick beyond strictly by > ELT, close back inside)
         if(high > m_levels[i].price + m_elt && close <= m_levels[i].price)
         {
            // Transition: ACTIVE -> SWEPT -> CONSUMED
            m_levels[i].state = LIQUIDITY_STATE_CONSUMED;
            PrintFormat("[Liquidity Sweep] BSL Swept at %.5f by wick high %.5f | Time=%s", 
                        m_levels[i].price, high, TimeToString(barTime, TIME_DATE|TIME_MINUTES));
         }
      }
      else if(m_levels[i].role == LIQUIDITY_ROLE_SSL)
      {
         // 1. Check Supersession (Body close beyond the level)
         if(close < m_levels[i].price)
         {
            m_levels[i].state = LIQUIDITY_STATE_CONSUMED;
            continue;
         }
         
         // 2. Check Sweep (Wick beyond strictly by > ELT, close back inside)
         if(low < m_levels[i].price - m_elt && close >= m_levels[i].price)
         {
            // Transition: ACTIVE -> SWEPT -> CONSUMED
            m_levels[i].state = LIQUIDITY_STATE_CONSUMED;
            PrintFormat("[Liquidity Sweep] SSL Swept at %.5f by wick low %.5f | Time=%s", 
                        m_levels[i].price, low, TimeToString(barTime, TIME_DATE|TIME_MINUTES));
         }
      }
   }
}

#endif
