//+------------------------------------------------------------------+
//|                                        CIdentifierGeneration.mqh |
//|                                        Copyright 2026, BOT_SMC   |
//+------------------------------------------------------------------+
#ifndef CIDENTIFIERGENERATION_MQH
#define CIDENTIFIERGENERATION_MQH

string GenerateUUID()
{
   MathSrand(GetTickCount() + (int)TimeLocal());
   string uuid = "";
   string hex = "0123456789abcdef";
   
   for(int i = 0; i < 36; i++)
   {
      if(i == 8 || i == 13 || i == 18 || i == 23) uuid += "-";
      else if(i == 14) uuid += "4";
      else if(i == 19) uuid += StringSubstr(hex, MathRand() % 4 + 8, 1);
      else uuid += StringSubstr(hex, MathRand() % 16, 1);
   }
   return uuid;
}

#endif
