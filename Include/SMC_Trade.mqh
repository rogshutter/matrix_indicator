//+------------------------------------------------------------------+
//|                                                SMC_Trade.mqh     |
//|           Version 2 - Prise de position + gestion risque stricte  |
//|     Drawdown, exposition limitée, confirmations stratégie        |
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""
#property version   "2.00"

#include <Trade\Trade.mqh>
#include "SMC_Structures.mqh"

//+------------------------------------------------------------------+
//| Gestion des trades avec risque strict                            |
//+------------------------------------------------------------------+
class CTradeManager
{
private:
   string            m_symbol;
   CTrade            m_trade;

   double            m_riskPercent;
   double            m_minRR;
   int               m_maxPositions;
   int               m_maxDailyTrades;
   double            m_maxDrawdownPercent;
   int               m_magicNumber;

   double            m_initialBalance;
   int               m_dailyTradeCount;
   datetime          m_lastTradeDay;

   double            NormalizePrice(double price);
   double            CalculateLotSize(double entryPrice, double stopLoss);
   void              UpdateDailyCount();

public:
                     CTradeManager();
                    ~CTradeManager();

   bool              Init(string symbol, double riskPercent, double minRR, int magic,
                          int maxPositions = 1, int maxDailyTrades = 3, double maxDrawdownPercent = 10.0);

   bool              IsTradeAllowed();
   double            CalculateRR(double entry, double sl, double tp);
   bool              IsValidSetup(double entry, double sl, double tp, double rr, bool isBuy = true);

   bool              PlaceBuyOrder(double entryPrice, double stopLoss, double takeProfit, string comment = "SMC V2 Buy");
   bool              PlaceSellOrder(double entryPrice, double stopLoss, double takeProfit, string comment = "SMC V2 Sell");
   bool              PlaceBuyLimit(double entryPrice, double stopLoss, double takeProfit, string comment = "SMC V2 Buy Lim");
   bool              PlaceSellLimit(double entryPrice, double stopLoss, double takeProfit, string comment = "SMC V2 Sell Lim");

   int               GetOpenPositions();
   int               GetPendingOrders();
   bool              HasOpenPosition();
   bool              HasPendingOrder();
   bool              CloseAllPositions();
   bool              ModifySL(double newSL);
   bool              MoveToBreakeven(double minProfit);
   bool              MoveToBreakevenOnBOS(bool hasBOSConfirmation);

   void              SetRiskPercent(double risk) { m_riskPercent = risk; }
   void              SetMinRR(double rr) { m_minRR = rr; }
   double            GetRiskPercent() { return m_riskPercent; }
   double            GetMinRR() { return m_minRR; }
   int               GetMagicNumber() { return m_magicNumber; }
};

//+------------------------------------------------------------------+
CTradeManager::CTradeManager()
{
   m_symbol = "";
   m_riskPercent = 0.5;
   m_minRR = 2.0;
   m_maxPositions = 1;
   m_maxDailyTrades = 3;
   m_maxDrawdownPercent = 10.0;
   m_magicNumber = 20260207;
   m_initialBalance = 0;
   m_dailyTradeCount = 0;
   m_lastTradeDay = 0;
}

//+------------------------------------------------------------------+
CTradeManager::~CTradeManager()
{
}

//+------------------------------------------------------------------+
bool CTradeManager::Init(string symbol, double riskPercent, double minRR, int magic,
                         int maxPositions, int maxDailyTrades, double maxDrawdownPercent)
{
   m_symbol = symbol;
   m_riskPercent = MathMax(0.1, MathMin(2.0, riskPercent));
   m_minRR = MathMax(1.5, minRR);
   m_magicNumber = magic;
   m_maxPositions = MathMax(1, MathMin(5, maxPositions));
   m_maxDailyTrades = MathMax(1, MathMin(10, maxDailyTrades));
   m_maxDrawdownPercent = MathMax(5.0, MathMin(25.0, maxDrawdownPercent));

   m_trade.SetExpertMagicNumber(magic);
   m_trade.SetDeviationInPoints(15);
   m_trade.SetTypeFilling(ORDER_FILLING_IOC);

   m_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_lastTradeDay = 0;
   m_dailyTradeCount = 0;
   return true;
}

//+------------------------------------------------------------------+
double CTradeManager::NormalizePrice(double price)
{
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
}

//+------------------------------------------------------------------+
// UpdateEquityHighWaterMark removed - replaced by initial balance drawdown

//+------------------------------------------------------------------+
void CTradeManager::UpdateDailyCount()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   if(today != m_lastTradeDay)
   {
      m_lastTradeDay = today;
      m_dailyTradeCount = 0;
   }
}

//+------------------------------------------------------------------+
bool CTradeManager::IsTradeAllowed()
{
   UpdateDailyCount();

   if(GetOpenPositions() >= m_maxPositions) return false;
   if(HasPendingOrder()) return false;
   if(m_dailyTradeCount >= m_maxDailyTrades) return false;

   // Drawdown basé sur le solde initial (pas high-water-mark qui bloque définitivement)
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double maxDD = m_initialBalance * (1.0 - m_maxDrawdownPercent / 100.0);
   if(eq < maxDD)
   {
      static datetime lastDDPrint = 0;
      if(TimeCurrent() - lastDDPrint > 86400) // Log 1x/jour max
      {
         Print("[DD] Trading bloqué: Equity=", DoubleToString(eq,2), 
               " < seuil=", DoubleToString(maxDD,2),
               " (initial=", DoubleToString(m_initialBalance,2), 
               ", maxDD%=", DoubleToString(m_maxDrawdownPercent,1), ")");
         lastDDPrint = TimeCurrent();
      }
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
bool CTradeManager::IsValidSetup(double entry, double sl, double tp, double rr, bool isBuy)
{
   if(entry <= 0 || sl <= 0 || tp <= 0) return false;
   if(rr < m_minRR) return false;
   
   // --- Vérification direction SL/TP ---
   if(isBuy)
   {
      if(sl >= entry) { Print("REJET: SL (", sl, ") >= entry (", entry, ") pour BUY"); return false; }
      if(tp <= entry) { Print("REJET: TP (", tp, ") <= entry (", entry, ") pour BUY"); return false; }
   }
   else
   {
      if(sl <= entry) { Print("REJET: SL (", sl, ") <= entry (", entry, ") pour SELL"); return false; }
      if(tp >= entry) { Print("REJET: TP (", tp, ") >= entry (", entry, ") pour SELL"); return false; }
   }
   
   double risk = MathAbs(entry - sl);
   if(risk <= 0) return false;
   
   // --- Distance minimum broker (STOPLEVEL) ---
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   long stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
   // Minimum = max(STOPLEVEL du broker, 3 pips = 30 points pour 5 digits)
   double minDist = MathMax(point * 30, stopLevel * point);
   
   // Tolérance floating point (0.5 point) pour éviter rejection sur 29.9999 < 30.0
   if(risk < minDist - point * 0.5) 
   { 
      Print("REJET: SL distance (", risk / point, " pts) < min (", minDist / point, " pts)"); 
      return false; 
   }
   
   double tpDist = MathAbs(tp - entry);
   if(tpDist < minDist - point * 0.5) 
   { 
      Print("REJET: TP distance (", tpDist / point, " pts) < min (", minDist / point, " pts)"); 
      return false; 
   }
   
   return true;
}

//+------------------------------------------------------------------+
double CTradeManager::CalculateRR(double entry, double sl, double tp)
{
   double risk = MathAbs(entry - sl);
   if(risk <= 0) return 0;
   double reward = MathAbs(tp - entry);
   return reward / risk;
}

//+------------------------------------------------------------------+
double CTradeManager::CalculateLotSize(double entryPrice, double stopLoss)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (m_riskPercent / 100.0);

   double slDistance = MathAbs(entryPrice - stopLoss);
   double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);

   if(tickSize <= 0 || tickValue <= 0 || slDistance <= 0) return SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);

   double slTicks = slDistance / tickSize;
   double lotSize = riskAmount / (slTicks * tickValue);

   double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

   lotSize = MathMax(minLot, lotSize);
   lotSize = MathMin(maxLot, lotSize);
   lotSize = NormalizeDouble(MathFloor(lotSize / lotStep) * lotStep, 2);
   return lotSize;
}

//+------------------------------------------------------------------+
int CTradeManager::GetOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
int CTradeManager::GetPendingOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != m_symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != m_magicNumber) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
bool CTradeManager::HasOpenPosition()
{
   return (GetOpenPositions() > 0);
}

//+------------------------------------------------------------------+
bool CTradeManager::HasPendingOrder()
{
   return (GetPendingOrders() > 0);
}

//+------------------------------------------------------------------+
bool CTradeManager::PlaceBuyOrder(double entryPrice, double stopLoss, double takeProfit, string comment)
{
   if(!IsTradeAllowed()) return false;
   if(!IsValidSetup(entryPrice, stopLoss, takeProfit, CalculateRR(entryPrice, stopLoss, takeProfit), true)) return false;

   double lot = CalculateLotSize(entryPrice, stopLoss);
   bool ok = m_trade.Buy(lot, m_symbol, 0, NormalizePrice(stopLoss), NormalizePrice(takeProfit), comment);
   if(ok) m_dailyTradeCount++;
   return ok;
}

//+------------------------------------------------------------------+
bool CTradeManager::PlaceSellOrder(double entryPrice, double stopLoss, double takeProfit, string comment)
{
   if(!IsTradeAllowed()) return false;
   if(!IsValidSetup(entryPrice, stopLoss, takeProfit, CalculateRR(entryPrice, stopLoss, takeProfit), false)) return false;

   double lot = CalculateLotSize(entryPrice, stopLoss);
   bool ok = m_trade.Sell(lot, m_symbol, 0, NormalizePrice(stopLoss), NormalizePrice(takeProfit), comment);
   if(ok) m_dailyTradeCount++;
   return ok;
}

//+------------------------------------------------------------------+
bool CTradeManager::PlaceBuyLimit(double entryPrice, double stopLoss, double takeProfit, string comment)
{
   if(!IsTradeAllowed()) return false;
   if(!IsValidSetup(entryPrice, stopLoss, takeProfit, CalculateRR(entryPrice, stopLoss, takeProfit), true)) return false;

   // Buy limit doit être SOUS le Ask, à au moins STOPLEVEL de distance
   double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   long stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = MathMax(stopLevel, 10) * point; // Au moins 1 pip
   
   if(entryPrice >= ask)
   {
      Print("REJET Buy Limit: prix (", entryPrice, ") >= Ask (", ask, ")");
      return false;
   }
   if(ask - entryPrice < minDist)
   {
      Print("REJET Buy Limit: distance prix-Ask (", (ask - entryPrice) / point, " pts) < STOPLEVEL (", stopLevel, " pts)");
      return false;
   }

   double lot = CalculateLotSize(entryPrice, stopLoss);
   // Expiration 48h pour éviter les ordres pendants de plusieurs mois
   datetime expiration = TimeCurrent() + 48 * 3600;
   bool ok = m_trade.BuyLimit(lot, NormalizePrice(entryPrice), m_symbol,
                              NormalizePrice(stopLoss), NormalizePrice(takeProfit), ORDER_TIME_SPECIFIED, expiration, comment);
   if(ok) m_dailyTradeCount++;
   return ok;
}

//+------------------------------------------------------------------+
bool CTradeManager::PlaceSellLimit(double entryPrice, double stopLoss, double takeProfit, string comment)
{
   if(!IsTradeAllowed()) return false;
   if(!IsValidSetup(entryPrice, stopLoss, takeProfit, CalculateRR(entryPrice, stopLoss, takeProfit), false)) return false;

   // Sell limit doit être AU-DESSUS du Bid, à au moins STOPLEVEL de distance
   double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   long stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = MathMax(stopLevel, 10) * point; // Au moins 1 pip
   
   if(entryPrice <= bid)
   {
      Print("REJET Sell Limit: prix (", entryPrice, ") <= Bid (", bid, ")");
      return false;
   }
   if(entryPrice - bid < minDist)
   {
      Print("REJET Sell Limit: distance prix-Bid (", (entryPrice - bid) / point, " pts) < STOPLEVEL (", stopLevel, " pts)");
      return false;
   }

   double lot = CalculateLotSize(entryPrice, stopLoss);
   // Expiration 48h pour éviter les ordres pendants de plusieurs mois
   datetime expiration = TimeCurrent() + 48 * 3600;
   bool ok = m_trade.SellLimit(lot, NormalizePrice(entryPrice), m_symbol,
                               NormalizePrice(stopLoss), NormalizePrice(takeProfit), ORDER_TIME_SPECIFIED, expiration, comment);
   if(ok) m_dailyTradeCount++;
   return ok;
}

//+------------------------------------------------------------------+
bool CTradeManager::CloseAllPositions()
{
   bool success = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;
      if(!m_trade.PositionClose(ticket))
         success = false;
   }
   return success;
}

//+------------------------------------------------------------------+
bool CTradeManager::ModifySL(double newSL)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;
      double tp = PositionGetDouble(POSITION_TP);
      return m_trade.PositionModify(ticket, NormalizePrice(newSL), tp);
   }
   return false;
}

//+------------------------------------------------------------------+
bool CTradeManager::MoveToBreakeven(double minProfit)
{
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double spread = SymbolInfoDouble(m_symbol, SYMBOL_ASK) - SymbolInfoDouble(m_symbol, SYMBOL_BID);
   double beBuffer = spread + point * 2; // Buffer pour ne pas être éjecté par le spread
   long stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minSLDist = stopLevel * point;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double price = PositionGetDouble(POSITION_PRICE_CURRENT);
      long posType = PositionGetInteger(POSITION_TYPE);
      double posTp = PositionGetDouble(POSITION_TP);

      if(posType == POSITION_TYPE_BUY)
      {
         if(price - openPrice >= minProfit && (sl < openPrice || sl == 0))
         {
            double newSL = NormalizePrice(openPrice + beBuffer);
            if(price - newSL < minSLDist) continue;
            return m_trade.PositionModify(ticket, newSL, posTp);
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         if(openPrice - price >= minProfit && (sl > openPrice || sl == 0))
         {
            double newSL = NormalizePrice(openPrice - beBuffer);
            if(newSL - price < minSLDist) continue;
            return m_trade.PositionModify(ticket, newSL, posTp);
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| BE conditionné par BOS structurel (Module 7)                       |
//| Ne déplace en BE que si un BOS confirme au-dessus/dessous de l'entrée |
//+------------------------------------------------------------------+
bool CTradeManager::MoveToBreakevenOnBOS(bool hasBOSConfirmation)
{
   if(!hasBOSConfirmation) return false;
   
   double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   double spread = SymbolInfoDouble(m_symbol, SYMBOL_ASK) - SymbolInfoDouble(m_symbol, SYMBOL_BID);
   // Buffer BE = spread + 2 points pour ne pas être éjecté immédiatement
   double beBuffer = spread + point * 2;
   long stopLevel = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minSLDist = stopLevel * point;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      long posType = PositionGetInteger(POSITION_TYPE);
      double posTp = PositionGetDouble(POSITION_TP);
      
      // Module 9/10 : BE uniquement si le prix a atteint au moins 50% du TP
      // "j'aurais attendu le BOS de ce high pour finir break even"
      double slDist = MathAbs(openPrice - sl);
      double minProfitForBE = slDist * 1.0; // Au moins 1R de profit avant BE

      if(posType == POSITION_TYPE_BUY && (sl < openPrice || sl == 0))
      {
         double profit = currentPrice - openPrice;
         if(profit < minProfitForBE) continue; // Pas assez de profit
         double newSL = NormalizePrice(openPrice + beBuffer);
         // Vérifier que le nouveau SL respecte STOPLEVEL
         if(currentPrice - newSL < minSLDist) continue;
         return m_trade.PositionModify(ticket, newSL, posTp);
      }
      else if(posType == POSITION_TYPE_SELL && (sl > openPrice || sl == 0))
      {
         double profit = openPrice - currentPrice;
         if(profit < minProfitForBE) continue; // Pas assez de profit
         double newSL = NormalizePrice(openPrice - beBuffer);
         // Vérifier que le nouveau SL respecte STOPLEVEL
         if(newSL - currentPrice < minSLDist) continue;
         return m_trade.PositionModify(ticket, newSL, posTp);
      }
   }
   return false;
}
//+------------------------------------------------------------------+
