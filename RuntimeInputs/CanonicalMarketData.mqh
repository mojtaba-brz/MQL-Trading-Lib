#ifndef MQLTRADINGLIB_CANONICAL_MARKET_DATA_MQH
#define MQLTRADINGLIB_CANONICAL_MARKET_DATA_MQH

#include "RuntimeInputContracts.mqh"

#define CANONICAL_MARKET_DATA_GENERATOR_ID "MQLTradingLib.CanonicalMarketData"
#define CANONICAL_MARKET_DATA_GENERATOR_VERSION "1.2.0"

enum ENUM_CANONICAL_TIME_STATUS
  {
   CANONICAL_TIME_INVALID=0,
   CANONICAL_TIME_READY=1,
   CANONICAL_TIME_AMBIGUOUS=2,
   CANONICAL_TIME_NONEXISTENT=3
  };

enum ENUM_CANONICAL_TICK_RELATION
  {
   CANONICAL_TICK_OUT_OF_ORDER=-1,
   CANONICAL_TICK_EXACT_DUPLICATE=0,
   CANONICAL_TICK_ORDERED=1,
   CANONICAL_TICK_SAME_TIME_DISTINCT=2
  };

struct SCanonicalTick
  {
   long              time_msc;
   double            bid;
   double            ask;
   double            last;
   ulong             volume;
   uint              flags;
  };

struct SCanonicalM1Bar
  {
   string            symbol;
   datetime          source_time;
   datetime          utc_time;
   double            open;
   double            high;
   double            low;
   double            close;
   long              tick_volume;
   int               spread_points;
   long              real_volume;
   bool              complete;
   bool              observed;
   string            source_timezone;
   string            conversion_rule;
   string            generator_id;
   string            generator_version;
  };

struct SCanonicalAggregatedBar
  {
   string            symbol;
   ENUM_TIMEFRAMES   timeframe;
   datetime          interval_start_utc;
   datetime          interval_end_utc;
   datetime          baseline_time_utc;
   datetime          endpoint_time_utc;
   double            baseline_price;
   double            open;
   double            high;
   double            low;
   double            close;
   long              tick_volume;
   long              real_volume;
   int               maximum_spread_points;
   int               source_count;
   int               expected_source_count;
   double            signed_log_response;
   double            telescoping_log_response;
   bool              complete;
   bool              telescoping_consistent;
   string            generator_id;
   string            generator_version;
  };

int CanonicalDaysInMonth(const int year,const int month)
  {
   if(month==2)
      return ((year%4==0 && year%100!=0) || year%400==0) ? 29 : 28;
   if(month==4 || month==6 || month==9 || month==11)
      return 30;
   return 31;
  }

datetime CanonicalLastSundayUtc(const int year,const int month,const int hour)
  {
   MqlDateTime value={};
   value.year=year;
   value.mon=month;
   value.day=CanonicalDaysInMonth(year,month);
   value.hour=hour;
   datetime candidate=StructToTime(value);
   MqlDateTime decoded={};
   if(!TimeToStruct(candidate,decoded))
      return 0;
   return candidate-(decoded.day_of_week*86400);
  }

double CanonicalExecutableMidPrice(const double bid,
                                   const double ask,
                                   string &reason)
  {
   reason="";
   if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || bid<=0.0 || ask<=0.0)
     {
      reason="bid_and_ask_must_be_positive_finite_values";
      return 0.0;
     }
   if(ask<bid)
     {
      reason="ask_is_below_bid";
      return 0.0;
     }
   return 0.5*(bid+ask);
  }

ENUM_CANONICAL_TICK_RELATION CanonicalTickRelation(const SCanonicalTick &previous,
                                                   const SCanonicalTick &candidate)
  {
   if(candidate.time_msc<previous.time_msc)
      return CANONICAL_TICK_OUT_OF_ORDER;
   if(candidate.time_msc>previous.time_msc)
      return CANONICAL_TICK_ORDERED;
   if(candidate.bid==previous.bid && candidate.ask==previous.ask &&
      candidate.last==previous.last && candidate.volume==previous.volume &&
      candidate.flags==previous.flags)
      return CANONICAL_TICK_EXACT_DUPLICATE;
   return CANONICAL_TICK_SAME_TIME_DISTINCT;
  }

// Converts a broker's EET/EEST-style wall clock without assuming one fixed
// offset across history. The EU transition instants are evaluated in UTC.
class CServerUtcConverter
  {
private:
   int               _standard_offset_seconds;
   int               _daylight_offset_seconds;
   bool              _initialized;

   int OffsetAtUtc(const datetime utc_time) const
     {
      MqlDateTime decoded={};
      if(!TimeToStruct(utc_time,decoded))
         return 0;
      datetime daylight_start=CanonicalLastSundayUtc(decoded.year,3,1);
      datetime daylight_end=CanonicalLastSundayUtc(decoded.year,10,1);
      if(utc_time>=daylight_start && utc_time<daylight_end)
         return _daylight_offset_seconds;
      return _standard_offset_seconds;
     }

public:
                     CServerUtcConverter(void)
     {
      _standard_offset_seconds=0;
      _daylight_offset_seconds=0;
      _initialized=false;
     }

   void SetParams(const int standard_offset_seconds,
                  const int daylight_offset_seconds)
     {
      _standard_offset_seconds=standard_offset_seconds;
      _daylight_offset_seconds=daylight_offset_seconds;
      Reset();
     }

   bool Init(void)
     {
      _initialized=(_standard_offset_seconds>=-43200 &&
                    _standard_offset_seconds<=50400 &&
                    _daylight_offset_seconds>=-43200 &&
                    _daylight_offset_seconds<=50400);
      return _initialized;
     }

   void Reset(void)
     {
      _initialized=false;
     }

   ENUM_CANONICAL_TIME_STATUS Step(const datetime source_server_time,
                                   datetime &utc_time,
                                   int &applied_offset_seconds) const
     {
      utc_time=0;
      applied_offset_seconds=0;
      if(!_initialized || source_server_time<=0)
         return CANONICAL_TIME_INVALID;

      datetime standard_candidate=source_server_time-_standard_offset_seconds;
      datetime daylight_candidate=source_server_time-_daylight_offset_seconds;
      bool standard_valid=(OffsetAtUtc(standard_candidate)==_standard_offset_seconds);
      bool daylight_valid=(OffsetAtUtc(daylight_candidate)==_daylight_offset_seconds);

      if(_standard_offset_seconds==_daylight_offset_seconds)
        {
         utc_time=standard_candidate;
         applied_offset_seconds=_standard_offset_seconds;
         return CANONICAL_TIME_READY;
        }
      if(standard_valid && daylight_valid)
         return CANONICAL_TIME_AMBIGUOUS;
      if(!standard_valid && !daylight_valid)
         return CANONICAL_TIME_NONEXISTENT;

      if(daylight_valid)
        {
         utc_time=daylight_candidate;
         applied_offset_seconds=_daylight_offset_seconds;
        }
      else
        {
         utc_time=standard_candidate;
         applied_offset_seconds=_standard_offset_seconds;
        }
      return CANONICAL_TIME_READY;
     }

   ENUM_CANONICAL_TIME_STATUS UtcToServer(const datetime utc_time,
                                          datetime &server_time,
                                          int &applied_offset_seconds) const
     {
      server_time=0;
      applied_offset_seconds=0;
      if(!_initialized || utc_time<=0)
         return CANONICAL_TIME_INVALID;
      applied_offset_seconds=OffsetAtUtc(utc_time);
      server_time=utc_time+applied_offset_seconds;
      return CANONICAL_TIME_READY;
     }
  };

class CCanonicalSessionCalendar
  {
private:
   string            _symbol;
   bool              _initialized;
   CServerUtcConverter _converter;

   int SecondsOfDay(const datetime value) const
     {
      MqlDateTime decoded={};
      if(!TimeToStruct(value,decoded))
         return -1;
      return decoded.hour*3600+decoded.min*60+decoded.sec;
     }

public:
                     CCanonicalSessionCalendar(void)
     {
      _symbol="";
      _initialized=false;
     }

   void SetParams(const string symbol,
                  const int standard_offset_seconds,
                  const int daylight_offset_seconds)
     {
      _symbol=symbol;
      _converter.SetParams(standard_offset_seconds,daylight_offset_seconds);
      Reset();
     }

   bool Init(void)
     {
      Reset();
      _initialized=(_symbol!="" && SymbolSelect(_symbol,true) &&
                    _converter.Init());
      return _initialized;
     }

   void Reset(void)
     {
      _initialized=false;
      _converter.Reset();
     }

   bool Step(const datetime utc_time) const
     {
      if(!_initialized)
         return false;
      datetime server_time=0;
      int offset=0;
      if(_converter.UtcToServer(utc_time,server_time,offset)!=CANONICAL_TIME_READY)
         return false;
      MqlDateTime decoded={};
      if(!TimeToStruct(server_time,decoded))
         return false;
      int second_of_day=decoded.hour*3600+decoded.min*60+decoded.sec;
      for(uint index=0;;++index)
        {
         datetime session_from=0;
         datetime session_to=0;
         if(!SymbolInfoSessionQuote(_symbol,(ENUM_DAY_OF_WEEK)decoded.day_of_week,
                                    index,session_from,session_to))
            break;
         int from_second=SecondsOfDay(session_from);
         int to_second=SecondsOfDay(session_to);
         if(from_second<0 || to_second<0)
            continue;
         if(to_second==0 && session_to>session_from)
            to_second=86400;
         if(from_second==to_second)
            return true;
         if(from_second<to_second && second_of_day>=from_second &&
            second_of_day<=to_second)
            return true;
         if(from_second>to_second && (second_of_day>=from_second ||
                                      second_of_day<to_second))
            return true;
        }
      return false;
     }

   int CountOpenMinutes(const datetime interval_start_utc,
                        const datetime interval_end_utc) const
     {
      if(!_initialized || interval_start_utc<=0 ||
         interval_end_utc<=interval_start_utc)
         return 0;
      int count=0;
      for(datetime value=interval_start_utc;value<interval_end_utc;value+=60)
         if(Step(value))
            ++count;
      return count;
     }
  };

class CCanonicalM1Source
  {
private:
   string            _symbol;
   datetime          _server_from;
   datetime          _server_to;
   int               _index;
   int               _count;
   int               _max_sync_attempts;
   int               _sync_delay_ms;
   bool              _synchronized;
   datetime          _first_source_time;
   datetime          _last_source_time;
   bool              _initialized;
   MqlRates          _rates[];
   CServerUtcConverter _converter;

public:
                     CCanonicalM1Source(void)
     {
      _symbol="";
      _server_from=0;
      _server_to=0;
      _index=0;
      _count=0;
      _max_sync_attempts=1;
      _sync_delay_ms=0;
      _synchronized=false;
      _first_source_time=0;
      _last_source_time=0;
      _initialized=false;
     }

   void SetParams(const string symbol,
                  const datetime server_from,
                  const datetime server_to,
                  const int standard_offset_seconds,
                  const int daylight_offset_seconds)
     {
      SetParams(symbol,server_from,server_to,standard_offset_seconds,
                daylight_offset_seconds,1,0);
     }

   void SetParams(const string symbol,
                  const datetime server_from,
                  const datetime server_to,
                  const int standard_offset_seconds,
                  const int daylight_offset_seconds,
                  const int max_sync_attempts,
                  const int sync_delay_ms)
     {
      _symbol=symbol;
      _server_from=server_from;
      _server_to=server_to;
      _max_sync_attempts=MathMax(1,max_sync_attempts);
      _sync_delay_ms=MathMax(0,sync_delay_ms);
      _converter.SetParams(standard_offset_seconds,daylight_offset_seconds);
      Reset();
     }

   bool Init(void)
     {
      Reset();
      if(_symbol=="" || _server_from<=0 || _server_to<=_server_from)
         return false;
      if(!_converter.Init() || !SymbolSelect(_symbol,true))
         return false;
      ArraySetAsSeries(_rates,false);
      for(int attempt=0;attempt<_max_sync_attempts;++attempt)
        {
         ResetLastError();
         _count=CopyRates(_symbol,PERIOD_M1,_server_from,_server_to,_rates);
         _synchronized=(bool)SeriesInfoInteger(_symbol,PERIOD_M1,
                                               SERIES_SYNCHRONIZED);
         if(_count>0 && _synchronized)
           {
            _first_source_time=_rates[0].time;
            _last_source_time=_rates[_count-1].time;
            _initialized=true;
            return true;
           }
         if(attempt+1<_max_sync_attempts && _sync_delay_ms>0)
            Sleep(_sync_delay_ms);
        }
      return false;
     }

   void Reset(void)
     {
      _index=0;
      _count=0;
      _synchronized=false;
      _first_source_time=0;
      _last_source_time=0;
      _initialized=false;
      ArrayFree(_rates);
      _converter.Reset();
     }

   bool Step(SCanonicalM1Bar &output,
             ENUM_CANONICAL_TIME_STATUS &time_status)
     {
      ZeroMemory(output);
      time_status=CANONICAL_TIME_INVALID;
      if(!_initialized || _index>=_count)
         return false;

      MqlRates source=_rates[_index++];
      output.symbol=_symbol;
      output.source_time=source.time;
      output.source_timezone="broker_server_wall_clock";
      output.generator_id=CANONICAL_MARKET_DATA_GENERATOR_ID;
      output.generator_version=CANONICAL_MARKET_DATA_GENERATOR_VERSION;
      datetime utc_time=0;
      int applied_offset=0;
      time_status=_converter.Step(source.time,utc_time,applied_offset);
      if(time_status!=CANONICAL_TIME_READY)
        {
         output.conversion_rule=EnumToString(time_status);
         return false;
        }

      output.utc_time=utc_time;
      output.open=source.open;
      output.high=source.high;
      output.low=source.low;
      output.close=source.close;
      output.tick_volume=source.tick_volume;
      output.spread_points=source.spread;
      output.real_volume=source.real_volume;
      output.complete=(source.time+60<=_server_to);
      output.observed=true;
      output.conversion_rule=StringFormat("EU_last_Sunday_offset_%d",applied_offset);
      return true;
     }

   int Count(void) const
     {
      return _count;
     }

   bool Synchronized(void) const
     {
      return _synchronized;
     }

   datetime FirstSourceTime(void) const
     {
      return _first_source_time;
     }

   datetime LastSourceTime(void) const
     {
      return _last_source_time;
     }
  };

class CCanonicalM1Normalizer
  {
private:
   string            _symbol;
   bool              _initialized;
   bool              _has_previous;
   SCanonicalM1Bar   _previous;
   CCanonicalSessionCalendar _calendar;
   CServerUtcConverter _converter;

   void Append(SCanonicalM1Bar &values[],const SCanonicalM1Bar &value) const
     {
      int count=ArraySize(values);
      ArrayResize(values,count+1);
      values[count]=value;
     }

public:
                     CCanonicalM1Normalizer(void)
     {
      _symbol="";
      _initialized=false;
      _has_previous=false;
      ZeroMemory(_previous);
     }

   void SetParams(const string symbol,
                  const int standard_offset_seconds,
                  const int daylight_offset_seconds)
     {
      _symbol=symbol;
      _calendar.SetParams(symbol,standard_offset_seconds,
                          daylight_offset_seconds);
      _converter.SetParams(standard_offset_seconds,daylight_offset_seconds);
      Reset();
     }

   bool Init(void)
     {
      Reset();
      _initialized=(_symbol!="" && _calendar.Init() && _converter.Init());
      return _initialized;
     }

   void Reset(void)
     {
      _initialized=false;
      _has_previous=false;
      ZeroMemory(_previous);
      _calendar.Reset();
      _converter.Reset();
     }

   bool Step(const SCanonicalM1Bar &observed,
             SCanonicalM1Bar &normalized[])
     {
      ArrayResize(normalized,0);
      if(!_initialized || observed.symbol!=_symbol || !observed.observed ||
         observed.utc_time<=0 || observed.close<=0.0)
         return false;
      if(_has_previous && observed.utc_time<=_previous.utc_time)
         return false;

      if(_has_previous)
        {
         for(datetime utc_time=_previous.utc_time+60;
             utc_time<observed.utc_time;utc_time+=60)
           {
            if(!_calendar.Step(utc_time))
               continue;
            SCanonicalM1Bar synthetic=_previous;
            int offset=0;
            if(_converter.UtcToServer(utc_time,synthetic.source_time,offset)!=
               CANONICAL_TIME_READY)
               return false;
            synthetic.utc_time=utc_time;
            synthetic.open=_previous.close;
            synthetic.high=_previous.close;
            synthetic.low=_previous.close;
            synthetic.close=_previous.close;
            synthetic.tick_volume=0;
            synthetic.real_volume=0;
            synthetic.complete=true;
            synthetic.observed=false;
            synthetic.source_timezone="broker_server_wall_clock";
            synthetic.conversion_rule=StringFormat(
               "open_session_no_quote_carry_forward_offset_%d",offset);
            synthetic.generator_id=CANONICAL_MARKET_DATA_GENERATOR_ID;
            synthetic.generator_version=CANONICAL_MARKET_DATA_GENERATOR_VERSION;
            Append(normalized,synthetic);
            _previous=synthetic;
           }
        }
      Append(normalized,observed);
      _previous=observed;
      _has_previous=true;
      return true;
     }
  };

class CEventTimeframeAggregator
  {
private:
   ENUM_TIMEFRAMES   _timeframe;
   datetime          _interval_start_utc;
   datetime          _interval_end_utc;
   int               _expected_source_count;
   double            _point;
   string            _symbol;
   datetime          _baseline_time_utc;
   double            _baseline_price;
   datetime          _last_source_time;
   datetime          _endpoint_time_utc;
   double            _open;
   double            _high;
   double            _low;
   double            _close;
   double            _previous_price;
   double            _telescoping_log_response;
   long              _tick_volume;
   long              _real_volume;
   int               _maximum_spread_points;
   int               _source_count;
   bool              _ordered;
   bool              _initialized;

public:
                     CEventTimeframeAggregator(void)
     {
      _timeframe=PERIOD_M1;
      _interval_start_utc=0;
      _interval_end_utc=0;
      _expected_source_count=0;
      _point=0.0;
      _symbol="";
      Reset();
     }

   void SetParams(const ENUM_TIMEFRAMES timeframe,
                  const datetime interval_start_utc,
                  const datetime interval_end_utc,
                  const int expected_source_count,
                  const double point)
     {
      _timeframe=timeframe;
      _interval_start_utc=interval_start_utc;
      _interval_end_utc=interval_end_utc;
      _expected_source_count=expected_source_count;
      _point=point;
      Reset();
     }

   bool Init(const string symbol,
             const datetime baseline_time_utc,
             const double baseline_price)
     {
      Reset();
      _symbol=symbol;
      _baseline_time_utc=baseline_time_utc;
      _baseline_price=baseline_price;
      _previous_price=baseline_price;
      _initialized=(symbol!="" && baseline_time_utc>0 && baseline_price>0.0 &&
                    _interval_start_utc>0 && _interval_end_utc>_interval_start_utc &&
                    _expected_source_count>0 && _point>0.0 &&
                    BanksEffectsIsRequiredTimeframe(_timeframe));
      return _initialized;
     }

   void Reset(void)
     {
      _baseline_time_utc=0;
      _baseline_price=0.0;
      _last_source_time=0;
      _endpoint_time_utc=0;
      _open=0.0;
      _high=0.0;
      _low=0.0;
      _close=0.0;
      _previous_price=0.0;
      _telescoping_log_response=0.0;
      _tick_volume=0;
      _real_volume=0;
      _maximum_spread_points=0;
      _source_count=0;
      _ordered=true;
      _initialized=false;
     }

   bool Step(const SCanonicalM1Bar &source)
     {
      if(!_initialized || source.symbol!=_symbol || !source.complete ||
         source.utc_time<_interval_start_utc || source.utc_time>=_interval_end_utc ||
         source.open<=0.0 || source.high<source.low || source.close<=0.0)
         return false;
      if(_last_source_time>0 && source.utc_time<=_last_source_time)
        {
         _ordered=false;
         return false;
        }

      if(_source_count==0)
        {
         _open=source.open;
         _high=source.high;
         _low=source.low;
        }
      else
        {
         if(source.high>_high)
            _high=source.high;
         if(source.low<_low)
            _low=source.low;
        }
      _close=source.close;
      _tick_volume+=source.tick_volume;
      _real_volume+=source.real_volume;
      if(source.spread_points>_maximum_spread_points)
         _maximum_spread_points=source.spread_points;
      _telescoping_log_response+=MathLog(source.close/_previous_price);
      _previous_price=source.close;
      _last_source_time=source.utc_time;
      _endpoint_time_utc=source.utc_time+60;
      ++_source_count;
      return true;
     }

   bool Result(SCanonicalAggregatedBar &output) const
     {
      ZeroMemory(output);
      if(!_initialized || _source_count<=0)
         return false;
      output.symbol=_symbol;
      output.timeframe=_timeframe;
      output.interval_start_utc=_interval_start_utc;
      output.interval_end_utc=_interval_end_utc;
      output.baseline_time_utc=_baseline_time_utc;
      output.endpoint_time_utc=_endpoint_time_utc;
      output.baseline_price=_baseline_price;
      output.open=_open;
      output.high=_high;
      output.low=_low;
      output.close=_close;
      output.tick_volume=_tick_volume;
      output.real_volume=_real_volume;
      output.maximum_spread_points=_maximum_spread_points;
      output.source_count=_source_count;
      output.expected_source_count=_expected_source_count;
      output.signed_log_response=MathLog(_close/_baseline_price);
      output.telescoping_log_response=_telescoping_log_response;
      double response_tolerance=_point/_baseline_price;
      output.telescoping_consistent=(MathAbs(output.signed_log_response-
                                             output.telescoping_log_response)<=response_tolerance);
      output.complete=(_ordered && _source_count==_expected_source_count &&
                       _endpoint_time_utc<=_interval_end_utc &&
                       output.telescoping_consistent);
      output.generator_id=CANONICAL_MARKET_DATA_GENERATOR_ID;
      output.generator_version=CANONICAL_MARKET_DATA_GENERATOR_VERSION;
      return true;
     }
  };

#endif
