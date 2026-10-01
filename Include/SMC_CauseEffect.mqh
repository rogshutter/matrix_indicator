//+------------------------------------------------------------------+
//|                                           SMC_CauseEffect.mqh    |
//|                   Version 2 - Module 4 : Cause et Effet           |
//|                                    Smart Money Concepts (SMC)     |
//+------------------------------------------------------------------+
//| Pédagogie Module 4 (images + textes complets) :                   |
//| - Accumulation = conso en BAS (processus achat Big Boyz)          |
//|   "arrête la tendance baissière, fourchette haut/bas, on pousse"  |
//| - Distribution = conso en HAUT (processus vente Big Boyz)         |
//|   "arrête la tendance haussière, fourchette haut/bas, on part"    |
//| - Réaccumulation = suite logique d'une accumulation (dans trend)  |
//| - Redistribution = suite logique d'une distribution (dans trend)  |
//| - LOI CAUSE À EFFET : cause=consolidation → effet=impulsion       |
//| - Dans la cause : détecter le FAILED, l'INTENTION, la LIQUIDITÉ   |
//| - Fractalité : causes à toutes les TF (H12→H1→M15→M5)           |
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""
#property version   "2.01"

#include "SMC_Structures.mqh"
#include "SMC_MarketStructure.mqh"
#include "SMC_BOS_ChoCh.mqh"

//+------------------------------------------------------------------+
//| Type de consolidation (Module 4)                                   |
//+------------------------------------------------------------------+
enum ENUM_CAUSE_TYPE
{
   CAUSE_NONE = 0,
   CAUSE_ACCUMULATION,        // Conso en bas → effet haussier
   CAUSE_DISTRIBUTION,        // Conso en haut → effet baissier
   CAUSE_REACCUMULATION,      // Suite logique accumulation (dans trend hausse)
   CAUSE_REDISTRIBUTION       // Suite logique distribution (dans trend baisse)
};

//+------------------------------------------------------------------+
//| Zone de Cause (Accumulation/Distribution)                          |
//+------------------------------------------------------------------+
struct SCauseZone
{
   datetime          timeStart;       // Début de la consolidation (l'arrêt)
   datetime          timeEnd;         // Fin de la conso (avant l'effet)
   double            priceHigh;       // Fourchette haute
   double            priceLow;        // Fourchette basse
   ENUM_CAUSE_TYPE   type;
   int               barStart;
   int               barEnd;

   // Éléments internes de la cause (Wyckoff simplifié)
   bool              hasFailed;       // "Le fail = 1er signe changement caractère"
   bool              hasLiqGrab;      // Prise de liquidité détectée
   bool              hasBOS;          // BOS = intention d'achat/vente
   bool              hasEffect;       // L'effet (impulsion) s'est produit

   void Init()
   {
      timeStart = 0; timeEnd = 0;
      priceHigh = 0.0; priceLow = 0.0;
      type = CAUSE_NONE;
      barStart = -1; barEnd = -1;
      hasFailed = false;
      hasLiqGrab = false;
      hasBOS = false;
      hasEffect = false;
   }
};

//+------------------------------------------------------------------+
//| Classe Cause & Effet - Module 4                                    |
//| Relie Module 1 : swings, bias, consolidation, BOS                  |
//+------------------------------------------------------------------+
class CCauseEffect
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   CMarketStructure* m_structure;
   CBOSChoCh*        m_bos;

   SCauseZone        m_zones[];
   int               m_zoneCount;
   int               m_zoneCapacity;

   void              DetectCauses(int barsToCheck);
   ENUM_CAUSE_TYPE   ClassifyZone(int barStart, int barEnd,
                                   double rangeHigh, double rangeLow);
   void              AnalyzeInternals(SCauseZone &zone);

public:
                     CCauseEffect();
                    ~CCauseEffect();

   bool              Init(string symbol, ENUM_TIMEFRAMES tf,
                          CMarketStructure* ms, CBOSChoCh* bos);
   void              Update(int barsToCheck);

   int               GetZoneCount() { return m_zoneCount; }
   bool              GetZone(int index, SCauseZone &zone);
   bool              HasRecentAccumulation(int barsLookback = 50);
   bool              HasRecentDistribution(int barsLookback = 50);

   void              DrawZones(color accumColor, color distribColor);
   void              ClearDrawings();
};

//+------------------------------------------------------------------+
CCauseEffect::CCauseEffect()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_structure = NULL;
   m_bos = NULL;
   m_zoneCount = 0;
   m_zoneCapacity = 50;
   ArrayResize(m_zones, m_zoneCapacity);
}

CCauseEffect::~CCauseEffect()
{
   ClearDrawings();
   ArrayFree(m_zones);
}

bool CCauseEffect::Init(string symbol, ENUM_TIMEFRAMES tf,
                         CMarketStructure* ms, CBOSChoCh* bos)
{
   if(ms == NULL) return false;
   m_symbol = symbol;
   m_timeframe = tf;
   m_structure = ms;
   m_bos = bos;
   m_zoneCount = 0;
   return true;
}

void CCauseEffect::Update(int barsToCheck)
{
   if(m_structure == NULL) return;
   m_zoneCount = 0;
   DetectCauses(barsToCheck);
}

//+------------------------------------------------------------------+
//| Détection des zones de cause (consolidation)                       |
//| "Le prix évolue entre deux fourchettes, il devient latéral"        |
//| Utilise les swings pour détecter les ranges structurels             |
//+------------------------------------------------------------------+
void CCauseEffect::DetectCauses(int barsToCheck)
{
   int maxBars = Bars(m_symbol, m_timeframe);
   if(barsToCheck <= 0 || barsToCheck > maxBars - 1)
      barsToCheck = MathMin(300, maxBars - 1);

   // Calcul ATR moyen pour les seuils
   double avgRange = 0;
   int atrN = MathMin(20, barsToCheck);
   for(int b = 1; b <= atrN; b++)
      avgRange += (iHigh(m_symbol, m_timeframe, b) - iLow(m_symbol, m_timeframe, b));
   if(atrN > 0) avgRange /= atrN;
   if(avgRange <= 0) return;

   // Seuil strict : une vraie consolidation = range serré pendant longtemps
   // Images pédagogiques montrent des consolidations claires, pas de mini-ranges
   int minBars = 20;                      // Minimum 20 barres (consolidation significative)
   double maxExpansion = avgRange * 2.5;  // Range max = 2.5x ATR (serré)

   int i = barsToCheck;
   while(i >= minBars && m_zoneCount < m_zoneCapacity)
   {
      double wHigh = iHigh(m_symbol, m_timeframe, i);
      double wLow = iLow(m_symbol, m_timeframe, i);
      int consoStart = i;
      int consoLen = 1;

      // Étendre tant que le prix reste dans le range
      for(int j = i - 1; j >= 0; j--)
      {
         double h = iHigh(m_symbol, m_timeframe, j);
         double l = iLow(m_symbol, m_timeframe, j);
         double newHigh = MathMax(wHigh, h);
         double newLow = MathMin(wLow, l);

         if((newHigh - newLow) > maxExpansion)
            break;  // Le prix sort du range → fin de la consolidation

         wHigh = newHigh;
         wLow = newLow;
         consoLen++;
      }

      int consoEnd = consoStart - consoLen + 1;

      if(consoLen >= minBars)
      {
         SCauseZone cz;
         cz.Init();
         cz.timeStart = iTime(m_symbol, m_timeframe, consoStart);
         cz.timeEnd = iTime(m_symbol, m_timeframe, MathMax(consoEnd, 0));
         cz.priceHigh = wHigh;
         cz.priceLow = wLow;
         cz.barStart = consoStart;
         cz.barEnd = MathMax(consoEnd, 0);

         // Classifier : Accumulation ou Distribution
         cz.type = ClassifyZone(consoStart, consoEnd, wHigh, wLow);

         if(cz.type != CAUSE_NONE)
         {
            // Analyser les éléments internes (fail, liq grab, BOS)
            AnalyzeInternals(cz);
            m_zones[m_zoneCount++] = cz;
         }

         // Sauter au-delà de cette consolidation
         i = MathMax(consoEnd - 1, 0);
      }
      else
      {
         i--;
      }
   }
}

//+------------------------------------------------------------------+
//| Classifier une zone de consolidation                               |
//| Image M4 : "Accumulation en bas sur les lows, Distribution en     |
//|             haut sur les highs"                                    |
//| Regarde ce qui s'est passé AVANT et APRÈS pour classifier         |
//+------------------------------------------------------------------+
ENUM_CAUSE_TYPE CCauseEffect::ClassifyZone(int barStart, int barEnd,
                                            double rangeHigh, double rangeLow)
{
   double rangeMid = (rangeHigh + rangeLow) / 2.0;

   // Regarder le mouvement AVANT la consolidation (tendance entrante)
   // Prendre les 10-20 barres avant le début de la conso
   int lookBefore = MathMin(20, Bars(m_symbol, m_timeframe) - barStart - 1);
   double priceBefore = iClose(m_symbol, m_timeframe, barStart + lookBefore);
   bool trendDownBefore = (priceBefore > rangeMid);  // Prix venait de plus haut = baisse
   bool trendUpBefore = (priceBefore < rangeMid);     // Prix venait de plus bas = hausse

   // Regarder l'EFFET après la consolidation
   int barAfterEnd = MathMax(barEnd - 1, 0);
   int lookAfter = MathMin(10, barAfterEnd);
   double highAfter = rangeMid;
   double lowAfter = rangeMid;
   for(int k = barAfterEnd; k >= MathMax(0, barAfterEnd - lookAfter); k--)
   {
      double h = iHigh(m_symbol, m_timeframe, k);
      double l = iLow(m_symbol, m_timeframe, k);
      if(h > highAfter) highAfter = h;
      if(l < lowAfter) lowAfter = l;
   }

   double breakUp = highAfter - rangeHigh;
   double breakDown = rangeLow - lowAfter;
   bool effectUp = (breakUp > breakDown && breakUp > 0);
   bool effectDown = (breakDown > breakUp && breakDown > 0);

   // Classification selon pédagogie :
   // - Vient d'une baisse + effet haussier = ACCUMULATION
   // - Vient d'une hausse + effet baissier = DISTRIBUTION
   // - Dans une tendance haussière + effet haussier = RÉACCUMULATION
   // - Dans une tendance baissière + effet baissier = REDISTRIBUTION

   if(trendDownBefore && effectUp)
      return CAUSE_ACCUMULATION;
   if(trendUpBefore && effectDown)
      return CAUSE_DISTRIBUTION;
   if(trendUpBefore && effectUp)
      return CAUSE_REACCUMULATION;
   if(trendDownBefore && effectDown)
      return CAUSE_REDISTRIBUTION;

   // Si pas encore d'effet clair, utiliser le biais du Module 1
   ENUM_MARKET_BIAS bias = m_structure.GetMarketBias();
   if(trendDownBefore && bias == BIAS_BULLISH) return CAUSE_ACCUMULATION;
   if(trendUpBefore && bias == BIAS_BEARISH) return CAUSE_DISTRIBUTION;

   return CAUSE_NONE;  // Pas assez d'info pour classifier
}

//+------------------------------------------------------------------+
//| Analyser l'intérieur de la cause (éléments Wyckoff simplifiés)     |
//| Image M4 : "Détecter le failed, l'intention, la prise de liq"     |
//+------------------------------------------------------------------+
void CCauseEffect::AnalyzeInternals(SCauseZone &zone)
{
   int failBar = -1;
   int liqGrabBar = -1;
   int bosBar = -1;
   int effectBar = -1;

   // --- FAILED : le prix fait un swing dans la direction opposée sans BOS ---
   for(int b = zone.barStart; b >= zone.barEnd; b--)
   {
      double lo = iLow(m_symbol, m_timeframe, b);
      double hi = iHigh(m_symbol, m_timeframe, b);

      if(zone.type == CAUSE_ACCUMULATION || zone.type == CAUSE_REACCUMULATION)
      {
         if(hi > zone.priceHigh * 0.998 && hi < zone.priceHigh * 1.002)
         { zone.hasFailed = true; failBar = b; break; }
      }
      else
      {
         if(lo < zone.priceLow * 1.002 && lo > zone.priceLow * 0.998)
         { zone.hasFailed = true; failBar = b; break; }
      }
   }

   // --- BOS / INTENTION : un BOS s'est produit dans la zone visible ---
   if(m_bos != NULL)
   {
      int bosCount = m_bos.GetEventCount();
      for(int j = 0; j < bosCount; j++)
      {
         SBOSEvent ev;
         if(!m_bos.GetEvent(j, ev)) continue;
         if(ev.time >= zone.timeStart && ev.time <= zone.timeEnd)
         {
            zone.hasBOS = true;
            // Trouver le bar index du BOS
            bosBar = iBarShift(m_symbol, m_timeframe, ev.time, false);
            break;
         }
      }
   }

   // --- PRISE DE LIQUIDITÉ : le prix dépasse brièvement la fourchette ---
   for(int b = zone.barStart; b >= zone.barEnd; b--)
   {
      double lo = iLow(m_symbol, m_timeframe, b);
      double hi = iHigh(m_symbol, m_timeframe, b);

      if(zone.type == CAUSE_ACCUMULATION || zone.type == CAUSE_REACCUMULATION)
      {
         if(lo < zone.priceLow)
         { zone.hasLiqGrab = true; liqGrabBar = b; break; }
      }
      else
      {
         if(hi > zone.priceHigh)
         { zone.hasLiqGrab = true; liqGrabBar = b; break; }
      }
   }

   // --- EFFET : vérifier si le breakout s'est produit après la zone ---
   int afterBar = MathMax(zone.barEnd - 1, 0);
   if(afterBar >= 0)
   {
      double cl = iClose(m_symbol, m_timeframe, afterBar);
      if(zone.type == CAUSE_ACCUMULATION || zone.type == CAUSE_REACCUMULATION)
         zone.hasEffect = (cl > zone.priceHigh);
      else
         zone.hasEffect = (cl < zone.priceLow);
      if(zone.hasEffect)
         effectBar = afterBar;
   }

   // --- Vérification d'ordre temporel (barres décroissantes = plus récent) ---
   // Séquence attendue : FAIL (le + ancien) → BOS/INTENTION → LIQ TAKE → EFFECT (le + récent)
   // En indices de barres : failBar > bosBar > liqGrabBar > effectBar
   if(zone.hasFailed && zone.hasBOS && failBar >= 0 && bosBar >= 0)
   {
      if(bosBar >= failBar) // BOS doit être APRÈS le fail (bar index plus petit)
         zone.hasBOS = false; // Invalider: séquence incorrecte
   }
   if(zone.hasBOS && zone.hasLiqGrab && bosBar >= 0 && liqGrabBar >= 0)
   {
      if(liqGrabBar >= bosBar) // Liq grab doit être APRÈS le BOS
         zone.hasLiqGrab = false;
   }
}

//+------------------------------------------------------------------+
bool CCauseEffect::GetZone(int index, SCauseZone &zone)
{
   if(index < 0 || index >= m_zoneCount) return false;
   zone = m_zones[index];
   return true;
}

bool CCauseEffect::HasRecentAccumulation(int barsLookback)
{
   datetime lookback = iTime(m_symbol, m_timeframe, barsLookback);
   for(int i = m_zoneCount - 1; i >= 0; i--)
      if((m_zones[i].type == CAUSE_ACCUMULATION || m_zones[i].type == CAUSE_REACCUMULATION)
         && m_zones[i].timeEnd >= lookback)
         return true;
   return false;
}

bool CCauseEffect::HasRecentDistribution(int barsLookback)
{
   datetime lookback = iTime(m_symbol, m_timeframe, barsLookback);
   for(int i = m_zoneCount - 1; i >= 0; i--)
      if((m_zones[i].type == CAUSE_DISTRIBUTION || m_zones[i].type == CAUSE_REDISTRIBUTION)
         && m_zones[i].timeEnd >= lookback)
         return true;
   return false;
}

//+------------------------------------------------------------------+
//| Dessin : fidèle aux images pédagogiques Module 4                   |
//| Accumulation = rectangle rose/lavande (en bas)                     |
//| Distribution = rectangle orange/pêche (en haut)                    |
//| Label avec le type + éléments internes détectés                    |
//+------------------------------------------------------------------+
void CCauseEffect::DrawZones(color accumColor, color distribColor)
{
   for(int i = 0; i < m_zoneCount; i++)
   {
      SCauseZone cz = m_zones[i];
      if(cz.type == CAUSE_NONE) continue;

      string name = "SMC_CE_" + IntegerToString(i);
      bool isAccum = (cz.type == CAUSE_ACCUMULATION || cz.type == CAUSE_REACCUMULATION);
      color col = isAccum ? accumColor : distribColor;

      // Rectangle de la zone (comme sur les diapos)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0,
         cz.timeStart, cz.priceHigh,
         cz.timeEnd, cz.priceLow);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);

      // Label avec type
      string lbl = name + "_lbl";
      string text = "";
      switch(cz.type)
      {
         case CAUSE_ACCUMULATION:    text = "ACCUMULATION"; break;
         case CAUSE_DISTRIBUTION:    text = "DISTRIBUTION"; break;
         case CAUSE_REACCUMULATION:  text = "RE-ACCUMULATION"; break;
         case CAUSE_REDISTRIBUTION:  text = "RE-DISTRIBUTION"; break;
         default: continue;
      }

      // Position du label : en haut pour distribution, en bas pour accumulation
      double labelPrice = isAccum ? cz.priceLow : cz.priceHigh;
      ObjectCreate(0, lbl, OBJ_TEXT, 0, cz.timeStart, labelPrice);
      ObjectSetString(0, lbl, OBJPROP_TEXT, text);
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, col);
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, lbl, OBJPROP_ANCHOR,
         isAccum ? ANCHOR_UPPER : ANCHOR_LOWER);

      // Bordure distincte pour séparer du fond
      string bd = name + "_bd";
      ObjectCreate(0, bd, OBJ_RECTANGLE, 0,
         cz.timeStart, cz.priceHigh,
         cz.timeEnd, cz.priceLow);
      ObjectSetInteger(0, bd, OBJPROP_COLOR, col);
      ObjectSetInteger(0, bd, OBJPROP_FILL, false);
      ObjectSetInteger(0, bd, OBJPROP_BACK, false);
      ObjectSetInteger(0, bd, OBJPROP_WIDTH, 2);
   }
}

//+------------------------------------------------------------------+
void CCauseEffect::ClearDrawings()
{
   ObjectsDeleteAll(0, "SMC_CE_");
}

//+------------------------------------------------------------------+
