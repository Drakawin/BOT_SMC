//+------------------------------------------------------------------+
//|                                      CMarketStructureEngine.mqh  |
//|                                        Copyright 2026, BOT_SMC   |
//|                                            Layer 2: Market Analysis|
//| Document: DOC02A (Market Structure Foundation)                   |
//| Document: DOC06A (Implementation Blueprint)                      |
//+------------------------------------------------------------------+
#ifndef CMARKETSTRUCTUREENGINE_MQH
#define CMARKETSTRUCTUREENGINE_MQH

//+------------------------------------------------------------------+
//| Enum: ENUM_STRUCTURE_STATE                                       |
//| Purpose: Define market structure states                          |
//+------------------------------------------------------------------+
enum ENUM_STRUCTURE_STATE
{
   STRUCTURE_STATE_INITIAL = 0,
   STRUCTURE_STATE_UNKNOWN = 1,
   STRUCTURE_STATE_BULLISH = 2,
   STRUCTURE_STATE_BEARISH = 3,
   STRUCTURE_STATE_INVALID = 4
};

//+------------------------------------------------------------------+
//| Enum: ENUM_SWING_TYPE                                            |
//| Purpose: Define swing point types                                |
//+------------------------------------------------------------------+
enum ENUM_SWING_TYPE
{
   SWING_TYPE_HIGH = 0,
   SWING_TYPE_LOW = 1
};

//+------------------------------------------------------------------+
//| Enum: ENUM_SWING_CLASSIFICATION                                  |
//| Purpose: Define swing classifications                            |
//+------------------------------------------------------------------+
enum ENUM_SWING_CLASSIFICATION
{
   SWING_CLASSIFICATION_NONE = 0,
   SWING_CLASSIFICATION_HH = 1,
   SWING_CLASSIFICATION_HL = 2,
   SWING_CLASSIFICATION_LH = 3,
   SWING_CLASSIFICATION_LL = 4
};

//+------------------------------------------------------------------+
//| Class: CMarketStructureEngine                                    |
//| Purpose: Detect swing points and classify market structure       |
//| Owner: Layer 2 (DOC02A)                                          |
//| Consumers: BOS Engine, CHoCH Engine, Liquidity Engine            |
//| Dependencies: None (uses standard MQL5 functions only)           |
//+------------------------------------------------------------------+
class CMarketStructureEngine
{
private:
   bool                     m_initialized;
   ENUM_STRUCTURE_STATE     m_structureState;
   double                   m_lastSwingHighPrice;
   double                   m_lastSwingLowPrice;
   int                      m_lastSwingHighBar;
   int                      m_lastSwingLowBar;
   string                   m_symbol;
   ENUM_TIMEFRAMES          m_timeframe;
   int                      m_sfs; // Swing Fractal Strength
   
   bool   ValidateBarIndex(int barIndex) const;
   bool   CheckFractalPattern(int barIndex, ENUM_SWING_TYPE type) const;
   void   UpdateStructureState(ENUM_SWING_CLASSIFICATION classification, ENUM_SWING_TYPE type);
   ENUM_SWING_CLASSIFICATION ClassifySwing(double currentPrice, double lastPrice, ENUM_SWING_TYPE type) const;
   double GetBarHigh(int barIndex) const;
   double GetBarLow(int barIndex) const;
   
public:
                     CMarketStructureEngine();
                    ~CMarketStructureEngine();
   
   bool   Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int sfs = 2);
   bool   IsInitialized() const;
   
   bool   DetectSwingHigh(int barIndex);
   bool   DetectSwingLow(int barIndex);
   
   ENUM_STRUCTURE_STATE GetStructureState() const;
   double GetLastSwingHighPrice() const;
   double GetLastSwingLowPrice() const;
   int    GetLastSwingHighBar() const;
   int    GetLastSwingLowBar() const;
   
   bool   IsHigherHigh(double currentHigh) const;
   bool   IsHigherLow(double currentLow) const;
   bool   IsLowerHigh(double currentHigh) const;
   bool   IsLowerLow(double currentLow) const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CMarketStructureEngine::CMarketStructureEngine()
{
   m_initialized = false;
   m_structureState = STRUCTURE_STATE_INITIAL;
   m_lastSwingHighPrice = 0.0;
   m_lastSwingLowPrice = 0.0;
   m_lastSwingHighBar = -1;
   m_lastSwingLowBar = -1;
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_sfs = 2;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CMarketStructureEngine::~CMarketStructureEngine()
{
}

//+------------------------------------------------------------------+
//| Validate bar index                                               |
//+------------------------------------------------------------------+
bool CMarketStructureEngine::ValidateBarIndex(int barIndex) const
{
   int totalBars = Bars(m_symbol, m_timeframe);
   return (barIndex >= 0 && barIndex < totalBars);
}

//+------------------------------------------------------------------+
//| Get bar high price                                               |
//+------------------------------------------------------------------+
double CMarketStructureEngine::GetBarHigh(int barIndex) const
{
   if(!ValidateBarIndex(barIndex))
      return 0.0;
   
   return iHigh(m_symbol, m_timeframe, barIndex);
}

//+------------------------------------------------------------------+
//| Get bar low price                                                |
//+------------------------------------------------------------------+
double CMarketStructureEngine::GetBarLow(int barIndex) const
{
   if(!ValidateBarIndex(barIndex))
      return 0.0;
   
   return iLow(m_symbol, m_timeframe, barIndex);
}

//+------------------------------------------------------------------+
//| Check fractal pattern with SFS                                   |
//+------------------------------------------------------------------+
bool CMarketStructureEngine::CheckFractalPattern(int barIndex, ENUM_SWING_TYPE type) const
{
   if(!ValidateBarIndex(barIndex))
      return false;
   
   // Need SFS bars on each side
   int leftStart = barIndex + m_sfs;
   int rightEnd = barIndex - m_sfs;
   
   if(rightEnd < 0)
      return false;
   
   double centerPrice = (type == SWING_TYPE_HIGH) ? GetBarHigh(barIndex) : GetBarLow(barIndex);
   
   if(centerPrice == 0.0)
      return false;
   
   // Check left side (higher bar indices)
   for(int i = barIndex + 1; i <= leftStart; i++)
   {
      if(!ValidateBarIndex(i))
         return false;
      
      double comparePrice = (type == SWING_TYPE_HIGH) ? GetBarHigh(i) : GetBarLow(i);
      
      if(type == SWING_TYPE_HIGH)
      {
         if(comparePrice >= centerPrice)
            return false;
      }
      else
      {
         if(comparePrice <= centerPrice)
            return false;
      }
   }
   
   // Check right side (lower bar indices)
   for(int i = barIndex - 1; i >= rightEnd; i--)
   {
      if(!ValidateBarIndex(i))
         return false;
      
      double comparePrice = (type == SWING_TYPE_HIGH) ? GetBarHigh(i) : GetBarLow(i);
      
      if(type == SWING_TYPE_HIGH)
      {
         if(comparePrice >= centerPrice)
            return false;
      }
      else
      {
         if(comparePrice <= centerPrice)
            return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Classify swing as HH/HL/LH/LL                                    |
//+------------------------------------------------------------------+
ENUM_SWING_CLASSIFICATION CMarketStructureEngine::ClassifySwing(double currentPrice, double lastPrice, ENUM_SWING_TYPE type) const
{
   if(lastPrice == 0.0)
      return SWING_CLASSIFICATION_NONE;
   
   if(type == SWING_TYPE_HIGH)
   {
      if(currentPrice > lastPrice)
         return SWING_CLASSIFICATION_HH;
      else if(currentPrice < lastPrice)
         return SWING_CLASSIFICATION_LH;
      else
         return SWING_CLASSIFICATION_NONE;
   }
   else // SWING_TYPE_LOW
   {
      if(currentPrice > lastPrice)
         return SWING_CLASSIFICATION_HL;
      else if(currentPrice < lastPrice)
         return SWING_CLASSIFICATION_LL;
      else
         return SWING_CLASSIFICATION_NONE;
   }
}

//+------------------------------------------------------------------+
//| Update structure state based on swing classification             |
//+------------------------------------------------------------------+
void CMarketStructureEngine::UpdateStructureState(ENUM_SWING_CLASSIFICATION classification, ENUM_SWING_TYPE type)
{
   // Initial state transitions to Unknown on first swing
   if(m_structureState == STRUCTURE_STATE_INITIAL)
   {
      m_structureState = STRUCTURE_STATE_UNKNOWN;
      return;
   }
   
   // Bullish structure: HH + HL
   if(classification == SWING_CLASSIFICATION_HH && type == SWING_TYPE_HIGH)
   {
      if(m_structureState == STRUCTURE_STATE_UNKNOWN || m_structureState == STRUCTURE_STATE_BULLISH)
         m_structureState = STRUCTURE_STATE_BULLISH;
   }
   else if(classification == SWING_CLASSIFICATION_HL && type == SWING_TYPE_LOW)
   {
      if(m_structureState == STRUCTURE_STATE_UNKNOWN || m_structureState == STRUCTURE_STATE_BULLISH)
         m_structureState = STRUCTURE_STATE_BULLISH;
   }
   // Bearish structure: LH + LL
   else if(classification == SWING_CLASSIFICATION_LH && type == SWING_TYPE_HIGH)
   {
      if(m_structureState == STRUCTURE_STATE_UNKNOWN || m_structureState == STRUCTURE_STATE_BEARISH)
         m_structureState = STRUCTURE_STATE_BEARISH;
   }
   else if(classification == SWING_CLASSIFICATION_LL && type == SWING_TYPE_LOW)
   {
      if(m_structureState == STRUCTURE_STATE_UNKNOWN || m_structureState == STRUCTURE_STATE_BEARISH)
         m_structureState = STRUCTURE_STATE_BEARISH;
   }
}

//+------------------------------------------------------------------+
//| Initialize engine                                                |
//+------------------------------------------------------------------+
bool CMarketStructureEngine::Initialize(string symbol, ENUM_TIMEFRAMES timeframe, int sfs)
{
   if(StringLen(symbol) == 0)
      return false;
   
   if(sfs < 1)
      return false;
   
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_sfs = sfs;
   m_initialized = true;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if initialized                                             |
//+------------------------------------------------------------------+
bool CMarketStructureEngine::IsInitialized() const
{
   return m_initialized;
}

//+------------------------------------------------------------------+
//| Detect Swing High at bar index                                   |
//+------------------------------------------------------------------+
bool CMarketStructureEngine::DetectSwingHigh(int barIndex)
{
   if(!m_initialized)
      return false;
   
   if(!CheckFractalPattern(barIndex, SWING_TYPE_HIGH))
      return false;
   
   double swingHighPrice = GetBarHigh(barIndex);
   
   if(swingHighPrice == 0.0)
      return false;
   
   // Classify swing
   ENUM_SWING_CLASSIFICATION classification = ClassifySwing(swingHighPrice, m_lastSwingHighPrice, SWING_TYPE_HIGH);
   
   // Update last swing high
   m_lastSwingHighPrice = swingHighPrice;
   m_lastSwingHighBar = barIndex;
   
   // Update structure state
   UpdateStructureState(classification, SWING_TYPE_HIGH);
   
   return true;
}

//+------------------------------------------------------------------+
//| Detect Swing Low at bar index                                    |
//+------------------------------------------------------------------+
bool CMarketStructureEngine::DetectSwingLow(int barIndex)
{
   if(!m_initialized)
      return false;
   
   if(!CheckFractalPattern(barIndex, SWING_TYPE_LOW))
      return false;
   
   double swingLowPrice = GetBarLow(barIndex);
   
   if(swingLowPrice == 0.0)
      return false;
   
   // Classify swing
   ENUM_SWING_CLASSIFICATION classification = ClassifySwing(swingLowPrice, m_lastSwingLowPrice, SWING_TYPE_LOW);
   
   // Update last swing low
   m_lastSwingLowPrice = swingLowPrice;
   m_lastSwingLowBar = barIndex;
   
   // Update structure state
   UpdateStructureState(classification, SWING_TYPE_LOW);
   
   return true;
}

//+------------------------------------------------------------------+
//| Get current structure state                                      |
//+------------------------------------------------------------------+
ENUM_STRUCTURE_STATE CMarketStructureEngine::GetStructureState() const
{
   return m_structureState;
}

//+------------------------------------------------------------------+
//| Get last Swing High price                                        |
//+------------------------------------------------------------------+
double CMarketStructureEngine::GetLastSwingHighPrice() const
{
   return m_lastSwingHighPrice;
}

//+------------------------------------------------------------------+
//| Get last Swing Low price                                         |
//+------------------------------------------------------------------+
double CMarketStructureEngine::GetLastSwingLowPrice() const
{
   return m_lastSwingLowPrice;
}

//+------------------------------------------------------------------+
//| Get last Swing High bar index                                    |
//+------------------------------------------------------------------+
int CMarketStructureEngine::GetLastSwingHighBar() const
{
   return m_lastSwingHighBar;
}

//+------------------------------------------------------------------+
//| Get last Swing Low bar index                                     |
//+------------------------------------------------------------------+
int CMarketStructureEngine::GetLastSwingLowBar() const
{
   return m_lastSwingLowBar;
}

//+------------------------------------------------------------------+
//| Check if current high is Higher High                             |
//+------------------------------------------------------------------+
bool CMarketStructureEngine::IsHigherHigh(double currentHigh) const
{
   if(m_lastSwingHighPrice == 0.0)
      return false;
   
   return (currentHigh > m_lastSwingHighPrice);
}

//+------------------------------------------------------------------+
//| Check if current low is Higher Low                               |
//+------------------------------------------------------------------+
bool CMarketStructureEngine::IsHigherLow(double currentLow) const
{
   if(m_lastSwingLowPrice == 0.0)
      return false;
   
   return (currentLow > m_lastSwingLowPrice);
}

//+------------------------------------------------------------------+
//| Check if current high is Lower High                              |
//+------------------------------------------------------------------+
bool CMarketStructureEngine::IsLowerHigh(double currentHigh) const
{
   if(m_lastSwingHighPrice == 0.0)
      return false;
   
   return (currentHigh < m_lastSwingHighPrice);
}

//+------------------------------------------------------------------+
//| Check if current low is Lower Low                                |
//+------------------------------------------------------------------+
bool CMarketStructureEngine::IsLowerLow(double currentLow) const
{
   if(m_lastSwingLowPrice == 0.0)
      return false;
   
   return (currentLow < m_lastSwingLowPrice);
}

#endif
