//+------------------------------------------------------------------+
//|                                                 OrderManager.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include "../Core/Defines.mqh"
#include "../Core/Utils.mqh"
#include "../Core/Diagnostics.mqh"

//+------------------------------------------------------------------+
//| Manajer Eksekusi Order, OCO, dan Expiration                      |
//+------------------------------------------------------------------+
class COrderManager
{
private:
   CTrade            m_trade;
   COrderInfo        m_orderInfo;
   CPositionInfo     m_positionInfo;

   string            m_symbol;
   ulong             m_magic;
   int               m_slippagePts;

public:
   COrderManager() : m_symbol(""), m_magic(0), m_slippagePts(30) {}
   ~COrderManager() {}

   void Init(const string symbol, ulong magic, int slippagePts)
   {
      m_symbol      = symbol;
      m_magic       = magic;
      m_slippagePts = slippagePts;

      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetDeviationInPoints(m_slippagePts);
      m_trade.SetTypeFillingBySymbol(m_symbol);
   }

   // Pasang pasangan Buy Stop dan Sell Stop untuk Pre-News Straddle dengan Auto-StopLevel Guard
   bool PlaceStraddleOrders(ulong magic, double distancePts, double slPts, double tpPts, double lot, int expirySec, ulong &outBuyTicket, ulong &outSellTicket, double &outBuyPrice, double &outSellPrice, string comment)
   {
      outBuyTicket  = 0;
      outSellTicket = 0;
      outBuyPrice   = 0;
      outSellPrice  = 0;

      m_trade.SetExpertMagicNumber(magic);

      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double pt  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      // Auto-StopLevel Guard: pastikan jarak order tidak melanggar batasan broker
      long stopLevel   = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      long freezeLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      double minSafePts = (double)MathMax(stopLevel, freezeLevel) + 10.0;

      double effectiveDistPts = MathMax(distancePts, minSafePts);
      if(effectiveDistPts > distancePts)
      {
         CUtils::Log(StringFormat("Auto-StopLevel Guard: Jarak Straddle dinaikkan dari %.0f pts ke %.0f pts (StopLevel: %d, Freeze: %d)",
            distancePts, effectiveDistPts, (int)stopLevel, (int)freezeLevel));
      }

      double buyStopPrice  = CUtils::NormalizePrice(m_symbol, ask + (effectiveDistPts * pt));
      double sellStopPrice = CUtils::NormalizePrice(m_symbol, bid - (effectiveDistPts * pt));

      double effectiveSLPts = (slPts > 0) ? MathMax(slPts, minSafePts) : 0;
      double effectiveTPPts = (tpPts > 0) ? MathMax(tpPts, minSafePts) : 0;

      double buySL  = (effectiveSLPts > 0) ? CUtils::NormalizePrice(m_symbol, buyStopPrice - (effectiveSLPts * pt)) : 0;
      double buyTP  = (effectiveTPPts > 0) ? CUtils::NormalizePrice(m_symbol, buyStopPrice + (effectiveTPPts * pt)) : 0;

      double sellSL = (effectiveSLPts > 0) ? CUtils::NormalizePrice(m_symbol, sellStopPrice + (effectiveSLPts * pt)) : 0;
      double sellTP = (effectiveTPPts > 0) ? CUtils::NormalizePrice(m_symbol, sellStopPrice - (effectiveTPPts * pt)) : 0;

      datetime expiryTime = (expirySec > 0) ? (TimeCurrent() + expirySec) : 0;

      // 1. Eksekusi Buy Stop
      ResetLastError();
      bool buySuccess = m_trade.BuyStop(lot, buyStopPrice, m_symbol, buySL, buyTP, ORDER_TIME_SPECIFIED, expiryTime, comment);
      if(buySuccess)
      {
         outBuyTicket = m_trade.ResultOrder();
         outBuyPrice  = buyStopPrice;
         CUtils::Log(StringFormat("Berhasil pasang Buy Stop di %s (Tiket: %I64u)", DoubleToString(buyStopPrice, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)), outBuyTicket));
      }
      else
      {
         int err = GetLastError();
         CUtils::Log(StringFormat("Gagal pasang Buy Stop: %s (Error: %d)", m_trade.ResultRetcodeDescription(), err));
         CDiagnostics::OnError("Place BuyStop (Straddle)", err, m_trade.ResultRetcodeDescription());
      }

      // 2. Eksekusi Sell Stop
      ResetLastError();
      bool sellSuccess = m_trade.SellStop(lot, sellStopPrice, m_symbol, sellSL, sellTP, ORDER_TIME_SPECIFIED, expiryTime, comment);
      if(sellSuccess)
      {
         outSellTicket = m_trade.ResultOrder();
         outSellPrice  = sellStopPrice;
         CUtils::Log(StringFormat("Berhasil pasang Sell Stop di %s (Tiket: %I64u)", DoubleToString(sellStopPrice, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)), outSellTicket));
      }
      else
      {
         int err = GetLastError();
         CUtils::Log(StringFormat("Gagal pasang Sell Stop: %s (Error: %d)", m_trade.ResultRetcodeDescription(), err));
         CDiagnostics::OnError("Place SellStop (Straddle)", err, m_trade.ResultRetcodeDescription());
      }

      // Rollback atomik jika salah satu gagal dipasang (mencegah order liar / orphan order)
      if(!buySuccess && sellSuccess)
      {
         CUtils::Log("Buy Stop gagal! Melakukan rollback atomik: menghapus Sell Stop pendamping...");
         m_trade.OrderDelete(outSellTicket);
         outSellTicket = 0;
         return false;
      }
      if(buySuccess && !sellSuccess)
      {
         CUtils::Log("Sell Stop gagal! Melakukan rollback atomik: menghapus Buy Stop pendamping...");
         m_trade.OrderDelete(outBuyTicket);
         outBuyTicket = 0;
         return false;
      }

      return (buySuccess && sellSuccess);
   }

   // Pasang pasangan Breakout Stop untuk Post-News Candle Breakout dengan Auto-StopLevel Guard
   bool PlacePostBreakoutOrders(ulong magic, double highPrice, double lowPrice, double bufferPts, double slPts, double tpPts, double lot, int expirySec, ulong &outBuyTicket, ulong &outSellTicket, double &outBuyPrice, double &outSellPrice, string comment)
   {
      outBuyTicket  = 0;
      outSellTicket = 0;
      outBuyPrice   = 0;
      outSellPrice  = 0;

      m_trade.SetExpertMagicNumber(magic);

      double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double pt  = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      long stopLevel   = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
      long freezeLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      double minSafePts = (double)MathMax(stopLevel, freezeLevel) + 10.0;

      double effectiveBufferPts = MathMax(bufferPts, minSafePts);

      double buyStopPrice  = CUtils::NormalizePrice(m_symbol, highPrice + (effectiveBufferPts * pt));
      double sellStopPrice = CUtils::NormalizePrice(m_symbol, lowPrice - (effectiveBufferPts * pt));

      // Guard: Pastikan harga pending order memenuhi minimum distance dari harga pasar saat ini
      if(buyStopPrice < ask + (minSafePts * pt))
      {
         buyStopPrice = CUtils::NormalizePrice(m_symbol, ask + (minSafePts * pt));
      }
      if(sellStopPrice > bid - (minSafePts * pt))
      {
         sellStopPrice = CUtils::NormalizePrice(m_symbol, bid - (minSafePts * pt));
      }

      double effectiveSLPts = (slPts > 0) ? MathMax(slPts, minSafePts) : 0;
      double effectiveTPPts = (tpPts > 0) ? MathMax(tpPts, minSafePts) : 0;

      double buySL  = (effectiveSLPts > 0) ? CUtils::NormalizePrice(m_symbol, buyStopPrice - (effectiveSLPts * pt)) : sellStopPrice;
      double buyTP  = (effectiveTPPts > 0) ? CUtils::NormalizePrice(m_symbol, buyStopPrice + (effectiveTPPts * pt)) : 0;

      double sellSL = (effectiveSLPts > 0) ? CUtils::NormalizePrice(m_symbol, sellStopPrice + (effectiveSLPts * pt)) : buyStopPrice;
      double sellTP = (effectiveTPPts > 0) ? CUtils::NormalizePrice(m_symbol, sellStopPrice - (effectiveTPPts * pt)) : 0;

      datetime expiryTime = (expirySec > 0) ? (TimeCurrent() + expirySec) : 0;

      // Buy Stop Breakout
      ResetLastError();
      bool buySuccess = m_trade.BuyStop(lot, buyStopPrice, m_symbol, buySL, buyTP, ORDER_TIME_SPECIFIED, expiryTime, comment);
      if(buySuccess)
      {
         outBuyTicket = m_trade.ResultOrder();
         outBuyPrice  = buyStopPrice;
         CUtils::Log(StringFormat("Post-News Buy Stop dipasang di %s (Tiket: %I64u)", DoubleToString(buyStopPrice, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)), outBuyTicket));
      }
      else
      {
         int err = GetLastError();
         CUtils::Log(StringFormat("Gagal pasang Post-BO Buy Stop: %s (Error: %d)", m_trade.ResultRetcodeDescription(), err));
         CDiagnostics::OnError("Place BuyStop (Post-BO)", err, m_trade.ResultRetcodeDescription());
      }

      // Sell Stop Breakout
      ResetLastError();
      bool sellSuccess = m_trade.SellStop(lot, sellStopPrice, m_symbol, sellSL, sellTP, ORDER_TIME_SPECIFIED, expiryTime, comment);
      if(sellSuccess)
      {
         outSellTicket = m_trade.ResultOrder();
         outSellPrice  = sellStopPrice;
         CUtils::Log(StringFormat("Post-News Sell Stop dipasang di %s (Tiket: %I64u)", DoubleToString(sellStopPrice, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS)), outSellTicket));
      }
      else
      {
         int err = GetLastError();
         CUtils::Log(StringFormat("Gagal pasang Post-BO Sell Stop: %s (Error: %d)", m_trade.ResultRetcodeDescription(), err));
         CDiagnostics::OnError("Place SellStop (Post-BO)", err, m_trade.ResultRetcodeDescription());
      }

      // Rollback atomik jika salah satu gagal dipasang
      if(!buySuccess && sellSuccess)
      {
         CUtils::Log("Post-Breakout Buy Stop gagal! Melakukan rollback atomik menghapus Sell Stop...");
         m_trade.OrderDelete(outSellTicket);
         outSellTicket = 0;
         return false;
      }
      if(buySuccess && !sellSuccess)
      {
         CUtils::Log("Post-Breakout Sell Stop gagal! Melakukan rollback atomik menghapus Buy Stop...");
         m_trade.OrderDelete(outBuyTicket);
         outBuyTicket = 0;
         return false;
      }

      return (buySuccess && sellSuccess);
   }

   // Manajemen OCO: Jika satu order aktif jadi posisi terbuka, hapus order sisi satunya
   void HandleOCO(ulong &buyTicket, ulong &sellTicket)
   {
      if(buyTicket == 0 && sellTicket == 0)
         return;

      bool buyFilled = IsOrderFilled(buyTicket);
      bool sellFilled = IsOrderFilled(sellTicket);

      // Jika Buy Stop sudah terpicu dan menjadi posisi terbuka
      if(buyFilled && sellTicket > 0)
      {
         ulong deletedTicket = sellTicket;
         CUtils::Log(StringFormat("OCO Triggered! Buy Stop (Tiket: %I64u) aktif. Menghapus Sell Stop (Tiket: %I64u)...", buyTicket, sellTicket));
         CancelPendingOrder(sellTicket);
         sellTicket = 0;
         CDiagnostics::OnOCO(buyTicket, deletedTicket);
      }
      // Jika Sell Stop sudah terpicu dan menjadi posisi terbuka
      else if(sellFilled && buyTicket > 0)
      {
         ulong deletedTicket = buyTicket;
         CUtils::Log(StringFormat("OCO Triggered! Sell Stop (Tiket: %I64u) aktif. Menghapus Buy Stop (Tiket: %I64u)...", sellTicket, buyTicket));
         CancelPendingOrder(buyTicket);
         buyTicket = 0;
         CDiagnostics::OnOCO(sellTicket, deletedTicket);
      }
   }

   // Batalkan pending order jika kadaluarsa
   void CancelIfExpired(ulong &ticket, int expirySec, datetime placeTime)
   {
      if(ticket == 0)
         return;

      if(TimeCurrent() - placeTime >= expirySec)
      {
         CUtils::Log(StringFormat("Pending order (Tiket: %I64u) kadaluarsa setelah %d detik. Membatalkan...", ticket, expirySec));
         CancelPendingOrder(ticket);
         ticket = 0;
      }
   }

   // Hapus pending order berdasarkan tiket
   bool CancelPendingOrder(ulong ticket)
   {
      if(ticket == 0)
         return false;

      if(m_orderInfo.Select(ticket))
      {
         ENUM_ORDER_STATE state = m_orderInfo.State();
         if(state == ORDER_STATE_PLACED || state == ORDER_STATE_STARTED)
         {
            bool res = m_trade.OrderDelete(ticket);
            if(!res)
            {
               CDiagnostics::OnError("CancelPendingOrder", GetLastError(), StringFormat("Gagal menghapus order #%I64u", ticket));
            }
            return res;
         }
      }
      return false;
   }

   // Cek apakah order sudah tereksekusi menjadi deal / posisi
   bool IsOrderFilled(ulong ticket)
   {
      if(ticket == 0)
         return false;

      // Cek apakah ada posisi dengan identifier tiket ini
      if(m_positionInfo.SelectByTicket(ticket))
         return true;

      // Cek riwayat order
      if(HistoryOrderSelect(ticket))
      {
         ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE);
         if(state == ORDER_STATE_FILLED || state == ORDER_STATE_PARTIAL)
            return true;
      }

      return false;
   }

   // Cek apakah ada pending order aktif dengan magic tertentu
   bool HasPendingOrders(ulong magic)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(m_orderInfo.SelectByIndex(i))
         {
            if(m_orderInfo.Symbol() == m_symbol && m_orderInfo.Magic() == magic)
               return true;
         }
      }
      return false;
   }

   // Cek apakah ada posisi terbuka aktif dengan magic tertentu
   bool HasOpenPositions(ulong magic)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(m_positionInfo.SelectByIndex(i))
         {
            if(m_positionInfo.Symbol() == m_symbol && m_positionInfo.Magic() == magic)
               return true;
         }
      }
      return false;
   }

   // Pemulihan tiket pending order dari server MT5 saat startup/reconnect
   void RecoverActiveOrders(ulong magic, ulong &outBuyTicket, ulong &outSellTicket)
   {
      outBuyTicket = 0;
      outSellTicket = 0;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(m_orderInfo.SelectByIndex(i))
         {
            if(m_orderInfo.Symbol() == m_symbol && m_orderInfo.Magic() == magic)
            {
               ENUM_ORDER_TYPE oType = m_orderInfo.OrderType();
               if(oType == ORDER_TYPE_BUY_STOP)
                  outBuyTicket = m_orderInfo.Ticket();
               else if(oType == ORDER_TYPE_SELL_STOP)
                  outSellTicket = m_orderInfo.Ticket();
            }
         }
      }
      if(outBuyTicket > 0 || outSellTicket > 0)
      {
         CUtils::Log(StringFormat("Order aktif berhasil dipulihkan dari terminal: Buy #%I64u, Sell #%I64u", outBuyTicket, outSellTicket));
      }
   }
};
