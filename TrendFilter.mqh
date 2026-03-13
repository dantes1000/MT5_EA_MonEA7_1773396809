#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// Input parameters
input bool AllowLong = true;                     // Autoriser les positions long
input bool AllowShort = true;                    // Autoriser les positions short
input bool RequireVolumeConfirm = true;          // Exiger confirmation du volume
input bool RequireRetest = false;                // Attendre un retest avant entrée
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1;       // Timeframe pour le calcul du range
input int TrendFilterEMA = 200;                  // Période EMA pour filtre de tendance (0=désactivé)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15;       // Timeframe pour l'exécution des trades
input bool UseNewsFilter = true;                 // Activer le filtre d'actualités économiques
input int NewsMinutesBefore = 60;                // Minutes avant la news pour suspendre le trading
input int NewsMinutesAfter = 30;                 // Minutes après la news pour reprendre le trading
input int NewsImpactLevel = 3;                   // Niveau d'impact minimum : 1=faible, 2=moyen, 3=fort
input bool CloseOnHighImpact = true;             // Fermer les positions avant news à fort impact
input int BreakoutType = 0;                      // 0=Range, 1=BollingerBands, 2=ATR
input double ATRMultiplier = 1.0;                // Multiplicateur ATR pour breakout
input double BBWidthMin = 0.5;                   // Largeur minimale des Bollinger Bands (en %)
input double BBWidthMax = 2.0;                   // Largeur maximale des Bollinger Bands (en %)
input int ADXPeriod = 14;                        // Période ADX
input int ADXThreshold = 20;                     // Seuil minimum ADX
input int RSIPeriod = 14;                        // Période RSI
input int RSIOverbought = 70;                    // Zone de surachat RSI
input int RSIOversold = 30;                      // Zone de survente RSI
input int VolumeSMA = 20;                        // Période SMA pour volume
input double VolumeThreshold = 1.5;              // Seuil volume (>1.5x SMA)
input int TradingStartHour = 8;                  // Heure de début trading (GMT)
input int TradingEndHour = 21;                   // Heure de fin trading (GMT)
input bool CloseBeforeWeekend = true;            // Fermer positions avant weekend
input int WeekendCloseHour = 21;                 // Heure fermeture weekend (GMT)
input int WeekendCloseDay = FRIDAY;              // Jour fermeture weekend
input double RetestTolerancePips = 5.0;          // Tolérance retest en pips
input int SignalShift = 0;                       // Décalage signal

// Global variables
int emaHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;
int bbHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int volumeSMAHandle = INVALID_HANDLE;
double point;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Initialize indicator handles
   if(TrendFilterEMA > 0)
      emaHandle = iMA(_Symbol, PERIOD_H1, TrendFilterEMA, 0, MODE_EMA, PRICE_CLOSE);
   
   atrHandle = iATR(_Symbol, RangeTF, 14);
   bbHandle = iBands(_Symbol, RangeTF, 20, 0, 2.0, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, RangeTF, ADXPeriod);
   rsiHandle = iRSI(_Symbol, RangeTF, RSIPeriod, PRICE_CLOSE);
   volumeSMAHandle = iMA(_Symbol, PERIOD_CURRENT, VolumeSMA, 0, MODE_SMA, VOLUME_TICK);
   
   if(emaHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE || bbHandle == INVALID_HANDLE || 
      adxHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || volumeSMAHandle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return INIT_FAILED;
   }
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(emaHandle != INVALID_HANDLE) IndicatorRelease(emaHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(bbHandle != INVALID_HANDLE) IndicatorRelease(bbHandle);
   if(adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(volumeSMAHandle != INVALID_HANDLE) IndicatorRelease(volumeSMAHandle);
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
//| Get indicator value                                              |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double value[1];
   if(CopyBuffer(handle, buffer, shift, 1, value) <= 0)
      return 0.0;
   return value[0];
}

//+------------------------------------------------------------------+
//| Breakout entry                                                   |
//+------------------------------------------------------------------+
bool IsBreakoutLong(double level, double tolerancePips = 0)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return ask > level + tolerancePips * point * 10;
}

bool IsBreakoutShort(double level, double tolerancePips = 0)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return bid < level - tolerancePips * point * 10;
}

//+------------------------------------------------------------------+
//| Retest check after breakout                                      |
//+------------------------------------------------------------------+
bool IsRetestLong(double level)
{
   double tol = RetestTolerancePips * point * 10;
   double lowBar = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

bool IsRetestShort(double level)
{
   double tol = RetestTolerancePips * point * 10;
   double highBar = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

//+------------------------------------------------------------------+
//| Trend entry (MA crossover)                                       |
//+------------------------------------------------------------------+
bool IsTrendLong(int fastHandle, int slowHandle)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, SignalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, SignalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, SignalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, SignalShift + 1);
   return (fast1 <= slow1 && fast0 > slow0);
}

bool IsTrendShort(int fastHandle, int slowHandle)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, SignalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, SignalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, SignalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, SignalShift + 1);
   return (fast1 >= slow1 && fast0 < slow0);
}

//+------------------------------------------------------------------+
//| EMA trend filter                                                 |
//+------------------------------------------------------------------+
bool IsTrendFilterLong()
{
   if(TrendFilterEMA <= 0) return true;
   
   double emaValue = GetIndicatorValue(emaHandle, 0, 0);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return ask > emaValue;
}

bool IsTrendFilterShort()
{
   if(TrendFilterEMA <= 0) return true;
   
   double emaValue = GetIndicatorValue(emaHandle, 0, 0);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return bid < emaValue;
}

//+------------------------------------------------------------------+
//| ADX strength validation                                          |
//+------------------------------------------------------------------+
bool IsADXStrong()
{
   double adxValue = GetIndicatorValue(adxHandle, 0, 0);
   return adxValue > ADXThreshold;
}

//+------------------------------------------------------------------+
//| RSI overbought/oversold filter                                   |
//+------------------------------------------------------------------+
bool IsRSIOKLong()
{
   double rsiValue = GetIndicatorValue(rsiHandle, 0, 0);
   return rsiValue < RSIOverbought;
}

bool IsRSIOKShort()
{
   double rsiValue = GetIndicatorValue(rsiHandle, 0, 0);
   return rsiValue > RSIOversold;
}

//+------------------------------------------------------------------+
//| Volume confirmation                                              |
//+------------------------------------------------------------------+
bool IsVolumeConfirmed()
{
   if(!RequireVolumeConfirm) return true;
   
   double currentVolume = iVolume(_Symbol, PERIOD_CURRENT, 0);
   double volumeSMA = GetIndicatorValue(volumeSMAHandle, 0, 0);
   
   if(volumeSMA <= 0) return false;
   return currentVolume > volumeSMA * VolumeThreshold;
}

//+------------------------------------------------------------------+
//| ATR volatility filter                                            |
//+------------------------------------------------------------------+
bool IsATRBreakoutLong(double level)
{
   double atrValue = GetIndicatorValue(atrHandle, 0, 0);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return ask > level + atrValue * ATRMultiplier;
}

bool IsATRBreakoutShort(double level)
{
   double atrValue = GetIndicatorValue(atrHandle, 0, 0);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return bid < level - atrValue * ATRMultiplier;
}

//+------------------------------------------------------------------+
//| Bollinger Bands width filter                                     |
//+------------------------------------------------------------------+
bool IsBBWidthOK()
{
   double upper = GetIndicatorValue(bbHandle, 1, 0);
   double lower = GetIndicatorValue(bbHandle, 2, 0);
   double middle = GetIndicatorValue(bbHandle, 0, 0);
   
   if(middle <= 0) return false;
   
   double widthPercent = ((upper - lower) / middle) * 100;
   return widthPercent >= BBWidthMin && widthPercent <= BBWidthMax;
}

//+------------------------------------------------------------------+
//| Trading time filter                                              |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   MqlDateTime dt;
   TimeGMT(dt);
   
   // Check day of week
   if(dt.day_of_week == SATURDAY || dt.day_of_week == SUNDAY)
      return false;
   
   // Check trading hours
   int currentHour = dt.hour;
   return currentHour >= TradingStartHour && currentHour < TradingEndHour;
}

//+------------------------------------------------------------------+
//| Weekend close check                                              |
//+------------------------------------------------------------------+
bool ShouldCloseForWeekend()
{
   if(!CloseBeforeWeekend) return false;
   
   MqlDateTime dt;
   TimeGMT(dt);
   
   return dt.day_of_week == WeekendCloseDay && dt.hour >= WeekendCloseHour;
}

//+------------------------------------------------------------------+
//| News filter (simplified)                                         |
//+------------------------------------------------------------------+
bool IsNewsFilterOK()
{
   if(!UseNewsFilter) return true;
   
   // This is a simplified implementation
   // In real implementation, you would connect to a news feed API
   // For now, always return true
   return true;
}

//+------------------------------------------------------------------+
//| Main filter function                                             |
//+------------------------------------------------------------------+
bool CheckLongEntry()
{
   if(!AllowLong) return false;
   if(!IsTradingTime()) return false;
   if(!IsNewsFilterOK()) return false;
   if(!IsTrendFilterLong()) return false;
   if(!IsADXStrong()) return false;
   if(!IsRSIOKLong()) return false;
   if(!IsVolumeConfirmed()) return false;
   
   // Breakout type specific checks
   switch(BreakoutType)
   {
      case 0: // Range
         // Implement range breakout logic here
         break;
      case 1: // Bollinger Bands
         if(!IsBBWidthOK()) return false;
         // Implement BB breakout logic here
         break;
      case 2: // ATR
         // Implement ATR breakout logic here
         break;
   }
   
   return true;
}

bool CheckShortEntry()
{
   if(!AllowShort) return false;
   if(!IsTradingTime()) return false;
   if(!IsNewsFilterOK()) return false;
   if(!IsTrendFilterShort()) return false;
   if(!IsADXStrong()) return false;
   if(!IsRSIOKShort()) return false;
   if(!IsVolumeConfirmed()) return false;
   
   // Breakout type specific checks
   switch(BreakoutType)
   {
      case 0: // Range
         // Implement range breakout logic here
         break;
      case 1: // Bollinger Bands
         if(!IsBBWidthOK()) return false;
         // Implement BB breakout logic here
         break;
      case 2: // ATR
         // Implement ATR breakout logic here
         break;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if should close positions                                  |
//+------------------------------------------------------------------+
bool ShouldClosePositions()
{
   if(ShouldCloseForWeekend()) return true;
   
   if(CloseOnHighImpact && UseNewsFilter)
   {
      // Check for high impact news
      // Simplified implementation
      return false;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Main entry point for filtering                                   |
//+------------------------------------------------------------------+
bool FilterLongSignal()
{
   // Check on execution timeframe
   if(!IsNewBar(ExecTF)) return false;
   
   return CheckLongEntry();
}

bool FilterShortSignal()
{
   // Check on execution timeframe
   if(!IsNewBar(ExecTF)) return false;
   
   return CheckShortEntry();
}

//+------------------------------------------------------------------+
//| Public interface functions                                       |
//+------------------------------------------------------------------+
bool IsLongSignalValid() { return FilterLongSignal(); }
bool IsShortSignalValid() { return FilterShortSignal(); }
bool ShouldCloseAllPositions() { return ShouldClosePositions(); }
bool IsTradingAllowed() { return IsTradingTime() && IsNewsFilterOK(); }

//+------------------------------------------------------------------+
