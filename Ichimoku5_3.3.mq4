
//------------------------------------------------------------------
#property copyright "www.forex-tsd.com"
#property link      "www.forex-tsd.com"
//------------------------------------------------------------------

//
//
//
//
//

#include <stdlib.mqh>

//
//
//
//
//

extern string Name_Expert       = "Ichimoku5.3.3Ea";
extern bool   EcnBroker         = true;
extern bool   UseAutoMagic      = true;
extern int    ManualMagic       = 81850282;  
extern double lStopLoss         = 100;
extern double sStopLoss         = 100;
extern double lTakeProfit       = 300;
extern double sTakeProfit       = 300;
extern double lTrailingStop     = 40;
extern double sTrailingStop     = 40;
extern int    Slippage          = 4;
extern double Lots              = 0.1;
extern double MaximumRisk       = 0;
extern double DecreaseFactor    = 3;

extern int    TenkanKijunTf     = 240;
extern int    Tenkan            = 9;
extern int    Kijun             = 26;
extern int    MaTimeframe       = 240;
extern int    MaPeriod          = 34;
extern int    MaType            = MODE_EMA;
extern int    bar               = 1;

extern bool   UseHourTrade      = false;
extern int    FromHourTrade     = 8;
extern int    ToHourTrade       = 19;

extern string __                = "Setting for friday positions close";
extern bool   CloseOnFriday     = false;
extern int    FridayCloseHour   = 21; // will be used only if CloseOnFriday == true
extern int    FridayCloseMinute = 59; // will be used only if CloseOnFriday == true

extern bool   ShowAlerts        = false;
extern color  clOpenBuy         = Blue;
extern color  clCloseBuy        = Aqua;
extern color  clOpenSell        = Red;
extern color  clCloseSell       = Violet;

//
//
//
//
//

double pipMultiplier = 1;

string s_symbol;

int    MAGIC;
int    ColorMode = 2; 
int    digit;

//
//
//
//
//

int init() 
{
   s_symbol = Symbol();
  
   digit  = MarketInfo(s_symbol,MODE_DIGITS);
   if (digit==2 || digit==4) pipMultiplier = 1;
   if (digit==3 || digit==5) pipMultiplier = 10;
   if (digit==6)             pipMultiplier = 100;
  
   if (UseAutoMagic) MAGIC = GetMagic();
               else  MAGIC = ManualMagic;    
              
return(0);
}

//
//
//
//
//

int deinit() { return(0); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//
//

int start()
{
   if(Bars < 100) { Print("bars less than 100"); return(0); }
   
   //
   //
   //
   //
   //
   
   if (UseHourTrade)
   {
     if(!(Hour() >= FromHourTrade && Hour() <= ToHourTrade)) { Comment("Non-Trading Hours!");  return(0);  }
   }
   
   //
   //
   //
   //
   //
   
   if (CloseOnFriday && TimeDayOfWeek(TimeCurrent())==5)
   {
     if (TimeHour(TimeCurrent()) > FridayCloseHour ||
        (TimeHour(TimeCurrent())== FridayCloseHour && TimeMinute(TimeCurrent())>= FridayCloseMinute))
     {
       for(int i=OrdersTotal()-1; i>=0; i--)
  	    { 
     	   OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
            if(OrderSymbol()     != s_symbol)    continue;
            if(OrderMagicNumber()!= MAGIC)       continue;

            if(OrderType()==OP_BUY)  { OrderClose(OrderTicket(),OrderLots(),Ask,0,CLR_NONE); continue; }
            if(OrderType()==OP_SELL) { OrderClose(OrderTicket(),OrderLots(),Bid,0,CLR_NONE); continue; }
       }
       return(0);
     }
   }
   
   //
   //
   //
   //
   //
   
   if (!ExistPositions())
   {
      double diCustom0 = iCustom(s_symbol,TenkanKijunTf,"Tenkan Sen-Kijun Sen",0,Tenkan,Kijun,0,bar);
      double diCustom1 = iCustom(s_symbol,TenkanKijunTf,"Tenkan Sen-Kijun Sen",0,Tenkan,Kijun,1,bar);
      double diCustom2 = iCustom(s_symbol,TenkanKijunTf,"Tenkan Sen-Kijun Sen",0,Tenkan,Kijun,1,bar);
      double diCustom3 = iCustom(s_symbol,TenkanKijunTf,"Tenkan Sen-Kijun Sen",0,Tenkan,Kijun,1,bar+1);
      double diMA3     = iMA(s_symbol,MaTimeframe,MaPeriod,0,MaType,PRICE_CLOSE,bar);
      double diMA4     = iMA(s_symbol,MaTimeframe,MaPeriod,0,MaType,PRICE_CLOSE,bar+1);

      if (diCustom0 > diCustom1 && diCustom2 > diMA3 && diCustom3 <= diMA4)
      {
         OpenBuy();
         return(0);
      }

      if (diCustom0 < diCustom1 && diCustom2 < diMA3 && diCustom3 >= diMA4)
      {
         OpenSell();
         return(0);
      }

  }
   
   if(lTrailingStop > 0)  TrailingPositionsBuy();
   if(sTrailingStop > 0)  TrailingPositionsSell();
return (0);
}

//
//
//
//
//

bool ExistPositions() {
	for (int i=0; i<OrdersTotal(); i++) {
		if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
			if (OrderSymbol() == s_symbol && OrderMagicNumber() == MAGIC) {
				return(true);
			}
		} 
	} 
return(false);
}

//
//
//
//
//

void TrailingPositionsBuy() { 
   for (int i = 0; i < OrdersTotal(); i++) { 
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) { 
         if (OrderSymbol() == s_symbol && OrderMagicNumber() == MAGIC) { 
            if (OrderType() == OP_BUY) { 
               if (Bid-OrderOpenPrice()     > lTrailingStop * Point * pipMultiplier) { 
                  if (OrderStopLoss() < Bid - lTrailingStop * Point * pipMultiplier) 
                      ModifyStopLoss(Bid    - lTrailingStop * Point * pipMultiplier); 
               } 
            } 
         } 
      } 
   } 
}

//
//
//
//
//
 
void TrailingPositionsSell() { 
   for (int i = 0; i < OrdersTotal(); i++) { 
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) { 
         if (OrderSymbol() == s_symbol && OrderMagicNumber() == MAGIC) { 
            if (OrderType() == OP_SELL) { 
               if (OrderOpenPrice() - Ask   > sTrailingStop * Point * pipMultiplier) { 
                  if (OrderStopLoss() > Ask + sTrailingStop * Point * pipMultiplier || OrderStopLoss() == 0)  
                      ModifyStopLoss(Ask    + sTrailingStop * Point * pipMultiplier); 
               } 
            } 
         } 
      } 
   } 
}

//
//
//
//
//
 
void ModifyStopLoss(double ldStopLoss) 
{ 
   bool fm;
   fm = OrderModify(OrderTicket(),OrderOpenPrice(),ldStopLoss,OrderTakeProfit(),0,CLR_NONE); 
   
   if (fm == false)
   {
	  int    ErrorCode = GetLastError();
	  string ErrDesc   = ErrorDescription(ErrorCode);

	  string ErrAlert  = StringConcatenate("Trailing Stop Modification - Error ",ErrorCode,": ",ErrDesc);
	  if (ShowAlerts   == true) Alert(ErrAlert);

	  string ErrLog    = StringConcatenate("Ask: ",MarketInfo(s_symbol,MODE_ASK)," Ticket: ",OrderTicket()," Stop: ",OrderStopLoss()," Trail: ",ldStopLoss);
	  Print(ErrLog);
	}
 
} 

//
//
//
//
//

void OpenBuy() 
{ 
    
   if (lStopLoss > 0)   double lbStop = Ask - lStopLoss   * Point * pipMultiplier; 
   else lbStop = 0;
   
   if (lTakeProfit > 0) double lbTake = Ask + lTakeProfit * Point * pipMultiplier;
   else lbTake = 0;
   
   if (AccountFreeMargin() < (100 * Lots)) { Print("We have no money. Free Margin = ", AccountFreeMargin()); return(0); }
   
   //
   //
   //
   //
   //
   
   if (!EcnBroker) 
         OrderSend(s_symbol,OP_BUY,LotsOptimized(),Ask,Slippage*Point*pipMultiplier,lbStop,lbTake,Name_Expert,MAGIC,0,clOpenBuy); 
   else
   {
         int buyTicket    = OrderSend(s_symbol,OP_BUY,LotsOptimized(),Ask,Slippage*Point*pipMultiplier,0,0,Name_Expert,MAGIC,0,clOpenBuy);		    		    
         if (buyTicket   >= 0)
         bool buyOrderMod = OrderModify(buyTicket,OrderOpenPrice(),lbStop,lbTake,0,CLR_NONE);
         
         if (buyOrderMod  == false)
         {
         
           int    ErrorCode = GetLastError();
           string ErrDesc   = ErrorDescription(ErrorCode);

           string ErrAlert  = StringConcatenate("Modify Buy Order - Error ",ErrorCode,": ",ErrDesc);
           if (ShowAlerts   == true) Alert(ErrAlert);

           string ErrLog    = StringConcatenate("Ask: ",Ask," Bid: ",Bid," Ticket: ",buyTicket," Stop: ",lbStop," Profit: ",lbTake);
           Print(ErrLog);
         }
    }		       

}

//
//
//
//
//

void OpenSell() 
{ 

   if (sStopLoss > 0)   double lsStop = Bid + sStopLoss   * Point * pipMultiplier; 
   else lsStop = 0;
   
   if (sTakeProfit > 0) double lsTake = Bid - sTakeProfit * Point * pipMultiplier;
   else lsTake = 0;
  
   if (AccountFreeMargin() < (100 * Lots)) { Print("We have no money. Free Margin = ", AccountFreeMargin()); return(0); }
   
   //
   //
   //
   //
   //
   
   if (!EcnBroker)
         OrderSend(s_symbol,OP_SELL,LotsOptimized(),Bid,Slippage*Point*pipMultiplier,lsStop,lsTake,Name_Expert,MAGIC,0,clOpenSell); 
   else
   {
         int sellTicket    = OrderSend(s_symbol,OP_SELL,LotsOptimized(),Bid,Slippage*Point*pipMultiplier,0,0,Name_Expert,MAGIC,0,clOpenSell);		    		    
         if (sellTicket    >= 0)
         bool sellOrderMod = OrderModify(sellTicket,OrderOpenPrice(),lsStop,lsTake,0,CLR_NONE);
         
         if (sellOrderMod  == false)
         {
           int    ErrorCode = GetLastError();
           string ErrDesc   = ErrorDescription(ErrorCode);

           string ErrAlert  = StringConcatenate("Modify Sell Order - Error ",ErrorCode,": ",ErrDesc);
           if (ShowAlerts   == true) Alert(ErrAlert);

           string ErrLog    = StringConcatenate("Ask: ",Ask," Bid: ",Bid," Ticket: ",sellTicket," Stop: ",lsStop," Profit: ",lsTake);
           Print(ErrLog);
          }
    }		       
} 

//
//
//
//
//

double LotsOptimized()
{
   double lot_min  = MarketInfo(s_symbol,MODE_MINLOT);
   double lot_max  = MarketInfo(s_symbol,MODE_MAXLOT);
   double lot_step = MarketInfo(s_symbol,MODE_LOTSTEP);
   double contract = MarketInfo(s_symbol,MODE_LOTSIZE);
   double lot      = Lots;
   int    orders   = HistoryTotal();     // history orders total
   int    losses   = 0;                  // number of losses orders without a break
   
   //
   //
   //
   //
   //
   
   if(lot_min < 0.0 || lot_max <= 0.0 || lot_step <= 0.0) 
   {
   Print("CalculateVolume: invalid MarketInfo() results [",lot_min,",",lot_max,",",lot_step,"]");
   return(0);
   }
   if(AccountLeverage()<=0)
   {
   Print("CalculateVolume: invalid AccountLeverage() [",AccountLeverage(),"]");
   return(0);
   }
   
   //
   //
   //
   //
   //
   
   if (MaximumRisk > 0)
   {
   lot = NormalizeDouble(AccountFreeMargin() * MaximumRisk * AccountLeverage()/contract,2);
   }
   
   if(DecreaseFactor>0)
   {
      for(int i=orders-1;i>=0;i--)
      {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)==false) { Print("Error in history!"); break; }
      if(OrderSymbol()!= s_symbol || OrderType() > OP_SELL) continue;
      
      //
      //
      //
      //
      //
      
      if(OrderProfit() > 0) break;
      if(OrderProfit() < 0) losses++;
      }
   if(losses>1) lot=NormalizeDouble(lot - lot * losses/DecreaseFactor,2);
   }
   
   //
   //
   //
   //
   //
   
   lot=NormalizeDouble(lot/lot_step,0)*lot_step;
   if(lot<lot_min) lot=lot_min;
   if(lot>lot_max) lot=lot_max;
   
return(lot);
} 

//
//
//
//
//

int GetMagic() 
{

   if (s_symbol == "CADJPY") return(915031);
   if (s_symbol == "CADCHF") return(915032);
   
   if (s_symbol == "GOLD")   return(915041);
   if (s_symbol == "SILVER") return(915042);
   
   if (s_symbol == "NZDJPY") return(915051);
   if (s_symbol == "NZDUSD") return(915052);
   
   if (s_symbol == "CHFJPY") return(515061);
   
   if (s_symbol == "EURAUD") return(515071);
   if (s_symbol == "EURCAD") return(515072);
   if (s_symbol == "EURUSD") return(515073);
   if (s_symbol == "EURGBP") return(515074);
   if (s_symbol == "EURCHF") return(515075);
   if (s_symbol == "EURNZD") return(515076);
   if (s_symbol == "EURJPY") return(515077);
   
   if (s_symbol == "GBPUSD") return(515081);
   if (s_symbol == "GBPCHF") return(515082);
   if (s_symbol == "GBPJPY") return(515083);
   
   if (s_symbol == "USDCHF") return(515091);
   if (s_symbol == "USDJPY") return(515092);
   if (s_symbol == "USDCAD") return(515093);

   if (s_symbol == "AUDUSD") return(515001);
   if (s_symbol == "AUDNZD") return(515002);
   if (s_symbol == "AUDCAD") return(515003);
   if (s_symbol == "AUDCHF") return(515004);
   if (s_symbol == "AUDJPY") return(515005);
   
   return(ManualMagic);
}





