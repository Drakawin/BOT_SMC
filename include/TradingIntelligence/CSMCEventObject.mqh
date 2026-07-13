//+------------------------------------------------------------------+
//|                                              CSMCEventObject.mqh |
//|                                        Copyright 2026, BOT_SMC   |
//| Document: DOC03E (SMC Event Object)                              |
//+------------------------------------------------------------------+
#ifndef CSMCEVENTOBJECT_MQH
#define CSMCEVENTOBJECT_MQH

#include "CIdentifierGeneration.mqh"

enum ENUM_SMC_EVENT_TYPE
{
   EVENT_SWING_HIGH_DETECTED = 0,
   EVENT_SWING_LOW_DETECTED = 1,
   EVENT_BOS_DETECTED = 2,
   EVENT_CHOCH_DETECTED = 3,
   EVENT_FVG_DETECTED = 4,
   EVENT_FVG_FILLED = 5,
   EVENT_OB_DETECTED = 6,
   EVENT_OB_MITIGATED = 7,
   EVENT_LIQUIDITY_SWEPT = 8,
   EVENT_LIQUIDITY_CONSUMED = 9
};

enum ENUM_MODULE_ID
{
   MODULE_DOC02A = 0, // Market Structure
   MODULE_DOC02B = 1, // BOS
   MODULE_DOC02C = 2, // CHoCH
   MODULE_DOC02D = 3, // Liquidity
   MODULE_DOC02E = 4, // Order Block (and Breaker)
   MODULE_DOC02F = 5, // FVG (and BPR/IFVG)
   MODULE_DOC03  = 6, // Trading Intelligence
   MODULE_DOC04  = 7, // Execution
   MODULE_DOC05  = 8  // Trade Management
};

enum ENUM_VALIDATION_STATUS
{
   STATUS_PENDING = 0,
   STATUS_VALIDATED = 1,
   STATUS_INVALID = 2
};

enum ENUM_EVENT_PRIORITY
{
   PRIORITY_LOW = 0,
   PRIORITY_MEDIUM = 1,
   PRIORITY_HIGH = 2
};

//+------------------------------------------------------------------+
//| Base Class for all SMC Events (Immutable interface)              |
//+------------------------------------------------------------------+
class CSMCEvent
{
protected:
   string                  m_eventId;
   ENUM_MODULE_ID          m_sourceModule;
   ENUM_SMC_EVENT_TYPE     m_eventType;
   datetime                m_timestamp;
   ENUM_TIMEFRAMES         m_timeframe;
   string                  m_symbol;
   ENUM_VALIDATION_STATUS  m_validationStatus;
   string                  m_dependencies[]; // List of UUIDs
   ENUM_EVENT_PRIORITY     m_priority;
   string                  m_version;

public:
   CSMCEvent(ENUM_MODULE_ID source, ENUM_SMC_EVENT_TYPE type, ENUM_TIMEFRAMES tf, string sym, ENUM_EVENT_PRIORITY prio)
   {
      m_eventId = CIdentifierGeneration::GenerateUUID();
      m_sourceModule = source;
      m_eventType = type;
      m_timestamp = TimeCurrent();
      m_timeframe = tf;
      m_symbol = sym;
      m_validationStatus = STATUS_VALIDATED;
      m_priority = prio;
      m_version = "1.0";
      ArrayResize(m_dependencies, 0);
   }
   
   virtual ~CSMCEvent() {}
   
   // Getters for the 10 core fields
   string                  GetEventId() const { return m_eventId; }
   ENUM_MODULE_ID          GetSourceModule() const { return m_sourceModule; }
   ENUM_SMC_EVENT_TYPE     GetEventType() const { return m_eventType; }
   datetime                GetTimestamp() const { return m_timestamp; }
   ENUM_TIMEFRAMES         GetTimeframe() const { return m_timeframe; }
   string                  GetSymbol() const { return m_symbol; }
   ENUM_VALIDATION_STATUS  GetValidationStatus() const { return m_validationStatus; }
   ENUM_EVENT_PRIORITY     GetPriority() const { return m_priority; }
   string                  GetVersion() const { return m_version; }
   
   virtual string          ToString() const 
   {
      return StringFormat("[%s] %s | Mod: %d | TF: %s", m_eventId, EnumToString(m_eventType), m_sourceModule, EnumToString(m_timeframe));
   }
};

// --- We can define derived classes for payloads here if needed by consumers ---
// For now, the base event handles the architectural requirement.

//+------------------------------------------------------------------+
//| Interface for any class that wants to listen to the Event Bus    |
//+------------------------------------------------------------------+
class IEventSubscriber
{
public:
   virtual void OnEvent(const CSMCEvent* event) = 0;
};

#endif