//+------------------------------------------------------------------+
//|                                              SMC_Refinement.mqh |
//|                         Module 10 - Raffinage PE & SL            |
//|                  Confluence multi-TF, Bougies Algorithmiques     |
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""

#include "SMC_Structures.mqh"
#include "SMC_MarketStructure.mqh"
#include "SMC_BOS_ChoCh.mqh"
#include "SMC_CandleTypes.mqh"

//+------------------------------------------------------------------+
//| Enums                                                             |
//+------------------------------------------------------------------+
enum ENUM_SL_REFINEMENT_TYPE
{
   SL_BODY_DOJI,           // Corps du doji/2G (agressif)
   SL_WICK_COMPLETE,       // Mèche complète (safe)
   SL_BODY_CONFLUENCE,     // Confluence des corps
   SL_INTERNAL_ODF         // Order Flow interne
};

enum ENUM_SIGNATURE_TYPE
{
   SIG_NONE,               // Pas de signature
   SIG_DOJI,               // Doji classique
   SIG_2G,                 // Pattern 2G (deux bougies)
   SIG_MANIPULATIVE,       // Bougie manipulatrice
   SIG_ALGO                // Bougie algorithmique (combo)
};

//+------------------------------------------------------------------+
//| Structure: Bougie Signature                                       |
//+------------------------------------------------------------------+
struct SSignatureCandle
{
   datetime time;
   int barIndex;
   double open, high, low, close;
   double bodyTop, bodyBottom;
   double bodySize;
   double upperWick;
   double lowerWick;
   double totalRange;
   double wickRatio;              // Ratio mèche totale / corps
   ENUM_SIGNATURE_TYPE sigType;
   bool isBullish;
   int tfConfluenceCount;         // Nombre de TF avec même niveau
   bool isValid;
   
   void Init()
   {
      time = 0;
      barIndex = 0;
      open = high = low = close = 0;
      bodyTop = bodyBottom = 0;
      bodySize = 0;
      upperWick = lowerWick = 0;
      totalRange = 0;
      wickRatio = 0;
      sigType = SIG_NONE;
      isBullish = false;
      tfConfluenceCount = 0;
      isValid = false;
   }
};

//+------------------------------------------------------------------+
//| Structure: Entrée Raffinée                                        |
//+------------------------------------------------------------------+
struct SRefinedEntry
{
   datetime signalTime;
   int signalBar;
   double entryPrice;              // PE raffiné
   double stopLoss;                // SL raffiné
   double slDistancePips;          // Distance SL en pips
   ENUM_SL_REFINEMENT_TYPE slType; // Type de raffinage
   ENUM_MARKET_BIAS direction;        // Direction du trade
   int tfConfluence;               // Confluence timeframe
   double tp1Price;                // Take Profit 1
   double tp2Price;                // Take Profit 2
   double riskRewardRatio;         // R:R potentiel
   SSignatureCandle sigCandle;     // Bougie signature associée
   bool isValid;
   
   void Init()
   {
      signalTime = 0;
      signalBar = 0;
      entryPrice = 0;
      stopLoss = 0;
      slDistancePips = 0;
      slType = SL_BODY_DOJI;
      direction = BIAS_NEUTRAL;
      tfConfluence = 0;
      tp1Price = tp2Price = 0;
      riskRewardRatio = 0;
      sigCandle.Init();
      isValid = false;
   }
};

//+------------------------------------------------------------------+
//| Class: CRefinement                                                |
//+------------------------------------------------------------------+
class CRefinement
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   CMarketStructure* m_marketStructure;
   CBOSChoCh*        m_bosChoCh;
   CCandleTypes*     m_candles;         // Module 2 : zones S/D pour validation
   
   // Données stockées
   SSignatureCandle  m_signatures[100];
   int               m_signatureCount;
   SRefinedEntry     m_entries[50];
   int               m_entryCount;
   
   // Paramètres
   double            m_dojiBodyRatio;      // Ratio max corps/range pour doji
   double            m_manipulativeWickRatio; // Ratio min mèche/corps pour manip
   int               m_minTFConfluence;    // Confluence TF minimum
   double            m_maxSLPips;          // SL maximum en pips
   
   // Timeframes pour confluence
   ENUM_TIMEFRAMES   m_confluenceTFs[10];
   int               m_confluenceTFCount;
   
   // Méthodes privées
   bool              IsDojiCandle(int bar);
   bool              Is2GPattern(int bar);
   bool              IsManipulativeCandle(int bar);
   double            GetBodyTop(int bar);
   double            GetBodyBottom(int bar);
   double            GetWickRatio(int bar);
   int               CheckTFConfluence(double priceLevel, ENUM_MARKET_BIAS direction);
   double            CalculateSL_BodyDoji(SSignatureCandle& sig, ENUM_MARKET_BIAS dir);
   double            CalculateSL_WickComplete(SSignatureCandle& sig, ENUM_MARKET_BIAS dir);
   double            CalculateSL_BodyConfluence(SSignatureCandle& sig, ENUM_MARKET_BIAS dir);
   double            CalculateSL_InternalODF(SSignatureCandle& sig, ENUM_MARKET_BIAS dir);
   double            PipsToPriceDistance(double pips);
   double            PriceDistanceToPips(double distance);
   
public:
                     CRefinement();
                    ~CRefinement();
   
   bool              Init(string symbol, ENUM_TIMEFRAMES timeframe,
                         CMarketStructure* ms, CBOSChoCh* bos,
                         CCandleTypes* candles = NULL);
   void              Update(int barsToCheck);
   
   // Détection
   void              FindSignatureCandles(int barsToCheck);
   void              RefineEntries();
   
   // Accesseurs
   int               GetSignatureCount() { return m_signatureCount; }
   SSignatureCandle  GetSignature(int index);
   int               GetEntryCount() { return m_entryCount; }
   SRefinedEntry     GetEntry(int index);
   
   // Visualisation
   void              DrawRefinedEntries(color peColor, color slColor);
   void              DrawSignatureCandles(color sigColor);
};

//+------------------------------------------------------------------+
//| Constructeur                                                      |
//+------------------------------------------------------------------+
CRefinement::CRefinement()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_marketStructure = NULL;
   m_bosChoCh = NULL;
   m_candles = NULL;
   m_signatureCount = 0;
   m_entryCount = 0;
   
   // Paramètres par défaut
   m_dojiBodyRatio = 0.15;           // Corps < 15% du range = doji
   m_manipulativeWickRatio = 2.0;    // Mèche > 2x le corps = manip
   m_minTFConfluence = 3;            // Min 3 TF convergents
   m_maxSLPips = 35.0;               // SL max 35 pips (Module 10 : 8-20 pips typique)
   
   // Timeframes de confluence (du plus grand au plus petit)
   // Module 10 : 45min, 30min, 20min, 18min, 16min, 15min, 14min, 13min, 12min, 11min, 10min
   // MT5 supporte : M30, M20, M15, M12, M10, M6, M5 (les non-standard sont approximés)
   m_confluenceTFs[0] = PERIOD_M30;
   m_confluenceTFs[1] = PERIOD_M20;
   m_confluenceTFs[2] = PERIOD_M15;
   m_confluenceTFs[3] = PERIOD_M12;
   m_confluenceTFs[4] = PERIOD_M10;
   m_confluenceTFs[5] = PERIOD_M6;
   m_confluenceTFs[6] = PERIOD_M5;
   m_confluenceTFs[7] = PERIOD_M4;
   m_confluenceTFCount = 8;
}

//+------------------------------------------------------------------+
//| Destructeur                                                       |
//+------------------------------------------------------------------+
CRefinement::~CRefinement()
{
}

//+------------------------------------------------------------------+
//| Initialisation                                                    |
//+------------------------------------------------------------------+
bool CRefinement::Init(string symbol, ENUM_TIMEFRAMES timeframe,
                       CMarketStructure* ms, CBOSChoCh* bos,
                       CCandleTypes* candles)
{
   if(ms == NULL || bos == NULL) return false;
   
   m_symbol = symbol;
   m_timeframe = timeframe;
   m_marketStructure = ms;
   m_bosChoCh = bos;
   m_candles = candles;
   
   return true;
}

//+------------------------------------------------------------------+
//| Mise à jour principale                                            |
//+------------------------------------------------------------------+
void CRefinement::Update(int barsToCheck)
{
   // 1. Trouver les bougies signature
   FindSignatureCandles(barsToCheck);
   
   // 2. Raffiner les entrées potentielles
   RefineEntries();
}

//+------------------------------------------------------------------+
//| Vérifie si c'est un Doji                                          |
//+------------------------------------------------------------------+
bool CRefinement::IsDojiCandle(int bar)
{
   double open = iOpen(m_symbol, m_timeframe, bar);
   double close = iClose(m_symbol, m_timeframe, bar);
   double high = iHigh(m_symbol, m_timeframe, bar);
   double low = iLow(m_symbol, m_timeframe, bar);
   
   double bodySize = MathAbs(close - open);
   double totalRange = high - low;
   
   if(totalRange < _Point * 10) return false; // Bougie trop petite
   
   double bodyRatio = bodySize / totalRange;
   
   return (bodyRatio <= m_dojiBodyRatio);
}

//+------------------------------------------------------------------+
//| Vérifie si c'est un pattern 2G (deux bougies)                     |
//+------------------------------------------------------------------+
bool CRefinement::Is2GPattern(int bar)
{
   if(bar < 1) return false;
   
   // 2G = deux bougies consécutives formant un pattern
   double open1 = iOpen(m_symbol, m_timeframe, bar);
   double close1 = iClose(m_symbol, m_timeframe, bar);
   double high1 = iHigh(m_symbol, m_timeframe, bar);
   double low1 = iLow(m_symbol, m_timeframe, bar);
   
   double open2 = iOpen(m_symbol, m_timeframe, bar + 1);
   double close2 = iClose(m_symbol, m_timeframe, bar + 1);
   double high2 = iHigh(m_symbol, m_timeframe, bar + 1);
   double low2 = iLow(m_symbol, m_timeframe, bar + 1);
   
   // 2G haussier: bougie baissière suivie de bougie haussière englobante
   bool bullish2G = (close2 < open2) && (close1 > open1) && 
                    (close1 > high2) && (low1 < low2);
   
   // 2G baissier: bougie haussière suivie de bougie baissière englobante
   bool bearish2G = (close2 > open2) && (close1 < open1) && 
                    (close1 < low2) && (high1 > high2);
   
   // Ou pattern avec doji + impulsion
   bool dojiSetup = IsDojiCandle(bar + 1) && 
                    ((iHigh(m_symbol, m_timeframe, bar) - iLow(m_symbol, m_timeframe, bar)) > 
                     (high2 - low2) * 1.5);
   
   return (bullish2G || bearish2G || dojiSetup);
}

//+------------------------------------------------------------------+
//| Vérifie si c'est une bougie manipulatrice                         |
//+------------------------------------------------------------------+
bool CRefinement::IsManipulativeCandle(int bar)
{
   double open = iOpen(m_symbol, m_timeframe, bar);
   double close = iClose(m_symbol, m_timeframe, bar);
   double high = iHigh(m_symbol, m_timeframe, bar);
   double low = iLow(m_symbol, m_timeframe, bar);
   
   double bodySize = MathAbs(close - open);
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;
   double totalWick = upperWick + lowerWick;
   
   if(bodySize < _Point * 5) bodySize = _Point * 5; // Évite division par 0
   
   double wickRatio = totalWick / bodySize;
   
   // Bougie manipulatrice = grande mèche par rapport au corps
   if(wickRatio >= m_manipulativeWickRatio)
   {
      // Vérifier que c'est une mèche unidirectionnelle (pas les deux)
      if(upperWick > lowerWick * 3 || lowerWick > upperWick * 3)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Obtient le haut du corps                                          |
//+------------------------------------------------------------------+
double CRefinement::GetBodyTop(int bar)
{
   double open = iOpen(m_symbol, m_timeframe, bar);
   double close = iClose(m_symbol, m_timeframe, bar);
   return MathMax(open, close);
}

//+------------------------------------------------------------------+
//| Obtient le bas du corps                                           |
//+------------------------------------------------------------------+
double CRefinement::GetBodyBottom(int bar)
{
   double open = iOpen(m_symbol, m_timeframe, bar);
   double close = iClose(m_symbol, m_timeframe, bar);
   return MathMin(open, close);
}

//+------------------------------------------------------------------+
//| Calcule le ratio mèche/corps                                      |
//+------------------------------------------------------------------+
double CRefinement::GetWickRatio(int bar)
{
   double open = iOpen(m_symbol, m_timeframe, bar);
   double close = iClose(m_symbol, m_timeframe, bar);
   double high = iHigh(m_symbol, m_timeframe, bar);
   double low = iLow(m_symbol, m_timeframe, bar);
   
   double bodySize = MathAbs(close - open);
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;
   
   if(bodySize < _Point * 5) bodySize = _Point * 5;
   
   return (upperWick + lowerWick) / bodySize;
}

//+------------------------------------------------------------------+
//| Trouve les bougies signature                                      |
//+------------------------------------------------------------------+
void CRefinement::FindSignatureCandles(int barsToCheck)
{
   m_signatureCount = 0;
   
   int bars = MathMin(barsToCheck, Bars(m_symbol, m_timeframe) - 5);
   if(bars < 10) return;
   
   for(int i = 2; i < bars && m_signatureCount < 100; i++)
   {
      SSignatureCandle sig;
      sig.Init();
      
      sig.barIndex = i;
      sig.time = iTime(m_symbol, m_timeframe, i);
      sig.open = iOpen(m_symbol, m_timeframe, i);
      sig.high = iHigh(m_symbol, m_timeframe, i);
      sig.low = iLow(m_symbol, m_timeframe, i);
      sig.close = iClose(m_symbol, m_timeframe, i);
      
      sig.bodyTop = GetBodyTop(i);
      sig.bodyBottom = GetBodyBottom(i);
      sig.bodySize = sig.bodyTop - sig.bodyBottom;
      sig.upperWick = sig.high - sig.bodyTop;
      sig.lowerWick = sig.bodyBottom - sig.low;
      sig.totalRange = sig.high - sig.low;
      sig.wickRatio = GetWickRatio(i);
      sig.isBullish = (sig.close > sig.open);
      
      // Déterminer le type de signature
      sig.sigType = SIG_NONE;
      
      // Vérifier doji
      if(IsDojiCandle(i))
      {
         sig.sigType = SIG_DOJI;
      }
      // Vérifier 2G
      else if(Is2GPattern(i))
      {
         sig.sigType = SIG_2G;
      }
      // Vérifier bougie manipulatrice
      else if(IsManipulativeCandle(i))
      {
         sig.sigType = SIG_MANIPULATIVE;
      }
      
      // Si on a trouvé une signature, vérifier la confluence
      if(sig.sigType != SIG_NONE)
      {
         // Déterminer la direction basée sur la mèche dominante
         ENUM_MARKET_BIAS dir = BIAS_NEUTRAL;
         if(sig.upperWick > sig.lowerWick * 2)
            dir = BIAS_BEARISH; // Grande mèche haute = signal baissier
         else if(sig.lowerWick > sig.upperWick * 2)
            dir = BIAS_BULLISH; // Grande mèche basse = signal haussier
         
         // Vérifier confluence multi-TF
         double checkPrice = (dir == BIAS_BULLISH) ? sig.bodyBottom : sig.bodyTop;
         sig.tfConfluenceCount = CheckTFConfluence(checkPrice, dir);
         
         // Marquer comme algorithmique si haute confluence
         if(sig.tfConfluenceCount >= m_minTFConfluence)
         {
            sig.sigType = SIG_ALGO;
         }
         
         sig.isValid = true;
         m_signatures[m_signatureCount] = sig;
         m_signatureCount++;
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie la confluence multi-timeframe                             |
//+------------------------------------------------------------------+
int CRefinement::CheckTFConfluence(double priceLevel, ENUM_MARKET_BIAS direction)
{
   int confluenceCount = 0;
   double tolerance = PipsToPriceDistance(2.0); // 2 pips de tolérance
   
   for(int t = 0; t < m_confluenceTFCount; t++)
   {
      ENUM_TIMEFRAMES tf = m_confluenceTFs[t];
      
      // Chercher une bougie signature similaire sur ce TF
      for(int i = 0; i < 10; i++)
      {
         double high = iHigh(m_symbol, tf, i);
         double low = iLow(m_symbol, tf, i);
         double open = iOpen(m_symbol, tf, i);
         double close = iClose(m_symbol, tf, i);
         
         double bodyTop = MathMax(open, close);
         double bodyBottom = MathMin(open, close);
         
         // Vérifier si le niveau de prix correspond
         bool levelMatch = false;
         if(direction == BIAS_BULLISH)
         {
            if(MathAbs(bodyBottom - priceLevel) <= tolerance)
               levelMatch = true;
         }
         else if(direction == BIAS_BEARISH)
         {
            if(MathAbs(bodyTop - priceLevel) <= tolerance)
               levelMatch = true;
         }
         
         if(levelMatch)
         {
            confluenceCount++;
            break; // Une seule correspondance par TF
         }
      }
   }
   
   return confluenceCount;
}

//+------------------------------------------------------------------+
//| Raffine les entrées                                               |
//+------------------------------------------------------------------+
void CRefinement::RefineEntries()
{
   m_entryCount = 0;
   
   double buffer = PipsToPriceDistance(1.0); // 1 pip de buffer au-delà du SL
   
   for(int i = 0; i < m_signatureCount && m_entryCount < 50; i++)
   {
      SSignatureCandle sig = m_signatures[i];
      
      // Filtrer les signatures de haute qualité
      if(sig.sigType == SIG_ALGO || 
         (sig.sigType != SIG_NONE && sig.tfConfluenceCount >= 2))
      {
         SRefinedEntry entry;
         entry.Init();
         
         entry.signalTime = sig.time;
         entry.signalBar = sig.barIndex;
         entry.sigCandle = sig;
         
         // Déterminer la direction
         if(sig.upperWick > sig.lowerWick * 2)
            entry.direction = BIAS_BEARISH;
         else if(sig.lowerWick > sig.upperWick * 2)
            entry.direction = BIAS_BULLISH;
         else
            continue; // Direction pas claire
         
         // --- Module 10 : Validation zone S/D (la signature DOIT être dans/proche d'une zone active) ---
         // Conforme à la pédagogie : raffiner = PE/SL DANS un setup existant, pas standalone
         if(m_candles != NULL)
         {
            bool inSDZone = false;
            double sigMid = (sig.bodyTop + sig.bodyBottom) / 2.0;
            
            for(int z = 0; z < m_candles.GetZoneCount(); z++)
            {
               SSupplyDemandZone zone;
               if(!m_candles.GetZone(z, zone)) continue;
               if(zone.status != ZONE_ACTIVE) continue;
               
               // Direction concordante
               if(entry.direction == BIAS_BULLISH && zone.direction != OB_BULLISH) continue;
               if(entry.direction == BIAS_BEARISH && zone.direction != OB_BEARISH) continue;
               
               // La signature est dans ou proche de la zone (tolérance = taille zone)
               double zoneSize = zone.priceHigh - zone.priceLow;
               double tolerance = zoneSize * 1.5; // 1.5x la taille de zone comme marge
               
               if(sigMid >= zone.priceLow - tolerance && sigMid <= zone.priceHigh + tolerance)
               {
                  inSDZone = true;
                  break;
               }
            }
            
            // Si pas de zone S/D, ne garder que les SIG_ALGO (très haute confluence)
            if(!inSDZone && sig.sigType != SIG_ALGO)
               continue;
         }
         
         // --- PE raffiné : corps de la bougie signature ---
         if(entry.direction == BIAS_BULLISH)
            entry.entryPrice = sig.bodyBottom;
         else
            entry.entryPrice = sig.bodyTop;
         
         // ============================================================
         // SL BASÉ SUR LA STRUCTURE (swing low/high)
         // Comme montré dans les images de la stratégie :
         // - Buy : SL = dernier swing low SOUS l'entrée (= bas de la zone OB)
         // - Sell : SL = dernier swing high AU-DESSUS de l'entrée (= haut de la zone OB)
         // C'est la clé : on ne met pas le SL sur le corps d'une bougie (3 pips)
         // mais sur la structure du marché (10-60+ pips).
         // ============================================================
         double structuralSL = 0;
         double minSLDist = PipsToPriceDistance(5.0); // SL minimum 5 pips de l'entrée
         
         if(entry.direction == BIAS_BULLISH && m_marketStructure != NULL)
         {
            // Chercher un swing low structurel SOUS l'entrée
            // Priorité 1: swing majeur (structure principale)
            for(int s = m_marketStructure.GetSwingLowCount() - 1; s >= 0; s--)
            {
               SSwingPoint swing;
               if(!m_marketStructure.GetSwingLow(s, swing)) continue;
               if(swing.price < entry.entryPrice && swing.isMajor)
               {
                  double dist = entry.entryPrice - swing.price;
                  if(dist >= minSLDist)
                  {
                     structuralSL = swing.price - buffer;
                     break;
                  }
               }
            }
            // Priorité 2: n'importe quel swing low assez loin
            if(structuralSL <= 0)
            {
               for(int s = m_marketStructure.GetSwingLowCount() - 1; s >= 0; s--)
               {
                  SSwingPoint swing;
                  if(!m_marketStructure.GetSwingLow(s, swing)) continue;
                  if(swing.price < entry.entryPrice)
                  {
                     double dist = entry.entryPrice - swing.price;
                     if(dist >= minSLDist)
                     {
                        structuralSL = swing.price - buffer;
                        break;
                     }
                  }
               }
            }
            // Fallback : low de la bougie signature SI assez loin
            if(structuralSL <= 0)
            {
               double dist = entry.entryPrice - sig.low;
               if(dist >= minSLDist)
                  structuralSL = sig.low - buffer;
            }
         }
         else if(entry.direction == BIAS_BEARISH && m_marketStructure != NULL)
         {
            // Chercher un swing high structurel AU-DESSUS de l'entrée
            // Priorité 1: swing majeur
            for(int s = m_marketStructure.GetSwingHighCount() - 1; s >= 0; s--)
            {
               SSwingPoint swing;
               if(!m_marketStructure.GetSwingHigh(s, swing)) continue;
               if(swing.price > entry.entryPrice && swing.isMajor)
               {
                  double dist = swing.price - entry.entryPrice;
                  if(dist >= minSLDist)
                  {
                     structuralSL = swing.price + buffer;
                     break;
                  }
               }
            }
            // Priorité 2: n'importe quel swing high assez loin
            if(structuralSL <= 0)
            {
               for(int s = m_marketStructure.GetSwingHighCount() - 1; s >= 0; s--)
               {
                  SSwingPoint swing;
                  if(!m_marketStructure.GetSwingHigh(s, swing)) continue;
                  if(swing.price > entry.entryPrice)
                  {
                     double dist = swing.price - entry.entryPrice;
                     if(dist >= minSLDist)
                     {
                        structuralSL = swing.price + buffer;
                        break;
                     }
                  }
               }
            }
            // Fallback : high de la bougie signature SI assez loin
            if(structuralSL <= 0)
            {
               double dist = sig.high - entry.entryPrice;
               if(dist >= minSLDist)
                  structuralSL = sig.high + buffer;
            }
         }
         
         // Vérifier que le SL structural est dans la limite max pips
         double slDistStruct = PriceDistanceToPips(MathAbs(structuralSL - entry.entryPrice));
         
         if(structuralSL > 0 && slDistStruct <= m_maxSLPips && slDistStruct >= 3.0)
         {
            entry.stopLoss = structuralSL;
            entry.slType = SL_WICK_COMPLETE;
            entry.slDistancePips = slDistStruct;
         }
         else
         {
            // Si le SL structural est trop loin (> maxSL), utiliser le wick de la bougie
            double sl_wick = CalculateSL_WickComplete(sig, entry.direction);
            double slDist_wick = PriceDistanceToPips(MathAbs(sl_wick - entry.entryPrice));
            
            if(slDist_wick <= m_maxSLPips && slDist_wick >= 3.0)
            {
               entry.stopLoss = sl_wick;
               entry.slType = SL_WICK_COMPLETE;
               entry.slDistancePips = slDist_wick;
            }
            else
               continue; // Pas de SL viable, skip
         }
         
         // --- Validation: SL doit être du bon côté de l'entrée ---
         if(entry.direction == BIAS_BULLISH && entry.stopLoss >= entry.entryPrice)
            continue;
         if(entry.direction == BIAS_BEARISH && entry.stopLoss <= entry.entryPrice)
            continue;
         
         // Calculer les TP
         double slDistance = MathAbs(entry.stopLoss - entry.entryPrice);
         if(entry.direction == BIAS_BULLISH)
         {
            entry.tp1Price = entry.entryPrice + slDistance * 2.0;  // 2R
            entry.tp2Price = entry.entryPrice + slDistance * 4.0;  // 4R
         }
         else
         {
            entry.tp1Price = entry.entryPrice - slDistance * 2.0;
            entry.tp2Price = entry.entryPrice - slDistance * 4.0;
         }
         
         entry.riskRewardRatio = 2.0; // Par défaut 2R pour TP1
         entry.tfConfluence = sig.tfConfluenceCount;
         entry.isValid = true;
         
         m_entries[m_entryCount] = entry;
         m_entryCount++;
      }
   }
}

//+------------------------------------------------------------------+
//| Calcule SL basé sur le corps du doji                              |
//+------------------------------------------------------------------+
double CRefinement::CalculateSL_BodyDoji(SSignatureCandle& sig, ENUM_MARKET_BIAS dir)
{
   double buffer = PipsToPriceDistance(1.0); // 1 pip de buffer
   double minDist = PipsToPriceDistance(3.0); // minimum 3 pips de distance
   
   if(dir == BIAS_BULLISH)
   {
      // Garantir au moins minDist sous l'entrée (bodyBottom)
      double dist = MathMax(sig.bodyBottom - sig.low, minDist);
      return sig.bodyBottom - dist - buffer;
   }
   else
   {
      // Garantir au moins minDist au-dessus de l'entrée (bodyTop)
      double dist = MathMax(sig.high - sig.bodyTop, minDist);
      return sig.bodyTop + dist + buffer;
   }
}

//+------------------------------------------------------------------+
//| Calcule SL basé sur la mèche complète                             |
//+------------------------------------------------------------------+
double CRefinement::CalculateSL_WickComplete(SSignatureCandle& sig, ENUM_MARKET_BIAS dir)
{
   double buffer = PipsToPriceDistance(1.0);
   
   if(dir == BIAS_BULLISH)
   {
      return sig.low - buffer;
   }
   else
   {
      return sig.high + buffer;
   }
}

//+------------------------------------------------------------------+
//| Calcule SL basé sur la confluence des corps                       |
//+------------------------------------------------------------------+
double CRefinement::CalculateSL_BodyConfluence(SSignatureCandle& sig, ENUM_MARKET_BIAS dir)
{
   // Chercher une bougie adjacente avec corps similaire
   int checkBar = sig.barIndex + 1;
   
   double prevBodyTop = GetBodyTop(checkBar);
   double prevBodyBottom = GetBodyBottom(checkBar);
   
   double tolerance = PipsToPriceDistance(1.0);
   
   if(dir == BIAS_BULLISH)
   {
      // Vérifier si les corps ont le même niveau bas
      if(MathAbs(sig.bodyBottom - prevBodyBottom) <= tolerance)
      {
         return MathMin(sig.bodyBottom, prevBodyBottom) - PipsToPriceDistance(0.5);
      }
   }
   else
   {
      // Vérifier si les corps ont le même niveau haut
      if(MathAbs(sig.bodyTop - prevBodyTop) <= tolerance)
      {
         return MathMax(sig.bodyTop, prevBodyTop) + PipsToPriceDistance(0.5);
      }
   }
   
   // Sinon retourner le SL body standard
   return CalculateSL_BodyDoji(sig, dir);
}

//+------------------------------------------------------------------+
//| Calcule SL basé sur l'Order Flow interne (Module 10)              |
//| ODF interne = point médian de la mèche opposée à la direction     |
//| Principe: SL à 50% de la mèche (plus serré que wick complet)      |
//+------------------------------------------------------------------+
double CRefinement::CalculateSL_InternalODF(SSignatureCandle& sig, ENUM_MARKET_BIAS dir)
{
   double buffer = PipsToPriceDistance(0.5);
   double minDist = PipsToPriceDistance(3.0); // minimum 3 pips de distance
   
   if(sig.sigType == SIG_MANIPULATIVE || sig.sigType == SIG_ALGO)
   {
      if(dir == BIAS_BULLISH)
      {
         // SL à 50% de la mèche basse (entre bodyBottom et low)
         // Toujours SOUS entry (bodyBottom) → correct pour un achat
         double halfWick = (sig.bodyBottom - sig.low) / 2.0;
         double sl = sig.bodyBottom - MathMax(halfWick, minDist) - buffer;
         return sl;
      }
      else
      {
         // SL à 50% de la mèche haute (entre bodyTop et high)
         // Toujours AU-DESSUS entry (bodyTop) → correct pour une vente
         double halfWick = (sig.high - sig.bodyTop) / 2.0;
         double sl = sig.bodyTop + MathMax(halfWick, minDist) + buffer;
         return sl;
      }
   }
   
   // Pour les dojis et 2G, même logique sur la mèche opposée
   if(sig.sigType == SIG_DOJI || sig.sigType == SIG_2G)
   {
      if(dir == BIAS_BULLISH)
      {
         double halfWick = (sig.bodyBottom - sig.low) / 2.0;
         return sig.bodyBottom - MathMax(halfWick, minDist) - buffer;
      }
      else
      {
         double halfWick = (sig.high - sig.bodyTop) / 2.0;
         return sig.bodyTop + MathMax(halfWick, minDist) + buffer;
      }
   }
   
   return 0; // Pas applicable
}

//+------------------------------------------------------------------+
//| Convertit pips en distance de prix                                |
//+------------------------------------------------------------------+
double CRefinement::PipsToPriceDistance(double pips)
{
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   
   if(digits == 3 || digits == 5)
      return pips * point * 10;
   else
      return pips * point;
}

//+------------------------------------------------------------------+
//| Convertit distance de prix en pips                                |
//+------------------------------------------------------------------+
double CRefinement::PriceDistanceToPips(double distance)
{
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   
   if(digits == 3 || digits == 5)
      return distance / (point * 10);
   else
      return distance / point;
}

//+------------------------------------------------------------------+
//| Accesseur signature                                               |
//+------------------------------------------------------------------+
SSignatureCandle CRefinement::GetSignature(int index)
{
   SSignatureCandle empty;
   empty.Init();
   
   if(index < 0 || index >= m_signatureCount)
      return empty;
   
   return m_signatures[index];
}

//+------------------------------------------------------------------+
//| Accesseur entrée                                                  |
//+------------------------------------------------------------------+
SRefinedEntry CRefinement::GetEntry(int index)
{
   SRefinedEntry empty;
   empty.Init();
   
   if(index < 0 || index >= m_entryCount)
      return empty;
   
   return m_entries[index];
}

//+------------------------------------------------------------------+
//| Dessine les entrées raffinées                                     |
//+------------------------------------------------------------------+
void CRefinement::DrawRefinedEntries(color peColor, color slColor)
{
   for(int i = 0; i < m_entryCount; i++)
   {
      SRefinedEntry entry = m_entries[i];
      if(!entry.isValid) continue;
      
      string prefix = "SMC_REFINED_" + IntegerToString(i);
      
      // Ligne PE (entry price)
      string peLine = prefix + "_PE";
      ObjectCreate(0, peLine, OBJ_HLINE, 0, 0, entry.entryPrice);
      ObjectSetInteger(0, peLine, OBJPROP_COLOR, peColor);
      ObjectSetInteger(0, peLine, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, peLine, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, peLine, OBJPROP_BACK, true);
      
      // Ligne SL
      string slLine = prefix + "_SL";
      ObjectCreate(0, slLine, OBJ_HLINE, 0, 0, entry.stopLoss);
      ObjectSetInteger(0, slLine, OBJPROP_COLOR, slColor);
      ObjectSetInteger(0, slLine, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, slLine, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, slLine, OBJPROP_BACK, true);
      
      // Zone PE-SL rectangle
      string zoneRect = prefix + "_ZONE";
      ObjectCreate(0, zoneRect, OBJ_RECTANGLE, 0,
         entry.signalTime, entry.entryPrice,
         iTime(m_symbol, m_timeframe, 0), entry.stopLoss);
      ObjectSetInteger(0, zoneRect, OBJPROP_COLOR, 
         entry.direction == BIAS_BULLISH ? clrDodgerBlue : clrCrimson);
      ObjectSetInteger(0, zoneRect, OBJPROP_FILL, true);
      ObjectSetInteger(0, zoneRect, OBJPROP_BACK, true);
      ObjectSetInteger(0, zoneRect, OBJPROP_STYLE, STYLE_SOLID);
      
      // Label avec infos
      string infoLabel = prefix + "_INFO";
      double labelY = (entry.entryPrice + entry.stopLoss) / 2;
      ObjectCreate(0, infoLabel, OBJ_TEXT, 0, entry.signalTime, labelY);
      
      string slTypeStr = "";
      switch(entry.slType)
      {
         case SL_BODY_DOJI: slTypeStr = "Body"; break;
         case SL_WICK_COMPLETE: slTypeStr = "Wick"; break;
         case SL_BODY_CONFLUENCE: slTypeStr = "Conf"; break;
         case SL_INTERNAL_ODF: slTypeStr = "ODF"; break;
      }
      
      string infoText = StringFormat("%.1f pips | %s | TF:%d", 
         entry.slDistancePips, slTypeStr, entry.tfConfluence);
      ObjectSetString(0, infoLabel, OBJPROP_TEXT, infoText);
      ObjectSetInteger(0, infoLabel, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, infoLabel, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, infoLabel, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, infoLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
      
      // Direction arrow
      string dirLabel = prefix + "_DIR";
      ObjectCreate(0, dirLabel, OBJ_TEXT, 0, 
         iTime(m_symbol, m_timeframe, entry.signalBar - 2), entry.entryPrice);
      string dirText = (entry.direction == BIAS_BULLISH) ? "▲ ACHAT" : "▼ VENTE";
      ObjectSetString(0, dirLabel, OBJPROP_TEXT, dirText);
      ObjectSetInteger(0, dirLabel, OBJPROP_COLOR, 
         entry.direction == BIAS_BULLISH ? clrLime : clrOrangeRed);
      ObjectSetInteger(0, dirLabel, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, dirLabel, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, dirLabel, OBJPROP_ANCHOR, ANCHOR_RIGHT);
   }
}

//+------------------------------------------------------------------+
//| Dessine les bougies signature                                     |
//+------------------------------------------------------------------+
void CRefinement::DrawSignatureCandles(color sigColor)
{
   for(int i = 0; i < m_signatureCount; i++)
   {
      SSignatureCandle sig = m_signatures[i];
      if(!sig.isValid) continue;
      
      string prefix = "SMC_SIG_" + IntegerToString(i);
      
      // Marqueur sur la bougie signature
      string marker = prefix + "_MARKER";
      double markerPrice = sig.upperWick > sig.lowerWick ? sig.high : sig.low;
      ObjectCreate(0, marker, OBJ_ARROW, 0, sig.time, markerPrice);
      ObjectSetInteger(0, marker, OBJPROP_ARROWCODE, 
         sig.upperWick > sig.lowerWick ? 234 : 233);
      ObjectSetInteger(0, marker, OBJPROP_COLOR, sigColor);
      ObjectSetInteger(0, marker, OBJPROP_WIDTH, 2);
      
      // Label type de signature
      string typeLabel = prefix + "_TYPE";
      double labelPrice = sig.upperWick > sig.lowerWick ? 
         sig.high + (sig.high - sig.low) * 0.15 : 
         sig.low - (sig.high - sig.low) * 0.15;
      ObjectCreate(0, typeLabel, OBJ_TEXT, 0, sig.time, labelPrice);
      
      string typeText = "";
      switch(sig.sigType)
      {
         case SIG_DOJI: typeText = "DOJI"; break;
         case SIG_2G: typeText = "2G"; break;
         case SIG_MANIPULATIVE: typeText = "MANIP"; break;
         case SIG_ALGO: typeText = "ALGO ★"; break;
         default: typeText = "?"; break;
      }
      
      if(sig.tfConfluenceCount > 0)
         typeText += " [" + IntegerToString(sig.tfConfluenceCount) + "TF]";
      
      ObjectSetString(0, typeLabel, OBJPROP_TEXT, typeText);
      ObjectSetInteger(0, typeLabel, OBJPROP_COLOR, sigColor);
      ObjectSetInteger(0, typeLabel, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, typeLabel, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, typeLabel, OBJPROP_ANCHOR, ANCHOR_CENTER);
   }
}
//+------------------------------------------------------------------+
