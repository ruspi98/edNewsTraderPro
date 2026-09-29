//+------------------------------------------------------------------+
//|                                             StraddleStrategy.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include "IStrategy.mqh"
#include "../Config/Config.mqh"
#include "../Core/Utils.mqh"
#include "../Core/Diagnostics.mqh"

//+------------------------------------------------------------------+
//| Strategi 1: Pre-News Straddle Breakout (Pending Buy/Sell Stop)   |
//+------------------------------------------------------------------+
class CStraddleStrategy : public IStrategy
{
private:
   string         m_symbol;
   ulong          m_magic;
   COrderManager *m_orderMgr;
   CRiskManager  *m_riskMgr;

   ulong          m_activeBuyTicket;
   ulong          m_activeSellTicket;
   datetime       m_placeTime;
   ulong          m_currentEventId;

public:
   CStraddleStrategy() : m_symbol(""), m_magic(0), m_orderMgr(NULL), m_riskMgr(NULL),
                         m_activeBuyTicket(0), m_activeSellTicket(0), m_placeTime(0), m_currentEventId(0) {}
   virtual ~CStraddleStrategy() {}

   virtual bool Init(const string symbol, ulong magic, COrderManager *orderMgr, CRiskManager *riskMgr) override
   {
      m_symbol   = symbol;
      m_magic    = magic + MAGIC_STRADDLE_OFFSET;
      m_orderMgr = orderMgr;
      m_riskMgr  = riskMgr;
      if(m_orderMgr != NULL)
      {
         m_orderMgr.RecoverActiveOrders(m_magic, m_activeBuyTicket, m_activeSellTicket);
      }
      return (m_orderMgr != NULL && m_riskMgr != NULL);
   }

   virtual string GetStrategyName() const override
   {
      return "Pre-News Straddle Breakout";
   }

   virtual void OnTimerUpdate(SNewsEvent &currentNews, int secondsToNews) override
   {
      // Validasi event berita dan pastikan belum ada order aktif
      if(currentNews.time <= 0 || currentNews.straddle_triggered || m_activeBuyTicket > 0 || m_activeSellTicket > 0)
         return;

      // Cek apakah sudah memasuki jendela waktu pasang pending order (contoh: 90 detik sebelum rilis)
      if(secondsToNews <= InpStraddleLeadSec && secondsToNews >= 0)
      {
         // 1. Cek proteksi spread
         if(!m_riskMgr.IsSpreadAllowed(InpMaxSpreadPts))
         {
            CUtils::Log(StringFormat("[%s] Menunggu spread stabil sebelum memasang Straddle... (Sisa waktu: %d detik)", m_symbol, secondsToNews));
            return;
         }

         // 2. Ambil SL & TP dinamis (ATR / Fixed) dan hitung lot
         double slPts = m_riskMgr.GetStopLossPoints();
         double tpPts = m_riskMgr.GetTakeProfitPoints();
         double lot   = m_riskMgr.CalculateLotSize(slPts);

         // 3. Pasang pasangan Buy Stop & Sell Stop
         ulong buyTicket = 0, sellTicket = 0;
         double buyPrice = 0, sellPrice = 0;
         string comment = StringFormat("%s-STRAD", InpEAName);

         bool success = m_orderMgr.PlaceStraddleOrders(
            m_magic,
            (double)InpStraddleDistancePts,
            slPts,
            tpPts,
            lot,
            InpStraddleExpirySec + InpStraddleLeadSec,
            buyTicket,
            sellTicket,
            buyPrice,
            sellPrice,
            comment
         );

         if(success)
         {
            m_activeBuyTicket              = buyTicket;
            m_activeSellTicket             = sellTicket;
            m_placeTime                    = TimeCurrent();
            m_currentEventId               = currentNews.calendar_id;
            currentNews.straddle_triggered = true;
            currentNews.buy_stop_ticket    = buyTicket;
            currentNews.sell_stop_ticket   = sellTicket;

            CDiagnostics::OnStraddlePlaced(buyTicket, sellTicket, buyPrice, sellPrice);
            CUtils::Log(StringFormat("Straddle sukses dipasang menjelang berita [%s %s]! Buy: %I64u, Sell: %I64u",
               currentNews.currency, currentNews.event_name, buyTicket, sellTicket));
         }
      }
   }

   virtual void OnTickUpdate() override
   {
      // 1. OCO (One Cancels Other): Hapus sisi lawan jika salah satu order tereksekusi
      if(InpStraddleOCO && (m_activeBuyTicket > 0 || m_activeSellTicket > 0))
      {
         m_orderMgr.HandleOCO(m_activeBuyTicket, m_activeSellTicket);
      }

      // 2. Expirasi: Batalkan order jika melewati batas waktu setelah berita
      if(m_activeBuyTicket > 0 || m_activeSellTicket > 0)
      {
         m_orderMgr.CancelIfExpired(m_activeBuyTicket, InpStraddleExpirySec + InpStraddleLeadSec, m_placeTime);
         m_orderMgr.CancelIfExpired(m_activeSellTicket, InpStraddleExpirySec + InpStraddleLeadSec, m_placeTime);
      }

      // 3. Sinkronisasi state: jika tidak ada pending order dan tidak ada posisi aktif, reset tiket ke 0
      if(m_activeBuyTicket > 0 || m_activeSellTicket > 0)
      {
         if(!m_orderMgr.HasPendingOrders(m_magic) && !m_orderMgr.HasOpenPositions(m_magic))
         {
            m_activeBuyTicket  = 0;
            m_activeSellTicket = 0;
         }
      }
   }

   virtual void OnDeinit() override
   {
      // Hapus sisa pending order jika EA di-remove
      if(m_activeBuyTicket > 0)
      {
         m_orderMgr.CancelPendingOrder(m_activeBuyTicket);
         m_activeBuyTicket = 0;
      }
      if(m_activeSellTicket > 0)
      {
         m_orderMgr.CancelPendingOrder(m_activeSellTicket);
         m_activeSellTicket = 0;
      }
   }
};
