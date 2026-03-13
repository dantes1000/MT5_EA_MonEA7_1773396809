#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| BreakoutSignal.mqh - Breakout signals with volume confirmation   |
//+------------------------------------------------------------------+

// Input parameters - Breakout
input int      BreakoutType = 0;           // 0=Range, 1=BollingerBands, 2=ATR
input bool     AllowLong = true;           // Allow long positions
input bool     AllowShort = true;          // Allow short positions
input bool     RequireVolumeConfirm = true;// Require volume confirmation
input bool     RequireRetest = false;      // Wait for retest before entry
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1; // Timeframe for range calculation
input int      TrendFilterEMA = 200;       // EMA period for trend filter (0=disabled)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15; // Timeframe for trade execution

// Input parameters - News filter
input bool     UseNewsFilter = true;       // Enable economic news filter
input int      NewsMinutesBefore = 60;     // Minutes before news to suspend trading
input int      NewsMinutesAfter = 30;      // Minutes after news to resume trading
input int      NewsImpactLevel = 3;        // Minimum impact level: 1=low, 2=medium, 3=high
input bool     CloseOnHighImpact = true;   // Close positions before high impact news

// Input parameters - Indicator filters
input bool     UseATRFilter = true;        // Enable ATR filter
input int      ATRPeriod = 14;             // ATR period
input double   MinATRPips = 20;            // Minimum ATR required (pips)
input double   MaxATRPips = 150;           // Maximum ATR allowed (pips)
input double   ATR_Mult_Min = 1.25;        // Minimum ATR multiplier for breakout validation
input double   ATR_Mult_Max = 3.0;         // Maximum ATR multiplier
input bool     UseBBFilter = true;         // Enable Bollinger Bands filter
input int      BBPeriod = 20;              // Bollinger Bands period
input double   BBDeviation = 2.0;          // BB standard deviation
input double   Min_Width_Pips = 30;        // Minimum BB width (pips)
input bool     UseEMAFilter = true;        // Enable EMA trend filter
input bool     UseADXFilter = true;        // Enable ADX filter
input int      ADXPeriod = 14;             // ADX period
input double   MinADX = 20;                // Minimum ADX value
input bool     UseRSIFilter = true;        // Enable RSI filter
input int      RSIPeriod = 14;             // RSI period
input double   RSI_Overbought = 70;        // Overbought level
input double   RSI_Oversold = 30;          // Oversold level
input bool     UseVolumeFilter = true;     // Enable volume filter
input int      VolumeMAPeriod = 20;        // Volume moving average period
input double   VolumeThreshold = 1.5;      // Volume threshold multiplier

// Internal variables
int            handleATR = INVALID_HANDLE;
int            handleBB = INVALID_HANDLE;
int            handleEMA = INVALID_HANDLE;
int            handleADX = INVALID_HANDLE;
int            handleRSI = INVALID_HANDLE;
int            handleVolumeMA = INVALID_HANDLE;
datetime       lastBarTime = 0;
double         rangeHigh = 0;
double         rangeLow = 0;
bool           newsFilterActive = false;

//+------------------------------------------------------------------+
//| New bar detection                                                |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES tf)
{
   datetime currentBar = iTime(_Symbol, tf, 0);
   if(lastBarTime != currentBar)
   {
      lastBarTime = currentBar;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Breakout entry detection                                         |
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
bool IsRetestLong(double level)
{
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol     = 10 * point * 10; // 10 pips tolerance
   double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

bool IsRetestShort(double level)
{
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol      = 10 * point * 10; // 10 pips tolerance
   double highBar  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

//+------------------------------------------------------------------+
//| Get indicator value                                              |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double value[1];
   if(CopyBuffer(handle, buffer, shift, 1, value) == 1)
      return value[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate range levels                                           |
//+------------------------------------------------------------------+
void CalculateRangeLevels()
{
   if(BreakoutType == 0) // Range
   {
      rangeHigh = iHigh(_Symbol, RangeTF, 1);
      rangeLow = iLow(_Symbol, RangeTF, 1);
   }
   else if(BreakoutType == 1) // Bollinger Bands
   {
      double bbUpper = GetIndicatorValue(handleBB, 1, 1);
      double bbLower = GetIndicatorValue(handleBB, 2, 1);
      rangeHigh = bbUpper;
      rangeLow = bbLower;
   }
   else if(BreakoutType == 2) // ATR
   {
      double atrValue = GetIndicatorValue(handleATR, 0, 1);
      double closePrev = iClose(_Symbol, RangeTF, 1);
      rangeHigh = closePrev + atrValue * ATR_Mult_Min;
      rangeLow = closePrev - atrValue * ATR_Mult_Min;
   }
}

//+------------------------------------------------------------------+
//| Check ATR filter                                                 |
//+------------------------------------------------------------------+
bool CheckATRFilter()
{
   if(!UseATRFilter) return true;
   
   double atrValue = GetIndicatorValue(handleATR, 0, 0);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atrPips = atrValue / point;
   
   if(atrPips < MinATRPips || atrPips > MaxATRPips)
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Check Bollinger Bands filter                                     |
//+------------------------------------------------------------------+
bool CheckBBFilter()
{
   if(!UseBBFilter) return true;
   
   double bbUpper = GetIndicatorValue(handleBB, 1, 0);
   double bbLower = GetIndicatorValue(handleBB, 2, 0);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bbWidthPips = (bbUpper - bbLower) / point;
   
   if(bbWidthPips < Min_Width_Pips)
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Check EMA trend filter                                           |
//+------------------------------------------------------------------+
bool CheckEMAFilter(bool isLong)
{
   if(!UseEMAFilter || TrendFilterEMA == 0) return true;
   
   double emaValue = GetIndicatorValue(handleEMA, 0, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(isLong)
      return currentPrice > emaValue;
   else
      return currentPrice < emaValue;
}

//+------------------------------------------------------------------+
//| Check ADX filter                                                 |
//+------------------------------------------------------------------+
bool CheckADXFilter()
{
   if(!UseADXFilter) return true;
   
   double adxValue = GetIndicatorValue(handleADX, 0, 0);
   return adxValue > MinADX;
}

//+------------------------------------------------------------------+
//| Check RSI filter                                                 |
//+------------------------------------------------------------------+
bool CheckRSIFilter(bool isLong)
{
   if(!UseRSIFilter) return true;
   
   double rsiValue = GetIndicatorValue(handleRSI, 0, 0);
   
   if(isLong)
      return rsiValue < RSI_Overbought;
   else
      return rsiValue > RSI_Oversold;
}

//+------------------------------------------------------------------+
//| Check volume confirmation                                        |
//+------------------------------------------------------------------+
bool CheckVolumeConfirmation()
{
   if(!RequireVolumeConfirm || !UseVolumeFilter) return true;
   
   long currentVolume = iVolume(_Symbol, PERIOD_CURRENT, 0);
   double volumeMA = GetIndicatorValue(handleVolumeMA, 0, 0);
   
   if(volumeMA > 0 && currentVolume > volumeMA * VolumeThreshold)
      return true;
      
   return false;
}

//+------------------------------------------------------------------+
//| Check news filter                                                |
//+------------------------------------------------------------------+
bool CheckNewsFilter()
{
   if(!UseNewsFilter) return true;
   
   // This is a simplified implementation
   // In real implementation, you would integrate with FFCal indicator
   // For now, we'll simulate the logic
   
   datetime currentTime = TimeCurrent();
   newsFilterActive = false;
   
   // Simulated news events - in real code, get from FFCal
   // For demonstration, assume no news is currently active
   
   return !newsFilterActive;
}

//+------------------------------------------------------------------+
//| Initialize indicators                                            |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
   // Initialize ATR
   if(UseATRFilter || BreakoutType == 2)
   {
      handleATR = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
      if(handleATR == INVALID_HANDLE)
         return false;
   }
   
   // Initialize Bollinger Bands
   if(UseBBFilter || BreakoutType == 1)
   {
      handleBB = iBands(_Symbol, PERIOD_CURRENT, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
      if(handleBB == INVALID_HANDLE)
         return false;
   }
   
   // Initialize EMA for trend filter
   if(UseEMAFilter && TrendFilterEMA > 0)
   {
      handleEMA = iMA(_Symbol, PERIOD_H1, TrendFilterEMA, 0, MODE_EMA, PRICE_CLOSE);
      if(handleEMA == INVALID_HANDLE)
         return false;
   }
   
   // Initialize ADX
   if(UseADXFilter)
   {
      handleADX = iADX(_Symbol, PERIOD_CURRENT, ADXPeriod);
      if(handleADX == INVALID_HANDLE)
         return false;
   }
   
   // Initialize RSI
   if(UseRSIFilter)
   {
      handleRSI = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
      if(handleRSI == INVALID_HANDLE)
         return false;
   }
   
   // Initialize Volume MA
   if(UseVolumeFilter)
   {
      handleVolumeMA = iMA(_Symbol, PERIOD_CURRENT, VolumeMAPeriod, 0, MODE_SMA, VOLUME_TICK);
      if(handleVolumeMA == INVALID_HANDLE)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for breakout signals                                       |
//+------------------------------------------------------------------+
int CheckBreakoutSignals()
{
   // Check if we're on execution timeframe
   if(Period() != ExecTF)
      return 0;
   
   // Check for new bar
   if(!IsNewBar(ExecTF))
      return 0;
   
   // Check news filter
   if(!CheckNewsFilter())
      return 0;
   
   // Calculate range levels
   CalculateRangeLevels();
   
   // Check ATR filter
   if(!CheckATRFilter())
      return 0;
   
   // Check Bollinger Bands filter
   if(!CheckBBFilter())
      return 0;
   
   int signal = 0;
   
   // Check long breakout
   if(AllowLong)
   {
      if(IsBreakoutLong(rangeHigh))
      {
         if((!RequireRetest || IsRetestLong(rangeHigh)) &&
            CheckEMAFilter(true) &&
            CheckADXFilter() &&
            CheckRSIFilter(true) &&
            CheckVolumeConfirmation())
         {
            signal = 1; // Buy signal
         }
      }
   }
   
   // Check short breakout
   if(AllowShort && signal == 0)
   {
      if(IsBreakoutShort(rangeLow))
      {
         if((!RequireRetest || IsRetestShort(rangeLow)) &&
            CheckEMAFilter(false) &&
            CheckADXFilter() &&
            CheckRSIFilter(false) &&
            CheckVolumeConfirmation())
         {
            signal = -1; // Sell signal
         }
      }
   }
   
   return signal;
}

//+------------------------------------------------------------------+
//| Deinitialize indicators                                          |
//+------------------------------------------------------------------+
void DeinitializeIndicators()
{
   if(handleATR != INVALID_HANDLE)
   {
      IndicatorRelease(handleATR);
      handleATR = INVALID_HANDLE;
   }
   
   if(handleBB != INVALID_HANDLE)
   {
      IndicatorRelease(handleBB);
      handleBB = INVALID_HANDLE;
   }
   
   if(handleEMA != INVALID_HANDLE)
   {
      IndicatorRelease(handleEMA);
      handleEMA = INVALID_HANDLE;
   }
   
   if(handleADX != INVALID_HANDLE)
   {
      IndicatorRelease(handleADX);
      handleADX = INVALID_HANDLE;
   }
   
   if(handleRSI != INVALID_HANDLE)
   {
      IndicatorRelease(handleRSI);
      handleRSI = INVALID_HANDLE;
   }
   
   if(handleVolumeMA != INVALID_HANDLE)
   {
      IndicatorRelease(handleVolumeMA);
      handleVolumeMA = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Main initialization function                                     |
//+------------------------------------------------------------------+
bool InitBreakoutSignal()
{
   if(!InitializeIndicators())
   {
      Print("Failed to initialize indicators");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Main deinitialization function                                   |
//+------------------------------------------------------------------+
void DeinitBreakoutSignal()
{
   DeinitializeIndicators();
}

//+------------------------------------------------------------------+
//| Main signal checking function                                    |
//+------------------------------------------------------------------+
int GetBreakoutSignal()
{
   return CheckBreakoutSignals();
}

//+------------------------------------------------------------------+
//| Check if news filter is active                                   |
//+------------------------------------------------------------------+
bool IsNewsFilterActive()
{
   return newsFilterActive;
}

//+------------------------------------------------------------------+
