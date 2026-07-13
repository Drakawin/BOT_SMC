//+------------------------------------------------------------------+
//|                                     CEntryDecisionEngine.mqh     |
//|                                        Copyright 2026, BOT_SMC   |
//| Document: DOC03C (Entry Decision Engine Architecture)            |
//+------------------------------------------------------------------+
#ifndef CENTRYDECISIONENGINE_MQH
#define CENTRYDECISIONENGINE_MQH

#include "CConfluenceEngine.mqh"

enum ENUM_ENTRY_DECISION
{
   DECISION_NO_ENTRY = 0,
   DECISION_ENTER_LONG = 1,
   DECISION_ENTER_SHORT = 2
};

enum ENUM_ENTRY_DIRECTION
{
   DIRECTION_NONE = 0,
   DIRECTION_LONG = 1,
   DIRECTION_SHORT = 2
};

struct SDecisionOutput
{
   ENUM_ENTRY_DECISION  decision;
   ENUM_ENTRY_DIRECTION direction;
   datetime             timestamp;
   
   // Audit Context
   SConfluenceResult    confluenceReference;
   string               decisionLogicTrace;
};

class CEntryDecisionEngine
{
private:
   bool                 m_initialized;

public:
                        CEntryDecisionEngine();
                       ~CEntryDecisionEngine();
                       
   bool                 Initialize();
   
   // Pipeline Stage 4 Evaluation
   SDecisionOutput      EvaluateDecision(const SConfluenceResult &confResult, datetime barTime);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CEntryDecisionEngine::CEntryDecisionEngine()
{
   m_initialized = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CEntryDecisionEngine::~CEntryDecisionEngine()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CEntryDecisionEngine::Initialize()
{
   m_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Evaluate Decision (Stage 4)                                      |
//+------------------------------------------------------------------+
SDecisionOutput CEntryDecisionEngine::EvaluateDecision(const SConfluenceResult &confResult, datetime barTime)
{
   SDecisionOutput output;
   output.decision = DECISION_NO_ENTRY;
   output.direction = DIRECTION_NONE;
   output.timestamp = barTime;
   output.confluenceReference = confResult;
   output.decisionLogicTrace = "";
   
   if(!m_initialized)
   {
      output.decisionLogicTrace = "Engine not initialized";
      return output;
   }
   
   // Rule 1: Confluence Check
   if(!confResult.isAccepted)
   {
      output.decision = DECISION_NO_ENTRY;
      output.direction = DIRECTION_NONE;
      output.decisionLogicTrace = "REJECTED: Confluence not accepted (" + confResult.failedConditionName + ")";
      return output;
   }
   
   // Rule 2: Bias Check
   if(confResult.evaluatedBias == ENTRY_BIAS_NONE)
   {
      output.decision = DECISION_NO_ENTRY;
      output.direction = DIRECTION_NONE;
      output.decisionLogicTrace = "REJECTED: Bias is UNKNOWN/NONE";
      return output;
   }
   
   // Rule 3: Direction Assignment
   if(confResult.evaluatedBias == ENTRY_BIAS_LONG)
   {
      output.decision = DECISION_ENTER_LONG;
      output.direction = DIRECTION_LONG;
      output.decisionLogicTrace = "ACCEPTED: ENTER_LONG";
      return output;
   }
   else if(confResult.evaluatedBias == ENTRY_BIAS_SHORT)
   {
      output.decision = DECISION_ENTER_SHORT;
      output.direction = DIRECTION_SHORT;
      output.decisionLogicTrace = "ACCEPTED: ENTER_SHORT";
      return output;
   }
   
   // Rule 4: Default
   output.decision = DECISION_NO_ENTRY;
   output.direction = DIRECTION_NONE;
   output.decisionLogicTrace = "REJECTED: Fallthrough default";
   
   return output;
}

#endif