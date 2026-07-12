//+------------------------------------------------------------------+
//|                                                CBOSEngine.mqh   |
//|                                        Copyright 2026, BOT_SMC   |
//|                                            Layer 2: Market Analysis|
//| Document: DOC02B (Break of Structure Engine)                     |
//| Document: DOC06A (Implementation Blueprint)                      |
//+------------------------------------------------------------------+
#ifndef CBOSENGINE_MQH
#define CBOSENGINE_MQH

#include "CMarketStructureEngine.mqh"

//+------------------------------------------------------------------+
//| Enum: ENUM_BOS_DIRECTION                                         |
//| Purpose: Define BOS direction                                    |
//+------------------------------------------------------------------+
enum ENUM_BOS_DIRECTION
{
   BOS_DIRECTION_NONE    = 0,
   BOS_DIRECTION_BULLISH = 1,
   BOS_DIRECTION_BEARISH = 2
};

//+------------------------------------------------------------------+
//| Struct: BOSEvent                                                 |
//| Purpose: Store complete BOS event information                    |
//+------------------------------------------------------------------+
struct BOSEvent
{
   datetime            timestamp;
   int                 barIndex;
   double              breakPrice;
   double              swingPrice;
   ENUM_BOS_DIRECTION  direction;
   bool                isValid;
};

//+------------------------------------------------------------------+
//| Class: CBOSEngine                                                |
//| Purpose: Detect Break of Structure events                        |
//| Owner: Layer 2 (DOC02B)                                          |
//| Consumers: Trading Intelligence Layer                            |
//| Dependencies: CMarketStructureEngine                             |
//+------------------------------------------------------------------+
class CBOSEngine
{
private:
   bool                     m_initialized;
   CMarketStructureEngine*  m_structureEngine;
   string                   m_symbol;
   ENUM_TIMEFRAMES          m_timeframe;
   
   BOSEvent                 m_lastBOS;
   int                      m_bosCount;
   
   bool   ValidateBarIndex(int barIndex) const;
   double GetBarClose(int barIndex) const;
   bool   CheckBullishBOS(int barIndex) const;
   bool   CheckBearishBOS(int barIndex) const;
   void   RecordBOS(int barIndex, double breakPrice, double swingPrice, ENUM_BOS_DIRECTION direction);
   
public:
                     CBOSEngine();
                    ~CBOSEngine();
   
   bool   Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CMarketStructureEngine* structureEngine);
   bool   IsInitialized() const;
   
   bool   DetectBOS(int barIndex);
   
   BOSEvent             GetLastBOS() const;
   ENUM_BOS_DIRECTION   GetLastBOSDirection() const;
   double               GetLastBOSBreakPrice() const;
   double               GetLastBOSSwingPrice() const;
   datetime             GetLastBOSTimestamp() const;
   int                  GetLastBOSBarIndex() const;
   int                  GetBOSCount() const;
   bool                 IsBullishBOS() const;
   bool                 IsBearishBOS() const;
   bool                 HasBOS() const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBOSEngine::CBOSEngine()
{
   m_initialized = false;
   m_structureEngine = NULL;
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_bosCount = 0;
   
   m_lastBOS.timestamp = 0;
   m_lastBOS.barIndex = -1;
   m_lastBOS.breakPrice = 0.0;
   m_lastBOS.swingPrice = 0.0;
   m_lastBOS.direction = BOS_DIRECTION_NONE;
   m_lastBOS.isValid = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBOSEngine::~CBOSEngine()
{
}

//+------------------------------------------------------------------+
//| Validate bar index                                               |
//+------------------------------------------------------------------+
bool CBOSEngine::ValidateBarIndex(int barIndex) const
{
   if(barIndex < 0)
      return false;
   
   int totalBars = Bars(m_symbol, m_timeframe);
   return (barIndex < totalBars);
}

//+------------------------------------------------------------------+
//| Get bar close price                                              |
//+------------------------------------------------------------------+
double CBOSEngine::GetBarClose(int barIndex) const
{
   if(!ValidateBarIndex(barIndex))
      return 0.0;
   
   return iClose(m_symbol, m_timeframe, barIndex);
}

//+------------------------------------------------------------------+
//| Check for Bullish BOS                                            |
//| Body close must be strictly above last swing high                |
//| Structure must be BULLISH                                        |
//+------------------------------------------------------------------+
bool CBOSEngine::CheckBullishBOS(int barIndex) const
{
   if(m_structureEngine == NULL)
      return false;
   
   ENUM_STRUCTURE_STATE state = m_structureEngine.GetStructureState();
   
   if(state != STRUCTURE_STATE_BULLISH)
      return false;
   
   double swingHigh = m_structureEngine.GetLastSwingHighPrice();
   
   if(swingHigh == 0.0)
      return false;
   
   double barClose = GetBarClose(barIndex);
   
   if(barClose == 0.0)
      return false;
   
   return (barClose > swingHigh);
}

//+------------------------------------------------------------------+
//| Check for Bearish BOS                                            |
//| Body close must be strictly below last swing low                 |
//| Structure must be BEARISH                                        |
//+------------------------------------------------------------------+
bool CBOSEngine::CheckBearishBOS(int barIndex) const
{
   if(m_structureEngine == NULL)
      return false;
   
   ENUM_STRUCTURE_STATE state = m_structureEngine.GetStructureState();
   
   if(state != STRUCTURE_STATE_BEARISH)
      return false;
   
   double swingLow = m_structureEngine.GetLastSwingLowPrice();
   
   if(swingLow == 0.0)
      return false;
   
   double barClose = GetBarClose(barIndex);
   
   if(barClose == 0.0)
      return false;
   
   return (barClose < swingLow);
}

//+------------------------------------------------------------------+
//| Record BOS event                                                 |
//+------------------------------------------------------------------+
void CBOSEngine::RecordBOS(int barIndex, double breakPrice, double swingPrice, ENUM_BOS_DIRECTION direction)
{
   m_lastBOS.timestamp = iTime(m_symbol, m_timeframe, barIndex);
   m_lastBOS.barIndex = barIndex;
   m_lastBOS.breakPrice = breakPrice;
   m_lastBOS.swingPrice = swingPrice;
   m_lastBOS.direction = direction;
   m_lastBOS.isValid = true;
   m_bosCount++;
}

//+------------------------------------------------------------------+
//| Initialize BOS engine                                            |
//+------------------------------------------------------------------+
bool CBOSEngine::Initialize(string symbol, ENUM_TIMEFRAMES timeframe, CMarketStructureEngine* structureEngine)
{
   if(StringLen(symbol) == 0)
      return false;
   
   if(structureEngine == NULL)
      return false;
   
   if(!structureEngine.IsInitialized())
      return false;
   
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_structureEngine = structureEngine;
   m_initialized = true;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if initialized                                             |
//+------------------------------------------------------------------+
bool CBOSEngine::IsInitialized() const
{
   return m_initialized;
}

//+------------------------------------------------------------------+
//| Detect BOS at bar index                                          |
//| Returns true if BOS detected, false otherwise                    |
//+------------------------------------------------------------------+
bool CBOSEngine::DetectBOS(int barIndex)
{
   if(!m_initialized)
      return false;
   
   if(!ValidateBarIndex(barIndex))
      return false;
   
   double barClose = GetBarClose(barIndex);
   
   if(barClose == 0.0)
      return false;
   
   if(CheckBullishBOS(barIndex))
   {
      RecordBOS(barIndex, barClose, m_structureEngine.GetLastSwingHighPrice(), BOS_DIRECTION_BULLISH);
      return true;
   }
   
   if(CheckBearishBOS(barIndex))
   {
      RecordBOS(barIndex, barClose, m_structureEngine.GetLastSwingLowPrice(), BOS_DIRECTION_BEARISH);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get last BOS event                                               |
//+------------------------------------------------------------------+
BOSEvent CBOSEngine::GetLastBOS() const
{
   return m_lastBOS;
}

//+------------------------------------------------------------------+
//| Get last BOS direction                                           |
//+------------------------------------------------------------------+
ENUM_BOS_DIRECTION CBOSEngine::GetLastBOSDirection() const
{
   return m_lastBOS.direction;
}

//+------------------------------------------------------------------+
//| Get last BOS break price                                         |
//+------------------------------------------------------------------+
double CBOSEngine::GetLastBOSBreakPrice() const
{
   return m_lastBOS.breakPrice;
}

//+------------------------------------------------------------------+
//| Get last BOS swing price (the swing that was broken)             |
//+------------------------------------------------------------------+
double CBOSEngine::GetLastBOSSwingPrice() const
{
   return m_lastBOS.swingPrice;
}

//+------------------------------------------------------------------+
//| Get last BOS timestamp                                           |
//+------------------------------------------------------------------+
datetime CBOSEngine::GetLastBOSTimestamp() const
{
   return m_lastBOS.timestamp;
}

//+------------------------------------------------------------------+
//| Get last BOS bar index                                           |
//+------------------------------------------------------------------+
int CBOSEngine::GetLastBOSBarIndex() const
{
   return m_lastBOS.barIndex;
}

//+------------------------------------------------------------------+
//| Get total BOS count                                              |
//+------------------------------------------------------------------+
int CBOSEngine::GetBOSCount() const
{
   return m_bosCount;
}

//+------------------------------------------------------------------+
//| Check if last BOS was bullish                                    |
//+------------------------------------------------------------------+
bool CBOSEngine::IsBullishBOS() const
{
   return (m_lastBOS.direction == BOS_DIRECTION_BULLISH);
}

//+------------------------------------------------------------------+
//| Check if last BOS was bearish                                    |
//+------------------------------------------------------------------+
bool CBOSEngine::IsBearishBOS() const
{
   return (m_lastBOS.direction == BOS_DIRECTION_BEARISH);
}

//+------------------------------------------------------------------+
//| Check if any BOS has been detected                               |
//+------------------------------------------------------------------+
bool CBOSEngine::HasBOS() const
{
   return m_lastBOS.isValid;
}

#endif
