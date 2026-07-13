//+------------------------------------------------------------------+
//|                                     CTradeStateMachine.mqh       |
//|                                        Copyright 2026, BOT_SMC   |
//| Document: DOC03D (Trade State Machine)                           |
//+------------------------------------------------------------------+
#ifndef CTRADESTATEMACHINE_MQH
#define CTRADESTATEMACHINE_MQH

#include "CEntryDecisionEngine.mqh"
#include "CIdentifierGeneration.mqh"

enum ENUM_TRADE_STATE
{
   TRADE_STATE_NONE = 0,
   TRADE_STATE_NEW = 1,
   TRADE_STATE_VALIDATED = 2,
   TRADE_STATE_READY = 3,
   TRADE_STATE_EXECUTING = 4,
   TRADE_STATE_EXECUTED = 5,
   TRADE_STATE_FAILED = 6,
   TRADE_STATE_EXPIRED = 7,
   TRADE_STATE_CANCELLED = 8,
   TRADE_STATE_ARCHIVED = 9
};

struct STradeStateRecord
{
   string               decisionId;
   SDecisionOutput      decision;
   ENUM_TRADE_STATE     currentState;
   datetime             stateUpdateTime;
   string               lastTransitionReason;
};

class CTradeStateMachine
{
private:
   bool                 m_initialized;
   STradeStateRecord    m_activeRecord;

   bool                 IsValidTransition(ENUM_TRADE_STATE fromState, ENUM_TRADE_STATE toState) const;

public:
                        CTradeStateMachine();
                       ~CTradeStateMachine();
                       
   bool                 Initialize();
   
   // Handle new decision from Stage 4
   void                 ProcessNewDecision(const SDecisionOutput &newDecision);
   
   // General state transition function (called by external events like Execution Status)
   bool                 TransitionState(ENUM_TRADE_STATE newState, string reason);
   
   ENUM_TRADE_STATE     GetCurrentState() const { return m_activeRecord.currentState; }
   STradeStateRecord    GetActiveRecord() const { return m_activeRecord; }
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeStateMachine::CTradeStateMachine()
{
   m_initialized = false;
   m_activeRecord.currentState = TRADE_STATE_NONE;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CTradeStateMachine::~CTradeStateMachine()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CTradeStateMachine::Initialize()
{
   m_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Validate State Transitions strictly according to DOC03D          |
//+------------------------------------------------------------------+
bool CTradeStateMachine::IsValidTransition(ENUM_TRADE_STATE fromState, ENUM_TRADE_STATE toState) const
{
   if(fromState == toState) return false;
   
   switch(fromState)
   {
      case TRADE_STATE_NONE:
         return (toState == TRADE_STATE_NEW);
         
      case TRADE_STATE_NEW:
         return (toState == TRADE_STATE_VALIDATED || toState == TRADE_STATE_CANCELLED || toState == TRADE_STATE_FAILED);
         
      case TRADE_STATE_VALIDATED:
         return (toState == TRADE_STATE_READY || toState == TRADE_STATE_CANCELLED || toState == TRADE_STATE_EXPIRED || toState == TRADE_STATE_FAILED);
         
      case TRADE_STATE_READY:
         return (toState == TRADE_STATE_EXECUTING || toState == TRADE_STATE_FAILED || toState == TRADE_STATE_EXPIRED || toState == TRADE_STATE_CANCELLED);
         
      case TRADE_STATE_EXECUTING:
         return (toState == TRADE_STATE_EXECUTED || toState == TRADE_STATE_FAILED || toState == TRADE_STATE_CANCELLED);
         
      case TRADE_STATE_EXECUTED:
         return (toState == TRADE_STATE_ARCHIVED);
         
      case TRADE_STATE_FAILED:
      case TRADE_STATE_EXPIRED:
      case TRADE_STATE_CANCELLED:
         return (toState == TRADE_STATE_ARCHIVED);
         
      case TRADE_STATE_ARCHIVED:
         return false; // Terminal
   }
   return false;
}

//+------------------------------------------------------------------+
//| Process New Decision from Stage 4                                |
//+------------------------------------------------------------------+
void CTradeStateMachine::ProcessNewDecision(const SDecisionOutput &newDecision)
{
   if(!m_initialized) return;
   
   if(newDecision.decision == DECISION_NO_ENTRY) return; // Ignore null decisions
   
   // DOC03D: Duplicate decision prevention. 
   // "If DOC03C produces a new decision while a non-terminal decision exists, the new decision is CANCELLED."
   bool hasActiveDecision = false;
   if(m_activeRecord.currentState == TRADE_STATE_NEW || 
      m_activeRecord.currentState == TRADE_STATE_VALIDATED || 
      m_activeRecord.currentState == TRADE_STATE_READY || 
      m_activeRecord.currentState == TRADE_STATE_EXECUTING)
   {
      hasActiveDecision = true;
   }
   
   if(hasActiveDecision)
   {
      PrintFormat("[State Machine] New decision CANCELLED. An active decision already exists in state: %s", EnumToString(m_activeRecord.currentState));
      return;
   }
   
   // Accept the new decision
   m_activeRecord.decisionId = GenerateUUID();
   m_activeRecord.decision = newDecision;
   m_activeRecord.currentState = TRADE_STATE_NONE;
   
   TransitionState(TRADE_STATE_NEW, "Received from Decision Pipeline");
   
   // --- MOCK TRANSITIONS UNTIL GATES/EXECUTION ARE BUILT ---
   // Move to VALIDATED
   TransitionState(TRADE_STATE_VALIDATED, "Passed initial validation (Mock)");
   // Move to READY
   TransitionState(TRADE_STATE_READY, "Cleared security gates (Mock)");
}

//+------------------------------------------------------------------+
//| Execute State Transition (Auditable)                             |
//+------------------------------------------------------------------+
bool CTradeStateMachine::TransitionState(ENUM_TRADE_STATE newState, string reason)
{
   if(!IsValidTransition(m_activeRecord.currentState, newState))
   {
      PrintFormat("[State Machine] ERROR: Invalid transition attempted from %s to %s", EnumToString(m_activeRecord.currentState), EnumToString(newState));
      return false;
   }
   
   ENUM_TRADE_STATE oldState = m_activeRecord.currentState;
   m_activeRecord.currentState = newState;
   m_activeRecord.stateUpdateTime = TimeCurrent();
   m_activeRecord.lastTransitionReason = reason;
   
   PrintFormat("[State Machine] [%s] %s -> %s | Reason: %s", 
               m_activeRecord.decisionId, EnumToString(oldState), EnumToString(newState), reason);
               
   return true;
}

#endif