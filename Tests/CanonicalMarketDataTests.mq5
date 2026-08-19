#property strict

#include "../RuntimeInputs/CanonicalMarketData.mqh"

int g_failures=0;

void ExpectTrue(const string name,const bool condition)
  {
   if(condition)
      return;
   ++g_failures;
   Print("FAIL: ",name);
  }

SCanonicalM1Bar FixtureBar(const datetime utc_time,
                           const double open,
                           const double high,
                           const double low,
                           const double close,
                           const int spread)
  {
   SCanonicalM1Bar value={};
   value.symbol="EURUSD_o";
   value.source_time=utc_time+7200;
   value.utc_time=utc_time;
   value.open=open;
   value.high=high;
   value.low=low;
   value.close=close;
   value.tick_volume=10;
   value.real_volume=1;
   value.spread_points=spread;
   value.complete=true;
   value.observed=true;
   return value;
  }

void TestClockConversion(void)
  {
   CServerUtcConverter converter;
   converter.SetParams(7200,10800);
   ExpectTrue("clock init",converter.Init());

   datetime utc_time=0;
   int offset=0;
   ENUM_CANONICAL_TIME_STATUS status=converter.Step(
      StringToTime("2026.01.15 12:00:00"),utc_time,offset);
   ExpectTrue("winter ready",status==CANONICAL_TIME_READY);
   ExpectTrue("winter UTC",utc_time==StringToTime("2026.01.15 10:00:00"));
   ExpectTrue("winter offset",offset==7200);

   status=converter.Step(StringToTime("2026.07.15 12:00:00"),utc_time,offset);
   ExpectTrue("summer ready",status==CANONICAL_TIME_READY);
   ExpectTrue("summer UTC",utc_time==StringToTime("2026.07.15 09:00:00"));
   ExpectTrue("summer offset",offset==10800);

   status=converter.Step(StringToTime("2026.10.25 03:30:00"),utc_time,offset);
   ExpectTrue("fall overlap rejected",status==CANONICAL_TIME_AMBIGUOUS);
   status=converter.Step(StringToTime("2026.03.29 03:30:00"),utc_time,offset);
   ExpectTrue("spring gap rejected",status==CANONICAL_TIME_NONEXISTENT);

   datetime server_time=0;
   status=converter.UtcToServer(StringToTime("2026.07.15 09:00:00"),
                                server_time,offset);
   ExpectTrue("UTC to summer server ready",status==CANONICAL_TIME_READY);
   ExpectTrue("UTC to summer server value",
              server_time==StringToTime("2026.07.15 12:00:00"));
   ExpectTrue("UTC to summer server offset",offset==10800);
  }

void TestExecutablePriceAndTicks(void)
  {
   string reason="";
   double mid=CanonicalExecutableMidPrice(1.1000,1.1002,reason);
   ExpectTrue("executable mid",MathAbs(mid-1.1001)<1e-12 && reason=="");
   mid=CanonicalExecutableMidPrice(1.1002,1.1000,reason);
   ExpectTrue("crossed quote rejected",mid==0.0 && reason!="");

   SCanonicalTick first={};
   first.time_msc=1000;
   first.bid=1.0;
   first.ask=1.1;
   SCanonicalTick same=first;
   ExpectTrue("exact duplicate",CanonicalTickRelation(first,same)==CANONICAL_TICK_EXACT_DUPLICATE);
   same.ask=1.2;
   ExpectTrue("same timestamp distinct",CanonicalTickRelation(first,same)==CANONICAL_TICK_SAME_TIME_DISTINCT);
   same.time_msc=999;
   ExpectTrue("out of order",CanonicalTickRelation(first,same)==CANONICAL_TICK_OUT_OF_ORDER);
  }

void TestAggregation(void)
  {
   datetime start=StringToTime("2026.01.15 10:00:00");
   CEventTimeframeAggregator aggregator;
   aggregator.SetParams(PERIOD_M15,start,start+900,15,0.00001);
   ExpectTrue("aggregator init",aggregator.Init("EURUSD_o",start-60,1.10000));

   double previous=1.10000;
   for(int i=0;i<15;++i)
     {
      double close=previous+0.00001;
      SCanonicalM1Bar bar=FixtureBar(start+i*60,previous,close+0.00002,
                                     previous-0.00002,close,2+i%3);
      ExpectTrue(StringFormat("aggregate step %d",i),aggregator.Step(bar));
      previous=close;
     }

   SCanonicalAggregatedBar output={};
   ExpectTrue("aggregate result",aggregator.Result(output));
   ExpectTrue("aggregate complete",output.complete);
   ExpectTrue("source count",output.source_count==15 && output.expected_source_count==15);
   ExpectTrue("OHLC open",MathAbs(output.open-1.10000)<1e-12);
   ExpectTrue("OHLC close",MathAbs(output.close-1.10015)<1e-12);
   ExpectTrue("volume sum",output.tick_volume==150 && output.real_volume==15);
   ExpectTrue("conservative spread",output.maximum_spread_points==4);
   ExpectTrue("endpoint",output.endpoint_time_utc==start+900);
   ExpectTrue("telescoping",output.telescoping_consistent);
  }

void TestSourceLifecycleDefaults(void)
  {
   CCanonicalM1Source source;
   source.SetParams("EURUSD_o",StringToTime("2026.08.01 00:00:00"),
                    StringToTime("2026.08.02 00:00:00"),7200,10800);
   ExpectTrue("source reset count",source.Count()==0);
   ExpectTrue("source reset synchronization",!source.Synchronized());
   ExpectTrue("source reset first time",source.FirstSourceTime()==0);
   ExpectTrue("source reset last time",source.LastSourceTime()==0);
   source.Reset();
   ExpectTrue("source explicit reset",source.Count()==0 && !source.Synchronized());
  }

void OnStart(void)
  {
   TestClockConversion();
   TestExecutablePriceAndTicks();
   TestAggregation();
   TestSourceLifecycleDefaults();
   if(g_failures==0)
      Print("CanonicalMarketDataTests: PASS");
   else
      PrintFormat("CanonicalMarketDataTests: FAIL failures=%d",g_failures);
  }
