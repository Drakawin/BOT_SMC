//+------------------------------------------------------------------+
//|                                        CConfluenceEngine.mqh     |
//|                                        Copyright 2026, BOT_SMC   |
//| Document: DOC03B (Confluence Engine Architecture)                |
//+------------------------------------------------------------------+
#ifndef CCONFLUENCEENGINE_MQH
#define CCONFLUENCEENGINE_MQH

#include "CTradeContextManager.mqh"

enum ENUM_ENTRY_BIAS
{
   ENTRY_BIAS_NONE = 0,
   ENTRY_BIAS_LONG = 1,
   ENTRY_BIAS_SHORT = 2
};

struct SConfluenceResult
{
   bool              isAccepted;
   string            failedConditionName;
   
   // References to the specific zones that satisfied the conditions
   int               selectedObIndex;
   int               selectedFvgIndex;
   int               selectedBprIndex;
   int               selectedBreakerIndex;
   
   ENUM_ENTRY_BIAS   evaluatedBias;
};

//+------------------------------------------------------------------+
//| Interface for Confluence Condition Slots                         |
//+------------------------------------------------------------------+
class IConfluenceCondition
{
public:
   virtual string    GetName() const = 0;
   virtual bool      Evaluate(const STradeContextSnapshot &context, SConfluenceResult &outResult) = 0;
};

//+------------------------------------------------------------------+
//| Main Engine                                                      |
//+------------------------------------------------------------------+
class CConfluenceEngine
{
private:
   bool                    m_initialized;
   IConfluenceCondition*   m_conditions[];
   int                     m_conditionCount;

public:
                           CConfluenceEngine();
                          ~CConfluenceEngine();
                          
   bool                    Initialize();
   void                    AddCondition(IConfluenceCondition* condition);
   
   // Pipeline Stage 3 Evaluation
   SConfluenceResult       EvaluateContext(const STradeContextSnapshot &context);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CConfluenceEngine::CConfluenceEngine()
{
   m_initialized = false;
   m_conditionCount = 0;
   ArrayResize(m_conditions, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CConfluenceEngine::~CConfluenceEngine()
{
   // Cleanup condition pointers if dynamically allocated
   for(int i = 0; i < m_conditionCount; i++)
   {
      if(CheckPointer(m_conditions[i]) == POINTER_DYNAMIC)
      {
         delete m_conditions[i];
      }
   }
   ArrayResize(m_conditions, 0);
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CConfluenceEngine::Initialize()
{
   m_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Add Condition Slot (Registers a rule)                            |
//+------------------------------------------------------------------+
void CConfluenceEngine::AddCondition(IConfluenceCondition* condition)
{
   if(condition == NULL) return;
   
   int newIndex = m_conditionCount;
   m_conditionCount++;
   ArrayResize(m_conditions, m_conditionCount);
   m_conditions[newIndex] = condition;
}

//+------------------------------------------------------------------+
//| Evaluate the entire Pipeline (STRICT AND)                        |
//+------------------------------------------------------------------+
SConfluenceResult CConfluenceEngine::EvaluateContext(const STradeContextSnapshot &context)
{
   SConfluenceResult result;
   result.isAccepted = false;
   result.failedConditionName = "Engine Not Initialized";
   result.selectedObIndex = -1;
   result.selectedFvgIndex = -1;
   result.selectedBprIndex = -1;
   result.selectedBreakerIndex = -1;
   result.evaluatedBias = ENTRY_BIAS_NONE;
   
   if(!m_initialized) return result;
   if(m_conditionCount == 0)
   {
      result.failedConditionName = "No Conditions Registered";
      return result;
   }
   
   // Loop through all registered slots (Dependency-ordered pipeline execution)
   for(int i = 0; i < m_conditionCount; i++)
   {
      if(m_conditions[i] == NULL) continue;
      
      bool isMet = m_conditions[i].Evaluate(context, result);
      
      // STRICT AND: Short-circuit on first failure
      if(!isMet)
      {
         result.isAccepted = false;
         result.failedConditionName = m_conditions[i].GetName();
         return result; // Immediately reject
      }
   }
   
   // If we pass all conditions
   result.isAccepted = true;
   result.failedConditionName = "NONE (ALL MET)";
   return result;
}

#endif