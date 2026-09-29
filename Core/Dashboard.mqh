//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                                                  edNewsTraderPro |
//|                                  Copyright 2026, edNewsTraderPro |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, edNewsTraderPro"
#property link      ""
#property strict

#include "Defines.mqh"
#include "Utils.mqh"
#include "../Config/Config.mqh"

//+------------------------------------------------------------------+
//| On-Chart Information Dashboard                                   |
//+------------------------------------------------------------------+
class CDashboard
{
private:
   string m_prefix;
   int    m_x;
   int    m_y;

   void CreateLabel(string name, string text, int x, int y, color clr, int fontSize = 9, bool isBold = false)
   {
      string objName = m_prefix + name;
      if(ObjectFind(0, objName) < 0)
      {
         ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
         ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
         ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      }
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetString(0, objName, OBJPROP_FONT, isBold ? "Segoe UI Bold" : "Segoe UI");
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   }

public:
   CDashboard() : m_prefix("edNews_"), m_x(20), m_y(25) {}
   ~CDashboard() {}

   void Init()
   {
      Destroy();
   }

   void Update(const string symbol, long currentSpread, const SNewsEvent &nextNews, int secondsToNews, bool hasNews, string sltpDesc = "")
   {
      if(!InpShowDashboard)
         return;

      int line = 0;
      int lineSpacing = 18;

      // Header
      CreateLabel("Header", "=== edNewsTraderPro v1.00 ===", m_x, m_y + (line++ * lineSpacing), clrGold, 10, true);

      // Status Symbol & Spread
      color spreadClr = (currentSpread <= InpMaxSpreadPts) ? clrLimeGreen : clrRed;
      string spreadText = StringFormat("Pair: %s | Spread: %d pts (Max: %d)", symbol, (int)currentSpread, InpMaxSpreadPts);
      CreateLabel("Spread", spreadText, m_x, m_y + (line++ * lineSpacing), spreadClr, 9);

      // Strategi Aktif
      string stratText = "Strategi: ";
      if(InpStrategyType == STRAT_STRADDLE_ONLY) stratText += "Pre-News Straddle";
      else if(InpStrategyType == STRAT_POST_BREAKOUT_ONLY) stratText += "Post-News Breakout";
      else stratText += "Hybrid (Straddle + Post-BO)";
      CreateLabel("Strategy", stratText, m_x, m_y + (line++ * lineSpacing), clrWhite, 9);

      // Mode SL & TP
      if(sltpDesc != "")
      {
         CreateLabel("SLTP", "SL/TP: " + sltpDesc, m_x, m_y + (line++ * lineSpacing), clrAquamarine, 9);
      }

      // Info Berita Terdekat
      if(hasNews)
      {
         string countdownStr = CUtils::FormatCountdown(secondsToNews);
         color cdClr = (secondsToNews > 0 && secondsToNews <= InpStraddleLeadSec) ? clrOrangeRed : clrCyan;

         string eventTitle = nextNews.event_name;
         if(StringLen(eventTitle) > 28)
            eventTitle = StringSubstr(eventTitle, 0, 25) + "...";

         CreateLabel("NewsTitle", StringFormat("Next News: [%s] %s", nextNews.currency, eventTitle), m_x, m_y + (line++ * lineSpacing), clrYellow, 9);
         CreateLabel("NewsTime", StringFormat("Waktu: %s (Server)", TimeToString(nextNews.time, TIME_DATE|TIME_MINUTES)), m_x, m_y + (line++ * lineSpacing), clrLightGray, 9);
         CreateLabel("Countdown", StringFormat("Hitung Mundur: %s", countdownStr), m_x, m_y + (line++ * lineSpacing), cdClr, 10, true);
      }
      else
      {
         CreateLabel("NewsTitle", "Next News: Tidak ada event High Impact", m_x, m_y + (line++ * lineSpacing), clrGray, 9);
         CreateLabel("NewsTime", "", m_x, m_y + (line++ * lineSpacing), clrGray, 9);
         CreateLabel("Countdown", "Status: Menunggu rilis kalender berikutnya", m_x, m_y + (line++ * lineSpacing), clrGray, 9);
      }
   }

   void Destroy()
   {
      ObjectsDeleteAll(0, m_prefix);
   }
};
