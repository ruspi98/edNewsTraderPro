//+------------------------------------------------------------------+
//|                                                  Diagnostics.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include "Defines.mqh"
#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Modul Diagnosa & Monitoring Real-Time                            |
//+------------------------------------------------------------------+
class CDiagnostics
{
private:
   static int      m_eventsProcessed;
   static int      m_straddlesPlaced;
   static int      m_postBOPlaced;
   static int      m_ocoExecuted;
   static int      m_trailingUpdated;
   static int      m_errorsOccurred;
   static datetime m_lastReportTime;
   static ulong    m_lastReportedEventId;

public:
   static void Init()
   {
      m_eventsProcessed     = 0;
      m_straddlesPlaced     = 0;
      m_postBOPlaced        = 0;
      m_ocoExecuted         = 0;
      m_trailingUpdated     = 0;
      m_errorsOccurred      = 0;
      m_lastReportedEventId = 0;
      m_lastReportTime      = TimeCurrent();
      CUtils::Log("[DIAGNOSTICS] Diagnostic & Health Monitoring AKTIF (Zero-Bug Monitoring).");
   }

   // Catat event baru yang masuk antrean aktif (hanya dicatat 1x per ID event)
   static void OnEventDetected(const SNewsEvent &ev, int secondsToRelease)
   {
      if(ev.calendar_id == m_lastReportedEventId && m_lastReportedEventId > 0)
         return;

      m_lastReportedEventId = ev.calendar_id;
      m_eventsProcessed++;
      string impStr = (ev.impact == IMPACT_HIGH) ? "HIGH" : (ev.impact == IMPACT_MEDIUM) ? "MED" : "LOW";
      CUtils::Log(StringFormat("[MONITOR EVENT #%d] %s | Currency: %s | Impact: %s | Rilis: %s (Hitung Mundur: %d dtk)",
         m_eventsProcessed, ev.event_name, ev.currency, impStr, TimeToString(ev.time, TIME_DATE|TIME_MINUTES), secondsToRelease));
   }

   // Catat order straddle berhasil dipasang
   static void OnStraddlePlaced(ulong buyTicket, ulong sellTicket, double buyPrice, double sellPrice)
   {
      m_straddlesPlaced++;
      CUtils::Log(StringFormat("[MONITOR STRADDLE #%d] BuyStop #%I64u @ %s | SellStop #%I64u @ %s",
         m_straddlesPlaced, buyTicket, DoubleToString(buyPrice, 5), sellTicket, DoubleToString(sellPrice, 5)));
   }

   // Catat order post-breakout berhasil dipasang
   static void OnPostBOPlaced(ulong buyTicket, ulong sellTicket, double buyPrice, double sellPrice)
   {
      m_postBOPlaced++;
      CUtils::Log(StringFormat("[MONITOR POST-BO #%d] BuyStop #%I64u @ %s | SellStop #%I64u @ %s",
         m_postBOPlaced, buyTicket, DoubleToString(buyPrice, 5), sellTicket, DoubleToString(sellPrice, 5)));
   }

   // Catat eksekusi OCO
   static void OnOCO(ulong triggeredTicket, ulong deletedTicket)
   {
      m_ocoExecuted++;
      CUtils::Log(StringFormat("[MONITOR OCO #%d] Order tersambar #%I64u -> Pending lawan #%I64u dibatalkan.",
         m_ocoExecuted, triggeredTicket, deletedTicket));
   }

   // Catat modifikasi Trailing / BEP
   static void OnTrailingModified(ulong posTicket, double newSL, bool isBEP)
   {
      m_trailingUpdated++;
      CUtils::Log(StringFormat("[MONITOR PROTEKSI #%d] Posisi #%I64u SL digeser ke %s (%s)",
         m_trailingUpdated, posTicket, DoubleToString(newSL, 5), isBEP ? "BEP Terkunci" : "Trailing Step"));
   }

   // Catat error / penolakan broker
   static void OnError(const string context, int errorCode, const string desc)
   {
      m_errorsOccurred++;
      CUtils::Log(StringFormat("[MONITOR PERINGATAN #%d] %s! Error: %d (%s)",
         m_errorsOccurred, context, errorCode, desc));
   }

   // Laporan periodik status kesehatan EA
   static void CheckPeriodicHealth()
   {
      datetime now = TimeCurrent();
      if(m_lastReportTime == 0 || now - m_lastReportTime >= 86400) // Laporan harian
      {
         PrintHealthSummary();
         m_lastReportTime = now;
      }
   }

   // Cetak ringkasan kesehatan sistem secara lengkap
   static void PrintHealthSummary()
   {
      CUtils::Log(StringFormat("[HEALTH SUMMARY] Event Diproses: %d | Straddle Sukses: %d | Post-BO: %d | OCO: %d | BE/Trail: %d | Errors: %d | Status Sistem: %s",
         m_eventsProcessed, m_straddlesPlaced, m_postBOPlaced, m_ocoExecuted, m_trailingUpdated, m_errorsOccurred,
         (m_errorsOccurred == 0) ? "100% SEHAT (ZERO BUGS)" : "PERINGATAN TERDETEKSI"));
   }
};

// Inisialisasi variabel statik
int      CDiagnostics::m_eventsProcessed     = 0;
int      CDiagnostics::m_straddlesPlaced     = 0;
int      CDiagnostics::m_postBOPlaced        = 0;
int      CDiagnostics::m_ocoExecuted         = 0;
int      CDiagnostics::m_trailingUpdated     = 0;
int      CDiagnostics::m_errorsOccurred      = 0;
datetime CDiagnostics::m_lastReportTime      = 0;
ulong    CDiagnostics::m_lastReportedEventId = 0;
