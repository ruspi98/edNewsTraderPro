//+------------------------------------------------------------------+
//|                                         ExportCalendarToCSV.mq5  |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property version   "1.10"
#property script_show_inputs

//--- Enum Filter Ekspor Dampak
enum ENUM_EXPORT_IMPACT
{
   EXPORT_HIGH_ONLY       = 0, // Hanya High Impact Saja (Rekomendasi)
   EXPORT_MEDIUM_AND_HIGH = 1, // Medium & High Impact
   EXPORT_ALL             = 2  // Semua Dampak (Low, Medium, High)
};

//--- Inputs
input datetime           InpFromDate        = D'2023.01.01 00:00'; // Tanggal Mulai
input datetime           InpToDate          = D'2026.09.28 23:59'; // Tanggal Selesai
input string             InpCurrencies      = "USD,EUR,GBP,JPY";   // Mata Uang Berita (pisahkan koma)
input ENUM_EXPORT_IMPACT InpImpactFilter    = EXPORT_HIGH_ONLY;    // Filter Dampak yang Diekspor
input string             InpFileName        = "news_calendar_3years.csv"; // Nama File Output di MQL5\Files

//+------------------------------------------------------------------+
//| Konversi ENUM_CALENDAR_EVENT_IMPORTANCE ke String                |
//+------------------------------------------------------------------+
string GetImpactString(ENUM_CALENDAR_EVENT_IMPORTANCE imp)
{
   switch(imp)
   {
      case CALENDAR_IMPORTANCE_HIGH:     return "HIGH";
      case CALENDAR_IMPORTANCE_MODERATE: return "MEDIUM";
      default:                           return "LOW";
   }
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   PrintFormat("Mengekspor kalender ekonomi dari %s sampai %s...", 
               TimeToString(InpFromDate), TimeToString(InpToDate));

   MqlCalendarValue values[];
   // Jika country_code NULL dan currency NULL, mengambil seluruh negara
   int totalValues = CalendarValueHistory(values, InpFromDate, InpToDate, NULL, NULL);
   if(totalValues <= 0)
   {
      PrintFormat("CalendarValueHistory gagal atau tidak ada data. Error: %d", GetLastError());
      return;
   }

   PrintFormat("Total raw event values ditemukan: %d", totalValues);

   int fileHandle = FileOpen(InpFileName, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fileHandle == INVALID_HANDLE)
   {
      PrintFormat("Gagal membuka file %s untuk penulisan! Error: %d", InpFileName, GetLastError());
      return;
   }

   // Tulis header komentar
   FileWriteString(fileHandle, "# edNewsTraderPro Economic Calendar Export (Standard 4-Column)\n");
   FileWriteString(fileHandle, StringFormat("# Exported Range: %s to %s\n", TimeToString(InpFromDate), TimeToString(InpToDate)));
   FileWriteString(fileHandle, StringFormat("# Currencies: %s | Filter: %s\n", InpCurrencies, EnumToString(InpImpactFilter)));
   FileWriteString(fileHandle, "# Format: YYYY.MM.DD HH:MM|CURRENCY|IMPACT|EVENT_NAME\n");

   string targetCurrs[];
   int numCurrs = StringSplit(InpCurrencies, ',', targetCurrs);
   for(int i = 0; i < numCurrs; i++)
   {
      StringTrimLeft(targetCurrs[i]);
      StringTrimRight(targetCurrs[i]);
      StringToUpper(targetCurrs[i]);
   }

   int countWritten = 0;
   for(int i = 0; i < totalValues; i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event))
         continue;

      // Filter Dampak (Impact)
      if(InpImpactFilter == EXPORT_HIGH_ONLY && event.importance != CALENDAR_IMPORTANCE_HIGH)
         continue;
      if(InpImpactFilter == EXPORT_MEDIUM_AND_HIGH && 
         (event.importance != CALENDAR_IMPORTANCE_HIGH && event.importance != CALENDAR_IMPORTANCE_MODERATE))
         continue;

      // Ambil data negara untuk mendapatkan currency
      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country))
         continue;

      // Filter Currency
      string curr = country.currency;
      StringToUpper(curr);
      bool currMatch = (numCurrs == 0 || InpCurrencies == "");
      for(int c = 0; c < numCurrs; c++)
      {
         if(curr == targetCurrs[c])
         {
            currMatch = true;
            break;
         }
      }
      if(!currMatch)
         continue;

      // Format baris 4 kolom: YYYY.MM.DD HH:MM|CURRENCY|IMPACT|EVENT_NAME
      string line = StringFormat("%s|%s|%s|%s\r\n", 
                                 TimeToString(values[i].time, TIME_DATE|TIME_MINUTES),
                                 curr,
                                 GetImpactString(event.importance),
                                 event.name);
      FileWriteString(fileHandle, line);
      countWritten++;
   }

   FileClose(fileHandle);
   PrintFormat("SUKSES: %d event berita berhasil diekspor ke MQL5\\Files\\%s", countWritten, InpFileName);
}
//+------------------------------------------------------------------+
