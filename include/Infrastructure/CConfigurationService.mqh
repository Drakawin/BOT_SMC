//+------------------------------------------------------------------+
//|                                       CConfigurationService.mqh  |
//|                                        Copyright 2026, BOT_SMC   |
//|                                            Layer 0: Infrastructure|
//| Document: DOC05A (Infrastructure Blueprint)                      |
//| Document: DOC06A (Implementation Blueprint)                      |
//+------------------------------------------------------------------+
#ifndef CCONFIGURATIONSERVICE_MQH
#define CCONFIGURATIONSERVICE_MQH

//+------------------------------------------------------------------+
//| Struct: ConfigInput                                              |
//| Purpose: Container for runtime input parameters passed from EA   |
//+------------------------------------------------------------------+
struct ConfigInput
{
   // Broker settings
   int    brokerUTCOffset;
   long   magicNumber;
   int    slippageCap;

   // Logging settings
   int    logLevel;
   string logPath;
   int    logRetentionDays;

   // Persistence settings
   string statePath;
   int    autoSaveInterval;
};

//+------------------------------------------------------------------+
//| Class: CConfigurationService                                     |
//| Purpose: Load, validate, and expose all project configuration    |
//| Owner: Layer 0 (DOC05A)                                          |
//| Consumers: All layers                                            |
//| Dependencies: None                                               |
//+------------------------------------------------------------------+
class CConfigurationService
{
private:
   //--- Configuration state
   bool   m_initialized;
   bool   m_valid;
   string m_validationError;

   //--- Trading Parameters (locked, DOC00)
   double m_lotSize;
   double m_riskRewardRatio;
   int    m_maxOpenPositions;
   double m_equityKillThreshold;

   //--- SMC Constants (locked, DOC00)
   int m_swingFractalStrength;
   int m_equalLevelTolerance;
   int m_fvgMinSize;
   int m_slBuffer;
   int m_breakEvenBuffer;
   int m_maxRiskPerTradePoints;

   //--- Timeframes (locked, PATCH_001)
   ENUM_TIMEFRAMES m_primaryTrendTimeframe;
   ENUM_TIMEFRAMES m_marketStructureTimeframe;
   ENUM_TIMEFRAMES m_executionTimeframe;

   //--- Session windows in minutes since midnight UTC (locked, DOC00)
   int m_londonSessionStart;
   int m_londonSessionEnd;
   int m_newYorkAMSessionStart;
   int m_newYorkAMSessionEnd;

   //--- Runtime configuration (configurable)
   int    m_brokerUTCOffset;
   long   m_magicNumber;
   int    m_slippageCap;
   int    m_logLevel;
   string m_logPath;
   int    m_logRetentionDays;
   string m_statePath;
   int    m_autoSaveInterval;

   //--- Private initialization helpers
   void   InitializeLockedConstants(void);
   bool   ValidateRuntimeParameters(const ConfigInput &configInput);
   void   SetValidationError(const string module, const string message);

public:
                     CConfigurationService(void);
                    ~CConfigurationService(void);

   //--- Initialization
   bool   Initialize(const ConfigInput &configInput);
   bool   IsValid(void) const;
   string GetValidationError(void) const;
   bool   IsInitialized(void) const;

   //--- Trading Parameters (getters)
   double GetLotSize(void) const;
   double GetRiskRewardRatio(void) const;
   int    GetMaxOpenPositions(void) const;
   double GetEquityKillThreshold(void) const;

   //--- SMC Constants (getters)
   int    GetSwingFractalStrength(void) const;
   int    GetEqualLevelTolerance(void) const;
   int    GetFVGMinSize(void) const;
   int    GetSLBuffer(void) const;
   int    GetBreakEvenBuffer(void) const;
   int    GetMaxRiskPerTradePoints(void) const;

   //--- Timeframes (getters)
   ENUM_TIMEFRAMES GetPrimaryTrendTimeframe(void) const;
   ENUM_TIMEFRAMES GetMarketStructureTimeframe(void) const;
   ENUM_TIMEFRAMES GetExecutionTimeframe(void) const;

   //--- Session windows in minutes since midnight UTC (getters)
   int    GetLondonSessionStart(void) const;
   int    GetLondonSessionEnd(void) const;
   int    GetNewYorkAMSessionStart(void) const;
   int    GetNewYorkAMSessionEnd(void) const;

   //--- Runtime configuration (getters)
   int    GetBrokerUTCOffset(void) const;
   long   GetMagicNumber(void) const;
   int    GetSlippageCap(void) const;
   int    GetLogLevel(void) const;
   string GetLogPath(void) const;
   int    GetLogRetentionDays(void) const;
   string GetStatePath(void) const;
   int    GetAutoSaveInterval(void) const;

   //--- Symbol information
   double GetPoint(void) const;
   int    GetDigits(void) const;
   double NormalizePrice(const double price) const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CConfigurationService::CConfigurationService(void)
   : m_initialized(false),
     m_valid(false),
     m_validationError(""),
     m_lotSize(0.0),
     m_riskRewardRatio(0.0),
     m_maxOpenPositions(0),
     m_equityKillThreshold(0.0),
     m_swingFractalStrength(0),
     m_equalLevelTolerance(0),
     m_fvgMinSize(0),
     m_slBuffer(0),
     m_breakEvenBuffer(0),
     m_maxRiskPerTradePoints(0),
     m_primaryTrendTimeframe(PERIOD_CURRENT),
     m_marketStructureTimeframe(PERIOD_CURRENT),
     m_executionTimeframe(PERIOD_CURRENT),
     m_londonSessionStart(0),
     m_londonSessionEnd(0),
     m_newYorkAMSessionStart(0),
     m_newYorkAMSessionEnd(0),
     m_brokerUTCOffset(0),
     m_magicNumber(0),
     m_slippageCap(0),
     m_logLevel(0),
     m_logPath(""),
     m_logRetentionDays(0),
     m_statePath(""),
     m_autoSaveInterval(0)
{
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CConfigurationService::~CConfigurationService(void)
{
}

//+------------------------------------------------------------------+
//| Initialize locked constants from DOC00 and PATCH_001             |
//| These values are hardcoded per approved specification            |
//+------------------------------------------------------------------+
void CConfigurationService::InitializeLockedConstants(void)
{
   //--- Trading Parameters (DOC00 locked)
   m_lotSize             = 0.01;
   m_riskRewardRatio     = 2.0;
   m_maxOpenPositions    = 1;
   m_equityKillThreshold = 0.50;

   //--- SMC Constants (DOC00 locked)
   m_swingFractalStrength  = 2;
   m_equalLevelTolerance   = 20;
   m_fvgMinSize            = 10;
   m_slBuffer              = 20;
   m_breakEvenBuffer       = 5;
   m_maxRiskPerTradePoints = 1500;

   //--- Timeframes (PATCH_001 locked)
   m_primaryTrendTimeframe   = PERIOD_H4;
   m_marketStructureTimeframe = PERIOD_H1;
   m_executionTimeframe      = PERIOD_M15;

   //--- Session windows in minutes since midnight UTC (DOC00 locked)
   //    London: 07:00–10:00 UTC
   m_londonSessionStart = 7 * 60;   // 420
   m_londonSessionEnd   = 10 * 60;  // 600

   //    New York AM: 12:00–15:00 UTC
   m_newYorkAMSessionStart = 12 * 60;  // 720
   m_newYorkAMSessionEnd   = 15 * 60;  // 900
}

//+------------------------------------------------------------------+
//| Set validation error with module context                         |
//+------------------------------------------------------------------+
void CConfigurationService::SetValidationError(const string module, const string message)
{
   m_validationError = StringFormat("[%s] %s", module, message);
}

//+------------------------------------------------------------------+
//| Validate runtime parameters                                      |
//| Returns true if all validation checks pass                       |
//+------------------------------------------------------------------+
bool CConfigurationService::ValidateRuntimeParameters(const ConfigInput &configInput)
{
   //--- Broker UTC offset validation
   if(configInput.brokerUTCOffset < -12 || configInput.brokerUTCOffset > 14)
   {
      SetValidationError("Configuration", "BrokerUTCOffset out of range (-12 to +14)");
      return(false);
   }

   //--- Magic number validation
   if(configInput.magicNumber <= 0)
   {
      SetValidationError("Configuration", "MagicNumber must be positive");
      return(false);
   }

   //--- Slippage cap validation
   if(configInput.slippageCap < 0)
   {
      SetValidationError("Configuration", "SlippageCap must be non-negative");
      return(false);
   }

   //--- Log level validation (0=TRACE through 5=FATAL)
   if(configInput.logLevel < 0 || configInput.logLevel > 5)
   {
      SetValidationError("Configuration", "LogLevel out of range (0-5)");
      return(false);
   }

   //--- Log retention validation
   if(configInput.logRetentionDays < 1)
   {
      SetValidationError("Configuration", "LogRetentionDays must be at least 1");
      return(false);
   }

   //--- Auto-save interval validation
   if(configInput.autoSaveInterval < 1)
   {
      SetValidationError("Configuration", "AutoSaveInterval must be at least 1 second");
      return(false);
   }

   //--- Log path validation
   if(StringLen(configInput.logPath) == 0)
   {
      SetValidationError("Configuration", "LogPath must not be empty");
      return(false);
   }

   //--- State path validation
   if(StringLen(configInput.statePath) == 0)
   {
      SetValidationError("Configuration", "StatePath must not be empty");
      return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
//| Initialize: load locked constants and validate runtime inputs    |
//| Returns true if initialization succeeds                          |
//+------------------------------------------------------------------+
bool CConfigurationService::Initialize(const ConfigInput &configInput)
{
   //--- Load locked constants
   InitializeLockedConstants();

   //--- Store runtime configuration
   m_brokerUTCOffset  = configInput.brokerUTCOffset;
   m_magicNumber      = configInput.magicNumber;
   m_slippageCap      = configInput.slippageCap;
   m_logLevel         = configInput.logLevel;
   m_logPath          = configInput.logPath;
   m_logRetentionDays = configInput.logRetentionDays;
   m_statePath        = configInput.statePath;
   m_autoSaveInterval = configInput.autoSaveInterval;

   //--- Validate runtime parameters
   m_valid = ValidateRuntimeParameters(configInput);

   m_initialized = true;
   return(m_valid);
}

//+------------------------------------------------------------------+
//| State queries                                                    |
//+------------------------------------------------------------------+
bool CConfigurationService::IsValid(void) const
{
   return(m_valid);
}

string CConfigurationService::GetValidationError(void) const
{
   return(m_validationError);
}

bool CConfigurationService::IsInitialized(void) const
{
   return(m_initialized);
}

//+------------------------------------------------------------------+
//| Trading Parameters getters                                       |
//+------------------------------------------------------------------+
double CConfigurationService::GetLotSize(void) const
{
   return(m_lotSize);
}

double CConfigurationService::GetRiskRewardRatio(void) const
{
   return(m_riskRewardRatio);
}

int CConfigurationService::GetMaxOpenPositions(void) const
{
   return(m_maxOpenPositions);
}

double CConfigurationService::GetEquityKillThreshold(void) const
{
   return(m_equityKillThreshold);
}

//+------------------------------------------------------------------+
//| SMC Constants getters                                            |
//+------------------------------------------------------------------+
int CConfigurationService::GetSwingFractalStrength(void) const
{
   return(m_swingFractalStrength);
}

int CConfigurationService::GetEqualLevelTolerance(void) const
{
   return(m_equalLevelTolerance);
}

int CConfigurationService::GetFVGMinSize(void) const
{
   return(m_fvgMinSize);
}

int CConfigurationService::GetSLBuffer(void) const
{
   return(m_slBuffer);
}

int CConfigurationService::GetBreakEvenBuffer(void) const
{
   return(m_breakEvenBuffer);
}

int CConfigurationService::GetMaxRiskPerTradePoints(void) const
{
   return(m_maxRiskPerTradePoints);
}

//+------------------------------------------------------------------+
//| Timeframes getters                                               |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES CConfigurationService::GetPrimaryTrendTimeframe(void) const
{
   return(m_primaryTrendTimeframe);
}

ENUM_TIMEFRAMES CConfigurationService::GetMarketStructureTimeframe(void) const
{
   return(m_marketStructureTimeframe);
}

ENUM_TIMEFRAMES CConfigurationService::GetExecutionTimeframe(void) const
{
   return(m_executionTimeframe);
}

//+------------------------------------------------------------------+
//| Session getters (minutes since midnight UTC)                     |
//+------------------------------------------------------------------+
int CConfigurationService::GetLondonSessionStart(void) const
{
   return(m_londonSessionStart);
}

int CConfigurationService::GetLondonSessionEnd(void) const
{
   return(m_londonSessionEnd);
}

int CConfigurationService::GetNewYorkAMSessionStart(void) const
{
   return(m_newYorkAMSessionStart);
}

int CConfigurationService::GetNewYorkAMSessionEnd(void) const
{
   return(m_newYorkAMSessionEnd);
}

//+------------------------------------------------------------------+
//| Runtime configuration getters                                    |
//+------------------------------------------------------------------+
int CConfigurationService::GetBrokerUTCOffset(void) const
{
   return(m_brokerUTCOffset);
}

long CConfigurationService::GetMagicNumber(void) const
{
   return(m_magicNumber);
}

int CConfigurationService::GetSlippageCap(void) const
{
   return(m_slippageCap);
}

int CConfigurationService::GetLogLevel(void) const
{
   return(m_logLevel);
}

string CConfigurationService::GetLogPath(void) const
{
   return(m_logPath);
}

int CConfigurationService::GetLogRetentionDays(void) const
{
   return(m_logRetentionDays);
}

string CConfigurationService::GetStatePath(void) const
{
   return(m_statePath);
}

int CConfigurationService::GetAutoSaveInterval(void) const
{
   return(m_autoSaveInterval);
}

//+------------------------------------------------------------------+
//| Symbol information helpers                                       |
//+------------------------------------------------------------------+
double CConfigurationService::GetPoint(void) const
{
   return(SymbolInfoDouble(_Symbol, SYMBOL_POINT));
}

int CConfigurationService::GetDigits(void) const
{
   return((int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
}

double CConfigurationService::NormalizePrice(const double price) const
{
   return(NormalizeDouble(price, GetDigits()));
}

#endif
