//+------------------------------------------------------------------+
//|                                           Ichimoku Chinkou Cross |
//|                                  Copyright © 2013, EarnForex.com |
//|                                        http://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2013, EarnForex"
#property link      "http://www.earnforex.com"

/*

Trades using Ichimoku Kinko Hyo indicator.

Implements Chinkou/Price cross strategy.

Chinkou crossing price (close) from below is a bullish signal.

Chinkou crossing price (close) from above is a bearish signal.

No SL/TP. Positions remain open from signal to signal.

Entry confirmed by current price above/below Kumo, latest Chinkou outside Kumo.

*/
// Main extern parameters
extern int Tenkan = 9; // Tenkan line period. The fast "moving average".
extern int Kijun = 26; // Kijun line period. The slow "moving average".
extern int Senkou = 52; // Senkou period. Used for Kumo (Cloud) spans.

// Money management
extern double Lots = 0.1; 		// Basic lot size
extern bool MM  = false;  	// If true - ATR-based position sizing
extern int ATR_Period = 20;
extern double ATR_Multiplier = 1;
extern double Risk = 2; // Risk tolerance in percentage points
extern double FixedBalance = 0; // If greater than 0, position size calculator will use it instead of actual account balance.
extern double MoneyRisk = 0; // Risk tolerance in base currency
extern bool UseMoneyInsteadOfPercentage = false;
extern bool UseEquityInsteadOfBalance = false;
extern int LotDigits = 2; // How many digits after dot supported in lot size. For example, 2 for 0.01, 1 for 0.1, 3 for 0.001, etc.

// Miscellaneous
extern string OrderCommentary = "Ichimoku-Chinkou-Cross";
extern int Slippage = 100; 	// Tolerated slippage in brokers' pips
extern int Magic = 2130512104; 	// Order magic number

// Global variables
// Common
int LastBars = 0;
bool HaveLongPosition;
bool HaveShortPosition;
double StopLoss; // Not actual stop-loss - just a potential loss of MM estimation.

// Entry signals
bool ChinkouPriceBull = false;
bool ChinkouPriceBear = false;
bool KumoBullConfirmation = false;
bool KumoBearConfirmation = false;
bool KumoChinkouBullConfirmation = false;
bool KumoChinkouBearConfirmation = false;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int init()
{
   return(0);    
}

//+------------------------------------------------------------------+
//| Deinitialization                                                 |
//+------------------------------------------------------------------+
int deinit()
{
   return(0);
}

//+------------------------------------------------------------------+
//| Each tick                                                        |
//+------------------------------------------------------------------+
int start()
{
   if ((!IsTradeAllowed()) || (IsTradeContextBusy()) || (!IsConnected()) || ((!MarketInfo(Symbol(), MODE_TRADEALLOWED)) && (!IsTesting()))) return(0);
	
	// Trade only if new bar has arrived
	if (LastBars != Bars) LastBars = Bars;
	else return(0);
   
   if (MM)
   {
      // Getting the potential loss value based on current ATR.
      StopLoss = iATR(NULL, 0, ATR_Period, 1) * ATR_Multiplier;
   }
   
   // Chinkou/Price Cross
   double ChinkouSpanLatest = iIchimoku(NULL, 0, Tenkan, Kijun, Senkou, MODE_CHINKOUSPAN, Kijun + 1); // Latest closed bar with Chinkou.
   double ChinkouSpanPreLatest = iIchimoku(NULL, 0, Tenkan, Kijun, Senkou, MODE_CHINKOUSPAN, Kijun + 2); // Bar older than latest closed bar with Chinkou.
   
   // Bullish entry condition
   if ((ChinkouSpanLatest > Close[Kijun + 1]) && (ChinkouSpanPreLatest <= Close[Kijun + 2]))
   {
      ChinkouPriceBull = true;
      ChinkouPriceBear = false;
   }
   // Bearish entry condition
   else if ((ChinkouSpanLatest < Close[Kijun + 1]) && (ChinkouSpanPreLatest >= Close[Kijun + 2]))
   {
      ChinkouPriceBull = false;
      ChinkouPriceBear = true;
   }
   else if (ChinkouSpanLatest == Close[Kijun + 1]) // Voiding entry conditions if cross is ongoing.
   {
      ChinkouPriceBull = false;
      ChinkouPriceBear = false;
   }
   
   // Kumo confirmation. When cross is happening current price (latest close) should be above/below both Senkou Spans, or price should close above/below both Senkou Spans after a cross.
   double SenkouSpanALatestByPrice = iIchimoku(NULL, 0, Tenkan, Kijun, Senkou, MODE_SENKOUSPANA, 1); // Senkou Span A at time of latest closed price bar.
   double SenkouSpanBLatestByPrice = iIchimoku(NULL, 0, Tenkan, Kijun, Senkou, MODE_SENKOUSPANB, 1); // Senkou Span B at time of latest closed price bar.
   if ((Close[1] > SenkouSpanALatestByPrice) && (Close[1] > SenkouSpanBLatestByPrice)) KumoBullConfirmation = true;
   else KumoBullConfirmation = false;
   if ((Close[1] < SenkouSpanALatestByPrice) && (Close[1] < SenkouSpanBLatestByPrice)) KumoBearConfirmation = true;
   else KumoBearConfirmation = false;
   
   // Kumo/Chinkou confirmation. When cross is happening Chinkou at its latest close should be above/below both Senkou Spans at that time, or it should close above/below both Senkou Spans after a cross.
   double SenkouSpanALatestByChinkou = iIchimoku(NULL, 0, Tenkan, Kijun, Senkou, MODE_SENKOUSPANA, Kijun + 1); // Senkou Span A at time of latest closed bar of Chinkou span.
   double SenkouSpanBLatestByChinkou = iIchimoku(NULL, 0, Tenkan, Kijun, Senkou, MODE_SENKOUSPANB, Kijun + 1); // Senkou Span B at time of latest closed bar of Chinkou span.
   if ((ChinkouSpanLatest > SenkouSpanALatestByChinkou) && (ChinkouSpanLatest > SenkouSpanBLatestByChinkou)) KumoChinkouBullConfirmation = true;
   else KumoChinkouBullConfirmation = false;
   if ((ChinkouSpanLatest < SenkouSpanALatestByChinkou) && (ChinkouSpanLatest < SenkouSpanBLatestByChinkou)) KumoChinkouBearConfirmation = true;
   else KumoChinkouBearConfirmation = false;

   GetPositionStates();
   
   if (ChinkouPriceBull)
   {
      if (HaveShortPosition) ClosePrevious();
      if ((KumoBullConfirmation) && (KumoChinkouBullConfirmation))
      {
         ChinkouPriceBull = false;
         fBuy();
      }
   }
   else if (ChinkouPriceBear)
   {
      if (HaveLongPosition) ClosePrevious();
      if ((KumoBearConfirmation) && (KumoChinkouBearConfirmation))
      {
         fSell();
         ChinkouPriceBear = false;
      }
   }
   return(0);
}

//+------------------------------------------------------------------+
//| Check what position is currently open										|
//+------------------------------------------------------------------+
void GetPositionStates()
{
   int total = OrdersTotal();
   for (int cnt = 0; cnt < total; cnt++)
   {
      if (OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES) == false) continue;
      if (OrderMagicNumber() != Magic) continue;
      if (OrderSymbol() != Symbol()) continue;

      if (OrderType() == OP_BUY)
      {
			HaveLongPosition = true;
			HaveShortPosition = false;
			return;
		}
      else if (OrderType() == OP_SELL)
      {
			HaveLongPosition = false;
			HaveShortPosition = true;
			return;
		}
	}
   HaveLongPosition = false;
	HaveShortPosition = false;
}

//+------------------------------------------------------------------+
//| Buy                                                              |
//+------------------------------------------------------------------+
void fBuy()
{
	RefreshRates();
	int result = OrderSend(Symbol(), OP_BUY, LotsOptimized(), Ask, Slippage, 0, 0,OrderCommentary, Magic);
	if (result == -1)
	{
		int e = GetLastError();
		Print("OrderSend Error: ", e);
	}
}

//+------------------------------------------------------------------+
//| Sell                                                             |
//+------------------------------------------------------------------+
void fSell()
{
	RefreshRates();
	int result = OrderSend(Symbol(), OP_SELL, LotsOptimized(), Bid, Slippage, 0, 0, OrderCommentary, Magic);
	if (result == -1)
	{
		int e = GetLastError();
		Print("OrderSend Error: ", e);
	}
}

//+------------------------------------------------------------------+
//| Calculate position size depending on money management parameters.|
//+------------------------------------------------------------------+
double LotsOptimized()
{
	if (!MM) return (Lots);
	
   double Size, RiskMoney, PositionSize = 0;

   if (AccountCurrency() == "") return(0);

   if (FixedBalance > 0)
   {
      Size = FixedBalance;
   }
   else if (UseEquityInsteadOfBalance)
   {
      Size = AccountEquity();
   }
   else
   {
      Size = AccountBalance();
   }
   
   if (!UseMoneyInsteadOfPercentage) RiskMoney = Size * Risk / 100;
   else RiskMoney = MoneyRisk;

   double UnitCost = MarketInfo(Symbol(), MODE_TICKVALUE);
   double TickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   
   if ((StopLoss != 0) && (UnitCost != 0) && (TickSize != 0)) PositionSize = NormalizeDouble(RiskMoney / (StopLoss * UnitCost / TickSize), LotDigits);
   
   if (PositionSize < MarketInfo(Symbol(), MODE_MINLOT)) PositionSize = MarketInfo(Symbol(), MODE_MINLOT);
   else if (PositionSize > MarketInfo(Symbol(), MODE_MAXLOT)) PositionSize = MarketInfo(Symbol(), MODE_MAXLOT);
   
   return(PositionSize);
} 

//+------------------------------------------------------------------+
//| Close previous position                                          |
//+------------------------------------------------------------------+
void ClosePrevious()
{
   int total = OrdersTotal();
   for (int i = 0; i < total; i++)
   {
      if (OrderSelect(i, SELECT_BY_POS) == false) continue;
      if ((OrderSymbol() == Symbol()) && (OrderMagicNumber() == Magic))
      {
         if (OrderType() == OP_BUY)
         {
            RefreshRates();
            OrderClose(OrderTicket(), OrderLots(), Bid, Slippage);
         }
         else if (OrderType() == OP_SELL)
         {
            RefreshRates();
            OrderClose(OrderTicket(), OrderLots(), Ask, Slippage);
         }
      }
   }
}
//+------------------------------------------------------------------+