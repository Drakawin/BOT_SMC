//+------------------------------------------------------------------+
//|                                        CIdentifierGeneration.mqh |
//|                                        Copyright 2026, BOT_SMC   |
//+------------------------------------------------------------------+
#ifndef CIDENTIFIERGENERATION_MQH
#define CIDENTIFIERGENERATION_MQH

class CIdentifierGeneration
{
public:
   CIdentifierGeneration();
   ~CIdentifierGeneration();
   
   static string GenerateUUID();
};

CIdentifierGeneration::CIdentifierGeneration() {}
CIdentifierGeneration::~CIdentifierGeneration() {}

string CIdentifierGeneration::GenerateUUID()
{
   // Basic pseudo-UUID generator for MQL5 (format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX)
   // Using TimeLocal() + GetTickCount() + MathRand() for entropy
   
   MathSrand(GetTickCount() + (int)TimeLocal());
   
   string uuid = "";
   string hex = "0123456789abcdef";
   
   for(int i = 0; i < 36; i++)
   {
      if(i == 8 || i == 13 || i == 18 || i == 23)
      {
         uuid += "-";
      }
      else if(i == 14)
      {
         uuid += "4"; // UUID v4 standard
      }
      else if(i == 19)
      {
         int r = MathRand() % 4 + 8; // 8, 9, a, or b
         uuid += StringSubstr(hex, r, 1);
      }
      else
      {
         int r = MathRand() % 16;
         uuid += StringSubstr(hex, r, 1);
      }
   }
   
   return uuid;
}

#endif