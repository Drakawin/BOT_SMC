//+------------------------------------------------------------------+
//|                                                 CFVGEngine.mqh   |
//|                                        Copyright 2026, BOT_SMC   |
//| Document: DOC02F (Fair Value Gap Engine)                         |
//+------------------------------------------------------------------+
#ifndef CFVGENGINE_MQH
#define CFVGENGINE_MQH

enum ENUM_FVG_STATE
{
   FVG_STATE_ACTIVE = 0,
   FVG_STATE_PARTIALLY_FILLED = 1,
   FVG_STATE_FILLED = 2,
   FVG_STATE_INVALIDATED = 3,
   FVG_STATE_EXPIRED = 4,
   FVG_STATE_ARCHIVED = 5,
   FVG_STATE_INVERSE_ACTIVE = 6,
   FVG_STATE_INVERSE_PARTIALLY_FILLED = 7,
   FVG_STATE_INVERSE_FILLED = 8
};

enum ENUM_FVG_DIRECTION
{
   FVG_DIRECTION_BULLISH = 0,
   FVG_DIRECTION_BEARISH = 1
};

struct SFVGRecord
{
   datetime             creationTime;  // Close time of candle 3
   double               originalLower;
   double               originalUpper;
   double               remainingLower;
   double               remainingUpper;
   ENUM_FVG_DIRECTION   direction;
   ENUM_FVG_STATE       state;
   bool                 isInverse;     // Flag to quickly identify IFVG
   bool                 isBPR;         // Flag to quickly identify BPR
};

class CFVGEngine
{
private:
   bool                 m_initialized;
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   double               m_minFvgSize;
   int                  m_maxActiveFVGs;
   
   SFVGRecord           m_fvgs[];
   int                  m_fvgCount;
   
   datetime             GetBarTime(int barIndex) const;
   double               GetBarHigh(int barIndex) const;
   double               GetBarLow(int barIndex) const;
   double               GetBarOpen(int barIndex) const;
   double               GetBarClose(int barIndex) const;
   
   void                 MergeWithOverlaps(SFVGRecord &newFvg);
   void                 CheckBPROverlaps(const SFVGRecord &newFvg);
   void                 EnforceActiveCap();

public:
                        CFVGEngine();
                       ~CFVGEngine();
                       
   bool                 Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int minPoints = 10, int maxActive = 5);
   bool                 IsInitialized() const;
   
   void                 DetectFVG(int barIndex);
   void                 CheckFills(int barIndex);
   
   int                  GetFVGCount() const { return m_fvgCount; }
   SFVGRecord           GetFVG(int index) const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CFVGEngine::CFVGEngine()
{
   m_initialized = false;
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_minFvgSize = 0.0;
   m_maxActiveFVGs = 5;
   m_fvgCount = 0;
   ArrayResize(m_fvgs, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CFVGEngine::~CFVGEngine()
{
   ArrayResize(m_fvgs, 0);
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CFVGEngine::Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int minPoints, int maxActive)
{
   if(StringLen(symbol) == 0) return false;
   
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_minFvgSize = minPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
   m_maxActiveFVGs = maxActive;
   m_initialized = true;
   
   return true;
}

bool CFVGEngine::IsInitialized() const { return m_initialized; }

datetime CFVGEngine::GetBarTime(int barIndex) const  { return iTime(m_symbol, m_timeframe, barIndex); }
double   CFVGEngine::GetBarHigh(int barIndex) const  { return iHigh(m_symbol, m_timeframe, barIndex); }
double   CFVGEngine::GetBarLow(int barIndex) const   { return iLow(m_symbol, m_timeframe, barIndex); }
double   CFVGEngine::GetBarOpen(int barIndex) const  { return iOpen(m_symbol, m_timeframe, barIndex); }
double   CFVGEngine::GetBarClose(int barIndex) const { return iClose(m_symbol, m_timeframe, barIndex); }

//+------------------------------------------------------------------+
//| Detect FVG (Requires 3 consecutive bars)                         |
//+------------------------------------------------------------------+
void CFVGEngine::DetectFVG(int barIndex)
{
   if(!m_initialized || barIndex < 0) return;
   
   // We evaluate on the close of Candle 3. So barIndex represents Candle 3.
   // Candle 2 = barIndex + 1
   // Candle 1 = barIndex + 2
   int c3 = barIndex;
   int c2 = barIndex + 1;
   int c1 = barIndex + 2;
   
   double high1 = GetBarHigh(c1);
   double low1 = GetBarLow(c1);
   double high3 = GetBarHigh(c3);
   double low3 = GetBarLow(c3);
   
   if(high1 == 0.0 || low3 == 0.0) return;
   
   SFVGRecord newFvg;
   bool detected = false;
   
   // Check Bullish FVG: low3 > high1
   if(low3 > high1)
   {
      double gap = low3 - high1;
      if(gap >= m_minFvgSize)
      {
         newFvg.direction = FVG_DIRECTION_BULLISH;
         newFvg.originalLower = high1;
         newFvg.originalUpper = low3;
         newFvg.remainingLower = high1;
         newFvg.remainingUpper = low3;
         newFvg.creationTime = GetBarTime(c3);
         newFvg.state = FVG_STATE_ACTIVE;
         newFvg.isInverse = false;
         newFvg.isBPR = false;
         detected = true;
      }
   }
   // Check Bearish FVG: high3 < low1
   else if(high3 < low1)
   {
      double gap = low1 - high3;
      if(gap >= m_minFvgSize)
      {
         newFvg.direction = FVG_DIRECTION_BEARISH;
         newFvg.originalLower = high3;
         newFvg.originalUpper = low1;
         newFvg.remainingLower = high3;
         newFvg.remainingUpper = low1;
         newFvg.creationTime = GetBarTime(c3);
         newFvg.state = FVG_STATE_ACTIVE;
         newFvg.isInverse = false;
         newFvg.isBPR = false;
         detected = true;
      }
   }
   
   if(detected)
   {
      MergeWithOverlaps(newFvg);
      CheckBPROverlaps(newFvg);
   }
}

//+------------------------------------------------------------------+
//| Merge With Overlaps and Add                                      |
//+------------------------------------------------------------------+
void CFVGEngine::MergeWithOverlaps(SFVGRecord &newFvg)
{
   bool merged = false;
   
   for(int i = 0; i < m_fvgCount; i++)
   {
      if((m_fvgs[i].state == FVG_STATE_ACTIVE || m_fvgs[i].state == FVG_STATE_PARTIALLY_FILLED) &&
         m_fvgs[i].direction == newFvg.direction)
      {
         // Check overlap between remaining bounds and new bounds
         bool overlaps = false;
         if(newFvg.originalLower <= m_fvgs[i].remainingUpper && newFvg.originalUpper >= m_fvgs[i].remainingLower)
            overlaps = true;
            
         if(overlaps)
         {
            m_fvgs[i].originalLower = MathMin(m_fvgs[i].originalLower, newFvg.originalLower);
            m_fvgs[i].originalUpper = MathMax(m_fvgs[i].originalUpper, newFvg.originalUpper);
            m_fvgs[i].remainingLower = MathMin(m_fvgs[i].remainingLower, newFvg.remainingLower);
            m_fvgs[i].remainingUpper = MathMax(m_fvgs[i].remainingUpper, newFvg.remainingUpper);
            // Update timestamp to the newest lock
            m_fvgs[i].creationTime = newFvg.creationTime;
            
            PrintFormat("[FVG] Merged %s overlapping FVG. New bounds: %.5f - %.5f", 
                        (newFvg.direction == FVG_DIRECTION_BULLISH ? "Bullish" : "Bearish"),
                        m_fvgs[i].remainingLower, m_fvgs[i].remainingUpper);
            merged = true;
            break;
         }
      }
   }
   
   if(!merged)
   {
      int newIndex = m_fvgCount;
      m_fvgCount++;
      ArrayResize(m_fvgs, m_fvgCount);
      m_fvgs[newIndex] = newFvg;
      
      PrintFormat("[FVG] New %s FVG created at %.5f - %.5f | Time=%s",
                  (newFvg.direction == FVG_DIRECTION_BULLISH ? "Bullish" : "Bearish"),
                  newFvg.remainingLower, newFvg.remainingUpper, 
                  TimeToString(newFvg.creationTime, TIME_DATE|TIME_MINUTES));
   }
   
   EnforceActiveCap();
}

//+------------------------------------------------------------------+
//| Check BPR Overlaps                                               |
//+------------------------------------------------------------------+
void CFVGEngine::CheckBPROverlaps(const SFVGRecord &newFvg)
{
   // newFvg is the newest confirmed FVG.
   // We look for opposite direction ACTIVE or PARTIALLY_FILLED FVGs (not IFVGs or BPRs) that overlap it.
   
   for(int i = 0; i < m_fvgCount; i++)
   {
      if((m_fvgs[i].state == FVG_STATE_ACTIVE || m_fvgs[i].state == FVG_STATE_PARTIALLY_FILLED) &&
         m_fvgs[i].direction != newFvg.direction && 
         !m_fvgs[i].isInverse && !m_fvgs[i].isBPR)
      {
         double overlapLower = MathMax(m_fvgs[i].remainingLower, newFvg.remainingLower);
         double overlapUpper = MathMin(m_fvgs[i].remainingUpper, newFvg.remainingUpper);
         
         // Valid overlap must satisfy Minimum FVG Size requirement (R-4)
         if((overlapUpper - overlapLower) >= m_minFvgSize)
         {
            // BPR inherits the direction of the newest FVG (the one that caused the overlap)
            SFVGRecord bprRecord;
            bprRecord.direction = newFvg.direction;
            bprRecord.originalLower = overlapLower;
            bprRecord.originalUpper = overlapUpper;
            bprRecord.remainingLower = overlapLower;
            bprRecord.remainingUpper = overlapUpper;
            bprRecord.creationTime = newFvg.creationTime;
            bprRecord.state = FVG_STATE_ACTIVE;
            bprRecord.isInverse = false;
            bprRecord.isBPR = true;
            
            int newIndex = m_fvgCount;
            m_fvgCount++;
            ArrayResize(m_fvgs, m_fvgCount);
            m_fvgs[newIndex] = bprRecord;
            
            PrintFormat("[FVG] %s Balanced Price Range (BPR) formed at %.5f - %.5f | Time=%s",
                        (bprRecord.direction == FVG_DIRECTION_BULLISH ? "Bullish" : "Bearish"),
                        bprRecord.remainingLower, bprRecord.remainingUpper, 
                        TimeToString(bprRecord.creationTime, TIME_DATE|TIME_MINUTES));
         }
      }
   }
   
   EnforceActiveCap();
}

//+------------------------------------------------------------------+
//| Enforce Active Cap per direction                                 |
//+------------------------------------------------------------------+
void CFVGEngine::EnforceActiveCap()
{
   int bullCount = 0;
   int bearCount = 0;
   
   // Loop backwards to find the newest ones and count them
   for(int i = m_fvgCount - 1; i >= 0; i--)
   {
      if(m_fvgs[i].state == FVG_STATE_ACTIVE || m_fvgs[i].state == FVG_STATE_PARTIALLY_FILLED || 
         m_fvgs[i].state == FVG_STATE_INVERSE_ACTIVE || m_fvgs[i].state == FVG_STATE_INVERSE_PARTIALLY_FILLED)
      {
         if(m_fvgs[i].direction == FVG_DIRECTION_BULLISH)
         {
            bullCount++;
            if(bullCount > m_maxActiveFVGs)
            {
               m_fvgs[i].state = FVG_STATE_EXPIRED;
               PrintFormat("[FVG] Expired older Bullish FVG/IFVG due to capacity cap.");
            }
         }
         else
         {
            bearCount++;
            if(bearCount > m_maxActiveFVGs)
            {
               m_fvgs[i].state = FVG_STATE_EXPIRED;
               PrintFormat("[FVG] Expired older Bearish FVG/IFVG due to capacity cap.");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Fills on closed bars                                       |
//+------------------------------------------------------------------+
void CFVGEngine::CheckFills(int barIndex)
{
   if(!m_initialized || barIndex < 0) return;
   
   double open = GetBarOpen(barIndex);
   double close = GetBarClose(barIndex);
   
   if(open == 0.0 || close == 0.0) return;
   
   double bodyLow = MathMin(open, close);
   double bodyHigh = MathMax(open, close);
   datetime barTime = GetBarTime(barIndex);
   
   for(int i = 0; i < m_fvgCount; i++)
   {
      // --- Handle Original FVGs ---
      if(m_fvgs[i].state == FVG_STATE_ACTIVE || m_fvgs[i].state == FVG_STATE_PARTIALLY_FILLED)
      {
         if(m_fvgs[i].direction == FVG_DIRECTION_BULLISH)
         {
            // Complete Fill
            if(bodyLow <= m_fvgs[i].remainingLower)
            {
               m_fvgs[i].state = FVG_STATE_INVERSE_ACTIVE;
               m_fvgs[i].isInverse = true;
               m_fvgs[i].direction = FVG_DIRECTION_BEARISH; // Reverses direction
               m_fvgs[i].remainingLower = m_fvgs[i].originalLower; // Reset boundaries
               m_fvgs[i].remainingUpper = m_fvgs[i].originalUpper;
               m_fvgs[i].creationTime = barTime;
               
               PrintFormat("[FVG] Bullish FVG Completely FILLED. Converted to Bearish IFVG. Time=%s", TimeToString(barTime, TIME_DATE|TIME_MINUTES));
            }
            // Partial Fill
            else if(bodyLow < m_fvgs[i].remainingUpper)
            {
               m_fvgs[i].remainingUpper = bodyLow;
               m_fvgs[i].state = FVG_STATE_PARTIALLY_FILLED;
               
               if(m_fvgs[i].remainingUpper <= m_fvgs[i].remainingLower)
               {
                  m_fvgs[i].state = FVG_STATE_INVALIDATED;
                  PrintFormat("[FVG] Bullish FVG INVALIDATED (collapsed).");
               }
            }
         }
         else if(m_fvgs[i].direction == FVG_DIRECTION_BEARISH)
         {
            // Complete Fill
            if(bodyHigh >= m_fvgs[i].remainingUpper)
            {
               m_fvgs[i].state = FVG_STATE_INVERSE_ACTIVE;
               m_fvgs[i].isInverse = true;
               m_fvgs[i].direction = FVG_DIRECTION_BULLISH; // Reverses direction
               m_fvgs[i].remainingLower = m_fvgs[i].originalLower; // Reset boundaries
               m_fvgs[i].remainingUpper = m_fvgs[i].originalUpper;
               m_fvgs[i].creationTime = barTime;
               
               PrintFormat("[FVG] Bearish FVG Completely FILLED. Converted to Bullish IFVG. Time=%s", TimeToString(barTime, TIME_DATE|TIME_MINUTES));
            }
            // Partial Fill
            else if(bodyHigh > m_fvgs[i].remainingLower)
            {
               m_fvgs[i].remainingLower = bodyHigh;
               m_fvgs[i].state = FVG_STATE_PARTIALLY_FILLED;
               
               if(m_fvgs[i].remainingUpper <= m_fvgs[i].remainingLower)
               {
                  m_fvgs[i].state = FVG_STATE_INVALIDATED;
                  PrintFormat("[FVG] Bearish FVG INVALIDATED (collapsed).");
               }
            }
         }
      }
      // --- Handle Inverse FVGs ---
      else if(m_fvgs[i].state == FVG_STATE_INVERSE_ACTIVE || m_fvgs[i].state == FVG_STATE_INVERSE_PARTIALLY_FILLED)
      {
         // IFVGs check logic is identical to normal FVGs based on their new direction
         if(m_fvgs[i].direction == FVG_DIRECTION_BULLISH) // Inverse Bullish
         {
            // Inverse Complete Fill
            if(bodyLow <= m_fvgs[i].remainingLower)
            {
               m_fvgs[i].state = FVG_STATE_INVERSE_FILLED;
               PrintFormat("[FVG] Bullish IFVG Completely FILLED (Consumed). Time=%s", TimeToString(barTime, TIME_DATE|TIME_MINUTES));
            }
            // Inverse Partial Fill
            else if(bodyLow < m_fvgs[i].remainingUpper)
            {
               m_fvgs[i].remainingUpper = bodyLow;
               m_fvgs[i].state = FVG_STATE_INVERSE_PARTIALLY_FILLED;
               
               if(m_fvgs[i].remainingUpper <= m_fvgs[i].remainingLower)
               {
                  m_fvgs[i].state = FVG_STATE_INVALIDATED;
                  PrintFormat("[FVG] Bullish IFVG INVALIDATED (collapsed).");
               }
            }
         }
         else if(m_fvgs[i].direction == FVG_DIRECTION_BEARISH) // Inverse Bearish
         {
            // Inverse Complete Fill
            if(bodyHigh >= m_fvgs[i].remainingUpper)
            {
               m_fvgs[i].state = FVG_STATE_INVERSE_FILLED;
               PrintFormat("[FVG] Bearish IFVG Completely FILLED (Consumed). Time=%s", TimeToString(barTime, TIME_DATE|TIME_MINUTES));
            }
            // Inverse Partial Fill
            else if(bodyHigh > m_fvgs[i].remainingLower)
            {
               m_fvgs[i].remainingLower = bodyHigh;
               m_fvgs[i].state = FVG_STATE_INVERSE_PARTIALLY_FILLED;
               
               if(m_fvgs[i].remainingUpper <= m_fvgs[i].remainingLower)
               {
                  m_fvgs[i].state = FVG_STATE_INVALIDATED;
                  PrintFormat("[FVG] Bearish IFVG INVALIDATED (collapsed).");
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get FVG by Index                                                 |
//+------------------------------------------------------------------+
SFVGRecord CFVGEngine::GetFVG(int index) const
{
   SFVGRecord emptyRecord;
   ZeroMemory(emptyRecord);
   
   if(index >= 0 && index < m_fvgCount)
      return m_fvgs[index];
      
   return emptyRecord;
}

#endif