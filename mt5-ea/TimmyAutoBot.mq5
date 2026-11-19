// TIMMY MT5 AUTO BOT — educational starter EA
// DEMO ONLY by default. Compile and test in MetaEditor/Strategy Tester.
// It is not the NYX EA algorithm and does not promise profitability.
#property strict
#include <Trade/Trade.mqh>
CTrade trade;

enum RiskProfile { CONSERVATIVE=0, BALANCED=1, DYNAMIC=2 };
input RiskProfile Profile = BALANCED;
input bool DemoOnly = true;                 // refuses live accounts while true
input double RiskPercent = 0.25;            // risk per trade; conservative default
input double MaxDailyLossPercent = 1.0;     // stop opening trades after daily loss threshold
input int MaxPositions = 1;
input int FastEMA = 20;
input int SlowEMA = 50;
input int RSIPeriod = 14;
input double StopATRMultiplier = 2.0;
input double RewardRisk = 1.5;
input ulong MagicNumber = 6111901;
input int MaxSpreadPoints = 35;
input bool AllowNewTrades = false;          // explicitly enable on a demo account only

int hFast, hSlow, hRsi, hAtr;
datetime lastBar=0;
double dayStartEquity=0;
int dayOfYear=-1;

int OnInit(){
  if(DemoOnly && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL){
    Print("TIMMY: DemoOnly is enabled. EA will not trade a live account."); return INIT_FAILED;
  }
  hFast=iMA(_Symbol,_Period,FastEMA,0,MODE_EMA,PRICE_CLOSE);
  hSlow=iMA(_Symbol,_Period,SlowEMA,0,MODE_EMA,PRICE_CLOSE);
  hRsi=iRSI(_Symbol,_Period,RSIPeriod,PRICE_CLOSE);
  hAtr=iATR(_Symbol,_Period,14);
  if(hFast==INVALID_HANDLE||hSlow==INVALID_HANDLE||hRsi==INVALID_HANDLE||hAtr==INVALID_HANDLE) return INIT_FAILED;
  trade.SetExpertMagicNumber(MagicNumber);
  ResetDailyBaseline();
  return INIT_SUCCEEDED;
}
void OnDeinit(const int reason){IndicatorRelease(hFast);IndicatorRelease(hSlow);IndicatorRelease(hRsi);IndicatorRelease(hAtr);}
void ResetDailyBaseline(){
  MqlDateTime t;TimeToStruct(TimeCurrent(),t);
  dayOfYear=t.day_of_year;dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);
}
bool DailyLossReached(){
  MqlDateTime t;TimeToStruct(TimeCurrent(),t);
  if(t.day_of_year!=dayOfYear)ResetDailyBaseline();
  if(dayStartEquity<=0)return true;
  double lossPct=(dayStartEquity-AccountInfoDouble(ACCOUNT_EQUITY))/dayStartEquity*100.0;
  return lossPct>=MaxDailyLossPercent;
}
int CountMyPositions(){
  int n=0;
  for(int i=PositionsTotal()-1;i>=0;i--){
    ulong ticket=PositionGetTicket(i);
    if(ticket>0 && PositionGetString(POSITION_SYMBOL)==_Symbol && (ulong)PositionGetInteger(POSITION_MAGIC)==MagicNumber)n++;
  }
  return n;
}
double ProfileRisk(){
  if(Profile==CONSERVATIVE)return MathMin(RiskPercent,0.15);
  if(Profile==DYNAMIC)return MathMin(RiskPercent,0.50);
  return MathMin(RiskPercent,0.25);
}
double LotsForRisk(double stopDistance){
  double equity=AccountInfoDouble(ACCOUNT_EQUITY);
  double riskMoney=equity*ProfileRisk()/100.0;
  double tickVal=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
  double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
  if(stopDistance<=0||tickVal<=0||tickSize<=0)return 0;
  double lossPerLot=(stopDistance/tickSize)*tickVal;
  double lots=riskMoney/lossPerLot;
  double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
  double minLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
  double maxLot=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
  lots=MathFloor(lots/step)*step;
  return MathMax(0,MathMin(maxLot,lots)<minLot?0:MathMin(maxLot,lots));
}
void OnTick(){
  if(!AllowNewTrades)return;
  if(DemoOnly && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL)return;
  if(DailyLossReached()||CountMyPositions()>=MaxPositions)return;
  if((int)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>MaxSpreadPoints)return;
  datetime bar=iTime(_Symbol,_Period,0);if(bar==lastBar)return;lastBar=bar;
  double f[3],s[3],r[3],a[3];
  ArraySetAsSeries(f,true);ArraySetAsSeries(s,true);ArraySetAsSeries(r,true);ArraySetAsSeries(a,true);
  if(CopyBuffer(hFast,0,0,3,f)<3||CopyBuffer(hSlow,0,0,3,s)<3||CopyBuffer(hRsi,0,0,3,r)<3||CopyBuffer(hAtr,0,0,3,a)<3)return;
  bool buy=(f[2]<=s[2]&&f[1]>s[1]&&r[1]>50&&r[1]<70);
  bool sell=(f[2]>=s[2]&&f[1]<s[1]&&r[1]<50&&r[1]>30);
  if(!buy&&!sell)return;
  double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK),bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
  double stopDist=a[1]*StopATRMultiplier;
  double lots=LotsForRisk(stopDist);if(lots<=0)return;
  int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
  if(buy){double sl=NormalizeDouble(ask-stopDist,digits),tp=NormalizeDouble(ask+stopDist*RewardRisk,digits);trade.Buy(lots,_Symbol,ask,sl,tp,"Timmy demo EMA/RSI");}
  if(sell){double sl=NormalizeDouble(bid+stopDist,digits),tp=NormalizeDouble(bid-stopDist*RewardRisk,digits);trade.Sell(lots,_Symbol,bid,sl,tp,"Timmy demo EMA/RSI");}
}
