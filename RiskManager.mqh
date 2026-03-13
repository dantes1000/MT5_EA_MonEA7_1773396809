//+------------------------------------------------------------------+
//| RiskManager.mqh                                                  |
//| Handles position sizing, stop loss, take profit, and partial close|
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
input int      MagicNumber = 123456;           // Magic number
input string   OrderComment = "RangeBreakEA";  // Order comment
input int      MaxSlippage = 3;                // Max slippage (points)
input int      MaxOrderRetries = 3;            // Max order retries
input bool     UsePartialClose = false;        // Enable partial close
input double   PartialCloseRR = 1.0;           // R:R for partial close
input double   PartialClosePct = 50;           // Percentage to close (%)
input bool     AllowAddPosition = false;       // Allow adding to position
input double   AddPositionRR = 1.0;            // Min R:R to add position
input double   RiskPercent = 2.0;              // Risk per trade (%)
input double   FixedLotSize = 0.1;             // Fixed lot size (if >0)
input bool     UseStopLoss = true;             // Use stop loss
input bool     UseTakeProfit = true;           // Use take profit
input double   StopLossPips = 50;              // Stop loss in pips
input double   TakeProfitPips = 100;           // Take profit in pips
input double   RiskRewardRatio = 2.0;          // Risk/Reward ratio
input bool     UseTrailingStop = false;        // Use trailing stop
input double   TrailingStartPips = 20;         // Pips profit to activate
input double   TrailingStepPips = 10;          // Trailing step in pips
input bool     UseBreakEven = false;           // Use breakeven stop
input double   BreakEvenPips = 20;             // Pips profit to move to BE
input double   MaxSpreadPips = 5.0;            // Max spread allowed (pips)
input int      MaxPositions = 1;               // Max simultaneous positions
input bool     HedgeAllowed = false;           // Allow hedge positions

//+------------------------------------------------------------------+
//| Risk manager class                                               |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   double       m_account_balance;
   double       m_account_equity;
   double       m_point;
   double       m_tick_size;
   int          m_digits;
   string       m_symbol;
   
   // Helper functions
   double       NormalizeDoubleCustom(double value, int digits);
   double       PipsToPoints(double pips);
   double       CalculateLotSize(double stop_loss_pips, double risk_percent);
   bool         CheckSpread();
   bool         CheckMaxPositions();
   bool         CheckHedge(int order_type);
   
public:
   // Constructor/destructor
                     CRiskManager();
                    ~CRiskManager();
   
   // Initialization
   bool              Init(string symbol);
   
   // Position sizing
   double            GetLotSize(double stop_loss_pips, double risk_percent = -1);
   
   // Stop loss/take profit calculation
   double            CalculateStopLossPrice(int order_type, double entry_price, double stop_loss_pips);
   double            CalculateTakeProfitPrice(int order_type, double entry_price, double take_profit_pips);
   
   // Order validation
   bool              ValidateOrder(int order_type, double lot_size, double stop_loss, double take_profit);
   
   // Position management
   bool              CheckPartialClose(long ticket);
   bool              CheckAddPosition(long ticket);
   bool              CheckTrailingStop(long ticket);
   bool              CheckBreakEven(long ticket);
   
   // Risk checks
   bool              IsTradingAllowed();
   double            GetCurrentRisk();
   
   // Utility functions
   double            GetOrderProfitPips(long ticket);
   double            GetOrderRiskReward(long ticket);
   bool              ModifyOrder(long ticket, double stop_loss, double take_profit);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager()
{
   m_symbol = _Symbol;
   m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   m_account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   m_account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager()
{
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
bool CRiskManager::Init(string symbol)
{
   m_symbol = symbol;
   m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_tick_size = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
   m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   
   if(m_point == 0 || m_tick_size == 0)
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Custom normalization                                             |
//+------------------------------------------------------------------+
double CRiskManager::NormalizeDoubleCustom(double value, int digits)
{
   return NormalizeDouble(value, digits);
}

//+------------------------------------------------------------------+
//| Convert pips to points                                           |
//+------------------------------------------------------------------+
double CRiskManager::PipsToPoints(double pips)
{
   return pips * 10 * m_point;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(double stop_loss_pips, double risk_percent)
{
   if(FixedLotSize > 0)
      return FixedLotSize;
      
   if(risk_percent <= 0)
      risk_percent = RiskPercent;
      
   if(stop_loss_pips <= 0 || risk_percent <= 0)
      return 0.01;
      
   double risk_amount = m_account_balance * risk_percent / 100.0;
   double stop_loss_points = PipsToPoints(stop_loss_pips);
   double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(stop_loss_points == 0 || tick_value == 0)
      return 0.01;
      
   double lot_size = risk_amount / (stop_loss_points / m_point * tick_value);
   
   // Normalize to broker requirements
   double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
   
   lot_size = MathMax(lot_size, min_lot);
   lot_size = MathMin(lot_size, max_lot);
   lot_size = MathRound(lot_size / lot_step) * lot_step;
   
   return NormalizeDoubleCustom(lot_size, 2);
}

//+------------------------------------------------------------------+
//| Get lot size for trade                                           |
//+------------------------------------------------------------------+
double CRiskManager::GetLotSize(double stop_loss_pips, double risk_percent = -1)
{
   return CalculateLotSize(stop_loss_pips, risk_percent);
}

//+------------------------------------------------------------------+
//| Calculate stop loss price                                        |
//+------------------------------------------------------------------+
double CRiskManager::CalculateStopLossPrice(int order_type, double entry_price, double stop_loss_pips)
{
   if(!UseStopLoss || stop_loss_pips <= 0)
      return 0;
      
   double stop_loss_points = PipsToPoints(stop_loss_pips);
   
   if(order_type == ORDER_TYPE_BUY)
      return NormalizeDoubleCustom(entry_price - stop_loss_points, m_digits);
   else if(order_type == ORDER_TYPE_SELL)
      return NormalizeDoubleCustom(entry_price + stop_loss_points, m_digits);
      
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate take profit price                                      |
//+------------------------------------------------------------------+
double CRiskManager::CalculateTakeProfitPrice(int order_type, double entry_price, double take_profit_pips)
{
   if(!UseTakeProfit || take_profit_pips <= 0)
      return 0;
      
   double take_profit_points = PipsToPoints(take_profit_pips);
   
   if(order_type == ORDER_TYPE_BUY)
      return NormalizeDoubleCustom(entry_price + take_profit_points, m_digits);
   else if(order_type == ORDER_TYPE_SELL)
      return NormalizeDoubleCustom(entry_price - take_profit_points, m_digits);
      
   return 0;
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                    |
//+------------------------------------------------------------------+
bool CRiskManager::CheckSpread()
{
   double current_spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * m_point;
   double max_spread = PipsToPoints(MaxSpreadPips);
   
   return current_spread <= max_spread;
}

//+------------------------------------------------------------------+
//| Check maximum positions                                          |
//+------------------------------------------------------------------+
bool CRiskManager::CheckMaxPositions()
{
   int positions_count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == m_symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         positions_count++;
   }
   
   return positions_count < MaxPositions;
}

//+------------------------------------------------------------------+
//| Check hedge positions                                            |
//+------------------------------------------------------------------+
bool CRiskManager::CheckHedge(int order_type)
{
   if(HedgeAllowed)
      return true;
      
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == m_symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         long pos_type = PositionGetInteger(POSITION_TYPE);
         if((order_type == ORDER_TYPE_BUY && pos_type == POSITION_TYPE_SELL) ||
            (order_type == ORDER_TYPE_SELL && pos_type == POSITION_TYPE_BUY))
            return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validate order parameters                                        |
//+------------------------------------------------------------------+
bool CRiskManager::ValidateOrder(int order_type, double lot_size, double stop_loss, double take_profit)
{
   // Check spread
   if(!CheckSpread())
   {
      Print("Spread too high");
      return false;
   }
   
   // Check max positions
   if(!CheckMaxPositions())
   {
      Print("Maximum positions reached");
      return false;
   }
   
   // Check hedge
   if(!CheckHedge(order_type))
   {
      Print("Hedge not allowed");
      return false;
   }
   
   // Check lot size
   double min_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
   
   if(lot_size < min_lot || lot_size > max_lot)
   {
      Print("Invalid lot size");
      return false;
   }
   
   // Check stop loss and take profit
   if(UseStopLoss && stop_loss > 0)
   {
      double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double sl_price = CalculateStopLossPrice(order_type, price, StopLossPips);
      
      if(order_type == ORDER_TYPE_BUY && sl_price >= price)
      {
         Print("Invalid stop loss for buy");
         return false;
      }
      if(order_type == ORDER_TYPE_SELL && sl_price <= price)
      {
         Print("Invalid stop loss for sell");
         return false;
      }
   }
   
   if(UseTakeProfit && take_profit > 0)
   {
      double price = (order_type == ORDER_TYPE_BUY) ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);
      double tp_price = CalculateTakeProfitPrice(order_type, price, TakeProfitPips);
      
      if(order_type == ORDER_TYPE_BUY && tp_price <= price)
      {
         Print("Invalid take profit for buy");
         return false;
      }
      if(order_type == ORDER_TYPE_SELL && tp_price >= price)
      {
         Print("Invalid take profit for sell");
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if partial close should be executed                        |
//+------------------------------------------------------------------+
bool CRiskManager::CheckPartialClose(long ticket)
{
   if(!UsePartialClose || PartialClosePct <= 0 || PartialClosePct >= 100)
      return false;
      
   double rr = GetOrderRiskReward(ticket);
   if(rr >= PartialCloseRR)
   {
      // Close partial position
      if(PositionSelectByTicket(ticket))
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         double close_volume = volume * PartialClosePct / 100.0;
         
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_DEAL;
         request.position = ticket;
         request.symbol = m_symbol;
         request.volume = NormalizeDoubleCustom(close_volume, 2);
         request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
         request.price = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         request.deviation = MaxSlippage;
         request.magic = MagicNumber;
         request.comment = OrderComment + " Partial Close";
         
         return OrderSend(request, result);
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if position should be added                                |
//+------------------------------------------------------------------+
bool CRiskManager::CheckAddPosition(long ticket)
{
   if(!AllowAddPosition)
      return false;
      
   double rr = GetOrderRiskReward(ticket);
   if(rr >= AddPositionRR)
   {
      // Add position logic would be implemented in main EA
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check and update trailing stop                                   |
//+------------------------------------------------------------------+
bool CRiskManager::CheckTrailingStop(long ticket)
{
   if(!UseTrailingStop || TrailingStartPips <= 0 || TrailingStepPips <= 0)
      return false;
      
   if(PositionSelectByTicket(ticket))
   {
      double profit_pips = GetOrderProfitPips(ticket);
      
      if(profit_pips >= TrailingStartPips)
      {
         long type = PositionGetInteger(POSITION_TYPE);
         double current_sl = PositionGetDouble(POSITION_SL);
         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(m_symbol, SYMBOL_BID) : SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         
         double new_sl = current_sl;
         double trail_points = PipsToPoints(TrailingStepPips);
         
         if(type == POSITION_TYPE_BUY)
         {
            new_sl = current_price - trail_points;
            if(new_sl > current_sl && new_sl > entry)
               return ModifyOrder(ticket, new_sl, PositionGetDouble(POSITION_TP));
         }
         else if(type == POSITION_TYPE_SELL)
         {
            new_sl = current_price + trail_points;
            if(new_sl < current_sl && new_sl < entry)
               return ModifyOrder(ticket, new_sl, PositionGetDouble(POSITION_TP));
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check and move to breakeven                                      |
//+------------------------------------------------------------------+
bool CRiskManager::CheckBreakEven(long ticket)
{
   if(!UseBreakEven || BreakEvenPips <= 0)
      return false;
      
   if(PositionSelectByTicket(ticket))
   {
      double profit_pips = GetOrderProfitPips(ticket);
      
      if(profit_pips >= BreakEvenPips)
      {
         long type = PositionGetInteger(POSITION_TYPE);
         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_sl = PositionGetDouble(POSITION_SL);
         
         // Move SL to breakeven if not already at or better
         if((type == POSITION_TYPE_BUY && current_sl < entry) ||
            (type == POSITION_TYPE_SELL && current_sl > entry))
         {
            return ModifyOrder(ticket, entry, PositionGetDouble(POSITION_TP));
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool CRiskManager::IsTradingAllowed()
{
   // Check account status
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return false;
      
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return false;
      
   // Check market status
   if(!SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL)
      return false;
      
   // Check margin
   double margin_required = AccountInfoDouble(ACCOUNT_MARGIN_REQUIRED);
   double margin_free = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   if(margin_required > 0 && margin_free < margin_required * 0.1) // Less than 10% free margin
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Get current portfolio risk                                       |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentRisk()
{
   double total_risk = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == m_symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         double volume = PositionGetDouble(POSITION_VOLUME);
         double sl = PositionGetDouble(POSITION_SL);
         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         long type = PositionGetInteger(POSITION_TYPE);
         
         double risk_pips = 0;
         if(type == POSITION_TYPE_BUY && sl > 0)
            risk_pips = (entry - sl) / (10 * m_point);
         else if(type == POSITION_TYPE_SELL && sl > 0)
            risk_pips = (sl - entry) / (10 * m_point);
            
         total_risk += risk_pips;
      }
   }
   
   return total_risk;
}

//+------------------------------------------------------------------+
//| Get order profit in pips                                         |
//+------------------------------------------------------------------+
double CRiskManager::GetOrderProfitPips(long ticket)
{
   if(PositionSelectByTicket(ticket))
   {
      double profit = PositionGetDouble(POSITION_PROFIT);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double tick_value = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      
      if(volume > 0 && tick_value > 0)
      {
         double profit_per_lot = profit / volume;
         return profit_per_lot / (tick_value * 10 * m_point);
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Get order risk/reward ratio                                      |
//+------------------------------------------------------------------+
double CRiskManager::GetOrderRiskReward(long ticket)
{
   if(PositionSelectByTicket(ticket))
   {
      double tp = PositionGetDouble(POSITION_TP);
      double sl = PositionGetDouble(POSITION_SL);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      long type = PositionGetInteger(POSITION_TYPE);
      
      if(tp > 0 && sl > 0)
      {
         double risk = 0, reward = 0;
         
         if(type == POSITION_TYPE_BUY)
         {
            risk = entry - sl;
            reward = tp - entry;
         }
         else if(type == POSITION_TYPE_SELL)
         {
            risk = sl - entry;
            reward = entry - tp;
         }
         
         if(risk > 0)
            return reward / risk;
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Modify order                                                     |
//+------------------------------------------------------------------+
bool CRiskManager::ModifyOrder(long ticket, double stop_loss, double take_profit)
{
   if(PositionSelectByTicket(ticket))
   {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol = m_symbol;
      request.sl = NormalizeDoubleCustom(stop_loss, m_digits);
      request.tp = NormalizeDoubleCustom(take_profit, m_digits);
      request.magic = MagicNumber;
      
      return OrderSend(request, result);
   }
   return false;
}
//+------------------------------------------------------------------+