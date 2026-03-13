#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// NewsFilter.mqh - Integrates FFCal indicator to disable trading around high-impact economic news

// Input parameters
input bool   UseNewsFilter = true;               // Activer le filtre d'actualités économiques
input int    NewsMinutesBefore = 60;             // Minutes avant la news pour suspendre le trading
input int    NewsMinutesAfter = 30;              // Minutes après la news pour reprendre le trading
input int    NewsImpactLevel = 3;                // Niveau d'impact minimum : 1=faible, 2=moyen, 3=fort
input bool   CloseOnHighImpact = true;           // Fermer les positions avant news à fort impact
input bool   UseATRFilter = true;                // Activer le filtre ATR
input int    ATRPeriod = 14;                     // Période ATR
input double MinATRPips = 20;                    // ATR minimum requis (pips)
input double MaxATRPips = 150;                   // ATR maximum autorisé (pips)
input double ATR_Mult_Min = 1.25;                // Multiplicateur ATR minimum pour valider un breakout
input double ATR_Mult_Max = 3.0;                 // Multiplicateur ATR maximum
input bool   UseBBFilter = true;                 // Activer le filtre Bollinger Bands
input int    BBPeriod = 20;                      // Période Bollinger Bands
input double BBDeviation = 2.0;                  // Déviation standard BB
input double Min_Width_Pips = 30;                // Largeur BB minimum (pips)
input double Max_Width_Pips = 200;               // Largeur BB maximum (pips)
input bool   UseEMAFilter = true;                // Activer le filtre EMA
input int    EMAPeriod = 200;                    // Période EMA
input bool   UseADXFilter = true;                // Activer le filtre ADX
input int    ADXPeriod = 14;                     // Période ADX
input double MinADX = 20;                        // Force de tendance minimum
input bool   UseRSIFilter = true;                // Activer le filtre RSI
input int    RSIPeriod = 14;                     // Période RSI
input double OverboughtLevel = 70;               // Niveau de surachat
input double OversoldLevel = 30;                 // Niveau de survente
input bool   UseVolumeFilter = true;             // Activer le filtre Volume
input int    VolumeSMAPeriod = 20;               // Période SMA du volume
input double VolumeThreshold = 1.5;              // Seuil volume (>1.5x moyenne)
input int    TradingStartHour = 8;               // Heure de début trading (GMT)
input int    TradingEndHour = 21;                // Heure de fin trading (GMT)
input bool   CloseBeforeWeekend = true;          // Fermer positions avant weekend
input int    WeekendCloseHour = 21;              // Heure fermeture weekend (GMT)
input int    WeekendCloseDay = 5;                // Jour fermeture weekend (5=Vendredi)

// Global variables
int atrHandle = -1;
int bbHandle = -1;
int emaHandle = -1;
int adxHandle = -1;
int rsiHandle = -1;
int volumeHandle = -1;
int volumeSMAHandle = -1;
datetime lastNewsCheck = 0;
bool newsTradingAllowed = true;

// [entry_signals]
// --- New bar detection (call at start of OnTick)
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

// --- Breakout entry
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

// --- Retest check after breakout
bool IsRetestLong(double level, double RetestTolerancePips)
{
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol     = RetestTolerancePips * point * 10;
   double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

bool IsRetestShort(double level, double RetestTolerancePips)
{
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol      = RetestTolerancePips * point * 10;
   double highBar  = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

// --- Trend entry (MA crossover)
bool IsTrendLong(int fastHandle, int slowHandle, int SignalShift)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, SignalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, SignalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, SignalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, SignalShift + 1);
   return (fast1 <= slow1 && fast0 > slow0);
}

bool IsTrendShort(int fastHandle, int slowHandle, int SignalShift)
{
   double fast0 = GetIndicatorValue(fastHandle, 0, SignalShift);
   double slow0 = GetIndicatorValue(slowHandle, 0, SignalShift);
   double fast1 = GetIndicatorValue(fastHandle, 0, SignalShift + 1);
   double slow1 = GetIndicatorValue(slowHandle, 0, SignalShift + 1);
   return (fast1 >= slow1 && fast0 < slow0);
}

// Helper function to get indicator value
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double value[1];
   if(CopyBuffer(handle, buffer, shift, 1, value) == 1)
      return value[0];
   return 0.0;
}

// Initialize indicators
bool InitIndicators()
{
   if(UseATRFilter)
   {
      atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
      if(atrHandle == INVALID_HANDLE)
         return false;
   }
   
   if(UseBBFilter)
   {
      bbHandle = iBands(_Symbol, PERIOD_CURRENT, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
      if(bbHandle == INVALID_HANDLE)
         return false;
   }
   
   if(UseEMAFilter)
   {
      emaHandle = iMA(_Symbol, PERIOD_H1, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(emaHandle == INVALID_HANDLE)
         return false;
   }
   
   if(UseADXFilter)
   {
      adxHandle = iADX(_Symbol, PERIOD_CURRENT, ADXPeriod);
      if(adxHandle == INVALID_HANDLE)
         return false;
   }
   
   if(UseRSIFilter)
   {
      rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
      if(rsiHandle == INVALID_HANDLE)
         return false;
   }
   
   if(UseVolumeFilter)
   {
      volumeHandle = iVolumes(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
      volumeSMAHandle = iMAOnArray(GetVolumeArray(), 0, VolumeSMAPeriod, 0, MODE_SMA, 0);
      if(volumeHandle == INVALID_HANDLE || volumeSMAHandle == INVALID_HANDLE)
         return false;
   }
   
   return true;
}

// Get volume array for SMA calculation
double GetVolumeArray()
{
   double volumes[];
   ArraySetAsSeries(volumes, true);
   if(CopyBuffer(volumeHandle, 0, 0, VolumeSMAPeriod + 10, volumes) > 0)
      return volumes;
   return 0.0;
}

// Check if trading is allowed based on time filters
bool IsTradingTimeAllowed()
{
   MqlDateTime timeStruct;
   TimeGMT(timeStruct);
   
   // Check trading hours
   if(timeStruct.hour < TradingStartHour || timeStruct.hour >= TradingEndHour)
      return false;
   
   // Check weekend closing
   if(CloseBeforeWeekend && timeStruct.day_of_week == WeekendCloseDay && timeStruct.hour >= WeekendCloseHour)
      return false;
   
   return true;
}

// Check news filter
bool CheckNewsFilter()
{
   if(!UseNewsFilter)
      return true;
   
   // Check if we need to update news status (once per minute)
   MqlDateTime currentTime;
   TimeGMT(currentTime);
   datetime currentGMT = TimeGMT();
   
   if(currentGMT - lastNewsCheck >= 60)
   {
      lastNewsCheck = currentGMT;
      
      // Simulate FFCal integration - in real implementation, use iCustom with FFCal
      // This is a simplified version
      bool highImpactNewsNear = SimulateFFCalCheck(currentGMT);
      
      if(highImpactNewsNear)
      {
         newsTradingAllowed = false;
         
         // Close positions if required
         if(CloseOnHighImpact)
            CloseAllPositions();
            
         return false;
      }
      else
      {
         newsTradingAllowed = true;
      }
   }
   
   return newsTradingAllowed;
}

// Simulate FFCal check (replace with actual FFCal integration)
bool SimulateFFCalCheck(datetime currentTime)
{
   // This should be replaced with actual FFCal indicator calls
   // For now, return false to allow trading
   return false;
}

// Close all positions
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}

// Check ATR filter
bool CheckATRFilter()
{
   if(!UseATRFilter)
      return true;
   
   double atrValue = GetIndicatorValue(atrHandle, 0, 0);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atrPips = atrValue / (point * 10);
   
   return (atrPips >= MinATRPips && atrPips <= MaxATRPips);
}

// Check Bollinger Bands filter
bool CheckBBFilter()
{
   if(!UseBBFilter)
      return true;
   
   double upperBand = GetIndicatorValue(bbHandle, 1, 0);
   double lowerBand = GetIndicatorValue(bbHandle, 2, 0);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double widthPips = (upperBand - lowerBand) / (point * 10);
   
   return (widthPips >= Min_Width_Pips && widthPips <= Max_Width_Pips);
}

// Check EMA filter
bool CheckEMAFilter(bool isLong)
{
   if(!UseEMAFilter)
      return true;
   
   double emaValue = GetIndicatorValue(emaHandle, 0, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, isLong ? SYMBOL_ASK : SYMBOL_BID);
   
   if(isLong)
      return currentPrice > emaValue;
   else
      return currentPrice < emaValue;
}

// Check ADX filter
bool CheckADXFilter()
{
   if(!UseADXFilter)
      return true;
   
   double adxValue = GetIndicatorValue(adxHandle, 0, 0);
   return adxValue >= MinADX;
}

// Check RSI filter
bool CheckRSIFilter(bool isLong)
{
   if(!UseRSIFilter)
      return true;
   
   double rsiValue = GetIndicatorValue(rsiHandle, 0, 0);
   
   if(isLong)
      return rsiValue < OverboughtLevel;
   else
      return rsiValue > OversoldLevel;
}

// Check Volume filter
bool CheckVolumeFilter()
{
   if(!UseVolumeFilter)
      return true;
   
   double currentVolume = GetIndicatorValue(volumeHandle, 0, 0);
   double volumeSMA = GetIndicatorValue(volumeSMAHandle, 0, 0);
   
   if(volumeSMA == 0)
      return true;
      
   return (currentVolume / volumeSMA) >= VolumeThreshold;
}

// Main filter check function
bool CheckAllFilters(bool isLong)
{
   // Check time filters
   if(!IsTradingTimeAllowed())
      return false;
   
   // Check news filter
   if(!CheckNewsFilter())
      return false;
   
   // Check indicator filters
   if(!CheckATRFilter())
      return false;
      
   if(!CheckBBFilter())
      return false;
      
   if(!CheckEMAFilter(isLong))
      return false;
      
   if(!CheckADXFilter())
      return false;
      
   if(!CheckRSIFilter(isLong))
      return false;
      
   if(!CheckVolumeFilter())
      return false;
   
   return true;
}

// Check breakout with ATR confirmation
bool IsValidBreakoutLong(double breakoutLevel, double rangeHigh, double rangeLow)
{
   if(!UseATRFilter)
      return true;
   
   double atrValue = GetIndicatorValue(atrHandle, 0, 0);
   double breakoutDistance = breakoutLevel - rangeHigh;
   double atrMultiplier = breakoutDistance / atrValue;
   
   return (atrMultiplier >= ATR_Mult_Min && atrMultiplier <= ATR_Mult_Max);
}

bool IsValidBreakoutShort(double breakoutLevel, double rangeHigh, double rangeLow)
{
   if(!UseATRFilter)
      return true;
   
   double atrValue = GetIndicatorValue(atrHandle, 0, 0);
   double breakoutDistance = rangeLow - breakoutLevel;
   double atrMultiplier = breakoutDistance / atrValue;
   
   return (atrMultiplier >= ATR_Mult_Min && atrMultiplier <= ATR_Mult_Max);
}

// Clean up indicators
void DeinitIndicators()
{
   if(atrHandle != INVALID_HANDLE)
      IndicatorRelease(atrHandle);
   if(bbHandle != INVALID_HANDLE)
      IndicatorRelease(bbHandle);
   if(emaHandle != INVALID_HANDLE)
      IndicatorRelease(emaHandle);
   if(adxHandle != INVALID_HANDLE)
      IndicatorRelease(adxHandle);
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
   if(volumeHandle != INVALID_HANDLE)
      IndicatorRelease(volumeHandle);
   if(volumeSMAHandle != INVALID_HANDLE)
      IndicatorRelease(volumeSMAHandle);
}

// Trade object for position management
CTrade trade;

// Main initialization function
int OnInit()
{
   if(!InitIndicators())
   {
      Print("Failed to initialize indicators");
      return INIT_FAILED;
   }
   
   // Initialize news check
   lastNewsCheck = TimeGMT();
   
   return INIT_SUCCEEDED;
}

// Main deinitialization function
void OnDeinit(const int reason)
{
   DeinitIndicators();
}

// Example usage in OnTick
void OnTick()
{
   // Check for new bar
   if(IsNewBar(PERIOD_CURRENT))
   {
      // Your trading logic here
      // Example:
      bool longSignal = YourLongSignalCondition();
      bool shortSignal = YourShortSignalCondition();
      
      if(longSignal && CheckAllFilters(true))
      {
         // Execute long trade
      }
      else if(shortSignal && CheckAllFilters(false))
      {
         // Execute short trade
      }
   }
   
   // Check for weekend closing
   if(CloseBeforeWeekend)
   {
      MqlDateTime timeStruct;
      TimeGMT(timeStruct);
      
      if(timeStruct.day_of_week == WeekendCloseDay && timeStruct.hour == WeekendCloseHour - 1 && timeStruct.min == 55)
      {
         CloseAllPositions();
      }
   }
}

// Replace these with your actual signal conditions
bool YourLongSignalCondition() { return false; }
bool YourShortSignalCondition() { return false; }