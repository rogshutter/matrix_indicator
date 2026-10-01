//+------------------------------------------------------------------+
//|                                              SMC_ConceptEntry.mqh |
//|                                          Copyright 2026, RG_SMV   |
//|                                     Module 9 - Concept Entry      |
//+------------------------------------------------------------------+
#ifndef SMC_CONCEPT_ENTRY_MQH
#define SMC_CONCEPT_ENTRY_MQH

#include "SMC_Structures.mqh"
#include "SMC_MarketStructure.mqh"
#include "SMC_BOS_ChoCh.mqh"
#include "SMC_CauseEffect.mqh"
#include "SMC_Wyckoff.mqh"
#include "SMC_CandleTypes.mqh"
#include "SMC_OrderFlow.mqh"
#include "SMC_Liquidity.mqh"

// Note: ENUM_BOS_SUBTYPE from SMC_Structures.mqh is used:
// BOS_SUB_CLASSIC = BOS classique (changement de tendance)
// BOS_SUB_CONTINUATION = BOS de continuation

//+------------------------------------------------------------------+
//| Structure d'un Inducement (liquidité en attente)                   |
//+------------------------------------------------------------------+
struct SInducement
{
   double               price;            // Prix du niveau d'inducement
   datetime             timeCreated;      // Quand l'inducement a été créé
   datetime             timeTaken;        // Quand il a été pris
   int                  barCreated;
   int                  barTaken;
   bool                 isTaken;          // A-t-il été nettoyé ?
   ENUM_MARKET_BIAS     direction;        // Direction après la prise
   
   void Init()
   {
      price = 0.0;
      timeCreated = 0;
      timeTaken = 0;
      barCreated = -1;
      barTaken = -1;
      isTaken = false;
      direction = BIAS_NEUTRAL;
   }
};

//+------------------------------------------------------------------+
//| Structure d'un Concept Entry                                        |
//+------------------------------------------------------------------+
struct SConceptEntry
{
   ENUM_BOS_SUBTYPE     bosType;          // Type de BOS (classique ou continuation)
   ENUM_MARKET_BIAS     direction;        // Direction du trade
   
   // Cause précédente (si applicable - entrée après avoir raté le Golden Setup)
   bool                 hasPreviousCause; // Y avait-il une cause Wyckoff avant ?
   datetime             causeTime;
   
   // Inducement
   SInducement          inducement;       // Niveau d'inducement qui a été pris
   
   // Zone d'entrée (Order Block)
   double               entryZoneHigh;
   double               entryZoneLow;
   datetime             entryZoneTime;
   int                  entryZoneBar;
   
   // Signature algorithmique (bougie qui prend l'argent)
   bool                 hasAlgoSignature;
   datetime             algoSignatureTime;
   double               algoSignaturePrice;
   
   // Order Flow
   bool                 hasImpulsion;     // IMPULSION détectée
   bool                 hasRetracement;   // RETRACEMENT détecté
   bool                 hasContinuation;  // CONTINUATION attendue
   
   // Paramètres de trade
   double               entryPrice;
   double               stopLoss;
   double               takeProfit1;
   double               takeProfit2;
   double               riskReward;
   
   // Score de confiance (0-100%)
   double               confidenceScore;   // Score qualité de l'entrée
   bool                 bosConfirmed;      // BOS confirmé sur LTF
   bool                 foundSDZone;       // Zone S/D trouvée
   bool                 trendAligned;      // Direction concorde avec la tendance HTF
   
   bool                 isValid;
   datetime             validUntil;
   
   void Init()
   {
      bosType = BOS_SUB_CLASSIC;
      direction = BIAS_NEUTRAL;
      hasPreviousCause = false;
      causeTime = 0;
      inducement.Init();
      entryZoneHigh = 0.0;
      entryZoneLow = 0.0;
      entryZoneTime = 0;
      entryZoneBar = -1;
      hasAlgoSignature = false;
      algoSignatureTime = 0;
      algoSignaturePrice = 0.0;
      hasImpulsion = false;
      hasRetracement = false;
      hasContinuation = false;
      entryPrice = 0.0;
      stopLoss = 0.0;
      takeProfit1 = 0.0;
      takeProfit2 = 0.0;
      riskReward = 0.0;
      confidenceScore = 0.0;
      bosConfirmed = false;
      foundSDZone = false;
      trendAligned = false;
      isValid = false;
      validUntil = 0;
   }
};

//+------------------------------------------------------------------+
//| Classe CConceptEntry                                                |
//+------------------------------------------------------------------+
class CConceptEntry
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   
   // Références aux autres modules
   CMarketStructure*    m_structure;
   CBOSChoCh*           m_bos;
   CCauseEffect*        m_causeEffect;
   CWyckoff*            m_wyckoff;
   CCandleTypes*        m_candles;       // Module 2 : zones S/D
   COrderFlow*          m_orderFlow;     // Module 3 : order flow chains
   CLiquidity*          m_liquidity;     // Module 5 : intacts, EQL/EQH
   
   // Données internes
   SConceptEntry        m_entries[100];   // Max 100 concept entries (historique visible)
   int                  m_entryCount;
   
   SInducement          m_inducements[200]; // Inducements (historique visible)
   int                  m_inducementCount;
   
   // Fonctions internes
   void                 DetectInducements(int barsToCheck);
   void                 CheckInducementSweeps(int barsToCheck);
   ENUM_BOS_SUBTYPE     ClassifyBOS(int bosBar); // Classique vs Continuation
   bool                 FindAlgoSignature(int barStart, int barEnd, 
                                          datetime &outTime, double &outPrice);
   void                 DetectOrderFlow(SConceptEntry &entry, int barStart);
   void                 CalculateTradeParams(SConceptEntry &entry);
   bool                 IsInducementLevel(double price, int bar, bool forBuy);
   
public:
                        CConceptEntry();
                       ~CConceptEntry();
   
   bool                 Init(string symbol, ENUM_TIMEFRAMES tf,
                             CMarketStructure* ms, CBOSChoCh* bos,
                             CCauseEffect* ce, CWyckoff* wyck,
                             CCandleTypes* candles = NULL, COrderFlow* odf = NULL,
                             CLiquidity* liq = NULL);
   void                 Update(int barsToCheck);
   
   // Accesseurs
   int                  GetEntryCount() { return m_entryCount; }
   bool                 GetEntry(int index, SConceptEntry &entry);
   bool                 HasValidEntry(ENUM_MARKET_BIAS direction);
   int                  GetInducementCount() { return m_inducementCount; }
   bool                 GetInducement(int index, SInducement &inducement);
   
   // Visualisation
   void                 DrawConceptEntries(color bullishColor, color bearishColor);
   void                 DrawInducements(color inducementColor);
   void                 ClearDrawings();
};

//+------------------------------------------------------------------+
//| Constructeur                                                       |
//+------------------------------------------------------------------+
CConceptEntry::CConceptEntry()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_structure = NULL;
   m_bos = NULL;
   m_causeEffect = NULL;
   m_wyckoff = NULL;
   m_candles = NULL;
   m_orderFlow = NULL;
   m_liquidity = NULL;
   m_entryCount = 0;
   m_inducementCount = 0;
}

//+------------------------------------------------------------------+
//| Destructeur                                                        |
//+------------------------------------------------------------------+
CConceptEntry::~CConceptEntry()
{
   ClearDrawings();
}

//+------------------------------------------------------------------+
//| Initialisation                                                     |
//+------------------------------------------------------------------+
bool CConceptEntry::Init(string symbol, ENUM_TIMEFRAMES tf,
                          CMarketStructure* ms, CBOSChoCh* bos,
                          CCauseEffect* ce, CWyckoff* wyck,
                          CCandleTypes* candles, COrderFlow* odf,
                          CLiquidity* liq)
{
   if(ms == NULL || bos == NULL) return false;
   
   m_symbol = symbol;
   m_timeframe = tf;
   m_structure = ms;
   m_bos = bos;
   m_causeEffect = ce;
   m_wyckoff = wyck;
   m_candles = candles;
   m_orderFlow = odf;
   m_liquidity = liq;
   m_entryCount = 0;
   m_inducementCount = 0;
   
   // Initialiser les tableaux
   for(int i = 0; i < 100; i++)
      m_entries[i].Init();
   for(int i = 0; i < 200; i++)
      m_inducements[i].Init();
   
   return true;
}

//+------------------------------------------------------------------+
//| Mise à jour - Détection des Concept Entries                        |
//+------------------------------------------------------------------+
void CConceptEntry::Update(int barsToCheck)
{
   m_entryCount = 0;
   
   // Étape 1: Détecter les inducements depuis les swings de la structure
   DetectInducements(barsToCheck);
   
   // Debug: compter les inducements pris
   int takenCount = 0;
   for(int d = 0; d < m_inducementCount; d++)
      if(m_inducements[d].isTaken) takenCount++;
   
   static int s_debugCE = 0;
   s_debugCE++;
   if(s_debugCE % 10 == 1)
   {
      int sdTotal = (m_candles != NULL) ? m_candles.GetZoneCount() : -1;
      int sdActive = 0;
      if(m_candles != NULL)
         for(int z = 0; z < m_candles.GetZoneCount(); z++)
         {
            SSupplyDemandZone tz;
            if(m_candles.GetZone(z, tz) && tz.status == ZONE_ACTIVE) sdActive++;
         }
      Print("[CE] Update: ", m_inducementCount, " inducements (", takenCount, " pris) | bias=",
            EnumToString(m_structure.GetMarketBias()),
            " | SwH=", m_structure.GetSwingHighCount(), " SwL=", m_structure.GetSwingLowCount(),
            " | S/D zones: ", sdTotal, " total, ", sdActive, " active");
   }
   
   // Étape 2: Pour chaque inducement PRIS, chercher une entrée
   // Séquence stratégique : Ajustement pris → BOS LTF → Zone S/D → Signature candle → Entry
   for(int i = 0; i < m_inducementCount && m_entryCount < 100; i++)
   {
      if(!m_inducements[i].isTaken) continue;
      
      SConceptEntry entry;
      entry.Init();
      
      entry.inducement = m_inducements[i];
      entry.direction = m_inducements[i].direction;
      
      // === STEP A : Classifier le BOS ===
      int sweepBar = m_inducements[i].barTaken;
      if(sweepBar < 0) continue;
      entry.bosType = ClassifyBOS(sweepBar);
      
      // === STEP B : Vérifier s'il y a un BOS récent APRÈS le sweep ===
      // Le BOS confirme la direction de l'entrée
      bool bosConfirmed = false;
      if(m_bos != NULL)
      {
         int bosCount = m_bos.GetEventCount();
         for(int j = bosCount - 1; j >= 0; j--)
         {
            SBOSEvent ev;
            if(!m_bos.GetEvent(j, ev) || !ev.isValid || ev.isTrap) continue;
            // BOS doit être APRÈS le sweep et dans les 30 dernières barres
            if(ev.barIndex > sweepBar || ev.barIndex > 30) continue;
            
            if(entry.direction == BIAS_BULLISH && 
               (ev.type == BOS_BULLISH || ev.type == CHOCH_BULLISH))
               { bosConfirmed = true; break; }
            if(entry.direction == BIAS_BEARISH && 
               (ev.type == BOS_BEARISH || ev.type == CHOCH_BEARISH))
               { bosConfirmed = true; break; }
         }
      }
      
      // Au moins un BOS OU une cause Wyckoff pour valider
      if(m_wyckoff != NULL)
      {
         if(m_wyckoff.HasActiveAccumulation() && entry.direction == BIAS_BULLISH)
            entry.hasPreviousCause = true;
         if(m_wyckoff.HasActiveDistribution() && entry.direction == BIAS_BEARISH)
            entry.hasPreviousCause = true;
      }
      
      // === STEP C : Chercher une zone S/D active (Module 2) ===
      bool foundSDZone = false;
      if(m_candles != NULL)
      {
         double currentPrice = iClose(m_symbol, m_timeframe, 0);
         double bestDist = 999999;
         SSupplyDemandZone bestZone;
         bestZone.Init();
         
         for(int z = 0; z < m_candles.GetZoneCount(); z++)
         {
            SSupplyDemandZone zone;
            if(!m_candles.GetZone(z, zone)) continue;
            if(zone.status != ZONE_ACTIVE) continue;
            
            // Direction concordante
            if(entry.direction == BIAS_BULLISH && zone.direction != OB_BULLISH) continue;
            if(entry.direction == BIAS_BEARISH && zone.direction != OB_BEARISH) continue;
            
            // Zone doit être dans une fenêtre raisonnable autour du sweep
            // (peut être créée avant OU après le sweep — la zone de réaction post-sweep est valide)
            // barIndex élevé = plus ancien, barIndex faible = plus récent
            // On accepte les zones créées jusqu'à 50 barres AVANT le sweep ou N'IMPORTE QUAND après
            if(zone.barIndexManip > sweepBar + 50) continue;
            
            // Chercher la zone la plus proche du prix ACTUEL (pas de l'inducement)
            double zoneMid = (zone.priceHigh + zone.priceLow) / 2.0;
            double dist = MathAbs(currentPrice - zoneMid);
            
            if(dist < bestDist)
            {
               bestDist = dist;
               bestZone = zone;
               foundSDZone = true;
            }
         }
         
         if(foundSDZone)
         {
            entry.entryZoneHigh = bestZone.priceHigh;
            entry.entryZoneLow = bestZone.priceLow;
            entry.entryZoneTime = bestZone.timeStart;
            entry.entryZoneBar = bestZone.barIndexManip;
         }
      }
      
      // === STEP D : Chercher la signature algorithmique ===
      datetime sigTime = 0;
      double sigPrice = 0;
      int sigSearchEnd = MathMax(sweepBar - 15, 0);
      if(FindAlgoSignature(sweepBar, sigSearchEnd, sigTime, sigPrice))
      {
         entry.hasAlgoSignature = true;
         entry.algoSignatureTime = sigTime;
         entry.algoSignaturePrice = sigPrice;
      }
      
      // Si pas de zone S/D, construire une zone autour de la signature
      if(!foundSDZone && entry.hasAlgoSignature)
      {
         double range = MathAbs(iHigh(m_symbol, m_timeframe, sweepBar) -
                               iLow(m_symbol, m_timeframe, sweepBar));
         if(range <= 0) range = iClose(m_symbol, m_timeframe, sweepBar) * 0.001;
         if(entry.direction == BIAS_BULLISH)
         {
            entry.entryZoneLow = entry.algoSignaturePrice;
            entry.entryZoneHigh = entry.algoSignaturePrice + range * 0.5;
         }
         else
         {
            entry.entryZoneHigh = entry.algoSignaturePrice;
            entry.entryZoneLow = entry.algoSignaturePrice - range * 0.5;
         }
         entry.entryZoneTime = entry.algoSignatureTime;
         entry.entryZoneBar = sweepBar;
      }
      
      // Si toujours pas de zone, construire une zone autour de l'inducement
      if(!foundSDZone && !entry.hasAlgoSignature)
      {
         double range = MathAbs(iHigh(m_symbol, m_timeframe, sweepBar) -
                               iLow(m_symbol, m_timeframe, sweepBar));
         if(range <= 0) range = m_inducements[i].price * 0.001;
         if(entry.direction == BIAS_BULLISH)
         {
            entry.entryZoneLow = m_inducements[i].price;
            entry.entryZoneHigh = m_inducements[i].price + range;
         }
         else
         {
            entry.entryZoneHigh = m_inducements[i].price;
            entry.entryZoneLow = m_inducements[i].price - range;
         }
         entry.entryZoneTime = m_inducements[i].timeTaken;
         entry.entryZoneBar = sweepBar;
      }
      
      // === STEP E : Order Flow ===
      if(m_orderFlow != NULL)
      {
         if(entry.direction == BIAS_BULLISH)
            entry.hasImpulsion = m_orderFlow.IsInBullishOrderFlow();
         else
            entry.hasImpulsion = m_orderFlow.IsInBearishOrderFlow();
         
         if(entry.direction == BIAS_BULLISH && m_orderFlow.HasActiveBullishBB())
            entry.hasRetracement = true;
         else if(entry.direction == BIAS_BEARISH && m_orderFlow.HasActiveBearishBB())
            entry.hasRetracement = true;
         
         entry.hasContinuation = entry.hasImpulsion;
      }
      else
      {
         DetectOrderFlow(entry, sweepBar);
      }
      
      // === STEP F : Calculer PE/SL/TP ===
      CalculateTradeParams(entry);
      
      // === STEP G : Valider l'entrée ===
      // Stocker les flags de confirmation dans la struct
      entry.bosConfirmed = bosConfirmed;
      entry.foundSDZone = foundSDZone;
      
      bool hasConfirmation = bosConfirmed || entry.hasPreviousCause || 
                             entry.hasImpulsion || entry.hasAlgoSignature;
      entry.isValid = (entry.entryZoneHigh > 0) && 
                      (hasConfirmation || foundSDZone);
      
      // === STEP H : Score de confiance (0-100%) ===
      // Le facteur DOMINANT est la concordance avec la tendance HTF
      // Si direction du signal = biais du marché → +30 points ("signaux sûrs")
      ENUM_MARKET_BIAS marketBias = m_structure.GetMarketBias();
      entry.trendAligned = (marketBias == entry.direction) ||
                           (marketBias == BIAS_NEUTRAL);  // Neutre = les deux OK
      
      double score = 0.0;
      if(entry.trendAligned)       score += 30.0;  // Concordance tendance HTF (dominant)
      if(entry.bosConfirmed)       score += 15.0;  // BOS LTF confirmé
      if(entry.foundSDZone)        score += 15.0;  // Zone S/D trouvée
      if(entry.hasAlgoSignature)   score += 10.0;  // Signature algorithmique
      if(entry.hasPreviousCause)   score += 10.0;  // Cause Wyckoff précédente
      if(entry.hasImpulsion)       score += 10.0;  // Order Flow impulsion
      if(entry.hasRetracement)     score +=  5.0;  // Retracement détecté
      if(entry.hasContinuation)    score +=  5.0;  // Continuation attendue
      entry.confidenceScore = score;
      
      if(entry.isValid && (i % 10 == 0))  // Log 1 entrée sur 10
         Print(StringFormat("[CE-SCORE] %s %s | Trend=%s BOS=%s SD=%s Algo=%s Wyck=%s ODF=%s | Score=%.0f%%",
            entry.direction == BIAS_BULLISH ? "BUY" : "SELL",
            entry.trendAligned ? "TREND" : "CONTRE",
            entry.trendAligned ? "Y" : "N",
            entry.bosConfirmed ? "Y" : "N",
            entry.foundSDZone ? "Y" : "N",
            entry.hasAlgoSignature ? "Y" : "N",
            entry.hasPreviousCause ? "Y" : "N",
            entry.hasImpulsion ? "Y" : "N",
            entry.confidenceScore));
      
      if(entry.isValid)
      {
         entry.validUntil = iTime(m_symbol, m_timeframe, 0) + 
                            PeriodSeconds(m_timeframe) * 50;
         
         m_entries[m_entryCount] = entry;
         m_entryCount++;
      }
   }
}

//+------------------------------------------------------------------+
//| Détecter les niveaux d'inducement à partir des swing points       |
//| de la structure (ajustements marqués par CMarketStructure)         |
//+------------------------------------------------------------------+
void CConceptEntry::DetectInducements(int barsToCheck)
{
   m_inducementCount = 0;
   if(m_structure == NULL) return;
   
   // === STRATÉGIE ===
   // Collecter les DEUX côtés (highs + lows) pour l'historique complet
   // Le score de confiance (trendAligned) filtre la concordance tendance
   // Itérer du PLUS RECENT au plus ancien (slots = signaux récents d'abord)
   
   // --- Swing Highs comme inducements (liquidité acheteuse → SELL) ---
   {
      int hCount = m_structure.GetSwingHighCount();
      for(int i = hCount - 1; i >= 0 && m_inducementCount < 200; i--)
      {
         SSwingPoint sw;
         if(!m_structure.GetSwingHigh(i, sw)) continue;
         if(!sw.isValid || !sw.isAdjustment) continue;
         if(sw.barIndex > barsToCheck) continue;
         if(!sw.adjustmentTaken) continue;
         
         SInducement ind;
         ind.Init();
         ind.price = sw.price;
         ind.timeCreated = sw.time;
         ind.barCreated = sw.barIndex;
         ind.direction = BIAS_BEARISH;
         ind.isTaken = true;
         ind.timeTaken = sw.adjustmentTakenTime;
         ind.barTaken = iBarShift(m_symbol, m_timeframe, sw.adjustmentTakenTime, false);
         
         m_inducements[m_inducementCount] = ind;
         m_inducementCount++;
      }
   }
   
   // --- Swing Lows comme inducements (liquidité vendeuse → BUY) ---
   {
      int lCount = m_structure.GetSwingLowCount();
      for(int i = lCount - 1; i >= 0 && m_inducementCount < 200; i--)
      {
         SSwingPoint sw;
         if(!m_structure.GetSwingLow(i, sw)) continue;
         if(!sw.isValid || !sw.isAdjustment) continue;
         if(sw.barIndex > barsToCheck) continue;
         if(!sw.adjustmentTaken) continue;
         
         SInducement ind;
         ind.Init();
         ind.price = sw.price;
         ind.timeCreated = sw.time;
         ind.barCreated = sw.barIndex;
         ind.direction = BIAS_BULLISH;
         ind.isTaken = true;
         ind.timeTaken = sw.adjustmentTakenTime;
         ind.barTaken = iBarShift(m_symbol, m_timeframe, sw.adjustmentTakenTime, false);
         
         m_inducements[m_inducementCount] = ind;
         m_inducementCount++;
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier si un niveau est un inducement (pas un BOS majeur)        |
//| NOTE: Simplifié car les inducements proviennent maintenant des     |
//| swings marqués isAdjustment par CMarketStructure                   |
//+------------------------------------------------------------------+
bool CConceptEntry::IsInducementLevel(double price, int bar, bool forBuy)
{
   // Avec la nouvelle approche, les inducements viennent des swings marqués
   // isAdjustment. Cette fonction n'est plus le filtre principal.
   return true;
}

//+------------------------------------------------------------------+
//| CheckInducementSweeps - Les sweeps sont maintenant gérés par       |
//| CMarketStructure::CheckAdjustmentSweeps(), plus besoin ici        |
//+------------------------------------------------------------------+
void CConceptEntry::CheckInducementSweeps(int barsToCheck)
{
   // Vide - les sweeps sont pré-calculés par DetectInducements()
   // via les champs adjustmentTaken de SSwingPoint
}

//+------------------------------------------------------------------+
//| Classifier le type de BOS (Classique vs Continuation)              |
//+------------------------------------------------------------------+
ENUM_BOS_SUBTYPE CConceptEntry::ClassifyBOS(int bosBar)
{
   // BOS Classique = Changement de tendance (après consolidation/cause)
   // BOS Continuation = Suivi du flow existant (pas de changement majeur)
   
   // Analyser la structure avant le BOS
   if(m_structure == NULL) return BOS_SUB_CLASSIC;
   
   ENUM_MARKET_BIAS currentBias = m_structure.GetMarketBias();
   
   // Vérifier s'il y a eu une cause (Wyckoff) récemment
   if(m_wyckoff != NULL)
   {
      // S'il y a une accumulation ou distribution active, c'est un BOS Classique
      if(m_wyckoff.HasActiveAccumulation() || m_wyckoff.HasActiveDistribution())
         return BOS_SUB_CLASSIC;
   }
   
   // Sinon, c'est probablement un BOS de continuation
   return BOS_SUB_CONTINUATION;
}

//+------------------------------------------------------------------+
//| Trouver la signature algorithmique (bougie qui prend l'argent)     |
//+------------------------------------------------------------------+
bool CConceptEntry::FindAlgoSignature(int barStart, int barEnd, 
                                       datetime &outTime, double &outPrice)
{
   // Une signature algorithmique est une bougie avec une grande mèche
   // qui "prend l'argent" (liquidity grab) avant de reverser
   
   for(int i = barStart; i >= barEnd && i >= 0; i--)
   {
      double open = iOpen(m_symbol, m_timeframe, i);
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);
      double close = iClose(m_symbol, m_timeframe, i);
      
      double body = MathAbs(close - open);
      double upperWick = high - MathMax(open, close);
      double lowerWick = MathMin(open, close) - low;
      double totalRange = high - low;
      
      if(totalRange == 0) continue;
      
      // Signature bearish: grande mèche haute (>50% du range)
      // (assoupli de 60% à 50% pour détecter plus de signatures)
      if(upperWick / totalRange > 0.50)
      {
         outTime = iTime(m_symbol, m_timeframe, i);
         outPrice = high;
         return true;
      }
      
      // Signature bullish: grande mèche basse (>50% du range)
      if(lowerWick / totalRange > 0.50)
      {
         outTime = iTime(m_symbol, m_timeframe, i);
         outPrice = low;
         return true;
      }
      
      // Doji (très petit corps) dans n'importe quelle direction
      if(body > 0 && body / totalRange < 0.15 && totalRange > 0)
      {
         outTime = iTime(m_symbol, m_timeframe, i);
         outPrice = (high + low) / 2.0;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Détecter l'Order Flow (Impulsion, Retracement, Continuation)       |
//+------------------------------------------------------------------+
void CConceptEntry::DetectOrderFlow(SConceptEntry &entry, int barStart)
{
   // L'Order Flow suit le pattern: IMPULSION → RETRACEMENT → CONTINUATION
   
   if(barStart < 5) return;
   
   // Analyser les 10 dernières bougies
   double highs[10], lows[10], closes[10];
   for(int i = 0; i < 10 && barStart - i >= 0; i++)
   {
      highs[i] = iHigh(m_symbol, m_timeframe, barStart - i);
      lows[i] = iLow(m_symbol, m_timeframe, barStart - i);
      closes[i] = iClose(m_symbol, m_timeframe, barStart - i);
   }
   
   // Détecter l'impulsion (mouvement fort dans une direction)
   double maxMove = 0;
   bool impulsionUp = false;
   
   for(int i = 0; i < 9; i++)
   {
      double move = closes[i] - closes[i + 1];
      if(MathAbs(move) > MathAbs(maxMove))
      {
         maxMove = move;
         impulsionUp = (move > 0);
      }
   }
   
   if(MathAbs(maxMove) > 0)
   {
      entry.hasImpulsion = true;
      
      // Vérifier le retracement (mouvement contraire)
      for(int i = 0; i < 5; i++)
      {
         double move = closes[i] - closes[i + 1];
         if((impulsionUp && move < 0) || (!impulsionUp && move > 0))
         {
            entry.hasRetracement = true;
            break;
         }
      }
      
      // La continuation est attendue après le retracement
      entry.hasContinuation = entry.hasImpulsion && entry.hasRetracement;
   }
}

//+------------------------------------------------------------------+
//| Calculer les paramètres de trade                                    |
//+------------------------------------------------------------------+
void CConceptEntry::CalculateTradeParams(SConceptEntry &entry)
{
   if(entry.entryZoneHigh == 0 && !entry.hasAlgoSignature) return;
   
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   double buffer = (digits == 3 || digits == 5) ? 10.0 * point : 1.0 * point; // ~1 pip buffer
   
   if(entry.direction == BIAS_BULLISH)
   {
      // PE = bord de la zone S/D (entryZoneLow) ou signature candle
      if(entry.entryZoneHigh > 0)
         entry.entryPrice = entry.entryZoneLow; // Acheter au bas de la zone demand
      else if(entry.hasAlgoSignature)
         entry.entryPrice = entry.algoSignaturePrice;
      
      // SL = sous la zone S/D + buffer (au lieu de 1.5x zone)
      double zoneSize = (entry.entryZoneHigh > 0) ? 
                        (entry.entryZoneHigh - entry.entryZoneLow) : 
                        (entry.algoSignaturePrice * 0.001);
      entry.stopLoss = entry.entryPrice - zoneSize - buffer;
      
      // TP : utiliser intacts si disponibles (Module 5)
      double risk = entry.entryPrice - entry.stopLoss;
      entry.takeProfit1 = entry.entryPrice + risk * 2;  // 2R default
      entry.takeProfit2 = entry.entryPrice + risk * 4;  // 4R default
      
      // Améliorer TP avec intact sellers (Module 5)
      if(m_liquidity != NULL)
      {
         SLiquidityZone liqTarget;
         if(m_liquidity.GetNearestIntactSeller(entry.entryPrice, liqTarget))
         {
            double liqDist = liqTarget.price - entry.entryPrice;
            if(liqDist > 0 && liqDist / risk >= 2.0)
               entry.takeProfit1 = liqTarget.price;
         }
      }
   }
   else
   {
      // PE = bord de la zone Supply (entryZoneHigh) ou signature candle
      if(entry.entryZoneHigh > 0)
         entry.entryPrice = entry.entryZoneHigh; // Vendre au haut de la zone supply
      else if(entry.hasAlgoSignature)
         entry.entryPrice = entry.algoSignaturePrice;
      
      // SL = au-dessus de la zone S/D + buffer
      double zoneSize = (entry.entryZoneHigh > 0) ? 
                        (entry.entryZoneHigh - entry.entryZoneLow) : 
                        (entry.algoSignaturePrice * 0.001);
      entry.stopLoss = entry.entryPrice + zoneSize + buffer;
      
      // TP default
      double risk = entry.stopLoss - entry.entryPrice;
      entry.takeProfit1 = entry.entryPrice - risk * 2;
      entry.takeProfit2 = entry.entryPrice - risk * 4;
      
      // Améliorer TP avec intact buyers (Module 5)
      if(m_liquidity != NULL)
      {
         SLiquidityZone liqTarget;
         if(m_liquidity.GetNearestIntactBuyer(entry.entryPrice, liqTarget))
         {
            double liqDist = entry.entryPrice - liqTarget.price;
            if(liqDist > 0 && liqDist / risk >= 2.0)
               entry.takeProfit1 = liqTarget.price;
         }
      }
   }
   
   // Calculer le Risk/Reward
   double risk = MathAbs(entry.entryPrice - entry.stopLoss);
   double reward = MathAbs(entry.takeProfit1 - entry.entryPrice);
   entry.riskReward = (risk > 0) ? reward / risk : 0;
}

//+------------------------------------------------------------------+
//| Accesseur pour un Concept Entry                                     |
//+------------------------------------------------------------------+
bool CConceptEntry::GetEntry(int index, SConceptEntry &entry)
{
   if(index < 0 || index >= m_entryCount) return false;
   entry = m_entries[index];
   return true;
}

//+------------------------------------------------------------------+
//| Vérifier s'il y a une entrée valide dans une direction             |
//+------------------------------------------------------------------+
bool CConceptEntry::HasValidEntry(ENUM_MARKET_BIAS direction)
{
   for(int i = 0; i < m_entryCount; i++)
   {
      if(m_entries[i].isValid && m_entries[i].direction == direction)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Accesseur pour un Inducement                                        |
//+------------------------------------------------------------------+
bool CConceptEntry::GetInducement(int index, SInducement &inducement)
{
   if(index < 0 || index >= m_inducementCount) return false;
   inducement = m_inducements[index];
   return true;
}

//+------------------------------------------------------------------+
//| Dessiner les Concept Entries                                        |
//+------------------------------------------------------------------+
void CConceptEntry::DrawConceptEntries(color bullishColor, color bearishColor)
{
   for(int i = 0; i < m_entryCount; i++)
   {
      SConceptEntry entry = m_entries[i];
      if(!entry.isValid) continue;
      
      string prefix = "SMC_CONCEPT_" + IntegerToString(i);
      color entryColor = (entry.direction == BIAS_BULLISH) ? bullishColor : bearishColor;
      
      // Zone d'entrée (rectangle)
      if(entry.entryZoneHigh > 0)
      {
         string zoneName = prefix + "_zone";
         datetime futureTime = iTime(m_symbol, m_timeframe, 0) + 
                               PeriodSeconds(m_timeframe) * 20;
         ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0,
            entry.entryZoneTime, entry.entryZoneHigh,
            futureTime, entry.entryZoneLow);
         ObjectSetInteger(0, zoneName, OBJPROP_COLOR, entryColor);
         ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
         ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
         ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
      }
      
      // Label du type de BOS
      string bosLabel = prefix + "_bos";
      double labelPrice = (entry.direction == BIAS_BULLISH) ? 
                          entry.entryZoneHigh : entry.entryZoneLow;
      ObjectCreate(0, bosLabel, OBJ_TEXT, 0, entry.entryZoneTime, labelPrice);
      string bosText = (entry.bosType == BOS_SUB_CLASSIC) ? "BOS CLASSIQUE" : "BOS CONTINUATION";
      ObjectSetString(0, bosLabel, OBJPROP_TEXT, bosText);
      ObjectSetInteger(0, bosLabel, OBJPROP_COLOR, 
         entry.bosType == BOS_SUB_CLASSIC ? clrRed : clrLime);
      ObjectSetInteger(0, bosLabel, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, bosLabel, OBJPROP_ANCHOR, 
         entry.direction == BIAS_BULLISH ? ANCHOR_LOWER : ANCHOR_UPPER);
      
      // Label direction (CONCEPT ENTRY)
      string dirLabel = prefix + "_dir";
      double dirY = (entry.entryZoneHigh + entry.entryZoneLow) / 2;
      ObjectCreate(0, dirLabel, OBJ_TEXT, 0, entry.entryZoneTime, dirY);
      string dirText = (entry.direction == BIAS_BULLISH) ? 
                       "CONCEPT ENTRY ↑ ACHAT" : "CONCEPT ENTRY ↓ VENTE";
      ObjectSetString(0, dirLabel, OBJPROP_TEXT, dirText);
      ObjectSetInteger(0, dirLabel, OBJPROP_COLOR, entryColor);
      ObjectSetInteger(0, dirLabel, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, dirLabel, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, dirLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
      
      // Order Flow indicators
      if(entry.hasImpulsion)
      {
         string impLabel = prefix + "_imp";
         ObjectCreate(0, impLabel, OBJ_TEXT, 0, entry.entryZoneTime, 
            entry.entryZoneHigh + (entry.entryZoneHigh - entry.entryZoneLow) * 0.3);
         ObjectSetString(0, impLabel, OBJPROP_TEXT, "IMPULSION ✓");
         ObjectSetInteger(0, impLabel, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, impLabel, OBJPROP_FONTSIZE, 7);
         ObjectSetInteger(0, impLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }
      
      if(entry.hasRetracement)
      {
         string retLabel = prefix + "_ret";
         ObjectCreate(0, retLabel, OBJ_TEXT, 0, entry.entryZoneTime,
            entry.entryZoneLow - (entry.entryZoneHigh - entry.entryZoneLow) * 0.2);
         ObjectSetString(0, retLabel, OBJPROP_TEXT, "RETRACEMENT ✓");
         ObjectSetInteger(0, retLabel, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, retLabel, OBJPROP_FONTSIZE, 7);
         ObjectSetInteger(0, retLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }
      
      // R:R label
      if(entry.riskReward > 0)
      {
         string rrLabel = prefix + "_rr";
         ObjectCreate(0, rrLabel, OBJ_TEXT, 0, entry.entryZoneTime,
            entry.entryZoneLow - (entry.entryZoneHigh - entry.entryZoneLow) * 0.4);
         ObjectSetString(0, rrLabel, OBJPROP_TEXT, 
            "R:R " + DoubleToString(entry.riskReward, 1));
         ObjectSetInteger(0, rrLabel, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, rrLabel, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, rrLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
      }
   }
}

//+------------------------------------------------------------------+
//| Dessiner les Inducements                                            |
//+------------------------------------------------------------------+
void CConceptEntry::DrawInducements(color inducementColor)
{
   for(int i = 0; i < m_inducementCount; i++)
   {
      SInducement ind = m_inducements[i];
      
      string prefix = "SMC_INDUC_" + IntegerToString(i);
      
      // Ligne horizontale pour l'inducement
      string lineName = prefix + "_line";
      datetime endTime = ind.isTaken ? ind.timeTaken : 
                         iTime(m_symbol, m_timeframe, 0);
      ObjectCreate(0, lineName, OBJ_TREND, 0,
         ind.timeCreated, ind.price,
         endTime, ind.price);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, inducementColor);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, ind.isTaken ? STYLE_SOLID : STYLE_DOT);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, !ind.isTaken);
      
      // Label INDUCEMENT
      string indLabel = prefix + "_lbl";
      ObjectCreate(0, indLabel, OBJ_TEXT, 0, ind.timeCreated, ind.price);
      ObjectSetString(0, indLabel, OBJPROP_TEXT, "INDUCEMENT");
      ObjectSetInteger(0, indLabel, OBJPROP_COLOR, inducementColor);
      ObjectSetInteger(0, indLabel, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, indLabel, OBJPROP_ANCHOR, 
         ind.direction == BIAS_BULLISH ? ANCHOR_UPPER : ANCHOR_LOWER);
      
      // Marquer X si pris
      if(ind.isTaken)
      {
         string xMark = prefix + "_x";
         ObjectCreate(0, xMark, OBJ_TEXT, 0, ind.timeTaken, ind.price);
         ObjectSetString(0, xMark, OBJPROP_TEXT, "✗");
         ObjectSetInteger(0, xMark, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, xMark, OBJPROP_FONTSIZE, 12);
         ObjectSetInteger(0, xMark, OBJPROP_ANCHOR, ANCHOR_CENTER);
      }
   }
}

//+------------------------------------------------------------------+
//| Nettoyer les dessins                                                |
//+------------------------------------------------------------------+
void CConceptEntry::ClearDrawings()
{
   ObjectsDeleteAll(0, "SMC_CONCEPT_");
   ObjectsDeleteAll(0, "SMC_INDUC_");
}

#endif // SMC_CONCEPT_ENTRY_MQH
