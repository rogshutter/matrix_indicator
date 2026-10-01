//+------------------------------------------------------------------+
//|                                              SMC_CandleTypes.mqh |
//|                          Version 2 - Module 2 : Types de bougies  |
//|                   Bougie Manipulatrice, BQA, Signatures Algo       |
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""
#property version   "2.02"

#include "SMC_Structures.mqh"

//+------------------------------------------------------------------+
//| Types de bougies SMV                                              |
//+------------------------------------------------------------------+
enum ENUM_SMV_CANDLE_TYPE
{
   CANDLE_NONE = 0,
   CANDLE_MANIPULATRICE,     // Bougie pleine/presque pleine (manipulation)
   CANDLE_BQA,               // Bougie Qui Prend l'Argent (mèche la plus extrême)
   CANDLE_DOJI_SIGNATURE,    // Doji Signature (trace algorithmique)
   CANDLE_SIGNATURE_LIQUIDITE // Signature de liquidité (grande mèche derrière corps)
};

//+------------------------------------------------------------------+
//| Direction de la bougie SMV                                        |
//+------------------------------------------------------------------+
enum ENUM_CANDLE_DIRECTION
{
   CANDLE_DIR_NONE = 0,
   CANDLE_DIR_BULLISH,       // Bougie haussière
   CANDLE_DIR_BEARISH        // Bougie baissière
};

//+------------------------------------------------------------------+
//| Zone d'Offre ou de Demande (Supply/Demand)                        |
//+------------------------------------------------------------------+
struct SSupplyDemandZone
{
   datetime          timeStart;      // Bougie manipulatrice
   datetime          timeEnd;        // Bougie BQA
   double            priceHigh;      // Borne haute de la zone
   double            priceLow;       // Borne basse de la zone
   ENUM_OB_TYPE      direction;      // OB_BULLISH = demand, OB_BEARISH = supply
   ENUM_ZONE_STATUS  status;         // Active, testée, mitiguée
   bool              hasDoji;        // Contient un Doji Signature
   int               barIndexManip;  // Index bougie manipulatrice
   int               barIndexBQA;    // Index BQA

   void Init()
   {
      timeStart = 0; timeEnd = 0;
      priceHigh = 0; priceLow = 0;
      direction = OB_NONE;
      status = ZONE_ACTIVE;
      hasDoji = false;
      barIndexManip = -1; barIndexBQA = -1;
   }
};

//+------------------------------------------------------------------+
//| Signature de liquidité (grande mèche = liquidité en attente)      |
//+------------------------------------------------------------------+
struct SLiquiditySignature
{
   datetime          time;
   double            wickPrice;      // Prix extrême de la mèche (target)
   double            bodyPrice;      // Prix du corps côté mèche
   bool              isAbove;        // true = mèche au-dessus (target acheteur), false = en-dessous
   int               barIndex;
   bool              isSwept;        // Liquidité déjà prise ?

   void Init()
   {
      time = 0; wickPrice = 0; bodyPrice = 0;
      isAbove = false; barIndex = -1; isSwept = false;
   }
};

//+------------------------------------------------------------------+
//| Classe de détection des types de bougies SMV (Module 2)           |
//+------------------------------------------------------------------+
class CCandleTypes
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

   // Paramètres
   double            m_manipBodyRatio;    // Ratio corps/range min pour bougie manipulatrice (0.70)
   double            m_dojiBodyRatio;     // Ratio corps/range max pour doji (0.15)
   double            m_liqWickRatio;      // Ratio mèche/range min pour signature liquidité (0.60)

   // Zones détectées
   SSupplyDemandZone m_zones[];
   int               m_zoneCount;
   int               m_zoneCapacity;

   // Signatures de liquidité
   SLiquiditySignature m_liqSigs[];
   int               m_liqCount;
   int               m_liqCapacity;

   // Méthodes internes
   bool              IsBougieManipulatrice(int barIndex, ENUM_CANDLE_DIRECTION &dir);
   bool              IsDoji(int barIndex);
   bool              HasLargeWick(int barIndex, bool &wickAbove);
   double            GetBodySize(int barIndex);
   double            GetCandleRange(int barIndex);
   double            GetUpperWick(int barIndex);
   double            GetLowerWick(int barIndex);

public:
                     CCandleTypes();
                    ~CCandleTypes();

   bool              Init(string symbol, ENUM_TIMEFRAMES tf,
                          double manipRatio = 0.70, double dojiRatio = 0.15, double liqWickRatio = 0.60);
   void              Update(int barsToCheck = 0);

   // Accesseurs zones
   int               GetZoneCount() { return m_zoneCount; }
   bool              GetZone(int index, SSupplyDemandZone &zone);
   bool              GetLastSupplyZone(SSupplyDemandZone &zone);
   bool              GetLastDemandZone(SSupplyDemandZone &zone);
   bool              IsPriceInSupplyZone(double price, SSupplyDemandZone &zone);
   bool              IsPriceInDemandZone(double price, SSupplyDemandZone &zone);

   // Accesseurs signatures liquidité
   int               GetLiqSigCount() { return m_liqCount; }
   bool              GetLiqSig(int index, SLiquiditySignature &sig);

   // Dessin
   void              DrawZones(color supplyColor = C'180,0,0', color demandColor = C'0,128,0');
   void              DrawLiqSignatures(color col = clrGold);
   void              ClearDrawings();
};

//+------------------------------------------------------------------+
CCandleTypes::CCandleTypes()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_manipBodyRatio = 0.70;
   m_dojiBodyRatio = 0.15;
   m_liqWickRatio = 0.60;
   m_zoneCount = 0;
   m_liqCount = 0;
   m_zoneCapacity = 200;
   m_liqCapacity = 200;
   ArrayResize(m_zones, m_zoneCapacity);
   ArrayResize(m_liqSigs, m_liqCapacity);
}

CCandleTypes::~CCandleTypes()
{
   ClearDrawings();
   ArrayFree(m_zones);
   ArrayFree(m_liqSigs);
}

//+------------------------------------------------------------------+
bool CCandleTypes::Init(string symbol, ENUM_TIMEFRAMES tf,
                        double manipRatio, double dojiRatio, double liqWickRatio)
{
   m_symbol = symbol;
   m_timeframe = tf;
   m_manipBodyRatio = manipRatio;
   m_dojiBodyRatio = dojiRatio;
   m_liqWickRatio = liqWickRatio;
   m_zoneCount = 0;
   m_liqCount = 0;
   return true;
}

//+------------------------------------------------------------------+
double CCandleTypes::GetBodySize(int barIndex)
{
   return MathAbs(iClose(m_symbol, m_timeframe, barIndex) - iOpen(m_symbol, m_timeframe, barIndex));
}

double CCandleTypes::GetCandleRange(int barIndex)
{
   return iHigh(m_symbol, m_timeframe, barIndex) - iLow(m_symbol, m_timeframe, barIndex);
}

double CCandleTypes::GetUpperWick(int barIndex)
{
   double high = iHigh(m_symbol, m_timeframe, barIndex);
   double bodyTop = MathMax(iOpen(m_symbol, m_timeframe, barIndex), iClose(m_symbol, m_timeframe, barIndex));
   return high - bodyTop;
}

double CCandleTypes::GetLowerWick(int barIndex)
{
   double low = iLow(m_symbol, m_timeframe, barIndex);
   double bodyBot = MathMin(iOpen(m_symbol, m_timeframe, barIndex), iClose(m_symbol, m_timeframe, barIndex));
   return bodyBot - low;
}

//+------------------------------------------------------------------+
//| Bougie manipulatrice : corps >= 70% du range (presque pleine)     |
//+------------------------------------------------------------------+
bool CCandleTypes::IsBougieManipulatrice(int barIndex, ENUM_CANDLE_DIRECTION &dir)
{
   double range = GetCandleRange(barIndex);
   if(range <= 0) return false;
   double body = GetBodySize(barIndex);
   if(body / range < m_manipBodyRatio) return false;

   double open = iOpen(m_symbol, m_timeframe, barIndex);
   double close = iClose(m_symbol, m_timeframe, barIndex);
   dir = (close > open) ? CANDLE_DIR_BULLISH : CANDLE_DIR_BEARISH;
   return true;
}

//+------------------------------------------------------------------+
//| Doji signature : corps <= 15% du range (petit corps, longues mèches) |
//+------------------------------------------------------------------+
bool CCandleTypes::IsDoji(int barIndex)
{
   double range = GetCandleRange(barIndex);
   if(range <= 0) return false;
   double body = GetBodySize(barIndex);
   return (body / range <= m_dojiBodyRatio);
}

//+------------------------------------------------------------------+
//| Signature de liquidité : grande mèche (>= 60% du range)          |
//+------------------------------------------------------------------+
bool CCandleTypes::HasLargeWick(int barIndex, bool &wickAbove)
{
   double range = GetCandleRange(barIndex);
   if(range <= 0) return false;
   double upperW = GetUpperWick(barIndex);
   double lowerW = GetLowerWick(barIndex);

   if(upperW / range >= m_liqWickRatio) { wickAbove = true; return true; }
   if(lowerW / range >= m_liqWickRatio) { wickAbove = false; return true; }
   return false;
}

//+------------------------------------------------------------------+
//| Update : scanner les bougies et détecter zones + signatures       |
//+------------------------------------------------------------------+
void CCandleTypes::Update(int barsToCheck)
{
   int maxBars = Bars(m_symbol, m_timeframe);
   if(barsToCheck <= 0 || barsToCheck > maxBars)
      barsToCheck = MathMin(200, maxBars);
   else
      barsToCheck = MathMin(barsToCheck, maxBars);

   m_zoneCount = 0;
   m_liqCount = 0;

   // Redimensionner si nécessaire
   int est = barsToCheck / 5 + 50;
   if(est > m_zoneCapacity) { m_zoneCapacity = est; ArrayResize(m_zones, m_zoneCapacity); }
   if(est > m_liqCapacity)  { m_liqCapacity = est;  ArrayResize(m_liqSigs, m_liqCapacity); }

   // Scanner du plus ancien au plus récent
   for(int i = barsToCheck - 1; i >= 2; i--)
   {
      ENUM_CANDLE_DIRECTION dir = CANDLE_DIR_NONE;

      // --- Détection bougie manipulatrice + BQA → zone d'offre/demande ---
      if(IsBougieManipulatrice(i, dir))
      {
         // La BQA est la bougie juste à côté (i-1) qui a la mèche/corps le plus extrême
         // OU un Doji signature adjacent
         int bqaIndex = i - 1;
         if(bqaIndex < 0) continue;

         bool bqaIsDoji = IsDoji(bqaIndex);

         SSupplyDemandZone zone;
         zone.Init();
         zone.barIndexManip = i;
         zone.barIndexBQA = bqaIndex;
         zone.timeStart = iTime(m_symbol, m_timeframe, i);
         zone.timeEnd = iTime(m_symbol, m_timeframe, bqaIndex);
         zone.hasDoji = bqaIsDoji;

         if(dir == CANDLE_DIR_BEARISH)
         {
            // Bougie manipulatrice baissière → Zone d'OFFRE (vente)
            // Haut = max(mèche haute BQA, mèche haute manip)
            // Bas = bas de la bougie manipulatrice (open = haut du corps bear)
            zone.direction = OB_BEARISH;
            zone.priceHigh = MathMax(iHigh(m_symbol, m_timeframe, i), iHigh(m_symbol, m_timeframe, bqaIndex));
            zone.priceLow = MathMin(iOpen(m_symbol, m_timeframe, i), iClose(m_symbol, m_timeframe, i));
            // Vérifier que le prix est parti en baisse après (confirmation)
            if(bqaIndex - 1 >= 0 && iClose(m_symbol, m_timeframe, bqaIndex - 1) < zone.priceLow)
               zone.status = ZONE_ACTIVE;
            else
               continue;  // Pas de confirmation
         }
         else if(dir == CANDLE_DIR_BULLISH)
         {
            // Bougie manipulatrice haussière → Zone de DEMANDE (achat)
            // Bas = min(mèche basse BQA, mèche basse manip)
            // Haut = haut de la bougie manipulatrice (corps)
            zone.direction = OB_BULLISH;
            zone.priceLow = MathMin(iLow(m_symbol, m_timeframe, i), iLow(m_symbol, m_timeframe, bqaIndex));
            zone.priceHigh = MathMax(iOpen(m_symbol, m_timeframe, i), iClose(m_symbol, m_timeframe, i));
            if(bqaIndex - 1 >= 0 && iClose(m_symbol, m_timeframe, bqaIndex - 1) > zone.priceHigh)
               zone.status = ZONE_ACTIVE;
            else
               continue;
         }

         // Vérifier mitigation (prix a traversé la zone depuis)
         for(int j = bqaIndex - 1; j >= 0; j--)
         {
            if(zone.direction == OB_BEARISH && iClose(m_symbol, m_timeframe, j) > zone.priceHigh)
            {
               zone.status = ZONE_MITIGATED;
               break;
            }
            if(zone.direction == OB_BULLISH && iClose(m_symbol, m_timeframe, j) < zone.priceLow)
            {
               zone.status = ZONE_MITIGATED;
               break;
            }
         }

         if(m_zoneCount < m_zoneCapacity)
         {
            m_zones[m_zoneCount] = zone;
            m_zoneCount++;
         }
      }

      // --- Détection Doji Signature isolé (pas adjacent à une manipulatrice) ---
      if(IsDoji(i))
      {
         // Vérifier qu'il y a eu une impulsion forte après (i-1 ou i-2)
         if(i - 1 >= 0)
         {
            double nextRange = GetCandleRange(i - 1);
            double dojiRange = GetCandleRange(i);
            if(nextRange > dojiRange * 2.0)  // Impulsion au moins 2x le Doji
            {
               // Créer une mini-zone au niveau du Doji
               SSupplyDemandZone zone;
               zone.Init();
               zone.barIndexManip = i;
               zone.barIndexBQA = i;
               zone.timeStart = iTime(m_symbol, m_timeframe, i);
               zone.timeEnd = iTime(m_symbol, m_timeframe, i);
               zone.hasDoji = true;
               zone.priceHigh = iHigh(m_symbol, m_timeframe, i);
               zone.priceLow = iLow(m_symbol, m_timeframe, i);

               double nextClose = iClose(m_symbol, m_timeframe, i - 1);
               double nextOpen = iOpen(m_symbol, m_timeframe, i - 1);
               zone.direction = (nextClose < nextOpen) ? OB_BEARISH : OB_BULLISH;
               zone.status = ZONE_ACTIVE;

               // Vérifier mitigation
               for(int j = i - 2; j >= 0; j--)
               {
                  if(zone.direction == OB_BEARISH && iClose(m_symbol, m_timeframe, j) > zone.priceHigh)
                  { zone.status = ZONE_MITIGATED; break; }
                  if(zone.direction == OB_BULLISH && iClose(m_symbol, m_timeframe, j) < zone.priceLow)
                  { zone.status = ZONE_MITIGATED; break; }
               }

               if(m_zoneCount < m_zoneCapacity) { m_zones[m_zoneCount] = zone; m_zoneCount++; }
            }
         }
      }

      // --- Détection Signature de Liquidité (grande mèche) ---
      bool wickAbove = false;
      if(HasLargeWick(i, wickAbove))
      {
         SLiquiditySignature sig;
         sig.Init();
         sig.time = iTime(m_symbol, m_timeframe, i);
         sig.barIndex = i;
         sig.isAbove = wickAbove;

         if(wickAbove)
         {
            sig.wickPrice = iHigh(m_symbol, m_timeframe, i);
            sig.bodyPrice = MathMax(iOpen(m_symbol, m_timeframe, i), iClose(m_symbol, m_timeframe, i));
         }
         else
         {
            sig.wickPrice = iLow(m_symbol, m_timeframe, i);
            sig.bodyPrice = MathMin(iOpen(m_symbol, m_timeframe, i), iClose(m_symbol, m_timeframe, i));
         }

         // Vérifier si la liquidité a été prise
         for(int j = i - 1; j >= 0; j--)
         {
            if(wickAbove && iHigh(m_symbol, m_timeframe, j) > sig.wickPrice)
            { sig.isSwept = true; break; }
            if(!wickAbove && iLow(m_symbol, m_timeframe, j) < sig.wickPrice)
            { sig.isSwept = true; break; }
         }

         if(m_liqCount < m_liqCapacity) { m_liqSigs[m_liqCount] = sig; m_liqCount++; }
      }
   }
}

//+------------------------------------------------------------------+
bool CCandleTypes::GetZone(int index, SSupplyDemandZone &zone)
{
   if(index < 0 || index >= m_zoneCount) return false;
   zone = m_zones[index];
   return true;
}

bool CCandleTypes::GetLastSupplyZone(SSupplyDemandZone &zone)
{
   for(int i = m_zoneCount - 1; i >= 0; i--)
      if(m_zones[i].direction == OB_BEARISH && m_zones[i].status == ZONE_ACTIVE)
      { zone = m_zones[i]; return true; }
   return false;
}

bool CCandleTypes::GetLastDemandZone(SSupplyDemandZone &zone)
{
   for(int i = m_zoneCount - 1; i >= 0; i--)
      if(m_zones[i].direction == OB_BULLISH && m_zones[i].status == ZONE_ACTIVE)
      { zone = m_zones[i]; return true; }
   return false;
}

bool CCandleTypes::IsPriceInSupplyZone(double price, SSupplyDemandZone &zone)
{
   for(int i = m_zoneCount - 1; i >= 0; i--)
      if(m_zones[i].direction == OB_BEARISH && m_zones[i].status == ZONE_ACTIVE
         && price >= m_zones[i].priceLow && price <= m_zones[i].priceHigh)
      { zone = m_zones[i]; return true; }
   return false;
}

bool CCandleTypes::IsPriceInDemandZone(double price, SSupplyDemandZone &zone)
{
   for(int i = m_zoneCount - 1; i >= 0; i--)
      if(m_zones[i].direction == OB_BULLISH && m_zones[i].status == ZONE_ACTIVE
         && price >= m_zones[i].priceLow && price <= m_zones[i].priceHigh)
      { zone = m_zones[i]; return true; }
   return false;
}

bool CCandleTypes::GetLiqSig(int index, SLiquiditySignature &sig)
{
   if(index < 0 || index >= m_liqCount) return false;
   sig = m_liqSigs[index];
   return true;
}

//+------------------------------------------------------------------+
//| Dessin des zones d'offre/demande                                   |
//+------------------------------------------------------------------+
void CCandleTypes::DrawZones(color supplyColor, color demandColor)
{
   string prefix = "SMC_SD_";
   long pSec = PeriodSeconds(m_timeframe);
   if(pSec <= 0) pSec = 300;

   for(int i = 0; i < m_zoneCount; i++)
   {
      if(m_zones[i].status == ZONE_MITIGATED) continue;

      string name = prefix + IntegerToString(i);
      color zoneColor = (m_zones[i].direction == OB_BEARISH) ? supplyColor : demandColor;

      // Zone COMPACTE : s'étend seulement ~15 barres après la fin (pas jusqu'au bord droit)
      datetime zoneEnd = m_zones[i].timeEnd + (datetime)(pSec * 15);

      ObjectCreate(0, name, OBJ_RECTANGLE, 0,
         m_zones[i].timeStart, m_zones[i].priceHigh,
         zoneEnd, m_zones[i].priceLow);
      ObjectSetInteger(0, name, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);

      // Label petit et discret
      string labelName = name + "_lbl";
      string labelText = (m_zones[i].direction == OB_BEARISH) ? "S" : "D";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, m_zones[i].timeStart, m_zones[i].priceHigh);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   }
}

//+------------------------------------------------------------------+
//| Dessin des signatures de liquidité (mèches = targets)              |
//+------------------------------------------------------------------+
void CCandleTypes::DrawLiqSignatures(color col)
{
   string prefix = "SMC_LQ_";
   for(int i = 0; i < m_liqCount; i++)
   {
      if(m_liqSigs[i].isSwept) continue;

      string name = prefix + IntegerToString(i);
      datetime timeEnd = iTime(m_symbol, m_timeframe, 0) + PeriodSeconds(m_timeframe) * 10;

      // Ligne pointillée au niveau de la mèche (target de liquidité)
      ObjectCreate(0, name, OBJ_TREND, 0, m_liqSigs[i].time, m_liqSigs[i].wickPrice, timeEnd, m_liqSigs[i].wickPrice);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);

      // Label "LIQ €"
      string lbl = name + "_lbl";
      string text = m_liqSigs[i].isAbove ? "LIQ $" : "LIQ $";
      ObjectCreate(0, lbl, OBJ_TEXT, 0, m_liqSigs[i].time, m_liqSigs[i].wickPrice);
      ObjectSetString(0, lbl, OBJPROP_TEXT, text);
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, col);
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, m_liqSigs[i].isAbove ? ANCHOR_LOWER : ANCHOR_UPPER);
   }
}

//+------------------------------------------------------------------+
void CCandleTypes::ClearDrawings()
{
   ObjectsDeleteAll(0, "SMC_SD_");
   ObjectsDeleteAll(0, "SMC_LQ_");
}
//+------------------------------------------------------------------+
