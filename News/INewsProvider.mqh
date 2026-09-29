//+------------------------------------------------------------------+
//|                                               INewsProvider.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include "../Core/Defines.mqh"

//+------------------------------------------------------------------+
//| Interface Abstraksi Penyedia Berita                             |
//+------------------------------------------------------------------+
class INewsProvider
{
public:
   virtual ~INewsProvider() {}
   
   // Inisialisasi provider
   virtual bool Init(const string symbol, const string currencies, ENUM_NEWS_IMPACT minImpact) = 0;
   
   // Muat / perbarui daftar berita yang akan datang
   virtual bool FetchUpcomingNews(datetime fromTime, datetime toTime, SNewsEvent &events[], int &totalCount) = 0;
   
   // Nama provider untuk keperluan logging/tampilan
   virtual string GetProviderName() const = 0;
};
