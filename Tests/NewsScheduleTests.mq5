#property strict

#include "../NewsTools/NewsSchedule.mqh"

int g_failures=0;

void Expect(const string name,const bool condition)
  {
   if(!condition)
     {
      ++g_failures;
      Print("FAIL: ",name);
     }
  }

void OnStart(void)
  {
   CNewsSchedule schedule;
   Expect("parameters",schedule.SetParams(PERIOD_M15,true));
   Expect("coverage",schedule.AddCoverage(D'2026.09.01 00:00',D'2026.09.02 00:00'));
   Expect("event",schedule.AddEvent(D'2026.09.01 14:00',"USD"));
   Expect("initializes",schedule.Init());
   bool blocked=false;
   string reason="";
   Expect("previous candle is blocked",
          schedule.Step(D'2026.09.01 13:45',"EUR","USD",blocked,reason) && blocked);
   Expect("second following candle is blocked",
          schedule.Step(D'2026.09.01 14:15',"EUR","USD",blocked,reason) && blocked);
   Expect("window end is enabled",
          schedule.Step(D'2026.09.01 14:30',"EUR","USD",blocked,reason) && !blocked);
   Expect("uncovered time fails closed",
          !schedule.Step(D'2026.09.02 12:00',"EUR","USD",blocked,reason) && blocked);
   bool has_event=false;
   Expect("news candle is identified",
          schedule.EventInCandle(D'2026.09.01 14:00',"EUR","USD",has_event) &&
          has_event);
   Expect("adjacent candle is not news candle",
          schedule.EventInCandle(D'2026.09.01 14:15',"EUR","USD",has_event) &&
          !has_event);
   Expect("news candle requires coverage",
          !schedule.EventInCandle(D'2026.09.02 12:00',"EUR","USD",has_event));
   if(g_failures==0)
      Print("NewsScheduleTests: PASS");
   else
      PrintFormat("NewsScheduleTests: FAIL failures=%d",g_failures);
  }
