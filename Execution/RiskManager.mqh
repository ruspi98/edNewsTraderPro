//+------------------------------------------------------------------+
//|                                                  RiskManager.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include "../Core/Utils.mqh"
#include "../Config/Config.mqh"

//+------------------------------------------------------------------+
//| Manajer Proteksi Risiko, ATR Dinamis, & Kalkulasi Lot            |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   string m_symbol;
   int    m_atrHandle;

public:
   CRiskManager() : m_symbol(""), m_atrHandle(INVALID_HANDLE) {}
   ~CRiskManager()
   {
      if(m_atrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
      }
   }

   void Init(const string symbol)
   {
      m_symbol = symbol;

      if(m_atrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
      }

      if(InpUseATR)
      {
         m_atrHandle = iATR(m_symbol, InpATRTimeframe, InpATRPeriod);
         if(m_atrHandle == INVALID_HANDLE)
         {
            CUtils::Log(StringFormat("PERINGATAN: Gagal membuat indikator ATR untuk %s! Error: %d", m_symbol, GetLastError()));
         }
         else
         {
            CUtils::Log(StringFormat("Indikator ATR (%s, TF: %s, Periode: %d) aktif untuk SL & TP dinamis.",
               m_symbol, EnumToString(InpATRTimeframe), InpATRPeriod));
         }
      }
   }

   // Periksa apakah spread saat ini aman (di bawah batas toleransi)
   bool IsSpreadAllowed(int maxSpreadPts)
   {
      long currentSpread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
      if(maxSpreadPts > 0 && currentSpread > maxSpreadPts)
      {
         CUtils::Log(StringFormat("Eksekusi dibatalkan! Spread melebar: %d pts > Max: %d pts", (int)currentSpread, maxSpreadPts));
         return false;
      }
      return true;
   }

   // Ambil spread saat ini
   long GetCurrentSpread()
   {
      return SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
   }

   // Ambil nilai ATR saat ini dan konversi ke satuan points
   double GetATRPoints()
   {
      if(m_atrHandle == INVALID_HANDLE)
         return 0;

      double buffer[];
      ArraySetAsSeries(buffer, true);
      // Baca bar close terakhir (bar 1) untuk nilai stabil tanpa repainting
      if(CopyBuffer(m_atrHandle, 0, 1, 1, buffer) <= 0)
         return 0;

      double pt = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(pt <= 0)
         return 0;

      return (buffer[0] / pt);
   }

   // Ambil Stop Loss dalam Points (Dinamis ATR atau Fixed)
   double GetStopLossPoints()
   {
      if(InpUseATR)
      {
         double atrPts = GetATRPoints();
         if(atrPts > 0)
         {
            double slPts = MathRound(atrPts * InpATRMultiplierSL);
            return MathMax(slPts, 10.0);
         }
      }
      return (double)InpStopLossPts;
   }

   // Ambil Take Profit dalam Points (Dinamis ATR atau Fixed)
   double GetTakeProfitPoints()
   {
      if(InpUseATR)
      {
         double atrPts = GetATRPoints();
         if(atrPts > 0)
         {
            double tpPts = MathRound(atrPts * InpATRMultiplierTP);
            return MathMax(tpPts, 10.0);
         }
      }
      return (double)InpTakeProfitPts;
   }

   // Ambil ringkasan mode SL & TP saat ini untuk Dashboard & Log
   string GetSLTPDescription()
   {
      if(InpUseATR)
      {
         double atrPts = GetATRPoints();
         return StringFormat("ATR %.0f pts (SL: %.0f, TP: %.0f)", atrPts, GetStopLossPoints(), GetTakeProfitPoints());
      }
      return StringFormat("Fixed (SL: %d, TP: %d)", InpStopLossPts, InpTakeProfitPts);
   }

   // Kalkulasi ukuran lot yang aman berbasis Stop Loss aktual
   double CalculateLotSize(double slPoints)
   {
      double minLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot  = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

      if(!InpUseRiskPercent)
      {
         // Gunakan lot tetap
         double lot = InpFixedLot;
         lot = MathMax(minLot, MathMin(maxLot, lot));
         return NormalizeDouble(lot, 2);
      }

      // Hitung lot dinamis berdasarkan risiko persentase saldo
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * (InpRiskPercent / 100.0);

      double tickSize  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double point     = SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      if(tickSize <= 0 || tickValue <= 0 || point <= 0 || slPoints <= 0)
      {
         return minLot;
      }

      double moneyLossPerLot = (slPoints * point / tickSize) * tickValue;
      if(moneyLossPerLot <= 0)
         return minLot;

      double rawLot = riskMoney / moneyLossPerLot;
      
      // Pembulatan ke kelipatan lotStep terdekat
      double steps = MathFloor(rawLot / lotStep);
      double calculatedLot = steps * lotStep;

      calculatedLot = MathMax(minLot, MathMin(maxLot, calculatedLot));
      return NormalizeDouble(calculatedLot, 2);
   }
};
