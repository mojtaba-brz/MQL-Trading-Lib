#property script_show_inputs
#property strict

#include "../RuntimeInputs/RuntimeInputContracts.mqh"

int g_failures=0;

void ExpectTrue(const string name,const bool condition)
  {
   if(condition)
      Print("PASS: ",name);
   else
     {
      Print("FAIL: ",name);
      ++g_failures;
     }
  }

void OnStart()
  {
   ENUM_TIMEFRAMES timeframes[];
   ExpectTrue("five required timeframes",
              BanksEffectsRequiredTimeframes(timeframes)==5);
   ExpectTrue("ordered M1",timeframes[0]==PERIOD_M1);
   ExpectTrue("ordered M15",timeframes[1]==PERIOD_M15);
   ExpectTrue("ordered H1",timeframes[2]==PERIOD_H1);
   ExpectTrue("ordered H4",timeframes[3]==PERIOD_H4);
   ExpectTrue("ordered D1",timeframes[4]==PERIOD_D1);
   ExpectTrue("reject M5",!BanksEffectsIsRequiredTimeframe(PERIOD_M5));

   SRuntimeInputValue value={};
   value.feature_id="test.return.m15";
   value.value=1.0;
   value.as_of=1000;
   value.timeframe=PERIOD_M15;
   value.status=RUNTIME_INPUT_READY;
   value.generator_id="test-generator";
   value.generator_version="1.0.0";

   ExpectTrue("usable input",RuntimeInputIsUsable(value,1010,60));
   ExpectTrue("future input rejected",!RuntimeInputIsUsable(value,999,60));
   ExpectTrue("stale input rejected",!RuntimeInputIsUsable(value,1100,60));
   value.status=RUNTIME_INPUT_UNAVAILABLE;
   ExpectTrue("unavailable input rejected",!RuntimeInputIsUsable(value,1010,60));

   if(g_failures==0)
      Print("RuntimeInputContractsTests: PASS");
   else
      PrintFormat("RuntimeInputContractsTests: FAIL failures=%d",g_failures);
  }
