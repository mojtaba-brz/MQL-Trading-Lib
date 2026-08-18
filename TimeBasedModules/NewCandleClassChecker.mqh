#ifndef MQLTRADINGLIB_NEW_CANDLE_CLASS_CHECKER_MQH
#define MQLTRADINGLIB_NEW_CANDLE_CLASS_CHECKER_MQH

// Stateful, reusable checker for one symbol/timeframe candle stream.
// The first valid observation initializes memory and is not reported as new.
class NewCandleClassChecker
  {
private:
   string            _symbol;
   ENUM_TIMEFRAMES   _period;
   datetime          _last_candle_time;

   string            ResolvedSymbol() const
                       {
                        return(_symbol=="" ? Symbol() : _symbol);
                       }

public:
                     // Existing constructor retained for compatibility.
                     NewCandleClassChecker(const ENUM_TIMEFRAMES period=PERIOD_M1)
                       {
                        _symbol="";
                        _period=period;
                        _last_candle_time=0;
                       }

   bool              Init(const datetime initial_candle_time)
                       {
                        Reset();
                        if(initial_candle_time<=0)
                           return(false);

                        _last_candle_time=initial_candle_time;
                        return(true);
                       }

   bool              Init()
                       {
                        datetime current_candle_time=iTime(ResolvedSymbol(),_period,0);
                        return(Init(current_candle_time));
                       }

   void              SetParams(const string symbol_name,
                               const ENUM_TIMEFRAMES period)
                       {
                        _symbol=symbol_name;
                        _period=period;
                        Reset();
                       }

   void              SetParams(const ENUM_TIMEFRAMES period=PERIOD_M1)
                       {
                        SetParams("",period);
                       }

   void              Reset()
                       {
                        _last_candle_time=0;
                       }

   bool              Step(const datetime observed_candle_time,
                          datetime &new_candle_time)
                       {
                        new_candle_time=0;
                        if(observed_candle_time<=0)
                           return(false);

                        if(_last_candle_time==0)
                          {
                           _last_candle_time=observed_candle_time;
                           return(false);
                          }

                        if(observed_candle_time==_last_candle_time)
                           return(false);

                        // A history reset or clock rewind creates a new baseline
                        // without emitting a false forward-candle event.
                        if(observed_candle_time<_last_candle_time)
                          {
                           _last_candle_time=observed_candle_time;
                           return(false);
                          }

                        _last_candle_time=observed_candle_time;
                        new_candle_time=observed_candle_time;
                        return(true);
                       }

   bool              Step(datetime &new_candle_time)
                       {
                        datetime current_candle_time=iTime(ResolvedSymbol(),_period,0);
                        return(Step(current_candle_time,new_candle_time));
                       }

   bool              IsInitialized() const
                       {
                        return(_last_candle_time>0);
                       }

   datetime          LastCandleTime() const
                       {
                        return(_last_candle_time);
                       }

   string            SymbolName() const
                       {
                        return(_symbol);
                       }

   ENUM_TIMEFRAMES   Period() const
                       {
                        return(_period);
                       }

   // Legacy API adapters. Keep these while existing consumers migrate.
   void              set_params(const ENUM_TIMEFRAMES period=PERIOD_M1)
                       {
                        // Preserve the original API behavior: changing the
                        // period did not reset the remembered candle.
                        _period=period;
                       }

   bool              check_step()
                       {
                        datetime current_candle_time=iTime(ResolvedSymbol(),_period,0);
                        if(current_candle_time<=0)
                           return(false);

                        // Preserve the original API behavior: the first valid
                        // candle after construction/reset was reported as new.
                        if(_last_candle_time==0)
                          {
                           _last_candle_time=current_candle_time;
                           return(true);
                          }

                        datetime new_candle_time=0;
                        return(Step(current_candle_time,new_candle_time));
                       }

   void              reset()
                       {
                        Reset();
                       }
  };

#endif
