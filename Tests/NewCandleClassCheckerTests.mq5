#property script_show_inputs
#property strict

#include "../TimeBasedModules/NewCandleClassChecker.mqh"

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
   NewCandleClassChecker checker(PERIOD_M15);
   checker.SetParams("TEST",PERIOD_M15);
   datetime emitted=0;

   ExpectTrue("starts uninitialized",!checker.IsInitialized());
   ExpectTrue("invalid observation rejected",!checker.Step(0,emitted));
   ExpectTrue("invalid observation emits zero",emitted==0);

   ExpectTrue("Init accepts initial candle",checker.Init(1000));
   ExpectTrue("checker is initialized",checker.IsInitialized());
   ExpectTrue("initial candle remembered",checker.LastCandleTime()==1000);

   ExpectTrue("same candle rejected",!checker.Step(1000,emitted));
   ExpectTrue("forward candle accepted",checker.Step(1900,emitted));
   ExpectTrue("forward candle emitted",emitted==1900);
   ExpectTrue("gap accepted once",checker.Step(4600,emitted));
   ExpectTrue("gap endpoint emitted",emitted==4600);
   ExpectTrue("gap endpoint not repeated",!checker.Step(4600,emitted));

   NewCandleClassChecker independent(PERIOD_H1);
   independent.SetParams("XAUUSD",PERIOD_H1);
   ExpectTrue("first Step remains compatible initialization",!independent.Step(4600,emitted));
   ExpectTrue("second instance advances independently",independent.Step(8200,emitted));
   ExpectTrue("first instance memory unchanged",checker.LastCandleTime()==4600);

   ExpectTrue("rewind rebases without event",!checker.Step(500,emitted));
   ExpectTrue("rewind baseline remembered",checker.LastCandleTime()==500);
   ExpectTrue("forward after rewind accepted",checker.Step(600,emitted));

   checker.SetParams("EURUSD",PERIOD_H1);
   ExpectTrue("SetParams updates symbol",checker.SymbolName()=="EURUSD");
   ExpectTrue("SetParams updates period",checker.Period()==PERIOD_H1);
   ExpectTrue("SetParams resets memory",!checker.IsInitialized());
   ExpectTrue("configured stream initializes",!checker.Step(10000,emitted));

   checker.Reset();
   ExpectTrue("Reset clears memory",!checker.IsInitialized());

   // Existing source-compatible API remains callable.
   NewCandleClassChecker legacy(PERIOD_M15);
   ExpectTrue("legacy fixture initialized",legacy.Init(1000));
   legacy.set_params(PERIOD_H1);
   ExpectTrue("legacy set_params preserves memory",legacy.LastCandleTime()==1000);
   legacy.reset();
   ExpectTrue("legacy reset clears memory",!legacy.IsInitialized());

   if(g_failures==0)
      Print("NewCandleClassCheckerTests: PASS");
   else
      PrintFormat("NewCandleClassCheckerTests: FAIL failures=%d",g_failures);
  }
