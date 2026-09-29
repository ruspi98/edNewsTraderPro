//+------------------------------------------------------------------+
//|                                              StrategyManager.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include "StraddleStrategy.mqh"
#include "PostBreakoutStrategy.mqh"
#include "../Config/Config.mqh"

//+------------------------------------------------------------------+
//| Pengelola dan Koordinator Strategi Aktif                         |
//+------------------------------------------------------------------+
class CStrategyManager
{
private:
   CStraddleStrategy     m_straddleStrategy;
   CPostBreakoutStrategy m_postBreakoutStrategy;
   
   bool                  m_useStraddle;
   bool                  m_usePostBreakout;

public:
   CStrategyManager() : m_useStraddle(false), m_usePostBreakout(false) {}
   ~CStrategyManager() {}

   bool Init(const string symbol, ulong magic, COrderManager *orderMgr, CRiskManager *riskMgr)
   {
      m_useStraddle     = (InpStrategyType == STRAT_STRADDLE_ONLY || InpStrategyType == STRAT_BOTH_COMBINED);
      m_usePostBreakout = (InpStrategyType == STRAT_POST_BREAKOUT_ONLY || InpStrategyType == STRAT_BOTH_COMBINED);

      bool ok = true;
      if(m_useStraddle)
      {
         if(!m_straddleStrategy.Init(symbol, magic, orderMgr, riskMgr))
            ok = false;
      }

      if(m_usePostBreakout)
      {
         if(!m_postBreakoutStrategy.Init(symbol, magic, orderMgr, riskMgr))
            ok = false;
      }

      CUtils::Log(StringFormat("Strategy Manager aktif. Straddle: %s, Post-Breakout: %s",
         m_useStraddle ? "YES" : "NO", m_usePostBreakout ? "YES" : "NO"));

      return ok;
   }

   // Update hitung mundur waktu rilis berita dari OnTimer
   void OnTimerUpdate(SNewsEvent &currentNews, int secondsToNews)
   {
      if(m_useStraddle)
      {
         m_straddleStrategy.OnTimerUpdate(currentNews, secondsToNews);
      }
      if(m_usePostBreakout)
      {
         m_postBreakoutStrategy.OnTimerUpdate(currentNews, secondsToNews);
      }
   }

   // Update setiap tick harga baru
   void OnTickUpdate()
   {
      if(m_useStraddle)
      {
         m_straddleStrategy.OnTickUpdate();
      }
      if(m_usePostBreakout)
      {
         m_postBreakoutStrategy.OnTickUpdate();
      }
   }

   // Pembersihan saat EA di-remove
   void OnDeinit()
   {
      if(m_useStraddle)
      {
         m_straddleStrategy.OnDeinit();
      }
      if(m_usePostBreakout)
      {
         m_postBreakoutStrategy.OnDeinit();
      }
   }
};
