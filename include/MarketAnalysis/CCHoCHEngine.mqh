//+------------------------------------------------------------------+
//|                                               CCHoCHEngine.mqh   |
//|                                        Copyright 2026, BOT_SMC   |
//|                                            Layer 2: Market Analysis|
//| Document: DOC02C (Change of Character Engine)                    |
//| Document: DOC06A (Implementation Blueprint)                      |
//+------------------------------------------------------------------+
#ifndef CCHOCHENGINE_MQH
#define CCHOCHENGINE_MQH

#include "CMarketStructureEngine.mqh"
#include "CBOSEngine.mqh"

//+------------------------------------------------------------------+
//| Enum: ENUM_PREVAILING_DIRECTION                                  |
//| Purpose: Define prevailing market direction                      |
//| DOC02C: Lines 214-228                                            |
//+------------------------------------------------------------------+
enum ENUM_PREVAILING_DIRECTION
{
   PREVAILING_DIRECTION_UNDEFINED = 0,
   PREVAILING_DIRECTION_BULLISH   = 1,
   PREVAILING_DIRECTION_BEARISH   = 2
};

//+------------------------------------------------------------------+
//| Enum: ENUM_CHOCH_DIRECTION                                       |
//| Purpose: Define CHoCH event direction                            |
//| DOC02C: Lines 110-111                                            |
//+------------------------------------------------------------------+
enum ENUM_CHOCH_DIRECTION
{
   CHOCH_DIRECTION_NONE    = 0,
   CHOCH_DIRECTION_BULLISH = 1,
   CHOCH_DIRECTION_BEARISH = 2
};

//+------------------------------------------------------------------+
//| Struct: CHoCHEvent                                               |
//| Purpose: Store complete CHoCH event information                  |
//| DOC02C: Lines 110-118                                            |
//+------------------------------------------------------------------+
struct CHoCHEvent
{
   datetime                  timestamp;
   int                       barIndex;
   double                    breakPrice;
   double                    swingPrice;
   ENUM_CHOCH_DIRECTION      direction;
   ENUM_PREVAILING_DIRECTION prevailingDirectionBefore;
   bool                      isValid;
};

//+------------------------------------------------------------------+
//| Class: CCHoCHEngine                                              |
//| Purpose: Detect Change of Character events                       |
//| DOC02C: Full specification                                       |
//| Owner: Layer 2 (Market Analysis)                                 |
//| Dependencies: CMarketStructureEngine, CBOSEngine                 |
//+------------------------------------------------------------------+
class CCHoCHEngine
{
private:
   bool                        m_initialized;
   string                      m_symbol;
   ENUM_TIMEFRAMES             m_timeframe;
   CMarketStructureEngine*     m_structureEngine;
   CBOSEngine*                 m_bosEngine;
   
   ENUM_PREVAILING_DIRECTION   m_prevailingDirection;
   CHoCHEvent                  m_lastCHoCH;
   int                         m_chochCount;
   
   // For Prevailing Direction derivation
   ENUM_PREVAILING_DIRECTION   m_lastBOSDirection;
   datetime                    m_lastBOSTime;
   datetime                    m_lastCHoCHTime;
   
   // Private methods
   bool                        ValidateBarIndex(int barIndex) const;
   double                      GetBarClose(int barIndex) const;
   bool                        CheckBullishCHoCH(int barIndex, double barClose);
   bool                        CheckBearishCHoCH(int barIndex, double barClose);
   void                        RecordCHoCH(int barIndex, double breakPrice, double swingPrice, ENUM_CHOCH_DIRECTION direction);
   void                        DerivePrevailingDirection();
   void                        SyncBOSState();

public:
                     CCHoCHEngine();
                    ~CCHoCHEngine();
   
   bool              Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CMarketStructureEngine* structureEngine, CBOSEngine* bosEngine);
   bool              IsInitialized() const;
   
   bool              DetectCHoCH(int barIndex);
   
   ENUM_PREVAILING_DIRECTION GetPrevailingDirection() const;
   CHoCHEvent        GetLastCHoCH() const;
   int               GetCHoCHCount() const;
   bool              IsBullishCHoCH() const;
   bool              IsBearishCHoCH() const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CCHoCHEngine::CCHoCHEngine()
{
   m_initialized = false;
   m_structureEngine = NULL;
   m_bosEngine = NULL;
   m_prevailingDirection = PREVAILING_DIRECTION_UNDEFINED;
   m_chochCount = 0;
   m_lastBOSDirection = PREVAILING_DIRECTION_UNDEFINED;
   m_lastBOSTime = 0;
   m_lastCHoCHTime = 0;
   
   // Initialize last CHoCH event
   m_lastCHoCH.timestamp = 0;
   m_lastCHoCH.barIndex = 0;
   m_lastCHoCH.breakPrice = 0.0;
   m_lastCHoCH.swingPrice = 0.0;
   m_lastCHoCH.direction = CHOCH_DIRECTION_NONE;
   m_lastCHoCH.prevailingDirectionBefore = PREVAILING_DIRECTION_UNDEFINED;
   m_lastCHoCH.isValid = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CCHoCHEngine::~CCHoCHEngine()
{
}

//+------------------------------------------------------------------+
//| Initialize engine                                                |
//+------------------------------------------------------------------+
bool CCHoCHEngine::Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CMarketStructureEngine* structureEngine, CBOSEngine* bosEngine)
{
   if(StringLen(symbol) == 0)
      return false;
   
   if(structureEngine == NULL || bosEngine == NULL)
      return false;
   
   if(!structureEngine.IsInitialized() || !bosEngine.IsInitialized())
      return false;
   
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_structureEngine = structureEngine;
   m_bosEngine = bosEngine;
   m_initialized = true;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if initialized                                             |
//+------------------------------------------------------------------+
bool CCHoCHEngine::IsInitialized() const
{
   return m_initialized;
}

//+------------------------------------------------------------------+
//| Validate bar index                                               |
//+------------------------------------------------------------------+
bool CCHoCHEngine::ValidateBarIndex(int barIndex) const
{
   if(barIndex < 0)
      return false;
   
   int totalBars = Bars(m_symbol, m_timeframe);
   return (barIndex < totalBars);
}

//+------------------------------------------------------------------+
//| Get bar close price                                              |
//+------------------------------------------------------------------+
double CCHoCHEngine::GetBarClose(int barIndex) const
{
   if(!ValidateBarIndex(barIndex))
      return 0.0;
   
   return iClose(m_symbol, m_timeframe, barIndex);
}

//+------------------------------------------------------------------+
//| Sync BOS state from CBOSEngine                                   |
//| DOC02C: Lines 216-223 - Prevailing Direction derivation          |
//+------------------------------------------------------------------+
void CCHoCHEngine::SyncBOSState()
{
   if(m_bosEngine == NULL)
      return;
   
   datetime lastBOSTime = m_bosEngine.GetLastBOSTimestamp();
   
   // If BOS engine has a newer event than we've seen
   if(lastBOSTime > m_lastBOSTime && lastBOSTime > 0)
   {
      m_lastBOSTime = lastBOSTime;
      
      // Map BOS direction to Prevailing Direction
      ENUM_BOS_DIRECTION bosDir = m_bosEngine.GetLastBOSDirection();
      if(bosDir == BOS_DIRECTION_BULLISH)
         m_lastBOSDirection = PREVAILING_DIRECTION_BULLISH;
      else if(bosDir == BOS_DIRECTION_BEARISH)
         m_lastBOSDirection = PREVAILING_DIRECTION_BEARISH;
      else
         m_lastBOSDirection = PREVAILING_DIRECTION_UNDEFINED;
   }
}

//+------------------------------------------------------------------+
//| Derive Prevailing Direction                                      |
//| DOC02C: Lines 214-228                                            |
//+------------------------------------------------------------------+
void CCHoCHEngine::DerivePrevailingDirection()
{
   // If no structural events yet, seed from DOC02A Structure State
   if(m_lastBOSTime == 0 && m_lastCHoCHTime == 0)
   {
      ENUM_STRUCTURE_STATE structureState = m_structureEngine.GetStructureState();
      
      if(structureState == STRUCTURE_STATE_BULLISH)
         m_prevailingDirection = PREVAILING_DIRECTION_BULLISH;
      else if(structureState == STRUCTURE_STATE_BEARISH)
         m_prevailingDirection = PREVAILING_DIRECTION_BEARISH;
      else
         m_prevailingDirection = PREVAILING_DIRECTION_UNDEFINED;
      
      return;
   }
   
   // Compare timestamps to find most recent structural event
   if(m_lastBOSTime >= m_lastCHoCHTime)
   {
      // Most recent event is BOS
      m_prevailingDirection = m_lastBOSDirection;
   }
   else
   {
      // Most recent event is CHoCH - direction is already set in m_prevailingDirection
      // when RecordCHoCH() was called (flip authority)
   }
   
}

//+------------------------------------------------------------------+
//| Check for Bullish CHoCH (reversal from bearish to bullish)       |
//| DOC02C: Lines 280-316                                            |
//+------------------------------------------------------------------+
bool CCHoCHEngine::CheckBullishCHoCH(int barIndex, double barClose)
{
   if(m_structureEngine == NULL)
      return false;
   
   // Get the most recent confirmed Swing High (opposing type for bullish CHoCH)
   double swingHigh = m_structureEngine.GetLastSwingHighPrice();
   int swingHighBar = m_structureEngine.GetLastSwingHighBar();
   datetime swingHighTime = iTime(m_symbol, m_timeframe, swingHighBar);
   
   // Guard: swing must exist
   if(swingHigh == 0.0)
      return false;
   
   // Guard: swing must be confirmed before or at the breaking candle close
   datetime barTime = iTime(m_symbol, m_timeframe, barIndex);
   if(swingHighTime > barTime)
      return false;
   
   // Guard: barClose must be valid
   if(barClose == 0.0)
      return false;
   
   // DOC02C Rule #3: Strict inequality
   // Bullish CHoCH: close > swingHighPrice
   
   if(barClose > swingHigh)
   {
      return true;
   }
      
   return false;
}

//+------------------------------------------------------------------+
//| Check for Bearish CHoCH (reversal from bullish to bearish)       |
//| DOC02C: Lines 329-362                                            |
//+------------------------------------------------------------------+
bool CCHoCHEngine::CheckBearishCHoCH(int barIndex, double barClose)
{
   if(m_structureEngine == NULL)
      return false;
   
   // Get the most recent confirmed Swing Low (opposing type for bearish CHoCH)
   double swingLow = m_structureEngine.GetLastSwingLowPrice();
   int swingLowBar = m_structureEngine.GetLastSwingLowBar();
   datetime swingLowTime = iTime(m_symbol, m_timeframe, swingLowBar);
   
   // Guard: swing must exist
   if(swingLow == 0.0)
      return false;
   
   // Guard: swing must be confirmed before or at the breaking candle close
   datetime barTime = iTime(m_symbol, m_timeframe, barIndex);
   if(swingLowTime > barTime)
      return false;
   
   // Guard: barClose must be valid
   if(barClose == 0.0)
      return false;
   
   // DOC02C Rule #3: Strict inequality
   // Bearish CHoCH: close < swingLowPrice
   if(barClose < swingLow)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Record CHoCH event                                               |
//| DOC02C: Lines 110-118, 143-144                                   |
//+------------------------------------------------------------------+
void CCHoCHEngine::RecordCHoCH(int barIndex, double breakPrice, double swingPrice, ENUM_CHOCH_DIRECTION direction)
{

   // Store prevailing direction before the flip
   ENUM_PREVAILING_DIRECTION prevDirection = m_prevailingDirection;
   
   // Populate CHoCH event (immutable record)
   m_lastCHoCH.timestamp = iTime(m_symbol, m_timeframe, barIndex);
   m_lastCHoCH.barIndex = barIndex;
   m_lastCHoCH.breakPrice = breakPrice;
   m_lastCHoCH.swingPrice = swingPrice;
   m_lastCHoCH.direction = direction;
   m_lastCHoCH.prevailingDirectionBefore = prevDirection;
   m_lastCHoCH.isValid = true;
   
   // DOC02C Rule #8: Flip authority - CHoCH flips Prevailing Direction
   if(direction == CHOCH_DIRECTION_BULLISH)
      m_prevailingDirection = PREVAILING_DIRECTION_BULLISH;
   else if(direction == CHOCH_DIRECTION_BEARISH)
      m_prevailingDirection = PREVAILING_DIRECTION_BEARISH;
   
   // Update CHoCH timestamp for derivation
   m_lastCHoCHTime = m_lastCHoCH.timestamp;
   
   // Increment count
   m_chochCount++;
}

//+------------------------------------------------------------------+
//| Detect CHoCH on closed bar                                       |
//| DOC02C: Full detection flow                                      |
//+------------------------------------------------------------------+
bool CCHoCHEngine::DetectCHoCH(int barIndex)
{
   // Guard: must be initialized
   if(!m_initialized)
      return false;
   
   // Guard: valid bar index
   if(!ValidateBarIndex(barIndex))
      return false;
   
   // Get bar close price (DOC02C Rule #2: Body close only)
   double barClose = GetBarClose(barIndex);
   if(barClose == 0.0)
      return false;
   
   // Step 1: Sync BOS state from CBOSEngine
   SyncBOSState();
   
   // Step 2: Derive Prevailing Direction
   DerivePrevailingDirection();

   
   // Step 3: Directional Gate (DOC02C Rule #5)
   // No CHoCH when Prevailing Direction is UNDEFINED
   if(m_prevailingDirection == PREVAILING_DIRECTION_UNDEFINED)
{
   Print("[CHOCH DEBUG] Prevailing Direction = UNDEFINED");
   return false;
}
   
   // Step 4: Check for CHoCH based on Prevailing Direction
   // DOC02C Rule #4: Reversal only (against Prevailing Direction)
   
   if(m_prevailingDirection == PREVAILING_DIRECTION_BULLISH)
     {
      

      // Prevailing is BULLISH → check for Bearish CHoCH (reversal)
      if(CheckBearishCHoCH(barIndex, barClose))
      {
         double swingPrice = m_structureEngine.GetLastSwingLowPrice();
         
       PrintFormat(
"[AUDIT] Prev=%d | Emit=Bullish | Break=%.5f | Swing=%.5f",
(int)m_prevailingDirection,
barClose,
swingPrice
);
         RecordCHoCH(barIndex, barClose, swingPrice, CHOCH_DIRECTION_BEARISH);
         return true;
      }
   }
   else if(m_prevailingDirection == PREVAILING_DIRECTION_BEARISH)
   {

      // Prevailing is BEARISH → check for Bullish CHoCH (reversal)
      if(CheckBullishCHoCH(barIndex, barClose))
      {
         double swingPrice = m_structureEngine.GetLastSwingHighPrice();
         
         PrintFormat(
"[AUDIT] Prev=%d | Emit=Bearish | Break=%.5f | Swing=%.5f",
(int)m_prevailingDirection,
barClose,
swingPrice
);

         RecordCHoCH(barIndex, barClose, swingPrice, CHOCH_DIRECTION_BULLISH);
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get current Prevailing Direction                                 |
//| DOC02C: Line 120                                                 |
//+------------------------------------------------------------------+
ENUM_PREVAILING_DIRECTION CCHoCHEngine::GetPrevailingDirection() const
{
   return m_prevailingDirection;
}

//+------------------------------------------------------------------+
//| Get last CHoCH event                                             |
//+------------------------------------------------------------------+
CHoCHEvent CCHoCHEngine::GetLastCHoCH() const
{
   return m_lastCHoCH;
}

//+------------------------------------------------------------------+
//| Get total CHoCH count                                            |
//| Runtime Validation Helper (not required by DOC02C)               |
//+------------------------------------------------------------------+
int CCHoCHEngine::GetCHoCHCount() const
{
   return m_chochCount;
}

//+------------------------------------------------------------------+
//| Check if last CHoCH was bullish                                  |
//| Runtime Validation Helper (not required by DOC02C)               |
//+------------------------------------------------------------------+
bool CCHoCHEngine::IsBullishCHoCH() const
{
   return (m_lastCHoCH.isValid && m_lastCHoCH.direction == CHOCH_DIRECTION_BULLISH);
}

//+------------------------------------------------------------------+
//| Check if last CHoCH was bearish                                  |
//| Runtime Validation Helper (not required by DOC02C)               |
//+------------------------------------------------------------------+
bool CCHoCHEngine::IsBearishCHoCH() const
{
   return (m_lastCHoCH.isValid && m_lastCHoCH.direction == CHOCH_DIRECTION_BEARISH);
}

#endif
