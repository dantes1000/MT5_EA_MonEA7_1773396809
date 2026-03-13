//+------------------------------------------------------------------+
//|                                                      Utilities.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Helper functions for timeframe conversion, pip calculations, and logging |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Timeframe conversion functions                                   |
//+------------------------------------------------------------------+
int TimeframeToSeconds(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return 60;
      case PERIOD_M2:  return 120;
      case PERIOD_M3:  return 180;
      case PERIOD_M4:  return 240;
      case PERIOD_M5:  return 300;
      case PERIOD_M6:  return 360;
      case PERIOD_M10: return 600;
      case PERIOD_M12: return 720;
      case PERIOD_M15: return 900;
      case PERIOD_M20: return 1200;
      case PERIOD_M30: return 1800;
      case PERIOD_H1:  return 3600;
      case PERIOD_H2:  return 7200;
      case PERIOD_H3:  return 10800;
      case PERIOD_H4:  return 14400;
      case PERIOD_H6:  return 21600;
      case PERIOD_H8:  return 28800;
      case PERIOD_H12: return 43200;
      case PERIOD_D1:  return 86400;
      case PERIOD_W1:  return 604800;
      case PERIOD_MN1: return 2592000;
      default:         return 0;
   }
}

ENUM_TIMEFRAMES SecondsToTimeframe(int seconds)
{
   switch(seconds)
   {
      case 60:     return PERIOD_M1;
      case 120:    return PERIOD_M2;
      case 180:    return PERIOD_M3;
      case 240:    return PERIOD_M4;
      case 300:    return PERIOD_M5;
      case 360:    return PERIOD_M6;
      case 600:    return PERIOD_M10;
      case 720:    return PERIOD_M12;
      case 900:    return PERIOD_M15;
      case 1200:   return PERIOD_M20;
      case 1800:   return PERIOD_M30;
      case 3600:   return PERIOD_H1;
      case 7200:   return PERIOD_H2;
      case 10800:  return PERIOD_H3;
      case 14400:  return PERIOD_H4;
      case 21600:  return PERIOD_H6;
      case 28800:  return PERIOD_H8;
      case 43200:  return PERIOD_H12;
      case 86400:  return PERIOD_D1;
      case 604800: return PERIOD_W1;
      case 2592000:return PERIOD_MN1;
      default:     return PERIOD_CURRENT;
   }
}

string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M2:  return "M2";
      case PERIOD_M3:  return "M3";
      case PERIOD_M4:  return "M4";
      case PERIOD_M5:  return "M5";
      case PERIOD_M6:  return "M6";
      case PERIOD_M10: return "M10";
      case PERIOD_M12: return "M12";
      case PERIOD_M15: return "M15";
      case PERIOD_M20: return "M20";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H3:  return "H3";
      case PERIOD_H4:  return "H4";
      case PERIOD_H6:  return "H6";
      case PERIOD_H8:  return "H8";
      case PERIOD_H12: return "H12";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "CURRENT";
   }
}

//+------------------------------------------------------------------+
//| Pip calculation functions                                        |
//+------------------------------------------------------------------+
double GetPipValue()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tick  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   // For 5-digit brokers, pip is usually 10 points
   if(point == 0.00001) return point * 10;
   // For 4-digit brokers, pip is usually 1 point
   if(point == 0.0001) return point;
   // For JPY pairs
   if(point == 0.001) return point * 10;
   // For JPY pairs on 3-digit brokers
   if(point == 0.01) return point;
   
   return point;
}

double PriceToPips(double priceDifference)
{
   double pipValue = GetPipValue();
   if(pipValue == 0) return 0;
   return priceDifference / pipValue;
}

double PipsToPrice(double pips)
{
   double pipValue = GetPipValue();
   return pips * pipValue;
}

//+------------------------------------------------------------------+
//| Lot size calculation                                             |
//+------------------------------------------------------------------+
double CalcLotSize(double riskPercent, double stopLossPips, double accountBalance = 0)
{
   if(accountBalance <= 0)
      accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   if(accountBalance <= 0 || riskPercent <= 0 || stopLossPips <= 0)
      return 0.01; // Default minimum lot
   
   double riskAmount = accountBalance * (riskPercent / 100.0);
   double pipValue = GetPipValue();
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(pipValue == 0 || tickValue == 0)
      return 0.01;
   
   double lotSize = riskAmount / (stopLossPips * pipValue * tickValue);
   
   // Normalize lot size to broker's requirements
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Logging functions                                                |
//+------------------------------------------------------------------+
void LogInfo(string message)
{
   Print("[INFO] ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), " - ", message);
}

void LogWarning(string message)
{
   Print("[WARNING] ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), " - ", message);
}

void LogError(string message)
{
   Print("[ERROR] ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), " - ", message);
}

void LogTrade(string symbol, double volume, ENUM_ORDER_TYPE type, double price, double sl, double tp, string comment = "")
{
   string typeStr = "";
   switch(type)
   {
      case ORDER_TYPE_BUY: typeStr = "BUY"; break;
      case ORDER_TYPE_SELL: typeStr = "SELL"; break;
      case ORDER_TYPE_BUY_LIMIT: typeStr = "BUY LIMIT"; break;
      case ORDER_TYPE_SELL_LIMIT: typeStr = "SELL LIMIT"; break;
      case ORDER_TYPE_BUY_STOP: typeStr = "BUY STOP"; break;
      case ORDER_TYPE_SELL_STOP: typeStr = "SELL STOP"; break;
      default: typeStr = "UNKNOWN";
   }
   
   string logMsg = StringFormat("Trade: %s %s %.2f lots @ %.5f SL:%.5f TP:%.5f %s", 
                                symbol, typeStr, volume, price, sl, tp, comment);
   LogInfo(logMsg);
}

//+------------------------------------------------------------------+
//| Price level functions                                            |
//+------------------------------------------------------------------+
double GetHigh(ENUM_TIMEFRAMES tf, int shift = 0)
{
   return iHigh(_Symbol, tf, shift);
}

double GetLow(ENUM_TIMEFRAMES tf, int shift = 0)
{
   return iLow(_Symbol, tf, shift);
}

double GetClose(ENUM_TIMEFRAMES tf, int shift = 0)
{
   return iClose(_Symbol, tf, shift);
}

double GetOpen(ENUM_TIMEFRAMES tf, int shift = 0)
{
   return iOpen(_Symbol, tf, shift);
}

//+------------------------------------------------------------------+
//| New bar detection                                                |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES tf)
{
   static datetime lastBarTime = 0;
   datetime currentBar = iTime(_Symbol, tf, 0);
   if(lastBarTime != currentBar)
   {
      lastBarTime = currentBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Breakout detection functions                                     |
//+------------------------------------------------------------------+
bool IsBreakoutLong(double level, double tolerancePips = 0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return ask > level + tolerancePips * point * 10;
}

bool IsBreakoutShort(double level, double tolerancePips = 0)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return bid < level - tolerancePips * point * 10;
}

//+------------------------------------------------------------------+
//| Retest check after breakout                                      |
//+------------------------------------------------------------------+
bool IsRetestLong(double level, double tolerancePips = 0)
{
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol     = tolerancePips * point * 10;
   double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

bool IsRetestShort(double level, double tolerancePips = 0)
{
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol      = tolerancePips * point * 10;
   double highBar  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

//+------------------------------------------------------------------+
//| Indicator value helper                                           |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double value[];
   ArraySetAsSeries(value, true);
   
   if(CopyBuffer(handle, buffer, shift, 1, value) < 1)
      return 0;
      
   return value[0];
}

//+------------------------------------------------------------------+
//| Trend entry (MA crossover)                                       |
//+------------------------------------------------------------------+
bool IsTrendLong(int fastHandle, int slowHandle, int signalShift = 0)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, signalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, signalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, signalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, signalShift + 1);
   return (fast1 <= slow1 && fast0 > slow0);
}

bool IsTrendShort(int fastHandle, int slowHandle, int signalShift = 0)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, signalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, signalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, signalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, signalShift + 1);
   return (fast1 >= slow1 && fast0 < slow0);
}

//+------------------------------------------------------------------+
//| Volume confirmation                                              |
//+------------------------------------------------------------------+
bool IsVolumeConfirm(int period = 20, double threshold = 1.5)
{
   long volumeArray[];
   ArraySetAsSeries(volumeArray, true);
   
   if(CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, period + 1, volumeArray) < period + 1)
      return false;
   
   // Calculate SMA of volume
   double sum = 0;
   for(int i = 1; i <= period; i++)
      sum += volumeArray[i];
   
   double volumeSMA = sum / period;
   double currentVolume = volumeArray[0];
   
   return currentVolume > volumeSMA * threshold;
}

//+------------------------------------------------------------------+
//| News filter helper                                               |
//+------------------------------------------------------------------+
bool IsNewsTime(int minutesBefore = 60, int minutesAfter = 30, int minImpactLevel = 3)
{
   // This is a placeholder - in real implementation you would integrate with FFCal indicator
   // or use an economic calendar API
   
   // For now, return false (no news) - implement actual news checking logic here
   return false;
}

//+------------------------------------------------------------------+
//| ATR filter                                                       |
//+------------------------------------------------------------------+
double GetATRValue(int period = 14, int shift = 0)
{
   int handle = iATR(_Symbol, PERIOD_CURRENT, period);
   if(handle == INVALID_HANDLE)
      return 0;
      
   return GetIndicatorValue(handle, 0, shift);
}

bool IsValidATR(double minPips = 20, double maxPips = 150)
{
   double atrValue = GetATRValue();
   double atrPips = PriceToPips(atrValue);
   
   return (atrPips >= minPips && atrPips <= maxPips);
}

//+------------------------------------------------------------------+
//| Bollinger Bands filter                                           |
//+------------------------------------------------------------------+
bool IsValidBBWidth(double minWidthPips = 30)
{
   int handle = iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return false;
      
   double upper = GetIndicatorValue(handle, 1, 0);
   double lower = GetIndicatorValue(handle, 2, 0);
   
   double widthPips = PriceToPips(upper - lower);
   return widthPips >= minWidthPips;
}

//+------------------------------------------------------------------+
//| EMA trend filter                                                 |
//+------------------------------------------------------------------+
bool IsTrendFilterLong(int emaPeriod = 200, ENUM_TIMEFRAMES tf = PERIOD_H1)
{
   int handle = iMA(_Symbol, tf, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return false;
      
   double emaValue = GetIndicatorValue(handle, 0, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   return currentPrice > emaValue;
}

bool IsTrendFilterShort(int emaPeriod = 200, ENUM_TIMEFRAMES tf = PERIOD_H1)
{
   int handle = iMA(_Symbol, tf, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return false;
      
   double emaValue = GetIndicatorValue(handle, 0, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   return currentPrice < emaValue;
}

//+------------------------------------------------------------------+
//| ADX trend strength                                               |
//+------------------------------------------------------------------+
bool IsStrongTrend(double minStrength = 20)
{
   int handle = iADX(_Symbol, PERIOD_CURRENT, 14);
   if(handle == INVALID_HANDLE)
      return false;
      
   double adxValue = GetIndicatorValue(handle, 0, 0);
   return adxValue >= minStrength;
}

//+------------------------------------------------------------------+
//| RSI overbought/oversold                                          |
//+------------------------------------------------------------------+
bool IsOverbought(int period = 14, double level = 70)
{
   int handle = iRSI(_Symbol, PERIOD_CURRENT, period, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return false;
      
   double rsiValue = GetIndicatorValue(handle, 0, 0);
   return rsiValue >= level;
}

bool IsOversold(int period = 14, double level = 30)
{
   int handle = iRSI(_Symbol, PERIOD_CURRENT, period, PRICE_CLOSE);
   if(handle == INVALID_HANDLE)
      return false;
      
   double rsiValue = GetIndicatorValue(handle, 0, 0);
   return rsiValue <= level;
}

//+------------------------------------------------------------------+
//| Range calculation                                                |
//+------------------------------------------------------------------+
bool GetDailyRange(double &high, double &low, int shift = 0)
{
   high = iHigh(_Symbol, PERIOD_D1, shift);
   low = iLow(_Symbol, PERIOD_D1, shift);
   
   return (high > 0 && low > 0);
}

//+------------------------------------------------------------------+
//| Position management helpers                                      |
//+------------------------------------------------------------------+
int CountOpenPositions(string symbol = "", int magic = -1)
{
   int count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if((symbol == "" || PositionGetString(POSITION_SYMBOL) == symbol) &&
            (magic == -1 || PositionGetInteger(POSITION_MAGIC) == magic))
         {
            count++;
         }
      }
   }
   
   return count;
}

bool CloseAllPositions(string symbol = "", int magic = -1)
{
   bool result = true;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if((symbol == "" || PositionGetString(POSITION_SYMBOL) == symbol) &&
            (magic == -1 || PositionGetInteger(POSITION_MAGIC) == magic))
         {
            MqlTradeRequest request = {};
            MqlTradeResult  resultTrade = {};
            
            request.action   = TRADE_ACTION_DEAL;
            request.position = PositionGetTicket(i);
            request.symbol   = PositionGetString(POSITION_SYMBOL);
            request.volume   = PositionGetDouble(POSITION_VOLUME);
            request.deviation= 5;
            request.magic    = PositionGetInteger(POSITION_MAGIC);
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               request.price = SymbolInfoDouble(request.symbol, SYMBOL_BID);
               request.type  = ORDER_TYPE_SELL;
            }
            else
            {
               request.price = SymbolInfoDouble(request.symbol, SYMBOL_ASK);
               request.type  = ORDER_TYPE_BUY;
            }
            
            if(!OrderSend(request, resultTrade))
               result = false;
         }
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
