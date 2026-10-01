//+------------------------------------------------------------------+
//|                                             SMC_Telegram.mqh     |
//|              Version 2 - Notifications Telegram (comme V1)       |
//|         Credentials depuis fichier + Signal / OB / TP / SL        |
//+------------------------------------------------------------------+
#property copyright "RG_SMV"
#property link      ""
#property version   "2.00"

//+------------------------------------------------------------------+
//| Classe Telegram - même logique que Version 1                      |
//| Fichier credentials : Terminal\Common\Files\telegram_credentials.txt |
//| Ligne 1 = Bot Token, Ligne 2 = Chat ID                            |
//+------------------------------------------------------------------+
class CTelegram
{
private:
   string m_botToken;
   string m_chatId;
   bool   m_initialized;
   string m_symbol;
   string m_credentialsFile;

   bool   LoadCredentials(string &botToken, string &chatId);
   bool   SaveCredentials();
   string UrlEncode(string text);
   bool   SendMessage(string text);

public:
   CTelegram();
   bool   Init(string symbol, string botToken, string chatId);

   // Signal (comme V1)
   bool   SendBuySignal(double entry, double sl, double tp1, double tp2, double rr);
   bool   SendSellSignal(double entry, double sl, double tp1, double tp2, double rr);

   // Order Block détecté
   bool   SendOrderBlockDetected(bool bullish, double priceHigh, double priceLow, string tfStr);

   // TP touché (niveau de liquidité atteint)
   bool   SendTPTouched(string levelType, double price, bool forBuy);

   // SL touché (niveau d'invalidation)
   bool   SendSLTouched(double price, bool wasBuyContext);

   bool   SendAlert(string alertMessage);
   bool   TestConnection();
};

//+------------------------------------------------------------------+
CTelegram::CTelegram()
{
   m_initialized = false;
   m_botToken = "";
   m_chatId = "";
   m_symbol = "";
   m_credentialsFile = "telegram_credentials.txt";
}

//+------------------------------------------------------------------+
bool CTelegram::Init(string symbol, string botToken, string chatId)
{
   m_symbol = symbol;
   m_botToken = botToken;
   m_chatId = chatId;

   if(m_botToken == "" || m_chatId == "")
   {
      string loadedToken = "";
      string loadedChatId = "";
      if(LoadCredentials(loadedToken, loadedChatId))
      {
         m_botToken = loadedToken;
         m_chatId = loadedChatId;
         Print("Telegram: Credentials charges depuis le fichier");
      }
   }

   if(m_botToken == "" || m_chatId == "")
   {
      Print("Telegram: Token ou ChatID manquant!");
      Print("Telegram: Entrez vos credentials dans les parametres de l'EA ou dans ", m_credentialsFile);
      m_initialized = false;
      return false;
   }

   SaveCredentials();
   m_initialized = true;
   Print("Telegram initialise. ChatID: ", m_chatId);
   return true;
}

//+------------------------------------------------------------------+
bool CTelegram::SaveCredentials()
{
   int handle = FileOpen(m_credentialsFile, FILE_WRITE|FILE_TXT|FILE_COMMON);
   if(handle == INVALID_HANDLE)
   {
      Print("Telegram: Impossible de sauvegarder les credentials");
      return false;
   }
   FileWriteString(handle, m_botToken + "\n");
   FileWriteString(handle, m_chatId + "\n");
   FileClose(handle);
   Print("Telegram: Credentials sauvegardes dans ", m_credentialsFile);
   return true;
}

//+------------------------------------------------------------------+
bool CTelegram::LoadCredentials(string &botToken, string &chatId)
{
   if(!FileIsExist(m_credentialsFile, FILE_COMMON))
      return false;
   int handle = FileOpen(m_credentialsFile, FILE_READ|FILE_TXT|FILE_COMMON);
   if(handle == INVALID_HANDLE)
      return false;
   botToken = FileReadString(handle);
   chatId = FileReadString(handle);
   FileClose(handle);
   StringReplace(botToken, "\n", "");
   StringReplace(botToken, "\r", "");
   StringReplace(chatId, "\n", "");
   StringReplace(chatId, "\r", "");
   return (botToken != "" && chatId != "");
}

//+------------------------------------------------------------------+
bool CTelegram::SendMessage(string text)
{
   if(!m_initialized) return false;
   string encodedText = UrlEncode(text);
   string url = "https://api.telegram.org/bot" + m_botToken +
                "/sendMessage?chat_id=" + m_chatId + "&text=" + encodedText;
   char post[], result[];
   string headers = "";
   ResetLastError();
   int res = WebRequest("GET", url, headers, 5000, post, result, headers);
   if(res == -1)
   {
      int err = GetLastError();
      Print("Telegram WebRequest error: ", err);
      if(err == 4060)
         Print("ATTENTION: Ajoutez 'https://api.telegram.org' dans Options -> Expert Advisors -> WebRequest");
      return false;
   }
   string response = CharArrayToString(result);
   if(StringFind(response, "\"ok\":true") >= 0)
   {
      Print("Telegram: Message envoye");
      return true;
   }
   Print("Telegram: Erreur. Response: ", response);
   return false;
}

//+------------------------------------------------------------------+
string CTelegram::UrlEncode(string text)
{
   string result = "";
   int len = StringLen(text);
   for(int i = 0; i < len; i++)
   {
      ushort ch = StringGetCharacter(text, i);
      if((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || (ch >= '0' && ch <= '9') ||
         ch == '-' || ch == '_' || ch == '.' || ch == '~' || ch == ':' || ch == '>' || ch == '<' || ch == '=' || ch == '!')
         result += CharToString((uchar)ch);
      else if(ch == ' ')
         result += "%20";
      else if(ch == '\n')
         result += "%0A";
      else if(ch < 128)
         result += StringFormat("%%%02X", ch);
   }
   return result;
}

//+------------------------------------------------------------------+
bool CTelegram::SendBuySignal(double entry, double sl, double tp1, double tp2, double rr)
{
   if(!m_initialized) return false;
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   string msg = "";
   msg += ">>> SIGNAL ACHAT <<<\n";
   msg += "====================\n";
   msg += "Paire: " + m_symbol + "\n";
   msg += "Entree: " + DoubleToString(entry, digits) + "\n";
   msg += "Stop Loss: " + DoubleToString(sl, digits) + "\n";
   msg += "TP1: " + DoubleToString(tp1, digits) + " | TP2: " + DoubleToString(tp2, digits) + "\n";
   msg += "R:R: " + DoubleToString(rr, 1) + "\n";
   msg += "Heure: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n";
   return SendMessage(msg);
}

//+------------------------------------------------------------------+
bool CTelegram::SendSellSignal(double entry, double sl, double tp1, double tp2, double rr)
{
   if(!m_initialized) return false;
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   string msg = "";
   msg += ">>> SIGNAL VENTE <<<\n";
   msg += "====================\n";
   msg += "Paire: " + m_symbol + "\n";
   msg += "Entree: " + DoubleToString(entry, digits) + "\n";
   msg += "Stop Loss: " + DoubleToString(sl, digits) + "\n";
   msg += "TP1: " + DoubleToString(tp1, digits) + " | TP2: " + DoubleToString(tp2, digits) + "\n";
   msg += "R:R: " + DoubleToString(rr, 1) + "\n";
   msg += "Heure: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n";
   return SendMessage(msg);
}

//+------------------------------------------------------------------+
bool CTelegram::SendOrderBlockDetected(bool bullish, double priceHigh, double priceLow, string tfStr)
{
   if(!m_initialized) return false;
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   string dir = bullish ? "DEMANDE (Bullish)" : "OFFRE (Bearish)";
   string msg = "";
   msg += "[ ORDER BLOCK ]\n";
   msg += "====================\n";
   msg += m_symbol + " | " + tfStr + "\n";
   msg += "Type: " + dir + "\n";
   msg += "Haut: " + DoubleToString(priceHigh, digits) + "\n";
   msg += "Bas:  " + DoubleToString(priceLow, digits) + "\n";
   msg += "Heure: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n";
   return SendMessage(msg);
}

//+------------------------------------------------------------------+
bool CTelegram::SendTPTouched(string levelType, double price, bool forBuy)
{
   if(!m_initialized) return false;
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   string dir = forBuy ? "ACHAT" : "VENTE";
   string msg = "";
   msg += "[ TP TOUCHE ]\n";
   msg += "====================\n";
   msg += m_symbol + "\n";
   msg += "Niveau: " + levelType + "\n";
   msg += "Prix: " + DoubleToString(price, digits) + "\n";
   msg += "Contexte: " + dir + "\n";
   msg += "Heure: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n";
   return SendMessage(msg);
}

//+------------------------------------------------------------------+
bool CTelegram::SendSLTouched(double price, bool wasBuyContext)
{
   if(!m_initialized) return false;
   int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   string ctx = wasBuyContext ? "ACHAT (inv. sous support)" : "VENTE (inv. au-dessus resistance)";
   string msg = "";
   msg += "[ SL TOUCHE ]\n";
   msg += "====================\n";
   msg += m_symbol + "\n";
   msg += "Prix: " + DoubleToString(price, digits) + "\n";
   msg += "Contexte: " + ctx + "\n";
   msg += "Heure: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n";
   return SendMessage(msg);
}

//+------------------------------------------------------------------+
bool CTelegram::SendAlert(string alertMessage)
{
   if(!m_initialized) return false;
   return SendMessage("!!! ALERTE !!!\n" + m_symbol + "\n" + alertMessage);
}

//+------------------------------------------------------------------+
bool CTelegram::TestConnection()
{
   return SendMessage("RG_SMV V2 connecte!\nTelegram OK.");
}
//+------------------------------------------------------------------+
