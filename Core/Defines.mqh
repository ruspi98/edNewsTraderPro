//+------------------------------------------------------------------+
//|                                                      Defines.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

//+------------------------------------------------------------------+
//| Enumerasi Strategi News                                          |
//+------------------------------------------------------------------+
enum ENUM_STRATEGY_TYPE
{
   STRAT_STRADDLE_ONLY      = 0, // Hanya Pre-News Straddle (Buy/Sell Stop)
   STRAT_POST_BREAKOUT_ONLY = 1, // Hanya Post-News Candle Breakout
   STRAT_BOTH_COMBINED      = 2  // Gabungan Keduanya (Straddle & Post-Breakout)
};

//+------------------------------------------------------------------+
//| Enumerasi Sumber Kalender Berita                                 |
//+------------------------------------------------------------------+
enum ENUM_NEWS_SOURCE
{
   NEWS_SRC_MT5_CALENDAR    = 0, // MT5 Built-in Economic Calendar
   NEWS_SRC_MANUAL_CSV      = 1, // Manual Timetable (Input CSV / Text)
   NEWS_SRC_HYBRID          = 2  // Hybrid (Kalender MT5 + Manual Override)
};

//+------------------------------------------------------------------+
//| Tingkat Dampak Berita (Impact Level)                             |
//+------------------------------------------------------------------+
enum ENUM_NEWS_IMPACT
{
   IMPACT_LOW    = 0, // Semua Impact termasuk Low
   IMPACT_MEDIUM = 1, // Medium & High Impact
   IMPACT_HIGH   = 2  // Khusus High Impact Saja (Rekomendasi)
};

//+------------------------------------------------------------------+
//| Tipe Order Pending                                               |
//+------------------------------------------------------------------+
enum ENUM_NEWS_ORDER_TYPE
{
   NEWS_ORDER_NONE     = 0,
   NEWS_ORDER_STRADDLE = 1,
   NEWS_ORDER_POST_BO  = 2
};

//+------------------------------------------------------------------+
//| Struktur Data Event Berita                                       |
//+------------------------------------------------------------------+
struct SNewsEvent
{
   ulong            calendar_id;              // ID kalender MT5 (jika ada)
   datetime         time;                     // Waktu rilis (Broker Server Time)
   string           currency;                 // USD, EUR, GBP, JPY, dll.
   string           event_name;               // Nama berita
   ENUM_NEWS_IMPACT impact;                   // Tingkat dampak
   double           actual;                   // Nilai aktual
   double           forecast;                 // Nilai perkiraan
   double           previous;                 // Nilai periode sebelumnya
   
   // Status eksekusi
   bool             straddle_triggered;       // Apakah pending straddle sudah dipasang
   bool             post_breakout_triggered;  // Apakah pending post-breakout sudah dipasang
   bool             is_completed;             // Apakah proses event ini sudah selesai
   
   // ID tiket order
   ulong            buy_stop_ticket;
   ulong            sell_stop_ticket;
   datetime         order_place_time;
};

//+------------------------------------------------------------------+
//| Konstanta Sistem                                                 |
//+------------------------------------------------------------------+
#define MAGIC_STRADDLE_OFFSET   10
#define MAGIC_POST_BO_OFFSET    20
#define MAX_NEWS_QUEUE_SIZE     100
