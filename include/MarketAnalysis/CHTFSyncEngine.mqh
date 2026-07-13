//+------------------------------------------------------------------+
//|                                              CHTFSyncEngine.mqh  |
//|                                        Copyright 2026, BOT_SMC   |
//| Document: DOC02K (HTF Bias Engine & MTF Synchronization)         |
//+------------------------------------------------------------------+
#ifndef CHTFSYNCENGINE_MQH
#define CHTFSYNCENGINE_MQH

#include "CMarketStructureEngine.mqh"

enum ENUM_SYNC_BIAS
{
   SYNC_BIAS_NEUTRAL = 0,
   SYNC_BIAS_BULLISH = 1,
   SYNC_BIAS_BEARISH = 2
};

class CHTFSyncEngine
{
private:
   bool                     m_initialized;
   string                   m_symbol;
   ENUM_TIMEFRAMES          m_htfPeriod;
   
   CMarketStructureEngine   m_htfStructure;
   ENUM_SYNC_BIAS           m_currentBias;
   datetime                 m_lastHtfTime;

public:
                        CHTFSyncEngine();
                       ~CHTFSyncEngine();
                       
   bool                 Initialize(string symbol, ENUM_TIMEFRAMES htfPeriod = PERIOD_H4, int sfs = 2);
   bool                 IsInitialized() const;
   
   // Evaluates HTF swings and computes alignment with LTF structure
   void                 Update(CMarketStructureEngine* ltfStructure);
   
   ENUM_SYNC_BIAS       GetSynchronizedBias() const { return m_currentBias; }
   ENUM_STRUCTURE_STATE GetHTFStructureState() const { return m_htfStructure.GetStructureState(); }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CHTFSyncEngine::CHTFSyncEngine()
{
   m_initialized = false;
   m_symbol = "";
   m_htfPeriod = PERIOD_H4;
   m_currentBias = SYNC_BIAS_NEUTRAL;
   m_lastHtfTime = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CHTFSyncEngine::~CHTFSyncEngine()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CHTFSyncEngine::Initialize(string symbol, ENUM_TIMEFRAMES htfPeriod, int sfs)
{
   if(StringLen(symbol) == 0) return false;
   
   m_symbol = symbol;
   m_htfPeriod = htfPeriod;
   
   // Initialize the internal HTF Market Structure engine
   if(!m_htfStructure.Initialize(symbol, m_htfPeriod, sfs))
   {
      return false;
   }
   
   m_initialized = true;
   return true;
}

bool CHTFSyncEngine::IsInitialized() const { return m_initialized; }

//+------------------------------------------------------------------+
//| Update (Evaluates HTF Swings and Alignment)                      |
//+------------------------------------------------------------------+
void CHTFSyncEngine::Update(CMarketStructureEngine* ltfStructure)
{
   if(!m_initialized || ltfStructure == NULL) return;
   
   // We evaluate HTF swings only when a new HTF bar opens.
   // Or practically, checking the offset bars (e.g. index 5) on the HTF chart.
   // To avoid recalculating the same bar repeatedly, we use a time gate.
   datetime currentHtfTime = iTime(m_symbol, m_htfPeriod, 0);
   
   bool htfUpdated = false;
   if(currentHtfTime != 0 && currentHtfTime != m_lastHtfTime)
   {
      m_lastHtfTime = currentHtfTime;
      
      // Lookback 5 bars on the HTF chart (SFS=2 requires 2 right-side closed bars, so bar 3 is minimum. We use 5 for safety buffer matching H1)
      bool highFound = m_htfStructure.DetectSwingHigh(5);
      bool lowFound = m_htfStructure.DetectSwingLow(5);
      
      if(highFound || lowFound)
      {
         htfUpdated = true;
      }
   }
   
   // Sync Evaluation (Alignment Rule per DOC02K)
   ENUM_STRUCTURE_STATE h4State = m_htfStructure.GetStructureState();
   ENUM_STRUCTURE_STATE h1State = ltfStructure.GetStructureState();
   
   ENUM_SYNC_BIAS newBias = SYNC_BIAS_NEUTRAL;
   
   if(h4State == STRUCTURE_STATE_BULLISH && h1State == STRUCTURE_STATE_BULLISH)
   {
      newBias = SYNC_BIAS_BULLISH;
   }
   else if(h4State == STRUCTURE_STATE_BEARISH && h1State == STRUCTURE_STATE_BEARISH)
   {
      newBias = SYNC_BIAS_BEARISH;
   }
   
   // If bias changed, log it
   if(newBias != m_currentBias || htfUpdated)
   {
      m_currentBias = newBias;
      string biasStr = (m_currentBias == SYNC_BIAS_BULLISH) ? "BULLISH" : 
                       (m_currentBias == SYNC_BIAS_BEARISH) ? "BEARISH" : "NEUTRAL";
                       
      string h4Str = (h4State == STRUCTURE_STATE_BULLISH) ? "BULLISH" : 
                     (h4State == STRUCTURE_STATE_BEARISH) ? "BEARISH" : "UNKNOWN";
                     
      string h1Str = (h1State == STRUCTURE_STATE_BULLISH) ? "BULLISH" : 
                     (h1State == STRUCTURE_STATE_BEARISH) ? "BEARISH" : "UNKNOWN";
                     
      // Only print if there was a meaningful update or shift
      if(newBias != SYNC_BIAS_NEUTRAL || htfUpdated)
      {
         PrintFormat("[MTF Sync] Bias = %s | H4=%s | H1=%s", biasStr, h4Str, h1Str);
      }
   }
}

#endif