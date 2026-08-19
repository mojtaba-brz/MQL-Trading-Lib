#property strict
#property script_show_inputs

#include "../RuntimeInputs/CanonicalMarketData.mqh"

input string InpSymbols="XAUUSD_o;USDX;EURUSD_o;USDJPY_o;GBPUSD_o;USDCHF_o;USDCAD_o;AUDUSD_o;NZDUSD_o;USCRUDE;UKBRENT";
input datetime InpServerFrom=D'2026.08.01 00:00:00';
input datetime InpServerTo=D'2026.08.18 00:00:00';
input datetime InpValidationEventServerTime=D'2026.08.05 15:00:00';
input datetime InpOilRollServerFrom=D'2026.06.10 00:00:00';
input datetime InpOilRollServerTo=D'2026.08.18 00:00:00';
input int InpStandardUtcOffsetSeconds=7200;
input int InpDaylightUtcOffsetSeconds=10800;
input string InpBrokerProfile="LiteFinance|LiteFinance-MT5-Demo|ECN_LOW_SPREAD";
input int InpConnectionTimeoutSeconds=60;
input int InpHistorySyncAttempts=60;
input int InpHistorySyncDelayMs=1000;

bool WaitForTerminalConnection(void)
  {
   int attempts=MathMax(1,InpConnectionTimeoutSeconds+1);
   for(int attempt=0;attempt<attempts;++attempt)
     {
      if((bool)TerminalInfoInteger(TERMINAL_CONNECTED))
         return true;
      if(attempt+1<attempts)
         Sleep(1000);
     }
   return false;
  }

string SafeFilePart(string value)
  {
   StringReplace(value,"\\","-");
   StringReplace(value,"/","-");
   StringReplace(value,":","-");
   StringReplace(value,";","-");
   return value;
  }

string TimeOrUnavailable(const long value)
  {
   if(value<=0)
      return "UNAVAILABLE";
   return TimeToString((datetime)value,TIME_DATE|TIME_SECONDS);
  }

bool ResolveValidationEventUtc(datetime &event_utc)
  {
   CServerUtcConverter converter;
   converter.SetParams(InpStandardUtcOffsetSeconds,InpDaylightUtcOffsetSeconds);
   if(!converter.Init())
      return false;
   int offset=0;
   return converter.Step(InpValidationEventServerTime,event_utc,offset)==
          CANONICAL_TIME_READY;
  }

bool FindExecutableBaseline(const string symbol,
                            const datetime event_utc,
                            long &baseline_time_msc,
                            double &baseline_price)
  {
   baseline_time_msc=0;
   baseline_price=0.0;
   ulong event_msc=(ulong)event_utc*1000;
   ulong from_msc=(ulong)(event_utc-3600)*1000;
   for(int attempt=0;attempt<MathMax(1,InpHistorySyncAttempts);++attempt)
     {
      MqlTick ticks[];
      int count=CopyTicksRange(symbol,ticks,COPY_TICKS_INFO,from_msc,event_msc-1);
      for(int i=count-1;i>=0;--i)
        {
         string reason="";
         double price=CanonicalExecutableMidPrice(ticks[i].bid,ticks[i].ask,reason);
         if(price>0.0 && ticks[i].time_msc<(long)event_msc)
           {
            baseline_time_msc=ticks[i].time_msc;
            baseline_price=price;
            return true;
           }
        }
      if(attempt+1<InpHistorySyncAttempts && InpHistorySyncDelayMs>0)
         Sleep(InpHistorySyncDelayMs);
     }
   return false;
  }

bool WriteTrajectories(const string symbol,
                       const string output_folder,
                       const datetime event_utc,
                       const long baseline_time_msc,
                       const double baseline_price,
                       SCanonicalM1Bar &event_bars[])
  {
   string path=output_folder+"\\"+SafeFilePart(symbol)+"_trajectories.csv";
   int file=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(file==INVALID_HANDLE)
      return false;
   FileWrite(file,"record_type","symbol","timeframe","event_utc_epoch",
             "baseline_time_msc","baseline_price","interval_start_utc",
             "interval_end_utc","endpoint_time_utc","open","high","low",
             "close","tick_volume","real_volume","maximum_spread_points",
             "source_count","expected_source_count","signed_log_response",
             "telescoping_log_response","complete","telescoping_consistent",
             "generator_id","generator_version");

   CCanonicalSessionCalendar calendar;
   calendar.SetParams(symbol,InpStandardUtcOffsetSeconds,
                      InpDaylightUtcOffsetSeconds);
   bool all_passed=calendar.Init();
   ENUM_TIMEFRAMES timeframes[5]={PERIOD_M1,PERIOD_M15,PERIOD_H1,
                                  PERIOD_H4,PERIOD_D1};
   int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   for(int index=0;index<5;++index)
     {
      ENUM_TIMEFRAMES timeframe=timeframes[index];
      datetime interval_end=event_utc+PeriodSeconds(timeframe);
      int expected=calendar.CountOpenMinutes(event_utc,interval_end);
      CEventTimeframeAggregator aggregator;
      aggregator.SetParams(timeframe,event_utc,interval_end,expected,point);
      bool initialized=aggregator.Init(symbol,(datetime)(baseline_time_msc/1000),
                                       baseline_price);
      if(initialized)
        {
         int bar_count=ArraySize(event_bars);
         for(int bar_index=0;bar_index<bar_count;++bar_index)
            if(event_bars[bar_index].utc_time>=event_utc &&
               event_bars[bar_index].utc_time<interval_end)
               aggregator.Step(event_bars[bar_index]);
        }
      SCanonicalAggregatedBar output={};
      bool has_result=initialized && aggregator.Result(output);
      bool passed=has_result && output.complete &&
                  output.telescoping_consistent &&
                  output.endpoint_time_utc==interval_end;
      all_passed=(all_passed && passed);
      FileWrite(file,"TRAJECTORY",symbol,EnumToString(timeframe),(long)event_utc,
                baseline_time_msc,DoubleToString(baseline_price,digits),
                (long)event_utc,(long)interval_end,
                has_result ? (long)output.endpoint_time_utc : 0,
                has_result ? DoubleToString(output.open,digits) : "",
                has_result ? DoubleToString(output.high,digits) : "",
                has_result ? DoubleToString(output.low,digits) : "",
                has_result ? DoubleToString(output.close,digits) : "",
                has_result ? output.tick_volume : 0,
                has_result ? output.real_volume : 0,
                has_result ? output.maximum_spread_points : 0,
                has_result ? output.source_count : 0,expected,
                has_result ? DoubleToString(output.signed_log_response,16) : "",
                has_result ? DoubleToString(output.telescoping_log_response,16) : "",
                has_result ? output.complete : false,
                has_result ? output.telescoping_consistent : false,
                CANONICAL_MARKET_DATA_GENERATOR_ID,
                CANONICAL_MARKET_DATA_GENERATOR_VERSION);
     }
   FileClose(file);
   return all_passed;
  }

SCanonicalM1Bar ParityBar(const datetime utc_time,
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
   return value;
  }

bool WriteParityFixture(const string output_folder)
  {
   string path=output_folder+"\\_mql_parity_fixture.csv";
   int file=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(file==INVALID_HANDLE)
      return false;
   FileWrite(file,"key","value");

   CServerUtcConverter converter;
   converter.SetParams(7200,10800);
   bool passed=converter.Init();
   datetime utc_time=0;
   int offset=0;
   ENUM_CANONICAL_TIME_STATUS status=converter.Step(
      StringToTime("2026.01.15 12:00:00"),utc_time,offset);
   FileWrite(file,"winter_status",EnumToString(status));
   FileWrite(file,"winter_utc_epoch",(long)utc_time);
   FileWrite(file,"winter_offset_seconds",offset);
   passed=(passed && status==CANONICAL_TIME_READY &&
           utc_time==StringToTime("2026.01.15 10:00:00") && offset==7200);
   status=converter.Step(StringToTime("2026.07.15 12:00:00"),utc_time,offset);
   FileWrite(file,"summer_status",EnumToString(status));
   FileWrite(file,"summer_utc_epoch",(long)utc_time);
   FileWrite(file,"summer_offset_seconds",offset);
   passed=(passed && status==CANONICAL_TIME_READY &&
           utc_time==StringToTime("2026.07.15 09:00:00") && offset==10800);
   status=converter.Step(StringToTime("2026.03.29 03:30:00"),utc_time,offset);
   FileWrite(file,"spring_status",EnumToString(status));
   passed=(passed && status==CANONICAL_TIME_NONEXISTENT);
   status=converter.Step(StringToTime("2026.10.25 03:30:00"),utc_time,offset);
   FileWrite(file,"autumn_status",EnumToString(status));
   passed=(passed && status==CANONICAL_TIME_AMBIGUOUS);

   datetime start=StringToTime("2026.01.15 10:00:00");
   CEventTimeframeAggregator aggregator;
   aggregator.SetParams(PERIOD_M15,start,start+900,15,0.00001);
   bool initialized=aggregator.Init("EURUSD_o",start-60,1.10000);
   double previous=1.10000;
   for(int i=0;i<15 && initialized;++i)
     {
      double close=previous+0.00001;
      SCanonicalM1Bar bar=ParityBar(start+i*60,previous,close+0.00002,
                                    previous-0.00002,close,2+i%3);
      initialized=aggregator.Step(bar);
      previous=close;
     }
   SCanonicalAggregatedBar output={};
   bool has_result=initialized && aggregator.Result(output);
   FileWrite(file,"trajectory_source_count",has_result ? output.source_count : 0);
   FileWrite(file,"trajectory_expected_source_count",
             has_result ? output.expected_source_count : 0);
   FileWrite(file,"trajectory_close",
             has_result ? DoubleToString(output.close,5) : "");
   FileWrite(file,"trajectory_endpoint_utc",
             has_result ? (long)output.endpoint_time_utc : 0);
   FileWrite(file,"trajectory_complete",has_result ? output.complete : false);
   FileWrite(file,"trajectory_telescoping_consistent",
             has_result ? output.telescoping_consistent : false);
   passed=(passed && has_result && output.complete &&
           output.telescoping_consistent);
   FileWrite(file,"passed",passed);
   FileWrite(file,"generator_id",CANONICAL_MARKET_DATA_GENERATOR_ID);
   FileWrite(file,"generator_version",CANONICAL_MARKET_DATA_GENERATOR_VERSION);
   FileClose(file);
   return passed;
  }

void WriteSessions(const int file,const string symbol)
  {
   for(int day=0;day<7;++day)
     {
      for(uint index=0;;++index)
        {
         datetime session_from=0;
         datetime session_to=0;
         if(!SymbolInfoSessionQuote(symbol,(ENUM_DAY_OF_WEEK)day,index,
                                    session_from,session_to))
            break;
         FileWrite(file,StringFormat("quote_session_%d_%u",day,index),
                   TimeToString(session_from,TIME_MINUTES)+"-"+
                   TimeToString(session_to,TIME_MINUTES));
        }
      for(uint index=0;;++index)
        {
         datetime session_from=0;
         datetime session_to=0;
         if(!SymbolInfoSessionTrade(symbol,(ENUM_DAY_OF_WEEK)day,index,
                                    session_from,session_to))
            break;
         FileWrite(file,StringFormat("trade_session_%d_%u",day,index),
                   TimeToString(session_from,TIME_MINUTES)+"-"+
                   TimeToString(session_to,TIME_MINUTES));
        }
     }
  }

bool WriteSymbol(const string symbol,const string output_folder)
  {
   datetime event_utc=0;
   if(!ResolveValidationEventUtc(event_utc))
      return false;
   long baseline_time_msc=0;
   double baseline_price=0.0;
   if(!FindExecutableBaseline(symbol,event_utc,baseline_time_msc,baseline_price))
     {
      PrintFormat("Phase2 exporter: no executable baseline tick for %s",symbol);
      return false;
     }

   CCanonicalM1Source source;
   source.SetParams(symbol,InpServerFrom,InpServerTo,
                    InpStandardUtcOffsetSeconds,InpDaylightUtcOffsetSeconds,
                    InpHistorySyncAttempts,InpHistorySyncDelayMs);
   if(!source.Init())
     {
      PrintFormat("Phase2 exporter: cannot initialize %s, error=%d",symbol,GetLastError());
      return false;
     }

   string path=output_folder+"\\"+SafeFilePart(symbol)+"_M1.csv";
   int file=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(file==INVALID_HANDLE)
     {
      PrintFormat("Phase2 exporter: cannot open %s, error=%d",path,GetLastError());
      return false;
     }

   FileWrite(file,"record_type","symbol","source_server_time","utc_epoch",
             "utc_time","open","high","low","close","tick_volume",
             "spread_points","real_volume","complete","observed",
             "source_timezone","conversion_rule","generator_id",
             "generator_version");

   SCanonicalM1Bar bar={};
   SCanonicalM1Bar event_bars[];
   CCanonicalM1Normalizer normalizer;
   normalizer.SetParams(symbol,InpStandardUtcOffsetSeconds,
                        InpDaylightUtcOffsetSeconds);
   if(!normalizer.Init())
     {
      FileClose(file);
      return false;
     }
   ENUM_CANONICAL_TIME_STATUS time_status=CANONICAL_TIME_INVALID;
   int written=0;
   int canonical_count=0;
   int synthetic_count=0;
   while(written<source.Count())
     {
      if(!source.Step(bar,time_status))
        {
         if(time_status==CANONICAL_TIME_AMBIGUOUS ||
            time_status==CANONICAL_TIME_NONEXISTENT)
           {
            FileWrite(file,"CLOCK_REJECTION",symbol,
                      TimeToString(bar.source_time,TIME_DATE|TIME_SECONDS),0,"",
                      0,0,0,0,0,0,0,false,false,bar.source_timezone,
                      bar.conversion_rule,bar.generator_id,bar.generator_version);
            ++written;
            continue;
           }
         break;
        }
      SCanonicalM1Bar normalized[];
      if(!normalizer.Step(bar,normalized))
        {
         FileClose(file);
         return false;
        }
      int normalized_count=ArraySize(normalized);
      for(int normalized_index=0;normalized_index<normalized_count;
          ++normalized_index)
        {
         SCanonicalM1Bar current=normalized[normalized_index];
         FileWrite(file,"M1",current.symbol,
                   TimeToString(current.source_time,TIME_DATE|TIME_SECONDS),
                   (long)current.utc_time,
                   TimeToString(current.utc_time,TIME_DATE|TIME_SECONDS),
                   DoubleToString(current.open,
                                  (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                   DoubleToString(current.high,
                                  (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                   DoubleToString(current.low,
                                  (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                   DoubleToString(current.close,
                                  (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                   current.tick_volume,current.spread_points,current.real_volume,
                   current.complete,current.observed,current.source_timezone,
                   current.conversion_rule,current.generator_id,
                   current.generator_version);
         ++canonical_count;
         if(!current.observed)
            ++synthetic_count;
         if(current.utc_time>=event_utc && current.utc_time<event_utc+86400)
           {
            int event_count=ArraySize(event_bars);
            ArrayResize(event_bars,event_count+1);
            event_bars[event_count]=current;
           }
        }
      ++written;
     }
   FileClose(file);

   bool trajectories_passed=WriteTrajectories(symbol,output_folder,event_utc,
                                               baseline_time_msc,baseline_price,
                                               event_bars);

   string metadata_path=output_folder+"\\"+SafeFilePart(symbol)+"_metadata.csv";
   int metadata=FileOpen(metadata_path,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(metadata==INVALID_HANDLE)
      return false;
   FileWrite(metadata,"key","value");
   FileWrite(metadata,"broker_profile",InpBrokerProfile);
   // Account identity is required to keep Demo, Real, Standard, and ECN feeds
   // separate. Login and account-holder name are intentionally not exported.
   FileWrite(metadata,"account_company",AccountInfoString(ACCOUNT_COMPANY));
   FileWrite(metadata,"account_server",AccountInfoString(ACCOUNT_SERVER));
   FileWrite(metadata,"account_currency",AccountInfoString(ACCOUNT_CURRENCY));
   FileWrite(metadata,"account_trade_mode",
             EnumToString((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)));
   FileWrite(metadata,"account_trade_mode_value",AccountInfoInteger(ACCOUNT_TRADE_MODE));
   FileWrite(metadata,"account_margin_mode",
             EnumToString((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)));
   FileWrite(metadata,"account_margin_mode_value",AccountInfoInteger(ACCOUNT_MARGIN_MODE));
   FileWrite(metadata,"terminal_connected",TerminalInfoInteger(TERMINAL_CONNECTED));
   FileWrite(metadata,"series_synchronized",source.Synchronized());
   FileWrite(metadata,"exported_m1_count",source.Count());
   FileWrite(metadata,"canonical_m1_count",canonical_count);
   FileWrite(metadata,"synthetic_open_minute_count",synthetic_count);
   FileWrite(metadata,"exported_server_first",TimeOrUnavailable(source.FirstSourceTime()));
   FileWrite(metadata,"exported_server_last",TimeOrUnavailable(source.LastSourceTime()));
   FileWrite(metadata,"validation_event_server_time",
             TimeToString(InpValidationEventServerTime,TIME_DATE|TIME_SECONDS));
   FileWrite(metadata,"validation_event_utc_epoch",(long)event_utc);
   FileWrite(metadata,"baseline_time_msc",baseline_time_msc);
   FileWrite(metadata,"baseline_price",
             DoubleToString(baseline_price,
                            (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)));
   FileWrite(metadata,"trajectories_passed",trajectories_passed);
   FileWrite(metadata,"symbol",symbol);
   FileWrite(metadata,"description",SymbolInfoString(symbol,SYMBOL_DESCRIPTION));
   FileWrite(metadata,"path",SymbolInfoString(symbol,SYMBOL_PATH));
   FileWrite(metadata,"currency_base",SymbolInfoString(symbol,SYMBOL_CURRENCY_BASE));
   FileWrite(metadata,"currency_profit",SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT));
   FileWrite(metadata,"digits",SymbolInfoInteger(symbol,SYMBOL_DIGITS));
   FileWrite(metadata,"point",DoubleToString(SymbolInfoDouble(symbol,SYMBOL_POINT),10));
   FileWrite(metadata,"tick_size",DoubleToString(SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE),10));
   FileWrite(metadata,"contract_size",DoubleToString(SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE),8));
   FileWrite(metadata,"chart_mode",SymbolInfoInteger(symbol,SYMBOL_CHART_MODE));
   FileWrite(metadata,"trade_calc_mode",SymbolInfoInteger(symbol,SYMBOL_TRADE_CALC_MODE));
   FileWrite(metadata,"start_time",TimeOrUnavailable(SymbolInfoInteger(symbol,SYMBOL_START_TIME)));
   FileWrite(metadata,"expiration_time",TimeOrUnavailable(SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_TIME)));
   FileWrite(metadata,"expiration_mode",SymbolInfoInteger(symbol,SYMBOL_EXPIRATION_MODE));
   WriteSessions(metadata,symbol);
   FileWrite(metadata,"requested_server_from",TimeToString(InpServerFrom,TIME_DATE|TIME_SECONDS));
   FileWrite(metadata,"requested_server_to",TimeToString(InpServerTo,TIME_DATE|TIME_SECONDS));
   FileWrite(metadata,"standard_utc_offset_seconds",InpStandardUtcOffsetSeconds);
   FileWrite(metadata,"daylight_utc_offset_seconds",InpDaylightUtcOffsetSeconds);
   FileWrite(metadata,"terminal_build",TerminalInfoInteger(TERMINAL_BUILD));
   FileWrite(metadata,"generated_at_server",TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS));
   FileWrite(metadata,"generated_at_utc",TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS));
   FileWrite(metadata,"generator_id",CANONICAL_MARKET_DATA_GENERATOR_ID);
   FileWrite(metadata,"generator_version",CANONICAL_MARKET_DATA_GENERATOR_VERSION);
   FileClose(metadata);
   return trajectories_passed;
  }

bool WriteOilRollSeries(const string symbol,const string output_folder)
  {
   CCanonicalM1Source source;
   source.SetParams(symbol,InpOilRollServerFrom,InpOilRollServerTo,
                    InpStandardUtcOffsetSeconds,InpDaylightUtcOffsetSeconds,
                    InpHistorySyncAttempts,InpHistorySyncDelayMs);
   if(!source.Init())
      return false;
   string path=output_folder+"\\"+SafeFilePart(symbol)+"_roll_M1.csv";
   int file=FileOpen(path,FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(file==INVALID_HANDLE)
      return false;
   FileWrite(file,"record_type","symbol","source_server_time","utc_epoch",
             "open","high","low","close","tick_volume","spread_points",
             "real_volume","generator_id","generator_version");
   SCanonicalM1Bar bar={};
   ENUM_CANONICAL_TIME_STATUS status=CANONICAL_TIME_INVALID;
   int processed=0;
   int exported=0;
   while(processed<source.Count())
     {
      if(!source.Step(bar,status))
        {
         ++processed;
         continue;
        }
      FileWrite(file,"M1",symbol,
                TimeToString(bar.source_time,TIME_DATE|TIME_SECONDS),
                (long)bar.utc_time,
                DoubleToString(bar.open,
                               (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                DoubleToString(bar.high,
                               (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                DoubleToString(bar.low,
                               (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                DoubleToString(bar.close,
                               (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS)),
                bar.tick_volume,bar.spread_points,bar.real_volume,
                bar.generator_id,bar.generator_version);
      ++processed;
      ++exported;
     }
   FileClose(file);
   return source.Synchronized() && exported==source.Count() && exported>0;
  }

void WriteExportManifest(const string output_folder,
                         const int requested,
                         const int succeeded,
                         const bool parity_passed,
                         const bool wti_roll_exported,
                         const bool brent_roll_exported)
  {
   int file=FileOpen(output_folder+"\\_export_manifest.csv",
                     FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(file==INVALID_HANDLE)
      return;
   FileWrite(file,"key","value");
   FileWrite(file,"requested_symbols",requested);
   FileWrite(file,"succeeded_symbols",succeeded);
   FileWrite(file,"parity_passed",parity_passed);
   FileWrite(file,"wti_roll_exported",wti_roll_exported);
   FileWrite(file,"brent_roll_exported",brent_roll_exported);
   FileWrite(file,"terminal_connected",TerminalInfoInteger(TERMINAL_CONNECTED));
   FileWrite(file,"account_server",AccountInfoString(ACCOUNT_SERVER));
   FileWrite(file,"account_trade_mode",
             EnumToString((ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE)));
   FileWrite(file,"generator_id",CANONICAL_MARKET_DATA_GENERATOR_ID);
   FileWrite(file,"generator_version",CANONICAL_MARKET_DATA_GENERATOR_VERSION);
   FileClose(file);
  }

void OnStart(void)
  {
   if(!WaitForTerminalConnection())
     {
      PrintFormat("Phase2 exporter: terminal did not connect within %d seconds",
                  InpConnectionTimeoutSeconds);
      return;
     }

   string output_folder="BanksEffects\\Phase2\\"+
                        TimeToString(TimeGMT(),TIME_DATE|TIME_SECONDS);
   StringReplace(output_folder,".","");
   StringReplace(output_folder,":","");
   StringReplace(output_folder," ","_");
   // FolderCreate can return false when the folder already exists. The portable
   // success test is whether the per-symbol FileOpen calls succeed.
   ResetLastError();
   FolderCreate("BanksEffects",FILE_COMMON);
   FolderCreate("BanksEffects\\Phase2",FILE_COMMON);
   FolderCreate(output_folder,FILE_COMMON);

   string symbols[];
   int count=StringSplit(InpSymbols,';',symbols);
   bool parity_passed=WriteParityFixture(output_folder);
   int succeeded=0;
   for(int i=0;i<count;++i)
     {
      StringTrimLeft(symbols[i]);
      StringTrimRight(symbols[i]);
      if(symbols[i]!="" && WriteSymbol(symbols[i],output_folder))
         ++succeeded;
     }
   bool wti_roll_exported=WriteOilRollSeries("USCRUDE",output_folder);
   bool brent_roll_exported=WriteOilRollSeries("UKBRENT",output_folder);
   WriteExportManifest(output_folder,count,succeeded,parity_passed,
                       wti_roll_exported,brent_roll_exported);
   PrintFormat("BanksEffects Phase2 export complete: %d/%d symbols; Common\\Files\\%s",
               succeeded,count,output_folder);
  }
