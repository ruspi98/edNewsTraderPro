//+------------------------------------------------------------------+
//|                                       ManualNewsProvider.mqh     |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include "INewsProvider.mqh"
#include "../Core/Utils.mqh"

//+------------------------------------------------------------------+
//| Provider Kalender Berita Manual (CSV / Text Timetable)           |
//+------------------------------------------------------------------+
class CManualNewsProvider : public INewsProvider
{
private:
   string            m_symbol;
   string            m_manualCSV;
   string            m_allowedCurrencies;
   ENUM_NEWS_IMPACT  m_minImpact;

   ENUM_NEWS_IMPACT ParseImpactString(string impStr)
   {
      StringTrimLeft(impStr);
      StringTrimRight(impStr);
      StringToUpper(impStr);
      if(StringFind(impStr, "HIGH") >= 0 || impStr == "3")
         return IMPACT_HIGH;
      if(StringFind(impStr, "MED") >= 0 || impStr == "2")
         return IMPACT_MEDIUM;
      if(StringFind(impStr, "LOW") >= 0 || impStr == "1")
         return IMPACT_LOW;
      return IMPACT_HIGH;
   }

   bool IsImpactToken(string token)
   {
      StringTrimLeft(token);
      StringTrimRight(token);
      StringToUpper(token);
      return (token == "HIGH" || token == "MEDIUM" || token == "MED" || token == "LOW" || 
              token == "1" || token == "2" || token == "3");
   }

public:
   CManualNewsProvider() : m_symbol(""), m_manualCSV(""), m_allowedCurrencies(""), m_minImpact(IMPACT_HIGH) {}
   virtual ~CManualNewsProvider() {}

   void SetManualCSV(const string manualCSV)
   {
      m_manualCSV = manualCSV;
   }

   virtual bool Init(const string symbol, const string currencies, ENUM_NEWS_IMPACT minImpact) override
   {
      m_symbol            = symbol;
      m_allowedCurrencies = currencies;
      m_minImpact         = minImpact;
      return true;
   }

   virtual string GetProviderName() const override
   {
      return "Manual CSV Timetable";
   }

   virtual bool FetchUpcomingNews(datetime fromTime, datetime toTime, SNewsEvent &events[], int &totalCount) override
   {
      totalCount = 0;
      ArrayResize(events, 0);

      if(m_manualCSV == "")
         return false;

      string entries[];
      int numEntries = 0;

      // 1. Cek apakah input merujuk ke nama file di folder MQL5\Files
      if(StringFind(m_manualCSV, ".csv") >= 0 || StringFind(m_manualCSV, ".txt") >= 0)
      {
         int fileHandle = FileOpen(m_manualCSV, FILE_READ|FILE_TXT|FILE_ANSI);
         if(fileHandle == INVALID_HANDLE)
         {
            // Coba buka dari folder Terminal\Common\Files
            fileHandle = FileOpen(m_manualCSV, FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
         }

         if(fileHandle != INVALID_HANDLE)
         {
            while(!FileIsEnding(fileHandle))
            {
               string line = FileReadString(fileHandle);
               StringTrimLeft(line);
               StringTrimRight(line);
               if(line == "" || StringSubstr(line, 0, 1) == "#") continue;

               int curSize = ArraySize(entries);
               ArrayResize(entries, curSize + 1);
               entries[curSize] = line;
            }
            FileClose(fileHandle);
            numEntries = ArraySize(entries);
            CUtils::Log(StringFormat("File kalender '%s' berhasil dibaca (%d baris).", m_manualCSV, numEntries));
         }
         else
         {
            CUtils::Log(StringFormat("PERINGATAN: File kalender '%s' tidak ditemukan di MQL5\\Files maupun Common\\Files! (Error: %d)", m_manualCSV, GetLastError()));
         }
      }

      // 2. Jika bukan file atau file tidak ditemukan, split string langsung
      if(numEntries == 0)
      {
         numEntries = StringSplit(m_manualCSV, ',', entries);
         if(numEntries <= 0)
         {
            numEntries = StringSplit(m_manualCSV, ';', entries);
            if(numEntries <= 0)
               return false;
         }
      }

      string baseCurr, quoteCurr;
      CUtils::GetSymbolCurrencies(m_symbol, baseCurr, quoteCurr);

      int allocated = 0;
      for(int i = 0; i < numEntries; i++)
      {
         string entry = entries[i];
         StringTrimLeft(entry);
         StringTrimRight(entry);
         if(entry == "")
            continue;

         // Cek apakah ada separator '|' atau ',' untuk metadata tambahan (WAKTU|CURRENCY|EVENT_NAME)
         string parts[];
         int numParts = StringSplit(entry, '|', parts);
         if(numParts <= 1)
         {
            numParts = StringSplit(entry, ',', parts);
         }


         datetime eventTime = 0;
         string eventCurr = quoteCurr;
         string eventName = "Manual News";
         ENUM_NEWS_IMPACT eventImpact = IMPACT_HIGH;

         if(numParts >= 1)
         {
            StringTrimLeft(parts[0]); StringTrimRight(parts[0]);
            eventTime = CUtils::ParseStringToTime(parts[0]);
         }
         if(numParts >= 2)
         {
            StringTrimLeft(parts[1]); StringTrimRight(parts[1]);
            eventCurr = parts[1];
         }
         if(numParts >= 4)
         {
            // Format 4 kolom standar: TIME|CURRENCY|IMPACT|EVENT_NAME
            if(IsImpactToken(parts[2]))
            {
               eventImpact = ParseImpactString(parts[2]);
               StringTrimLeft(parts[3]); StringTrimRight(parts[3]);
               eventName = parts[3];
            }
            // Format alternatif: TIME|CURRENCY|EVENT_NAME|IMPACT
            else if(IsImpactToken(parts[3]))
            {
               eventImpact = ParseImpactString(parts[3]);
               StringTrimLeft(parts[2]); StringTrimRight(parts[2]);
               eventName = parts[2];
            }
            else
            {
               StringTrimLeft(parts[2]); StringTrimRight(parts[2]);
               StringTrimLeft(parts[3]); StringTrimRight(parts[3]);
               eventName = parts[2] + " - " + parts[3];
            }
         }
         else if(numParts >= 3)
         {
            // Format legacy 3 kolom: TIME|CURRENCY|EVENT_NAME
            StringTrimLeft(parts[2]); StringTrimRight(parts[2]);
            if(IsImpactToken(parts[2]))
            {
               eventImpact = ParseImpactString(parts[2]);
               eventName   = "High Impact Scheduled Event";
            }
            else
            {
               eventName   = parts[2];
               eventImpact = IMPACT_HIGH;
            }
         }

         if(eventTime <= 0)
            continue;

         // Filter rentang waktu
         if(eventTime < fromTime || eventTime > toTime)
            continue;

         // Filter relevansi mata uang
         if(!CUtils::IsCurrencyRelevant(m_symbol, eventCurr, m_allowedCurrencies))
            continue;

         // Filter dampak berita (Impact Filter)
         if(m_minImpact == IMPACT_HIGH && eventImpact != IMPACT_HIGH)
            continue;
         if(m_minImpact == IMPACT_MEDIUM && (eventImpact != IMPACT_HIGH && eventImpact != IMPACT_MEDIUM))
            continue;

         if(allocated >= ArraySize(events))
         {
            int newSize = (allocated == 0) ? 8 : allocated * 2;
            ArrayResize(events, newSize);
         }

         events[allocated].calendar_id             = (ulong)eventTime * 1000 + (ulong)(i % 1000);
         events[allocated].time                    = eventTime;
         events[allocated].currency                = eventCurr;
         events[allocated].event_name              = eventName;
         events[allocated].impact                  = eventImpact;
         events[allocated].actual                  = 0.0;
         events[allocated].forecast                = 0.0;
         events[allocated].previous                = 0.0;
         events[allocated].straddle_triggered      = false;
         events[allocated].post_breakout_triggered = false;
         events[allocated].is_completed            = false;
         events[allocated].buy_stop_ticket         = 0;
         events[allocated].sell_stop_ticket        = 0;
         events[allocated].order_place_time        = 0;

         string impLabel = (eventImpact == IMPACT_HIGH) ? "HIGH" : (eventImpact == IMPACT_MEDIUM) ? "MED" : "LOW";
         CUtils::Log(StringFormat("Event berita terdeteksi: [%s | %s] %s pada %s", eventCurr, impLabel, eventName, TimeToString(eventTime)));
         allocated++;
      }

      ArrayResize(events, allocated);
      totalCount = allocated;
      return (totalCount > 0);
   }
};
