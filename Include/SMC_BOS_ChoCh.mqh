//+------------------------------------------------------------------+
//|                                              SMC_BOS_ChoCh.mqh |
//|                          Version 2 - Module 1 : 3 types de BOS   |
//|                                    Smart Money Concepts (SMC)   |
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""
#property version   "2.00"

#include "SMC_Structures.mqh"
#include "SMC_MarketStructure.mqh"

//+------------------------------------------------------------------+
//| Événement BOS/ChoCh - Module 1 : sous-type (classique/continuation/trap) |
//+------------------------------------------------------------------+
struct SBOSEvent
{
   datetime          time;
   double            breakPrice;
   double            levelBroken;
   int               barIndex;
   ENUM_BOS_TYPE     type;           // BOS_BULLISH/BEARISH ou CHOCH_BULLISH/BEARISH
   ENUM_BOS_SUBTYPE  subtype;        // Module 1 : BOS_SUB_CLASSIC, BOS_SUB_CONTINUATION, BOS_SUB_TRAP
   bool              isValid;
   bool              isTrap;

   void Init()
   {
      time = 0;
      breakPrice = 0.0;
      levelBroken = 0.0;
      barIndex = -1;
      type = BOS_NONE;
      subtype = BOS_SUB_NONE;
      isValid = false;
      isTrap = false;
   }
};

//+------------------------------------------------------------------+
//| Classe BOS/ChoCh - Module 1 : 3 types (classique, continuation, trap) |
//| Option HTF pour détecter BOS trap (vision fractalité)             |
//+------------------------------------------------------------------+
class CBOSChoCh
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   CMarketStructure* m_marketStructure;
   CMarketStructure* m_htfMarketStructure;  // Module 1 : optionnel, pour détecter BOS trap (HTF)

   SBOSEvent         m_bosEvents[];
   int               m_eventCount;
   ENUM_MARKET_BIAS  m_previousBias;

   bool              IsTrapBOS(SBOSEvent &bos);
   bool              IsTrapBOSWithHTF(SBOSEvent &bos);  // Module 1 : BOS contre tendance HTF = trap

public:
                     CBOSChoCh();
                    ~CBOSChoCh();

   bool              Init(string symbol, ENUM_TIMEFRAMES tf, CMarketStructure* ms, CMarketStructure* htfMS = NULL);
   void              Update(int barsToCheck = 0);  // 0 = barre courante uniquement, >0 = recalcul sur plage (sync structure)

   int               GetEventCount() { return m_eventCount; }
   bool              GetLastBOS(SBOSEvent &bos);
   bool              GetLastChoCh(SBOSEvent &bos);
   bool              GetEvent(int index, SBOSEvent &bos);

   bool              HasRecentBOSBullish(int barsLookback = 10);
   bool              HasRecentBOSBearish(int barsLookback = 10);
   bool              HasRecentChoCh(int barsLookback = 10);
   bool              HasRecentBOSTrap(int barsLookback = 10);  // Module 1

   void              DrawBOSEvents(color bosColor = clrGreen, color chochColor = clrOrange);
   void              ClearDrawings();
};

//+------------------------------------------------------------------+
CBOSChoCh::CBOSChoCh()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_marketStructure = NULL;
   m_htfMarketStructure = NULL;
   m_eventCount = 0;
   m_previousBias = BIAS_NEUTRAL;
   ArrayResize(m_bosEvents, MAX_SWING_POINTS);
}

//+------------------------------------------------------------------+
CBOSChoCh::~CBOSChoCh()
{
   ClearDrawings();
   ArrayFree(m_bosEvents);
}

//+------------------------------------------------------------------+
bool CBOSChoCh::Init(string symbol, ENUM_TIMEFRAMES tf, CMarketStructure* ms, CMarketStructure* htfMS)
{
   if(ms == NULL) return false;
   m_symbol = symbol;
   m_timeframe = tf;
   m_marketStructure = ms;
   m_htfMarketStructure = htfMS;
   m_eventCount = 0;
   // Initialiser m_previousBias avec le biais actuel (évite faux ChoCh au démarrage)
   m_previousBias = ms.GetMarketBias();
   for(int i = 0; i < MAX_SWING_POINTS; i++) m_bosEvents[i].Init();
   return true;
}

//+------------------------------------------------------------------+
//| Trap = prix revient de l'autre côté du niveau cassé (faux BOS)   |
//| Pédagogie : "le prix repasse sous/au-dessus du niveau cassé"      |
//+------------------------------------------------------------------+
bool CBOSChoCh::IsTrapBOS(SBOSEvent &bos)
{
   double currentPrice = iClose(m_symbol, m_timeframe, 0);
   if(bos.type == BOS_BULLISH || bos.type == CHOCH_BULLISH)
      return (currentPrice < bos.levelBroken);
   if(bos.type == BOS_BEARISH || bos.type == CHOCH_BEARISH)
      return (currentPrice > bos.levelBroken);
   return false;
}

//+------------------------------------------------------------------+
//| Module 1 (pratique 10 + image BOS trap) : BOS trap = structure majeure HTF n'a pas été BOS |
//| "La structure majeure qui est ici n'a pas été BOS" - on regarde de gauche à droite. |
//| Si LTF montre un BOS haussier mais le niveau clé HTF (LH en bearish) n'a pas été cassé = trap. |
//+------------------------------------------------------------------+
bool CBOSChoCh::IsTrapBOSWithHTF(SBOSEvent &bos)
{
   if(m_htfMarketStructure == NULL) return IsTrapBOS(bos);
   ENUM_MARKET_BIAS htfBias = m_htfMarketStructure.GetMarketBias();
   if(htfBias == BIAS_NEUTRAL) return IsTrapBOS(bos);
   double currentPrice = iClose(m_symbol, m_timeframe, 0);
   double htfKeyHigh = m_htfMarketStructure.GetKeyLevelHighPrice();
   double htfKeyLow = m_htfMarketStructure.GetKeyLevelLowPrice();
   if((bos.type == BOS_BULLISH || bos.type == CHOCH_BULLISH) && htfBias == BIAS_BEARISH)
   {
      if(htfKeyHigh <= 0.0) return IsTrapBOS(bos);
      return (currentPrice < htfKeyHigh);
   }
   if((bos.type == BOS_BEARISH || bos.type == CHOCH_BEARISH) && htfBias == BIAS_BULLISH)
   {
      if(htfKeyLow <= 0.0) return IsTrapBOS(bos);
      return (currentPrice > htfKeyLow);
   }
   return IsTrapBOS(bos);
}

//+------------------------------------------------------------------+
//| Mise à jour - BOS confirmé par la CLÔTURE (corps de la bougie)   |
//| barsToCheck > 0 : recalcul sur la plage visible (sync avec structure) |
//| barsToCheck = 0 : détection sur barre courante uniquement         |
//+------------------------------------------------------------------+
void CBOSChoCh::Update(int barsToCheck)
{
   if(m_marketStructure == NULL) return;

   if(barsToCheck > 0)
   {
      // --- Recalcul sur plage visible : BOS/ChoCh alignés sur les swings affichés ---
      m_eventCount = 0;
      int hCount = m_marketStructure.GetSwingHighCount();
      int lCount = m_marketStructure.GetSwingLowCount();
      double pointEps = MathMax(_Point * 10, SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10);

      // Cassure de chaque swing high (sauf le premier) : première barre qui clôture au-dessus
      for(int i = 1; i < hCount && m_eventCount < MAX_SWING_POINTS; i++)
      {
         SSwingPoint sh;
         if(!m_marketStructure.GetSwingHigh(i, sh) || !sh.isValid) continue;
         int startBar = (sh.barIndex > 0) ? (sh.barIndex - 1) : 0;
         double bosMargin = sh.price * 0.0005; // 0.05% micro-marge de confirmation
         for(int b = startBar; b >= 0; b--)
         {
            double cl = iClose(m_symbol, m_timeframe, b);
            if(cl <= sh.price + bosMargin) continue; // Close doit dépasser le niveau + marge
            // Éviter doublon même niveau
            bool dup = false;
            for(int j = 0; j < m_eventCount; j++)
               if(MathAbs(m_bosEvents[j].levelBroken - sh.price) < pointEps) { dup = true; break; }
            if(dup) break;
            SBOSEvent ev;
            ev.Init();
            ev.time = iTime(m_symbol, m_timeframe, b);
            ev.breakPrice = cl;
            ev.levelBroken = sh.price;
            ev.barIndex = b;
            ev.isValid = true;
            if(sh.type == SWING_LH || sh.type == SWING_HIGH)
               { ev.type = CHOCH_BULLISH; ev.subtype = BOS_SUB_CLASSIC; }
            else
               { ev.type = BOS_BULLISH;  ev.subtype = BOS_SUB_CONTINUATION; }
            m_bosEvents[m_eventCount] = ev;
            m_eventCount++;
            break;
         }
      }

      // Cassure de chaque swing low (sauf le premier)
      for(int i = 1; i < lCount && m_eventCount < MAX_SWING_POINTS; i++)
      {
         SSwingPoint sl;
         if(!m_marketStructure.GetSwingLow(i, sl) || !sl.isValid) continue;
         int startBar = (sl.barIndex > 0) ? (sl.barIndex - 1) : 0;
         double bosMargin = sl.price * 0.0005; // 0.05% micro-marge de confirmation
         for(int b = startBar; b >= 0; b--)
         {
            double cl = iClose(m_symbol, m_timeframe, b);
            if(cl >= sl.price - bosMargin) continue; // Close doit casser sous le niveau - marge
            bool dup = false;
            for(int j = 0; j < m_eventCount; j++)
               if(MathAbs(m_bosEvents[j].levelBroken - sl.price) < pointEps) { dup = true; break; }
            if(dup) break;
            SBOSEvent ev;
            ev.Init();
            ev.time = iTime(m_symbol, m_timeframe, b);
            ev.breakPrice = cl;
            ev.levelBroken = sl.price;
            ev.barIndex = b;
            ev.isValid = true;
            if(sl.type == SWING_HL || sl.type == SWING_LOW)
               { ev.type = CHOCH_BEARISH; ev.subtype = BOS_SUB_CLASSIC; }
            else
               { ev.type = BOS_BEARISH;  ev.subtype = BOS_SUB_CONTINUATION; }
            m_bosEvents[m_eventCount] = ev;
            m_eventCount++;
            break;
         }
      }

      // Trier les événements par temps (ancien → récent) pour cohérence affichage
      for(int i = 0; i < m_eventCount - 1; i++)
         for(int j = i + 1; j < m_eventCount; j++)
            if(m_bosEvents[j].time < m_bosEvents[i].time)
            {
               SBOSEvent tmp = m_bosEvents[i];
               m_bosEvents[i] = m_bosEvents[j];
               m_bosEvents[j] = tmp;
            }

      // Marquer les traps (prix repassé de l'autre côté du niveau)
      for(int i = 0; i < m_eventCount; i++)
      {
         if(!m_bosEvents[i].isValid) continue;
         m_bosEvents[i].isTrap = IsTrapBOSWithHTF(m_bosEvents[i]);
         if(m_bosEvents[i].isTrap) m_bosEvents[i].subtype = BOS_SUB_TRAP;
      }
      m_previousBias = m_marketStructure.GetMarketBias();
      return;
   }

   // --- Mode barre courante uniquement (comportement historique) ---
   ENUM_MARKET_BIAS currentBias = m_marketStructure.GetMarketBias();
   SSwingPoint lastHigh, lastLow, prevHigh, prevLow;
   if(!m_marketStructure.GetLastSwingHigh(lastHigh)) return;
   if(!m_marketStructure.GetLastSwingLow(lastLow)) return;
   bool hasPrevHigh = m_marketStructure.GetSwingHigh(m_marketStructure.GetSwingHighCount() - 2, prevHigh);
   bool hasPrevLow = m_marketStructure.GetSwingLow(m_marketStructure.GetSwingLowCount() - 2, prevLow);
   double currentClose = iClose(m_symbol, m_timeframe, 0);

   if(hasPrevHigh && currentClose > prevHigh.price)
   {
      bool alreadyRecorded = false;
      for(int i = 0; i < m_eventCount; i++)
         if(MathAbs(m_bosEvents[i].levelBroken - prevHigh.price) < _Point * 10) { alreadyRecorded = true; break; }
      if(!alreadyRecorded && m_eventCount < MAX_SWING_POINTS)
      {
         SBOSEvent bos;
         bos.Init();
         bos.time = iTime(m_symbol, m_timeframe, 0);
         bos.breakPrice = currentClose;
         bos.levelBroken = prevHigh.price;
         bos.barIndex = 0;
         bos.isValid = true;
         if(m_previousBias == BIAS_BEARISH || m_previousBias == BIAS_NEUTRAL)
            { bos.type = CHOCH_BULLISH; bos.subtype = BOS_SUB_CLASSIC; }
         else
            { bos.type = BOS_BULLISH;  bos.subtype = BOS_SUB_CONTINUATION; }
         m_bosEvents[m_eventCount] = bos;
         m_eventCount++;
      }
   }

   if(hasPrevLow && currentClose < prevLow.price)
   {
      bool alreadyRecorded = false;
      for(int i = 0; i < m_eventCount; i++)
         if(MathAbs(m_bosEvents[i].levelBroken - prevLow.price) < _Point * 10) { alreadyRecorded = true; break; }
      if(!alreadyRecorded && m_eventCount < MAX_SWING_POINTS)
      {
         SBOSEvent bos;
         bos.Init();
         bos.time = iTime(m_symbol, m_timeframe, 0);
         bos.breakPrice = currentClose;
         bos.levelBroken = prevLow.price;
         bos.barIndex = 0;
         bos.isValid = true;
         if(m_previousBias == BIAS_BULLISH || m_previousBias == BIAS_NEUTRAL)
            { bos.type = CHOCH_BEARISH; bos.subtype = BOS_SUB_CLASSIC; }
         else
            { bos.type = BOS_BEARISH;  bos.subtype = BOS_SUB_CONTINUATION; }
         m_bosEvents[m_eventCount] = bos;
         m_eventCount++;
      }
   }

   for(int i = MathMax(0, m_eventCount - 5); i < m_eventCount; i++)
   {
      if(m_bosEvents[i].isValid && !m_bosEvents[i].isTrap)
      {
         m_bosEvents[i].isTrap = IsTrapBOSWithHTF(m_bosEvents[i]);
         if(m_bosEvents[i].isTrap) m_bosEvents[i].subtype = BOS_SUB_TRAP;
      }
   }
   m_previousBias = currentBias;
}

//+------------------------------------------------------------------+
bool CBOSChoCh::GetLastBOS(SBOSEvent &bos)
{
   for(int i = m_eventCount - 1; i >= 0; i--)
      if((m_bosEvents[i].type == BOS_BULLISH || m_bosEvents[i].type == BOS_BEARISH) && !m_bosEvents[i].isTrap)
         { bos = m_bosEvents[i]; return true; }
   return false;
}

//+------------------------------------------------------------------+
bool CBOSChoCh::GetLastChoCh(SBOSEvent &bos)
{
   for(int i = m_eventCount - 1; i >= 0; i--)
      if((m_bosEvents[i].type == CHOCH_BULLISH || m_bosEvents[i].type == CHOCH_BEARISH) && !m_bosEvents[i].isTrap)
         { bos = m_bosEvents[i]; return true; }
   return false;
}

//+------------------------------------------------------------------+
bool CBOSChoCh::GetEvent(int index, SBOSEvent &bos)
{
   if(index < 0 || index >= m_eventCount) return false;
   bos = m_bosEvents[index];
   return true;
}

//+------------------------------------------------------------------+
bool CBOSChoCh::HasRecentBOSBullish(int barsLookback)
{
   datetime lookbackTime = iTime(m_symbol, m_timeframe, barsLookback);
   for(int i = m_eventCount - 1; i >= 0; i--)
   {
      if(m_bosEvents[i].time < lookbackTime) break;
      if(m_bosEvents[i].type == BOS_BULLISH && !m_bosEvents[i].isTrap) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool CBOSChoCh::HasRecentBOSBearish(int barsLookback)
{
   datetime lookbackTime = iTime(m_symbol, m_timeframe, barsLookback);
   for(int i = m_eventCount - 1; i >= 0; i--)
   {
      if(m_bosEvents[i].time < lookbackTime) break;
      if(m_bosEvents[i].type == BOS_BEARISH && !m_bosEvents[i].isTrap) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool CBOSChoCh::HasRecentChoCh(int barsLookback)
{
   datetime lookbackTime = iTime(m_symbol, m_timeframe, barsLookback);
   for(int i = m_eventCount - 1; i >= 0; i--)
   {
      if(m_bosEvents[i].time < lookbackTime) break;
      if((m_bosEvents[i].type == CHOCH_BULLISH || m_bosEvents[i].type == CHOCH_BEARISH) && !m_bosEvents[i].isTrap)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
bool CBOSChoCh::HasRecentBOSTrap(int barsLookback)
{
   datetime lookbackTime = iTime(m_symbol, m_timeframe, barsLookback);
   for(int i = m_eventCount - 1; i >= 0; i--)
   {
      if(m_bosEvents[i].time < lookbackTime) break;
      if(m_bosEvents[i].isTrap && m_bosEvents[i].subtype == BOS_SUB_TRAP) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
void CBOSChoCh::DrawBOSEvents(color bosColor, color chochColor)
{
   string prefix = "SMC_BOS_";
   for(int i = 0; i < m_eventCount; i++)
   {
      string name = prefix + IntegerToString(i);
      string label = "";
      color lineColor = bosColor;
      switch(m_bosEvents[i].type)
      {
         case BOS_BULLISH:  label = "BOS↑";  lineColor = bosColor; break;
         case BOS_BEARISH:  label = "BOS↓";  lineColor = bosColor; break;
         case CHOCH_BULLISH: label = "ChoCh↑"; lineColor = chochColor; break;
         case CHOCH_BEARISH: label = "ChoCh↓"; lineColor = chochColor; break;
         default: continue;
      }
      if(m_bosEvents[i].subtype == BOS_SUB_TRAP || m_bosEvents[i].isTrap) label += " TRAP";
      else if(m_bosEvents[i].subtype == BOS_SUB_CLASSIC) label += " (classique)";
      else if(m_bosEvents[i].subtype == BOS_SUB_CONTINUATION) label += " (cont.)";
      string lineName = name + "_line";
      ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, m_bosEvents[i].levelBroken);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
      ObjectCreate(0, name, OBJ_TEXT, 0, m_bosEvents[i].time, m_bosEvents[i].levelBroken);
      ObjectSetString(0, name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   }
}

//+------------------------------------------------------------------+
void CBOSChoCh::ClearDrawings()
{
   ObjectsDeleteAll(0, "SMC_BOS_");
}

//+------------------------------------------------------------------+
