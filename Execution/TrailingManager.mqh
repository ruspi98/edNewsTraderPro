//+------------------------------------------------------------------+
//|                                              TrailingManager.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include "../Config/Config.mqh"
#include "../Core/Utils.mqh"
#include "../Core/Diagnostics.mqh"

//+------------------------------------------------------------------+
//| Manajer Breakeven dan Trailing Stop Dinamis                      |
//+------------------------------------------------------------------+
class CTrailingManager
{
private:
   CTrade        m_trade;
   CPositionInfo m_positionInfo;
   string        m_symbol;
   ulong         m_magic;

public:
   CTrailingManager() : m_symbol(""), m_magic(0) {}
   ~CTrailingManager() {}

   void Init(const string symbol, ulong magic)
   {
      m_symbol = symbol;
      m_magic  = magic;
      m_trade.SetExpertMagicNumber(m_magic);
   }

   // Update Breakeven dan Trailing Stop untuk semua posisi aktif EA
   void Update()
   {
      if(!InpUseBreakeven && !InpUseTrailing && !InpUseTimeExit)
         return;

      int total = PositionsTotal();
      for(int i = total - 1; i >= 0; i--)
      {
         if(!m_positionInfo.SelectByIndex(i))
            continue;

         // Validasi symbol dan magic number
         if(m_positionInfo.Symbol() != m_symbol)
            continue;

         ulong posMagic = m_positionInfo.Magic();
         if(posMagic != m_magic && 
            posMagic != (m_magic + MAGIC_STRADDLE_OFFSET) && 
            posMagic != (m_magic + MAGIC_POST_BO_OFFSET))
            continue;

         ulong ticket       = m_positionInfo.Ticket();
         ENUM_POSITION_TYPE type = m_positionInfo.PositionType();
         double openPrice   = m_positionInfo.PriceOpen();
         double currentSL   = m_positionInfo.StopLoss();
         double currentTP   = m_positionInfo.TakeProfit();
         double currentPrice= m_positionInfo.PriceCurrent();
         double pt          = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
         long stopLevel     = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
         long freezeLevel   = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL);
         double minDist     = MathMax(stopLevel, freezeLevel) * pt;

         // 0. Logika Time-Based Auto Exit (Tutup otomatis jika momentum berita sudah habis)
         if(InpUseTimeExit && InpMaxHoldMinutes > 0)
         {
            datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
            if(posTime > 0 && (TimeCurrent() - posTime) >= (InpMaxHoldMinutes * 60))
            {
               ResetLastError();
               if(m_trade.PositionClose(ticket))
               {
                  CUtils::Log(StringFormat("Time-Exit: Posisi #%I64u ditutup otomatis setelah bertahan %d menit.", ticket, InpMaxHoldMinutes));
                  continue;
               }
            }
         }

         // 1. Logika Breakeven (BEP)
         if(InpUseBreakeven)
         {
            if(type == POSITION_TYPE_BUY)
            {
               double profitPts = (currentPrice - openPrice) / pt;
               if(profitPts >= InpBEPTriggerPts)
               {
                  double newSL = CUtils::NormalizePrice(m_symbol, openPrice + (InpBEPLockPts * pt));
                  if(currentPrice - newSL >= minDist && currentSL < newSL)
                  {
                     ResetLastError();
                     if(m_trade.PositionModify(ticket, newSL, currentTP))
                     {
                        CUtils::Log(StringFormat("Breakeven Buy terkunci! Posisi #%I64u SL digeser ke %s", ticket, DoubleToString(newSL, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS))));
                        CDiagnostics::OnTrailingModified(ticket, newSL, true);
                        currentSL = newSL;
                     }
                     else
                     {
                        CDiagnostics::OnError("PositionModify (BEP Buy)", GetLastError(), m_trade.ResultRetcodeDescription());
                     }
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               double profitPts = (openPrice - currentPrice) / pt;
               if(profitPts >= InpBEPTriggerPts)
               {
                  double newSL = CUtils::NormalizePrice(m_symbol, openPrice - (InpBEPLockPts * pt));
                  if(newSL - currentPrice >= minDist && (currentSL == 0 || currentSL > newSL))
                  {
                     ResetLastError();
                     if(m_trade.PositionModify(ticket, newSL, currentTP))
                     {
                        CUtils::Log(StringFormat("Breakeven Sell terkunci! Posisi #%I64u SL digeser ke %s", ticket, DoubleToString(newSL, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS))));
                        CDiagnostics::OnTrailingModified(ticket, newSL, true);
                        currentSL = newSL;
                     }
                     else
                     {
                        CDiagnostics::OnError("PositionModify (BEP Sell)", GetLastError(), m_trade.ResultRetcodeDescription());
                     }
                  }
               }
            }
         }

         // 2. Logika Trailing Stop
         if(InpUseTrailing)
         {
            if(type == POSITION_TYPE_BUY)
            {
               double profitPts = (currentPrice - openPrice) / pt;
               if(profitPts >= InpTrailPts)
               {
                  double targetSL = CUtils::NormalizePrice(m_symbol, currentPrice - (InpTrailPts * pt));
                  if(currentPrice - targetSL >= minDist && targetSL > openPrice && (currentSL == 0 || targetSL - currentSL >= InpTrailStepPts * pt))
                  {
                     ResetLastError();
                     if(m_trade.PositionModify(ticket, targetSL, currentTP))
                     {
                        CUtils::Log(StringFormat("Trailing Stop Buy #%I64u dipindahkan ke %s", ticket, DoubleToString(targetSL, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS))));
                        CDiagnostics::OnTrailingModified(ticket, targetSL, false);
                     }
                     else
                     {
                        CDiagnostics::OnError("PositionModify (Trailing Buy)", GetLastError(), m_trade.ResultRetcodeDescription());
                     }
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               double profitPts = (openPrice - currentPrice) / pt;
               if(profitPts >= InpTrailPts)
               {
                  double targetSL = CUtils::NormalizePrice(m_symbol, currentPrice + (InpTrailPts * pt));
                  if(targetSL - currentPrice >= minDist && targetSL < openPrice && (currentSL == 0 || currentSL - targetSL >= InpTrailStepPts * pt))
                  {
                     ResetLastError();
                     if(m_trade.PositionModify(ticket, targetSL, currentTP))
                     {
                        CUtils::Log(StringFormat("Trailing Stop Sell #%I64u dipindahkan ke %s", ticket, DoubleToString(targetSL, (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS))));
                        CDiagnostics::OnTrailingModified(ticket, targetSL, false);
                     }
                     else
                     {
                        CDiagnostics::OnError("PositionModify (Trailing Sell)", GetLastError(), m_trade.ResultRetcodeDescription());
                     }
                  }
               }
            }
         }
      }
   }
};
