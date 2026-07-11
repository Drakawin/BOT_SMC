//+------------------------------------------------------------------+
//|                                        CBootstrapEngine.mqh      |
//|                                        Copyright 2026, BOT_SMC   |
//|                                            Layer 0: Infrastructure|
//| Document: DOC05A (Infrastructure Blueprint)                      |
//| Document: DOC06A (Implementation Blueprint)                      |
//+------------------------------------------------------------------+
#ifndef CBOOTSTRAPENGINE_MQH
#define CBOOTSTRAPENGINE_MQH

#include "CConfigurationService.mqh"
#include "CLoggingService.mqh"
#include "CErrorHandlingService.mqh"
#include "CClockTimeService.mqh"

//+------------------------------------------------------------------+
//| Enum: ENUM_BOOTSTRAP_STATUS                                      |
//| Purpose: Define bootstrap startup status                         |
//+------------------------------------------------------------------+
enum ENUM_BOOTSTRAP_STATUS
{
   BOOTSTRAP_STATUS_SUCCESS        = 0,
   BOOTSTRAP_STATUS_CONFIG_FAILED  = 1,
   BOOTSTRAP_STATUS_LOGGING_FAILED = 2,
   BOOTSTRAP_STATUS_ERROR_FAILED   = 3,
   BOOTSTRAP_STATUS_CLOCK_FAILED   = 4
};

//+------------------------------------------------------------------+
//| Class: CBootstrapEngine                                          |
//| Purpose: Orchestrate infrastructure service startup              |
//| Owner: Layer 0 (DOC05A)                                          |
//| Consumers: Main EA                                               |
//| Dependencies: All infrastructure services                        |
//+------------------------------------------------------------------+
class CBootstrapEngine
{
private:
   bool                     m_initialized;
   ENUM_BOOTSTRAP_STATUS    m_status;
   string                   m_statusMessage;
   
   CConfigurationService*   m_configService;
   CLoggingService*         m_loggingService;
   CErrorHandlingService*   m_errorService;
   CClockTimeService*       m_clockService;
   
   bool   InitializeConfiguration();
   bool   InitializeLogging();
   bool   InitializeErrorHandling();
   bool   InitializeClock();
   
   void   SetStatus(const ENUM_BOOTSTRAP_STATUS status, const string message);
   void   CleanupServices();
   
public:
                     CBootstrapEngine();
                    ~CBootstrapEngine();
   
   ENUM_BOOTSTRAP_STATUS Initialize();
   bool                  IsInitialized() const;
   ENUM_BOOTSTRAP_STATUS GetStatus() const;
   string                GetStatusMessage() const;
   
   CConfigurationService* GetConfigurationService() const;
   CLoggingService*       GetLoggingService() const;
   CErrorHandlingService* GetErrorHandlingService() const;
   CClockTimeService*     GetClockService() const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBootstrapEngine::CBootstrapEngine()
{
   m_initialized = false;
   m_status = BOOTSTRAP_STATUS_SUCCESS;
   m_statusMessage = "";
   
   m_configService = NULL;
   m_loggingService = NULL;
   m_errorService = NULL;
   m_clockService = NULL;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBootstrapEngine::~CBootstrapEngine()
{
   CleanupServices();
}

//+------------------------------------------------------------------+
//| Set bootstrap status                                             |
//+------------------------------------------------------------------+
void CBootstrapEngine::SetStatus(const ENUM_BOOTSTRAP_STATUS status, const string message)
{
   m_status = status;
   m_statusMessage = message;
}

//+------------------------------------------------------------------+
//| Cleanup all services                                             |
//+------------------------------------------------------------------+
void CBootstrapEngine::CleanupServices()
{
   if(m_configService != NULL)
   {
      delete m_configService;
      m_configService = NULL;
   }
   
   if(m_loggingService != NULL)
   {
      delete m_loggingService;
      m_loggingService = NULL;
   }
   
   if(m_errorService != NULL)
   {
      delete m_errorService;
      m_errorService = NULL;
   }
   
   if(m_clockService != NULL)
   {
      delete m_clockService;
      m_clockService = NULL;
   }
}

//+------------------------------------------------------------------+
//| Initialize Configuration Service                                 |
//+------------------------------------------------------------------+
bool CBootstrapEngine::InitializeConfiguration()
{
   m_configService = new CConfigurationService();
   
   if(m_configService == NULL)
   {
      SetStatus(BOOTSTRAP_STATUS_CONFIG_FAILED, "Failed to create Configuration Service");
      return false;
   }
   
   ConfigInput defaultConfig;
   defaultConfig.brokerUTCOffset = 0;
   defaultConfig.magicNumber = 123456;
   defaultConfig.slippageCap = 10;
   defaultConfig.logLevel = 2;
   defaultConfig.logPath = "logs/";
   defaultConfig.logRetentionDays = 30;
   defaultConfig.statePath = "state/";
   defaultConfig.autoSaveInterval = 60;
   
   if(!m_configService.Initialize(defaultConfig))
   {
      SetStatus(BOOTSTRAP_STATUS_CONFIG_FAILED, "Configuration Service initialization failed");
      delete m_configService;
      m_configService = NULL;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize Logging Service                                       |
//+------------------------------------------------------------------+
bool CBootstrapEngine::InitializeLogging()
{
   m_loggingService = new CLoggingService();
   
   if(m_loggingService == NULL)
   {
      SetStatus(BOOTSTRAP_STATUS_LOGGING_FAILED, "Failed to create Logging Service");
      return false;
   }
   
   if(!m_loggingService.Initialize(LOG_LEVEL_INFO))
   {
      SetStatus(BOOTSTRAP_STATUS_LOGGING_FAILED, "Logging Service initialization failed");
      delete m_loggingService;
      m_loggingService = NULL;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize Error Handling Service                                |
//+------------------------------------------------------------------+
bool CBootstrapEngine::InitializeErrorHandling()
{
   m_errorService = new CErrorHandlingService();
   
   if(m_errorService == NULL)
   {
      SetStatus(BOOTSTRAP_STATUS_ERROR_FAILED, "Failed to create Error Handling Service");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize Clock Service                                         |
//+------------------------------------------------------------------+
bool CBootstrapEngine::InitializeClock()
{
   m_clockService = new CClockTimeService();
   
   if(m_clockService == NULL)
   {
      SetStatus(BOOTSTRAP_STATUS_CLOCK_FAILED, "Failed to create Clock Service");
      return false;
   }
   
   if(!m_clockService.Initialize())
   {
      SetStatus(BOOTSTRAP_STATUS_CLOCK_FAILED, "Clock Service initialization failed");
      delete m_clockService;
      m_clockService = NULL;
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize all services in correct order                         |
//+------------------------------------------------------------------+
ENUM_BOOTSTRAP_STATUS CBootstrapEngine::Initialize()
{
   if(!InitializeConfiguration())
   {
      CleanupServices();
      return m_status;
   }
   
   if(!InitializeLogging())
   {
      CleanupServices();
      return m_status;
   }
   
   if(!InitializeErrorHandling())
   {
      CleanupServices();
      return m_status;
   }
   
   if(!InitializeClock())
   {
      CleanupServices();
      return m_status;
   }
   
   m_initialized = true;
   SetStatus(BOOTSTRAP_STATUS_SUCCESS, "All infrastructure services initialized successfully");
   
   return BOOTSTRAP_STATUS_SUCCESS;
}

//+------------------------------------------------------------------+
//| Check if bootstrap is initialized                                |
//+------------------------------------------------------------------+
bool CBootstrapEngine::IsInitialized() const
{
   return m_initialized;
}

//+------------------------------------------------------------------+
//| Get bootstrap status                                             |
//+------------------------------------------------------------------+
ENUM_BOOTSTRAP_STATUS CBootstrapEngine::GetStatus() const
{
   return m_status;
}

//+------------------------------------------------------------------+
//| Get bootstrap status message                                     |
//+------------------------------------------------------------------+
string CBootstrapEngine::GetStatusMessage() const
{
   return m_statusMessage;
}

//+------------------------------------------------------------------+
//| Get Configuration Service pointer                                |
//+------------------------------------------------------------------+
CConfigurationService* CBootstrapEngine::GetConfigurationService() const
{
   return m_configService;
}

//+------------------------------------------------------------------+
//| Get Logging Service pointer                                      |
//+------------------------------------------------------------------+
CLoggingService* CBootstrapEngine::GetLoggingService() const
{
   return m_loggingService;
}

//+------------------------------------------------------------------+
//| Get Error Handling Service pointer                               |
//+------------------------------------------------------------------+
CErrorHandlingService* CBootstrapEngine::GetErrorHandlingService() const
{
   return m_errorService;
}

//+------------------------------------------------------------------+
//| Get Clock Service pointer                                        |
//+------------------------------------------------------------------+
CClockTimeService* CBootstrapEngine::GetClockService() const
{
   return m_clockService;
}

#endif