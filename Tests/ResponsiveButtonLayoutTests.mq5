//+------------------------------------------------------------------+
//|                            ResponsiveButtonLayoutTests.mq5       |
//+------------------------------------------------------------------+
#property script_show_inputs
#property version "1.000"
#property strict

#include "../Dashboard/ResponsiveButtonLayout.mqh"

int g_failures=0;

void ExpectTrue(const string test_name,const bool condition)
  {
   if(condition)
      Print("PASS: ",test_name);
   else
     {
      Print("FAIL: ",test_name);
      ++g_failures;
     }
  }

void ExpectEqual(const string test_name,const int actual,const int expected)
  {
   if(actual == expected)
      Print("PASS: ",test_name);
   else
     {
      PrintFormat("FAIL: %s actual=%d expected=%d",test_name,actual,expected);
      ++g_failures;
     }
  }

void OnStart()
  {
   SResponsiveButtonLayout layout={};
   ExpectTrue("configure narrow lower-right",
              ConfigureResponsiveButtonLayout(4,346,CORNER_RIGHT_LOWER,
                                               10,175,20,92,22,4,4,layout));
   ExpectEqual("narrow columns",layout.columns,3);
   ExpectEqual("narrow rows",layout.rows,2);

   int x=0;
   int y=0;
   ExpectTrue("position first narrow button",ResponsiveButtonPosition(layout,0,x,y));
   ExpectEqual("first narrow x",x,294);
   ExpectEqual("first narrow y",y,68);
   ExpectTrue("position third narrow button",ResponsiveButtonPosition(layout,2,x,y));
   ExpectEqual("third narrow x",x,102);
   ExpectEqual("third narrow y",y,68);
   ExpectTrue("position wrapped narrow button",ResponsiveButtonPosition(layout,3,x,y));
   ExpectEqual("wrapped narrow x",x,102);
   ExpectEqual("wrapped narrow y",y,42);

   ExpectTrue("configure wide upper-left",
              ConfigureResponsiveButtonLayout(4,800,CORNER_LEFT_UPPER,
                                               10,175,20,92,22,4,4,layout));
   ExpectEqual("wide columns",layout.columns,4);
   ExpectEqual("wide rows",layout.rows,1);
   ExpectTrue("position final wide button",ResponsiveButtonPosition(layout,3,x,y));
   ExpectEqual("final wide x",x,298);
   ExpectEqual("final wide y",y,175);

   ExpectTrue("reject invalid item count",
              !ConfigureResponsiveButtonLayout(0,800,CORNER_LEFT_UPPER,
                                                10,175,20,92,22,4,4,layout));
   ExpectTrue("reject invalid position",!ResponsiveButtonPosition(layout,0,x,y));

   if(g_failures == 0)
      Print("ResponsiveButtonLayoutTests: PASS");
   else
      PrintFormat("ResponsiveButtonLayoutTests: FAIL failures=%d",g_failures);
  }
