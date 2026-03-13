#property strict

//+------------------------------------------------------------------+
//| IndicatorFilters.mqh - Manages ATR, Bollinger Bands, RSI, and volume filters |
//+------------------------------------------------------------------+

// Input parameters
input int BreakoutType = 0;               // 0=Range, 1=BollingerBands, 2=ATR
input bool AllowLong = true;              // Autoriser les positions long
input bool AllowShort = true;             // Autoriser les positions short
input bool RequireVolumeConfirm = true;   // Exiger confirmation du volume
input bool RequireRetest = false;         // Attendre un retest avant entrée
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1; // Timeframe pour le calcul du range
input int TrendFilterEMA = 200;           // Période EMA pour filtre de tendance (0=désactivé)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15; // Timeframe pour l'exécution des trades
input bool UseNewsFilter = true;          // Activer le filtre d'actualités économiques
input int NewsMinutesBefore = 60;         // Minutes avant la news pour suspendre le trading
input int NewsMinutesAfter = 30;          // Minutes après la news pour reprendre le trading
input int NewsImpactLevel = 3;            // Niveau d'impact minimum : 1=faible, 2=moyen, 3=fort
input bool CloseOnHighImpact = true;      // Fermer les positions avant news à fort impact
input bool UseATRFilter = true;           // Activer le filtre ATR
input int ATRPeriod = 14;                 // Période ATR
input double MinATRPips = 20;             // ATR minimum requis (pips)
input double MaxATRPips = 150;            // ATR maximum autorisé (pips)
input double ATR_Mult_Min = 1.25;         // Multiplicateur ATR minimum pour valider un breakout
input double ATR_Mult_Max = 3.0;          // Multiplicateur ATR maximum
input bool UseBBFilter = true;            // Activer le filtre Bollinger Bands
input int BBPeriod = 20;                  // Période Bollinger Bands
input double BBDeviation = 2.0;           // Déviation standard BB
input double Min_Width_Pips = 30;         // Largeur BB minimum (pips)
input double Max_Width_Pips = 120;        // Largeur BB maximum (pips)
input bool UseEMAFilter = true;           // Activer le filtre EMA
input int EMAPeriod = 200;                // Période EMA pour filtre de tendance
input ENUM_TIMEFRAMES EMATf = PERIOD_H1;  // Timeframe EMA
input bool UseADXFilter = true;           // Activer le filtre ADX
input int ADXPeriod = 14;                 // Période ADX
input double ADXThreshold = 20.0;         // Seuil ADX minimum
input bool UseRSIFilter = false;          // Activer le filtre RSI
input int RSIPeriod = 14;                 // Période RSI
input double RSIOverbought = 70;          // Niveau surachat RSI (ne pas acheter au-dessus)
input double RSIOversold = 30;            // Niveau survente RSI (ne pas vendre en dessous)
input bool UseVolumeFilter = true;        // Activer le filtre de volume
input int VolumePeriod = 20;              // Période moyenne de volume
input double VolumeMultiplier = 1.5;      // Multiplicateur volume minimum
input int Vol_Confirm_Type = 1;           // 0=Tick, 1=Réel
input int MagicNumber = 123456;           // Identifiant unique des ordres de l'EA
input string OrderComment = "RangeBreakEA"; // Commentaire sur les ordres
input int MaxSlippage = 3;                // Slippage maximum autorisé (points)

// Global variables
int atrHandle = INVALID_HANDLE;
int bbHandle = INVALID_HANDLE;
int emaHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int volumeHandle = INVALID_HANDLE;
double point;

//+------------------------------------------------------------------+
//| Initialization function                                          |
//+------------------------------------------------------------------+
bool IndicatorFiltersInit()
{
   point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Create indicator handles
   if(UseATRFilter)
   {
      atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
      if(atrHandle == INVALID_HANDLE)
      {
         Print("Failed to create ATR indicator");
         return false;
      }
   }
   
   if(UseBBFilter)
   {
      bbHandle = iBands(_Symbol, PERIOD_CURRENT, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
      if(bbHandle == INVALID_HANDLE)
      {
         Print("Failed to create Bollinger Bands indicator");
         return false;
      }
   }
   
   if(UseEMAFilter && TrendFilterEMA > 0)
   {
      emaHandle = iMA(_Symbol, EMATf, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(emaHandle == INVALID_HANDLE)
      {
         Print("Failed to create EMA indicator");
         return false;
      }
   }
   
   if(UseADXFilter)
   {
      adxHandle = iADX(_Symbol, PERIOD_CURRENT, ADXPeriod);
      if(adxHandle == INVALID_HANDLE)
      {
         Print("Failed to create ADX indicator");
         return false;
      }
   }
   
   if(UseRSIFilter)
   {
      rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
      if(rsiHandle == INVALID_HANDLE)
      {
         Print("Failed to create RSI indicator");
         return false;
      }
   }
   
   if(UseVolumeFilter)
   {
      volumeHandle = iVolumes(_Symbol, PERIOD_CURRENT, Vol_Confirm_Type == 0 ? VOLUME_TICK : VOLUME_REAL);
      if(volumeHandle == INVALID_HANDLE)
      {
         Print("Failed to create Volume indicator");
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void IndicatorFiltersDeinit()
{
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(bbHandle != INVALID_HANDLE) IndicatorRelease(bbHandle);
   if(emaHandle != INVALID_HANDLE) IndicatorRelease(emaHandle);
   if(adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(volumeHandle != INVALID_HANDLE) IndicatorRelease(volumeHandle);
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
//| Breakout entry functions                                         |
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
   double tol = 5 * point * 10; // Default 5 pips tolerance
   double lowBar = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

bool IsRetestShort(double level)
{
   double tol = 5 * point * 10; // Default 5 pips tolerance
   double highBar = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (highBar >= level - tol && closeBar < level);
}

//+------------------------------------------------------------------+
//| Get indicator value helper                                       |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double value[1];
   if(CopyBuffer(handle, buffer, shift, 1, value) <= 0)
      return 0.0;
   return value[0];
}

//+------------------------------------------------------------------+
//| ATR Filter                                                       |
//+------------------------------------------------------------------+
bool CheckATRFilter()
{
   if(!UseATRFilter) return true;
   
   double atrValue = GetIndicatorValue(atrHandle, 0, 0);
   double atrPips = atrValue / point;
   
   // Check ATR range
   if(atrPips < MinATRPips || atrPips > MaxATRPips)
      return false;
   
   // Calculate breakout levels based on ATR multiplier
   double high = iHigh(_Symbol, RangeTF, 1);
   double low = iLow(_Symbol, RangeTF, 1);
   double range = high - low;
   
   double atrMultiplier = range / atrValue;
   if(atrMultiplier < ATR_Mult_Min || atrMultiplier > ATR_Mult_Max)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Bollinger Bands Filter                                           |
//+------------------------------------------------------------------+
bool CheckBBFilter()
{
   if(!UseBBFilter) return true;
   
   double upperBand = GetIndicatorValue(bbHandle, 1, 0);
   double lowerBand = GetIndicatorValue(bbHandle, 2, 0);
   
   double bbWidth = upperBand - lowerBand;
   double bbWidthPips = bbWidth / point;
   
   // Check BB width range
   if(bbWidthPips < Min_Width_Pips || bbWidthPips > Max_Width_Pips)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| EMA Filter                                                       |
//+------------------------------------------------------------------+
bool CheckEMAFilter()
{
   if(!UseEMAFilter || TrendFilterEMA == 0) return true;
   
   double emaValue = GetIndicatorValue(emaHandle, 0, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // For long positions, price should be above EMA
   // For short positions, price should be below EMA
   // This is a simple trend filter
   return true; // Always pass for now, implement specific logic as needed
}

//+------------------------------------------------------------------+
//| ADX Filter                                                       |
//+------------------------------------------------------------------+
bool CheckADXFilter()
{
   if(!UseADXFilter) return true;
   
   double adxValue = GetIndicatorValue(adxHandle, 0, 0);
   
   // Check if ADX is above threshold (indicating trend strength)
   if(adxValue < ADXThreshold)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| RSI Filter                                                       |
//+------------------------------------------------------------------+
bool CheckRSIFilter()
{
   if(!UseRSIFilter) return true;
   
   double rsiValue = GetIndicatorValue(rsiHandle, 0, 0);
   
   // For long positions, RSI should not be overbought
   // For short positions, RSI should not be oversold
   // This check is done separately for long/short signals
   return true; // Always pass for now, implement specific logic as needed
}

//+------------------------------------------------------------------+
//| Volume Filter                                                    |
//+------------------------------------------------------------------+
bool CheckVolumeFilter()
{
   if(!UseVolumeFilter || !RequireVolumeConfirm) return true;
   
   double currentVolume = GetIndicatorValue(volumeHandle, 0, 0);
   
   // Calculate average volume
   double sumVolume = 0;
   for(int i = 1; i <= VolumePeriod; i++)
   {
      sumVolume += GetIndicatorValue(volumeHandle, 0, i);
   }
   double avgVolume = sumVolume / VolumePeriod;
   
   // Check if current volume is above threshold
   if(currentVolume < avgVolume * VolumeMultiplier)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| News Filter                                                      |
//+------------------------------------------------------------------+
bool CheckNewsFilter()
{
   if(!UseNewsFilter) return true;
   
   // This is a placeholder for news filter logic
   // In a real implementation, you would need to:
   // 1. Connect to an economic calendar service
   // 2. Check for upcoming news events
   // 3. Compare current time with news time
   // 4. Check impact level
   
   // For now, always return true (no news blocking)
   return true;
}

//+------------------------------------------------------------------+
//| Check all filters                                                |
//+------------------------------------------------------------------+
bool CheckAllFilters()
{
   if(!CheckATRFilter()) return false;
   if(!CheckBBFilter()) return false;
   if(!CheckEMAFilter()) return false;
   if(!CheckADXFilter()) return false;
   if(!CheckRSIFilter()) return false;
   if(!CheckVolumeFilter()) return false;
   if(!CheckNewsFilter()) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check RSI levels for specific direction                          |
//+------------------------------------------------------------------+
bool CheckRSIForLong()
{
   if(!UseRSIFilter) return true;
   
   double rsiValue = GetIndicatorValue(rsiHandle, 0, 0);
   return rsiValue < RSIOverbought;
}

bool CheckRSIForShort()
{
   if(!UseRSIFilter) return true;
   
   double rsiValue = GetIndicatorValue(rsiHandle, 0, 0);
   return rsiValue > RSIOversold;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed for specific direction               |
//+------------------------------------------------------------------+
bool CanTradeLong()
{
   if(!AllowLong) return false;
   if(!CheckAllFilters()) return false;
   if(!CheckRSIForLong()) return false;
   return true;
}

bool CanTradeShort()
{
   if(!AllowShort) return false;
   if(!CheckAllFilters()) return false;
   if(!CheckRSIForShort()) return false;
   return true;
}

//+------------------------------------------------------------------+
//| Calculate breakout level based on type                           |
//+------------------------------------------------------------------+
double CalculateBreakoutLevel(bool isLong)
{
   double level = 0;
   
   switch(BreakoutType)
   {
      case 0: // Range
         if(isLong)
            level = iHigh(_Symbol, RangeTF, 1);
         else
            level = iLow(_Symbol, RangeTF, 1);
         break;
         
      case 1: // Bollinger Bands
         if(isLong)
            level = GetIndicatorValue(bbHandle, 1, 0); // Upper band
         else
            level = GetIndicatorValue(bbHandle, 2, 0); // Lower band
         break;
         
      case 2: // ATR
         double atrValue = GetIndicatorValue(atrHandle, 0, 0);
         double currentPrice = isLong ? 
            SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
            SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         if(isLong)
            level = currentPrice + atrValue * ATR_Mult_Min;
         else
            level = currentPrice - atrValue * ATR_Mult_Min;
         break;
   }
   
   return level;
}

//+------------------------------------------------------------------+
//| Main entry signal check                                          |
//+------------------------------------------------------------------+
bool CheckEntrySignal(bool isLong)
{
   if(!IsNewBar(ExecTF)) return false;
   
   double breakoutLevel = CalculateBreakoutLevel(isLong);
   
   if(isLong)
   {
      if(!CanTradeLong()) return false;
      
      if(RequireRetest)
         return IsRetestLong(breakoutLevel);
      else
         return IsBreakoutLong(breakoutLevel);
   }
   else
   {
      if(!CanTradeShort()) return false;
      
      if(RequireRetest)
         return IsRetestShort(breakoutLevel);
      else
         return IsBreakoutShort(breakoutLevel);
   }
}

//+------------------------------------------------------------------+
//| Get current ATR value in pips                                    |
//+------------------------------------------------------------------+
double GetCurrentATRInPips()
{
   if(!UseATRFilter) return 0;
   
   double atrValue = GetIndicatorValue(atrHandle, 0, 0);
   return atrValue / point;
}

//+------------------------------------------------------------------+
//| Get current Bollinger Bands width in pips                        |
//+------------------------------------------------------------------+
double GetCurrentBBWidthInPips()
{
   if(!UseBBFilter) return 0;
   
   double upperBand = GetIndicatorValue(bbHandle, 1, 0);
   double lowerBand = GetIndicatorValue(bbHandle, 2, 0);
   double bbWidth = upperBand - lowerBand;
   return bbWidth / point;
}

//+------------------------------------------------------------------+
//| Get current RSI value                                            |
//+------------------------------------------------------------------+
double GetCurrentRSI()
{
   if(!UseRSIFilter) return 0;
   
   return GetIndicatorValue(rsiHandle, 0, 0);
}

//+------------------------------------------------------------------+
//| Get current volume ratio                                         |
//+------------------------------------------------------------------+
double GetCurrentVolumeRatio()
{
   if(!UseVolumeFilter) return 0;
   
   double currentVolume = GetIndicatorValue(volumeHandle, 0, 0);
   double sumVolume = 0;
   for(int i = 1; i <= VolumePeriod; i++)
   {
      sumVolume += GetIndicatorValue(volumeHandle, 0, i);
   }
   double avgVolume = sumVolume / VolumePeriod;
   
   if(avgVolume == 0) return 0;
   return currentVolume / avgVolume;
}