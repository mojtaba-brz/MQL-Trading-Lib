#property strict

#include "../Correlation/CorrelationClass.mqh"

int g_failures=0;

void ExpectTrue(const string name,const bool condition)
  {
   if(condition)
      return;
   ++g_failures;
   Print("FAIL: ",name);
  }

void ExpectNear(const string name,const double actual,const double expected)
  {
   ExpectTrue(name,MathIsValidNumber(actual) && MathAbs(actual-expected)<1e-12);
  }

void TestLifecycle(void)
  {
   CorrelationCalculator calculator;
   ExpectTrue("params",calculator.SetParams(3));
   ExpectTrue("init",calculator.Init());
   ExpectTrue("empty before two",calculator.Value()==EMPTY_VALUE);
   ExpectTrue("first step",calculator.Step(1.0,2.0));
   ExpectTrue("count one",calculator.Count()==1 && !calculator.IsReady());
   ExpectTrue("second step",calculator.Step(2.0,4.0));
   ExpectNear("warmup correlation",calculator.Value(),1.0);
   ExpectTrue("third step",calculator.Step(3.0,6.0));
   ExpectTrue("ready",calculator.IsReady());
   ExpectNear("full correlation",calculator.Value(),1.0);
   ExpectTrue("rolling step",calculator.Step(4.0,8.0));
   ExpectNear("rolling correlation",calculator.Value(),1.0);
   calculator.Reset();
   ExpectTrue("reset",calculator.Count()==0 && !calculator.IsReady());
  }

void TestCompatibility(void)
  {
   CorrelationCalculator calculator(3);
   calculator.addData(1.0,3.0);
   calculator.addData(2.0,2.0);
   calculator.addData(3.0,1.0);
   ExpectNear("legacy methods",calculator.getCorrelation(),-1.0);
  }

void TestArrayStatistic(void)
  {
   double first[]={1.0,2.0,3.0,4.0};
   double second[]={8.0,6.0,4.0,2.0};
   ExpectNear("array Pearson",PearsonCorrelation(first,second,4),-1.0);
   double constant[]={1.0,1.0,1.0,1.0};
   ExpectTrue("constant rejected",PearsonCorrelation(first,constant,4)==EMPTY_VALUE);
  }

void TestClockWindow(void)
  {
   int minute=-1;
   ExpectTrue("parse",AssetCorrelationClockMinute("03:15",minute) && minute==195);
   ExpectTrue("bad clock",!AssetCorrelationClockMinute("25:00",minute));
   datetime value=StringToTime("2026.09.05 10:00:00");
   ExpectTrue("inside window",AssetCorrelationInClockWindow(value,180,720));
   ExpectTrue("outside window",!AssetCorrelationInClockWindow(value,900,1380));
  }

void OnStart(void)
  {
   TestLifecycle();
   TestCompatibility();
   TestArrayStatistic();
   TestClockWindow();
   if(g_failures==0)
      Print("PASS: CorrelationClassTests");
   else
      PrintFormat("FAILURES: %d",g_failures);
  }
