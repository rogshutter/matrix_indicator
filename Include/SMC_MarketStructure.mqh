//+------------------------------------------------------------------+
//|                                         SMC_MarketStructure.mqh |
//|                          Version 2 - Module 1 Structure is Queen |
//|                                    Smart Money Concepts (SMC)   |
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""
#property version   "2.02"

#include "SMC_Structures.mqh"

//+------------------------------------------------------------------+
//| Structure interne : point brut (avant alternance)                 |
//+------------------------------------------------------------------+
struct SRawSwing
{
   datetime time;
   double   price;
   int      barIndex;
   bool     isHigh;  // true = swing high, false = swing low
};

//+------------------------------------------------------------------+
//| Classe de détection de structure de marché                       |
//| V2 : alternance High-Low forcée, classification correcte          |
//+------------------------------------------------------------------+
class CMarketStructure
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_swingStrength;

   SSwingPoint       m_swingHighs[];
   SSwingPoint       m_swingLows[];
   int               m_highCount;
   int               m_lowCount;
   int               m_capacity;

   ENUM_MARKET_BIAS  m_currentBias;
   int               m_majorHighIndex;
   int               m_majorLowIndex;

   // Détection brute
   bool              IsSwingHigh(int barIndex);
   bool              IsSwingLow(int barIndex);

   // Construction de la séquence alternée
   void              BuildAlternatingSequence(SRawSwing &raw[], int rawCount,
                                              SSwingPoint &highs[], int &hCount,
                                              SSwingPoint &lows[], int &lCount);
   void              UpdateBias();
   void              UpdateMajorStructure();
   void              MarkAdjustments();
   void              CheckAdjustmentSweeps();

public:
                     CMarketStructure();
                    ~CMarketStructure();

   bool              Init(string symbol, ENUM_TIMEFRAMES tf, int swingStrength = 3);
   void              Update(int barsToCheck = 0);

   ENUM_MARKET_BIAS  GetMarketBias() { return m_currentBias; }
   int               GetSwingHighCount() { return m_highCount; }
   int               GetSwingLowCount() { return m_lowCount; }

   bool              GetLastSwingHigh(SSwingPoint &swing);
   bool              GetLastSwingLow(SSwingPoint &swing);
   bool              GetSwingHigh(int index, SSwingPoint &swing);
   bool              GetSwingLow(int index, SSwingPoint &swing);

   bool              GetMajorSwingHigh(SSwingPoint &swing);
   bool              GetMajorSwingLow(SSwingPoint &swing);
   bool              IsMajorBreakoutBullish();
   bool              IsMajorBreakoutBearish();

   double            GetKeyLevelHighPrice();
   double            GetKeyLevelLowPrice();
   double            Get8020Level(bool isHighToLow);
   bool              IsPriceIn8020Zone(double price);

   bool              IsHigherHigh();
   bool              IsHigherLow();
   bool              IsLowerHigh();
   bool              IsLowerLow();
   bool              HasStructuredRetracement(int minSwings = 4);

   // Module 1 : Consolidation (range) - prix entre deux niveaux
   bool              IsConsolidation(double &rangeHigh, double &rangeLow, int lookback = 20);

   // Module 1 : Structure de rotation
   bool              HasRotationStructure(double &intensities[], int &intCount, double &neutralityPrice, int lookback = 30);

   // Module 1 : 80/20 basé sur structure majeure (pas dernier swing)
   double            GetMajorRangeHigh();
   double            GetMajorRangeLow();

   void              DrawSwingPoints(color highColor = clrRed, color lowColor = clrBlue);
   void              DrawKeyLevels(color lineColor = clrLime);
   void              ClearDrawings();
};

//+------------------------------------------------------------------+
CMarketStructure::CMarketStructure()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_swingStrength = 3;
   m_highCount = 0;
   m_lowCount = 0;
   m_currentBias = BIAS_NEUTRAL;
   m_majorHighIndex = -1;
   m_majorLowIndex = -1;
   m_capacity = MAX_SWING_POINTS;
   ArrayResize(m_swingHighs, m_capacity);
   ArrayResize(m_swingLows, m_capacity);
}

//+------------------------------------------------------------------+
CMarketStructure::~CMarketStructure()
{
   ClearDrawings();
   ArrayFree(m_swingHighs);
   ArrayFree(m_swingLows);
}

//+------------------------------------------------------------------+
bool CMarketStructure::Init(string symbol, ENUM_TIMEFRAMES tf, int swingStrength)
{
   m_symbol = symbol;
   m_timeframe = tf;
   m_swingStrength = MathMax(1, swingStrength);
   m_highCount = 0;
   m_lowCount = 0;
   m_currentBias = BIAS_NEUTRAL;
   m_majorHighIndex = -1;
   m_majorLowIndex = -1;
   m_capacity = MAX_SWING_POINTS;
   ArrayResize(m_swingHighs, m_capacity);
   ArrayResize(m_swingLows, m_capacity);
   return true;
}

//+------------------------------------------------------------------+
bool CMarketStructure::IsSwingHigh(int barIndex)
{
   if(barIndex < m_swingStrength) return false;
   double high = iHigh(m_symbol, m_timeframe, barIndex);
   if(high <= 0) return false;
   for(int i = 1; i <= m_swingStrength; i++)
   {
      if(iHigh(m_symbol, m_timeframe, barIndex - i) >= high) return false;
      if(iHigh(m_symbol, m_timeframe, barIndex + i) >= high) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool CMarketStructure::IsSwingLow(int barIndex)
{
   if(barIndex < m_swingStrength) return false;
   double low = iLow(m_symbol, m_timeframe, barIndex);
   if(low <= 0) return false;
   for(int i = 1; i <= m_swingStrength; i++)
   {
      if(iLow(m_symbol, m_timeframe, barIndex - i) <= low) return false;
      if(iLow(m_symbol, m_timeframe, barIndex + i) <= low) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Construire une séquence ALTERNÉE High-Low-High-Low                |
//| Si deux highs consécutifs : garder le plus haut                    |
//| Si deux lows consécutifs : garder le plus bas                      |
//| Puis classifier HH/LH/HL/LL par comparaison avec le précédent     |
//| du même type dans la séquence alternée                             |
//+------------------------------------------------------------------+
void CMarketStructure::BuildAlternatingSequence(
   SRawSwing &raw[], int rawCount,
   SSwingPoint &highs[], int &hCount,
   SSwingPoint &lows[], int &lCount)
{
   hCount = 0;
   lCount = 0;
   if(rawCount == 0) return;

   // Étape 1 : forcer l'alternance
   SRawSwing alt[];
   ArrayResize(alt, rawCount);
   int altCount = 0;

   alt[0] = raw[0];
   altCount = 1;

   for(int i = 1; i < rawCount; i++)
   {
      if(raw[i].isHigh == alt[altCount - 1].isHigh)
      {
         // Même type que le précédent : garder le plus extrême
         if(raw[i].isHigh)
         {
            if(raw[i].price > alt[altCount - 1].price)
               alt[altCount - 1] = raw[i];  // Remplacer par le plus haut
         }
         else
         {
            if(raw[i].price < alt[altCount - 1].price)
               alt[altCount - 1] = raw[i];  // Remplacer par le plus bas
         }
      }
      else
      {
         // Type différent : ajouter
         if(altCount >= ArraySize(alt))
            ArrayResize(alt, altCount + 100);
         alt[altCount] = raw[i];
         altCount++;
      }
   }

   // Étape 2 : classifier et séparer en highs/lows
   double prevHighPrice = 0;
   double prevLowPrice = 0;
   bool hasPrevHigh = false;
   bool hasPrevLow = false;

   for(int i = 0; i < altCount; i++)
   {
      SSwingPoint sp;
      sp.Init();
      sp.time = alt[i].time;
      sp.price = alt[i].price;
      sp.barIndex = alt[i].barIndex;
      sp.isValid = true;
      sp.isMajor = false;

      if(alt[i].isHigh)
      {
         if(!hasPrevHigh)
            sp.type = SWING_HIGH;
         else
            sp.type = (sp.price > prevHighPrice) ? SWING_HH : SWING_LH;

         prevHighPrice = sp.price;
         hasPrevHigh = true;

         if(hCount < ArraySize(highs))
         {
            highs[hCount] = sp;
            hCount++;
         }
      }
      else
      {
         if(!hasPrevLow)
            sp.type = SWING_LOW;
         else
            sp.type = (sp.price > prevLowPrice) ? SWING_HL : SWING_LL;

         prevLowPrice = sp.price;
         hasPrevLow = true;

         if(lCount < ArraySize(lows))
         {
            lows[lCount] = sp;
            lCount++;
         }
      }
   }

   ArrayFree(alt);
}

//+------------------------------------------------------------------+
//| Déterminer le biais à partir des 2 derniers swings de chaque type |
//+------------------------------------------------------------------+
void CMarketStructure::UpdateBias()
{
   m_currentBias = BIAS_NEUTRAL;
   if(m_highCount < 2 || m_lowCount < 2) return;

   ENUM_SWING_TYPE lastH = m_swingHighs[m_highCount - 1].type;
   ENUM_SWING_TYPE lastL = m_swingLows[m_lowCount - 1].type;

   // Bullish = dernier high est HH ET dernier low est HL
   if(lastH == SWING_HH && lastL == SWING_HL)
      m_currentBias = BIAS_BULLISH;
   // Bearish = dernier high est LH ET dernier low est LL
   else if(lastH == SWING_LH && lastL == SWING_LL)
      m_currentBias = BIAS_BEARISH;
   // Sinon : vérifier les 2 derniers de chaque
   else
   {
      // Compter les HH/HL vs LH/LL sur les 3 derniers de chaque
      int bullScore = 0, bearScore = 0;
      for(int i = MathMax(0, m_highCount - 3); i < m_highCount; i++)
      {
         if(m_swingHighs[i].type == SWING_HH) bullScore++;
         if(m_swingHighs[i].type == SWING_LH) bearScore++;
      }
      for(int i = MathMax(0, m_lowCount - 3); i < m_lowCount; i++)
      {
         if(m_swingLows[i].type == SWING_HL) bullScore++;
         if(m_swingLows[i].type == SWING_LL) bearScore++;
      }
      if(bullScore > bearScore) m_currentBias = BIAS_BULLISH;
      else if(bearScore > bullScore) m_currentBias = BIAS_BEARISH;
   }
}

//+------------------------------------------------------------------+
void CMarketStructure::UpdateMajorStructure()
{
   for(int i = 0; i < m_highCount; i++) m_swingHighs[i].isMajor = false;
   for(int i = 0; i < m_lowCount; i++)  m_swingLows[i].isMajor = false;
   m_majorHighIndex = -1;
   m_majorLowIndex = -1;
   if(m_highCount < 2 || m_lowCount < 2) return;

   if(m_currentBias == BIAS_BULLISH)
   {
      for(int i = m_lowCount - 1; i >= 0; i--)
         if(m_swingLows[i].type == SWING_HL) { m_swingLows[i].isMajor = true; m_majorLowIndex = i; break; }
      for(int i = m_highCount - 1; i >= 0; i--)
         if(m_swingHighs[i].type == SWING_HH) { m_swingHighs[i].isMajor = true; m_majorHighIndex = i; break; }
   }
   else if(m_currentBias == BIAS_BEARISH)
   {
      for(int i = m_highCount - 1; i >= 0; i--)
         if(m_swingHighs[i].type == SWING_LH) { m_swingHighs[i].isMajor = true; m_majorHighIndex = i; break; }
      for(int i = m_lowCount - 1; i >= 0; i--)
         if(m_swingLows[i].type == SWING_LL) { m_swingLows[i].isMajor = true; m_majorLowIndex = i; break; }
   }
}

//+------------------------------------------------------------------+
//| Mise à jour : scan, alternance, classification, biais              |
//+------------------------------------------------------------------+
void CMarketStructure::Update(int barsToCheck)
{
   int maxBars = Bars(m_symbol, m_timeframe);
   if(barsToCheck <= 0 || barsToCheck > maxBars)
      barsToCheck = MathMin(200, maxBars);
   else
      barsToCheck = MathMin(barsToCheck, maxBars);

   // Estimer et redimensionner
   int estimated = barsToCheck / MathMax(1, m_swingStrength) + 100;
   if(estimated > m_capacity)
   {
      m_capacity = estimated;
      ArrayResize(m_swingHighs, m_capacity);
      ArrayResize(m_swingLows, m_capacity);
   }

   // Étape 1 : détecter tous les swings bruts (chronologique : ancien → récent)
   SRawSwing rawSwings[];
   ArrayResize(rawSwings, estimated);
   int rawCount = 0;

   int startBar = m_swingStrength;
   for(int i = barsToCheck; i >= startBar; i--)
   {
      bool isH = IsSwingHigh(i);
      bool isL = IsSwingLow(i);

      if(isH)
      {
         if(rawCount >= ArraySize(rawSwings))
            ArrayResize(rawSwings, rawCount + 200);
         rawSwings[rawCount].time = iTime(m_symbol, m_timeframe, i);
         rawSwings[rawCount].price = iHigh(m_symbol, m_timeframe, i);
         rawSwings[rawCount].barIndex = i;
         rawSwings[rawCount].isHigh = true;
         rawCount++;
      }
      if(isL)
      {
         if(rawCount >= ArraySize(rawSwings))
            ArrayResize(rawSwings, rawCount + 200);
         rawSwings[rawCount].time = iTime(m_symbol, m_timeframe, i);
         rawSwings[rawCount].price = iLow(m_symbol, m_timeframe, i);
         rawSwings[rawCount].barIndex = i;
         rawSwings[rawCount].isHigh = false;
         rawCount++;
      }
   }

   // Étape 2 : alternance + classification
   m_highCount = 0;
   m_lowCount = 0;
   BuildAlternatingSequence(rawSwings, rawCount, m_swingHighs, m_highCount, m_swingLows, m_lowCount);
   ArrayFree(rawSwings);

   // Étape 3 : biais et structure majeure
   UpdateBias();
   UpdateMajorStructure();
   
   // Étape 4 : marquer les ajustements (swings mineurs) et vérifier si pris
   MarkAdjustments();
   CheckAdjustmentSweeps();
}

//+------------------------------------------------------------------+
//| Marquer les ajustements (swings mineurs dans la tendance)         |
//| En tendance bull : chaque HL non-majeur = ajustement potentiel    |
//| En tendance bear : chaque LH non-majeur = ajustement potentiel    |
//| En range/neutre   : tous les non-majeurs = ajustements           |
//+------------------------------------------------------------------+
void CMarketStructure::MarkAdjustments()
{
   // Reset tous les flags
   for(int i = 0; i < m_highCount; i++) m_swingHighs[i].isAdjustment = false;
   for(int i = 0; i < m_lowCount; i++)  m_swingLows[i].isAdjustment = false;
   
   if(m_currentBias == BIAS_BULLISH)
   {
      // Bull : les HL qui ne sont pas majeurs sont des ajustements
      // Les LH sont aussi des ajustements (retracements)
      for(int i = 0; i < m_lowCount; i++)
         if(!m_swingLows[i].isMajor && (m_swingLows[i].type == SWING_HL || m_swingLows[i].type == SWING_LOW))
            m_swingLows[i].isAdjustment = true;
      for(int i = 0; i < m_highCount; i++)
         if(!m_swingHighs[i].isMajor && m_swingHighs[i].type == SWING_LH)
            m_swingHighs[i].isAdjustment = true;
   }
   else if(m_currentBias == BIAS_BEARISH)
   {
      // Bear : les LH qui ne sont pas majeurs sont des ajustements
      // Les HL sont aussi des ajustements (retracements) 
      for(int i = 0; i < m_highCount; i++)
         if(!m_swingHighs[i].isMajor && (m_swingHighs[i].type == SWING_LH || m_swingHighs[i].type == SWING_HIGH))
            m_swingHighs[i].isAdjustment = true;
      for(int i = 0; i < m_lowCount; i++)
         if(!m_swingLows[i].isMajor && m_swingLows[i].type == SWING_HL)
            m_swingLows[i].isAdjustment = true;
   }
   else
   {
      // Neutre : tous les non-majeurs sont des ajustements potentiels
      for(int i = 0; i < m_highCount; i++)
         if(!m_swingHighs[i].isMajor) m_swingHighs[i].isAdjustment = true;
      for(int i = 0; i < m_lowCount; i++)
         if(!m_swingLows[i].isMajor) m_swingLows[i].isAdjustment = true;
   }
}

//+------------------------------------------------------------------+
//| Vérifier si les ajustements ont été pris (swept par le prix)      |
//| Un ajustement est "pris" quand le prix dépasse le niveau du swing |
//+------------------------------------------------------------------+
void CMarketStructure::CheckAdjustmentSweeps()
{
   // Pour chaque swing high marqué comme ajustement
   for(int i = 0; i < m_highCount; i++)
   {
      if(!m_swingHighs[i].isAdjustment || m_swingHighs[i].adjustmentTaken) continue;
      
      // Chercher si une bougie après ce swing a dépassé le prix
      for(int b = m_swingHighs[i].barIndex - 1; b >= 0; b--)
      {
         if(iHigh(m_symbol, m_timeframe, b) > m_swingHighs[i].price)
         {
            m_swingHighs[i].adjustmentTaken = true;
            m_swingHighs[i].adjustmentTakenTime = iTime(m_symbol, m_timeframe, b);
            break;
         }
      }
   }
   
   // Pour chaque swing low marqué comme ajustement
   for(int i = 0; i < m_lowCount; i++)
   {
      if(!m_swingLows[i].isAdjustment || m_swingLows[i].adjustmentTaken) continue;
      
      // Chercher si une bougie après ce swing a cassé en dessous
      for(int b = m_swingLows[i].barIndex - 1; b >= 0; b--)
      {
         if(iLow(m_symbol, m_timeframe, b) < m_swingLows[i].price)
         {
            m_swingLows[i].adjustmentTaken = true;
            m_swingLows[i].adjustmentTakenTime = iTime(m_symbol, m_timeframe, b);
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
bool CMarketStructure::GetLastSwingHigh(SSwingPoint &swing)
{
   if(m_highCount == 0) return false;
   swing = m_swingHighs[m_highCount - 1];
   return true;
}

bool CMarketStructure::GetLastSwingLow(SSwingPoint &swing)
{
   if(m_lowCount == 0) return false;
   swing = m_swingLows[m_lowCount - 1];
   return true;
}

bool CMarketStructure::GetSwingHigh(int index, SSwingPoint &swing)
{
   if(index < 0 || index >= m_highCount) return false;
   swing = m_swingHighs[index];
   return true;
}

bool CMarketStructure::GetSwingLow(int index, SSwingPoint &swing)
{
   if(index < 0 || index >= m_lowCount) return false;
   swing = m_swingLows[index];
   return true;
}

bool CMarketStructure::GetMajorSwingHigh(SSwingPoint &swing)
{
   if(m_majorHighIndex < 0 || m_majorHighIndex >= m_highCount) return false;
   swing = m_swingHighs[m_majorHighIndex];
   return true;
}

bool CMarketStructure::GetMajorSwingLow(SSwingPoint &swing)
{
   if(m_majorLowIndex < 0 || m_majorLowIndex >= m_lowCount) return false;
   swing = m_swingLows[m_majorLowIndex];
   return true;
}

bool CMarketStructure::IsMajorBreakoutBullish()
{
   SSwingPoint keyHigh;
   if(!GetMajorSwingHigh(keyHigh)) return false;
   double close0 = iClose(m_symbol, m_timeframe, 0);
   return (m_currentBias == BIAS_BEARISH || m_currentBias == BIAS_NEUTRAL) && (close0 > keyHigh.price);
}

bool CMarketStructure::IsMajorBreakoutBearish()
{
   SSwingPoint keyLow;
   if(!GetMajorSwingLow(keyLow)) return false;
   double close0 = iClose(m_symbol, m_timeframe, 0);
   return (m_currentBias == BIAS_BULLISH || m_currentBias == BIAS_NEUTRAL) && (close0 < keyLow.price);
}

double CMarketStructure::GetKeyLevelHighPrice()
{
   SSwingPoint sw;
   return GetMajorSwingHigh(sw) ? sw.price : 0.0;
}

double CMarketStructure::GetKeyLevelLowPrice()
{
   SSwingPoint sw;
   return GetMajorSwingLow(sw) ? sw.price : 0.0;
}

double CMarketStructure::Get8020Level(bool isHighToLow)
{
   if(m_highCount == 0 || m_lowCount == 0) return 0.0;
   double lastHigh = m_swingHighs[m_highCount - 1].price;
   double lastLow = m_swingLows[m_lowCount - 1].price;
   double range = lastHigh - lastLow;
   return isHighToLow ? lastHigh - (range * 0.8) : lastLow + (range * 0.8);
}

bool CMarketStructure::IsPriceIn8020Zone(double price)
{
   if(m_highCount == 0 || m_lowCount == 0) return false;
   double lastHigh = m_swingHighs[m_highCount - 1].price;
   double lastLow = m_swingLows[m_lowCount - 1].price;
   double range = lastHigh - lastLow;
   return (price <= lastLow + range * 0.2) || (price >= lastLow + range * 0.8);
}

bool CMarketStructure::IsHigherHigh() { return m_highCount >= 2 && m_swingHighs[m_highCount - 1].type == SWING_HH; }
bool CMarketStructure::IsHigherLow()  { return m_lowCount >= 2  && m_swingLows[m_lowCount - 1].type == SWING_HL; }
bool CMarketStructure::IsLowerHigh()  { return m_highCount >= 2 && m_swingHighs[m_highCount - 1].type == SWING_LH; }
bool CMarketStructure::IsLowerLow()   { return m_lowCount >= 2  && m_swingLows[m_lowCount - 1].type == SWING_LL; }

bool CMarketStructure::HasStructuredRetracement(int minSwings)
{
   int nH = MathMin(minSwings, m_highCount);
   int nL = MathMin(minSwings, m_lowCount);
   if(nH < 2 || nL < 2) return false;
   bool hasHH = false, hasLH = false, hasHL = false, hasLL = false;
   for(int i = m_highCount - nH; i < m_highCount; i++)
   {
      if(m_swingHighs[i].type == SWING_HH) hasHH = true;
      if(m_swingHighs[i].type == SWING_LH) hasLH = true;
   }
   for(int i = m_lowCount - nL; i < m_lowCount; i++)
   {
      if(m_swingLows[i].type == SWING_HL) hasHL = true;
      if(m_swingLows[i].type == SWING_LL) hasLL = true;
   }
   return (hasHH && hasHL) || (hasLH && hasLL);
}

//+------------------------------------------------------------------+
//| Consolidation : prix oscille entre deux niveaux sans les casser    |
//| Détecte si les N derniers highs et lows sont dans une fourchette  |
//+------------------------------------------------------------------+
bool CMarketStructure::IsConsolidation(double &rangeHigh, double &rangeLow, int lookback)
{
   if(m_highCount < 3 || m_lowCount < 3) return false;
   int startH = MathMax(0, m_highCount - lookback);
   int startL = MathMax(0, m_lowCount - lookback);

   double maxH = 0, minH = 999999;
   for(int i = startH; i < m_highCount; i++)
   {
      if(m_swingHighs[i].price > maxH) maxH = m_swingHighs[i].price;
      if(m_swingHighs[i].price < minH) minH = m_swingHighs[i].price;
   }
   double maxL = 0, minL = 999999;
   for(int i = startL; i < m_lowCount; i++)
   {
      if(m_swingLows[i].price > maxL) maxL = m_swingLows[i].price;
      if(m_swingLows[i].price < minL) minL = m_swingLows[i].price;
   }

   double totalRange = maxH - minL;
   if(totalRange <= 0) return false;
   double highSpread = maxH - minH;  // écart entre les highs
   double lowSpread = maxL - minL;   // écart entre les lows

   // Consolidation = les highs restent proches entre eux ET les lows aussi
   // (écart < 30% du range total pour chaque)
   if(highSpread < totalRange * 0.30 && lowSpread < totalRange * 0.30)
   {
      rangeHigh = maxH;
      rangeLow = minL;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Structure de rotation : retracement structuré avec perte d'intensité |
//| Mesure la taille (en prix) de chaque leg du zigzag récent          |
//| Retourne true si les legs diminuent progressivement                 |
//+------------------------------------------------------------------+
bool CMarketStructure::HasRotationStructure(double &intensities[], int &intCount, double &neutralityPrice, int lookback)
{
   intCount = 0;
   neutralityPrice = 0;
   if(m_highCount < 3 || m_lowCount < 3) return false;

   // Construire le zigzag des derniers swings
   SSwingPoint pts[];
   ArrayResize(pts, lookback * 2);
   int ptCount = 0;
   int startH = MathMax(0, m_highCount - lookback);
   int startL = MathMax(0, m_lowCount - lookback);
   int hi = startH, li = startL;
   while(hi < m_highCount || li < m_lowCount)
   {
      SSwingPoint swH; swH.Init();
      SSwingPoint swL; swL.Init();
      bool gotH = (hi < m_highCount);
      bool gotL = (li < m_lowCount);
      if(gotH) swH = m_swingHighs[hi];
      if(gotL) swL = m_swingLows[li];
      if(!gotH && !gotL) break;
      if(gotH && gotL)
      {
         if(swH.time <= swL.time) { pts[ptCount++] = swH; hi++; }
         else { pts[ptCount++] = swL; li++; }
      }
      else if(gotH) { pts[ptCount++] = swH; hi++; }
      else { pts[ptCount++] = swL; li++; }
   }

   if(ptCount < 5) { ArrayFree(pts); return false; }

   // Mesurer l'intensité de chaque leg
   ArrayResize(intensities, ptCount - 1);
   intCount = 0;
   double sumPrice = 0;
   for(int i = 1; i < ptCount; i++)
   {
      double legSize = MathAbs(pts[i].price - pts[i-1].price);
      intensities[intCount++] = legSize;
      sumPrice += pts[i].price;
   }

   // Zone de neutralité = prix moyen de la zone
   neutralityPrice = sumPrice / (double)(ptCount - 1);

   // Vérifier si l'intensité diminue (au moins 3 legs consécutives en baisse)
   int decreasingCount = 0;
   for(int i = 1; i < intCount; i++)
   {
      if(intensities[i] < intensities[i-1]) decreasingCount++;
   }

   ArrayFree(pts);
   // Rotation = au moins 60% des legs sont décroissantes
   return (intCount >= 4 && decreasingCount >= (int)(intCount * 0.5));
}

//+------------------------------------------------------------------+
//| Range majeur : High et Low de la structure majeure (pas le dernier swing) |
//+------------------------------------------------------------------+
double CMarketStructure::GetMajorRangeHigh()
{
   if(m_majorHighIndex >= 0 && m_majorHighIndex < m_highCount)
      return m_swingHighs[m_majorHighIndex].price;
   if(m_highCount > 0) return m_swingHighs[m_highCount - 1].price;
   return 0;
}

double CMarketStructure::GetMajorRangeLow()
{
   if(m_majorLowIndex >= 0 && m_majorLowIndex < m_lowCount)
      return m_swingLows[m_majorLowIndex].price;
   if(m_lowCount > 0) return m_swingLows[m_lowCount - 1].price;
   return 0;
}

//+------------------------------------------------------------------+
void CMarketStructure::DrawSwingPoints(color highColor, color lowColor)
{
   string prefix = "SMC_Swing_";
   for(int i = 0; i < m_highCount; i++)
   {
      string name = prefix + "H_" + IntegerToString(i);
      string label = "";
      switch(m_swingHighs[i].type) { case SWING_HH: label = "HH"; break; case SWING_LH: label = "LH"; break; default: label = "H"; break; }
      if(m_swingHighs[i].isMajor) label += "*";
      ObjectCreate(0, name, OBJ_TEXT, 0, m_swingHighs[i].time, m_swingHighs[i].price);
      ObjectSetString(0, name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, name, OBJPROP_COLOR, highColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LOWER);
   }
   for(int i = 0; i < m_lowCount; i++)
   {
      string name = prefix + "L_" + IntegerToString(i);
      string label = "";
      switch(m_swingLows[i].type) { case SWING_HL: label = "HL"; break; case SWING_LL: label = "LL"; break; default: label = "L"; break; }
      if(m_swingLows[i].isMajor) label += "*";
      ObjectCreate(0, name, OBJ_TEXT, 0, m_swingLows[i].time, m_swingLows[i].price);
      ObjectSetString(0, name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, name, OBJPROP_COLOR, lowColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
   }
}

//+------------------------------------------------------------------+
void CMarketStructure::DrawKeyLevels(color lineColor)
{
   double keyHigh = GetKeyLevelHighPrice();
   double keyLow = GetKeyLevelLowPrice();
   string prefix = "SMC_Key_";
   if(keyHigh > 0.0)
   {
      string name = prefix + "H";
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, keyHigh);
      ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, "Niveau clé High (Structure majeure)");
   }
   if(keyLow > 0.0)
   {
      string name = prefix + "L";
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, keyLow);
      ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, "Niveau clé Low (Structure majeure)");
   }
}

//+------------------------------------------------------------------+
void CMarketStructure::ClearDrawings()
{
   ObjectsDeleteAll(0, "SMC_Swing_");
   ObjectsDeleteAll(0, "SMC_Key_");
}
//+------------------------------------------------------------------+
