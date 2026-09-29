//+------------------------------------------------------------------+
//|                                                    IStrategy.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include "../Core/Defines.mqh"
#include "../Execution/OrderManager.mqh"
#include "../Execution/RiskManager.mqh"

//+------------------------------------------------------------------+
//| Interface Abstraksi Strategi Trading Berita                      |
//+------------------------------------------------------------------+
class IStrategy
{
public:
   virtual ~IStrategy() {}

   // Inisialisasi strategi dengan dependensi eksekusi
   virtual bool Init(const string symbol, ulong magic, COrderManager *orderMgr, CRiskManager *riskMgr) = 0;

   // Update setiap 1 detik dari OnTimer (untuk pemantauan countdown berita)
   virtual void OnTimerUpdate(SNewsEvent &currentNews, int secondsToNews) = 0;

   // Update setiap tick harga masuk
   virtual void OnTickUpdate() = 0;

   // Pembersihan saat EA deinit
   virtual void OnDeinit() = 0;

   // Nama strategi untuk log
   virtual string GetStrategyName() const = 0;
};
