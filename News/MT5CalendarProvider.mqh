//+------------------------------------------------------------------+
//|                                        MT5CalendarProvider.mqh   |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include "INewsProvider.mqh"
#include "../Core/Utils.mqh"

//+------------------------------------------------------------------+
//| Provider Kalender Bawaan MT5 (MQL5 Economic Calendar)            |
//+------------------------------------------------------------------+
class CMT5CalendarProvider : public INewsProvider
{
private:
   string            m_symbol;
   string            m_allowedCurrencies;
   ENUM_NEWS_IMPACT  m_minImpact;
   bool              m_isCalendarAvailable;

public:
   CMT5CalendarProvider() : m_symbol(""), m_allowedCurrencies(""), m_minImpact(IMPACT_HIGH), m_isCalendarAvailable(false) {}
   virtual ~CMT5CalendarProvider() {}

   virtual bool Init(const string symbol, const string currencies, ENUM_NEWS_IMPACT minImpact) override
   {
      m_symbol            = symbol;
      m_allowedCurrencies = currencies;
      m_minImpact         = minImpact;

      // Tes ketersediaan kalender MT5
      MqlCalendarValue testValues[];
      datetime testStart = TimeCurrent() - 3600;
      datetime testEnd   = TimeCurrent() + 3600;
      
      ResetLastError();
      int count = CalendarValueHistory(testValues, testStart, testEnd);
      if(count >= 0)
      {
         m_isCalendarAvailable = true;
         CUtils::Log("MT5 Calendar Provider berhasil diinisialisasi.");
      }
      else
      {
         int err = GetLastError();
         CUtils::Log(StringFormat("MT5 Calendar belum aktif atau tidak didukung broker (Kode error: %d).", err));
         m_isCalendarAvailable = false;
      }
      return true;
   }

   virtual string GetProviderName() const override
   {
      return "MT5 Economic Calendar";
   }

   virtual bool FetchUpcomingNews(datetime fromTime, datetime toTime, SNewsEvent &events[], int &totalCount) override
   {
      totalCount = 0;
      ArrayResize(events, 0);

      MqlCalendarValue values[];
      ResetLastError();
      int valCount = CalendarValueHistory(values, fromTime, toTime);
      if(valCount <= 0)
         return false;

      int allocated = 0;
      for(int i = 0; i < valCount; i++)
      {
         MqlCalendarEvent eventInfo;
         if(!CalendarEventById(values[i].event_id, eventInfo))
            continue;

         // Ambil data negara dan mata uang berdasarkan country_id
         MqlCalendarCountry countryInfo;
         if(!CalendarCountryById(eventInfo.country_id, countryInfo))
            continue;

         string eventCurrency = countryInfo.currency;

         // Filter dampak (Impact)
         ENUM_NEWS_IMPACT eventImpact = IMPACT_LOW;
         if(eventInfo.importance == CALENDAR_IMPORTANCE_HIGH)
            eventImpact = IMPACT_HIGH;
         else if(eventInfo.importance == CALENDAR_IMPORTANCE_MODERATE)
            eventImpact = IMPACT_MEDIUM;
         else
            eventImpact = IMPACT_LOW;

         // Lewatkan jika dampak di bawah filter minimum
         if(m_minImpact == IMPACT_HIGH && eventImpact != IMPACT_HIGH)
            continue;
         if(m_minImpact == IMPACT_MEDIUM && (eventImpact != IMPACT_HIGH && eventImpact != IMPACT_MEDIUM))
            continue;

         // Filter mata uang relevan
         if(!CUtils::IsCurrencyRelevant(m_symbol, eventCurrency, m_allowedCurrencies))
            continue;

         // Simpan event berita
         if(allocated >= ArraySize(events))
         {
            int newSize = (allocated == 0) ? 16 : allocated * 2;
            ArrayResize(events, newSize);
         }

         events[allocated].calendar_id             = values[i].id;
         events[allocated].time                    = values[i].time;
         events[allocated].currency                = eventCurrency;
         events[allocated].event_name              = eventInfo.name;
         events[allocated].impact                  = eventImpact;
         events[allocated].actual                  = (double)values[i].actual_value / 1000000.0;
         events[allocated].forecast                = (double)values[i].forecast_value / 1000000.0;
         events[allocated].previous                = (double)values[i].prev_value / 1000000.0;
         events[allocated].straddle_triggered      = false;
         events[allocated].post_breakout_triggered = false;
         events[allocated].is_completed            = false;
         events[allocated].buy_stop_ticket         = 0;
         events[allocated].sell_stop_ticket        = 0;
         events[allocated].order_place_time        = 0;

         allocated++;
      }

      ArrayResize(events, allocated);
      totalCount = allocated;
      return (totalCount > 0);
   }
};
