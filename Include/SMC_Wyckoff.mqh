//+------------------------------------------------------------------+
//|                                                SMC_Wyckoff.mqh   |
//|                  Version 2 - Module 7 : Wyckoff Golden Setup      |
//|                                    Smart Money Concepts (SMC)     |
//+------------------------------------------------------------------+
//| Pédagogie Module 7 (images + textes complets) :                   |
//| ACCUMULATION Type 1 & 2 :                                          |
//|   - Phase A : Arrêt tendance (PS → SC → AR)                       |
//|   - Phase B : Construction cause (ST → UA)                         |
//|   - Phase C : Prise liquidité (STB → Spring → Test)              |
//|   - Phase D : Initiation tendance (LPS → SOS)                     |
//|   - Phase E : Mark-up (effet haussier)                            |
//| DISTRIBUTION Type 1 & 2 :                                          |
//|   - Phase A : Arrêt tendance (PSY → BC → AR)                      |
//|   - Phase B : Construction cause (ST → MSO/mSOW)                   |
//|   - Phase C : Prise liquidité (UT → UTAD → Test)                  |
//|   - Phase D : Initiation tendance (LPSY → SOW)                    |
//|   - Phase E : Mark-down (effet baissier)                          |
//| GOLDEN ENTRY / SNIPER ENTRY :                                      |
//|   - Entrée sur le TEST après prise de liquidité                   |
//|   - Accumulation : entrée sur LPS après Spring/STB                |
//|   - Distribution : entrée sur LPSY après UT/UTAD                  |
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""
#property version   "2.07"

#include "SMC_Structures.mqh"
#include "SMC_MarketStructure.mqh"
#include "SMC_BOS_ChoCh.mqh"
#include "SMC_CauseEffect.mqh"

//+------------------------------------------------------------------+
//| Wyckoff Phase (A-E)                                               |
//+------------------------------------------------------------------+
enum ENUM_WYCKOFF_PHASE
{
   WP_NONE = 0,
   WP_PHASE_A,     // Stopping action (arrêt de tendance)
   WP_PHASE_B,     // Building cause (construction du range)
   WP_PHASE_C,     // Liquidity grab (prise de liquidité = test)
   WP_PHASE_D,     // Trend initiation (départ du mouvement)
   WP_PHASE_E      // Effect phase (mark-up / mark-down)
};

//+------------------------------------------------------------------+
//| Type d'événement Wyckoff                                          |
//+------------------------------------------------------------------+
enum ENUM_WYCKOFF_EVENT
{
   WE_NONE = 0,
   // -- Événements communs Accumulation/Distribution --
   WE_AR,          // Automatic Rally/Reaction (élargit le range)
   WE_ST,          // Secondary Test (test du SC/BC)
   WE_TEST,        // Test générique après prise de liquidité
   
   // -- Événements Accumulation --
   WE_PS,          // Preliminary Support (échec d'arrêt)
   WE_SC,          // Selling Climax (arrête baisse, fixe bas du range)
   WE_UA,          // Upthrust Action (prend liq AR, montre intention achat)
   WE_STB,         // Spring Test Bottom (1ère prise liq sous SC-ST)
   WE_SPRING,      // Spring (2ème prise liq agressive - Type 1)
   WE_LPS,         // Last Point of Support (test après liq = ENTRÉE)
   WE_SOS,         // Sign of Strength (BOS haussier = confirmation)
   WE_BU,          // Back-Up (retest résistance devenue support)
   
   // -- Événements Distribution --
   WE_PSY,         // Preliminary Supply (échec d'arrêt)
   WE_BC,          // Buying Climax (arrête hausse, fixe haut du range)
   WE_MSO,         // Minor Sign of Weakness (prend liq AR, intention vente)
   WE_UT,          // Upthrust (1ère prise liq au-dessus BC-ST)
   WE_UTAD,        // Upthrust After Distribution (2ème prise liq - Type 1)
   WE_LPSY,        // Last Point of Supply (test après liq = ENTRÉE)
   WE_SOW          // Sign of Weakness (BOS baissier = confirmation)
};

//+------------------------------------------------------------------+
//| Type de pattern Wyckoff                                           |
//+------------------------------------------------------------------+
enum ENUM_WYCKOFF_PATTERN
{
   WYCK_NONE = 0,
   WYCK_ACCUMULATION_1,   // Avec Spring (2 prises de liquidité)
   WYCK_ACCUMULATION_2,   // Sans Spring (1 prise - STB seulement)
   WYCK_DISTRIBUTION_1,   // Avec UTAD (2 prises de liquidité)
   WYCK_DISTRIBUTION_2    // Sans UTAD (1 prise - UT seulement)
};

//+------------------------------------------------------------------+
//| Mode de détection Wyckoff (Module 8)                               |
//+------------------------------------------------------------------+
enum ENUM_WYCKOFF_MODE
{
   WYCK_MODE_CLASSIC = 0,   // Module 7 : Pattern standard horizontal
   WYCK_MODE_NEUTRAL,       // Module 8 : Décompte double (BC+SC simultanés)
   WYCK_MODE_ROTATION       // Module 8 : Structure de rotation diagonale
};

//+------------------------------------------------------------------+
//| Structure Wyckoff Neutre/Avancé (Module 8)                          |
//| Décompte simultané des deux côtés du range                         |
//+------------------------------------------------------------------+
struct SWyckoffNeutral
{
   double               rangeHigh;           // BC level (arrête l'achat)
   double               rangeLow;            // SC level (arrête la vente)
   datetime             timeStart;
   datetime             timeEnd;
   int                  barStart;
   int                  barEnd;
   
   // Tests offre/demande internes
   bool                 bcSupplyTested;      // ST a testé l'offre du BC
   bool                 scDemandTested;      // ST a testé la demande du SC
   
   // Prises de liquidité externes
   bool                 utTriggered;         // Liquidité externe BC prise (UT)
   double               utPrice;
   datetime             utTime;
   bool                 stbTriggered;        // Liquidité externe SC prise (STB)
   double               stbPrice;
   datetime             stbTime;
   
   ENUM_MARKET_BIAS     direction;           // Biais après prise de liq externe
   bool                 isValid;             // Pattern validé
   
   void Init()
   {
      rangeHigh = 0.0;
      rangeLow = 0.0;
      timeStart = 0;
      timeEnd = 0;
      barStart = -1;
      barEnd = -1;
      bcSupplyTested = false;
      scDemandTested = false;
      utTriggered = false;
      utPrice = 0.0;
      utTime = 0;
      stbTriggered = false;
      stbPrice = 0.0;
      stbTime = 0;
      direction = BIAS_NEUTRAL;
      isValid = false;
   }
};

//+------------------------------------------------------------------+
//| Structure de Rotation (Module 8)                                     |
//| Wyckoff diagonal avec perte de momentum (vagues Elliott)           |
//+------------------------------------------------------------------+
struct SRotationStructure
{
   datetime             timeStart;
   datetime             timeEnd;
   int                  barStart;
   int                  barEnd;
   
   // Analyse des impulsions (vagues Elliott)
   int                  waveCount;           // Nombre de vagues (3-5)
   double               impulseSize[5];      // Taille de chaque impulsion en pips
   bool                 momentumLoss;        // Perte de momentum détectée
   
   // Lignes diagonales du range
   double               diagonalHighStart;   // Ligne supérieure début
   double               diagonalHighEnd;     // Ligne supérieure fin
   double               diagonalLowStart;    // Ligne inférieure début
   double               diagonalLowEnd;      // Ligne inférieure fin
   
   // Événements Wyckoff dans la rotation
   bool                 hasPS;
   bool                 hasSC;  // or BC according to direction
   bool                 hasAR;
   bool                 hasST;
   bool                 hasLiquidityGrab;    // STB/Spring ou UT/UTAD
   bool                 hasBOS;              // Intention confirmée
   
   ENUM_MARKET_BIAS     prevTrend;           // Tendance avant rotation
   ENUM_MARKET_BIAS     newDirection;        // Nouvelle direction après rotation
   bool                 isValid;
   
   void Init()
   {
      timeStart = 0;
      timeEnd = 0;
      barStart = -1;
      barEnd = -1;
      waveCount = 0;
      ArrayInitialize(impulseSize, 0.0);
      momentumLoss = false;
      diagonalHighStart = 0.0;
      diagonalHighEnd = 0.0;
      diagonalLowStart = 0.0;
      diagonalLowEnd = 0.0;
      hasPS = false;
      hasSC = false;
      hasAR = false;
      hasST = false;
      hasLiquidityGrab = false;
      hasBOS = false;
      prevTrend = BIAS_NEUTRAL;
      newDirection = BIAS_NEUTRAL;
      isValid = false;
   }
};

//+------------------------------------------------------------------+
//| Structure d'un événement Wyckoff                                   |
//+------------------------------------------------------------------+
struct SWyckoffEvent
{
   datetime             time;
   double               price;
   int                  barIndex;
   ENUM_WYCKOFF_EVENT   type;
   ENUM_WYCKOFF_PHASE   phase;
   
   void Init()
   {
      time = 0;
      price = 0.0;
      barIndex = -1;
      type = WE_NONE;
      phase = WP_NONE;
   }
};

//+------------------------------------------------------------------+
//| Structure d'un pattern Wyckoff complet                             |
//+------------------------------------------------------------------+
struct SWyckoffPattern
{
   ENUM_WYCKOFF_PATTERN  type;
   ENUM_WYCKOFF_PHASE    currentPhase;
   datetime              timeStart;
   datetime              timeEnd;
   int                   barStart;
   int                   barEnd;
   double                rangeHigh;      // Fourchette haute (AR level)
   double                rangeLow;       // Fourchette basse (SC/BC level)
   
   SWyckoffEvent         events[20];     // Événements détectés
   int                   eventCount;
   
   bool                  hasGoldenEntry; // Golden Entry détecté ?
   datetime              goldenEntryTime;
   double                goldenEntryPrice;
   double                goldenEntrySL;
   double                goldenEntryTP1;
   double                goldenEntryTP2;
   
   bool                  isComplete;     // Pattern validé ?
   
   void Init()
   {
      type = WYCK_NONE;
      currentPhase = WP_NONE;
      timeStart = 0;
      timeEnd = 0;
      barStart = -1;
      barEnd = -1;
      rangeHigh = 0.0;
      rangeLow = 0.0;
      eventCount = 0;
      hasGoldenEntry = false;
      goldenEntryTime = 0;
      goldenEntryPrice = 0.0;
      goldenEntrySL = 0.0;
      goldenEntryTP1 = 0.0;
      goldenEntryTP2 = 0.0;
      isComplete = false;
      
      for(int i = 0; i < 20; i++)
         events[i].Init();
   }
   
   void AddEvent(ENUM_WYCKOFF_EVENT evType, datetime evTime, double evPrice, 
                 int evBar, ENUM_WYCKOFF_PHASE evPhase)
   {
      if(eventCount < 20)
      {
         events[eventCount].type = evType;
         events[eventCount].time = evTime;
         events[eventCount].price = evPrice;
         events[eventCount].barIndex = evBar;
         events[eventCount].phase = evPhase;
         eventCount++;
      }
   }
   
   bool IsAccumulation()
   {
      return (type == WYCK_ACCUMULATION_1 || type == WYCK_ACCUMULATION_2);
   }
   
   bool IsDistribution()
   {
      return (type == WYCK_DISTRIBUTION_1 || type == WYCK_DISTRIBUTION_2);
   }
};

//+------------------------------------------------------------------+
//| Classe Wyckoff - Module 7 & 8                                       |
//+------------------------------------------------------------------+
class CWyckoff
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_timeframe;
   CMarketStructure*    m_structure;
   CBOSChoCh*           m_bos;
   CCauseEffect*        m_causeEffect;  // Utilise Module 4 comme base
   
   // Module 7 - Patterns classiques
   SWyckoffPattern      m_patterns[20];
   int                  m_patternCount;
   
   // Module 8 - Patterns neutres (double décompte)
   SWyckoffNeutral      m_neutralPatterns[10];
   int                  m_neutralCount;
   
   // Module 8 - Structures de rotation
   SRotationStructure   m_rotations[10];
   int                  m_rotationCount;
   
   // Fonctions de détection internes - Module 7
   void                 DetectPatterns(int barsToCheck);
   void                 AnalyzeAccumulation(SCauseZone &zone, int zoneIdx);
   void                 AnalyzeDistribution(SCauseZone &zone, int zoneIdx);
   bool                 FindSwingLow(int barStart, int barEnd, datetime &outTime, 
                                     double &outPrice, int &outBar);
   bool                 FindSwingHigh(int barStart, int barEnd, datetime &outTime, 
                                      double &outPrice, int &outBar);
   bool                 IsBreakBelow(double price, double level, double tolerance);
   bool                 IsBreakAbove(double price, double level, double tolerance);
   void                 DetectGoldenEntry(SWyckoffPattern &pattern);
   string               GetEventLabel(ENUM_WYCKOFF_EVENT ev);
   
   // Fonctions de détection internes - Module 8 Wyckoff Neutre
   void                 DetectNeutralPatterns(int barsToCheck);
   void                 AnalyzeNeutralZone(SCauseZone &zone, int zoneIdx);
   bool                 CheckSupplyTest(double bcLevel, int barStart, int barEnd);
   bool                 CheckDemandTest(double scLevel, int barStart, int barEnd);
   bool                 CheckExternalLiquidity(double level, bool isAbove, int barStart, 
                                                int barEnd, double &outPrice, datetime &outTime);
   
   // Fonctions de détection internes - Module 8 Structure de Rotation
   void                 DetectRotationStructures(int barsToCheck);
   bool                 CalculateMomentumLoss(int barStart, int barEnd, 
                                               double &impulseSize[], int &waveCount);
   void                 CalculateDiagonalLines(SRotationStructure &rotation);
   
public:
                        CWyckoff();
                       ~CWyckoff();
   
   bool                 Init(string symbol, ENUM_TIMEFRAMES tf,
                             CMarketStructure* ms, CBOSChoCh* bos, 
                             CCauseEffect* ce);
   void                 Update(int barsToCheck);
   
   // Module 7 - Accesseurs patterns classiques
   int                  GetPatternCount() { return m_patternCount; }
   bool                 GetPattern(int index, SWyckoffPattern &pattern);
   bool                 HasActiveAccumulation();
   bool                 HasActiveDistribution();
   bool                 HasGoldenEntry(bool isBullish);
   
   // Module 8 - Accesseurs patterns neutres
   int                  GetNeutralCount() { return m_neutralCount; }
   bool                 GetNeutralPattern(int index, SWyckoffNeutral &pattern);
   bool                 HasNeutralSetup();
   
   // Module 8 - Accesseurs structures rotation
   int                  GetRotationCount() { return m_rotationCount; }
   bool                 GetRotation(int index, SRotationStructure &rotation);
   bool                 HasRotationStructure();
   
   // Visualisation
   void                 DrawPatterns(color accumColor, color distribColor);
   void                 DrawGoldenEntries(color goldenColor);
   void                 DrawNeutralPatterns(color neutralColor);
   void                 DrawRotationStructures(color rotationColor);
   void                 ClearDrawings();
};

//+------------------------------------------------------------------+
//| Constructeur                                                       |
//+------------------------------------------------------------------+
CWyckoff::CWyckoff()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_structure = NULL;
   m_bos = NULL;
   m_causeEffect = NULL;
   m_patternCount = 0;
   m_neutralCount = 0;
   m_rotationCount = 0;
}

//+------------------------------------------------------------------+
//| Destructeur                                                        |
//+------------------------------------------------------------------+
CWyckoff::~CWyckoff()
{
   ClearDrawings();
}

//+------------------------------------------------------------------+
//| Initialisation                                                     |
//+------------------------------------------------------------------+
bool CWyckoff::Init(string symbol, ENUM_TIMEFRAMES tf,
                     CMarketStructure* ms, CBOSChoCh* bos, CCauseEffect* ce)
{
   if(ms == NULL || ce == NULL) return false;
   
   m_symbol = symbol;
   m_timeframe = tf;
   m_structure = ms;
   m_bos = bos;
   m_causeEffect = ce;
   m_patternCount = 0;
   
   return true;
}

//+------------------------------------------------------------------+
//| Mise à jour principale                                             |
//+------------------------------------------------------------------+
void CWyckoff::Update(int barsToCheck)
{
   if(m_causeEffect == NULL) return;
   
   // Module 7 - Patterns classiques
   m_patternCount = 0;
   DetectPatterns(barsToCheck);
   
   // Module 8 - Patterns neutres et structures de rotation
   DetectNeutralPatterns(barsToCheck);
   DetectRotationStructures(barsToCheck);
}

//+------------------------------------------------------------------+
//| Détection des patterns Wyckoff                                     |
//| Utilise les zones du Module 4 comme point de départ                |
//+------------------------------------------------------------------+
void CWyckoff::DetectPatterns(int barsToCheck)
{
   int zoneCount = m_causeEffect.GetZoneCount();
   if(zoneCount == 0) return;
   
   for(int i = 0; i < zoneCount && m_patternCount < 20; i++)
   {
      SCauseZone zone;
      if(!m_causeEffect.GetZone(i, zone)) continue;
      
      // Analyser chaque zone selon son type
      if(zone.type == CAUSE_ACCUMULATION || zone.type == CAUSE_REACCUMULATION)
         AnalyzeAccumulation(zone, i);
      else if(zone.type == CAUSE_DISTRIBUTION || zone.type == CAUSE_REDISTRIBUTION)
         AnalyzeDistribution(zone, i);
   }
}

//+------------------------------------------------------------------+
//| Analyse d'une zone d'Accumulation pour détecter pattern Wyckoff    |
//| Séquence attendue : PS → SC → AR → ST → UA → STB → (Spring) → LPS |
//+------------------------------------------------------------------+
void CWyckoff::AnalyzeAccumulation(SCauseZone &zone, int zoneIdx)
{
   SWyckoffPattern pattern;
   pattern.Init();
   
   pattern.timeStart = zone.timeStart;
   pattern.timeEnd = zone.timeEnd;
   pattern.barStart = zone.barStart;
   pattern.barEnd = zone.barEnd;
   pattern.rangeHigh = zone.priceHigh;
   pattern.rangeLow = zone.priceLow;
   pattern.currentPhase = WP_PHASE_A;
   
   double rangeMid = (zone.priceHigh + zone.priceLow) / 2.0;
   double rangeSize = zone.priceHigh - zone.priceLow;
   double tolerance = rangeSize * 0.15; // 15% de tolérance
   
   // --- Phase A : Détecter PS, SC, AR ---
   datetime psTime = 0, scTime = 0, arTime = 0;
   double psPrice = 0, scPrice = 0, arPrice = 0;
   int psBar = -1, scBar = -1, arBar = -1;
   
   // SC = le plus bas swing dans la première moitié du range
   int midBar = (zone.barStart + zone.barEnd) / 2;
   if(FindSwingLow(zone.barStart, midBar, scTime, scPrice, scBar))
   {
      pattern.AddEvent(WE_SC, scTime, scPrice, scBar, WP_PHASE_A);
      
      // PS = swing avant SC qui ne stoppe pas (optionnel)
      datetime tempTime;
      double tempPrice;
      int tempBar;
      if(FindSwingLow(zone.barStart + 10, scBar + 5, tempTime, tempPrice, tempBar))
      {
         if(tempPrice > scPrice && tempBar > scBar)
         {
            pattern.AddEvent(WE_PS, tempTime, tempPrice, tempBar, WP_PHASE_A);
         }
      }
   }
   
   // AR = premier swing high significatif après SC
   if(scBar > 0 && FindSwingHigh(scBar, zone.barEnd, arTime, arPrice, arBar))
   {
      if(arPrice > rangeMid)
      {
         pattern.AddEvent(WE_AR, arTime, arPrice, arBar, WP_PHASE_A);
         pattern.currentPhase = WP_PHASE_B;
      }
   }
   
   // --- Phase B : Détecter ST, UA ---
   if(arBar > 0 && scBar > 0)
   {
      // ST = test du niveau SC (swing low proche de SC sans le casser)
      datetime stTime = 0;
      double stPrice = 0;
      int stBar = -1;
      
      for(int b = arBar - 1; b >= zone.barEnd; b--)
      {
         double lo = iLow(m_symbol, m_timeframe, b);
         // ST = near SC level but doesn't break it significantly
         if(lo <= scPrice + tolerance && lo >= scPrice - tolerance * 0.5)
         {
            if(stBar < 0 || lo < stPrice)
            {
               stTime = iTime(m_symbol, m_timeframe, b);
               stPrice = lo;
               stBar = b;
            }
         }
      }
      
      if(stBar > 0)
      {
         pattern.AddEvent(WE_ST, stTime, stPrice, stBar, WP_PHASE_B);
         
         // UA = swing high qui prend la liquidité de AR
         datetime uaTime = 0;
         double uaPrice = 0;
         int uaBar = -1;
         
         for(int b = stBar - 1; b >= zone.barEnd; b--)
         {
            double hi = iHigh(m_symbol, m_timeframe, b);
            if(hi >= arPrice - tolerance)
            {
               uaTime = iTime(m_symbol, m_timeframe, b);
               uaPrice = hi;
               uaBar = b;
               break;
            }
         }
         
         if(uaBar > 0)
            pattern.AddEvent(WE_UA, uaTime, uaPrice, uaBar, WP_PHASE_B);
      }
   }
   
   // --- Phase C : Détecter STB, (Spring), Test/LPS ---
   if(zone.hasLiqGrab && scBar > 0)
   {
      pattern.currentPhase = WP_PHASE_C;
      
      // Chercher les breaks sous le niveau SC-ST
      double liqLevel = scPrice;
      int stbBar = -1, springBar = -1;
      double stbPrice = 0, springPrice = 0;
      datetime stbTime = 0, springTime = 0;
      
      // Parcourir pour trouver les breaks
      for(int b = zone.barStart; b >= zone.barEnd; b--)
      {
         double lo = iLow(m_symbol, m_timeframe, b);
         if(lo < liqLevel)
         {
            if(stbBar < 0)
            {
               // Premier break = STB
               stbBar = b;
               stbPrice = lo;
               stbTime = iTime(m_symbol, m_timeframe, b);
            }
            else if(lo < stbPrice)
            {
               // Deuxième break plus profond = Spring (Type 1)
               springBar = b;
               springPrice = lo;
               springTime = iTime(m_symbol, m_timeframe, b);
            }
         }
      }
      
      if(stbBar > 0)
      {
         pattern.AddEvent(WE_STB, stbTime, stbPrice, stbBar, WP_PHASE_C);
         
         if(springBar > 0)
         {
            pattern.AddEvent(WE_SPRING, springTime, springPrice, springBar, WP_PHASE_C);
            pattern.type = WYCK_ACCUMULATION_1;
         }
         else
         {
            pattern.type = WYCK_ACCUMULATION_2;
         }
         
         // LPS = test après liquidité (entrée !) + confirmation ChoCh/BOS haussier
         int afterLiqBar = (springBar > 0) ? springBar : stbBar;
         datetime lpsTime = 0;
         double lpsPrice = 0;
         int lpsBar = -1;
         
         for(int b = afterLiqBar - 1; b >= MathMax(zone.barEnd - 5, 0); b--)
         {
            double lo = iLow(m_symbol, m_timeframe, b);
            if(lo >= liqLevel - tolerance && lo <= liqLevel + tolerance)
            {
               // Vérifier qu'il y a une confirmation ChoCh/BOS haussier après ce test
               // = le prix fait un higher high par rapport aux bougies récentes
               bool hasChochConfirm = false;
               double recentHigh = 0;
               for(int k = b + 3; k > b && k >= 0; k--)
                  recentHigh = MathMax(recentHigh, iHigh(m_symbol, m_timeframe, k));
               for(int k = b - 1; k >= MathMax(b - 5, 0); k--)
               {
                  if(iClose(m_symbol, m_timeframe, k) > recentHigh)
                  { hasChochConfirm = true; break; }
               }
               
               if(hasChochConfirm)
               {
                  lpsTime = iTime(m_symbol, m_timeframe, b);
                  lpsPrice = lo;
                  lpsBar = b;
                  break;
               }
            }
         }
         
         if(lpsBar > 0)
         {
            pattern.AddEvent(WE_LPS, lpsTime, lpsPrice, lpsBar, WP_PHASE_C);
            pattern.currentPhase = WP_PHASE_D;
         }
      }
   }
   else if(scBar > 0)
   {
      // Pas de liquidity grab détecté par Module 4, essayer de le trouver
      pattern.type = WYCK_ACCUMULATION_2;
   }
   
   // --- Phase D/E : Détecter SOS, BU ---
   if(zone.hasBOS)
   {
      // SOS = BOS haussier après Phase C
      datetime sosTime = 0;
      double sosPrice = 0;
      int sosBar = -1;
      
      for(int b = zone.barEnd; b >= MathMax(zone.barEnd - 10, 0); b--)
      {
         double hi = iHigh(m_symbol, m_timeframe, b);
         if(hi > zone.priceHigh)
         {
            sosTime = iTime(m_symbol, m_timeframe, b);
            sosPrice = hi;
            sosBar = b;
            break;
         }
      }
      
      if(sosBar >= 0)
      {
         pattern.AddEvent(WE_SOS, sosTime, sosPrice, sosBar, WP_PHASE_D);
         pattern.currentPhase = WP_PHASE_E;
         pattern.isComplete = true;
      }
   }
   
   // Calculer Golden Entry si applicable
   if(pattern.type != WYCK_NONE && pattern.eventCount >= 3)
   {
      DetectGoldenEntry(pattern);
      m_patterns[m_patternCount++] = pattern;
   }
}

//+------------------------------------------------------------------+
//| Analyse d'une zone de Distribution pour détecter pattern Wyckoff   |
//| Séquence attendue : PSY → BC → AR → ST → MSO → UT → (UTAD) → LPSY |
//+------------------------------------------------------------------+
void CWyckoff::AnalyzeDistribution(SCauseZone &zone, int zoneIdx)
{
   SWyckoffPattern pattern;
   pattern.Init();
   
   pattern.timeStart = zone.timeStart;
   pattern.timeEnd = zone.timeEnd;
   pattern.barStart = zone.barStart;
   pattern.barEnd = zone.barEnd;
   pattern.rangeHigh = zone.priceHigh;
   pattern.rangeLow = zone.priceLow;
   pattern.currentPhase = WP_PHASE_A;
   
   double rangeMid = (zone.priceHigh + zone.priceLow) / 2.0;
   double rangeSize = zone.priceHigh - zone.priceLow;
   double tolerance = rangeSize * 0.15;
   
   // --- Phase A : Détecter PSY, BC, AR ---
   datetime bcTime = 0, arTime = 0;
   double bcPrice = 0, arPrice = 0;
   int bcBar = -1, arBar = -1;
   
   // BC = le plus haut swing dans la première moitié du range
   int midBar = (zone.barStart + zone.barEnd) / 2;
   if(FindSwingHigh(zone.barStart, midBar, bcTime, bcPrice, bcBar))
   {
      pattern.AddEvent(WE_BC, bcTime, bcPrice, bcBar, WP_PHASE_A);
      
      // PSY = swing avant BC qui ne stoppe pas (optionnel)
      datetime tempTime;
      double tempPrice;
      int tempBar;
      if(FindSwingHigh(zone.barStart + 10, bcBar + 5, tempTime, tempPrice, tempBar))
      {
         if(tempPrice < bcPrice && tempBar > bcBar)
         {
            pattern.AddEvent(WE_PSY, tempTime, tempPrice, tempBar, WP_PHASE_A);
         }
      }
   }
   
   // AR = premier swing low significatif après BC
   if(bcBar > 0 && FindSwingLow(bcBar, zone.barEnd, arTime, arPrice, arBar))
   {
      if(arPrice < rangeMid)
      {
         pattern.AddEvent(WE_AR, arTime, arPrice, arBar, WP_PHASE_A);
         pattern.currentPhase = WP_PHASE_B;
      }
   }
   
   // --- Phase B : Détecter ST, MSO ---
   if(arBar > 0 && bcBar > 0)
   {
      // ST = test du niveau BC
      datetime stTime = 0;
      double stPrice = 0;
      int stBar = -1;
      
      for(int b = arBar - 1; b >= zone.barEnd; b--)
      {
         double hi = iHigh(m_symbol, m_timeframe, b);
         if(hi >= bcPrice - tolerance && hi <= bcPrice + tolerance * 0.5)
         {
            if(stBar < 0 || hi > stPrice)
            {
               stTime = iTime(m_symbol, m_timeframe, b);
               stPrice = hi;
               stBar = b;
            }
         }
      }
      
      if(stBar > 0)
      {
         pattern.AddEvent(WE_ST, stTime, stPrice, stBar, WP_PHASE_B);
         
         // MSO = swing low qui prend la liquidité de AR
         datetime msoTime = 0;
         double msoPrice = 0;
         int msoBar = -1;
         
         for(int b = stBar - 1; b >= zone.barEnd; b--)
         {
            double lo = iLow(m_symbol, m_timeframe, b);
            if(lo <= arPrice + tolerance)
            {
               msoTime = iTime(m_symbol, m_timeframe, b);
               msoPrice = lo;
               msoBar = b;
               break;
            }
         }
         
         if(msoBar > 0)
            pattern.AddEvent(WE_MSO, msoTime, msoPrice, msoBar, WP_PHASE_B);
      }
   }
   
   // --- Phase C : Détecter UT, (UTAD), Test/LPSY ---
   if(zone.hasLiqGrab && bcBar > 0)
   {
      pattern.currentPhase = WP_PHASE_C;
      
      double liqLevel = bcPrice;
      int utBar = -1, utadBar = -1;
      double utPrice = 0, utadPrice = 0;
      datetime utTime = 0, utadTime = 0;
      
      for(int b = zone.barStart; b >= zone.barEnd; b--)
      {
         double hi = iHigh(m_symbol, m_timeframe, b);
         if(hi > liqLevel)
         {
            if(utBar < 0)
            {
               utBar = b;
               utPrice = hi;
               utTime = iTime(m_symbol, m_timeframe, b);
            }
            else if(hi > utPrice)
            {
               utadBar = b;
               utadPrice = hi;
               utadTime = iTime(m_symbol, m_timeframe, b);
            }
         }
      }
      
      if(utBar > 0)
      {
         pattern.AddEvent(WE_UT, utTime, utPrice, utBar, WP_PHASE_C);
         
         if(utadBar > 0)
         {
            pattern.AddEvent(WE_UTAD, utadTime, utadPrice, utadBar, WP_PHASE_C);
            pattern.type = WYCK_DISTRIBUTION_1;
         }
         else
         {
            pattern.type = WYCK_DISTRIBUTION_2;
         }
         
         // LPSY = test après liquidité (entrée !) + confirmation ChoCh/BOS baissier
         int afterLiqBar = (utadBar > 0) ? utadBar : utBar;
         datetime lpsyTime = 0;
         double lpsyPrice = 0;
         int lpsyBar = -1;
         
         for(int b = afterLiqBar - 1; b >= MathMax(zone.barEnd - 5, 0); b--)
         {
            double hi = iHigh(m_symbol, m_timeframe, b);
            if(hi >= liqLevel - tolerance && hi <= liqLevel + tolerance)
            {
               // Vérifier confirmation ChoCh/BOS baissier après ce test
               // = le prix fait un lower low par rapport aux bougies récentes
               bool hasChochConfirm = false;
               double recentLow = DBL_MAX;
               for(int k = b + 3; k > b && k >= 0; k--)
                  recentLow = MathMin(recentLow, iLow(m_symbol, m_timeframe, k));
               for(int k = b - 1; k >= MathMax(b - 5, 0); k--)
               {
                  if(iClose(m_symbol, m_timeframe, k) < recentLow)
                  { hasChochConfirm = true; break; }
               }
               
               if(hasChochConfirm)
               {
                  lpsyTime = iTime(m_symbol, m_timeframe, b);
                  lpsyPrice = hi;
                  lpsyBar = b;
                  break;
               }
            }
         }
         
         if(lpsyBar > 0)
         {
            pattern.AddEvent(WE_LPSY, lpsyTime, lpsyPrice, lpsyBar, WP_PHASE_C);
            pattern.currentPhase = WP_PHASE_D;
         }
      }
   }
   else if(bcBar > 0)
   {
      pattern.type = WYCK_DISTRIBUTION_2;
   }
   
   // --- Phase D/E : Détecter SOW ---
   if(zone.hasBOS)
   {
      datetime sowTime = 0;
      double sowPrice = 0;
      int sowBar = -1;
      
      for(int b = zone.barEnd; b >= MathMax(zone.barEnd - 10, 0); b--)
      {
         double lo = iLow(m_symbol, m_timeframe, b);
         if(lo < zone.priceLow)
         {
            sowTime = iTime(m_symbol, m_timeframe, b);
            sowPrice = lo;
            sowBar = b;
            break;
         }
      }
      
      if(sowBar >= 0)
      {
         pattern.AddEvent(WE_SOW, sowTime, sowPrice, sowBar, WP_PHASE_D);
         pattern.currentPhase = WP_PHASE_E;
         pattern.isComplete = true;
      }
   }
   
   if(pattern.type != WYCK_NONE && pattern.eventCount >= 3)
   {
      DetectGoldenEntry(pattern);
      m_patterns[m_patternCount++] = pattern;
   }
}

//+------------------------------------------------------------------+
//| Trouver un swing low dans une plage de barres                      |
//+------------------------------------------------------------------+
bool CWyckoff::FindSwingLow(int barStart, int barEnd, datetime &outTime, 
                             double &outPrice, int &outBar)
{
   if(barStart <= barEnd) return false;
   
   double lowestPrice = DBL_MAX;
   int lowestBar = -1;
   
   for(int b = barStart; b >= barEnd; b--)
   {
      double lo = iLow(m_symbol, m_timeframe, b);
      if(lo < lowestPrice)
      {
         lowestPrice = lo;
         lowestBar = b;
      }
   }
   
   if(lowestBar >= 0)
   {
      outTime = iTime(m_symbol, m_timeframe, lowestBar);
      outPrice = lowestPrice;
      outBar = lowestBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Trouver un swing high dans une plage de barres                     |
//+------------------------------------------------------------------+
bool CWyckoff::FindSwingHigh(int barStart, int barEnd, datetime &outTime, 
                              double &outPrice, int &outBar)
{
   if(barStart <= barEnd) return false;
   
   double highestPrice = 0;
   int highestBar = -1;
   
   for(int b = barStart; b >= barEnd; b--)
   {
      double hi = iHigh(m_symbol, m_timeframe, b);
      if(hi > highestPrice)
      {
         highestPrice = hi;
         highestBar = b;
      }
   }
   
   if(highestBar >= 0)
   {
      outTime = iTime(m_symbol, m_timeframe, highestBar);
      outPrice = highestPrice;
      outBar = highestBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Détection du Golden Entry (point d'entrée optimal)                 |
//| Accumulation : entrée sur LPS après Spring/STB                     |
//| Distribution : entrée sur LPSY après UT/UTAD                       |
//+------------------------------------------------------------------+
void CWyckoff::DetectGoldenEntry(SWyckoffPattern &pattern)
{
   pattern.hasGoldenEntry = false;
   
   if(pattern.IsAccumulation())
   {
      // Chercher LPS
      for(int i = 0; i < pattern.eventCount; i++)
      {
         if(pattern.events[i].type == WE_LPS)
         {
            pattern.hasGoldenEntry = true;
            pattern.goldenEntryTime = pattern.events[i].time;
            pattern.goldenEntryPrice = pattern.events[i].price;
            
            // SL sous le Spring ou STB
            double slPrice = pattern.rangeLow;
            for(int j = 0; j < pattern.eventCount; j++)
            {
               if(pattern.events[j].type == WE_SPRING || 
                  pattern.events[j].type == WE_STB)
               {
                  if(pattern.events[j].price < slPrice)
                     slPrice = pattern.events[j].price;
               }
            }
            double slBuffer = (pattern.rangeHigh - pattern.rangeLow) * 0.1;
            pattern.goldenEntrySL = slPrice - slBuffer;
            
            // TP1 = PS.high (le haut du PS se fait TOUJOURS swept)
            // Si PS détecté, utiliser son prix ; sinon fallback au range high
            double psHighPrice = pattern.rangeHigh;
            for(int j = 0; j < pattern.eventCount; j++)
            {
               if(pattern.events[j].type == WE_PS)
               {
                  psHighPrice = pattern.events[j].price;
                  break;
               }
            }
            pattern.goldenEntryTP1 = psHighPrice;
            
            // TP2 = projection au-delà du range (intact levels idéalement)
            double rangeSize = pattern.rangeHigh - pattern.rangeLow;
            pattern.goldenEntryTP2 = pattern.rangeHigh + rangeSize;
            
            break;
         }
      }
   }
   else if(pattern.IsDistribution())
   {
      // Chercher LPSY
      for(int i = 0; i < pattern.eventCount; i++)
      {
         if(pattern.events[i].type == WE_LPSY)
         {
            pattern.hasGoldenEntry = true;
            pattern.goldenEntryTime = pattern.events[i].time;
            pattern.goldenEntryPrice = pattern.events[i].price;
            
            // SL au-dessus du UT ou UTAD
            double slPrice = pattern.rangeHigh;
            for(int j = 0; j < pattern.eventCount; j++)
            {
               if(pattern.events[j].type == WE_UTAD || 
                  pattern.events[j].type == WE_UT)
               {
                  if(pattern.events[j].price > slPrice)
                     slPrice = pattern.events[j].price;
               }
            }
            double slBuffer = (pattern.rangeHigh - pattern.rangeLow) * 0.1;
            pattern.goldenEntrySL = slPrice + slBuffer;
            
            // TP1 = PSY.low (le bas du PSY se fait TOUJOURS swept)
            // Si PSY détecté, utiliser son prix ; sinon fallback au range low
            double psyLowPrice = pattern.rangeLow;
            for(int j = 0; j < pattern.eventCount; j++)
            {
               if(pattern.events[j].type == WE_PSY)
               {
                  psyLowPrice = pattern.events[j].price;
                  break;
               }
            }
            pattern.goldenEntryTP1 = psyLowPrice;
            
            // TP2 = projection sous le range
            double rangeSize = pattern.rangeHigh - pattern.rangeLow;
            pattern.goldenEntryTP2 = pattern.rangeLow - rangeSize;
            
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Obtenir un pattern par index                                       |
//+------------------------------------------------------------------+
bool CWyckoff::GetPattern(int index, SWyckoffPattern &pattern)
{
   if(index < 0 || index >= m_patternCount) return false;
   pattern = m_patterns[index];
   return true;
}

//+------------------------------------------------------------------+
bool CWyckoff::HasActiveAccumulation()
{
   for(int i = 0; i < m_patternCount; i++)
      if(m_patterns[i].IsAccumulation() && m_patterns[i].barEnd <= 50)
         return true;
   return false;
}

//+------------------------------------------------------------------+
bool CWyckoff::HasActiveDistribution()
{
   for(int i = 0; i < m_patternCount; i++)
      if(m_patterns[i].IsDistribution() && m_patterns[i].barEnd <= 50)
         return true;
   return false;
}

//+------------------------------------------------------------------+
bool CWyckoff::HasGoldenEntry(bool isBullish)
{
   for(int i = 0; i < m_patternCount; i++)
   {
      if(m_patterns[i].hasGoldenEntry && m_patterns[i].barEnd <= 50)
      {
         if(isBullish && m_patterns[i].IsAccumulation())
            return true;
         if(!isBullish && m_patterns[i].IsDistribution())
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Libellé des événements                                             |
//+------------------------------------------------------------------+
string CWyckoff::GetEventLabel(ENUM_WYCKOFF_EVENT ev)
{
   switch(ev)
   {
      case WE_PS:     return "PS";
      case WE_SC:     return "SC";
      case WE_AR:     return "AR";
      case WE_ST:     return "ST";
      case WE_UA:     return "UA";
      case WE_STB:    return "STB";
      case WE_SPRING: return "SPRING";
      case WE_LPS:    return "LPS";
      case WE_SOS:    return "SOS";
      case WE_BU:     return "BU";
      case WE_PSY:    return "PSY";
      case WE_BC:     return "BC";
      case WE_MSO:    return "mSOW";
      case WE_UT:     return "UT";
      case WE_UTAD:   return "UTAD";
      case WE_LPSY:   return "LPSY";
      case WE_SOW:    return "SOW";
      case WE_TEST:   return "TEST";
      default:        return "";
   }
}

//+------------------------------------------------------------------+
//| Dessin des patterns Wyckoff                                        |
//| Fidèle aux images pédagogiques du Module 7                        |
//+------------------------------------------------------------------+
void CWyckoff::DrawPatterns(color accumColor, color distribColor)
{
   for(int i = 0; i < m_patternCount; i++)
   {
      SWyckoffPattern pat = m_patterns[i];
      if(pat.type == WYCK_NONE) continue;
      
      string prefix = "SMC_WYCK_" + IntegerToString(i);
      bool isAccum = pat.IsAccumulation();
      color mainColor = isAccum ? accumColor : distribColor;
      
      // Rectangle de la zone (fond)
      string rectName = prefix + "_rect";
      ObjectCreate(0, rectName, OBJ_RECTANGLE, 0,
         pat.timeStart, pat.rangeHigh,
         pat.timeEnd, pat.rangeLow);
      ObjectSetInteger(0, rectName, OBJPROP_COLOR, mainColor);
      ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
      ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
      ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
      
      // Ligne haute du range (fourchette haute)
      string highLine = prefix + "_high";
      ObjectCreate(0, highLine, OBJ_TREND, 0,
         pat.timeStart, pat.rangeHigh,
         pat.timeEnd, pat.rangeHigh);
      ObjectSetInteger(0, highLine, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, highLine, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, highLine, OBJPROP_RAY_RIGHT, false);
      
      // Ligne basse du range (fourchette basse)
      string lowLine = prefix + "_low";
      ObjectCreate(0, lowLine, OBJ_TREND, 0,
         pat.timeStart, pat.rangeLow,
         pat.timeEnd, pat.rangeLow);
      ObjectSetInteger(0, lowLine, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, lowLine, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, lowLine, OBJPROP_RAY_RIGHT, false);
      
      // Label du type de pattern
      string typeLabel = prefix + "_type";
      string typeText = "";
      switch(pat.type)
      {
         case WYCK_ACCUMULATION_1:  typeText = "ACCUMULATION #1"; break;
         case WYCK_ACCUMULATION_2:  typeText = "ACCUMULATION #2"; break;
         case WYCK_DISTRIBUTION_1:  typeText = "DISTRIBUTION #1"; break;
         case WYCK_DISTRIBUTION_2:  typeText = "DISTRIBUTION #2"; break;
      }
      
      double labelPrice = isAccum ? pat.rangeLow : pat.rangeHigh;
      ObjectCreate(0, typeLabel, OBJ_TEXT, 0, pat.timeStart, labelPrice);
      ObjectSetString(0, typeLabel, OBJPROP_TEXT, typeText);
      ObjectSetInteger(0, typeLabel, OBJPROP_COLOR, mainColor);
      ObjectSetInteger(0, typeLabel, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, typeLabel, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, typeLabel, OBJPROP_ANCHOR, 
         isAccum ? ANCHOR_UPPER : ANCHOR_LOWER);
      
      // Dessiner chaque événement Wyckoff
      for(int j = 0; j < pat.eventCount; j++)
      {
         SWyckoffEvent ev = pat.events[j];
         if(ev.type == WE_NONE) continue;
         
         string evName = prefix + "_ev_" + IntegerToString(j);
         string evLabel = GetEventLabel(ev.type);
         
         // Label de l'événement
         ObjectCreate(0, evName, OBJ_TEXT, 0, ev.time, ev.price);
         ObjectSetString(0, evName, OBJPROP_TEXT, evLabel);
         ObjectSetInteger(0, evName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, evName, OBJPROP_FONTSIZE, 8);
         
         // Ancrage: événements bas → en bas, événements haut → en haut
         bool isHighEvent = (ev.type == WE_AR || ev.type == WE_UA || 
                             ev.type == WE_BC || ev.type == WE_ST ||
                             ev.type == WE_UT || ev.type == WE_UTAD ||
                             ev.type == WE_LPSY || ev.type == WE_SOS);
         ObjectSetInteger(0, evName, OBJPROP_ANCHOR, 
            isHighEvent ? ANCHOR_LOWER : ANCHOR_UPPER);
      }
   }
}

//+------------------------------------------------------------------+
//| Dessin des Golden Entries                                          |
//+------------------------------------------------------------------+
void CWyckoff::DrawGoldenEntries(color goldenColor)
{
   for(int i = 0; i < m_patternCount; i++)
   {
      SWyckoffPattern pat = m_patterns[i];
      if(!pat.hasGoldenEntry) continue;
      
      string prefix = "SMC_GOLDEN_" + IntegerToString(i);
      
      // Marker pour l'entrée
      string entryMark = prefix + "_entry";
      ObjectCreate(0, entryMark, OBJ_ARROW, 0, 
         pat.goldenEntryTime, pat.goldenEntryPrice);
      ObjectSetInteger(0, entryMark, OBJPROP_ARROWCODE, 
         pat.IsAccumulation() ? 233 : 234);  // Flèche haut/bas
      ObjectSetInteger(0, entryMark, OBJPROP_COLOR, goldenColor);
      ObjectSetInteger(0, entryMark, OBJPROP_WIDTH, 3);
      
      // Label "GOLDEN ENTRY"
      string goldenLabel = prefix + "_label";
      ObjectCreate(0, goldenLabel, OBJ_TEXT, 0, 
         pat.goldenEntryTime, pat.goldenEntryPrice);
      ObjectSetString(0, goldenLabel, OBJPROP_TEXT, "GOLDEN ENTRY");
      ObjectSetInteger(0, goldenLabel, OBJPROP_COLOR, goldenColor);
      ObjectSetInteger(0, goldenLabel, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, goldenLabel, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, goldenLabel, OBJPROP_ANCHOR, 
         pat.IsAccumulation() ? ANCHOR_LOWER : ANCHOR_UPPER);
      
      // Rectangle SL/TP pour visualiser le trade
      // Zone SL (rouge)
      string slZone = prefix + "_sl";
      double slTop = pat.IsAccumulation() ? pat.goldenEntryPrice : pat.goldenEntrySL;
      double slBot = pat.IsAccumulation() ? pat.goldenEntrySL : pat.goldenEntryPrice;
      datetime futureTime = pat.goldenEntryTime + PeriodSeconds(m_timeframe) * 20;
      
      ObjectCreate(0, slZone, OBJ_RECTANGLE, 0,
         pat.goldenEntryTime, slTop,
         futureTime, slBot);
      ObjectSetInteger(0, slZone, OBJPROP_COLOR, C'150,50,50');
      ObjectSetInteger(0, slZone, OBJPROP_FILL, true);
      ObjectSetInteger(0, slZone, OBJPROP_BACK, true);
      
      // Zone TP1 (vert)
      string tpZone = prefix + "_tp";
      double tpTop = pat.IsAccumulation() ? pat.goldenEntryTP1 : pat.goldenEntryPrice;
      double tpBot = pat.IsAccumulation() ? pat.goldenEntryPrice : pat.goldenEntryTP1;
      
      ObjectCreate(0, tpZone, OBJ_RECTANGLE, 0,
         pat.goldenEntryTime, tpTop,
         futureTime, tpBot);
      ObjectSetInteger(0, tpZone, OBJPROP_COLOR, C'50,150,50');
      ObjectSetInteger(0, tpZone, OBJPROP_FILL, true);
      ObjectSetInteger(0, tpZone, OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| Nettoyer les dessins                                               |
//+------------------------------------------------------------------+
void CWyckoff::ClearDrawings()
{
   ObjectsDeleteAll(0, "SMC_WYCK_");
   ObjectsDeleteAll(0, "SMC_GOLDEN_");
   ObjectsDeleteAll(0, "SMC_NEUTRAL_");
   ObjectsDeleteAll(0, "SMC_ROTATION_");
}

//+------------------------------------------------------------------+
//| MODULE 8 - WYCKOFF NEUTRE/AVANCÉ                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Détection des patterns neutres (double décompte BC+SC)             |
//+------------------------------------------------------------------+
void CWyckoff::DetectNeutralPatterns(int barsToCheck)
{
   m_neutralCount = 0;
   int zoneCount = m_causeEffect.GetZoneCount();
   if(zoneCount == 0) return;
   
   for(int i = 0; i < zoneCount && m_neutralCount < 10; i++)
   {
      SCauseZone zone;
      if(!m_causeEffect.GetZone(i, zone)) continue;
      
      // Wyckoff neutre s'applique aux consolidations latérales
      if(zone.type != CAUSE_ACCUMULATION && zone.type != CAUSE_DISTRIBUTION)
         continue;
      
      AnalyzeNeutralZone(zone, i);
   }
}

//+------------------------------------------------------------------+
//| Analyser une zone comme pattern neutre (dual count)                |
//+------------------------------------------------------------------+
void CWyckoff::AnalyzeNeutralZone(SCauseZone &zone, int zoneIdx)
{
   SWyckoffNeutral neutral;
   neutral.Init();
   
   neutral.rangeHigh = zone.priceHigh;  // BC level
   neutral.rangeLow = zone.priceLow;    // SC level
   neutral.timeStart = zone.timeStart;
   neutral.timeEnd = zone.timeEnd;
   neutral.barStart = zone.barStart;
   neutral.barEnd = zone.barEnd;
   
   double rangeSize = zone.priceHigh - zone.priceLow;
   double tolerance = rangeSize * 0.10;  // 10% tolerance
   
   // Vérifier test de l'offre (BC) et de la demande (SC)
   neutral.bcSupplyTested = CheckSupplyTest(zone.priceHigh, zone.barStart, zone.barEnd);
   neutral.scDemandTested = CheckDemandTest(zone.priceLow, zone.barStart, zone.barEnd);
   
   // Vérifier prise de liquidité externe (UT au-dessus BC, STB en-dessous SC)
   double utPrice = 0, stbPrice = 0;
   datetime utTime = 0, stbTime = 0;
   
   neutral.utTriggered = CheckExternalLiquidity(zone.priceHigh, true, 
                                                  zone.barStart, zone.barEnd, 
                                                  utPrice, utTime);
   if(neutral.utTriggered)
   {
      neutral.utPrice = utPrice;
      neutral.utTime = utTime;
   }
   
   neutral.stbTriggered = CheckExternalLiquidity(zone.priceLow, false, 
                                                   zone.barStart, zone.barEnd, 
                                                   stbPrice, stbTime);
   if(neutral.stbTriggered)
   {
      neutral.stbPrice = stbPrice;
      neutral.stbTime = stbTime;
   }
   
   // Déterminer la direction après prise de liquidité externe
   if(neutral.utTriggered && !neutral.stbTriggered)
      neutral.direction = BIAS_BEARISH;  // Après UT → baisse
   else if(neutral.stbTriggered && !neutral.utTriggered)
      neutral.direction = BIAS_BULLISH;  // Après STB → hausse
   else if(neutral.utTriggered && neutral.stbTriggered)
   {
      // Les deux liquidités prises - la dernière détermine la direction
      if(utTime > stbTime)
         neutral.direction = BIAS_BEARISH;
      else
         neutral.direction = BIAS_BULLISH;
   }
   
   // Valider le pattern (doit avoir au moins un test ET une prise de liq externe)
   neutral.isValid = (neutral.bcSupplyTested || neutral.scDemandTested) &&
                     (neutral.utTriggered || neutral.stbTriggered);
   
   if(neutral.isValid)
   {
      m_neutralPatterns[m_neutralCount] = neutral;
      m_neutralCount++;
   }
}

//+------------------------------------------------------------------+
//| Vérifier si l'offre (BC level) a été testée                        |
//+------------------------------------------------------------------+
bool CWyckoff::CheckSupplyTest(double bcLevel, int barStart, int barEnd)
{
   double tolerance = bcLevel * 0.003;  // 0.3%
   int testCount = 0;
   
   for(int i = barEnd; i <= barStart && i >= 0; i++)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      // Un test approche le niveau mais ne le dépasse pas significativement
      if(high >= bcLevel - tolerance && high <= bcLevel + tolerance)
         testCount++;
   }
   
   return (testCount >= 2);  // Au moins 2 tests de l'offre
}

//+------------------------------------------------------------------+
//| Vérifier si la demande (SC level) a été testée                     |
//+------------------------------------------------------------------+
bool CWyckoff::CheckDemandTest(double scLevel, int barStart, int barEnd)
{
   double tolerance = scLevel * 0.003;  // 0.3%
   int testCount = 0;
   
   for(int i = barEnd; i <= barStart && i >= 0; i++)
   {
      double low = iLow(m_symbol, m_timeframe, i);
      // Un test approche le niveau mais ne le dépasse pas significativement
      if(low <= scLevel + tolerance && low >= scLevel - tolerance)
         testCount++;
   }
   
   return (testCount >= 2);  // Au moins 2 tests de la demande
}

//+------------------------------------------------------------------+
//| Vérifier prise de liquidité externe                                 |
//+------------------------------------------------------------------+
bool CWyckoff::CheckExternalLiquidity(double level, bool isAbove, int barStart, 
                                        int barEnd, double &outPrice, datetime &outTime)
{
   double tolerance = level * 0.002;  // 0.2% - breakout clair requis
   
   for(int i = barEnd; i <= barStart && i >= 0; i++)
   {
      if(isAbove)
      {
         double high = iHigh(m_symbol, m_timeframe, i);
         if(high > level + tolerance)
         {
            outPrice = high;
            outTime = iTime(m_symbol, m_timeframe, i);
            return true;
         }
      }
      else
      {
         double low = iLow(m_symbol, m_timeframe, i);
         if(low < level - tolerance)
         {
            outPrice = low;
            outTime = iTime(m_symbol, m_timeframe, i);
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Accesseur pattern neutre                                            |
//+------------------------------------------------------------------+
bool CWyckoff::GetNeutralPattern(int index, SWyckoffNeutral &pattern)
{
   if(index < 0 || index >= m_neutralCount) return false;
   pattern = m_neutralPatterns[index];
   return true;
}

//+------------------------------------------------------------------+
//| Check if there is a neutral setup                                   |
//+------------------------------------------------------------------+
bool CWyckoff::HasNeutralSetup()
{
   for(int i = 0; i < m_neutralCount; i++)
   {
      if(m_neutralPatterns[i].isValid)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Dessiner les patterns neutres                                       |
//+------------------------------------------------------------------+
void CWyckoff::DrawNeutralPatterns(color neutralColor)
{
   for(int i = 0; i < m_neutralCount; i++)
   {
      SWyckoffNeutral neutral = m_neutralPatterns[i];
      if(!neutral.isValid) continue;
      
      string prefix = "SMC_NEUTRAL_" + IntegerToString(i);
      
      // Rectangle du range (BC-SC)
      string rangeName = prefix + "_range";
      ObjectCreate(0, rangeName, OBJ_RECTANGLE, 0,
         neutral.timeStart, neutral.rangeHigh,
         neutral.timeEnd, neutral.rangeLow);
      ObjectSetInteger(0, rangeName, OBJPROP_COLOR, neutralColor);
      ObjectSetInteger(0, rangeName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, rangeName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, rangeName, OBJPROP_FILL, false);
      ObjectSetInteger(0, rangeName, OBJPROP_BACK, true);
      
      // Label BC (haut)
      string bcLabel = prefix + "_BC";
      ObjectCreate(0, bcLabel, OBJ_TEXT, 0, neutral.timeStart, neutral.rangeHigh);
      ObjectSetString(0, bcLabel, OBJPROP_TEXT, "BC (Supply)");
      ObjectSetInteger(0, bcLabel, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, bcLabel, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, bcLabel, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      
      // Label SC (bas)
      string scLabel = prefix + "_SC";
      ObjectCreate(0, scLabel, OBJ_TEXT, 0, neutral.timeStart, neutral.rangeLow);
      ObjectSetString(0, scLabel, OBJPROP_TEXT, "SC (Demand)");
      ObjectSetInteger(0, scLabel, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, scLabel, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, scLabel, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      
      // Marker UT si déclenché
      if(neutral.utTriggered)
      {
         string utMark = prefix + "_UT";
         ObjectCreate(0, utMark, OBJ_ARROW, 0, neutral.utTime, neutral.utPrice);
         ObjectSetInteger(0, utMark, OBJPROP_ARROWCODE, 234);  // Flèche bas
         ObjectSetInteger(0, utMark, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, utMark, OBJPROP_WIDTH, 2);
         
         string utLabel = prefix + "_UT_lbl";
         ObjectCreate(0, utLabel, OBJ_TEXT, 0, neutral.utTime, neutral.utPrice);
         ObjectSetString(0, utLabel, OBJPROP_TEXT, "UT");
         ObjectSetInteger(0, utLabel, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, utLabel, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(0, utLabel, OBJPROP_ANCHOR, ANCHOR_LOWER);
      }
      
      // Marker STB si déclenché
      if(neutral.stbTriggered)
      {
         string stbMark = prefix + "_STB";
         ObjectCreate(0, stbMark, OBJ_ARROW, 0, neutral.stbTime, neutral.stbPrice);
         ObjectSetInteger(0, stbMark, OBJPROP_ARROWCODE, 233);  // Flèche haut
         ObjectSetInteger(0, stbMark, OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0, stbMark, OBJPROP_WIDTH, 2);
         
         string stbLabel = prefix + "_STB_lbl";
         ObjectCreate(0, stbLabel, OBJ_TEXT, 0, neutral.stbTime, neutral.stbPrice);
         ObjectSetString(0, stbLabel, OBJPROP_TEXT, "STB");
         ObjectSetInteger(0, stbLabel, OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0, stbLabel, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(0, stbLabel, OBJPROP_ANCHOR, ANCHOR_UPPER);
      }
      
      // Label direction finale
      string dirLabel = prefix + "_dir";
      double dirY = (neutral.rangeHigh + neutral.rangeLow) / 2;
      ObjectCreate(0, dirLabel, OBJ_TEXT, 0, neutral.timeEnd, dirY);
      string dirText = (neutral.direction == BIAS_BULLISH) ? "→ LONG" : "→ SHORT";
      ObjectSetString(0, dirLabel, OBJPROP_TEXT, dirText);
      ObjectSetInteger(0, dirLabel, OBJPROP_COLOR, 
         neutral.direction == BIAS_BULLISH ? clrLime : clrOrangeRed);
      ObjectSetInteger(0, dirLabel, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, dirLabel, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, dirLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
}

//+------------------------------------------------------------------+
//| MODULE 8 - STRUCTURE DE ROTATION                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Détection des structures de rotation                                |
//+------------------------------------------------------------------+
void CWyckoff::DetectRotationStructures(int barsToCheck)
{
   m_rotationCount = 0;
   
   // Analyser les segments de tendance pour détecter perte de momentum
   int bars = MathMin(barsToCheck, Bars(m_symbol, m_timeframe));
   if(bars < 50) return;  // Besoin d'assez de données
   
   // Pour chaque segment de 50 bougies, chercher perte de momentum
   for(int startBar = 0; startBar < bars - 50 && m_rotationCount < 10; startBar += 25)
   {
      int endBar = startBar + 50;
      
      SRotationStructure rotation;
      rotation.Init();
      rotation.barStart = startBar;
      rotation.barEnd = endBar;
      rotation.timeStart = iTime(m_symbol, m_timeframe, endBar);
      rotation.timeEnd = iTime(m_symbol, m_timeframe, startBar);
      
      // Calculer perte de momentum
      double impulses[5];
      int waveCount = 0;
      
      if(CalculateMomentumLoss(startBar, endBar, impulses, waveCount))
      {
         rotation.momentumLoss = true;
         rotation.waveCount = waveCount;
         for(int w = 0; w < waveCount && w < 5; w++)
            rotation.impulseSize[w] = impulses[w];
         
         // Calculer les lignes diagonales
         CalculateDiagonalLines(rotation);
         
         // Déterminer la tendance précédente et nouvelle direction
         rotation.prevTrend = (rotation.diagonalHighStart < rotation.diagonalHighEnd) 
                              ? BIAS_BULLISH : BIAS_BEARISH;
         rotation.newDirection = (rotation.prevTrend == BIAS_BULLISH) 
                                  ? BIAS_BEARISH : BIAS_BULLISH;
         
         rotation.isValid = (rotation.waveCount >= 3);
         
         if(rotation.isValid)
         {
            m_rotations[m_rotationCount] = rotation;
            m_rotationCount++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculer la perte de momentum (Elliott waves simplifiées)          |
//+------------------------------------------------------------------+
bool CWyckoff::CalculateMomentumLoss(int barStart, int barEnd, 
                                      double &impulseSize[], int &waveCount)
{
   // Trouver les swings dans la période
   waveCount = 0;
   ArrayInitialize(impulseSize, 0.0);
   
   double prevSwing = 0;
   bool prevIsHigh = false;
   
   for(int i = barEnd; i >= barStart && waveCount < 5; i--)
   {
      double high = iHigh(m_symbol, m_timeframe, i);
      double low = iLow(m_symbol, m_timeframe, i);
      
      // Détection simplifiée de swing
      bool isLocalHigh = (i > barStart) && (i < barEnd - 2);
      bool isLocalLow = (i > barStart) && (i < barEnd - 2);
      
      if(i > barStart && i < barEnd - 2)
      {
         double prevHigh = iHigh(m_symbol, m_timeframe, i + 1);
         double nextHigh = iHigh(m_symbol, m_timeframe, i - 1);
         double prevLow = iLow(m_symbol, m_timeframe, i + 1);
         double nextLow = iLow(m_symbol, m_timeframe, i - 1);
         
         isLocalHigh = (high > prevHigh && high > nextHigh);
         isLocalLow = (low < prevLow && low < nextLow);
      }
      
      if(isLocalHigh && (waveCount == 0 || !prevIsHigh))
      {
         if(prevSwing > 0)
         {
            impulseSize[waveCount] = MathAbs(high - prevSwing);
            waveCount++;
         }
         prevSwing = high;
         prevIsHigh = true;
      }
      else if(isLocalLow && (waveCount == 0 || prevIsHigh))
      {
         if(prevSwing > 0)
         {
            impulseSize[waveCount] = MathAbs(prevSwing - low);
            waveCount++;
         }
         prevSwing = low;
         prevIsHigh = false;
      }
   }
   
   // Vérifier s'il y a perte de momentum (impulsions décroissantes)
   if(waveCount >= 3)
   {
      int decreasingCount = 0;
      for(int i = 1; i < waveCount; i++)
      {
         if(impulseSize[i] < impulseSize[i-1] * 0.85)  // 15% de réduction
            decreasingCount++;
      }
      return (decreasingCount >= 2);  // Au moins 2 réductions
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculer les lignes diagonales du range de rotation                |
//+------------------------------------------------------------------+
void CWyckoff::CalculateDiagonalLines(SRotationStructure &rotation)
{
   // Trouver le plus haut et plus bas au début et à la fin
   double highStart = iHigh(m_symbol, m_timeframe, rotation.barEnd);
   double lowStart = iLow(m_symbol, m_timeframe, rotation.barEnd);
   double highEnd = iHigh(m_symbol, m_timeframe, rotation.barStart);
   double lowEnd = iLow(m_symbol, m_timeframe, rotation.barStart);
   
   // Chercher les vrais extremes dans les premiers et derniers 10%
   int rangeSize = rotation.barEnd - rotation.barStart;
   int lookbackStart = rangeSize / 10;
   int lookbackEnd = rangeSize / 10;
   
   for(int i = rotation.barEnd; i >= rotation.barEnd - lookbackStart && i >= 0; i--)
   {
      highStart = MathMax(highStart, iHigh(m_symbol, m_timeframe, i));
      lowStart = MathMin(lowStart, iLow(m_symbol, m_timeframe, i));
   }
   
   for(int i = rotation.barStart; i <= rotation.barStart + lookbackEnd && i >= 0; i++)
   {
      highEnd = MathMax(highEnd, iHigh(m_symbol, m_timeframe, i));
      lowEnd = MathMin(lowEnd, iLow(m_symbol, m_timeframe, i));
   }
   
   rotation.diagonalHighStart = highStart;
   rotation.diagonalHighEnd = highEnd;
   rotation.diagonalLowStart = lowStart;
   rotation.diagonalLowEnd = lowEnd;
}

//+------------------------------------------------------------------+
//| Accesseur structure rotation                                        |
//+------------------------------------------------------------------+
bool CWyckoff::GetRotation(int index, SRotationStructure &rotation)
{
   if(index < 0 || index >= m_rotationCount) return false;
   rotation = m_rotations[index];
   return true;
}

//+------------------------------------------------------------------+
//| Check if there is a rotation structure                              |
//+------------------------------------------------------------------+
bool CWyckoff::HasRotationStructure()
{
   for(int i = 0; i < m_rotationCount; i++)
   {
      if(m_rotations[i].isValid)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Dessiner les structures de rotation                                 |
//+------------------------------------------------------------------+
void CWyckoff::DrawRotationStructures(color rotationColor)
{
   for(int i = 0; i < m_rotationCount; i++)
   {
      SRotationStructure rotation = m_rotations[i];
      if(!rotation.isValid) continue;
      
      string prefix = "SMC_ROTATION_" + IntegerToString(i);
      
      // === PARALLÉLOGRAMME (4 lignes formant un canal diagonal) ===
      
      // Ligne diagonale haute (resistance)
      string highLine = prefix + "_high";
      ObjectCreate(0, highLine, OBJ_TREND, 0,
         rotation.timeStart, rotation.diagonalHighStart,
         rotation.timeEnd, rotation.diagonalHighEnd);
      ObjectSetInteger(0, highLine, OBJPROP_COLOR, rotationColor);
      ObjectSetInteger(0, highLine, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, highLine, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, highLine, OBJPROP_RAY_RIGHT, false);
      
      // Ligne diagonale basse (support)
      string lowLine = prefix + "_low";
      ObjectCreate(0, lowLine, OBJ_TREND, 0,
         rotation.timeStart, rotation.diagonalLowStart,
         rotation.timeEnd, rotation.diagonalLowEnd);
      ObjectSetInteger(0, lowLine, OBJPROP_COLOR, rotationColor);
      ObjectSetInteger(0, lowLine, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lowLine, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lowLine, OBJPROP_RAY_RIGHT, false);
      
      // Ligne verticale gauche (fermeture début)
      string leftLine = prefix + "_left";
      ObjectCreate(0, leftLine, OBJ_TREND, 0,
         rotation.timeStart, rotation.diagonalHighStart,
         rotation.timeStart, rotation.diagonalLowStart);
      ObjectSetInteger(0, leftLine, OBJPROP_COLOR, rotationColor);
      ObjectSetInteger(0, leftLine, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, leftLine, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, leftLine, OBJPROP_RAY_RIGHT, false);
      
      // Ligne verticale droite (fermeture fin)
      string rightLine = prefix + "_right";
      ObjectCreate(0, rightLine, OBJ_TREND, 0,
         rotation.timeEnd, rotation.diagonalHighEnd,
         rotation.timeEnd, rotation.diagonalLowEnd);
      ObjectSetInteger(0, rightLine, OBJPROP_COLOR, rotationColor);
      ObjectSetInteger(0, rightLine, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, rightLine, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, rightLine, OBJPROP_RAY_RIGHT, false);
      
      // === LABELS WYCKOFF (PSY, BC, SC, ST) ===
      
      // Label PSY (début du range)
      string psyLabel = prefix + "_PSY";
      ObjectCreate(0, psyLabel, OBJ_TEXT, 0, rotation.timeStart, rotation.diagonalLowStart);
      ObjectSetString(0, psyLabel, OBJPROP_TEXT, "PSY");
      ObjectSetInteger(0, psyLabel, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, psyLabel, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, psyLabel, OBJPROP_ANCHOR, ANCHOR_UPPER);
      
      // Label BC (Buy Climax - haut du range)
      string bcLabel = prefix + "_BC";
      datetime bcTime = rotation.timeStart + (rotation.timeEnd - rotation.timeStart) / 4;
      ObjectCreate(0, bcLabel, OBJ_TEXT, 0, bcTime, rotation.diagonalHighStart + 
         (rotation.diagonalHighEnd - rotation.diagonalHighStart) / 4);
      ObjectSetString(0, bcLabel, OBJPROP_TEXT, "BC");
      ObjectSetInteger(0, bcLabel, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, bcLabel, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, bcLabel, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, bcLabel, OBJPROP_ANCHOR, ANCHOR_LOWER);
      
      // Label SC (Selling Climax - bas du range)
      string scLabel = prefix + "_SC";
      datetime scTime = rotation.timeStart + (rotation.timeEnd - rotation.timeStart) / 3;
      ObjectCreate(0, scLabel, OBJ_TEXT, 0, scTime, rotation.diagonalLowStart + 
         (rotation.diagonalLowEnd - rotation.diagonalLowStart) / 3);
      ObjectSetString(0, scLabel, OBJPROP_TEXT, "SC");
      ObjectSetInteger(0, scLabel, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, scLabel, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, scLabel, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, scLabel, OBJPROP_ANCHOR, ANCHOR_UPPER);
      
      // Label ST (Secondary Test)
      string stLabel = prefix + "_ST";
      datetime stTime = rotation.timeStart + (rotation.timeEnd - rotation.timeStart) / 2;
      double stPrice = (rotation.diagonalHighStart + rotation.diagonalLowStart) / 2 +
                       (rotation.diagonalHighEnd + rotation.diagonalLowEnd - 
                        rotation.diagonalHighStart - rotation.diagonalLowStart) / 4;
      ObjectCreate(0, stLabel, OBJ_TEXT, 0, stTime, stPrice);
      ObjectSetString(0, stLabel, OBJPROP_TEXT, "ST");
      ObjectSetInteger(0, stLabel, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, stLabel, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, stLabel, OBJPROP_ANCHOR, ANCHOR_CENTER);
      
      // Label rotation central
      string rotLabel = prefix + "_label";
      double midPrice = (rotation.diagonalHighEnd + rotation.diagonalLowEnd) / 2;
      ObjectCreate(0, rotLabel, OBJ_TEXT, 0, rotation.timeEnd, midPrice);
      string labelText = "ROTATION (" + IntegerToString(rotation.waveCount) + " vagues)";
      ObjectSetString(0, rotLabel, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, rotLabel, OBJPROP_COLOR, rotationColor);
      ObjectSetInteger(0, rotLabel, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, rotLabel, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, rotLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
      
      // Indicateur de momentum loss
      string momLabel = prefix + "_momentum";
      ObjectCreate(0, momLabel, OBJ_TEXT, 0, rotation.timeEnd, 
         rotation.diagonalLowEnd - (rotation.diagonalHighEnd - rotation.diagonalLowEnd) * 0.15);
      ObjectSetString(0, momLabel, OBJPROP_TEXT, "⚡ Perte Momentum");
      ObjectSetInteger(0, momLabel, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, momLabel, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, momLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
      
      // Direction attendue
      string dirLabel = prefix + "_dir";
      ObjectCreate(0, dirLabel, OBJ_TEXT, 0, rotation.timeEnd,
         rotation.diagonalHighEnd + (rotation.diagonalHighEnd - rotation.diagonalLowEnd) * 0.15);
      string dirText = (rotation.newDirection == BIAS_BULLISH) ? "↑ ACHAT" : "↓ VENTE";
      ObjectSetString(0, dirLabel, OBJPROP_TEXT, dirText);
      ObjectSetInteger(0, dirLabel, OBJPROP_COLOR, 
         rotation.newDirection == BIAS_BULLISH ? clrLime : clrOrangeRed);
      ObjectSetInteger(0, dirLabel, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, dirLabel, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, dirLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
}

//+------------------------------------------------------------------+
