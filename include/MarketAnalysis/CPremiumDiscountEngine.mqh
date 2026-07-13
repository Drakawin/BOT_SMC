//+------------------------------------------------------------------+
//|                                     CPremiumDiscountEngine.mqh   |
//|                                        Copyright 2026, BOT_SMC   |
//| Document: DOC02J (Premium and Discount Engine)                   |
//+------------------------------------------------------------------+
#ifndef CPREMIUMDISCOUNTENGINE_MQH
#define CPREMIUMDISCOUNTENGINE_MQH

class CPremiumDiscountEngine
{
private:
   bool                 m_initialized;
   
   double               m_rangeHigh;
   double               m_rangeLow;
   double               m_equilibrium;

public:
                        CPremiumDiscountEngine();
                       ~CPremiumDiscountEngine();
                       
   bool                 Initialize();
   bool                 IsInitialized() const { return m_initialized; }
   
   // Update the dealing range when new swings are detected
   void                 UpdateRange(double swingHigh, double swingLow);
   
   // State getters
   bool                 IsRangeDefined() const;
   double               GetRangeHigh() const { return m_rangeHigh; }
   double               GetRangeLow() const { return m_rangeLow; }
   double               GetEquilibrium() const { return m_equilibrium; }
   
   // Spatial queries (Point-based)
   bool                 IsPremium(double price) const;
   bool                 IsDiscount(double price) const;
   
   // Spatial queries (Zone-based)
   // A zone is strictly in Premium if its lowest boundary is >= Equilibrium
   bool                 IsZoneStrictlyPremium(double zoneLow) const;
   
   // A zone is strictly in Discount if its highest boundary is <= Equilibrium
   bool                 IsZoneStrictlyDiscount(double zoneHigh) const;
   
   // A zone touches Premium if its highest boundary crosses above Equilibrium
   bool                 DoesZoneTouchPremium(double zoneHigh) const;
   
   // A zone touches Discount if its lowest boundary crosses below Equilibrium
   bool                 DoesZoneTouchDiscount(double zoneLow) const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CPremiumDiscountEngine::CPremiumDiscountEngine()
{
   m_initialized = false;
   m_rangeHigh = 0.0;
   m_rangeLow = 0.0;
   m_equilibrium = 0.0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CPremiumDiscountEngine::~CPremiumDiscountEngine()
{
}

//+------------------------------------------------------------------+
//| Initialize                                                       |
//+------------------------------------------------------------------+
bool CPremiumDiscountEngine::Initialize()
{
   m_initialized = true;
   return true;
}

//+------------------------------------------------------------------+
//| Update Dealing Range and Equilibrium                             |
//+------------------------------------------------------------------+
void CPremiumDiscountEngine::UpdateRange(double swingHigh, double swingLow)
{
   if(!m_initialized) return;
   
   // Only update if both bounds are valid
   if(swingHigh > 0.0 && swingLow > 0.0 && swingHigh > swingLow)
   {
      m_rangeHigh = swingHigh;
      m_rangeLow = swingLow;
      m_equilibrium = (m_rangeHigh + m_rangeLow) / 2.0;
   }
}

//+------------------------------------------------------------------+
//| Check if Range is Defined                                        |
//+------------------------------------------------------------------+
bool CPremiumDiscountEngine::IsRangeDefined() const
{
   return (m_rangeHigh > 0.0 && m_rangeLow > 0.0 && m_equilibrium > 0.0);
}

//+------------------------------------------------------------------+
//| Spatial Query: Point in Premium? (Strictly > Equilibrium)        |
//+------------------------------------------------------------------+
bool CPremiumDiscountEngine::IsPremium(double price) const
{
   if(!IsRangeDefined()) return false; // Fail safe
   return (price > m_equilibrium);
}

//+------------------------------------------------------------------+
//| Spatial Query: Point in Discount? (Strictly < Equilibrium)       |
//+------------------------------------------------------------------+
bool CPremiumDiscountEngine::IsDiscount(double price) const
{
   if(!IsRangeDefined()) return false;
   return (price < m_equilibrium);
}

//+------------------------------------------------------------------+
//| Spatial Query: Zone Strictly Premium                             |
//+------------------------------------------------------------------+
bool CPremiumDiscountEngine::IsZoneStrictlyPremium(double zoneLow) const
{
   if(!IsRangeDefined()) return false;
   return (zoneLow >= m_equilibrium);
}

//+------------------------------------------------------------------+
//| Spatial Query: Zone Strictly Discount                            |
//+------------------------------------------------------------------+
bool CPremiumDiscountEngine::IsZoneStrictlyDiscount(double zoneHigh) const
{
   if(!IsRangeDefined()) return false;
   return (zoneHigh <= m_equilibrium);
}

//+------------------------------------------------------------------+
//| Spatial Query: Zone Touches Premium                              |
//+------------------------------------------------------------------+
bool CPremiumDiscountEngine::DoesZoneTouchPremium(double zoneHigh) const
{
   if(!IsRangeDefined()) return false;
   return (zoneHigh > m_equilibrium);
}

//+------------------------------------------------------------------+
//| Spatial Query: Zone Touches Discount                             |
//+------------------------------------------------------------------+
bool CPremiumDiscountEngine::DoesZoneTouchDiscount(double zoneLow) const
{
   if(!IsRangeDefined()) return false;
   return (zoneLow < m_equilibrium);
}

#endif