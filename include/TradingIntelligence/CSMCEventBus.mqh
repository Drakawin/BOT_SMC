//+------------------------------------------------------------------+
//|                                                 CSMCEventBus.mqh |
//|                                        Copyright 2026, BOT_SMC   |
//| Document: DOC03E (SMC Event Bus logic)                           |
//+------------------------------------------------------------------+
#ifndef CSMCEVENTBUS_MQH
#define CSMCEVENTBUS_MQH

#include "CSMCEventObject.mqh"

class CSMCEventBus
{
private:
   IEventSubscriber*    m_subscribers[];
   int                  m_subscriberCount;

public:
                        CSMCEventBus();
                       ~CSMCEventBus();
                       
   void                 Subscribe(IEventSubscriber* subscriber);
   void                 Publish(const CSMCEvent* event);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSMCEventBus::CSMCEventBus()
{
   m_subscriberCount = 0;
   ArrayResize(m_subscribers, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSMCEventBus::~CSMCEventBus()
{
   ArrayResize(m_subscribers, 0);
}

//+------------------------------------------------------------------+
//| Subscribe                                                        |
//+------------------------------------------------------------------+
void CSMCEventBus::Subscribe(IEventSubscriber* subscriber)
{
   if(subscriber == NULL) return;
   
   for(int i = 0; i < m_subscriberCount; i++)
   {
      if(m_subscribers[i] == subscriber) return; // Already subscribed
   }
   
   int newIndex = m_subscriberCount;
   m_subscriberCount++;
   ArrayResize(m_subscribers, m_subscriberCount);
   m_subscribers[newIndex] = subscriber;
}

//+------------------------------------------------------------------+
//| Publish Event to all subscribers                                 |
//+------------------------------------------------------------------+
void CSMCEventBus::Publish(const CSMCEvent* event)
{
   if(event == NULL) return;
   
   for(int i = 0; i < m_subscriberCount; i++)
   {
      if(m_subscribers[i] != NULL)
      {
         m_subscribers[i].OnEvent(event);
      }
   }
}

#endif