#ifndef MQL_TRADING_LIB_NEWS_SCHEDULE_MQH
#define MQL_TRADING_LIB_NEWS_SCHEDULE_MQH

struct SNewsScheduleEvent
  {
   datetime server_time;
   string   currency;
  };

struct SNewsScheduleCoverage
  {
   datetime start;
   datetime end;
  };

// Deterministic bar-aligned schedule gate shared by fixture and live sources.
class CNewsSchedule
  {
private:
   ENUM_TIMEFRAMES       _timeframe;
   bool                  _require_coverage;
   bool                  _parameters_set;
   bool                  _initialized;
   SNewsScheduleEvent    _events[];
   SNewsScheduleCoverage _coverages[];

   bool WithinCoverage(const datetime server_time) const
     {
      if(!_require_coverage)
         return true;
      for(int i=0;i<ArraySize(_coverages);++i)
         if(server_time>=_coverages[i].start && server_time<_coverages[i].end)
            return true;
      return false;
     }

public:
   bool SetParams(const ENUM_TIMEFRAMES timeframe,const bool require_coverage)
     {
      _timeframe=timeframe;
      _require_coverage=require_coverage;
      _parameters_set=(PeriodSeconds(_timeframe)>0 && PeriodSeconds(_timeframe)<86400);
      Reset();
      return _parameters_set;
     }

   bool AddCoverage(const datetime start,const datetime end)
     {
      if(!_parameters_set || start<=0 || end<=start)
         return false;
      int size=ArraySize(_coverages);
      ArrayResize(_coverages,size+1);
      _coverages[size].start=start;
      _coverages[size].end=end;
      return true;
     }

   bool AddEvent(const datetime server_time,const string currency)
     {
      if(!_parameters_set || server_time<=0 || StringLen(currency)!=3)
         return false;
      int size=ArraySize(_events);
      ArrayResize(_events,size+1);
      _events[size].server_time=server_time;
      _events[size].currency=currency;
      return true;
     }

   bool Init(void)
     {
      _initialized=_parameters_set && ArraySize(_events)>0 &&
                   (!_require_coverage || ArraySize(_coverages)>0);
      return _initialized;
     }

   void Reset(void)
     {
      _initialized=false;
      ArrayResize(_events,0);
      ArrayResize(_coverages,0);
     }

   bool Step(const datetime entry_time,const string currency_one,const string currency_two,
             bool &blocked,string &reason) const
     {
      blocked=true;
      reason="";
      if(!_initialized)
        {
         reason="news schedule is not initialized";
         return false;
        }
      if(!WithinCoverage(entry_time))
        {
         reason="entry time is outside news coverage";
         return false;
        }
      int seconds=PeriodSeconds(_timeframe);
      for(int i=0;i<ArraySize(_events);++i)
        {
         if(_events[i].currency!=currency_one && _events[i].currency!=currency_two)
            continue;
         datetime news_open=(datetime)((long)_events[i].server_time-
                                      ((long)_events[i].server_time%seconds));
         if(entry_time>=news_open-seconds && entry_time<news_open+2*seconds)
           {
            reason=StringFormat("high-impact %s event at %s",_events[i].currency,
                                TimeToString(_events[i].server_time,TIME_DATE|TIME_MINUTES));
            return true;
           }
        }
      blocked=false;
      return true;
     }

   bool EventInCandle(const datetime candle_open,const string currency_one,
                      const string currency_two,bool &has_event) const
     {
      has_event=false;
      if(!_initialized || !WithinCoverage(candle_open))
         return false;
      int seconds=PeriodSeconds(_timeframe);
      if(seconds<=0)
         return false;
      datetime candle_close=candle_open+seconds;
      for(int i=0;i<ArraySize(_events);++i)
        {
         if(_events[i].currency!=currency_one && _events[i].currency!=currency_two)
            continue;
         if(_events[i].server_time>=candle_open && _events[i].server_time<candle_close)
           {
            has_event=true;
            return true;
           }
        }
      return true;
     }

   int EventCount(void) const { return ArraySize(_events); }
  };

#endif
