//+------------------------------------------------------------------+
//|                                                       Config.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| PARAMETER INPUT UTAMA                                            |
//+------------------------------------------------------------------+
sinput string   Group_General        = "========== GENERAL SETTINGS =========="; // [PENGATURAN UMUM]
input string    InpEAName            = "edNewsTraderPro";       // Nama EA / Komentar Order
input ulong     InpMagicNumber       = 889900;                  // Magic Number Unik
input ENUM_STRATEGY_TYPE InpStrategyType = STRAT_POST_BREAKOUT_ONLY; // Mode Strategi News (Default: Post-Breakout Lebih Aman)
input ENUM_NEWS_SOURCE   InpNewsSource   = NEWS_SRC_HYBRID;     // Sumber Kalender Berita

sinput string   Group_NewsFilter     = "========== NEWS CALENDAR FILTER =========="; // [FILTER KALENDER BERITA]
input string    InpFilterCurrencies  = "USD,EUR,GBP,JPY";       // Filter Mata Uang (Pisahkan Koma)
input ENUM_NEWS_IMPACT InpMinImpact  = IMPACT_HIGH;             // Minimum Dampak Berita
input int       InpLookAheadHours    = 24;                      // Lookahead Kalender (Jam ke Depan)
input string    InpManualNewsCSV     = "news_calendar_3years.csv"; // Manual Jadwal Berita (File CSV / Format YYYY.MM.DD HH:MM)
input int       InpCalendarUpdateMin = 15;                      // Interval Refresh Kalender MT5 (Menit)

sinput string   Group_Straddle       = "========== PRE-NEWS STRADDLE SETTINGS =========="; // [STRATEGI 1: PRE-NEWS STRADDLE]
input int       InpStraddleLeadSec   = 90;                      // Detik Sebelum Rilis untuk Pasang Pending Order
input int       InpStraddleDistancePts = 180;                   // Jarak Pending Order dari Harga Running (Points)
input bool      InpStraddleOCO       = true;                    // Aktifkan OCO (One Cancels Other)
input int       InpStraddleExpirySec = 300;                     // Hapus Pending Jika Tidak Tembus (Detik Pasca Rilis)

sinput string   Group_PostNews       = "========== POST-NEWS BREAKOUT SETTINGS =========="; // [STRATEGI 2: POST-NEWS BREAKOUT]
input int       InpPostNewsWaitSec   = 60;                      // Detik Pasca Rilis untuk Menunggu Spread Normal
input ENUM_TIMEFRAMES InpPostNewsCandleTF = PERIOD_M1;          // Timeframe untuk Mengukur High/Low Candle Rilis
input int       InpPostNewsBufferPts = 30;                      // Tambahan Buffer di Atas High / di Bawah Low (Points)
input int       InpPostNewsExpirySec = 600;                     // Expirasi Pending Order Post-Breakout (Detik)

sinput string   Group_Risk           = "========== RISK & MONEY MANAGEMENT =========="; // [MANAJEMEN RISIKO]
input bool      InpUseRiskPercent    = false;                   // Gunakan Auto Lot Berbasis Risiko (%)
input double    InpRiskPercent       = 1.0;                     // Risiko per Transaksi (% Saldo)
input double    InpFixedLot          = 0.10;                    // Lot Tetap (Jika Auto Lot False)
input int       InpMaxSpreadPts      = 35;                      // Maksimum Spread Diizinkan (Points)
input int       InpMaxSlippagePts    = 30;                      // Maksimum Toleransi Slippage (Points)

sinput string   Group_ATR            = "========== ATR DYNAMIC SL & TP =========="; // [SL & TP BERBASIS ATR]
input bool      InpUseATR            = false;                   // Aktifkan SL & TP Berbasis ATR (true = ATR, false = Fixed Points)
input ENUM_TIMEFRAMES InpATRTimeframe= PERIOD_M15;              // Timeframe Indikator ATR
input int       InpATRPeriod         = 14;                      // Periode Indikator ATR
input double    InpATRMultiplierSL   = 1.2;                     // Pengali ATR untuk Stop Loss (SL = ATR * Multiplier)
input double    InpATRMultiplierTP   = 2.8;                     // Pengali ATR untuk Take Profit (TP = ATR * Multiplier)

sinput string   Group_FixedSLTP      = "========== FIXED SL & TP (FALLBACK) =========="; // [SL & TP TETAP (JIKA ATR NONAKTIF)]
input int       InpStopLossPts       = 150;                     // Stop Loss Tetap (Points, jika InpUseATR = false)
input int       InpTakeProfitPts     = 350;                     // Take Profit Tetap (Points, jika InpUseATR = false)

sinput string   Group_Trailing       = "========== BREAKEVEN & TRAILING STOP =========="; // [BREAKEVEN & TRAILING STOP]
input bool      InpUseBreakeven      = true;                    // Aktifkan Breakeven (BEP)
input int       InpBEPTriggerPts     = 60;                      // Jarak Profit untuk Pindah SL ke BEP (Points, 60 = 6 pips)
input int       InpBEPLockPts        = 15;                      // Kunci Profit Saat BEP (Points, 15 = 1.5 pips)
input bool      InpUseTrailing       = true;                    // Aktifkan Trailing Stop
input int       InpTrailPts          = 100;                     // Jarak Trailing Stop (Points, 100 = 10 pips)
input int       InpTrailStepPts      = 25;                      // Langkah Trailing Step (Points)

sinput string   Group_TimeExit       = "========== TIME-BASED AUTO EXIT =========="; // [AUTO CLOSE SETELAH MOMENTUM HABIS]
input bool      InpUseTimeExit       = true;                    // Tutup Posisi Jika Waktu Tahan Terlewati
input int       InpMaxHoldMinutes    = 180;                     // Maksimum Waktu Tahan Posisi (Menit, 180 = 3 Jam)

sinput string   Group_Display        = "========== ON-CHART DASHBOARD =========="; // [TAMPILAN PANEL]
input bool      InpShowDashboard     = true;                    // Tampilkan Info Panel di Chart
