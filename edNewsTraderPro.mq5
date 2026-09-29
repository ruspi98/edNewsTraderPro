//+------------------------------------------------------------------+
//|                                              edNewsTraderPro.mq5 |
//|                                  Copyright 2026, edNewsTraderPro |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, edNewsTraderPro"
#property link        ""
#property version     "1.00"
#property description "Expert Advisor MT5 Modular Berbasis Berita Ekonomi (Multi-Strategy & Multi-Pair)"
#property tester_file "news_calendar_3years.csv"
#property tester_file "news_calendar.csv"

//+------------------------------------------------------------------+
//| Include Seluruh Modul Terorganisir                              |
//+------------------------------------------------------------------+
#include "Config/Config.mqh"
#include "Core/Defines.mqh"
#include "Core/Utils.mqh"
#include "Core/Diagnostics.mqh"
#include "Core/Dashboard.mqh"
#include "News/NewsManager.mqh"
#include "Execution/RiskManager.mqh"
#include "Execution/OrderManager.mqh"
#include "Execution/TrailingManager.mqh"
#include "Strategy/StrategyManager.mqh"

//+------------------------------------------------------------------+
//| Objek Instance Global                                            |
//+------------------------------------------------------------------+
CNewsManager      g_newsManager;
CRiskManager      g_riskManager;
COrderManager     g_orderManager;
CTrailingManager  g_trailingManager;
CStrategyManager  g_strategyManager;
CDashboard        g_dashboard;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   CUtils::Log("Memulai inisialisasi edNewsTraderPro...");

   // 0. Inisialisasi Modul Diagnosa & Health Monitoring
   CDiagnostics::Init();

   // 1. Inisialisasi Modul Proteksi & Eksekusi
   g_riskManager.Init(_Symbol);
   g_orderManager.Init(_Symbol, InpMagicNumber, InpMaxSlippagePts);
   g_trailingManager.Init(_Symbol, InpMagicNumber);

   // 2. Inisialisasi Modul Kalender & Berita
   g_newsManager.Init(
      _Symbol,
      InpNewsSource,
      InpFilterCurrencies,
      InpMinImpact,
      InpManualNewsCSV,
      InpCalendarUpdateMin
   );

   // 3. Inisialisasi Strategi
   if(!g_strategyManager.Init(_Symbol, InpMagicNumber, &g_orderManager, &g_riskManager))
   {
      CUtils::Log("Gagal menginisialisasi Strategy Manager!");
      return INIT_FAILED;
   }

   // 4. Inisialisasi Dashboard Visual
   g_dashboard.Init();

   // 5. Timer 1 detik untuk presisi perhitungan waktu berita
   if(!EventSetTimer(1))
   {
      CUtils::Log("Gagal memasang Timer 1 detik!");
      return INIT_FAILED;
   }

   CUtils::Log("Inisialisasi edNewsTraderPro SUKSES. EA siap beroperasi.");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   g_dashboard.Destroy();
   g_strategyManager.OnDeinit();
   CDiagnostics::PrintHealthSummary();
   CUtils::Log(StringFormat("edNewsTraderPro dimatikan (Reason code: %d).", reason));
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Jika sedang dalam Strategy Tester, pastikan event kalender diperiksa per tick
   if((bool)MQLInfoInteger(MQL_TESTER))
   {
      ProcessNewsEvents();
   }

   // 1. Update logika strategi (OCO & auto-cancel expiration)
   g_strategyManager.OnTickUpdate();

   // 2. Update manajemen trailing stop & breakeven
   g_trailingManager.Update();

   // 3. Pemantauan kesehatan periodik
   CDiagnostics::CheckPeriodicHealth();
}

//+------------------------------------------------------------------+
//| Pemrosesan Event Berita (Dipanggil oleh OnTimer & Tester OnTick) |
//+------------------------------------------------------------------+
void ProcessNewsEvents()
{
   // 1. Refresh periodik kalender
   g_newsManager.UpdateTimer();

   // 2. Ambil berita rilis terdekat
   SNewsEvent nextNews;
   int secondsToNews = 0;
   bool hasNews = g_newsManager.GetNextEvent(nextNews, secondsToNews);

   // 3. Update strategi berbasis waktu hitung mundur
   if(hasNews)
   {
      CDiagnostics::OnEventDetected(nextNews, secondsToNews);
      g_strategyManager.OnTimerUpdate(nextNews, secondsToNews);
      if(nextNews.straddle_triggered)
      {
         g_newsManager.SetStraddleTriggered(nextNews.calendar_id, nextNews.buy_stop_ticket, nextNews.sell_stop_ticket);
      }
      if(nextNews.post_breakout_triggered)
      {
         g_newsManager.SetPostBreakoutTriggered(nextNews.calendar_id, nextNews.buy_stop_ticket, nextNews.sell_stop_ticket);
      }
   }

   // 4. Update tampilan HUD Dashboard di chart
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE))
   {
      long currentSpread = g_riskManager.GetCurrentSpread();
      string sltpDesc = g_riskManager.GetSLTPDescription();
      g_dashboard.Update(_Symbol, currentSpread, nextNews, secondsToNews, hasNews, sltpDesc);
   }
}

//+------------------------------------------------------------------+
//| Expert timer function (Presisi Detik)                            |
//+------------------------------------------------------------------+
void OnTimer()
{
   ProcessNewsEvents();
}

//+------------------------------------------------------------------+
//| Trade Transaction function (Deteksi Kilat Perubahan Order/Deal)  |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Segera tangani OCO jika terjadi transaksi eksekusi pending order menjadi posisi
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD || trans.type == TRADE_TRANSACTION_ORDER_DELETE)
   {
      g_strategyManager.OnTickUpdate();
   }
}
