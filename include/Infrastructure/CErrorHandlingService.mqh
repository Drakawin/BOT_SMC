//+------------------------------------------------------------------+
//|                                         CErrorHandlingService.mqh|
//|                                        Copyright 2026, BOT_SMC   |
//|                                            Layer 0: Infrastructure|
//| Document: DOC05A (Infrastructure Blueprint)                      |
//| Document: DOC06A (Implementation Blueprint)                      |
//+------------------------------------------------------------------+
#ifndef CERRORHANDLINGSERVICE_MQH
#define CERRORHANDLINGSERVICE_MQH

//+------------------------------------------------------------------+
//| Enum: ENUM_ERROR_SEVERITY                                        |
//| Purpose: Define error severity levels                            |
//+------------------------------------------------------------------+
enum ENUM_ERROR_SEVERITY
{
   ERROR_SEVERITY_INFO      = 0,
   ERROR_SEVERITY_WARNING   = 1,
   ERROR_SEVERITY_ERROR     = 2,
   ERROR_SEVERITY_CRITICAL  = 3,
   ERROR_SEVERITY_FATAL     = 4
};

//+------------------------------------------------------------------+
//| Struct: ErrorInfo                                                |
//| Purpose: Container for complete error information                |
//+------------------------------------------------------------------+
struct ErrorInfo
{
   int                  errorCode;
   string               errorCategory;
   string               errorMessage;
   string               sourceModule;
   datetime             timestamp;
   ENUM_ERROR_SEVERITY  severity;
};

//+------------------------------------------------------------------+
//| Class: CErrorHandlingService                                     |
//| Purpose: Provide centralized error handling and tracking         |
//| Owner: Layer 0 (DOC05A)                                          |
//| Consumers: All layers                                            |
//| Dependencies: None                                               |
//+------------------------------------------------------------------+
class CErrorHandlingService
{
private:
   //--- Error tracking state
   bool               m_hasError;
   int                m_lastErrorCode;
   string             m_lastErrorCategory;
   string             m_lastErrorMessage;
   string             m_lastErrorModule;
   datetime           m_lastErrorTimestamp;
   ENUM_ERROR_SEVERITY m_lastErrorSeverity;

public:
                     CErrorHandlingService(void);
                    ~CErrorHandlingService(void);

   //--- Error reporting
   void   ReportError(const int errorCode,
                      const string errorCategory,
                      const string errorMessage,
                      const string sourceModule,
                      const ENUM_ERROR_SEVERITY severity);

   //--- Error management
   void   ClearLastError(void);
   bool   HasError(void) const;

   //--- Error information retrieval
   ErrorInfo GetLastErrorInfo(void) const;
   string   GetLastErrorMessage(void) const;
   int      GetLastErrorCode(void) const;
   ENUM_ERROR_SEVERITY GetLastErrorSeverity(void) const;
   string   GetLastErrorCategory(void) const;
   string   GetLastErrorModule(void) const;
   datetime GetLastErrorTimestamp(void) const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CErrorHandlingService::CErrorHandlingService(void)
   : m_hasError(false),
     m_lastErrorCode(0),
     m_lastErrorCategory(""),
     m_lastErrorMessage(""),
     m_lastErrorModule(""),
     m_lastErrorTimestamp(0),
     m_lastErrorSeverity(ERROR_SEVERITY_INFO)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CErrorHandlingService::~CErrorHandlingService(void)
{
}

//+------------------------------------------------------------------+
//| Report a new error with complete information                     |
//+------------------------------------------------------------------+
void CErrorHandlingService::ReportError(const int errorCode,
                                        const string errorCategory,
                                        const string errorMessage,
                                        const string sourceModule,
                                        const ENUM_ERROR_SEVERITY severity)
{
   m_lastErrorCode     = errorCode;
   m_lastErrorCategory = errorCategory;
   m_lastErrorMessage  = errorMessage;
   m_lastErrorModule   = sourceModule;
   m_lastErrorTimestamp = TimeCurrent();
   m_lastErrorSeverity = severity;
   m_hasError          = true;
}

//+------------------------------------------------------------------+
//| Clear the last error                                             |
//+------------------------------------------------------------------+
void CErrorHandlingService::ClearLastError(void)
{
   m_hasError          = false;
   m_lastErrorCode     = 0;
   m_lastErrorCategory = "";
   m_lastErrorMessage  = "";
   m_lastErrorModule   = "";
   m_lastErrorTimestamp = 0;
   m_lastErrorSeverity = ERROR_SEVERITY_INFO;
}

//+------------------------------------------------------------------+
//| Check if an error exists                                         |
//+------------------------------------------------------------------+
bool CErrorHandlingService::HasError(void) const
{
   return(m_hasError);
}

//+------------------------------------------------------------------+
//| Get complete error information as ErrorInfo struct               |
//+------------------------------------------------------------------+
ErrorInfo CErrorHandlingService::GetLastErrorInfo(void) const
{
   ErrorInfo errorInfo;
   errorInfo.errorCode     = m_lastErrorCode;
   errorInfo.errorCategory = m_lastErrorCategory;
   errorInfo.errorMessage  = m_lastErrorMessage;
   errorInfo.sourceModule  = m_lastErrorModule;
   errorInfo.timestamp     = m_lastErrorTimestamp;
   errorInfo.severity      = m_lastErrorSeverity;
   return(errorInfo);
}

//+------------------------------------------------------------------+
//| Get last error message                                           |
//+------------------------------------------------------------------+
string CErrorHandlingService::GetLastErrorMessage(void) const
{
   return(m_lastErrorMessage);
}

//+------------------------------------------------------------------+
//| Get last error code                                              |
//+------------------------------------------------------------------+
int CErrorHandlingService::GetLastErrorCode(void) const
{
   return(m_lastErrorCode);
}

//+------------------------------------------------------------------+
//| Get last error severity                                          |
//+------------------------------------------------------------------+
ENUM_ERROR_SEVERITY CErrorHandlingService::GetLastErrorSeverity(void) const
{
   return(m_lastErrorSeverity);
}

//+------------------------------------------------------------------+
//| Get last error category                                          |
//+------------------------------------------------------------------+
string CErrorHandlingService::GetLastErrorCategory(void) const
{
   return(m_lastErrorCategory);
}

//+------------------------------------------------------------------+
//| Get last error source module                                     |
//+------------------------------------------------------------------+
string CErrorHandlingService::GetLastErrorModule(void) const
{
   return(m_lastErrorModule);
}

//+------------------------------------------------------------------+
//| Get last error timestamp                                         |
//+------------------------------------------------------------------+
datetime CErrorHandlingService::GetLastErrorTimestamp(void) const
{
   return(m_lastErrorTimestamp);
}

#endif

