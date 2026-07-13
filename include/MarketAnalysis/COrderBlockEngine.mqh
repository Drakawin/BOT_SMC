//+------------------------------------------------------------------+
//|                                            COrderBlockEngine.mqh |
//|                                        Copyright 2026, BOT_SMC   |
//| Document: DOC02EB (Order Block Engine)                           |
//| Document: DOC02I  (Breaker Block Engine)                         |
//+------------------------------------------------------------------+
#ifndef CORDERBLOCKENGINE_MQH
#define CORDERBLOCKENGINE_MQH

enum ENUM_OB_STATE
{
   OB_STATE_ACTIVE = 0,
   OB_STATE_MITIGATED = 1,
   OB_STATE_INVALIDATED = 2,
   OB_STATE_EXPIRED = 3,
   OB_STATE_ARCHIVED = 4
};

enum ENUM_OB_DIRECTION
{
   OB_DIRECTION_BULLISH = 0,
   OB_DIRECTION_BEARISH = 1
};

struct SOBRecord
{
   datetime             creationTime; // Time of the OB candle itself
   double               zoneHigh;
   double               zoneLow;
   double               nearEdge;
   double               farEdge;
   ENUM_OB_DIRECTION    direction;
   ENUM_OB_STATE        state;
   datetime             lockTime;     // Time of the BOS/CHoCH breakout that confirmed it
   datetime             invalidationTime; // Time when it was invalidated
   bool                 isPromotedToBreaker; // Flag to ensure single promotion
};

enum ENUM_BB_STATE
{
   BB_STATE_ACTIVE = 0,
   BB_STATE_MITIGATED = 1,
   BB_STATE_ARCHIVED = 2
};

enum ENUM_BB_DIRECTION
{
   BB_DIRECTION_BULLISH = 0,
   BB_DIRECTION_BEARISH = 1
};

struct SBreakerRecord
{
   datetime             promotionTime;
   double               upperBoundary;
   double               lowerBoundary;
   ENUM_BB_DIRECTION    direction;
   ENUM_BB_STATE        state;
   
   // Reference to the original OB
   datetime             obCreationTime;
   datetime             obInvalidationTime;
   ENUM_OB_DIRECTION    originalDirection;
};

class COrderBlockEngine
{
private:
   bool                 m_initialized;
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   
   SOBRecord            m_obs[];
   int                  m_obCount;
   
   SBreakerRecord       m_breakers[];
   int                  m_bbCount;
   
   datetime             GetBarTime(int barIndex) const;
   double               GetBarHigh(int barIndex) const;
   double               GetBarLow(int barIndex) const;
   double               GetBarOpen(int barIndex) const;
   double               GetBarClose(int barIndex) const;
   
   void                 ExpirePreviousActive(ENUM_OB_DIRECTION dir);

public:
                        COrderBlockEngine();
                       ~COrderBlockEngine();
                       
   bool                 Initialize(string symbol, ENUM_TIMEFRAMES timeframe);
   bool                 IsInitialized() const;
   
   // --- Order Block Methods ---
   void                 DetectOrderBlock(int breakoutBarIndex, ENUM_OB_DIRECTION direction);
   void                 CheckMitigationAndInvalidation(int barIndex);
   int                  GetOBCount() const { return m_obCount; }
   SOBRecord            GetOB(int index) const;
   
   // --- Breaker Block Methods ---
   int                  GetMostRecentlyInvalidatedOB(ENUM_OB_DIRECTION dir) const;
   void                 MarkOBAsPromoted(int index);
   
   void                 DetectBreakerBlock(int breakoutBarIndex, ENUM_OB_DIRECTION breakDir);
   void                 CheckBreakerMitigation(int barIndex);
   int                  GetBBCount() const { return m_bbCount; }
   SBreakerRecord       GetBB(int index) const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
COrderBlockEngine::COrderBlockEngine()
{
   m_initialized = false;
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_obCount = 0;
   m_bbCount = 0;
   ArrayResize(m_obs, 0);
   ArrayResize(m_breakers, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
COrderBlockEngine::~COrderBlockEngine()
{
   ArrayResize(m_obs, 0);
   ArrayResize(m_breakers, 0);
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool COrderBlockEngine::Initialize(string symbol, ENUM_TIMEFRAMES timeframe)
{
   if(StringLen(symbol) == 0) return false;
   
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_initialized = true;
   
   return true;
}

bool COrderBlockEngine::IsInitialized() const { return m_initialized; }

datetime COrderBlockEngine::GetBarTime(int barIndex) const  { return iTime(m_symbol, m_timeframe, barIndex); }
double   COrderBlockEngine::GetBarHigh(int barIndex) const  { return iHigh(m_symbol, m_timeframe, barIndex); }
double   COrderBlockEngine::GetBarLow(int barIndex) const   { return iLow(m_symbol, m_timeframe, barIndex); }
double   COrderBlockEngine::GetBarOpen(int barIndex) const  { return iOpen(m_symbol, m_timeframe, barIndex); }
double   COrderBlockEngine::GetBarClose(int barIndex) const { return iClose(m_symbol, m_timeframe, barIndex); }

//+------------------------------------------------------------------+
//| Expire Previous Active Order Block (Supersession rule)           |
//+------------------------------------------------------------------+
void COrderBlockEngine::ExpirePreviousActive(ENUM_OB_DIRECTION dir)
{
   for(int i = m_obCount - 1; i >= 0; i--)
   {
      if(m_obs[i].state == OB_STATE_ACTIVE && m_obs[i].direction == dir)
      {
         m_obs[i].state = OB_STATE_EXPIRED;
         PrintFormat("[OB] Expired older %s OB due to supersession.", (dir == OB_DIRECTION_BULLISH ? "Bullish" : "Bearish"));
         break; 
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Order Block (Triggered by BOS/CHoCH)                      |
//+------------------------------------------------------------------+
void COrderBlockEngine::DetectOrderBlock(int breakoutBarIndex, ENUM_OB_DIRECTION direction)
{
   if(!m_initialized || breakoutBarIndex < 0) return;
   
   int searchLimit = breakoutBarIndex + 50; 
   int foundObBar = -1;
   
   for(int i = breakoutBarIndex + 1; i <= searchLimit; i++)
   {
      double open = GetBarOpen(i);
      double close = GetBarClose(i);
      
      if(open == 0.0 || close == 0.0) continue;
      
      if(direction == OB_DIRECTION_BULLISH && close < open)
      {
         foundObBar = i;
         break;
      }
      else if(direction == OB_DIRECTION_BEARISH && close > open)
      {
         foundObBar = i;
         break;
      }
   }
   
   if(foundObBar != -1)
   {
      SOBRecord newOb;
      newOb.creationTime = GetBarTime(foundObBar);
      newOb.lockTime = GetBarTime(breakoutBarIndex);
      newOb.zoneHigh = GetBarHigh(foundObBar);
      newOb.zoneLow = GetBarLow(foundObBar);
      newOb.direction = direction;
      newOb.state = OB_STATE_ACTIVE;
      newOb.invalidationTime = 0;
      newOb.isPromotedToBreaker = false;
      
      if(direction == OB_DIRECTION_BULLISH)
      {
         newOb.nearEdge = newOb.zoneHigh;
         newOb.farEdge = newOb.zoneLow;
      }
      else
      {
         newOb.nearEdge = newOb.zoneLow;
         newOb.farEdge = newOb.zoneHigh;
      }
      
      ExpirePreviousActive(direction);
      
      int newIndex = m_obCount;
      m_obCount++;
      ArrayResize(m_obs, m_obCount);
      m_obs[newIndex] = newOb;
      
      PrintFormat("[OB] New %s Order Block confirmed at %.5f - %.5f | Source Time=%s | Locked at=%s",
                  (direction == OB_DIRECTION_BULLISH ? "Bullish" : "Bearish"),
                  newOb.zoneLow, newOb.zoneHigh, 
                  TimeToString(newOb.creationTime, TIME_DATE|TIME_MINUTES),
                  TimeToString(newOb.lockTime, TIME_DATE|TIME_MINUTES));
   }
   else
   {
      PrintFormat("[OB] Failed to find opposite-body candle for %s impulse (Gap move).", (direction == OB_DIRECTION_BULLISH ? "Bullish" : "Bearish"));
   }
}

//+------------------------------------------------------------------+
//| Check Mitigation and Invalidation (Order Blocks)                 |
//+------------------------------------------------------------------+
void COrderBlockEngine::CheckMitigationAndInvalidation(int barIndex)
{
   if(!m_initialized || barIndex < 0) return;
   
   double open = GetBarOpen(barIndex);
   double close = GetBarClose(barIndex);
   datetime barTime = GetBarTime(barIndex);
   
   if(open == 0.0 || close == 0.0) return;
   
   double bodyLow = MathMin(open, close);
   double bodyHigh = MathMax(open, close);
   
   for(int i = 0; i < m_obCount; i++)
   {
      if(m_obs[i].state != OB_STATE_ACTIVE && m_obs[i].state != OB_STATE_MITIGATED)
         continue;
         
      if(barTime <= m_obs[i].lockTime)
         continue;
         
      if(m_obs[i].direction == OB_DIRECTION_BULLISH)
      {
         if(close < m_obs[i].farEdge)
         {
            m_obs[i].state = OB_STATE_INVALIDATED;
            m_obs[i].invalidationTime = barTime;
            PrintFormat("[OB] Bullish OB INVALIDATED by body close %.5f below Far Edge %.5f | Time=%s", close, m_obs[i].farEdge, TimeToString(barTime, TIME_DATE|TIME_MINUTES));
         }
         else if(m_obs[i].state == OB_STATE_ACTIVE && bodyLow <= m_obs[i].nearEdge)
         {
            m_obs[i].state = OB_STATE_MITIGATED;
            PrintFormat("[OB] Bullish OB MITIGATED (body into zone) | Time=%s", TimeToString(barTime, TIME_DATE|TIME_MINUTES));
         }
      }
      else if(m_obs[i].direction == OB_DIRECTION_BEARISH)
      {
         if(close > m_obs[i].farEdge)
         {
            m_obs[i].state = OB_STATE_INVALIDATED;
            m_obs[i].invalidationTime = barTime;
            PrintFormat("[OB] Bearish OB INVALIDATED by body close %.5f above Far Edge %.5f | Time=%s", close, m_obs[i].farEdge, TimeToString(barTime, TIME_DATE|TIME_MINUTES));
         }
         else if(m_obs[i].state == OB_STATE_ACTIVE && bodyHigh >= m_obs[i].nearEdge)
         {
            m_obs[i].state = OB_STATE_MITIGATED;
            PrintFormat("[OB] Bearish OB MITIGATED (body into zone) | Time=%s", TimeToString(barTime, TIME_DATE|TIME_MINUTES));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get Most Recently Invalidated OB for Breaker Promotion           |
//+------------------------------------------------------------------+
int COrderBlockEngine::GetMostRecentlyInvalidatedOB(ENUM_OB_DIRECTION dir) const
{
   int bestIndex = -1;
   datetime latestTime = 0;
   
   for(int i = 0; i < m_obCount; i++)
   {
      if(m_obs[i].state == OB_STATE_INVALIDATED && m_obs[i].direction == dir && !m_obs[i].isPromotedToBreaker)
      {
         if(m_obs[i].invalidationTime > latestTime)
         {
            latestTime = m_obs[i].invalidationTime;
            bestIndex = i;
         }
      }
   }
   return bestIndex;
}

//+------------------------------------------------------------------+
//| Mark OB as Promoted to prevent duplicate breakers                |
//+------------------------------------------------------------------+
void COrderBlockEngine::MarkOBAsPromoted(int index)
{
   if(index >= 0 && index < m_obCount)
   {
      m_obs[index].isPromotedToBreaker = true;
   }
}

//+------------------------------------------------------------------+
//| Get OB by Index                                                  |
//+------------------------------------------------------------------+
SOBRecord COrderBlockEngine::GetOB(int index) const
{
   SOBRecord emptyRecord;
   ZeroMemory(emptyRecord);
   if(index >= 0 && index < m_obCount) return m_obs[index];
   return emptyRecord;
}

//+------------------------------------------------------------------+
//| Detect Breaker Block (Triggered by opposite BOS/CHoCH)           |
//+------------------------------------------------------------------+
void COrderBlockEngine::DetectBreakerBlock(int breakoutBarIndex, ENUM_OB_DIRECTION breakDir)
{
   if(!m_initialized || breakoutBarIndex < 0) return;
   
   ENUM_OB_DIRECTION targetObDir = (breakDir == OB_DIRECTION_BULLISH) ? OB_DIRECTION_BEARISH : OB_DIRECTION_BULLISH;
   
   int obIndex = GetMostRecentlyInvalidatedOB(targetObDir);
   
   if(obIndex != -1)
   {
      SOBRecord originalOB = m_obs[obIndex];
      
      SBreakerRecord newBB;
      newBB.promotionTime = GetBarTime(breakoutBarIndex);
      newBB.upperBoundary = originalOB.zoneHigh;
      newBB.lowerBoundary = originalOB.zoneLow;
      
      newBB.direction = (originalOB.direction == OB_DIRECTION_BEARISH) ? BB_DIRECTION_BULLISH : BB_DIRECTION_BEARISH;
      newBB.state = BB_STATE_ACTIVE;
      
      newBB.obCreationTime = originalOB.creationTime;
      newBB.obInvalidationTime = originalOB.invalidationTime;
      newBB.originalDirection = originalOB.direction;
      
      MarkOBAsPromoted(obIndex);
      
      int newIndex = m_bbCount;
      m_bbCount++;
      ArrayResize(m_breakers, m_bbCount);
      m_breakers[newIndex] = newBB;
      
      PrintFormat("[Breaker] Promoted %s Breaker Block at %.5f - %.5f | Original OB Invalidation Time=%s | Promotion Time=%s",
                  (newBB.direction == BB_DIRECTION_BULLISH ? "Bullish" : "Bearish"),
                  newBB.lowerBoundary, newBB.upperBoundary, 
                  TimeToString(newBB.obInvalidationTime, TIME_DATE|TIME_MINUTES),
                  TimeToString(newBB.promotionTime, TIME_DATE|TIME_MINUTES));
   }
}

//+------------------------------------------------------------------+
//| Check Mitigation (Breaker Blocks)                                |
//+------------------------------------------------------------------+
void COrderBlockEngine::CheckBreakerMitigation(int barIndex)
{
   if(!m_initialized || barIndex < 0) return;
   
   double open = GetBarOpen(barIndex);
   double close = GetBarClose(barIndex);
   datetime barTime = GetBarTime(barIndex);
   
   if(open == 0.0 || close == 0.0) return;
   
   for(int i = 0; i < m_bbCount; i++)
   {
      if(m_breakers[i].state != BB_STATE_ACTIVE)
         continue;
         
      if(barTime <= m_breakers[i].promotionTime)
         continue;
         
      if(m_breakers[i].direction == BB_DIRECTION_BULLISH)
      {
         if(close <= m_breakers[i].upperBoundary)
         {
            m_breakers[i].state = BB_STATE_MITIGATED;
            PrintFormat("[Breaker] Bullish Breaker MITIGATED by body close %.5f into zone %.5f | Time=%s", close, m_breakers[i].upperBoundary, TimeToString(barTime, TIME_DATE|TIME_MINUTES));
         }
      }
      else if(m_breakers[i].direction == BB_DIRECTION_BEARISH)
      {
         if(close >= m_breakers[i].lowerBoundary)
         {
            m_breakers[i].state = BB_STATE_MITIGATED;
            PrintFormat("[Breaker] Bearish Breaker MITIGATED by body close %.5f into zone %.5f | Time=%s", close, m_breakers[i].lowerBoundary, TimeToString(barTime, TIME_DATE|TIME_MINUTES));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get BB by Index                                                  |
//+------------------------------------------------------------------+
SBreakerRecord COrderBlockEngine::GetBB(int index) const
{
   SBreakerRecord emptyRecord;
   ZeroMemory(emptyRecord);
   if(index >= 0 && index < m_bbCount) return m_breakers[index];
   return emptyRecord;
}

#endif