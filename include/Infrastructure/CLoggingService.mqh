//+------------------------------------------------------------------+
//|                                            CLoggingService.mqh   |
//|                                        Copyright 2026, BOT_SMC   |
//|                                            Layer 0: Infrastructure|
//| Document: DOC05A (Infrastructure Blueprint)                      |
//| Document: DOC06A (Implementation Blueprint)                      |
//+------------------------------------------------------------------+
#ifndef CLOGGINGSERVICE_MQH
#define CLOGGINGSERVICE_MQH

//+------------------------------------------------------------------+
//| Enum: ENUM_LOG_LEVEL                                             |
//| Purpose: Define log severity levels                              |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_LEVEL_TRACE   = 0,
   LOG_LEVEL_DEBUG   = 1,
   LOG_LEVEL_INFO    = 2,
   LOG_LEVEL_WARNING = 3,
   LOG_LEVEL_ERROR   = 4,
   LOG_LEVEL_FATAL   = 5
};

//+------------------------------------------------------------------+
//| Class: CLoggingService                                           |
//| Purpose: Provide centralized logging to MT5 Journal              |
//| Owner: Layer 0 (DOC05A)                                          |
//| Consumers: All layers                                            |
//| Dependencies: None                                               |
//+------------------------------------------------------------------+
class CLoggingService
{
private:
   //--- Logging state
   bool            m_initialized;
   ENUM_LOG_LEVEL  m_currentLevel;

   //--- Private helpers
   string GetLevelName(const ENUM_LOG_LEVEL level) const;
   string FormatMessage(const ENUM_LOG_LEVEL level,
                        const string category,
                        const string module,
                        const string message) const;
   void   WriteToJournal(const string formattedMessage) const;

public:
                     CLoggingService(void);
                    ~CLoggingService(void);

   //--- Initialization
   bool   Initialize(const ENUM_LOG_LEVEL initialLevel);
   bool   IsInitialized(void) const;

   //--- Configuration
   void   SetLogLevel(const ENUM_LOG_LEVEL level);
   ENUM_LOG_LEVEL GetLogLevel(void) const;

   //--- Logging methods
   void   Trace(const string category, const string module, const string message);
   void   Debug(const string category, const string module, const string message);
   void   Info(const string category, const string module, const string message);
   void   Warning(const string category, const string module, const string message);
   void   Error(const string category, const string module, const string message);
   void   Fatal(const string category, const string module, const string message);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CLoggingService::CLoggingService(void)
   : m_initialized(false),
     m_currentLevel(LOG_LEVEL_INFO)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CLoggingService::~CLoggingService(void)
{
}

//+------------------------------------------------------------------+
//| Get human-readable log level name                                |
//+------------------------------------------------------------------+
string CLoggingService::GetLevelName(const ENUM_LOG_LEVEL level) const
{
   switch(level)
   {
      case LOG_LEVEL_TRACE:   return("TRACE");
      case LOG_LEVEL_DEBUG:   return("DEBUG");
      case LOG_LEVEL_INFO:    return("INFO");
      case LOG_LEVEL_WARNING: return("WARN");
      case LOG_LEVEL_ERROR:   return("ERROR");
      case LOG_LEVEL_FATAL:   return("FATAL");
      default:                return("UNKNOWN");
   }
}

//+------------------------------------------------------------------+
//| Format log message with consistent structure                     |
//| Format: [TIMESTAMP] [LEVEL] [CATEGORY] [MODULE] MESSAGE          |
//+------------------------------------------------------------------+
string CLoggingService::FormatMessage(const ENUM_LOG_LEVEL level,
                                      const string category,
                                      const string module,
                                      const string message) const
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
   string levelName = GetLevelName(level);

   return(StringFormat("[%s] [%s] [%s] [%s] %s",
                       timestamp,
                       levelName,
                       category,
                       module,
                       message));
}

//+------------------------------------------------------------------+
//| Write formatted message to MT5 Journal                           |
//+------------------------------------------------------------------+
void CLoggingService::WriteToJournal(const string formattedMessage) const
{
   Print(formattedMessage);
}

//+------------------------------------------------------------------+
//| Initialize logging service with specified level                  |
//+------------------------------------------------------------------+
bool CLoggingService::Initialize(const ENUM_LOG_LEVEL initialLevel)
{
   m_currentLevel = initialLevel;
   m_initialized = true;
   return(true);
}

//+------------------------------------------------------------------+
//| Check if service is initialized                                  |
//+------------------------------------------------------------------+
bool CLoggingService::IsInitialized(void) const
{
   return(m_initialized);
}

//+------------------------------------------------------------------+
//| Set current log level                                            |
//+------------------------------------------------------------------+
void CLoggingService::SetLogLevel(const ENUM_LOG_LEVEL level)
{
   m_currentLevel = level;
}

//+------------------------------------------------------------------+
//| Get current log level                                            |
//+------------------------------------------------------------------+
ENUM_LOG_LEVEL CLoggingService::GetLogLevel(void) const
{
   return(m_currentLevel);
}

//+------------------------------------------------------------------+
//| Log TRACE message                                                |
//+------------------------------------------------------------------+
void CLoggingService::Trace(const string category, const string module, const string message)
{
   if(!m_initialized || m_currentLevel > LOG_LEVEL_TRACE)
      return;

   string formatted = FormatMessage(LOG_LEVEL_TRACE, category, module, message);
   WriteToJournal(formatted);
}

//+------------------------------------------------------------------+
//| Log DEBUG message                                                |
//+------------------------------------------------------------------+
void CLoggingService::Debug(const string category, const string module, const string message)
{
   if(!m_initialized || m_currentLevel > LOG_LEVEL_DEBUG)
      return;

   string formatted = FormatMessage(LOG_LEVEL_DEBUG, category, module, message);
   WriteToJournal(formatted);
}

//+------------------------------------------------------------------+
//| Log INFO message                                                 |
//+------------------------------------------------------------------+
void CLoggingService::Info(const string category, const string module, const string message)
{
   if(!m_initialized || m_currentLevel > LOG_LEVEL_INFO)
      return;

   string formatted = FormatMessage(LOG_LEVEL_INFO, category, module, message);
   WriteToJournal(formatted);
}

//+------------------------------------------------------------------+
//| Log WARNING message                                              |
//+------------------------------------------------------------------+
void CLoggingService::Warning(const string category, const string module, const string message)
{
   if(!m_initialized || m_currentLevel > LOG_LEVEL_WARNING)
      return;

   string formatted = FormatMessage(LOG_LEVEL_WARNING, category, module, message);
   WriteToJournal(formatted);
}

//+------------------------------------------------------------------+
//| Log ERROR message                                                |
//+------------------------------------------------------------------+
void CLoggingService::Error(const string category, const string module, const string message)
{
   if(!m_initialized || m_currentLevel > LOG_LEVEL_ERROR)
      return;

   string formatted = FormatMessage(LOG_LEVEL_ERROR, category, module, message);
   WriteToJournal(formatted);
}

//+------------------------------------------------------------------+
//| Log FATAL message                                                |
//+------------------------------------------------------------------+
void CLoggingService::Fatal(const string category, const string module, const string message)
{
   if(!m_initialized)
      return;

   string formatted = FormatMessage(LOG_LEVEL_FATAL, category, module, message);
   WriteToJournal(formatted);
}

#endif
