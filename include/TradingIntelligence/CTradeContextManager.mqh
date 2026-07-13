//+------------------------------------------------------------------+
//|                                       CTradeContextManager.mqh   |
//|                                        Copyright 2026, BOT_SMC   |
//| Document: DOC03A (Trade Context Object)                          |
//+------------------------------------------------------------------+
#ifndef CTRADECONTEXTMANAGER_MQH
#define CTRADECONTEXTMANAGER_MQH

#include "CSMCEventBus.mqh"
#include "..\MarketAnalysis\CMarketStructureEngine.mqh"
#include "..\MarketAnalysis\CBOSEngine.mqh"
#include "..\MarketAnalysis\CCHoCHEngine.mqh"
#include "..\MarketAnalysis\CLiquidityEngine.mqh"
#include "..\MarketAnalysis\COrderBlockEngine.mqh"
#include "..\MarketAnalysis\CFVGEngine.mqh"
#include "..\MarketAnalysis\CPremiumDiscountEngine.mqh"
#include "..\MarketAnalysis\CHTFSyncEngine.mqh"

// The Trade Context Object acts as a frozen snapshot combining:
// 1. Structural Context (Engine pointers)
// 2. Market Data
// 3. Account State
struct STradeContextSnapshot
{
   datetime    timestamp;
   double      bid;
   double      ask;
   double      spread;
   double      accountBalance;
   double      accountEquity;
   int         openPositions;
   
   // We store references to the engines (since their records are structurally immutable per bar)
   // A deeper copy could be done if threading was used, but for MQL5 synchronous processing, pointers to the current bar state is safe.
   CMarketStructureEngine*  marketStructure;
   CBOSEngine*              bosEngine;
   CCHoCHEngine*            chochEngine;
   CLiquidityEngine*        liquidityEngine;
   COrderBlockEngine*       obEngine;
   CFVGEngine*              fvgEngine;
   CPremiumDiscountEngine*  pdEngine;
   CHTFSyncEngine*          htfEngine;
   CCHoCHEngine*            ltfChochEngine; // Added for M15 Trigger
};

class CTradeContextManager : public IEventSubscriber
{
private:
   STradeContextSnapshot    m_currentSnapshot;
   bool                     m_initialized;
   
public:
                        CTradeContextManager();
                       ~CTradeContextManager();
                       
   bool                 Initialize();
   
   // Implementation of IEventSubscriber
   virtual void         OnEvent(const CSMCEvent* event);
   
   // Freezes the state for the current bar to be consumed by the Decision Pipeline
   void                 BuildSnapshot(CMarketStructureEngine* ms, 
                                      CBOSEngine* bos, 
                                      CCHoCHEngine* choch,
                                      CLiquidityEngine* liq,
                                      COrderBlockEngine* ob,
                                      CFVGEngine* fvg,
                                      CPremiumDiscountEngine* pd,
                                      CHTFSyncEngine* htf,
                                      CCHoCHEngine* ltfChoch);
                                      
   STradeContextSnapshot GetSnapshot() const { return m_currentSnapshot; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeContextManager::CTradeContextManager()
{
   m_initialized = false;
   ZeroMemory(m_currentSnapshot);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeContextManager::~CTradeContextManager()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CTradeContextManager::Initialize()
{
   m_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Event Listener (Logging events passing through the bus)          |
//+------------------------------------------------------------------+
void CTradeContextManager::OnEvent(const CSMCEvent* event)
{
   if(event == NULL) return;
   // For now, simply observe that the event arrived into the context sphere
   PrintFormat("[ContextManager] Received Event: %s", event.ToString());
}

//+------------------------------------------------------------------+
//| Build Frozen Snapshot per M15 bar                                |
//+------------------------------------------------------------------+
void CTradeContextManager::BuildSnapshot(CMarketStructureEngine* ms, 
                                         CBOSEngine* bos, 
                                         CCHoCHEngine* choch,
                                         CLiquidityEngine* liq,
                                         COrderBlockEngine* ob,
                                         CFVGEngine* fvg,
                                         CPremiumDiscountEngine* pd,
                                         CHTFSyncEngine* htf,
                                         CCHoCHEngine* ltfChoch)
{
   if(!m_initialized) return;
   
   m_currentSnapshot.timestamp = TimeCurrent();
   
   // 1. Market Data
   m_currentSnapshot.bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   m_currentSnapshot.ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   m_currentSnapshot.spread = m_currentSnapshot.ask - m_currentSnapshot.bid;
   
   // 2. Account State
   m_currentSnapshot.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_currentSnapshot.accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   m_currentSnapshot.openPositions = PositionsTotal();
   
   // 3. Structural Context (Pointers to engine states which have already updated for this bar)
   m_currentSnapshot.marketStructure = ms;
   m_currentSnapshot.bosEngine = bos;
   m_currentSnapshot.chochEngine = choch;
   m_currentSnapshot.liquidityEngine = liq;
   m_currentSnapshot.obEngine = ob;
   m_currentSnapshot.fvgEngine = fvg;
   m_currentSnapshot.pdEngine = pd;
   m_currentSnapshot.htfEngine = htf;
   m_currentSnapshot.ltfChochEngine = ltfChoch;
}

#endif