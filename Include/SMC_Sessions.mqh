//+------------------------------------------------------------------+
//|                                               SMC_Sessions.mqh   |
//|           Module 6 - Sessions / Kill Zones / Heure de Tir        |
//|     Filtre temporel basé sur la stratégie SMC Module 6           |
//+------------------------------------------------------------------+
//| Kill Zones (heures France / UTC+1 hiver, UTC+2 été) :            |
//|   - Europe (Londres) : 9h (8h hiver)                              |
//|   - US (New York)    : 14h (13h hiver)                            |
//|   - Chicago          : 16h (15h hiver)                            |
//|   - Sydney           : 2h (1h hiver)                              |
//|   - Tokyo            : 4h (3h hiver)                              |
//| Monthly High/Low : se forme entre le 26 et le 9 du mois          |
//| Mid-Month : 14-18, mouvement correctif                           |
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""
#property version   "2.00"

#include "SMC_Structures.mqh"

//+------------------------------------------------------------------+
//| Session type                                                       |
//+------------------------------------------------------------------+
enum ENUM_SESSION_TYPE
{
   SESSION_NONE = 0,
   SESSION_SYDNEY,        // Sydney : 22:00 - 07:00 UTC
   SESSION_TOKYO,         // Tokyo  : 00:00 - 09:00 UTC
   SESSION_LONDON,        // London : 07:00 - 16:00 UTC
   SESSION_NEWYORK,       // New York : 12:00 - 21:00 UTC
   SESSION_CHICAGO        // Chicago overlap : 14:00 - 21:00 UTC
};

//+------------------------------------------------------------------+
//| Monthly phase                                                      |
//+------------------------------------------------------------------+
enum ENUM_MONTHLY_PHASE
{
   MONTH_PHASE_NONE = 0,
   MONTH_PHASE_HIGHLOW_FORMATION,  // 26th - 9th : Monthly H/L se forme
   MONTH_PHASE_MIDMONTH,           // 14th - 18th : correctif
   MONTH_PHASE_NORMAL              // Reste du mois
};

//+------------------------------------------------------------------+
//| Kill Zone window                                                    |
//+------------------------------------------------------------------+
struct SKillZone
{
   ENUM_SESSION_TYPE session;
   int               startHourUTC;   // Heure début UTC
   int               startMinute;
   int               endHourUTC;     // Heure fin UTC
   int               endMinute;
   int               durationMinutes; // Durée de la fenêtre active
   bool              isActive;
   
   void Init(ENUM_SESSION_TYPE sess, int startH, int startM, int endH, int endM)
   {
      session = sess;
      startHourUTC = startH;
      startMinute = startM;
      endHourUTC = endH;
      endMinute = endM;
      durationMinutes = (endH * 60 + endM) - (startH * 60 + startM);
      if(durationMinutes < 0) durationMinutes += 24 * 60; // Overnight
      isActive = false;
   }
};

//+------------------------------------------------------------------+
//| Classe CSessions                                                    |
//+------------------------------------------------------------------+
class CSessions
{
private:
   string            m_symbol;
   int               m_brokerOffsetHours;  // Offset broker vs UTC
   
   // Kill Zones (les fenêtres de tir)
   SKillZone         m_killZones[5];
   int               m_killZoneCount;
   
   // Configuration
   bool              m_requireKillZone;     // Interdire les trades hors kill zone
   bool              m_useLondonNY;         // Focus London+NY uniquement (recommandé)
   int               m_killZoneWindowMin;   // Fenêtre en minutes autour de l'heure de tir
   
   // Monthly tracking
   ENUM_MONTHLY_PHASE m_currentMonthPhase;
   double            m_monthlyHigh;
   double            m_monthlyLow;
   datetime          m_monthlyHighTime;
   datetime          m_monthlyLowTime;
   bool              m_monthlyHLFormed;     // True si le H/L mensuel est considéré formé
   
   // Fonctions internes
   int               GetBrokerOffset();
   int               ConvertToUTC(int brokerHour, int brokerMinute);
   bool              IsTimeInRange(int hourUTC, int minuteUTC, int startH, int startM, int endH, int endM);
   void              UpdateMonthlyPhase();
   void              UpdateMonthlyHL();
   
public:
                     CSessions();
                    ~CSessions();
   
   bool              Init(string symbol, bool requireKillZone = true,
                          bool londonNYOnly = true, int windowMinutes = 90);
   void              Update();
   
   // ---- Filtre principal ----
   bool              IsTradeAllowed();          // True si dans une Kill Zone
   
   // ---- Accesseurs ----
   ENUM_SESSION_TYPE GetCurrentSession();        // Session active
   bool              IsInKillZone();             // Dans une fenêtre de tir
   bool              IsLondonSession();
   bool              IsNewYorkSession();
   bool              IsOverlap();                // London + NY overlap (14-16 UTC)
   
   ENUM_MONTHLY_PHASE GetMonthlyPhase();
   bool              IsMonthlyHLFormation();     // 26th-9th
   bool              IsMidMonth();               // 14th-18th
   double            GetMonthlyHigh() { return m_monthlyHigh; }
   double            GetMonthlyLow()  { return m_monthlyLow; }
   
   // ---- NFP/FOMC awareness ----
   bool              IsHighImpactNewsDay();      // Vendredi 1er du mois (NFP) ou FOMC
};

//+------------------------------------------------------------------+
CSessions::CSessions()
{
   m_symbol = "";
   m_brokerOffsetHours = 0;
   m_killZoneCount = 0;
   m_requireKillZone = true;
   m_useLondonNY = true;
   m_killZoneWindowMin = 90;
   m_currentMonthPhase = MONTH_PHASE_NONE;
   m_monthlyHigh = 0;
   m_monthlyLow = 0;
   m_monthlyHighTime = 0;
   m_monthlyLowTime = 0;
   m_monthlyHLFormed = false;
}

//+------------------------------------------------------------------+
CSessions::~CSessions()
{
}

//+------------------------------------------------------------------+
bool CSessions::Init(string symbol, bool requireKillZone, bool londonNYOnly, int windowMinutes)
{
   m_symbol = symbol;
   m_requireKillZone = requireKillZone;
   m_useLondonNY = londonNYOnly;
   m_killZoneWindowMin = MathMax(30, MathMin(180, windowMinutes));
   
   // Détecter le décalage broker
   m_brokerOffsetHours = GetBrokerOffset();
   
   // Configurer les Kill Zones (heures UTC)
   // Fenêtre = heure ciblée ± windowMinutes/2
   m_killZoneCount = 0;
   
   // London Kill Zone : 07:00 - 10:00 UTC (ouverture + 1ère heure)
   m_killZones[m_killZoneCount].Init(SESSION_LONDON, 7, 0, 10, 0);
   m_killZoneCount++;
   
   // New York Kill Zone : 12:00 - 15:00 UTC (ouverture + 1ère heure)
   m_killZones[m_killZoneCount].Init(SESSION_NEWYORK, 12, 0, 15, 0);
   m_killZoneCount++;
   
   // Chicago Power Hour : 14:00 - 16:00 UTC (overlap London close)
   m_killZones[m_killZoneCount].Init(SESSION_CHICAGO, 14, 0, 16, 0);
   m_killZoneCount++;
   
   if(!londonNYOnly)
   {
      // Sydney : 22:00 - 01:00 UTC
      m_killZones[m_killZoneCount].Init(SESSION_SYDNEY, 22, 0, 1, 0);
      m_killZoneCount++;
      
      // Tokyo : 00:00 - 03:00 UTC
      m_killZones[m_killZoneCount].Init(SESSION_TOKYO, 0, 0, 3, 0);
      m_killZoneCount++;
   }
   
   // Initialiser le monthly tracking
   UpdateMonthlyHL();
   UpdateMonthlyPhase();
   
   return true;
}

//+------------------------------------------------------------------+
void CSessions::Update()
{
   UpdateMonthlyPhase();
   UpdateMonthlyHL();
   
   // Mettre à jour le statut des kill zones
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   int brokerH = dt.hour;
   int brokerM = dt.min;
   
   // Convertir en UTC
   int utcH = brokerH - m_brokerOffsetHours;
   if(utcH < 0) utcH += 24;
   if(utcH >= 24) utcH -= 24;
   
   for(int i = 0; i < m_killZoneCount; i++)
   {
      m_killZones[i].isActive = IsTimeInRange(utcH, brokerM,
         m_killZones[i].startHourUTC, m_killZones[i].startMinute,
         m_killZones[i].endHourUTC, m_killZones[i].endMinute);
   }
}

//+------------------------------------------------------------------+
//| Filtre principal : le trade est-il autorisé maintenant ?           |
//+------------------------------------------------------------------+
bool CSessions::IsTradeAllowed()
{
   if(!m_requireKillZone) return true;
   return IsInKillZone();
}

//+------------------------------------------------------------------+
bool CSessions::IsInKillZone()
{
   for(int i = 0; i < m_killZoneCount; i++)
   {
      if(m_killZones[i].isActive)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
ENUM_SESSION_TYPE CSessions::GetCurrentSession()
{
   for(int i = 0; i < m_killZoneCount; i++)
   {
      if(m_killZones[i].isActive)
         return m_killZones[i].session;
   }
   return SESSION_NONE;
}

//+------------------------------------------------------------------+
bool CSessions::IsLondonSession()
{
   for(int i = 0; i < m_killZoneCount; i++)
      if(m_killZones[i].session == SESSION_LONDON && m_killZones[i].isActive)
         return true;
   return false;
}

//+------------------------------------------------------------------+
bool CSessions::IsNewYorkSession()
{
   for(int i = 0; i < m_killZoneCount; i++)
      if(m_killZones[i].session == SESSION_NEWYORK && m_killZones[i].isActive)
         return true;
   return false;
}

//+------------------------------------------------------------------+
bool CSessions::IsOverlap()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int utcH = dt.hour - m_brokerOffsetHours;
   if(utcH < 0) utcH += 24;
   // Overlap = London + NY open simultanément : 12:00 - 16:00 UTC
   return (utcH >= 12 && utcH < 16);
}

//+------------------------------------------------------------------+
//| Vérifier si l'heure actuelle est dans un intervalle                |
//| Gère les cas overnight (startH > endH)                            |
//+------------------------------------------------------------------+
bool CSessions::IsTimeInRange(int hourUTC, int minuteUTC,
                               int startH, int startM, int endH, int endM)
{
   int nowMin = hourUTC * 60 + minuteUTC;
   int startMin = startH * 60 + startM;
   int endMin = endH * 60 + endM;
   
   if(startMin <= endMin)
   {
      // Même jour (ex: 7:00 - 10:00)
      return (nowMin >= startMin && nowMin < endMin);
   }
   else
   {
      // Overnight (ex: 22:00 - 01:00)
      return (nowMin >= startMin || nowMin < endMin);
   }
}

//+------------------------------------------------------------------+
//| Détecter l'offset broker par rapport à UTC                         |
//| Compare TimeCurrent/TimeGMT ou utilise une heuristique            |
//+------------------------------------------------------------------+
int CSessions::GetBrokerOffset()
{
   datetime brokerTime = TimeCurrent();
   datetime gmtTime = TimeGMT();
   
   if(brokerTime == 0 || gmtTime == 0)
      return 2; // Défaut : UTC+2 (broker standard MT5)
   
   int diffSeconds = (int)(brokerTime - gmtTime);
   int diffHours = diffSeconds / 3600;
   
   // Sanity check (-12 à +14)
   if(diffHours < -12 || diffHours > 14)
      return 2;
   
   return diffHours;
}

//+------------------------------------------------------------------+
//| Phase mensuelle                                                    |
//+------------------------------------------------------------------+
void CSessions::UpdateMonthlyPhase()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int day = dt.day;
   
   if(day >= 26 || day <= 9)
      m_currentMonthPhase = MONTH_PHASE_HIGHLOW_FORMATION;
   else if(day >= 14 && day <= 18)
      m_currentMonthPhase = MONTH_PHASE_MIDMONTH;
   else
      m_currentMonthPhase = MONTH_PHASE_NORMAL;
}

//+------------------------------------------------------------------+
ENUM_MONTHLY_PHASE CSessions::GetMonthlyPhase()
{
   return m_currentMonthPhase;
}

//+------------------------------------------------------------------+
bool CSessions::IsMonthlyHLFormation()
{
   return (m_currentMonthPhase == MONTH_PHASE_HIGHLOW_FORMATION);
}

//+------------------------------------------------------------------+
bool CSessions::IsMidMonth()
{
   return (m_currentMonthPhase == MONTH_PHASE_MIDMONTH);
}

//+------------------------------------------------------------------+
//| Tracker le Monthly High/Low                                        |
//+------------------------------------------------------------------+
void CSessions::UpdateMonthlyHL()
{
   // Chercher le high/low du mois en cours sur D1
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Début du mois
   datetime monthStart = StringToTime(StringFormat("%04d.%02d.01", dt.year, dt.mon));
   
   int barStart = iBarShift(m_symbol, PERIOD_D1, monthStart, false);
   if(barStart < 0) barStart = 30;
   int barEnd = 0;
   
   double highestPrice = 0;
   double lowestPrice = DBL_MAX;
   datetime highTime = 0, lowTime = 0;
   
   for(int b = barStart; b >= barEnd; b--)
   {
      double hi = iHigh(m_symbol, PERIOD_D1, b);
      double lo = iLow(m_symbol, PERIOD_D1, b);
      
      if(hi > highestPrice)
      {
         highestPrice = hi;
         highTime = iTime(m_symbol, PERIOD_D1, b);
      }
      if(lo < lowestPrice)
      {
         lowestPrice = lo;
         lowTime = iTime(m_symbol, PERIOD_D1, b);
      }
   }
   
   m_monthlyHigh = highestPrice;
   m_monthlyLow = lowestPrice;
   m_monthlyHighTime = highTime;
   m_monthlyLowTime = lowTime;
   
   // Le H/L est considéré "formé" si on est passé la période 26-9
   m_monthlyHLFormed = (dt.day > 9 && dt.day < 26);
}

//+------------------------------------------------------------------+
//| NFP = 1er vendredi du mois                                         |
//+------------------------------------------------------------------+
bool CSessions::IsHighImpactNewsDay()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // NFP = premier vendredi du mois (day_of_week == 5, day <= 7)
   if(dt.day_of_week == 5 && dt.day <= 7)
      return true;
   
   // FOMC = typiquement mercredi toutes les 6 semaines
   // Simplification : signaler les mercredis 3ème semaine du mois
   if(dt.day_of_week == 3 && dt.day >= 15 && dt.day <= 21)
      return true;
   
   return false;
}
//+------------------------------------------------------------------+
