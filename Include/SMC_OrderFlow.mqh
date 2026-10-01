//+------------------------------------------------------------------+
//|                                              SMC_OrderFlow.mqh   |
//|                   Version 2 - Module 3 : OB, Order Flow, Breaker  |
//|                                    Smart Money Concepts (SMC)     |
//+------------------------------------------------------------------+
//| Pédagogie Module 3 :                                              |
//| - OB/POI = zones d'offre/demande (basées sur Module 2)            |
//| - Order Flow = mitigation sur mitigation de l'offre/demande       |
//|   "la bougie manipulatrice viendra récupérer l'ancien niveau"     |
//| - Breaker Block = zone de polarité inversée                       |
//|   "l'offre qui devient une demande" (et vice versa)               |
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""
#property version   "2.00"

#include "SMC_Structures.mqh"
#include "SMC_MarketStructure.mqh"
#include "SMC_BOS_ChoCh.mqh"
#include "SMC_CandleTypes.mqh"

//+------------------------------------------------------------------+
//| Classe Order Flow - Module 3                                      |
//| Détecte les chaînes Order Flow et les Breaker Blocks              |
//| Utilise les zones d'offre/demande de CCandleTypes (Module 2)      |
//| et le contexte structurel de CMarketStructure + CBOSChoCh         |
//+------------------------------------------------------------------+
class COrderFlow
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

   // Références aux modules précédents
   CMarketStructure* m_structure;
   CCandleTypes*     m_candles;
   CBOSChoCh*        m_bos;

   // Order Flow chains (liens entre zones)
   SOrderFlowLink    m_odfLinks[];
   int               m_odfCount;
   int               m_odfCapacity;

   // Breaker Blocks
   SBreakerBlock     m_breakers[];
   int               m_bbCount;
   int               m_bbCapacity;

   // Méthodes internes
   void              DetectOrderFlowChains();
   void              DetectBreakerBlocks();

public:
                     COrderFlow();
                    ~COrderFlow();

   bool              Init(string symbol, ENUM_TIMEFRAMES tf,
                          CMarketStructure* ms, CCandleTypes* ct, CBOSChoCh* bos);
   void              Update(int barsToCheck);

   // Accesseurs Order Flow
   int               GetODFCount() { return m_odfCount; }
   bool              GetODFLink(int index, SOrderFlowLink &link);
   bool              IsInBullishOrderFlow();
   bool              IsInBearishOrderFlow();
   int               GetCurrentChainLength(ENUM_OB_TYPE dir);

   // Accesseurs Breaker Block
   int               GetBBCount() { return m_bbCount; }
   bool              GetBB(int index, SBreakerBlock &bb);
   bool              IsPriceInActiveBreakerBlock(double price, SBreakerBlock &bb);
   bool              HasActiveBullishBB();
   bool              HasActiveBearishBB();

   // Dessin
   void              DrawOrderFlow(color odfBullColor, color odfBearColor);
   void              DrawBreakerBlocks(color bbBullColor, color bbBearColor);
   void              ClearDrawings();
};

//+------------------------------------------------------------------+
COrderFlow::COrderFlow()
{
   m_symbol = "";
   m_timeframe = PERIOD_CURRENT;
   m_structure = NULL;
   m_candles = NULL;
   m_bos = NULL;
   m_odfCount = 0;
   m_bbCount = 0;
   m_odfCapacity = MAX_ODF_LINKS;
   m_bbCapacity = MAX_BREAKER_BLOCKS;
   ArrayResize(m_odfLinks, m_odfCapacity);
   ArrayResize(m_breakers, m_bbCapacity);
}

//+------------------------------------------------------------------+
COrderFlow::~COrderFlow()
{
   ClearDrawings();
   ArrayFree(m_odfLinks);
   ArrayFree(m_breakers);
}

//+------------------------------------------------------------------+
bool COrderFlow::Init(string symbol, ENUM_TIMEFRAMES tf,
                       CMarketStructure* ms, CCandleTypes* ct, CBOSChoCh* bos)
{
   if(ms == NULL || ct == NULL) return false;
   m_symbol = symbol;
   m_timeframe = tf;
   m_structure = ms;
   m_candles = ct;
   m_bos = bos;
   m_odfCount = 0;
   m_bbCount = 0;
   return true;
}

//+------------------------------------------------------------------+
//| Mise à jour principale - appeler après Update des modules 1 & 2   |
//+------------------------------------------------------------------+
void COrderFlow::Update(int barsToCheck)
{
   if(m_candles == NULL || m_structure == NULL) return;

   // 1. Détecter les chaînes d'Order Flow parmi les zones existantes
   DetectOrderFlowChains();

   // 2. Détecter les Breaker Blocks (zones mitiguées + BOS après)
   DetectBreakerBlocks();
}

//+------------------------------------------------------------------+
//| Order Flow : mitigation sur mitigation                            |
//| "la bougie manipulatrice viendra récupérer l'ancien niveau,       |
//|  le niveau précédent, d'offre et de demande, à chaque fois"       |
//| Pattern escalier : D1 → BOS → retrace → D2 (récupère D1) → ...  |
//+------------------------------------------------------------------+
void COrderFlow::DetectOrderFlowChains()
{
   m_odfCount = 0;
   int zoneCount = m_candles.GetZoneCount();
   if(zoneCount < 2) return;

   // Indices de la dernière zone demand / supply vue
   int lastDemandIdx = -1;
   int lastSupplyIdx = -1;

   // Compteurs de chaînes
   int demandChainId = 0;
   int supplyChainId = 1000;  // offset pour distinguer
   int demandChainPos = 0;
   int supplyChainPos = 0;

   for(int i = 0; i < zoneCount && m_odfCount < m_odfCapacity; i++)
   {
      SSupplyDemandZone zone;
      if(!m_candles.GetZone(i, zone)) continue;

      // --- Zones de DEMANDE (bullish ODF = escalier montant) ---
      if(zone.direction == OB_BULLISH)
      {
         if(lastDemandIdx >= 0)
         {
            SSupplyDemandZone prevZone;
            if(m_candles.GetZone(lastDemandIdx, prevZone))
            {
               // Tolérance = 50% de la hauteur de la zone précédente
               double zoneH = prevZone.priceHigh - prevZone.priceLow;
               double tol = MathMax(zoneH * 0.5, SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 50);

               // "Récupérer" = la bougie manip de la nouvelle zone descend
               // jusqu'au niveau de la zone précédente (ou proche)
               double candleLow = iLow(m_symbol, m_timeframe, zone.barIndexManip);
               bool recovers = (candleLow <= prevZone.priceHigh + tol);

               // Escalier : la nouvelle zone est au même niveau ou plus haut
               bool staircase = (zone.priceLow >= prevZone.priceLow - tol);

               if(recovers && staircase)
               {
                  SOrderFlowLink link;
                  link.Init();
                  link.fromZoneIdx = lastDemandIdx;
                  link.toZoneIdx = i;
                  link.timeFrom = prevZone.timeStart;
                  link.timeTo = zone.timeStart;
                  link.priceFrom = (prevZone.priceHigh + prevZone.priceLow) / 2.0;
                  link.priceTo = (zone.priceHigh + zone.priceLow) / 2.0;
                  link.direction = OB_BULLISH;
                  link.chainId = demandChainId;
                  link.chainPosition = ++demandChainPos;
                  m_odfLinks[m_odfCount++] = link;
               }
               else
               {
                  // Rupture de chaîne → nouvelle chaîne
                  demandChainId += 2;
                  demandChainPos = 0;
               }
            }
         }
         lastDemandIdx = i;
      }

      // --- Zones d'OFFRE (bearish ODF = escalier descendant) ---
      else if(zone.direction == OB_BEARISH)
      {
         if(lastSupplyIdx >= 0)
         {
            SSupplyDemandZone prevZone;
            if(m_candles.GetZone(lastSupplyIdx, prevZone))
            {
               double zoneH = prevZone.priceHigh - prevZone.priceLow;
               double tol = MathMax(zoneH * 0.5, SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 50);

               // "Récupérer" = la bougie manip de la nouvelle zone monte
               // jusqu'au niveau de la zone précédente (ou proche)
               double candleHigh = iHigh(m_symbol, m_timeframe, zone.barIndexManip);
               bool recovers = (candleHigh >= prevZone.priceLow - tol);

               // Escalier : la nouvelle zone est au même niveau ou plus bas
               bool staircase = (zone.priceHigh <= prevZone.priceHigh + tol);

               if(recovers && staircase)
               {
                  SOrderFlowLink link;
                  link.Init();
                  link.fromZoneIdx = lastSupplyIdx;
                  link.toZoneIdx = i;
                  link.timeFrom = prevZone.timeStart;
                  link.timeTo = zone.timeStart;
                  link.priceFrom = (prevZone.priceHigh + prevZone.priceLow) / 2.0;
                  link.priceTo = (zone.priceHigh + zone.priceLow) / 2.0;
                  link.direction = OB_BEARISH;
                  link.chainId = supplyChainId;
                  link.chainPosition = ++supplyChainPos;
                  m_odfLinks[m_odfCount++] = link;
               }
               else
               {
                  supplyChainId += 2;
                  supplyChainPos = 0;
               }
            }
         }
         lastSupplyIdx = i;
      }
   }
}

//+------------------------------------------------------------------+
//| Breaker Block : zone de polarité inversée                         |
//| "l'offre qui devient une demande" (et vice versa)                 |
//| Condition : zone mitiguée (prix traverse sans réaction) + BOS     |
//| après dans la direction opposée                                   |
//+------------------------------------------------------------------+
void COrderFlow::DetectBreakerBlocks()
{
   m_bbCount = 0;
   int zoneCount = m_candles.GetZoneCount();

   for(int i = 0; i < zoneCount && m_bbCount < m_bbCapacity; i++)
   {
      SSupplyDemandZone zone;
      if(!m_candles.GetZone(i, zone)) continue;
      if(zone.status != ZONE_MITIGATED) continue;

      // Vérifier s'il y a eu un BOS dans la direction opposée après la mitigation
      bool hasBOSAfter = false;
      if(m_bos != NULL)
      {
         int bosCount = m_bos.GetEventCount();
         for(int j = 0; j < bosCount; j++)
         {
            SBOSEvent ev;
            if(!m_bos.GetEvent(j, ev)) continue;
            if(ev.time <= zone.timeEnd) continue; // BOS doit être après la zone

            // Supply mitiguée (prix monte à travers) + BOS haussier → BB demand
            if(zone.direction == OB_BEARISH &&
               (ev.type == BOS_BULLISH || ev.type == CHOCH_BULLISH))
            {
               hasBOSAfter = true;
               break;
            }
            // Demand mitiguée (prix descend à travers) + BOS baissier → BB supply
            if(zone.direction == OB_BULLISH &&
               (ev.type == BOS_BEARISH || ev.type == CHOCH_BEARISH))
            {
               hasBOSAfter = true;
               break;
            }
         }
      }
      else
      {
         // Sans BOS, on vérifie juste qu'il y a un mouvement impulsif après
         // au moins 3 bougies dans la direction opposée
         int startBar = zone.barIndexBQA - 1;
         if(startBar < 3) continue;
         int impulseCount = 0;
         for(int k = startBar; k >= MathMax(0, startBar - 5); k--)
         {
            double cl = iClose(m_symbol, m_timeframe, k);
            double op = iOpen(m_symbol, m_timeframe, k);
            if(zone.direction == OB_BEARISH && cl > op) impulseCount++;
            if(zone.direction == OB_BULLISH && cl < op) impulseCount++;
         }
         hasBOSAfter = (impulseCount >= 3);
      }

      if(!hasBOSAfter) continue;

      // Créer le Breaker Block avec polarité inversée
      SBreakerBlock bb;
      bb.Init();
      bb.timeStart = zone.timeStart;
      bb.priceHigh = zone.priceHigh;
      bb.priceLow = zone.priceLow;
      bb.barIndex = zone.barIndexManip;
      bb.originalDir = zone.direction;
      bb.newDir = (zone.direction == OB_BULLISH) ? OB_BEARISH : OB_BULLISH;
      bb.status = ZONE_ACTIVE;
      bb.reactionConfirmed = false;

      // Vérifier si le prix est revenu ET a réagi (confirmation)
      for(int k = zone.barIndexBQA - 1; k >= 0; k--)
      {
         double high = iHigh(m_symbol, m_timeframe, k);
         double low = iLow(m_symbol, m_timeframe, k);
         double cl = iClose(m_symbol, m_timeframe, k);
         double op = iOpen(m_symbol, m_timeframe, k);

         if(bb.newDir == OB_BULLISH)
         {
            // Ancienne supply → nouvelle demand : prix revient et rebondit à la hausse
            if(low <= bb.priceHigh && low >= bb.priceLow)
            {
               if(cl > op)   // Bougie haussière = réaction
               {
                  bb.reactionConfirmed = true;
                  break;
               }
            }
            // Si le prix casse en dessous → zone mitiguée de nouveau
            if(cl < bb.priceLow)
            {
               bb.status = ZONE_MITIGATED;
               break;
            }
         }
         else
         {
            // Ancienne demand → nouvelle supply : prix revient et rejette à la baisse
            if(high >= bb.priceLow && high <= bb.priceHigh)
            {
               if(cl < op)   // Bougie baissière = réaction
               {
                  bb.reactionConfirmed = true;
                  break;
               }
            }
            if(cl > bb.priceHigh)
            {
               bb.status = ZONE_MITIGATED;
               break;
            }
         }
      }

      m_breakers[m_bbCount++] = bb;
   }
}

//+------------------------------------------------------------------+
//| Accesseurs Order Flow                                              |
//+------------------------------------------------------------------+
bool COrderFlow::GetODFLink(int index, SOrderFlowLink &link)
{
   if(index < 0 || index >= m_odfCount) return false;
   link = m_odfLinks[index];
   return true;
}

bool COrderFlow::IsInBullishOrderFlow()
{
   // Vérifie si la dernière zone demand fait partie d'une chaîne ODF active
   for(int i = m_odfCount - 1; i >= 0; i--)
      if(m_odfLinks[i].direction == OB_BULLISH && m_odfLinks[i].chainPosition >= 1)
         return true;
   return false;
}

bool COrderFlow::IsInBearishOrderFlow()
{
   for(int i = m_odfCount - 1; i >= 0; i--)
      if(m_odfLinks[i].direction == OB_BEARISH && m_odfLinks[i].chainPosition >= 1)
         return true;
   return false;
}

int COrderFlow::GetCurrentChainLength(ENUM_OB_TYPE dir)
{
   // Retourne la longueur de la dernière chaîne ODF de cette direction
   int maxPos = 0;
   int lastChainId = -1;
   for(int i = m_odfCount - 1; i >= 0; i--)
   {
      if(m_odfLinks[i].direction != dir) continue;
      if(lastChainId < 0) lastChainId = m_odfLinks[i].chainId;
      if(m_odfLinks[i].chainId != lastChainId) break;
      if(m_odfLinks[i].chainPosition > maxPos)
         maxPos = m_odfLinks[i].chainPosition;
   }
   return maxPos;
}

//+------------------------------------------------------------------+
//| Accesseurs Breaker Block                                           |
//+------------------------------------------------------------------+
bool COrderFlow::GetBB(int index, SBreakerBlock &bb)
{
   if(index < 0 || index >= m_bbCount) return false;
   bb = m_breakers[index];
   return true;
}

bool COrderFlow::IsPriceInActiveBreakerBlock(double price, SBreakerBlock &bb)
{
   for(int i = m_bbCount - 1; i >= 0; i--)
   {
      if(m_breakers[i].status != ZONE_ACTIVE) continue;
      if(price >= m_breakers[i].priceLow && price <= m_breakers[i].priceHigh)
      {
         bb = m_breakers[i];
         return true;
      }
   }
   return false;
}

bool COrderFlow::HasActiveBullishBB()
{
   for(int i = m_bbCount - 1; i >= 0; i--)
      if(m_breakers[i].newDir == OB_BULLISH && m_breakers[i].status == ZONE_ACTIVE)
         return true;
   return false;
}

bool COrderFlow::HasActiveBearishBB()
{
   for(int i = m_bbCount - 1; i >= 0; i--)
      if(m_breakers[i].newDir == OB_BEARISH && m_breakers[i].status == ZONE_ACTIVE)
         return true;
   return false;
}

//+------------------------------------------------------------------+
//| Dessin Order Flow : flèches reliant les zones chaînées             |
//+------------------------------------------------------------------+
void COrderFlow::DrawOrderFlow(color odfBullColor, color odfBearColor)
{
   string prefix = "SMC_ODF_";

   for(int i = 0; i < m_odfCount; i++)
   {
      SOrderFlowLink link = m_odfLinks[i];
      string name = prefix + IntegerToString(i);
      color col = (link.direction == OB_BULLISH) ? odfBullColor : odfBearColor;

      // Ligne pointillée reliant le milieu des deux zones
      ObjectCreate(0, name, OBJ_TREND, 0,
         link.timeFrom, link.priceFrom,
         link.timeTo, link.priceTo);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOTDOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);

      // Label "ODF #N"
      string lbl = name + "_lbl";
      ObjectCreate(0, lbl, OBJ_TEXT, 0, link.timeTo, link.priceTo);
      ObjectSetString(0, lbl, OBJPROP_TEXT, "ODF #" + IntegerToString(link.chainPosition));
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, col);
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, lbl, OBJPROP_ANCHOR,
         (link.direction == OB_BULLISH) ? ANCHOR_UPPER : ANCHOR_LOWER);
   }
}

//+------------------------------------------------------------------+
//| Dessin Breaker Blocks : rectangles avec bordure spéciale           |
//| Pédagogie : "zone de polarité inversée"                           |
//+------------------------------------------------------------------+
void COrderFlow::DrawBreakerBlocks(color bbBullColor, color bbBearColor)
{
   string prefix = "SMC_BB_";

   for(int i = 0; i < m_bbCount; i++)
   {
      if(m_breakers[i].status == ZONE_MITIGATED) continue;

      SBreakerBlock bb = m_breakers[i];
      string name = prefix + IntegerToString(i);
      color col = (bb.newDir == OB_BULLISH) ? bbBullColor : bbBearColor;
      datetime timeEnd = iTime(m_symbol, m_timeframe, 0) + PeriodSeconds(m_timeframe) * 10;

      // Rectangle de la zone
      ObjectCreate(0, name, OBJ_RECTANGLE, 0,
         bb.timeStart, bb.priceHigh,
         timeEnd, bb.priceLow);
      ObjectSetInteger(0, name, OBJPROP_COLOR, col);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);

      // Bordure pointillée pour distinguer des zones normales
      string border = name + "_bd";
      ObjectCreate(0, border, OBJ_RECTANGLE, 0,
         bb.timeStart, bb.priceHigh,
         timeEnd, bb.priceLow);
      ObjectSetInteger(0, border, OBJPROP_COLOR, col);
      ObjectSetInteger(0, border, OBJPROP_FILL, false);
      ObjectSetInteger(0, border, OBJPROP_BACK, false);
      ObjectSetInteger(0, border, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, border, OBJPROP_WIDTH, 2);

      // Label "BB (D)" ou "BB (S)" + réaction confirmée
      string lbl = name + "_lbl";
      string text = "BB ";
      text += (bb.newDir == OB_BULLISH) ? "(Demand)" : "(Supply)";
      if(bb.reactionConfirmed) text += " OK";
      ObjectCreate(0, lbl, OBJ_TEXT, 0, bb.timeStart, bb.priceHigh);
      ObjectSetString(0, lbl, OBJPROP_TEXT, text);
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, col);
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   }
}

//+------------------------------------------------------------------+
void COrderFlow::ClearDrawings()
{
   ObjectsDeleteAll(0, "SMC_ODF_");
   ObjectsDeleteAll(0, "SMC_BB_");
}

//+------------------------------------------------------------------+
