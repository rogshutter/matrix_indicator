//+------------------------------------------------------------------+
//|                                              SMC_Structures.mqh |
//|                          Version 2 - Module 1 Structure is Queen |
//|                                    Smart Money Concepts (SMC)   |
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""
#property version   "2.00"

//+------------------------------------------------------------------+
//| Enumerations                                                     |
//+------------------------------------------------------------------+

// Type de swing point
enum ENUM_SWING_TYPE
{
   SWING_NONE = 0,      // Pas de swing
   SWING_HH,            // Higher High
   SWING_HL,            // Higher Low
   SWING_LH,            // Lower High
   SWING_LL,            // Lower Low
   SWING_HIGH,          // High non classifié
   SWING_LOW            // Low non classifié
};

// Biais du marché
enum ENUM_MARKET_BIAS
{
   BIAS_NEUTRAL = 0,    // Neutre/Consolidation
   BIAS_BULLISH,        // Haussier
   BIAS_BEARISH         // Baissier
};

// Type de BOS (Break of Structure)
enum ENUM_BOS_TYPE
{
   BOS_NONE = 0,
   BOS_BULLISH,         // BOS haussier (continuation)
   BOS_BEARISH,         // BOS baissier (continuation)
   CHOCH_BULLISH,       // ChoCh haussier (changement de tendance / BOS classique)
   CHOCH_BEARISH        // ChoCh baissier (changement de tendance / BOS classique)
};

// Sous-type de BOS - Module 1 : les 3 types de BOS
enum ENUM_BOS_SUBTYPE
{
   BOS_SUB_NONE = 0,
   BOS_SUB_CLASSIC,     // BOS classique = changement de tendance (ChoCh)
   BOS_SUB_CONTINUATION,// BOS de continuation
   BOS_SUB_TRAP         // BOS trap = piège des big boys
};

// Type d'Order Block
enum ENUM_OB_TYPE
{
   OB_NONE = 0,
   OB_BULLISH,
   OB_BEARISH
};

// Statut d'une zone
enum ENUM_ZONE_STATUS
{
   ZONE_ACTIVE = 0,
   ZONE_TESTED = 1,
   ZONE_MITIGATED = 2,
   ZONE_EXPIRED = 3
};

// Type de liquidité (Module 5)
enum ENUM_LIQUIDITY_TYPE
{
   LIQ_NONE = 0,
   LIQ_EQL,              // Equal Low (double bottom = pool de liquidité)
   LIQ_EQH,              // Equal High (double top = pool de liquidité)
   LIQ_TRENDLINE,        // Trendline de liquidité (3+ touches)
   LIQ_INDUCEMENT,       // Inducement (swing mineur sans BOS majeur)
   LIQ_INTACT_BUYER,     // Intact Buyer (low non manipulé = target)
   LIQ_INTACT_SELLER     // Intact Seller (high non manipulé = target)
};

// Zone Premium/Discount (règle 80-20)
enum ENUM_PRICE_ZONE
{
   ZONE_DISCOUNT = 0,
   ZONE_EQUILIBRIUM = 1,
   ZONE_PREMIUM = 2
};

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+

// Point de Swing
struct SSwingPoint
{
   datetime          time;
   double            price;
   int               barIndex;
   ENUM_SWING_TYPE   type;
   bool              isValid;
   bool              isMajor;        // Module 1 : fait partie de la structure majeure
   bool              isAdjustment;   // Module 9 : swing mineur = ajustement (inducement potentiel)
   bool              adjustmentTaken;// Module 9 : l'ajustement a été pris (swept)
   datetime          adjustmentTakenTime; // Module 9 : quand l'ajustement a été pris

   void Init()
   {
      time = 0;
      price = 0.0;
      barIndex = -1;
      type = SWING_NONE;
      isValid = false;
      isMajor = false;
      isAdjustment = false;
      adjustmentTaken = false;
      adjustmentTakenTime = 0;
   }
};

// Order Block
struct SOrderBlock
{
   datetime          timeStart;
   datetime          timeEnd;
   double            priceHigh;
   double            priceLow;
   int               barIndex;
   ENUM_OB_TYPE      type;
   ENUM_ZONE_STATUS  status;
   double            entryPrice;
   bool              hasFVG;

   void Init()
   {
      timeStart = 0;
      timeEnd = 0;
      priceHigh = 0.0;
      priceLow = 0.0;
      barIndex = -1;
      type = OB_NONE;
      status = ZONE_ACTIVE;
      entryPrice = 0.0;
      hasFVG = false;
   }

   double GetMidPoint() { return (priceHigh + priceLow) / 2.0; }
   double GetHeight() { return MathAbs(priceHigh - priceLow); }
};

// Fair Value Gap
struct SFVG
{
   datetime          time;
   double            priceHigh;
   double            priceLow;
   int               barIndex;
   ENUM_OB_TYPE      type;
   ENUM_ZONE_STATUS  status;
   double            fillPercent;

   void Init()
   {
      time = 0;
      priceHigh = 0.0;
      priceLow = 0.0;
      barIndex = -1;
      type = OB_NONE;
      status = ZONE_ACTIVE;
      fillPercent = 0.0;
   }

   double GetMidPoint() { return (priceHigh + priceLow) / 2.0; }
   double GetHeight() { return MathAbs(priceHigh - priceLow); }
};

// Zone de Liquidité (Module 5 : enrichie)
struct SLiquidityZone
{
   datetime          time;
   double            price;
   int               barIndex;
   ENUM_LIQUIDITY_TYPE type;
   bool              isSwept;
   datetime          sweepTime;

   void Init()
   {
      time = 0;
      price = 0.0;
      barIndex = -1;
      type = LIQ_NONE;
      isSwept = false;
      sweepTime = 0;
   }
};

// Trendline de Liquidité (Module 5)
struct STrendlineLiquidity
{
   datetime          time1;           // Premier point
   datetime          time2;           // Dernier point
   double            price1;
   double            price2;
   int               barIndex1;
   int               barIndex2;
   int               touchCount;      // Nombre de touches (min 3)
   bool              isSupport;       // true = support (lows), false = résistance (highs)
   bool              isSwept;         // Liquidité déjà prise ?
   datetime          sweepTime;

   void Init()
   {
      time1 = 0; time2 = 0;
      price1 = 0.0; price2 = 0.0;
      barIndex1 = -1; barIndex2 = -1;
      touchCount = 0;
      isSupport = true;
      isSwept = false;
      sweepTime = 0;
   }
};

// Breaker Block (Module 3 - zone de polarité inversée)
struct SBreakerBlock
{
   datetime          timeStart;
   double            priceHigh;
   double            priceLow;
   int               barIndex;
   ENUM_OB_TYPE      originalDir;     // Direction originale (avant cassure)
   ENUM_OB_TYPE      newDir;          // Nouvelle direction (polarité inversée)
   ENUM_ZONE_STATUS  status;
   bool              reactionConfirmed; // Réaction confirmée sur le breaker

   void Init()
   {
      timeStart = 0;
      priceHigh = 0.0;
      priceLow = 0.0;
      barIndex = -1;
      originalDir = OB_NONE;
      newDir = OB_NONE;
      status = ZONE_ACTIVE;
      reactionConfirmed = false;
   }
};

// Lien Order Flow (Module 3 - mitigation sur mitigation)
struct SOrderFlowLink
{
   int               fromZoneIdx;     // Index zone source (précédente)
   int               toZoneIdx;       // Index zone destination (nouvelle, qui récupère)
   datetime          timeFrom;
   datetime          timeTo;
   double            priceFrom;       // Mid-price zone source
   double            priceTo;         // Mid-price zone destination
   ENUM_OB_TYPE      direction;       // OB_BULLISH = ODF haussier, OB_BEARISH = ODF baissier
   int               chainId;         // Identifiant de chaîne
   int               chainPosition;   // Position dans la chaîne (1, 2, 3...)

   void Init()
   {
      fromZoneIdx = -1;
      toZoneIdx = -1;
      timeFrom = 0;
      timeTo = 0;
      priceFrom = 0.0;
      priceTo = 0.0;
      direction = OB_NONE;
      chainId = 0;
      chainPosition = 0;
   }
};

// Point d'Intérêt (POI)
struct SPOI
{
   datetime          time;
   double            priceHigh;
   double            priceLow;
   ENUM_OB_TYPE      direction;
   bool              hasOB;
   bool              hasFVG;
   bool              hasBB;           // Module 3 : contient un Breaker Block
   bool              hasODF;          // Module 3 : fait partie d'un Order Flow
   bool              inDiscountZone;
   bool              inPremiumZone;
   double            strength;

   void Init()
   {
      time = 0;
      priceHigh = 0.0;
      priceLow = 0.0;
      direction = OB_NONE;
      hasOB = false;
      hasFVG = false;
      hasBB = false;
      hasODF = false;
      inDiscountZone = false;
      inPremiumZone = false;
      strength = 0.0;
   }
};

// Configuration de Trade
struct STradeSetup
{
   datetime          signalTime;
   ENUM_OB_TYPE      direction;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit1;
   double            takeProfit2;
   double            riskReward;
   string            reason;
   bool              isValid;

   void Init()
   {
      signalTime = 0;
      direction = OB_NONE;
      entryPrice = 0.0;
      stopLoss = 0.0;
      takeProfit1 = 0.0;
      takeProfit2 = 0.0;
      riskReward = 0.0;
      reason = "";
      isValid = false;
   }
};

// Analyse multi-timeframe (fractalité - Module 1)
struct SMTFAnalysis
{
   ENUM_TIMEFRAMES   htfTimeframe;
   ENUM_TIMEFRAMES   ltfTimeframe;
   ENUM_MARKET_BIAS  htfBias;
   ENUM_MARKET_BIAS  ltfBias;
   bool              biasConfluence;   // Les deux TF alignés (80% vs 80%)
   bool              ltfInRetracement;  // LTF dans les 20% (retracement HTF)
   bool              atHTFDecisionZone; // Prix dans zone décisionnelle HTF (offre/demande)

   void Init()
   {
      htfTimeframe = PERIOD_H1;
      ltfTimeframe = PERIOD_M5;
      htfBias = BIAS_NEUTRAL;
      ltfBias = BIAS_NEUTRAL;
      biasConfluence = false;
      ltfInRetracement = false;
      atHTFDecisionZone = false;
   }
};

//+------------------------------------------------------------------+
//| Constantes                                                        |
//+------------------------------------------------------------------+
#define MAX_SWING_POINTS    2000
#define MAX_ORDER_BLOCKS    200
#define MAX_FVGS            200
#define MAX_LIQUIDITY_ZONES 200
#define MAX_POIS            100
#define MAX_BREAKER_BLOCKS  200
#define MAX_ODF_LINKS       500
#define MAX_LIQ_LEVELS      500
#define MAX_TRENDLINES_LIQ  50

//+------------------------------------------------------------------+
