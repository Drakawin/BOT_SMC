//+------------------------------------------------------------------+
//|                                        CClockTimeService.mqh     |
//|                                        Copyright 2026, BOT_SMC   |
//|                                            Layer 0: Infrastructure|
//| Document: DOC05A (Infrastructure Blueprint)                      |
//| Document: DOC06A (Implementation Blueprint)                      |
//+------------------------------------------------------------------+
#ifndef CCLOCKTIMESERVICE_MQH
#define CCLOCKTIMESERVICE_MQH

//+------------------------------------------------------------------+
//| Class: CClockTimeService                                         |
//| Purpose: Provide centralized time utilities                      |
//| Owner: Layer 0 (DOC05A)                                          |
//| Consumers: All layers                                            |
//| Dependencies: None                                               |
//+------------------------------------------------------------------+
class CClockTimeService
{
private:
   bool              m_isInitialized;
   int               m_utcOffsetMinutes;
   
   void              InitializeOffset();
   
public:
                     CClockTimeService();
                    ~CClockTimeService();
   
   bool              Initialize();
   bool              IsInitialized() const;
   
   datetime          GetBrokerTime() const;
   datetime          GetUTCTime() const;
   datetime          GetLocalTime() const;
   
   datetime          BrokerToUTC(const datetime brokerTime) const;
   datetime          UTCToBroker(const datetime utcTime) const;
   
   datetime          GetCurrentTimestamp() const;
   
   string            FormatDateTime(const datetime dt) const;
   string            FormatDate(const datetime dt) const;
   string            FormatTime(const datetime dt) const;
   
   datetime          ParseDateTime(const string dateTimeStr) const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CClockTimeService::CClockTimeService()
{
   m_isInitialized = false;
   m_utcOffsetMinutes = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CClockTimeService::~CClockTimeService()
{
}

//+------------------------------------------------------------------+
//| Initialize offset between broker and UTC                         |
//+------------------------------------------------------------------+
void CClockTimeService::InitializeOffset()
{
   datetime brokerTime = TimeCurrent();
   datetime utcTime = TimeGMT();
   
   if(brokerTime > 0 && utcTime > 0)
   {
      m_utcOffsetMinutes = (int)((brokerTime - utcTime) / 60);
   }
   else
   {
      m_utcOffsetMinutes = 0;
   }
}

//+------------------------------------------------------------------+
//| Initialize service                                               |
//+------------------------------------------------------------------+
bool CClockTimeService::Initialize()
{
   InitializeOffset();
   m_isInitialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Check if service is initialized                                  |
//+------------------------------------------------------------------+
bool CClockTimeService::IsInitialized() const
{
   return m_isInitialized;
}

//+------------------------------------------------------------------+
//| Get current broker time                                          |
//+------------------------------------------------------------------+
datetime CClockTimeService::GetBrokerTime() const
{
   return TimeCurrent();
}

//+------------------------------------------------------------------+
//| Get current UTC time                                             |
//+------------------------------------------------------------------+
datetime CClockTimeService::GetUTCTime() const
{
   return TimeGMT();
}

//+------------------------------------------------------------------+
//| Get current local time                                           |
//+------------------------------------------------------------------+
datetime CClockTimeService::GetLocalTime() const
{
   return TimeLocal();
}

//+------------------------------------------------------------------+
//| Convert broker time to UTC                                       |
//+------------------------------------------------------------------+
datetime CClockTimeService::BrokerToUTC(const datetime brokerTime) const
{
   return brokerTime - (m_utcOffsetMinutes * 60);
}

//+------------------------------------------------------------------+
//| Convert UTC time to broker time                                  |
//+------------------------------------------------------------------+
datetime CClockTimeService::UTCToBroker(const datetime utcTime) const
{
   return utcTime + (m_utcOffsetMinutes * 60);
}

//+------------------------------------------------------------------+
//| Get current timestamp                                            |
//+------------------------------------------------------------------+
datetime CClockTimeService::GetCurrentTimestamp() const
{
   return TimeCurrent();
}

//+------------------------------------------------------------------+
//| Format date and time as string                                   |
//+------------------------------------------------------------------+
string CClockTimeService::FormatDateTime(const datetime dt) const
{
   return TimeToString(dt, TIME_DATE|TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| Format date only as string                                       |
//+------------------------------------------------------------------+
string CClockTimeService::FormatDate(const datetime dt) const
{
   return TimeToString(dt, TIME_DATE);
}

//+------------------------------------------------------------------+
//| Format time only as string                                       |
//+------------------------------------------------------------------+
string CClockTimeService::FormatTime(const datetime dt) const
{
   return TimeToString(dt, TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| Parse date and time from string                                  |
//+------------------------------------------------------------------+
datetime CClockTimeService::ParseDateTime(const string dateTimeStr) const
{
   return StringToTime(dateTimeStr);
}

#endif

