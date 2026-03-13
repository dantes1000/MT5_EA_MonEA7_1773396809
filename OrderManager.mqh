#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| OrderManager.mqh - Handles pending order placement, slippage control, retries, and magic number assignment |
//+------------------------------------------------------------------+

// Input parameters
input bool     AllowLong = true;                // Allow long positions
input bool     AllowShort = true;               // Allow short positions
input bool     RequireVolumeConfirm = true;     // Require volume confirmation
input bool     RequireRetest = false;           // Wait for retest before entry
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1;      // Timeframe for range calculation
input int      TrendFilterEMA = 200;            // EMA period for trend filter (0=disabled)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15;      // Timeframe for trade execution
input bool     UseNewsFilter = true;            // Enable economic news filter
input int      NewsMinutesBefore = 60;          // Minutes before news to suspend trading
input int      NewsMinutesAfter = 30;           // Minutes after news to resume trading
input int      NewsImpactLevel = 3;             // Minimum impact level: 1=low, 2=medium, 3=high
input bool     CloseOnHighImpact = true;        // Close positions before high impact news
input bool     UseATRFilter = true;             // Enable ATR filter
input int      ATRPeriod = 14;                  // ATR period
input double   MinATRPips = 20;                 // Minimum ATR required (pips)
input double   MaxATRPips = 150;                // Maximum ATR allowed (pips)
input double   ATR_Mult_Min = 1.25;             // Minimum ATR multiplier for breakout validation
input double   ATR_Mult_Max = 3.0;              // Maximum ATR multiplier
input bool     UseBBFilter = true;              // Enable Bollinger Bands filter
input int      BBPeriod = 20;                   // Bollinger Bands period
input double   BBDeviation = 2.0;               // Bollinger Bands standard deviation
input double   Min_Width_Pips = 30;             // Minimum BB width (pips)
input double   LotSize = 0.1;                   // Fixed lot size (use 0 for auto calculation)
input double   RiskPercent = 2.0;               // Risk percentage for auto lot calculation
input int      MaxSlippage = 3;                 // Maximum slippage in points
input int      MaxRetries = 3;                  // Maximum order placement retries
input int      RetryDelay = 100;                // Delay between retries in milliseconds
input int      MagicNumber = 12345;             // Magic number for order identification
input string   OrderComment = "Breakout Order"; // Order comment

// Global variables
int            atrHandle = INVALID_HANDLE;
int            bbHandle = INVALID_HANDLE;
int            emaHandle = INVALID_HANDLE;
int            volumeHandle = INVALID_HANDLE;
datetime       lastBarTime = 0;

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
bool IsRetestLong(double level, double tolerancePips = 5)
{
   double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol     = tolerancePips * point * 10;
   double lowBar  = iLow(_Symbol, PERIOD_CURRENT, 1);
   double closeBar = iClose(_Symbol, PERIOD_CURRENT, 1);
   return (lowBar <= level + tol && closeBar > level);
}

bool IsRetestShort(double level, double tolerancePips = 5)
{
   double point    = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol      = tolerancePips * point * 10;
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
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(tickValue == 0 || point == 0) return 0.01;
   
   double riskAmount = accountBalance * RiskPercent / 100;
   double stopLossPips = 50; // Default stop loss in pips
   double lotSize = riskAmount / (stopLossPips * 10 * point * tickValue);
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed by news filter                       |
//+------------------------------------------------------------------+
bool IsTradingAllowedByNews()
{
   if(!UseNewsFilter) return true;
   
   // Check FFCal indicator for upcoming news
   // This is a simplified implementation - in reality you would need to integrate with FFCal
   // or use a custom news feed
   
   // For demonstration, we'll assume trading is always allowed
   // In a real implementation, you would check the FFCal indicator values
   
   return true;
}

//+------------------------------------------------------------------+
//| Check trend filter                                               |
//+------------------------------------------------------------------+
bool CheckTrendFilter(bool isLong)
{
   if(TrendFilterEMA <= 0) return true;
   
   if(emaHandle == INVALID_HANDLE)
      emaHandle = iMA(_Symbol, PERIOD_H1, TrendFilterEMA, 0, MODE_EMA, PRICE_CLOSE);
   
   if(emaHandle == INVALID_HANDLE) return false;
   
   double emaValue[1];
   if(CopyBuffer(emaHandle, 0, 0, 1, emaValue) <= 0) return false;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(isLong)
      return currentPrice > emaValue[0];
   else
      return currentPrice < emaValue[0];
}

//+------------------------------------------------------------------+
//| Check ATR filter                                                 |
//+------------------------------------------------------------------+
bool CheckATRFilter(double breakoutLevel, bool isLong)
{
   if(!UseATRFilter) return true;
   
   if(atrHandle == INVALID_HANDLE)
      atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   
   if(atrHandle == INVALID_HANDLE) return false;
   
   double atrValue[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrValue) <= 0) return false;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atrPips = atrValue[0] / (point * 10);
   
   // Check ATR range
   if(atrPips < MinATRPips || atrPips > MaxATRPips) return false;
   
   // Check breakout distance vs ATR
   double currentPrice = isLong ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double distancePips = MathAbs(currentPrice - breakoutLevel) / (point * 10);
   double atrMultiplier = distancePips / atrPips;
   
   return (atrMultiplier >= ATR_Mult_Min && atrMultiplier <= ATR_Mult_Max);
}

//+------------------------------------------------------------------+
//| Check Bollinger Bands filter                                     |
//+------------------------------------------------------------------+
bool CheckBBFilter()
{
   if(!UseBBFilter) return true;
   
   if(bbHandle == INVALID_HANDLE)
      bbHandle = iBands(_Symbol, PERIOD_CURRENT, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
   
   if(bbHandle == INVALID_HANDLE) return false;
   
   double upperBand[1], lowerBand[1];
   if(CopyBuffer(bbHandle, 1, 0, 1, upperBand) <= 0) return false;
   if(CopyBuffer(bbHandle, 2, 0, 1, lowerBand) <= 0) return false;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double widthPips = (upperBand[0] - lowerBand[0]) / (point * 10);
   
   return widthPips >= Min_Width_Pips;
}

//+------------------------------------------------------------------+
//| Check volume confirmation                                        |
//+------------------------------------------------------------------+
bool CheckVolumeConfirm()
{
   if(!RequireVolumeConfirm) return true;
   
   if(volumeHandle == INVALID_HANDLE)
      volumeHandle = iVolumes(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
   
   if(volumeHandle == INVALID_HANDLE) return false;
   
   double currentVolume[1], smaVolume[20];
   if(CopyBuffer(volumeHandle, 0, 0, 1, currentVolume) <= 0) return false;
   if(CopyBuffer(volumeHandle, 0, 1, 20, smaVolume) <= 0) return false;
   
   // Calculate SMA of volume
   double sum = 0;
   for(int i = 0; i < 20; i++)
      sum += smaVolume[i];
   double volumeSMA = sum / 20;
   
   return currentVolume[0] > volumeSMA * 1.5;
}

//+------------------------------------------------------------------+
//| Place pending order with retries and slippage control            |
//+------------------------------------------------------------------+
bool PlacePendingOrder(ENUM_ORDER_TYPE orderType, double price, double stopLoss, double takeProfit, double lotSize)
{
   if(!IsTradingAllowedByNews()) return false;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = orderType;
   request.price = price;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = MaxSlippage;
   request.magic = MagicNumber;
   request.comment = OrderComment;
   
   for(int attempt = 0; attempt < MaxRetries; attempt++)
   {
      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE)
            return true;
      }
      
      Sleep(RetryDelay);
      
      // Refresh price for next attempt
      if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP)
         request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      else
         request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Place breakout order                                             |
//+------------------------------------------------------------------+
bool PlaceBreakoutOrder(bool isLong, double breakoutLevel, double atrValue)
{
   if(!IsTradingAllowedByNews()) return false;
   
   // Check basic permissions
   if((isLong && !AllowLong) || (!isLong && !AllowShort)) return false;
   
   // Check trend filter
   if(!CheckTrendFilter(isLong)) return false;
   
   // Check ATR filter
   if(!CheckATRFilter(breakoutLevel, isLong)) return false;
   
   // Check BB filter
   if(!CheckBBFilter()) return false;
   
   // Check volume confirmation
   if(!CheckVolumeConfirm()) return false;
   
   // Check retest if required
   if(RequireRetest)
   {
      if(isLong)
      {
         if(!IsRetestLong(breakoutLevel)) return false;
      }
      else
      {
         if(!IsRetestShort(breakoutLevel)) return false;
      }
   }
   
   // Calculate lot size
   double lotSize = CalcLotSize();
   if(lotSize <= 0) return false;
   
   // Calculate stop loss and take profit based on ATR
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopLossDistance = atrValue * 1.5;
   double takeProfitDistance = atrValue * 2.0;
   
   double price, stopLoss, takeProfit;
   ENUM_ORDER_TYPE orderType;
   
   if(isLong)
   {
      orderType = ORDER_TYPE_BUY_STOP;
      price = breakoutLevel;
      stopLoss = price - stopLossDistance;
      takeProfit = price + takeProfitDistance;
   }
   else
   {
      orderType = ORDER_TYPE_SELL_STOP;
      price = breakoutLevel;
      stopLoss = price + stopLossDistance;
      takeProfit = price - takeProfitDistance;
   }
   
   // Place the order
   return PlacePendingOrder(orderType, price, stopLoss, takeProfit, lotSize);
}

//+------------------------------------------------------------------+
//| Close all positions before high impact news                      |
//+------------------------------------------------------------------+
void ClosePositionsBeforeNews()
{
   if(!CloseOnHighImpact || !UseNewsFilter) return;
   
   // Check if high impact news is coming soon
   // This would integrate with FFCal indicator
   // For now, we'll close all positions with our magic number
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_DEAL;
         request.symbol = _Symbol;
         request.volume = PositionGetDouble(POSITION_VOLUME);
         request.position = PositionGetTicket(i);
         request.deviation = MaxSlippage;
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            request.type = ORDER_TYPE_SELL;
            request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         }
         else
         {
            request.type = ORDER_TYPE_BUY;
            request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         }
         
         OrderSend(request, result);
      }
   }
}

//+------------------------------------------------------------------+
//| Clean up indicator handles                                       |
//+------------------------------------------------------------------+
void CleanupHandles()
{
   if(atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(atrHandle);
      atrHandle = INVALID_HANDLE;
   }
   
   if(bbHandle != INVALID_HANDLE)
   {
      IndicatorRelease(bbHandle);
      bbHandle = INVALID_HANDLE;
   }
   
   if(emaHandle != INVALID_HANDLE)
   {
      IndicatorRelease(emaHandle);
      emaHandle = INVALID_HANDLE;
   }
   
   if(volumeHandle != INVALID_HANDLE)
   {
      IndicatorRelease(volumeHandle);
      volumeHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Initialize OrderManager                                          |
//+------------------------------------------------------------------+
void OrderManagerInit()
{
   // Initialize indicator handles
   if(UseATRFilter)
      atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATRPeriod);
   
   if(UseBBFilter)
      bbHandle = iBands(_Symbol, PERIOD_CURRENT, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
   
   if(TrendFilterEMA > 0)
      emaHandle = iMA(_Symbol, PERIOD_H1, TrendFilterEMA, 0, MODE_EMA, PRICE_CLOSE);
   
   if(RequireVolumeConfirm)
      volumeHandle = iVolumes(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
}

//+------------------------------------------------------------------+
//| Deinitialize OrderManager                                        |
//+------------------------------------------------------------------+
void OrderManagerDeinit()
{
   CleanupHandles();
}
