//+------------------------------------------------------------------+
//|                                                     RG_SMV_V2.mq5 |
//|                  Version 3 - Modules 1 à 5                         |
//|                                    Smart Money Concepts (SMC)   |
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""
#property version   "3.00"
#property description "EA Version 3 - Modules 1-5 : Structure + Bougies + OrderFlow + Cause/Effet + Liquidité"

#include "Include\SMC_Structures.mqh"
#include "Include\SMC_MarketStructure.mqh"
#include "Include\SMC_BOS_ChoCh.mqh"
#include "Include\SMC_CandleTypes.mqh"
#include "Include\SMC_OrderFlow.mqh"
#include "Include\SMC_CauseEffect.mqh"
#include "Include\SMC_Liquidity.mqh"
#include "Include\SMC_Telegram.mqh"
#include "Include\SMC_Trade.mqh"

//+------------------------------------------------------------------+
//| Paramètres d'entrée                                               |
//+------------------------------------------------------------------+
input group "=== Timeframes ==="
input bool             InpAutoTF = true;               // Auto-détection HTF/LTF
input ENUM_TIMEFRAMES  InpHTF = PERIOD_H1;             // HTF (si auto=false)
input ENUM_TIMEFRAMES  InpLTF = PERIOD_M5;             // LTF (si auto=false)

input group "=== Affichage ==="
input bool             InpVisualMode = true;            // Mode visuel (flèches, labels)
input int              InpArrowSize = 4;                // Taille des flèches (1-5)
input int              InpMinConfidence = 0;            // Confiance minimum % (0=tout, 50=moyen, 80=tendance)

input group "=== Telegram ==="
input bool             InpUseTelegram = false;          // Activer notifications Telegram
input string           InpBotToken = "";                // Bot Token (@BotFather) ou vide = fichier
input string           InpChatID = "";                  // Chat ID (@userinfobot) ou vide = fichier

input group "=== Trading ==="
input bool             InpTradingEnabled = false;       // Activer l'exécution des trades (false = signaux uniquement)
input double           InpRiskPercent = 1.0;            // Risque par trade (% capital)
input double           InpMinRR = 1.5;                  // R:R minimum pour ouvrir
input int              InpMaxPositions = 1;             // Max positions simultanées
input int              InpMaxDailyTrades = 5;           // Max trades par jour
input double           InpMaxDrawdownPercent = 10.0;    // Blocage si drawdown dépasse (%)


//+------------------------------------------------------------------+
//| Constantes internes (anciens paramètres masqués)                  |
//+------------------------------------------------------------------+
const int              InpSwingStrengthChart = 2;   // Force swing Chart/LTF (réactif)
const int              InpSwingStrengthHTF = 3;     // Force swing HTF (conservateur)
const int              InpMagicNumber = 20260207;
const bool             InpUseLimitOrders = true;
const bool             InpRequireNoBOSTrap = false;
const bool             InpRequireStructureAlign = false;
const int              InpLabelFontSize = 10;
// Couleurs internes — valeurs fixes
const color            InpSwingHighColor = clrRed;
const color            InpSwingLowColor = clrBlue;
const color            InpKeyLevelColor = clrLime;
const color            InpBOSColor = clrGreen;
const color            InpChoChColor = clrOrange;
const color            InpSupplyColor = C'180,0,0';
const color            InpDemandColor = C'0,128,0';
const color            InpLiqSigColor = clrGold;
const color            InpODFBullColor = clrDodgerBlue;
const color            InpODFBearColor = clrCrimson;
const color            InpBBBullColor = C'0,100,180';
const color            InpBBBearColor = C'180,50,0';
const color            InpAccumColor = C'200,180,220';
const color            InpDistribColor = C'230,190,130';
const color            InpIntactColor = clrYellow;
const color            InpEQLColor = clrCyan;
const color            InpEQHColor = clrMagenta;
const color            InpIDMColor = clrOrangeRed;
const color            InpTrendLiqColor = clrGoldenrod;
// Affichage modules — tous activés en mode visuel
const bool             InpDrawCircles = false;
const bool             InpDrawStructureLabel = true;
const bool             InpDrawKeyLevels = false;
const bool             InpDrawBOS = true;
const bool             InpDrawSupplyDemand = true;
const bool             InpDrawLiqSignatures = false;
const bool             InpDrawOrderFlow = false;
const bool             InpDrawBreakerBlocks = false;
const bool             InpDrawCauseEffect = false;
const bool             InpDrawLiquidity = false;
const bool             InpDrawTrendlineLiq = false;
// Telegram — toujours notifier signaux
const bool             InpNotifySignal = true;
const bool             InpNotifyOB = false;
const bool             InpNotifyTP = false;
const bool             InpNotifySL = false;

//+------------------------------------------------------------------+
//| Variables globales                                                |
//+------------------------------------------------------------------+
CMarketStructure* g_msChart;
CMarketStructure* g_msHTF;
CBOSChoCh*        g_bosChart;
CBOSChoCh*        g_bosHTF;
CCandleTypes*     g_candles;
COrderFlow*       g_orderFlow;   // Module 3
CCauseEffect*     g_causeEffect; // Module 4
CLiquidity*       g_liquidity;   // Module 5
CTelegram*        g_telegram;     // Notifications Telegram
CTradeManager*    g_tradeManager; // Prise de position (risque strict)

ENUM_TIMEFRAMES   g_tfChart;
ENUM_TIMEFRAMES   g_tfHTF;

bool              g_initialized = false;
bool              g_tradingEnabled = true;  // InpTradingEnabled OU force ON en backtest (testeur peut ne pas afficher les inputs)
datetime          g_lastBarTime = 0;
int               g_lastOBZoneCount = -1;   // Telegram: dernier nombre de zones OB
double            g_lastTPNotifPrice = 0;   // Telegram: dernier prix TP notifie (eviter doublons)
datetime          g_lastSLNotifTime = 0;    // Telegram: derniere notif SL (eviter spam)
int               g_lastFirstVisible = -1;
int               g_lastVisibleCount = -1;
datetime          g_visibleTimeLeft = 0;
datetime          g_visibleTimeRight = 0;

//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetAutoHTF(ENUM_TIMEFRAMES chartTF)
{
   switch(chartTF)
   {
      case PERIOD_M1:  return PERIOD_M15;
      case PERIOD_M2:  return PERIOD_M30;
      case PERIOD_M3:  return PERIOD_M30;
      case PERIOD_M4:  return PERIOD_H1;
      case PERIOD_M5:  return PERIOD_H1;
      case PERIOD_M6:  return PERIOD_H1;
      case PERIOD_M10: return PERIOD_H1;
      case PERIOD_M12: return PERIOD_H2;
      case PERIOD_M15: return PERIOD_H4;
      case PERIOD_M20: return PERIOD_H4;
      case PERIOD_M30: return PERIOD_H4;
      case PERIOD_H1:  return PERIOD_H4;
      case PERIOD_H2:  return PERIOD_D1;
      case PERIOD_H3:  return PERIOD_D1;
      case PERIOD_H4:  return PERIOD_D1;
      case PERIOD_H6:  return PERIOD_W1;
      case PERIOD_H8:  return PERIOD_W1;
      case PERIOD_H12: return PERIOD_W1;
      case PERIOD_D1:  return PERIOD_W1;
      case PERIOD_W1:  return PERIOD_MN1;
      case PERIOD_MN1: return PERIOD_MN1;
      default:         return PERIOD_H4;
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpAutoTF)
   {
      g_tfChart = (ENUM_TIMEFRAMES)Period();
      g_tfHTF   = GetAutoHTF(g_tfChart);
   }
   else
   {
      g_tfChart = InpLTF;
      g_tfHTF   = InpHTF;
   }

   g_msChart    = new CMarketStructure();
   g_msHTF      = new CMarketStructure();
   g_bosChart   = new CBOSChoCh();
   g_bosHTF     = new CBOSChoCh();
   g_candles    = new CCandleTypes();
   g_orderFlow  = new COrderFlow();
   g_causeEffect = new CCauseEffect();
   g_liquidity  = new CLiquidity();

   if(!g_msChart.Init(_Symbol, g_tfChart, InpSwingStrengthChart))    { Print("Err Chart MS"); return INIT_FAILED; }
   if(!g_msHTF.Init(_Symbol, g_tfHTF, InpSwingStrengthHTF))            { Print("Err HTF MS");   return INIT_FAILED; }
   if(!g_bosHTF.Init(_Symbol, g_tfHTF, g_msHTF, NULL))          { Print("Err HTF BOS");  return INIT_FAILED; }
   if(!g_bosChart.Init(_Symbol, g_tfChart, g_msChart, g_msHTF)) { Print("Err Chart BOS"); return INIT_FAILED; }
   if(!g_candles.Init(_Symbol, g_tfChart))                       { Print("Err Candles");  return INIT_FAILED; }
   if(!g_orderFlow.Init(_Symbol, g_tfChart, g_msChart, g_candles, g_bosChart))
      { Print("Err OrderFlow"); return INIT_FAILED; }
   if(!g_causeEffect.Init(_Symbol, g_tfChart, g_msChart, g_bosChart))
      { Print("Err CauseEffect"); return INIT_FAILED; }
   if(!g_liquidity.Init(_Symbol, g_tfChart, g_msChart, g_bosChart))
      { Print("Err Liquidity"); return INIT_FAILED; }

   g_tradeManager = new CTradeManager();
   if(!g_tradeManager.Init(_Symbol, InpRiskPercent, InpMinRR, InpMagicNumber,
                           InpMaxPositions, InpMaxDailyTrades, InpMaxDrawdownPercent))
      { Print("Err TradeManager"); return INIT_FAILED; }

   g_telegram = new CTelegram();
   if(InpUseTelegram)
   {
      if(g_telegram.Init(_Symbol, InpBotToken, InpChatID))
      {
         Print("Telegram: OK (credentials fichier si vides)");
         g_telegram.TestConnection();
      }
      else
         Print("Telegram: non configure (token/chatID manquants)");
   }

   g_initialized = true;
   g_lastFirstVisible = -1;
   g_lastVisibleCount = -1;
   g_lastBarTime = 0;
   g_lastOBZoneCount = -1;
   g_lastTPNotifPrice = 0;
   g_lastSLNotifTime = 0;

   g_tradingEnabled = InpTradingEnabled;
   if(MQLInfoInteger(MQL_TESTER))
      g_tradingEnabled = true;

   Print("RG_SMV V3.00 | TF=", EnumToString(g_tfChart), " HTF=", EnumToString(g_tfHTF),
         (InpAutoTF ? " (AUTO)" : ""), " | Telegram: ", InpUseTelegram ? "ON" : "OFF",
         " | Trading: ", g_tradingEnabled ? "ON" : "OFF");

   if(InpVisualMode) RecalculateAndDraw();
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "SMC_");
   ObjectsDeleteAll(0, "SIG_ARW_");   // Flèches historiques
   ObjectsDeleteAll(0, "SIG_LIVE_");  // Flèches live (TryOpenPosition)
   if(g_msChart   != NULL) delete g_msChart;
   if(g_msHTF     != NULL) delete g_msHTF;
   if(g_bosChart  != NULL) delete g_bosChart;
   if(g_bosHTF    != NULL) delete g_bosHTF;
   if(g_candles   != NULL) delete g_candles;
   if(g_orderFlow != NULL) delete g_orderFlow;
   if(g_causeEffect != NULL) delete g_causeEffect;
   if(g_liquidity != NULL) delete g_liquidity;
   if(g_telegram != NULL) delete g_telegram;
   if(g_tradeManager != NULL) delete g_tradeManager;
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initialized) return;
   datetime curBar = iTime(_Symbol, (ENUM_TIMEFRAMES)Period(), 0);
   if(curBar == g_lastBarTime) return;
   g_lastBarTime = curBar;
   
   // Mise à jour des modules d'analyse (toujours, même sans mode visuel)
   // RecalculateAndDraw gère à la fois l'analyse ET le dessin
   if(InpVisualMode)
      RecalculateAndDraw();
   else
   {
      // Mode sans visuel : mettre à jour les modules avec fenêtre suffisante
      int bc = MathMin(500, Bars(_Symbol, g_tfChart) - 1);
      int bh = MathMin(100, Bars(_Symbol, g_tfHTF) - 1);
      g_msHTF.Update(bh);    g_bosHTF.Update(bh);
      g_msChart.Update(bc);  g_bosChart.Update(bc);
      g_candles.Update(bc);  g_orderFlow.Update(bc);
      g_causeEffect.Update(bc); g_liquidity.Update(bc);
   }
   
   // Diagnostic journalier (1 fois par jour à 09:00)
   {
      static datetime s_lastDiagDay = 0;
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
      if(today != s_lastDiagDay && dt.hour >= 9)
      {
         s_lastDiagDay = today;
         ENUM_MARKET_BIAS htfB = g_msHTF.GetMarketBias();
         ENUM_MARKET_BIAS ltfB = g_msChart.GetMarketBias();
         string htfStr = (htfB == BIAS_BULLISH ? "BULL" : (htfB == BIAS_BEARISH ? "BEAR" : "NEUT"));
         string ltfStr = (ltfB == BIAS_BULLISH ? "BULL" : (ltfB == BIAS_BEARISH ? "BEAR" : "NEUT"));
         Print("[DIAG] HTF=", htfStr, " LTF=", ltfStr,
               " | SwingH=", g_msChart.GetSwingHighCount(), " SwingL=", g_msChart.GetSwingLowCount(),
               " | S/D zones=", g_candles.GetZoneCount(),
               " | BOS=", g_bosChart.GetEventCount(),
               " | Liq=", g_liquidity.GetLevelCount());
      }
   }
   
   if(InpUseTelegram && g_telegram != NULL)
      SendTelegramSignalNotification();
   
   // Debug: log toutes les 20 barres pour suivre la détection
   {
      static int s_barDebugCount = 0;
      s_barDebugCount++;
      if(s_barDebugCount % 20 == 1)
      {
         int sdCount = g_candles.GetZoneCount();
         int bosCount = g_bosChart.GetEventCount();
         int liqCount = g_liquidity.GetLevelCount();
         if(sdCount > 0 || bosCount > 0)
            Print("[DBG] Bar#", s_barDebugCount, 
                  " | S/D=", sdCount, " BOS=", bosCount, " Liq=", liqCount);
      }
   }
   
   // Mode signal uniquement : chercher les signaux
   {
      TryOpenPosition();
   }
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
{
   if(!g_initialized || !InpVisualMode) return;
   if(id != CHARTEVENT_CHART_CHANGE) return;
   int fv = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int vc = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   if(fv == g_lastFirstVisible && vc == g_lastVisibleCount) return;
   RecalculateAndDraw();
}

//+------------------------------------------------------------------+
void RecalculateAndDraw()
{
   int firstVisible = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   int visibleBars  = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
   g_lastFirstVisible = firstVisible;
   g_lastVisibleCount = visibleBars;

   ENUM_TIMEFRAMES chartTF = (ENUM_TIMEFRAMES)Period();
   int chartBars = Bars(_Symbol, chartTF);
   if(chartBars < 10) return;

   int margin = MathMax(visibleBars / 2, 50);
   int leftBar  = MathMin(firstVisible + margin, chartBars - 1);
   int rightBar = MathMax(firstVisible - visibleBars - margin, 0);

   g_visibleTimeLeft  = iTime(_Symbol, chartTF, leftBar);
   g_visibleTimeRight = iTime(_Symbol, chartTF, rightBar);
   if(g_visibleTimeLeft == 0 || g_visibleTimeRight == 0) return;

   int barsChart = iBarShift(_Symbol, g_tfChart, g_visibleTimeLeft, false) + InpSwingStrength + 10;
   int barsHTF   = iBarShift(_Symbol, g_tfHTF,   g_visibleTimeLeft, false) + InpSwingStrength + 10;
   barsChart = MathMin(barsChart, Bars(_Symbol, g_tfChart) - 1);
   barsHTF   = MathMin(barsHTF,   Bars(_Symbol, g_tfHTF) - 1);
   // Minimum analysis depth: 500 LTF bars (~2 jours M5) et 100 HTF bars (~4 jours H1)
   // Dans le tester non-visuel, ChartGetInteger retourne 0, donnant ~50 bars.
   // 50 bars M5 = 4h, ~17 bars H1 = insuffisant pour détecter la structure!
   barsChart = MathMax(barsChart, 500);
   barsHTF   = MathMax(barsHTF, 100);
   barsChart = MathMin(barsChart, Bars(_Symbol, g_tfChart) - 1);
   barsHTF   = MathMin(barsHTF,   Bars(_Symbol, g_tfHTF) - 1);

   g_msHTF.Update(barsHTF);
   g_bosHTF.Update(barsHTF);
   g_msChart.Update(barsChart);
   g_bosChart.Update(barsChart);
   g_candles.Update(barsChart);
   g_orderFlow.Update(barsChart);   // Module 3 : Order Flow + Breaker Blocks
   g_causeEffect.Update(barsChart); // Module 4 : Accumulation / Distribution
   g_liquidity.Update(barsChart);   // Module 5 : Liquidité (EQL/EQH, Intact, IDM, Trendline)

   DrawVisuals();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void DrawVisuals()
{
   ObjectsDeleteAll(0, "SMC_");

   CMarketStructure* ms = g_msChart;
   ENUM_TIMEFRAMES tf = g_tfChart;

   int highCount = ms.GetSwingHighCount();
   int lowCount  = ms.GetSwingLowCount();

   // Rayon cercles
   double radiusPrice = 0.0001;
   long periodSec = PeriodSeconds(tf);
   if(periodSec <= 0) periodSec = 300;
   datetime radiusTime = (datetime)(periodSec * 3);
   double avgRange = 0;
   for(int b = 1; b <= 20; b++)
      avgRange += (iHigh(_Symbol, tf, b) - iLow(_Symbol, tf, b));
   if(avgRange > 0) radiusPrice = (avgRange / 20.0) * 0.15;

   // --- SWING HIGHS ---
   for(int i = 0; i < highCount; i++)
   {
      SSwingPoint swing;
      if(!ms.GetSwingHigh(i, swing)) continue;
      if(swing.time < g_visibleTimeLeft || swing.time > g_visibleTimeRight) continue;

      string name = "SMC_H" + IntegerToString(i);
      string label = "";
      switch(swing.type) { case SWING_HH: label = "HH"; break; case SWING_LH: label = "LH"; break; default: label = "H"; break; }
      if(swing.isMajor) label += "*";

      ObjectCreate(0, name, OBJ_TEXT, 0, swing.time, swing.price);
      ObjectSetString(0, name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpSwingHighColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpLabelFontSize);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LOWER);

      if(InpDrawCircles)
      {
         string cn = name + "c";
         ObjectCreate(0, cn, OBJ_ELLIPSE, 0,
            swing.time - radiusTime, swing.price - radiusPrice,
            swing.time + radiusTime, swing.price + radiusPrice);
         ObjectSetInteger(0, cn, OBJPROP_COLOR, InpSwingHighColor);
         ObjectSetInteger(0, cn, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, cn, OBJPROP_FILL, false);
         ObjectSetInteger(0, cn, OBJPROP_BACK, false);
      }
   }

   // --- SWING LOWS ---
   for(int i = 0; i < lowCount; i++)
   {
      SSwingPoint swing;
      if(!ms.GetSwingLow(i, swing)) continue;
      if(swing.time < g_visibleTimeLeft || swing.time > g_visibleTimeRight) continue;

      string name = "SMC_L" + IntegerToString(i);
      string label = "";
      switch(swing.type) { case SWING_HL: label = "HL"; break; case SWING_LL: label = "LL"; break; default: label = "L"; break; }
      if(swing.isMajor) label += "*";

      ObjectCreate(0, name, OBJ_TEXT, 0, swing.time, swing.price);
      ObjectSetString(0, name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpSwingLowColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpLabelFontSize);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);

      if(InpDrawCircles)
      {
         string cn = name + "c";
         ObjectCreate(0, cn, OBJ_ELLIPSE, 0,
            swing.time - radiusTime, swing.price - radiusPrice,
            swing.time + radiusTime, swing.price + radiusPrice);
         ObjectSetInteger(0, cn, OBJPROP_COLOR, InpSwingLowColor);
         ObjectSetInteger(0, cn, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, cn, OBJPROP_FILL, false);
         ObjectSetInteger(0, cn, OBJPROP_BACK, false);
      }
   }

   // --- Label STRUCTURE ---
   if(InpDrawStructureLabel)
   {
      ENUM_MARKET_BIAS bias = ms.GetMarketBias();
      string text = (bias == BIAS_BULLISH) ? "BULLISH STRUCTURE" : (bias == BIAS_BEARISH) ? "BEARISH STRUCTURE" : "CONSOLIDATION";
      color tc = (bias == BIAS_BULLISH) ? clrDodgerBlue : (bias == BIAS_BEARISH) ? clrCrimson : clrGray;
      datetime midTime = (datetime)((long)(g_visibleTimeLeft + g_visibleTimeRight) / 2);
      double midPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : iClose(_Symbol, tf, 0);
      ObjectCreate(0, "SMC_SL", OBJ_TEXT, 0, midTime, midPrice);
      ObjectSetString(0, "SMC_SL", OBJPROP_TEXT, text);
      ObjectSetInteger(0, "SMC_SL", OBJPROP_COLOR, tc);
      ObjectSetInteger(0, "SMC_SL", OBJPROP_FONTSIZE, 12);
      ObjectSetInteger(0, "SMC_SL", OBJPROP_ANCHOR, ANCHOR_CENTER);
   }

   // --- BOS / ChoCh (chart TF + HTF) - filtrés par zone visible ---
   if(InpDrawBOS)
   {
      DrawBOSFiltered(g_bosChart, g_tfChart, "SMC_BC", InpBOSColor, InpChoChColor);
      DrawBOSFiltered(g_bosHTF, g_tfHTF, "SMC_BH", clrDarkGreen, clrDarkOrange);
   }

   // --- Niveaux clés HTF ---
   if(InpDrawKeyLevels)
      g_msHTF.DrawKeyLevels(InpKeyLevelColor);

   // --- Module 2 : Zones d'offre/demande ---
   if(InpDrawSupplyDemand)
      g_candles.DrawZones(InpSupplyColor, InpDemandColor);

   // --- Module 2 : Signatures de liquidité ---
   if(InpDrawLiqSignatures)
      g_candles.DrawLiqSignatures(InpLiqSigColor);

   // --- Module 3 : Order Flow (liens entre zones chaînées) ---
   if(InpDrawOrderFlow)
      g_orderFlow.DrawOrderFlow(InpODFBullColor, InpODFBearColor);

   // --- Module 3 : Breaker Blocks (zones de polarité inversée) ---
   if(InpDrawBreakerBlocks)
      g_orderFlow.DrawBreakerBlocks(InpBBBullColor, InpBBBearColor);

   // --- Module 4 : Accumulation / Distribution (rectangles de consolidation) ---
   if(InpDrawCauseEffect)
      g_causeEffect.DrawZones(InpAccumColor, InpDistribColor);

   // --- Module 5 : Niveaux de liquidité (Intact, EQL/EQH, Inducement, Trendline Liq) ---
   if(InpDrawLiquidity)
      g_liquidity.DrawLiquidity(InpIntactColor, InpEQLColor, InpEQHColor,
                                 InpIDMColor, InpTrendLiqColor, InpDrawTrendlineLiq);
   
   // --- Flèches stratégiques sur l'historique (BOS + S/D zones) ---
   DrawHistoricalArrows();
}

//+------------------------------------------------------------------+
//| Dessine les flèches sur l'historique basées sur Modules 1-5       |
//| Logique: BOS/ChoCh + zone S/D + alignement HTF + liquidité        |
//+------------------------------------------------------------------+
void DrawHistoricalArrows()
{
   ObjectsDeleteAll(0, "SIG_ARW_");
   
   ENUM_TIMEFRAMES tf = g_tfChart;
   int arrowCount = 0;
   
   // Offset vertical pour les flèches
   double avgRange = 0;
   for(int b = 1; b <= 20; b++)
      avgRange += (iHigh(_Symbol, tf, b) - iLow(_Symbol, tf, b));
   double offset = (avgRange > 0) ? (avgRange / 20.0) * 0.3 : 0.0001;
   
   ENUM_MARKET_BIAS htfBias = g_msHTF.GetMarketBias();
   
   // Parcourir les BOS events et chercher une zone S/D associée
   int bosCount = g_bosChart.GetEventCount();
   for(int b = 0; b < bosCount && arrowCount < 200; b++)
   {
      SBOSEvent ev;
      if(!g_bosChart.GetEvent(b, ev) || !ev.isValid) continue;
      if(ev.isTrap || ev.subtype == BOS_SUB_TRAP) continue;
      
      // Filtrer par zone visible
      if(ev.time < g_visibleTimeLeft || ev.time > g_visibleTimeRight) continue;
      
      bool isBuy = (ev.type == BOS_BULLISH || ev.type == CHOCH_BULLISH);
      bool isSell = (ev.type == BOS_BEARISH || ev.type == CHOCH_BEARISH);
      if(!isBuy && !isSell) continue;
      
      // Alignement HTF (Module 1 fractalité)
      bool trendAligned = false;
      if(isBuy && htfBias != BIAS_BEARISH) trendAligned = true;
      if(isSell && htfBias != BIAS_BULLISH) trendAligned = true;
      
      // Chercher une zone S/D matching (Module 2)
      bool foundZone = false;
      double zoneHigh = 0, zoneLow = 0;
      datetime zoneTime = 0;
      int zoneCount = g_candles.GetZoneCount();
      for(int z = zoneCount - 1; z >= 0; z--)
      {
         SSupplyDemandZone zone;
         if(!g_candles.GetZone(z, zone)) continue;
         if(zone.status != ZONE_ACTIVE && zone.status != ZONE_TESTED) continue;
         
         // BUY → chercher demand zone sous le BOS level
         if(isBuy && zone.direction == OB_BULLISH && zone.priceHigh <= ev.levelBroken)
         {
            // La zone doit exister AVANT le BOS
            if(zone.timeEnd < ev.time)
            {
               foundZone = true;
               zoneHigh = zone.priceHigh;
               zoneLow = zone.priceLow;
               zoneTime = zone.timeEnd;
               break;
            }
         }
         // SELL → chercher supply zone au-dessus du BOS level
         if(isSell && zone.direction == OB_BEARISH && zone.priceLow >= ev.levelBroken)
         {
            if(zone.timeEnd < ev.time)
            {
               foundZone = true;
               zoneHigh = zone.priceHigh;
               zoneLow = zone.priceLow;
               zoneTime = zone.timeEnd;
               break;
            }
         }
      }
      
      // Calculer PE/SL/TP
      double pe = 0, sl = 0, tp = 0;
      if(foundZone)
      {
         double zoneHeight = zoneHigh - zoneLow;
         double buffer = zoneHeight * 0.2;
         if(buffer < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20)
            buffer = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20;
         
         if(isBuy)
         {
            pe = zoneHigh;                 // Entrée au haut de la demand zone
            sl = zoneLow - buffer;         // SL sous la zone
            // TP = intact seller ou 2R
            SLiquidityZone liqTarget;
            if(g_liquidity.GetNearestIntactSeller(pe, liqTarget) && liqTarget.price > pe)
               tp = liqTarget.price;
            else
               tp = pe + (pe - sl) * 2.0;
         }
         else
         {
            pe = zoneLow;                  // Entrée au bas de la supply zone
            sl = zoneHigh + buffer;        // SL au-dessus de la zone
            SLiquidityZone liqTarget;
            if(g_liquidity.GetNearestIntactBuyer(pe, liqTarget) && liqTarget.price < pe)
               tp = liqTarget.price;
            else
               tp = pe - (sl - pe) * 2.0;
         }
      }
      else
      {
         // Pas de zone S/D → signal faible, utiliser le BOS level
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double defaultSL = MathMax(offset * 3, point * 100);
         if(isBuy)
         {
            pe = ev.levelBroken;
            sl = pe - defaultSL;
            tp = pe + defaultSL * 2.0;
         }
         else
         {
            pe = ev.levelBroken;
            sl = pe + defaultSL;
            tp = pe - defaultSL * 2.0;
         }
      }
      
      // Calcul Risk:Reward
      double rr = 0;
      if(MathAbs(pe - sl) > 0)
         rr = MathAbs(tp - pe) / MathAbs(pe - sl);
      if(rr < InpMinRR) continue;
      
      // Validation SL direction
      if(isBuy && sl >= pe) continue;
      if(isSell && sl <= pe) continue;
      
      // Score de confiance (Modules 1-5)
      double confidence = 0;
      if(trendAligned) confidence += 30;                                       // Module 1: HTF aligné
      confidence += 15;                                                        // Module 1: BOS confirmé (toujours vrai ici)
      if(foundZone) confidence += 20;                                          // Module 2: zone S/D
      if(ev.type == CHOCH_BULLISH || ev.type == CHOCH_BEARISH) confidence += 5; // ChoCh bonus
      if(g_causeEffect.HasRecentAccumulation(50) && isBuy) confidence += 10;   // Module 4
      if(g_causeEffect.HasRecentDistribution(50) && isSell) confidence += 10;  // Module 4
      // Module 5: inducement swept bonus
      bool hasSweptInducement = false;
      for(int li = 0; li < g_liquidity.GetLevelCount(); li++)
      {
         SLiquidityZone lz;
         if(!g_liquidity.GetLevel(li, lz)) continue;
         if(lz.type == LIQ_INDUCEMENT && lz.isSwept)
         {
            // L'inducement doit avoir été swept AVANT ce BOS
            if(lz.sweepTime <= ev.time && lz.sweepTime > 0)
            { hasSweptInducement = true; break; }
         }
      }
      if(hasSweptInducement) confidence += 15;                                 // Module 5: liquidité prise
      
      // Filtre confiance minimum
      if(confidence < InpMinConfidence) continue;
      
      // Dessiner la flèche
      int arrowBar = iBarShift(_Symbol, tf, ev.time, false);
      if(arrowBar < 0) continue;
      
      double arrowPrice;
      if(isBuy)
         arrowPrice = iLow(_Symbol, tf, arrowBar) - offset;
      else
         arrowPrice = iHigh(_Symbol, tf, arrowBar) + offset;
      
      string name = "SIG_ARW_" + IntegerToString(b) + "_" + IntegerToString(arrowBar);
      
      if(isBuy)
      {
         ObjectCreate(0, name, OBJ_ARROW_BUY, 0, ev.time, arrowPrice);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
      }
      else
      {
         ObjectCreate(0, name, OBJ_ARROW_SELL, 0, ev.time, arrowPrice);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrCrimson);
      }
      ObjectSetInteger(0, name, OBJPROP_WIDTH, InpArrowSize);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, 
         StringFormat("%s %s | PE=%.5f SL=%.5f RR=%.1f | Conf=%.0f%%| %s | %s",
                      isBuy ? "BUY" : "SELL",
                      (ev.type == CHOCH_BULLISH || ev.type == CHOCH_BEARISH) ? "ChoCh" : "BOS",
                      pe, sl, rr, confidence,
                      trendAligned ? "HTF OK" : "CONTRE-TENDANCE",
                      foundZone ? "Zone S/D" : "Sans zone"));
      arrowCount++;
   }
}

//+------------------------------------------------------------------+
//| Dessine une flèche au prix d'entrée validé par la stratégie       |
//| (BOS + zone S/D, signaux Modules 1-5)                              |
//+------------------------------------------------------------------+
void DrawStrategyArrow(datetime barTime, double entryPrice, bool isBuy, const string source)
{
   // Prefix SIG_LIVE_ pour ne PAS être supprimé par DrawHistoricalArrows (SIG_ARW_)
   string arrowName = "SIG_LIVE_" + TimeToString(barTime, TIME_DATE|TIME_SECONDS) + "_" + source;
   if(isBuy)
   {
      ObjectCreate(0, arrowName, OBJ_ARROW_BUY, 0, barTime, entryPrice);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrDodgerBlue);
   }
   else
   {
      ObjectCreate(0, arrowName, OBJ_ARROW_SELL, 0, barTime, entryPrice);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrCrimson);
   }
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, InpArrowSize);
   ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   ObjectSetString(0, arrowName, OBJPROP_TOOLTIP, source + " " + (isBuy ? "BUY" : "SELL"));
}

//+------------------------------------------------------------------+
//| Convertit un timeframe en texte lisible (ex. "H1", "H4", "M15") |
//+------------------------------------------------------------------+
string TFToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return "TF?";
   }
}

//+------------------------------------------------------------------+
//| BOS/ChoCh filtrés par zone visible (dynamique comme les swings)   |
//| Affiche le suffixe du timeframe pour distinguer chart TF / HTF    |
//+------------------------------------------------------------------+
void DrawBOSFiltered(CBOSChoCh* bos, ENUM_TIMEFRAMES bosTF, string prefix, color bosCol, color chochCol)
{
   if(bos == NULL) return;
   int cnt = bos.GetEventCount();
   int drawn = 0;
   string tfTag = " (" + TFToString(bosTF) + ")";

   for(int i = 0; i < cnt; i++)
   {
      SBOSEvent ev;
      if(!bos.GetEvent(i, ev)) continue;
      if(ev.time < g_visibleTimeLeft || ev.time > g_visibleTimeRight) continue;

      string name = prefix + IntegerToString(drawn);
      string label = "";
      color lineColor = bosCol;
      switch(ev.type)
      {
         case BOS_BULLISH:   label = "BOS"; lineColor = bosCol; break;
         case BOS_BEARISH:   label = "BOS"; lineColor = bosCol; break;
         case CHOCH_BULLISH: label = "ChoCh"; lineColor = chochCol; break;
         case CHOCH_BEARISH: label = "ChoCh"; lineColor = chochCol; break;
         default: continue;
      }
      if(ev.subtype == BOS_SUB_TRAP || ev.isTrap) label += " TRAP";
      else if(ev.subtype == BOS_SUB_CONTINUATION) label += " cont.";
      label += tfTag;

      string lineName = name + "_ln";
      ObjectCreate(0, lineName, OBJ_TREND, 0,
         ev.time, ev.levelBroken,
         ev.time + PeriodSeconds(bosTF) * 20, ev.levelBroken);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);

      ObjectCreate(0, name, OBJ_TEXT, 0, ev.time, ev.levelBroken);
      ObjectSetString(0, name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      drawn++;
   }
}

//+------------------------------------------------------------------+
//| Notifications Telegram complémentaires (OB, TP, SL)                |
//| Les signaux BUY/SELL sont envoyés depuis TryOpenPosition()         |
//| après validation complète de la stratégie                          |
//+------------------------------------------------------------------+
void SendTelegramSignalNotification()
{
   if(g_telegram == NULL || !InpUseTelegram) return;

   datetime now = TimeCurrent();
   double close1 = iClose(_Symbol, g_tfChart, 1);
   string tfStr = TFToString(g_tfChart);

   // --- Order Block (nouvelle zone Supply/Demand) ---
   if(InpNotifyOB)
   {
      int zCount = g_candles.GetZoneCount();
      if(g_lastOBZoneCount >= 0 && zCount > g_lastOBZoneCount)
      {
         SSupplyDemandZone zone;
         if(g_candles.GetZone(zCount - 1, zone))
         {
            bool bull = (zone.direction == OB_BULLISH);
            g_telegram.SendOrderBlockDetected(bull, zone.priceHigh, zone.priceLow, tfStr);
         }
         g_lastOBZoneCount = zCount;
      }
      if(g_lastOBZoneCount < 0)
         g_lastOBZoneCount = zCount;
   }

   // --- TP touché (niveau liquidité swept) ---
   if(InpNotifyTP)
   {
      datetime bar1Time = iTime(_Symbol, g_tfChart, 1);
      int lc = g_liquidity.GetLevelCount();
      for(int i = 0; i < lc; i++)
      {
         SLiquidityZone lz;
         if(!g_liquidity.GetLevel(i, lz) || !lz.isSwept) continue;
         if(lz.sweepTime < bar1Time) continue;
         if(MathAbs(lz.price - g_lastTPNotifPrice) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10)
            continue;
         string levelType = "";
         bool forBuy = false;
         switch(lz.type)
         {
            case LIQ_INTACT_SELLER: levelType = "Intact Seller"; forBuy = true; break;
            case LIQ_INTACT_BUYER:  levelType = "Intact Buyer";  forBuy = false; break;
            case LIQ_EQH: levelType = "EQH"; forBuy = true; break;
            case LIQ_EQL: levelType = "EQL"; forBuy = false; break;
            default: continue;
         }
         g_telegram.SendTPTouched(levelType, lz.price, forBuy);
         g_lastTPNotifPrice = lz.price;
         break;
      }
   }

   // --- SL touché (prix casse zone contre-tendance) ---
   if(InpNotifySL && (now - g_lastSLNotifTime) >= PeriodSeconds(g_tfChart) * 2)
   {
      ENUM_MARKET_BIAS bias = g_msChart.GetMarketBias();
      SSupplyDemandZone demandZone, supplyZone;
      bool hasDemand = g_candles.GetLastDemandZone(demandZone);
      bool hasSupply = g_candles.GetLastSupplyZone(supplyZone);
      if(bias == BIAS_BULLISH && hasDemand && close1 < demandZone.priceLow)
      {
         g_telegram.SendSLTouched(close1, true);
         g_lastSLNotifTime = now;
      }
      else if(bias == BIAS_BEARISH && hasSupply && close1 > supplyZone.priceHigh)
      {
         g_telegram.SendSLTouched(close1, false);
         g_lastSLNotifTime = now;
      }
   }
}

//+------------------------------------------------------------------+
//| Tente d'ouvrir une position basée sur Modules 1-5                  |
//| Logique: BOS récent + zone S/D + alignement HTF + liquidité        |
//+------------------------------------------------------------------+
void TryOpenPosition()
{
   if(InpRequireNoBOSTrap && g_bosChart.HasRecentBOSTrap(5))
      return;

   double entry = 0, sl = 0, tp = 0, rr = 0;
   bool isBuy = false;
   string source = "";
   double bestConfidence = 0;
   
   // Adapter la fenêtre de recherche au timeframe
   int periodMin = (int)MathMax(1, PeriodSeconds(Period()) / 60);
   int maxBarsLookback = (int)MathMin(96, MathMax(12, (int)(720.0 / (double)periodMin)));
   
   ENUM_MARKET_BIAS htfBias = g_msHTF.GetMarketBias();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minSLDist = point * 50; // Minimum 5 pips SL
   
   // Parcourir les BOS récents pour trouver le meilleur signal
   int bosCount = g_bosChart.GetEventCount();
   for(int b = bosCount - 1; b >= 0; b--)
   {
      SBOSEvent ev;
      if(!g_bosChart.GetEvent(b, ev) || !ev.isValid) continue;
      if(ev.isTrap || ev.subtype == BOS_SUB_TRAP) continue;
      if(ev.barIndex < 0 || ev.barIndex > maxBarsLookback) continue;
      
      bool sigBuy = (ev.type == BOS_BULLISH || ev.type == CHOCH_BULLISH);
      bool sigSell = (ev.type == BOS_BEARISH || ev.type == CHOCH_BEARISH);
      if(!sigBuy && !sigSell) continue;
      
      // Alignement HTF (Module 1)
      if(InpRequireStructureAlign)
      {
         if(sigBuy && !IsFractalConfluenceForBuy()) continue;
         if(sigSell && !IsFractalConfluenceForSell()) continue;
      }
      bool trendAligned = false;
      if(sigBuy && htfBias != BIAS_BEARISH) trendAligned = true;
      if(sigSell && htfBias != BIAS_BULLISH) trendAligned = true;
      
      // Chercher la meilleure zone S/D matching (Module 2)
      bool foundZone = false;
      double zH = 0, zL = 0;
      int zoneCount = g_candles.GetZoneCount();
      for(int z = zoneCount - 1; z >= 0; z--)
      {
         SSupplyDemandZone zone;
         if(!g_candles.GetZone(z, zone)) continue;
         if(zone.status != ZONE_ACTIVE && zone.status != ZONE_TESTED) continue;
         
         if(sigBuy && zone.direction == OB_BULLISH && zone.priceHigh <= ev.levelBroken)
         {
            foundZone = true; zH = zone.priceHigh; zL = zone.priceLow;
            break;
         }
         if(sigSell && zone.direction == OB_BEARISH && zone.priceLow >= ev.levelBroken)
         {
            foundZone = true; zH = zone.priceHigh; zL = zone.priceLow;
            break;
         }
      }
      
      if(!foundZone) continue; // Pas de zone S/D = pas de signal
      
      // Calculer PE/SL/TP
      double pe_c = 0, sl_c = 0, tp_c = 0;
      double zoneHeight = zH - zL;
      double buffer = MathMax(zoneHeight * 0.2, point * 20);
      
      if(sigBuy)
      {
         pe_c = zH;
         sl_c = zL - buffer;
         SLiquidityZone liqTarget;
         if(g_liquidity.GetNearestIntactSeller(pe_c, liqTarget) && liqTarget.price > pe_c)
            tp_c = liqTarget.price;
         else
            tp_c = pe_c + (pe_c - sl_c) * 2.0;
      }
      else
      {
         pe_c = zL;
         sl_c = zH + buffer;
         SLiquidityZone liqTarget;
         if(g_liquidity.GetNearestIntactBuyer(pe_c, liqTarget) && liqTarget.price < pe_c)
            tp_c = liqTarget.price;
         else
            tp_c = pe_c - (sl_c - pe_c) * 2.0;
      }
      
      // Validation SL direction
      if(sigBuy && sl_c >= pe_c) continue;
      if(sigSell && sl_c <= pe_c) continue;
      if(MathAbs(pe_c - sl_c) < minSLDist) continue;
      
      // RR check
      double rr_c = MathAbs(tp_c - pe_c) / MathAbs(pe_c - sl_c);
      if(rr_c < InpMinRR) continue;
      
      // Score de confiance
      double conf = 0;
      if(trendAligned) conf += 30;
      conf += 15; // BOS confirmé
      conf += 20; // Zone S/D trouvée (toujours ici car foundZone=true)
      if(ev.type == CHOCH_BULLISH || ev.type == CHOCH_BEARISH) conf += 5;
      if(sigBuy && g_causeEffect.HasRecentAccumulation(50)) conf += 10;
      if(sigSell && g_causeEffect.HasRecentDistribution(50)) conf += 10;
      // Inducement swept
      for(int li = 0; li < g_liquidity.GetLevelCount(); li++)
      {
         SLiquidityZone lz;
         if(!g_liquidity.GetLevel(li, lz)) continue;
         if(lz.type == LIQ_INDUCEMENT && lz.isSwept && lz.sweepTime <= ev.time)
         { conf += 15; break; }
      }
      
      if(conf < InpMinConfidence) continue;
      
      // Garder le meilleur signal (plus haute confiance, plus récent)
      if(conf > bestConfidence || (conf == bestConfidence && ev.barIndex < maxBarsLookback / 2))
      {
         entry = pe_c; sl = sl_c; tp = tp_c; rr = rr_c;
         isBuy = sigBuy;
         bestConfidence = conf;
         source = (ev.type == CHOCH_BULLISH || ev.type == CHOCH_BEARISH) ? "ChoCh" : "BOS";
         if(trendAligned) source += "+HTF";
      }
   }

   if(entry <= 0 || sl <= 0 || tp <= 0) 
   { 
      static int s_noEntry = 0;
      s_noEntry++;
      if(s_noEntry % 20 == 1)
         Print("[TRY] Pas de signal: BOS=", g_bosChart.GetEventCount(),
               " | S/D=", g_candles.GetZoneCount(),
               " | Liq=", g_liquidity.GetLevelCount());
      return;
   }
   
   // --- Validation direction SL/TP (défense en profondeur) ---
   if(isBuy)
   {
      if(sl >= entry) { Print("REJET SL mauvais cote: SL=", sl, " >= Entry=", entry, " pour BUY | ", source); return; }
      if(tp <= entry) { Print("REJET TP mauvais cote: TP=", tp, " <= Entry=", entry, " pour BUY | ", source); return; }
   }
   else
   {
      if(sl <= entry) { Print("REJET SL mauvais cote: SL=", sl, " <= Entry=", entry, " pour SELL | ", source); return; }
      if(tp >= entry) { Print("REJET TP mauvais cote: TP=", tp, " >= Entry=", entry, " pour SELL | ", source); return; }
   }
   
   // --- Déduplication : ne pas retenter le même signal ---
   {
      static double s_lastEntry = 0, s_lastSL = 0, s_lastTP = 0;
      static bool   s_lastBuy = false;
      static datetime s_lastTime = 0;
      
      double tol = point * 10;
      
      if(MathAbs(entry - s_lastEntry) < tol && 
         MathAbs(sl - s_lastSL) < tol && 
         MathAbs(tp - s_lastTP) < tol && 
         isBuy == s_lastBuy &&
         TimeCurrent() - s_lastTime < 3600)
      {
         return;
      }
      
      s_lastEntry = entry;
      s_lastSL = sl;
      s_lastTP = tp;
      s_lastBuy = isBuy;
      s_lastTime = TimeCurrent();
   }
   
   // --- Correction TP : utiliser les niveaux de liquidité ---
   if(g_liquidity != NULL)
   {
      double liqTP = 0;
      SLiquidityZone liqTarget;
      if(isBuy)
      {
         if(g_liquidity.GetNearestIntactSeller(entry, liqTarget))
            liqTP = liqTarget.price;
      }
      else
      {
         if(g_liquidity.GetNearestIntactBuyer(entry, liqTarget))
            liqTP = liqTarget.price;
      }
      if(liqTP > 0)
      {
         double liqRR = g_tradeManager.CalculateRR(entry, sl, liqTP);
         if(liqRR >= InpMinRR && liqRR > rr)
         {
            tp = liqTP;
            rr = liqRR;
         }
      }
   }
   
   if(rr < InpMinRR) { Print("[TRY-RR] Rejet final RR=", DoubleToString(rr,2), " < ", InpMinRR, " | ", source); return; }

   // --- Filtre 80/20 : en consolidation, prix doit être en zone extrême (20%) ---
   if(g_msChart != NULL)
   {
      double rangeH = 0, rangeL = 0;
      if(g_msChart.IsConsolidation(rangeH, rangeL))
      {
         double cur = iClose(_Symbol, g_tfChart, 0);
         double range20 = (rangeH - rangeL) * 0.2;
         if(isBuy && cur > rangeL + range20)
         { Print("[TRY-8020] Rejet 80/20 BUY: prix=", cur, " | ", source); return; }
         if(!isBuy && cur < rangeH - range20)
         { Print("[TRY-8020] Rejet 80/20 SELL: prix=", cur, " | ", source); return; }
      }
   }

   // ====== Flèche + Trade ======
   datetime barTime = iTime(_Symbol, (ENUM_TIMEFRAMES)Period(), 0);
   
   if(g_tradingEnabled && g_tradeManager != NULL)
   {
      bool tradeOK = false;
      string comment = StringFormat("SMC V3 %s %s", source, isBuy ? "Buy" : "Sell");
      
      if(InpUseLimitOrders)
      {
         if(isBuy)
            tradeOK = g_tradeManager.PlaceBuyLimit(entry, sl, tp, comment);
         else
            tradeOK = g_tradeManager.PlaceSellLimit(entry, sl, tp, comment);
      }
      else
      {
         double currentPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double tolerance = point * 50;
         if(MathAbs(currentPrice - entry) <= tolerance)
         {
            if(isBuy)
               tradeOK = g_tradeManager.PlaceBuyOrder(entry, sl, tp, comment);
            else
               tradeOK = g_tradeManager.PlaceSellOrder(entry, sl, tp, comment);
         }
      }
      
      if(tradeOK)
      {
         if(InpVisualMode)
            DrawStrategyArrow(barTime, entry, isBuy, source);
         Print("[TRADE] ", source, " ", (isBuy ? "BUY" : "SELL"),
               " @ ", DoubleToString(entry, _Digits),
               " | SL ", DoubleToString(sl, _Digits),
               " | TP ", DoubleToString(tp, _Digits),
               " | RR ", DoubleToString(rr, 1),
               " | Conf ", DoubleToString(bestConfidence, 0), "%");
         if(InpUseTelegram && g_telegram != NULL)
         {
            if(isBuy)
               g_telegram.SendBuySignal(entry, sl, tp, tp, rr);
            else
               g_telegram.SendSellSignal(entry, sl, tp, tp, rr);
         }
      }
   }
   else
   {
      if(InpVisualMode)
         DrawStrategyArrow(barTime, entry, isBuy, source);
      Print("[SIGNAL] ", source, " ", (isBuy ? "BUY" : "SELL"),
            " @ ", DoubleToString(entry, _Digits),
            " | SL ", DoubleToString(sl, _Digits),
            " | TP ", DoubleToString(tp, _Digits),
            " | RR ", DoubleToString(rr, 1),
            " | Conf ", DoubleToString(bestConfidence, 0), "%");
      if(InpUseTelegram && g_telegram != NULL)
      {
         if(isBuy)
            g_telegram.SendBuySignal(entry, sl, tp, tp, rr);
         else
            g_telegram.SendSellSignal(entry, sl, tp, tp, rr);
      }
   }
}

//+------------------------------------------------------------------+
//| Utilitaires fractalité                                            |
//+------------------------------------------------------------------+
bool IsFractalConfluenceForBuy()
{
   ENUM_MARKET_BIAS htfBias = g_msHTF.GetMarketBias();
   // HTF BEARISH → pas d'achat. HTF NEUTRAL ou BULLISH → OK pour acheter
   // (marché en range = on peut trader les deux côtés sur le LTF)
   if(htfBias == BIAS_BEARISH) return false;
   ENUM_MARKET_BIAS chartBias = g_msChart.GetMarketBias();
   if(chartBias != BIAS_BULLISH && chartBias != BIAS_NEUTRAL) return false;
   if(g_bosChart.HasRecentBOSTrap(10)) return false;
   return true;
}

bool IsFractalConfluenceForSell()
{
   ENUM_MARKET_BIAS htfBias = g_msHTF.GetMarketBias();
   // HTF BULLISH → pas de vente. HTF NEUTRAL ou BEARISH → OK pour vendre
   if(htfBias == BIAS_BULLISH) return false;
   ENUM_MARKET_BIAS chartBias = g_msChart.GetMarketBias();
   if(chartBias != BIAS_BEARISH && chartBias != BIAS_NEUTRAL) return false;
   if(g_bosChart.HasRecentBOSTrap(10)) return false;
   return true;
}
//+------------------------------------------------------------------+
