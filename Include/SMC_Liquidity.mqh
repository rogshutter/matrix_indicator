//+------------------------------------------------------------------+
//|                                              SMC_Liquidity.mqh   |
//|                   Version 2 - Module 5 : Liquidité sur le marché  |
//|                                    Smart Money Concepts (SMC)     |
//+------------------------------------------------------------------+
//| Module 5 - Textes & pédagogie (6 fichiers) :                      |
//| 1. Intact Buyer / Intact Seller (théorie + pratique)              |
//|    High/Low non manipulés = liquidité intacte = cibles TP.       |
//|    "Sur chaque high et chaque low, il y a de la liquidité."       |
//| 2. Equal Low (EQL) / Equal High (EQH)                             |
//|    Double bottom / double top = niveaux de liquidité à sauter.   |
//|    Retail place stops sous EQL → big boys prennent la liquidité.  |
//| 3. Trendline de liquidité (théorie + pratique)                    |
//|    3+ points de touche = liquidité en attente (piège trendliners).|
//| 4. Signature de liquidité (théorie + pratique)                   |
//|    Bougie avec grande mèche = niveau de liquidité à venir chercher|
//|    → dessinée via Module 2 (InpDrawLiqSignatures).               |
//| 5. Inducement (théorie + pratique)                               |
//|    Tout LH/HL qui ne donne pas BOS majeur = inducement, doit sauter.|
//|    "Continuation" = mouvement qui ne BOS pas la structure à gauche.|
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""
#property version   "2.00"

#include "SMC_Structures.mqh"
#include "SMC_MarketStructure.mqh"
#include "SMC_BOS_ChoCh.mqh"

//+------------------------------------------------------------------+
//| Classe Liquidité - Module 5                                       |
//| Relie : Module 1 (structure, swings, BOS) pour les détections     |
//| Relie : Module 2 (signatures de liquidité déjà détectées)         |
//| Relie : Module 3 (Order Flow context pour inducement)             |
//+------------------------------------------------------------------+
class CLiquidity
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

   // Références aux modules précédents
   CMarketStructure* m_structure;      // Module 1 : swings, bias, major structure
   CBOSChoCh*        m_bos;            // Module 1 : BOS pour inducement

   // Niveaux de liquidité détectés
   SLiquidityZone    m_levels[];       // Intact, EQL, EQH, Inducement
   int               m_levelCount;
   int               m_levelCapacity;

   // Trendlines de liquidité
   STrendlineLiquidity m_trendlines[];
   int               m_trendlineCount;
   int               m_trendlineCapacity;

   // Tolérance pour EQL/EQH (calculée dynamiquement)
   double            m_eqlTolerance;

   // Méthodes internes
   void              DetectIntactLevels();
   void              DetectEqualLowsHighs();
   void              DetectTrendlineLiquidity();
   void              DetectInducements();
   void              CheckSweeps();
   double            CalcAvgRange(int bars);

public:
                     CLiquidity();
                    ~CLiquidity();

   bool              Init(string symbol, ENUM_TIMEFRAMES tf,
                          CMarketStructure* ms, CBOSChoCh* bos);
   void              Update(int barsToCheck);

   // Accesseurs niveaux
   int               GetLevelCount() { return m_levelCount; }
   bool              GetLevel(int index, SLiquidityZone &lz);
   bool              GetNearestIntactBuyer(double belowPrice, SLiquidityZone &lz);
   bool              GetNearestIntactSeller(double abovePrice, SLiquidityZone &lz);
   bool              HasUnssweptEQL();
   bool              HasUnsweptEQH();
   bool              HasActiveInducement(ENUM_OB_TYPE dir);

   // Accesseurs trendlines
   int               GetTrendlineCount() { return m_trendlineCount; }
   bool              GetTrendline(int index, STrendlineLiquidity &tl);

   // Dessin (drawTrendlines = false pour n'afficher que les niveaux Intact/EQL/EQH/Inducement)
   void              DrawLiquidity(color intactColor, color eqlColor, color eqhColor,
                                   color idmColor, color trendColor, bool drawTrendlines = true);
   void              ClearDrawings();
};

//+------------------------------------------------------------------+
CLiquidity::CLiquidity()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_structure = NULL;
   m_bos = NULL;
   m_levelCount = 0;
   m_trendlineCount = 0;
   m_levelCapacity = MAX_LIQ_LEVELS;
   m_trendlineCapacity = MAX_TRENDLINES_LIQ;
   m_eqlTolerance = 0.0;
   ArrayResize(m_levels, m_levelCapacity);
   ArrayResize(m_trendlines, m_trendlineCapacity);
}

//+------------------------------------------------------------------+
CLiquidity::~CLiquidity()
{
   ClearDrawings();
   ArrayFree(m_levels);
   ArrayFree(m_trendlines);
}

//+------------------------------------------------------------------+
bool CLiquidity::Init(string symbol, ENUM_TIMEFRAMES tf,
                       CMarketStructure* ms, CBOSChoCh* bos)
{
   if(ms == NULL) return false;
   m_symbol = symbol;
   m_timeframe = tf;
   m_structure = ms;
   m_bos = bos;
   m_levelCount = 0;
   m_trendlineCount = 0;
   return true;
}

//+------------------------------------------------------------------+
//| Calcule la range moyenne des N dernières bougies (pour tolérance)  |
//+------------------------------------------------------------------+
double CLiquidity::CalcAvgRange(int bars)
{
   double sum = 0;
   int count = MathMin(bars, Bars(m_symbol, m_timeframe) - 1);
   if(count <= 0) return SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 100;
   for(int i = 1; i <= count; i++)
      sum += (iHigh(m_symbol, m_timeframe, i) - iLow(m_symbol, m_timeframe, i));
   return sum / count;
}

//+------------------------------------------------------------------+
//| Mise à jour principale                                            |
//+------------------------------------------------------------------+
void CLiquidity::Update(int barsToCheck)
{
   if(m_structure == NULL) return;
   m_levelCount = 0;
   m_trendlineCount = 0;

   // Tolérance EQL/EQH = 25% de la range moyenne
   m_eqlTolerance = CalcAvgRange(20) * 0.25;

   // 1. Intact Buyer/Seller (chaque high/low non manipulé)
   DetectIntactLevels();

   // 2. Equal Lows / Equal Highs
   DetectEqualLowsHighs();

   // 3. Trendlines de liquidité
   DetectTrendlineLiquidity();

   // 4. Inducement (swing mineur sans BOS majeur)
   DetectInducements();

   // 5. Vérifier quels niveaux ont été pris (swept)
   CheckSweeps();
}

//+------------------------------------------------------------------+
//| Intact Buyer = low non manipulé, Intact Seller = high non manipulé|
//| "sur chaque high et chaque low non manipulés, liquidité intacte"  |
//+------------------------------------------------------------------+
void CLiquidity::DetectIntactLevels()
{
   int hCount = m_structure.GetSwingHighCount();
   int lCount = m_structure.GetSwingLowCount();

   // Intact Sellers (highs non pris)
   for(int i = 0; i < hCount && m_levelCount < m_levelCapacity; i++)
   {
      SSwingPoint sh;
      if(!m_structure.GetSwingHigh(i, sh) || !sh.isValid) continue;

      // Vérifier si ce high a été pris (une bougie a clôturé au-dessus)
      bool swept = false;
      for(int b = sh.barIndex - 1; b >= 0; b--)
      {
         if(iClose(m_symbol, m_timeframe, b) > sh.price)
         { swept = true; break; }
      }

      SLiquidityZone lz;
      lz.Init();
      lz.time = sh.time;
      lz.price = sh.price;
      lz.barIndex = sh.barIndex;
      lz.type = LIQ_INTACT_SELLER;
      lz.isSwept = swept;
      m_levels[m_levelCount++] = lz;
   }

   // Intact Buyers (lows non pris)
   for(int i = 0; i < lCount && m_levelCount < m_levelCapacity; i++)
   {
      SSwingPoint sl;
      if(!m_structure.GetSwingLow(i, sl) || !sl.isValid) continue;

      bool swept = false;
      for(int b = sl.barIndex - 1; b >= 0; b--)
      {
         if(iClose(m_symbol, m_timeframe, b) < sl.price)
         { swept = true; break; }
      }

      SLiquidityZone lz;
      lz.Init();
      lz.time = sl.time;
      lz.price = sl.price;
      lz.barIndex = sl.barIndex;
      lz.type = LIQ_INTACT_BUYER;
      lz.isSwept = swept;
      m_levels[m_levelCount++] = lz;
   }
}

//+------------------------------------------------------------------+
//| Equal Lows / Equal Highs                                          |
//| "double top/bottom = niveaux de liquidité qui doivent sauter"     |
//| 2+ lows/highs au même prix (± tolérance)                         |
//+------------------------------------------------------------------+
void CLiquidity::DetectEqualLowsHighs()
{
   int hCount = m_structure.GetSwingHighCount();
   int lCount = m_structure.GetSwingLowCount();
   double tol = m_eqlTolerance;

   // --- Equal Highs (EQH) ---
   for(int i = 0; i < hCount - 1 && m_levelCount < m_levelCapacity; i++)
   {
      SSwingPoint h1;
      if(!m_structure.GetSwingHigh(i, h1) || !h1.isValid) continue;

      for(int j = i + 1; j < hCount; j++)
      {
         SSwingPoint h2;
         if(!m_structure.GetSwingHigh(j, h2) || !h2.isValid) continue;

         if(MathAbs(h1.price - h2.price) <= tol)
         {
            // Éviter doublon : vérifier si on a déjà un EQH proche
            bool dup = false;
            for(int k = 0; k < m_levelCount; k++)
               if(m_levels[k].type == LIQ_EQH && MathAbs(m_levels[k].price - h1.price) <= tol)
               { dup = true; break; }
            if(dup) break;

            double eqPrice = (h1.price + h2.price) / 2.0;
            bool swept = false;
            int lastBar = MathMin(h1.barIndex, h2.barIndex);
            for(int b = lastBar - 1; b >= 0; b--)
            {
               if(iClose(m_symbol, m_timeframe, b) > eqPrice + tol)
               { swept = true; break; }
            }

            SLiquidityZone lz;
            lz.Init();
            lz.time = h2.time;  // Le plus récent
            lz.price = eqPrice;
            lz.barIndex = h2.barIndex;
            lz.type = LIQ_EQH;
            lz.isSwept = swept;
            m_levels[m_levelCount++] = lz;
            break;  // Un seul EQH par groupe
         }
      }
   }

   // --- Equal Lows (EQL) ---
   for(int i = 0; i < lCount - 1 && m_levelCount < m_levelCapacity; i++)
   {
      SSwingPoint l1;
      if(!m_structure.GetSwingLow(i, l1) || !l1.isValid) continue;

      for(int j = i + 1; j < lCount; j++)
      {
         SSwingPoint l2;
         if(!m_structure.GetSwingLow(j, l2) || !l2.isValid) continue;

         if(MathAbs(l1.price - l2.price) <= tol)
         {
            bool dup = false;
            for(int k = 0; k < m_levelCount; k++)
               if(m_levels[k].type == LIQ_EQL && MathAbs(m_levels[k].price - l1.price) <= tol)
               { dup = true; break; }
            if(dup) break;

            double eqPrice = (l1.price + l2.price) / 2.0;
            bool swept = false;
            int lastBar = MathMin(l1.barIndex, l2.barIndex);
            for(int b = lastBar - 1; b >= 0; b--)
            {
               if(iClose(m_symbol, m_timeframe, b) < eqPrice - tol)
               { swept = true; break; }
            }

            SLiquidityZone lz;
            lz.Init();
            lz.time = l2.time;
            lz.price = eqPrice;
            lz.barIndex = l2.barIndex;
            lz.type = LIQ_EQL;
            lz.isSwept = swept;
            m_levels[m_levelCount++] = lz;
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Trendline de Liquidité                                            |
//| "3 points de touche = un max de retails vont placer des ordres"   |
//| Relie 3+ swing lows (support) ou highs (résistance) en trendline |
//+------------------------------------------------------------------+
void CLiquidity::DetectTrendlineLiquidity()
{
   int hCount = m_structure.GetSwingHighCount();
   int lCount = m_structure.GetSwingLowCount();
   double tol = m_eqlTolerance;

   // --- Trendlines support (3+ swing lows ascendants) ---
   if(lCount >= 3)
   {
      for(int start = 0; start <= lCount - 3 && m_trendlineCount < m_trendlineCapacity; start++)
      {
         SSwingPoint s1, s2;
         if(!m_structure.GetSwingLow(start, s1)) continue;
         if(!m_structure.GetSwingLow(start + 1, s2)) continue;
         if(!s1.isValid || !s2.isValid) continue;

         // Vérifier direction (ascendante pour support)
         if(s2.price <= s1.price - tol) continue;

         int touches = 2;
         SSwingPoint last = s2;

         // Chercher des points supplémentaires sur la même ligne
         for(int k = start + 2; k < lCount; k++)
         {
            SSwingPoint sk;
            if(!m_structure.GetSwingLow(k, sk) || !sk.isValid) continue;

            // Interpoler le prix attendu sur la trendline au temps de sk
            double dt = (double)(last.time - s1.time);
            if(dt <= 0) continue;
            double slope = (last.price - s1.price) / dt;
            double expected = s1.price + slope * (double)(sk.time - s1.time);

            if(MathAbs(sk.price - expected) <= tol * 1.5)
            {
               touches++;
               last = sk;
            }
         }

         if(touches >= 3)
         {
            // Vérifier si la trendline a été swept (prix cassé en dessous)
            bool swept = false;
            for(int b = last.barIndex - 1; b >= 0; b--)
            {
               double dt2 = (double)(last.time - s1.time);
               if(dt2 <= 0) break;
               double slope2 = (last.price - s1.price) / dt2;
               datetime tBar = iTime(m_symbol, m_timeframe, b);
               double tlPrice = s1.price + slope2 * (double)(tBar - s1.time);
               if(iClose(m_symbol, m_timeframe, b) < tlPrice - tol)
               { swept = true; break; }
            }

            STrendlineLiquidity tl;
            tl.Init();
            tl.time1 = s1.time;
            tl.time2 = last.time;
            tl.price1 = s1.price;
            tl.price2 = last.price;
            tl.barIndex1 = s1.barIndex;
            tl.barIndex2 = last.barIndex;
            tl.touchCount = touches;
            tl.isSupport = true;
            tl.isSwept = swept;
            m_trendlines[m_trendlineCount++] = tl;
            break;  // Une trendline support par scan
         }
      }
   }

   // --- Trendlines résistance (3+ swing highs descendants) ---
   if(hCount >= 3)
   {
      for(int start = 0; start <= hCount - 3 && m_trendlineCount < m_trendlineCapacity; start++)
      {
         SSwingPoint s1, s2;
         if(!m_structure.GetSwingHigh(start, s1)) continue;
         if(!m_structure.GetSwingHigh(start + 1, s2)) continue;
         if(!s1.isValid || !s2.isValid) continue;

         if(s2.price >= s1.price + tol) continue;

         int touches = 2;
         SSwingPoint last = s2;

         for(int k = start + 2; k < hCount; k++)
         {
            SSwingPoint sk;
            if(!m_structure.GetSwingHigh(k, sk) || !sk.isValid) continue;

            double dt = (double)(last.time - s1.time);
            if(dt <= 0) continue;
            double slope = (last.price - s1.price) / dt;
            double expected = s1.price + slope * (double)(sk.time - s1.time);

            if(MathAbs(sk.price - expected) <= tol * 1.5)
            {
               touches++;
               last = sk;
            }
         }

         if(touches >= 3)
         {
            bool swept = false;
            for(int b = last.barIndex - 1; b >= 0; b--)
            {
               double dt2 = (double)(last.time - s1.time);
               if(dt2 <= 0) break;
               double slope2 = (last.price - s1.price) / dt2;
               datetime tBar = iTime(m_symbol, m_timeframe, b);
               double tlPrice = s1.price + slope2 * (double)(tBar - s1.time);
               if(iClose(m_symbol, m_timeframe, b) > tlPrice + tol)
               { swept = true; break; }
            }

            STrendlineLiquidity tl;
            tl.Init();
            tl.time1 = s1.time;
            tl.time2 = last.time;
            tl.price1 = s1.price;
            tl.price2 = last.price;
            tl.barIndex1 = s1.barIndex;
            tl.barIndex2 = last.barIndex;
            tl.touchCount = touches;
            tl.isSupport = false;
            tl.isSwept = swept;
            m_trendlines[m_trendlineCount++] = tl;
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Inducement = swing mineur qui ne donne pas BOS majeur             |
//| "tout LH/HL dans une structure qui ne donne pas BOS = inducement" |
//| "c'est de la liquidité qui doit sauter avant le vrai mouvement"   |
//| Relie Module 1 : compare chaque swing avec la structure majeure   |
//+------------------------------------------------------------------+
void CLiquidity::DetectInducements()
{
   int hCount = m_structure.GetSwingHighCount();
   int lCount = m_structure.GetSwingLowCount();
   ENUM_MARKET_BIAS bias = m_structure.GetMarketBias();

   // En tendance baissière : les LH qui ne cassent pas la structure majeure = inducement
   // En tendance haussière : les HL qui ne cassent pas la structure majeure = inducement

   SSwingPoint majorHigh, majorLow;
   bool hasMajorHigh = m_structure.GetMajorSwingHigh(majorHigh);
   bool hasMajorLow = m_structure.GetMajorSwingLow(majorLow);

   if(bias == BIAS_BEARISH && hasMajorHigh)
   {
      // Chaque LH non-majeur = inducement (ne BOS pas au-dessus du major LH)
      for(int i = 0; i < hCount && m_levelCount < m_levelCapacity; i++)
      {
         SSwingPoint sh;
         if(!m_structure.GetSwingHigh(i, sh) || !sh.isValid) continue;
         if(sh.isMajor) continue;  // Majeur = pas inducement
         if(sh.type != SWING_LH) continue;  // Seuls les LH comptent

         // Ce LH est en dessous du major → pas de BOS majeur → inducement
         if(sh.price < majorHigh.price)
         {
            // Vérifier s'il a été pris
            bool swept = false;
            for(int b = sh.barIndex - 1; b >= 0; b--)
            {
               if(iHigh(m_symbol, m_timeframe, b) > sh.price)
               { swept = true; break; }
            }

            SLiquidityZone lz;
            lz.Init();
            lz.time = sh.time;
            lz.price = sh.price;
            lz.barIndex = sh.barIndex;
            lz.type = LIQ_INDUCEMENT;
            lz.isSwept = swept;
            m_levels[m_levelCount++] = lz;
         }
      }
   }
   else if(bias == BIAS_BULLISH && hasMajorLow)
   {
      // Chaque HL non-majeur = inducement (ne BOS pas en dessous du major HL)
      for(int i = 0; i < lCount && m_levelCount < m_levelCapacity; i++)
      {
         SSwingPoint sl;
         if(!m_structure.GetSwingLow(i, sl) || !sl.isValid) continue;
         if(sl.isMajor) continue;
         if(sl.type != SWING_HL) continue;

         if(sl.price > majorLow.price)
         {
            bool swept = false;
            for(int b = sl.barIndex - 1; b >= 0; b--)
            {
               if(iLow(m_symbol, m_timeframe, b) < sl.price)
               { swept = true; break; }
            }

            SLiquidityZone lz;
            lz.Init();
            lz.time = sl.time;
            lz.price = sl.price;
            lz.barIndex = sl.barIndex;
            lz.type = LIQ_INDUCEMENT;
            lz.isSwept = swept;
            m_levels[m_levelCount++] = lz;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier quels niveaux ont été swept (pris) par le prix courant   |
//+------------------------------------------------------------------+
void CLiquidity::CheckSweeps()
{
   double curHigh = iHigh(m_symbol, m_timeframe, 0);
   double curLow = iLow(m_symbol, m_timeframe, 0);
   datetime curTime = iTime(m_symbol, m_timeframe, 0);

   for(int i = 0; i < m_levelCount; i++)
   {
      if(m_levels[i].isSwept) continue;

      switch(m_levels[i].type)
      {
         case LIQ_INTACT_SELLER:
         case LIQ_EQH:
            if(curHigh > m_levels[i].price)
            { m_levels[i].isSwept = true; m_levels[i].sweepTime = curTime; }
            break;
         case LIQ_INTACT_BUYER:
         case LIQ_EQL:
            if(curLow < m_levels[i].price)
            { m_levels[i].isSwept = true; m_levels[i].sweepTime = curTime; }
            break;
         case LIQ_INDUCEMENT:
            // Inducement swept quand le prix le traverse
            if(curHigh > m_levels[i].price || curLow < m_levels[i].price)
            { m_levels[i].isSwept = true; m_levels[i].sweepTime = curTime; }
            break;
         default: break;
      }
   }
}

//+------------------------------------------------------------------+
//| Accesseurs                                                         |
//+------------------------------------------------------------------+
bool CLiquidity::GetLevel(int index, SLiquidityZone &lz)
{
   if(index < 0 || index >= m_levelCount) return false;
   lz = m_levels[index];
   return true;
}

bool CLiquidity::GetNearestIntactBuyer(double belowPrice, SLiquidityZone &lz)
{
   double bestPrice = -1;
   int bestIdx = -1;
   for(int i = 0; i < m_levelCount; i++)
   {
      if(m_levels[i].type != LIQ_INTACT_BUYER || m_levels[i].isSwept) continue;
      if(m_levels[i].price < belowPrice && m_levels[i].price > bestPrice)
      { bestPrice = m_levels[i].price; bestIdx = i; }
   }
   if(bestIdx >= 0) { lz = m_levels[bestIdx]; return true; }
   return false;
}

bool CLiquidity::GetNearestIntactSeller(double abovePrice, SLiquidityZone &lz)
{
   double bestPrice = DBL_MAX;
   int bestIdx = -1;
   for(int i = 0; i < m_levelCount; i++)
   {
      if(m_levels[i].type != LIQ_INTACT_SELLER || m_levels[i].isSwept) continue;
      if(m_levels[i].price > abovePrice && m_levels[i].price < bestPrice)
      { bestPrice = m_levels[i].price; bestIdx = i; }
   }
   if(bestIdx >= 0) { lz = m_levels[bestIdx]; return true; }
   return false;
}

bool CLiquidity::HasUnssweptEQL()
{
   for(int i = 0; i < m_levelCount; i++)
      if(m_levels[i].type == LIQ_EQL && !m_levels[i].isSwept) return true;
   return false;
}

bool CLiquidity::HasUnsweptEQH()
{
   for(int i = 0; i < m_levelCount; i++)
      if(m_levels[i].type == LIQ_EQH && !m_levels[i].isSwept) return true;
   return false;
}

bool CLiquidity::HasActiveInducement(ENUM_OB_TYPE dir)
{
   for(int i = 0; i < m_levelCount; i++)
   {
      if(m_levels[i].type != LIQ_INDUCEMENT || m_levels[i].isSwept) continue;
      // En bearish, inducement = LH (au-dessus) → dir = OB_BEARISH
      // En bullish, inducement = HL (en dessous) → dir = OB_BULLISH
      return true;
   }
   return false;
}

bool CLiquidity::GetTrendline(int index, STrendlineLiquidity &tl)
{
   if(index < 0 || index >= m_trendlineCount) return false;
   tl = m_trendlines[index];
   return true;
}

//+------------------------------------------------------------------+
//| Dessin de tous les niveaux de liquidité                            |
//| Visuels fidèles aux textes et images Module 5 (Intact, EQL, EQH,   |
//| Inducement, Trendline de liquidité).                              |
//+------------------------------------------------------------------+
void CLiquidity::DrawLiquidity(color intactColor, color eqlColor, color eqhColor,
                                color idmColor, color trendColor, bool drawTrendlines)
{
   datetime timeEnd = iTime(m_symbol, m_timeframe, 0) + PeriodSeconds(m_timeframe) * 10;
   long pSec = PeriodSeconds(m_timeframe);
   if(pSec <= 0) pSec = 300;
   datetime markLen = (datetime)(pSec * 5);  // Longueur des marques courtes

   for(int i = 0; i < m_levelCount; i++)
   {
      SLiquidityZone lz = m_levels[i];
      if(lz.isSwept) continue;

      string name = "SMC_LIQ_" + IntegerToString(i);

      switch(lz.type)
      {
         // --- INTACT BUYER / INTACT SELLER (texte M5) ---
         // Ligne pointillée horizontale = cible TP (high/low non manipulé)
         case LIQ_INTACT_SELLER:
         case LIQ_INTACT_BUYER:
         {
            string ln = name + "_ln";
            ObjectCreate(0, ln, OBJ_TREND, 0,
               lz.time, lz.price, timeEnd, lz.price);
            ObjectSetInteger(0, ln, OBJPROP_COLOR, intactColor);
            ObjectSetInteger(0, ln, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, ln, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, ln, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, ln, OBJPROP_BACK, true);

            string lb = (lz.type == LIQ_INTACT_SELLER) ? "Intact Seller" : "Intact Buyer";
            ObjectCreate(0, name, OBJ_TEXT, 0, lz.time, lz.price);
            ObjectSetString(0, name, OBJPROP_TEXT, lb);
            ObjectSetInteger(0, name, OBJPROP_COLOR, intactColor);
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
            ObjectSetInteger(0, name, OBJPROP_ANCHOR,
               (lz.type == LIQ_INTACT_SELLER) ? ANCHOR_LOWER : ANCHOR_UPPER);
            break;
         }

         // --- Equal High (texte M5 : double top = liquidité à sauter) ---
         case LIQ_EQH:
         {
            // Ligne de connexion étendue vers la droite
            string ln = name + "_ln";
            ObjectCreate(0, ln, OBJ_TREND, 0,
               lz.time, lz.price, timeEnd, lz.price);
            ObjectSetInteger(0, ln, OBJPROP_COLOR, eqhColor);
            ObjectSetInteger(0, ln, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, ln, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, ln, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, ln, OBJPROP_BACK, true);

            // Label "EQH"
            ObjectCreate(0, name, OBJ_TEXT, 0, lz.time, lz.price);
            ObjectSetString(0, name, OBJPROP_TEXT, "EQH");
            ObjectSetInteger(0, name, OBJPROP_COLOR, eqhColor);
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LOWER);
            break;
         }

         // --- Equal Low (texte M5 : double bottom = liquidité à sauter) ---
         case LIQ_EQL:
         {
            string ln = name + "_ln";
            ObjectCreate(0, ln, OBJ_TREND, 0,
               lz.time, lz.price, timeEnd, lz.price);
            ObjectSetInteger(0, ln, OBJPROP_COLOR, eqlColor);
            ObjectSetInteger(0, ln, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, ln, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, ln, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, ln, OBJPROP_BACK, true);

            ObjectCreate(0, name, OBJ_TEXT, 0, lz.time, lz.price);
            ObjectSetString(0, name, OBJPROP_TEXT, "EQL");
            ObjectSetInteger(0, name, OBJPROP_COLOR, eqlColor);
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
            break;
         }

         // --- Inducement (texte M5 : LH/HL qui ne donne pas BOS majeur = doit sauter) ---
         // Label "INDUCEMENT" en bleu comme sur les diapos
         case LIQ_INDUCEMENT:
         {
            // Flèche orange horizontale longue
            string ln = name + "_ln";
            ObjectCreate(0, ln, OBJ_TREND, 0,
               lz.time, lz.price, timeEnd, lz.price);
            ObjectSetInteger(0, ln, OBJPROP_COLOR, idmColor);
            ObjectSetInteger(0, ln, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, ln, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, ln, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, ln, OBJPROP_BACK, false);

            // Label "INDUCEMENT" en bleu (comme sur les images)
            ObjectCreate(0, name, OBJ_TEXT, 0, lz.time, lz.price);
            ObjectSetString(0, name, OBJPROP_TEXT, "INDUCEMENT");
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
            // Si bearish (LH non-major) = au-dessus, sinon en-dessous
            ENUM_MARKET_BIAS bias = m_structure.GetMarketBias();
            ObjectSetInteger(0, name, OBJPROP_ANCHOR,
               (bias == BIAS_BEARISH) ? ANCHOR_LOWER : ANCHOR_UPPER);
            break;
         }

         default: continue;
      }
   }

   // --- Trendlines de liquidité (texte M5 : 3+ points de touche = liquidité en attente) ---
   if(drawTrendlines)
   {
      for(int i = 0; i < m_trendlineCount; i++)
      {
         if(m_trendlines[i].isSwept) continue;

         STrendlineLiquidity tl = m_trendlines[i];
         string name = "SMC_TL_" + IntegerToString(i);

         // Extension 30% au-delà du dernier point
         double dt = (double)(tl.time2 - tl.time1);
         double slope = (dt > 0) ? (tl.price2 - tl.price1) / dt : 0;
         datetime extTime = tl.time2 + (datetime)(dt * 0.3);
         double extPrice = tl.price2 + slope * (double)(dt * 0.3);

         ObjectCreate(0, name, OBJ_TREND, 0,
            tl.time1, tl.price1, extTime, extPrice);
         ObjectSetInteger(0, name, OBJPROP_COLOR, trendColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);

         // Label "Trendline Liq (N)" comme dans le module 5
         string lbl = name + "_lbl";
         ObjectCreate(0, lbl, OBJ_TEXT, 0, tl.time2, tl.price2);
         ObjectSetString(0, lbl, OBJPROP_TEXT,
            "Trendline Liq (" + IntegerToString(tl.touchCount) + ")");
         ObjectSetInteger(0, lbl, OBJPROP_COLOR, trendColor);
         ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 7);
         ObjectSetInteger(0, lbl, OBJPROP_ANCHOR,
            tl.isSupport ? ANCHOR_UPPER : ANCHOR_LOWER);
      }
   }
}

//+------------------------------------------------------------------+
void CLiquidity::ClearDrawings()
{
   ObjectsDeleteAll(0, "SMC_LIQ_");
   ObjectsDeleteAll(0, "SMC_TL_");
}

//+------------------------------------------------------------------+
