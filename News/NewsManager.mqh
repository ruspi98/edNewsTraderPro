//+------------------------------------------------------------------+
//|                                                  NewsManager.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include "MT5CalendarProvider.mqh"
#include "ManualNewsProvider.mqh"
#include "../Config/Config.mqh"

//+------------------------------------------------------------------+
//| Struktur Penyimpanan Riwayat Histori Event                      |
//+------------------------------------------------------------------+
struct SEventHistory
{
   ulong            calendar_id;
   datetime         time;
   string           currency;
   string           event_name;
   bool             straddle_triggered;
   bool             post_breakout_triggered;
   bool             is_completed;
   ulong            buy_stop_ticket;
   ulong            sell_stop_ticket;
   datetime         order_place_time;
};

//+------------------------------------------------------------------+
//| Pengelola Seluruh Sumber dan Antrean Berita                      |
//+------------------------------------------------------------------+
class CNewsManager
{
private:
   CMT5CalendarProvider   m_calendarProvider;
   CManualNewsProvider    m_manualProvider;
   
   SNewsEvent             m_eventQueue[];
   int                    m_totalEvents;
   datetime               m_lastRefreshTime;
   int                    m_refreshIntervalSec;
   
   SEventHistory          m_history[];
   int                    m_totalHistory;
   
   string                 m_symbol;
   ENUM_NEWS_SOURCE       m_sourceType;

   // Temukan riwayat event berdasarkan calendar_id atau pasangan time+currency
   int FindHistory(ulong calendar_id, datetime eventTime, string currency)
   {
      for(int i = 0; i < m_totalHistory; i++)
      {
         if(calendar_id > 0 && m_history[i].calendar_id == calendar_id)
            return i;
         if(m_history[i].time == eventTime && m_history[i].currency == currency)
            return i;
      }
      return -1;
   }

   // Rekam atau perbarui status event ke dalam memori persisten histori
   void RecordHistory(const SNewsEvent &ev)
   {
      int idx = FindHistory(ev.calendar_id, ev.time, ev.currency);
      if(idx >= 0)
      {
         m_history[idx].straddle_triggered      = ev.straddle_triggered;
         m_history[idx].post_breakout_triggered = ev.post_breakout_triggered;
         m_history[idx].is_completed            = ev.is_completed;
         m_history[idx].buy_stop_ticket         = ev.buy_stop_ticket;
         m_history[idx].sell_stop_ticket        = ev.sell_stop_ticket;
         m_history[idx].order_place_time        = ev.order_place_time;
      }
      else
      {
         int newSize = m_totalHistory + 1;
         ArrayResize(m_history, newSize);
         m_history[m_totalHistory].calendar_id             = ev.calendar_id;
         m_history[m_totalHistory].time                    = ev.time;
         m_history[m_totalHistory].currency                = ev.currency;
         m_history[m_totalHistory].event_name              = ev.event_name;
         m_history[m_totalHistory].straddle_triggered      = ev.straddle_triggered;
         m_history[m_totalHistory].post_breakout_triggered = ev.post_breakout_triggered;
         m_history[m_totalHistory].is_completed            = ev.is_completed;
         m_history[m_totalHistory].buy_stop_ticket         = ev.buy_stop_ticket;
         m_history[m_totalHistory].sell_stop_ticket        = ev.sell_stop_ticket;
         m_history[m_totalHistory].order_place_time        = ev.order_place_time;
         m_totalHistory++;
      }
   }

   // Urutkan antrean berita berdasarkan waktu terkecil ke terbesar
   void SortQueue()
   {
      for(int i = 0; i < m_totalEvents - 1; i++)
      {
         for(int j = i + 1; j < m_totalEvents; j++)
         {
            if(m_eventQueue[j].time < m_eventQueue[i].time)
            {
               SNewsEvent temp = m_eventQueue[i];
               m_eventQueue[i] = m_eventQueue[j];
               m_eventQueue[j] = temp;
            }
         }
      }
   }

public:
   CNewsManager() : m_totalEvents(0), m_lastRefreshTime(0), m_refreshIntervalSec(900),
                    m_totalHistory(0), m_symbol(""), m_sourceType(NEWS_SRC_HYBRID) {}
   ~CNewsManager() {}

   bool Init(const string symbol, ENUM_NEWS_SOURCE source, const string currencies, ENUM_NEWS_IMPACT impact, const string manualCSV, int refreshMin)
   {
      m_symbol             = symbol;
      m_sourceType         = source;
      m_refreshIntervalSec = refreshMin * 60;
      m_totalHistory       = 0;
      ArrayResize(m_history, 0);

      m_calendarProvider.Init(m_symbol, currencies, impact);
      m_manualProvider.Init(m_symbol, currencies, impact);
      m_manualProvider.SetManualCSV(manualCSV);

      RefreshQueue();
      return true;
   }

   // Perbarui daftar event dari provider terpilih
   void RefreshQueue()
   {
      datetime now = TimeCurrent();
      datetime fromTime = now - 3600; // Simpan 1 jam ke belakang untuk event yang sedang aktif
      datetime toTime   = now + (InpLookAheadHours * 3600);

      m_totalEvents = 0;
      ArrayResize(m_eventQueue, 0);

      SNewsEvent calEvents[];
      int calCount = 0;

      SNewsEvent manEvents[];
      int manCount = 0;

      if(m_sourceType == NEWS_SRC_MT5_CALENDAR || m_sourceType == NEWS_SRC_HYBRID)
      {
         m_calendarProvider.FetchUpcomingNews(fromTime, toTime, calEvents, calCount);
      }

      if(m_sourceType == NEWS_SRC_MANUAL_CSV || m_sourceType == NEWS_SRC_HYBRID)
      {
         m_manualProvider.FetchUpcomingNews(fromTime, toTime, manEvents, manCount);
      }

      // Gabungkan event dan hindari duplikasi waktu/mata uang yang berdekatan
      int combinedSize = calCount + manCount;
      ArrayResize(m_eventQueue, combinedSize);

      for(int i = 0; i < calCount; i++)
      {
         m_eventQueue[m_totalEvents++] = calEvents[i];
      }

      for(int j = 0; j < manCount; j++)
      {
         // Cek apakah sudah ada event serupa dari kalender
         bool duplicate = false;
         for(int k = 0; k < m_totalEvents; k++)
         {
            if(MathAbs(m_eventQueue[k].time - manEvents[j].time) < 180 && m_eventQueue[k].currency == manEvents[j].currency)
            {
               duplicate = true;
               break;
            }
         }
         if(!duplicate)
         {
            m_eventQueue[m_totalEvents++] = manEvents[j];
         }
      }

      ArrayResize(m_eventQueue, m_totalEvents);
      SortQueue();

      // Pulihkan status eksekusi event dari histori persisten
      for(int k = 0; k < m_totalEvents; k++)
      {
         int hIdx = FindHistory(m_eventQueue[k].calendar_id, m_eventQueue[k].time, m_eventQueue[k].currency);
         if(hIdx >= 0)
         {
            m_eventQueue[k].straddle_triggered      = m_history[hIdx].straddle_triggered;
            m_eventQueue[k].post_breakout_triggered = m_history[hIdx].post_breakout_triggered;
            m_eventQueue[k].is_completed            = m_history[hIdx].is_completed;
            m_eventQueue[k].buy_stop_ticket         = m_history[hIdx].buy_stop_ticket;
            m_eventQueue[k].sell_stop_ticket        = m_history[hIdx].sell_stop_ticket;
            m_eventQueue[k].order_place_time        = m_history[hIdx].order_place_time;
         }
      }

      m_lastRefreshTime = now;
      CUtils::Log(StringFormat("Antrean berita diperbarui: %d event siap dipantau.", m_totalEvents));
   }

   // Dipanggil secara periodik dari OnTimer / OnTick
   void UpdateTimer()
   {
      datetime now = TimeCurrent();
      if(m_lastRefreshTime == 0 || MathAbs(now - m_lastRefreshTime) >= m_refreshIntervalSec)
      {
         RefreshQueue();
      }
   }

   // Cek apakah siklus hidup event sudah tuntas berdasarkan strategi aktif
   void CheckAndMarkCompletion(SNewsEvent &ev, datetime now)
   {
      if(ev.is_completed) return;

      bool straddleDone = ev.straddle_triggered || (now > ev.time);
      bool postBODone   = ev.post_breakout_triggered || (now > ev.time + InpPostNewsWaitSec + 120);

      if(InpStrategyType == STRAT_STRADDLE_ONLY)
      {
         if(straddleDone)
         {
            ev.is_completed = true;
            RecordHistory(ev);
         }
      }
      else if(InpStrategyType == STRAT_POST_BREAKOUT_ONLY)
      {
         if(postBODone)
         {
            ev.is_completed = true;
            RecordHistory(ev);
         }
      }
      else // STRAT_BOTH_COMBINED
      {
         if(straddleDone && postBODone)
         {
            ev.is_completed = true;
            RecordHistory(ev);
         }
      }
   }

   // Ambil event berikutnya yang belum selesai
   bool GetNextEvent(SNewsEvent &outEvent, int &secondsToRelease)
   {
      datetime now = TimeCurrent();
      for(int i = 0; i < m_totalEvents; i++)
      {
         CheckAndMarkCompletion(m_eventQueue[i], now);

         if(!m_eventQueue[i].is_completed)
         {
            // Event belum selesai dan belum kedaluwarsa lebih dari 30 menit
            if(now <= m_eventQueue[i].time + 1800)
            {
               outEvent = m_eventQueue[i];
               secondsToRelease = (int)(m_eventQueue[i].time - now);
               return true;
            }
            else
            {
               m_eventQueue[i].is_completed = true;
               RecordHistory(m_eventQueue[i]);
            }
         }
      }
      return false;
   }

   // Tandai event straddle sudah aktif
   void SetStraddleTriggered(ulong calendar_id, ulong buyTicket, ulong sellTicket)
   {
      for(int i = 0; i < m_totalEvents; i++)
      {
         if(m_eventQueue[i].calendar_id == calendar_id)
         {
            m_eventQueue[i].straddle_triggered = true;
            m_eventQueue[i].buy_stop_ticket    = buyTicket;
            m_eventQueue[i].sell_stop_ticket   = sellTicket;
            m_eventQueue[i].order_place_time   = TimeCurrent();
            RecordHistory(m_eventQueue[i]);
            break;
         }
      }
   }

   // Tandai event post-breakout sudah aktif
   void SetPostBreakoutTriggered(ulong calendar_id, ulong buyTicket, ulong sellTicket)
   {
      for(int i = 0; i < m_totalEvents; i++)
      {
         if(m_eventQueue[i].calendar_id == calendar_id)
         {
            m_eventQueue[i].post_breakout_triggered = true;
            m_eventQueue[i].buy_stop_ticket         = buyTicket;
            m_eventQueue[i].sell_stop_ticket        = sellTicket;
            m_eventQueue[i].order_place_time        = TimeCurrent();
            RecordHistory(m_eventQueue[i]);
            break;
         }
      }
   }

   // Tandai event selesai sepenuhnya
   void MarkEventCompleted(ulong calendar_id)
   {
      for(int i = 0; i < m_totalEvents; i++)
      {
         if(m_eventQueue[i].calendar_id == calendar_id)
         {
            m_eventQueue[i].is_completed = true;
            RecordHistory(m_eventQueue[i]);
            break;
         }
      }
   }
};
