#property copyright "Copyright 2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Indicators/Trend.mqh>
#include <Arrays/ArrayObj.mqh>

// Input parameters - Breakout
input int      BreakoutType = 0;           // 0=Range, 1=BollingerBands, 2=ATR
input bool     AllowLong = true;           // Autoriser les positions long
input bool     AllowShort = true;          // Autoriser les positions short
input bool     RequireVolumeConfirm = true;// Exiger confirmation du volume
input bool     RequireRetest = false;      // Attendre un retest avant entrée
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1; // Timeframe pour le calcul du range
input int      TrendFilterEMA = 200;       // Période EMA pour filtre de tendance (0=désactivé)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15; // Timeframe pour l'exécution des trades

// Input parameters - News filter
input bool     UseNewsFilter = true;       // Activer le filtre d'actualités économiques
input int      NewsMinutesBefore = 60;     // Minutes avant la news pour suspendre le trading
input int      NewsMinutesAfter = 30;      // Minutes après la news pour reprendre le trading
input int      NewsImpactLevel = 3;        // Niveau d'impact minimum : 1=faible, 2=moyen, 3=fort
input bool     CloseOnHighImpact = true;   // Fermer les positions avant news à fort impact

// Input parameters - Indicator filters
input bool     UseATRFilter = true;        // Activer le filtre ATR
input int      ATRPeriod = 14;             // Période ATR
input double   MinATRPips = 20;            // ATR minimum requis (pips)
input double   MaxATRPips = 150;           // ATR maximum autorisé (pips)
input double   ATR_Mult_Min = 1.25;        // Multiplicateur ATR minimum pour valider un breakout
input double   ATR_Mult_Max = 3.0;         // Multiplicateur ATR maximum
input bool     UseBBFilter = true;         // Activer le filtre Bollinger Bands
input int      BBPeriod = 20;              // Période Bollinger Bands
input double   BBDeviation = 2.0;          // Déviation standard BB
input double   Min_Width_Pips = 30;        // Largeur BB minimum (pips)
input double   Max_Width_Pips = 120;       // Largeur BB maximum (pips)
input bool     UseEMAFilter = true;        // Activer le filtre EMA
input int      EMAPeriod = 200;            // Période EMA pour filtre de tendance
input ENUM_TIMEFRAMES EMATf = PERIOD_H1;   // Timeframe EMA
input bool     UseADXFilter = true;        // Activer le filtre ADX
input int      ADXPeriod = 14;             // Période ADX
input double   ADXThreshold = 20.0;        // Seuil ADX minimum
input bool     UseRSIFilter = false;       // Activer le filtre RSI
input int      RSIPeriod = 14;             // Période RSI
input double   RSIOverbought = 70;         // Niveau surachat RSI (ne pas acheter au-dessus)
input double   RSIOversold = 30;           // Niveau survente RSI (ne pas vendre en dessous)
input bool     UseVolumeFilter = true;     // Activer le filtre volume
input int      VolumeSMAPeriod = 20;       // Période SMA volume
input double   VolumeThreshold = 1.5;      // Seuil volume (>1.5x moyenne)

// Input parameters - Trading
input double   LotSize = 0.01;             // Taille du lot (0 pour auto)
input double   RiskPercent = 2.0;          // Pourcentage de risque (si LotSize=0)
input double   StopLossPips = 50;          // Stop loss en pips
input double   TakeProfitPips = 100;       // Take profit en pips
input int      MaxPositions = 1;           // Nombre maximum de positions simultanées
input int      MagicNumber = 12345;        // Numéro magique
input string   TradeComment = "RangeBreakout"; // Commentaire des trades

// Global variables
CTrade trade;
CSymbolInfo symbolInfo;
datetime lastBarTime = 0;
int emaHandle = INVALID_HANDLE;
int atrHandle = INVALID_HANDLE;
int bbHandle = INVALID_HANDLE;
int adxHandle = INVALID_HANDLE;
int rsiHandle = INVALID_HANDLE;
int volumeSMAHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   
   if(!symbolInfo.Name(_Symbol))
      return INIT_FAILED;
   
   // Initialize indicator handles
   if(UseEMAFilter && TrendFilterEMA > 0)
   {
      emaHandle = iMA(_Symbol, EMATf, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(emaHandle == INVALID_HANDLE)
         Print("Failed to create EMA indicator");
   }
   
   if(UseATRFilter)
   {
      atrHandle = iATR(_Symbol, RangeTF, ATRPeriod);
      if(atrHandle == INVALID_HANDLE)
         Print("Failed to create ATR indicator");
   }
   
   if(UseBBFilter)
   {
      bbHandle = iBands(_Symbol, RangeTF, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
      if(bbHandle == INVALID_HANDLE)
         Print("Failed to create Bollinger Bands indicator");
   }
   
   if(UseADXFilter)
   {
      adxHandle = iADX(_Symbol, RangeTF, ADXPeriod);
      if(adxHandle == INVALID_HANDLE)
         Print("Failed to create ADX indicator");
   }
   
   if(UseRSIFilter)
   {
      rsiHandle = iRSI(_Symbol, RangeTF, RSIPeriod, PRICE_CLOSE);
      if(rsiHandle == INVALID_HANDLE)
         Print("Failed to create RSI indicator");
   }
   
   if(UseVolumeFilter)
   {
      volumeSMAHandle = iMA(_Symbol, PERIOD_CURRENT, VolumeSMAPeriod, 0, MODE_SMA, VOLUME_TICK);
      if(volumeSMAHandle == INVALID_HANDLE)
         Print("Failed to create Volume SMA indicator");
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
//| Breakout entry functions                                         |
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
//| Calculate lot size                                               |
//+------------------------------------------------------------------+
double CalcLotSize()
{
   if(LotSize > 0) return LotSize;
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * RiskPercent / 100.0;
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double stopLossPoints = StopLossPips * 10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(stopLossPoints == 0 || tickValue == 0) return 0.01;
   
   double lotSize = riskAmount / (stopLossPoints * tickValue);
   lotSize = NormalizeDouble(lotSize, 2);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Check if news filter blocks trading                              |
//+------------------------------------------------------------------+
bool IsNewsBlocking()
{
   if(!UseNewsFilter) return false;
   
   // This is a simplified implementation
   // In real implementation, you would integrate with FFCal or another news source
   // For now, return false to allow trading
   return false;
}

//+------------------------------------------------------------------+
//| Close positions before high impact news                          |
//+------------------------------------------------------------------+
void ClosePositionsBeforeNews()
{
   if(!CloseOnHighImpact || !UseNewsFilter) return;
   
   // Check if high impact news is approaching
   bool highImpactNewsApproaching = false; // Simplified
   
   if(highImpactNewsApproaching)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            trade.PositionClose(PositionGetTicket(i));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get indicator value                                              |
//+------------------------------------------------------------------+
double GetIndicatorValue(int handle, int buffer, int shift)
{
   double value[];
   ArraySetAsSeries(value, true);
   
   if(CopyBuffer(handle, buffer, shift, 1, value) <= 0)
      return 0;
      
   return value[0];
}

//+------------------------------------------------------------------+
//| Check EMA trend filter                                           |
//+------------------------------------------------------------------+
bool CheckEMATrendFilter(bool isLong)
{
   if(!UseEMAFilter || emaHandle == INVALID_HANDLE) return true;
   
   double emaValue = GetIndicatorValue(emaHandle, 0, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(isLong)
      return currentPrice > emaValue;
   else
      return currentPrice < emaValue;
}

//+------------------------------------------------------------------+
//| Check ATR filter                                                 |
//+------------------------------------------------------------------+
bool CheckATRFilter(double breakoutLevel, bool isLong)
{
   if(!UseATRFilter || atrHandle == INVALID_HANDLE) return true;
   
   double atrValue = GetIndicatorValue(atrHandle, 0, 0);
   double currentPrice = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double distance = MathAbs(currentPrice - breakoutLevel);
   
   double minATR = MinATRPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   double maxATR = MaxATRPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   
   // Check ATR range
   if(atrValue < minATR || atrValue > maxATR) return false;
   
   // Check breakout distance vs ATR
   double atrMultiplier = distance / atrValue;
   return (atrMultiplier >= ATR_Mult_Min && atrMultiplier <= ATR_Mult_Max);
}

//+------------------------------------------------------------------+
//| Check Bollinger Bands filter                                     |
//+------------------------------------------------------------------+
bool CheckBBFilter()
{
   if(!UseBBFilter || bbHandle == INVALID_HANDLE) return true;
   
   double upperBand = GetIndicatorValue(bbHandle, 1, 0);
   double lowerBand = GetIndicatorValue(bbHandle, 2, 0);
   double bandWidth = upperBand - lowerBand;
   
   double minWidth = Min_Width_Pips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   double maxWidth = Max_Width_Pips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
   
   return (bandWidth >= minWidth && bandWidth <= maxWidth);
}

//+------------------------------------------------------------------+
//| Check ADX filter                                                 |
//+------------------------------------------------------------------+
bool CheckADXFilter()
{
   if(!UseADXFilter || adxHandle == INVALID_HANDLE) return true;
   
   double adxValue = GetIndicatorValue(adxHandle, 0, 0);
   return adxValue >= ADXThreshold;
}

//+------------------------------------------------------------------+
//| Check RSI filter                                                 |
//+------------------------------------------------------------------+
bool CheckRSIFilter(bool isLong)
{
   if(!UseRSIFilter || rsiHandle == INVALID_HANDLE) return true;
   
   double rsiValue = GetIndicatorValue(rsiHandle, 0, 0);
   
   if(isLong)
      return rsiValue < RSIOverbought;
   else
      return rsiValue > RSIOversold;
}

//+------------------------------------------------------------------+
//| Check volume confirmation                                        |
//+------------------------------------------------------------------+
bool CheckVolumeConfirmation()
{
   if(!RequireVolumeConfirm || !UseVolumeFilter || volumeSMAHandle == INVALID_HANDLE) return true;
   
   double currentVolume = iVolume(_Symbol, PERIOD_CURRENT, 0);
   double volumeSMA = GetIndicatorValue(volumeSMAHandle, 0, 0);
   
   if(volumeSMA == 0) return true;
   
   return (currentVolume / volumeSMA) >= VolumeThreshold;
}

//+------------------------------------------------------------------+
//| Calculate range levels                                           |
//+------------------------------------------------------------------+
void CalculateRangeLevels(double &highLevel, double &lowLevel)
{
   highLevel = iHigh(_Symbol, RangeTF, 1);
   lowLevel = iLow(_Symbol, RangeTF, 1);
}

//+------------------------------------------------------------------+
//| Check for breakout signals                                       |
//+------------------------------------------------------------------+
void CheckBreakoutSignals()
{
   // Check if we can open new positions
   if(PositionsTotal() >= MaxPositions) return;
   if(IsNewsBlocking()) return;
   
   // Calculate range levels
   double rangeHigh, rangeLow;
   CalculateRangeLevels(rangeHigh, rangeLow);
   
   // Check long breakout
   if(AllowLong && IsBreakoutLong(rangeHigh))
   {
      if(RequireRetest && !IsRetestLong(rangeHigh)) return;
      
      // Apply all filters
      if(!CheckEMATrendFilter(true)) return;
      if(!CheckATRFilter(rangeHigh, true)) return;
      if(!CheckBBFilter()) return;
      if(!CheckADXFilter()) return;
      if(!CheckRSIFilter(true)) return;
      if(!CheckVolumeConfirmation()) return;
      
      // Calculate trade parameters
      double lotSize = CalcLotSize();
      double sl = rangeLow - StopLossPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
      double tp = rangeHigh + TakeProfitPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
      
      // Open buy position
      trade.Buy(lotSize, _Symbol, 0, sl, tp, TradeComment);
   }
   
   // Check short breakout
   if(AllowShort && IsBreakoutShort(rangeLow))
   {
      if(RequireRetest && !IsRetestShort(rangeLow)) return;
      
      // Apply all filters
      if(!CheckEMATrendFilter(false)) return;
      if(!CheckATRFilter(rangeLow, false)) return;
      if(!CheckBBFilter()) return;
      if(!CheckADXFilter()) return;
      if(!CheckRSIFilter(false)) return;
      if(!CheckVolumeConfirmation()) return;
      
      // Calculate trade parameters
      double lotSize = CalcLotSize();
      double sl = rangeHigh + StopLossPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
      double tp = rangeLow - TakeProfitPips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
      
      // Open sell position
      trade.Sell(lotSize, _Symbol, 0, sl, tp, TradeComment);
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Update symbol info
   symbolInfo.RefreshRates();
   
   // Check for new bar on execution timeframe
   if(IsNewBar(ExecTF))
   {
      // Close positions before high impact news
      ClosePositionsBeforeNews();
      
      // Check for breakout signals
      CheckBreakoutSignals();
   }
}

//+------------------------------------------------------------------+
