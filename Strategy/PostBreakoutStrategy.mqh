//+------------------------------------------------------------------+
//|                                         PostBreakoutStrategy.mqh |
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
//| Strategi 2: Post-News Candle Range Breakout (M1/M5 Momentum)     |
//+------------------------------------------------------------------+
class CPostBreakoutStrategy : public IStrategy
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
   CPostBreakoutStrategy() : m_symbol(""), m_magic(0), m_orderMgr(NULL), m_riskMgr(NULL),
                             m_activeBuyTicket(0), m_activeSellTicket(0), m_placeTime(0), m_currentEventId(0) {}
   virtual ~CPostBreakoutStrategy() {}

   virtual bool Init(const string symbol, ulong magic, COrderManager *orderMgr, CRiskManager *riskMgr) override
   {
      m_symbol   = symbol;
      m_magic    = magic + MAGIC_POST_BO_OFFSET;
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
      return "Post-News Candle Breakout";
   }

   virtual void OnTimerUpdate(SNewsEvent &currentNews, int secondsToNews) override
   {
      // Validasi event berita dan pastikan belum ada order aktif
      if(currentNews.time <= 0 || currentNews.post_breakout_triggered || m_activeBuyTicket > 0 || m_activeSellTicket > 0)
         return;

      // Cek apakah sudah melewati waktu tunggu pasca rilis (contoh: 60 detik setelah berita)
      // secondsToNews bernilai negatif saat waktu sekarang sudah melewati news.time
      int secondsPassed = -secondsToNews;
      if(secondsPassed >= InpPostNewsWaitSec && secondsPassed <= (InpPostNewsWaitSec + 120))
      {
         // 1. Cek proteksi spread (memastikan spread sudah normal pasca spike rilis)
         if(!m_riskMgr.IsSpreadAllowed(InpMaxSpreadPts))
         {
            CUtils::Log(StringFormat("[%s] Post-News menunggu spread normal... (%d pts > %d pts)",
               m_symbol, (int)m_riskMgr.GetCurrentSpread(), InpMaxSpreadPts));
            return;
         }

         // 2. Ambil High dan Low candle rilis berita
         datetime newsStartTime = currentNews.time;
         datetime newsEndTime   = TimeCurrent();

         MqlRates rates[];
         ArraySetAsSeries(rates, true);
         int copied = CopyRates(m_symbol, InpPostNewsCandleTF, newsStartTime, newsEndTime, rates);
         if(copied <= 0)
         {
            CUtils::Log(StringFormat("[%s] Gagal membaca data rates candle rilis berita.", m_symbol));
            return;
         }

         double highestPrice = rates[0].high;
         double lowestPrice  = rates[0].low;

         for(int i = 1; i < copied; i++)
         {
            if(rates[i].high > highestPrice) highestPrice = rates[i].high;
            if(rates[i].low < lowestPrice)   lowestPrice  = rates[i].low;
         }

         // Validasi harga running saat ini tidak melanggar stops level
         double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         double pt  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         long stopLvl = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
         long freezeLvl = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
         double minDist = MathMax(stopLvl, freezeLvl) * pt;

         double plannedBuyPrice  = CUtils::NormalizePrice(m_symbol, highestPrice + (InpPostNewsBufferPts * pt));
         double plannedSellPrice = CUtils::NormalizePrice(m_symbol, lowestPrice - (InpPostNewsBufferPts * pt));

         if(plannedBuyPrice <= ask + minDist || plannedSellPrice >= bid - minDist)
         {
            CUtils::Log(StringFormat("[%s] Harga running sudah melampaui rentang candle rilis [%s - %s]. Melewati setup Post-Breakout untuk mencegah fakeout...",
               m_symbol, DoubleToString(lowestPrice, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)),
               DoubleToString(highestPrice, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS))));
            currentNews.post_breakout_triggered = true;
            return;
         }

         // 3. Ambil SL & TP dinamis (ATR / Fixed) dan hitung lot
         double slPts = m_riskMgr.GetStopLossPoints();
         double tpPts = m_riskMgr.GetTakeProfitPoints();
         double lot   = m_riskMgr.CalculateLotSize(slPts);

         // 4. Pasang pending order breakout High / Low
         ulong buyTicket = 0, sellTicket = 0;
         double buyPrice = 0, sellPrice = 0;
         string comment = StringFormat("%s-POSTBO", InpEAName);

         bool success = m_orderMgr.PlacePostBreakoutOrders(
            m_magic,
            highestPrice,
            lowestPrice,
            (double)InpPostNewsBufferPts,
            slPts,
            tpPts,
            lot,
            InpPostNewsExpirySec,
            buyTicket,
            sellTicket,
            buyPrice,
            sellPrice,
            comment
         );

         if(success)
         {
            m_activeBuyTicket                   = buyTicket;
            m_activeSellTicket                  = sellTicket;
            m_placeTime                         = TimeCurrent();
            m_currentEventId                    = currentNews.calendar_id;
            currentNews.post_breakout_triggered = true;
            currentNews.buy_stop_ticket         = buyTicket;
            currentNews.sell_stop_ticket        = sellTicket;

            CDiagnostics::OnPostBOPlaced(buyTicket, sellTicket, buyPrice, sellPrice);
            CUtils::Log(StringFormat("Post-News Breakout sukses dipasang untuk [%s %s]! Range High: %s, Low: %s",
               currentNews.currency, currentNews.event_name,
               DoubleToString(highestPrice, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)),
               DoubleToString(lowestPrice, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS))));
         }
      }
      else if(secondsPassed > (InpPostNewsWaitSec + 120))
      {
         // Waktu jendela pasca-rilis telah berlalu
         currentNews.post_breakout_triggered = true;
      }
   }

   virtual void OnTickUpdate() override
   {
      // 1. OCO logic
      if(m_activeBuyTicket > 0 || m_activeSellTicket > 0)
      {
         m_orderMgr.HandleOCO(m_activeBuyTicket, m_activeSellTicket);
      }

      // 2. Expirasi
      if(m_activeBuyTicket > 0 || m_activeSellTicket > 0)
      {
         m_orderMgr.CancelIfExpired(m_activeBuyTicket, InpPostNewsExpirySec, m_placeTime);
         m_orderMgr.CancelIfExpired(m_activeSellTicket, InpPostNewsExpirySec, m_placeTime);
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
