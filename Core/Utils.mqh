//+------------------------------------------------------------------+
//|                                                        Utils.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include "Defines.mqh"

//+------------------------------------------------------------------+
//| Class Helper Utilitas Sistem                                     |
//+------------------------------------------------------------------+
class CUtils
{
public:
   // Log ke terminal dengan prefix standar
   static void Log(const string message)
   {
      PrintFormat("[edNewsTraderPro] %s", message);
   }

   // Format waktu countdown
   static string FormatCountdown(int totalSeconds)
   {
      bool isNegative = (totalSeconds < 0);
      int absSec = MathAbs(totalSeconds);
      
      int hours = absSec / 3600;
      int minutes = (absSec % 3600) / 60;
      int seconds = absSec % 60;
      
      string sign = isNegative ? "+" : "-"; // Jika negatif berarti sudah lewat X detik pasca rilis
      return StringFormat("%s%02d:%02d:%02d", sign, hours, minutes, seconds);
   }

   // Konversi point multiplier untuk 3 & 5 digit broker
   static double GetPipMultiplier(const string symbol)
   {
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      if(digits == 3 || digits == 5)
         return 10.0;
      return 1.0;
   }

   // Normalisasi harga order sesuai digit symbol
   static double NormalizePrice(const string symbol, double price)
   {
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      return NormalizeDouble(price, digits);
   }

   // Parsing base currency & quote currency dari symbol chart
   static void GetSymbolCurrencies(const string symbol, string &baseCurr, string &quoteCurr)
   {
      baseCurr  = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
      quoteCurr = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
      
      // Fallback jika broker menamai XAUUSD dengan nama komoditas
      if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      {
         baseCurr = "USD"; // Relevan dengan data USD
         quoteCurr = "USD";
      }
   }

   // Cek apakah mata uang berita cocok dengan pair chart
   static bool IsCurrencyRelevant(const string symbol, const string newsCurrency, const string allowedCurrencies)
   {
      string curr = newsCurrency;
      StringTrimLeft(curr);
      StringTrimRight(curr);
      StringToUpper(curr);

      // 1. Cek terhadap filter whitelist user
      if(allowedCurrencies != "" && allowedCurrencies != "ALL")
      {
         if(StringFind(allowedCurrencies, curr) < 0)
            return false;
      }

      // 2. Jika nama symbol mengandung kode mata uang (contoh: EURUSDc mengandung EUR dan USD)
      if(StringFind(symbol, curr) >= 0)
         return true;

      // Khusus XAU/Gold relevan terhadap rilis USD
      if((StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0) && curr == "USD")
         return true;

      return false;
   }

   // Konversi string tanggal manual ke datetime
   static datetime ParseStringToTime(string timeStr)
   {
      StringTrimLeft(timeStr);
      StringTrimRight(timeStr);
      
      // Standarisasi pemisah tanggal: ganti '-' atau '/' dengan '.'
      StringReplace(timeStr, "-", ".");
      StringReplace(timeStr, "/", ".");
      
      return StringToTime(timeStr);
   }
};
