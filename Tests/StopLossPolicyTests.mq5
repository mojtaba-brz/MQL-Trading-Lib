#property strict

#include "../RiskManagement/StopLossPolicy.mqh"

int g_failures=0;

void Expect(const string name,const bool condition)
  {
   if(!condition)
     {
      ++g_failures;
      Print("FAIL: ",name);
     }
  }

void ExpectNear(const string name,const double actual,const double expected)
  {
   Expect(name,MathIsValidNumber(actual) && MathAbs(actual-expected)<1e-10);
  }

MqlRates Bar(const string time,const double open,const double high,
             const double low,const double close)
  {
   MqlRates bar={};
   bar.time=StringToTime(time);
   bar.open=open;
   bar.high=high;
   bar.low=low;
   bar.close=close;
   return bar;
  }

SStopLossParams Params(const ENUM_INITIAL_STOP_METHOD method)
  {
   SStopLossParams params={};
   params.initial_method=method;
   params.setup_lookback=3;
   params.atr_period=3;
   params.atr_multiplier=1.5;
   params.structure_buffer_atr=0.25;
   params.maximum_distance_atr=5.0;
   params.mae_quantile_atr=1.25;
   params.time_exit_enabled=true;
   params.time_exit_bars=2;
   params.time_exit_minimum_favorable_r=0.5;
   params.signal_invalidation_enabled=true;
   params.trailing_enabled=true;
   params.trailing_lookback=2;
   params.trailing_buffer_atr=0.1;
   return params;
  }

void OnStart(void)
  {
   MqlRates bars[];
   ArrayResize(bars,5);
   bars[0]=Bar("2026.09.06 08:00",100.0,101.0,99.0,100.0);
   bars[1]=Bar("2026.09.06 09:00",100.0,102.0,99.5,101.0);
   bars[2]=Bar("2026.09.06 10:00",101.0,103.0,100.0,102.0);
   bars[3]=Bar("2026.09.06 11:00",102.0,104.0,101.0,103.0);
   bars[4]=Bar("2026.09.06 12:00",103.0,105.0,102.0,104.0);
   double atr=StopLossATR(bars,5,3);
   ExpectNear("true-range ATR",atr,3.0);

   double stop=0.0;
   string reason="";
   CStopLossPolicy policy;
   Expect("Init requires parameters",!policy.Init());
   SStopLossParams params=Params(INITIAL_STOP_STRUCTURE_ATR);
   Expect("hybrid params",policy.SetParams(params) && policy.Init());
   Expect("hybrid buy",policy.CalculateInitialStop(true,104.0,bars,5,
          D'2026.09.06 10:00',0.1,0.01,stop,reason));
   ExpectNear("hybrid uses wider structural stop",stop,99.25);

   params=Params(INITIAL_STOP_SETUP_WINDOW);
   policy.SetParams(params); policy.Init();
   Expect("setup buy",policy.CalculateInitialStop(true,104.0,bars,5,
          D'2026.09.06 10:00',0.1,0.01,stop,reason));
   ExpectNear("setup low plus ATR buffer",stop,99.25);

   params=Params(INITIAL_STOP_ATR);
   policy.SetParams(params); policy.Init();
   Expect("ATR sell",policy.CalculateInitialStop(false,104.0,bars,5,
          D'2026.09.06 10:00',0.1,0.01,stop,reason));
   ExpectNear("ATR sell distance",stop,108.5);

   params=Params(INITIAL_STOP_SESSION);
   policy.SetParams(params); policy.Init();
   Expect("session buy",policy.CalculateInitialStop(true,104.0,bars,5,
          D'2026.09.06 10:00',0.1,0.01,stop,reason));
   ExpectNear("session low",stop,99.25);

   params=Params(INITIAL_STOP_MAE_ATR);
   policy.SetParams(params); policy.Init();
   Expect("MAE buy",policy.CalculateInitialStop(true,104.0,bars,5,
          D'2026.09.06 10:00',0.1,0.01,stop,reason));
   ExpectNear("frozen MAE quantile",stop,100.25);
   Expect("buy stop rounds away from entry",policy.CalculateInitialStop(true,104.0,bars,5,
          D'2026.09.06 10:00',0.1,0.1,stop,reason));
   ExpectNear("tick-size rounding",stop,100.2);

   params.maximum_distance_atr=0.5;
   Expect("narrow maximum params",policy.SetParams(params) && policy.Init());
   Expect("excessively wide stop rejected",!policy.CalculateInitialStop(true,104.0,bars,5,
          D'2026.09.06 10:00',0.1,0.01,stop,reason) && stop==EMPTY_VALUE);

   params=Params(INITIAL_STOP_ATR);
   policy.SetParams(params); policy.Init();
   Expect("begin managed position",policy.Begin(true,104.0,99.5,D'2026.09.06 12:00'));
   MqlRates managed[];
   ArrayResize(managed,5);
   managed[0]=bars[1]; managed[1]=bars[2]; managed[2]=bars[3]; managed[3]=bars[4];
   managed[4]=Bar("2026.09.06 13:00",104.0,104.5,103.0,103.5);
   SStopLossDecision decision={};
   Expect("management first step",policy.Step(managed,5,false,false,decision));
   Expect("first bar remains open",!decision.close_position && decision.age_bars==1);
   managed[0]=managed[1]; managed[1]=managed[2]; managed[2]=managed[3]; managed[3]=managed[4];
   managed[4]=Bar("2026.09.06 14:00",103.5,104.2,103.2,103.8);
   Expect("time-stop step",policy.Step(managed,5,false,false,decision));
   Expect("time stop closes",decision.close_position && decision.age_bars==2);

   policy.Reset(); policy.Begin(true,104.0,99.5,D'2026.09.06 12:00');
   Expect("signal exit step",policy.Step(managed,5,false,true,decision));
   Expect("signal invalidation closes",decision.close_position);

   policy.Reset(); policy.Begin(true,104.0,99.5,D'2026.09.06 12:00');
   Expect("trailing step",policy.Step(managed,5,true,false,decision));
   Expect("trailing ratchets",decision.move_stop && decision.stop_price>99.5);
   double first_trail=decision.stop_price;
   managed[0]=Bar("2026.09.06 09:00",100.0,102.0,98.0,101.0);
   managed[4]=Bar("2026.09.06 15:00",103.8,104.0,100.0,101.0);
   Expect("later trailing step",policy.Step(managed,5,true,false,decision));
   Expect("trailing never loosens",!decision.move_stop && policy.CurrentStop()==first_trail);

   if(g_failures==0)
      Print("StopLossPolicyTests: PASS");
   else
      PrintFormat("StopLossPolicyTests: FAIL failures=%d",g_failures);
  }
