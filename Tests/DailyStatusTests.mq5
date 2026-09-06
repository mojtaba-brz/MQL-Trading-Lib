#property strict

#include "../Report/DailyStatus.mqh"

int g_daily_status_failures=0;

void ExpectDailyStatus(const string name,const bool condition)
  {
   if(!condition)
     {
      ++g_daily_status_failures;
      Print("FAIL: ",name);
     }
  }

void OnStart(void)
  {
   double percent=0.0;
   ExpectDailyStatus("positive equity result",
                     DailyEquityPercentFromValues(105.0,100.0,percent));
   ExpectDailyStatus("positive equity percent",MathAbs(percent-5.0)<1e-10);
   ExpectDailyStatus("floating loss is included",
                     DailyEquityPercentFromValues(97.5,100.0,percent));
   ExpectDailyStatus("negative equity percent",MathAbs(percent+2.5)<1e-10);
   ExpectDailyStatus("invalid midnight balance rejected",
                     !DailyEquityPercentFromValues(100.0,0.0,percent));
   ExpectDailyStatus("broker midnight",
                     BrokerDayStart(D'2026.09.06 18:37:41')==D'2026.09.06 00:00:00');

   if(g_daily_status_failures==0)
      Print("DailyStatusTests: PASS");
   else
      PrintFormat("DailyStatusTests: FAIL failures=%d",g_daily_status_failures);
  }
