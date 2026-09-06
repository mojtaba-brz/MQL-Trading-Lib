#ifndef STOP_LOSS_POLICY_MQH
#define STOP_LOSS_POLICY_MQH

enum ENUM_INITIAL_STOP_METHOD
  {
   INITIAL_STOP_STRUCTURE_ATR=0, // Setup structure with an ATR minimum distance
   INITIAL_STOP_SETUP_WINDOW=1,  // Setup-window high or low
   INITIAL_STOP_ATR=2,           // Fixed ATR distance
   INITIAL_STOP_SESSION=3,       // Current-session high or low
   INITIAL_STOP_MAE_ATR=4        // Frozen MAE quantile expressed in ATR units
  };

struct SStopLossParams
  {
   ENUM_INITIAL_STOP_METHOD initial_method;
   int      setup_lookback;
   int      atr_period;
   double   atr_multiplier;
   double   structure_buffer_atr;
   double   maximum_distance_atr;
   double   mae_quantile_atr;
   bool     time_exit_enabled;
   int      time_exit_bars;
   double   time_exit_minimum_favorable_r;
   bool     signal_invalidation_enabled;
   bool     trailing_enabled;
   int      trailing_lookback;
   double   trailing_buffer_atr;
  };

struct SStopLossDecision
  {
   bool     valid;
   bool     close_position;
   bool     move_stop;
   double   stop_price;
   int      age_bars;
   double   maximum_favorable_r;
   string   reason;
  };

bool StopLossCandleValid(const MqlRates &bar)
  {
   return bar.time>0 && MathIsValidNumber(bar.open) &&
          MathIsValidNumber(bar.high) && MathIsValidNumber(bar.low) &&
          MathIsValidNumber(bar.close) && bar.low>0.0 &&
          bar.high>=MathMax(bar.open,bar.close) &&
          bar.low<=MathMin(bar.open,bar.close);
  }

bool StopLossChronologicalCandlesValid(const MqlRates &bars[],const int total)
  {
   if(total<=0 || total>ArraySize(bars))
      return false;
   for(int i=0;i<total;++i)
     {
      if(!StopLossCandleValid(bars[i]) || (i>0 && bars[i].time<=bars[i-1].time))
         return false;
     }
   return true;
  }

double StopLossATR(const MqlRates &bars[],const int total,const int period)
  {
   if(period<1 || total<period+1 || total>ArraySize(bars) ||
      !StopLossChronologicalCandlesValid(bars,total))
      return EMPTY_VALUE;
   double sum=0.0;
   for(int i=total-period;i<total;++i)
     {
      double previous_close=bars[i-1].close;
      double true_range=MathMax(bars[i].high-bars[i].low,
                                MathMax(MathAbs(bars[i].high-previous_close),
                                        MathAbs(bars[i].low-previous_close)));
      sum+=true_range;
     }
   return sum/period;
  }

bool StopLossWindowExtreme(const MqlRates &bars[],const int total,const int lookback,
                           const bool want_low,double &value)
  {
   if(lookback<1 || total<lookback || total>ArraySize(bars) ||
      !StopLossChronologicalCandlesValid(bars,total))
      return false;
   int first=total-lookback;
   value=(want_low ? bars[first].low : bars[first].high);
   for(int i=first+1;i<total;++i)
      value=(want_low ? MathMin(value,bars[i].low) : MathMax(value,bars[i].high));
   return true;
  }

bool StopLossSessionExtreme(const MqlRates &bars[],const int total,const datetime session_start,
                            const bool want_low,double &value)
  {
   if(session_start<=0 || total<=0 || total>ArraySize(bars) ||
      !StopLossChronologicalCandlesValid(bars,total))
      return false;
   bool found=false;
   for(int i=0;i<total;++i)
     {
      if(bars[i].time<session_start)
         continue;
      if(!found)
        {
         value=(want_low ? bars[i].low : bars[i].high);
         found=true;
        }
      else
         value=(want_low ? MathMin(value,bars[i].low) : MathMax(value,bars[i].high));
     }
   return found;
  }

bool StopLossVolumeForRisk(const string symbol,const bool is_buy,const double entry_price,
                           const double stop_price,const double balance,
                           const double risk_percent,double &volume,string &reason)
  {
   volume=0.0;
   reason="";
   if(symbol=="" || entry_price<=0.0 || stop_price<=0.0 || balance<=0.0 ||
      risk_percent<=0.0 || risk_percent>100.0 ||
      (is_buy && stop_price>=entry_price) || (!is_buy && stop_price<=entry_price))
     {
      reason="invalid risk-volume inputs";
      return false;
     }
   double loss_per_lot=0.0;
   ENUM_ORDER_TYPE side=(is_buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcProfit(side,symbol,1.0,entry_price,stop_price,loss_per_lot) ||
      !MathIsValidNumber(loss_per_lot) || loss_per_lot>=0.0)
     {
      reason="OrderCalcProfit could not value the stop loss";
      return false;
     }
   double minimum=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   if(minimum<=0.0 || maximum<minimum || step<=0.0)
     {
      reason="invalid broker volume specification";
      return false;
     }
   double risk_money=balance*risk_percent/100.0;
   double raw=risk_money/MathAbs(loss_per_lot);
   volume=MathFloor(raw/step+1e-10)*step;
   volume=MathMin(volume,maximum);
   volume=NormalizeDouble(volume,8);
   if(volume<minimum)
     {
      volume=0.0;
      reason="risk budget is below the broker minimum volume";
      return false;
     }
   return true;
  }

class CStopLossPolicy
  {
private:
   SStopLossParams _params;
   bool             _parameters_set;
   bool             _initialized;
   bool             _active;
   bool             _is_buy;
   double           _entry_price;
   double           _initial_stop;
   double           _current_stop;
   double           _initial_risk;
   double           _maximum_favorable_excursion;
   datetime         _last_bar_time;
   int              _age_bars;

   bool ParamsValid(void) const
     {
      return _params.initial_method>=INITIAL_STOP_STRUCTURE_ATR &&
             _params.initial_method<=INITIAL_STOP_MAE_ATR &&
             _params.setup_lookback>=1 && _params.atr_period>=1 &&
             _params.atr_multiplier>0.0 &&
             _params.structure_buffer_atr>=0.0 &&
             _params.maximum_distance_atr>0.0 &&
             _params.mae_quantile_atr>0.0 &&
             (!_params.time_exit_enabled || _params.time_exit_bars>=1) &&
             _params.time_exit_minimum_favorable_r>=0.0 &&
             _params.trailing_lookback>=1 && _params.trailing_buffer_atr>=0.0;
     }

public:
   CStopLossPolicy(void)
     {
      _parameters_set=false;
      _initialized=false;
      Reset();
     }

   bool SetParams(const SStopLossParams &params)
     {
      _params=params;
      _parameters_set=ParamsValid();
      _initialized=false;
      Reset();
      return _parameters_set;
     }

   bool Init(void)
     {
      Reset();
      _initialized=_parameters_set && ParamsValid();
      return _initialized;
     }

   void Reset(void)
     {
      _active=false;
      _is_buy=true;
      _entry_price=0.0;
      _initial_stop=0.0;
      _current_stop=0.0;
      _initial_risk=0.0;
      _maximum_favorable_excursion=0.0;
      _last_bar_time=0;
      _age_bars=0;
     }

   bool CalculateInitialStop(const bool is_buy,const double entry_price,
                             const MqlRates &completed_bars[],const int total,
                             const datetime session_start,const double minimum_distance,
                             const double price_tick_size,
                             double &stop_price,string &reason) const
     {
      stop_price=EMPTY_VALUE;
      reason="";
      if(!_initialized || entry_price<=0.0 || minimum_distance<0.0 ||
         price_tick_size<=0.0)
        {
         reason="stop policy is not initialized or entry inputs are invalid";
         return false;
        }
      double atr=StopLossATR(completed_bars,total,_params.atr_period);
      if(atr==EMPTY_VALUE || atr<=0.0)
        {
         reason="insufficient or invalid completed OHLC for ATR";
         return false;
        }
      double extreme=0.0;
      if(_params.initial_method==INITIAL_STOP_STRUCTURE_ATR ||
         _params.initial_method==INITIAL_STOP_SETUP_WINDOW)
        {
         if(!StopLossWindowExtreme(completed_bars,total,_params.setup_lookback,is_buy,extreme))
           {
            reason="insufficient setup-window OHLC";
            return false;
           }
        }
      else if(_params.initial_method==INITIAL_STOP_SESSION)
        {
         if(!StopLossSessionExtreme(completed_bars,total,session_start,is_buy,extreme))
           {
            reason="no completed OHLC in the selected session";
            return false;
           }
        }

      double buffer=_params.structure_buffer_atr*atr;
      if(_params.initial_method==INITIAL_STOP_STRUCTURE_ATR)
        {
         double structural=(is_buy ? extreme-buffer : extreme+buffer);
         double volatility=(is_buy ? entry_price-_params.atr_multiplier*atr :
                                          entry_price+_params.atr_multiplier*atr);
         stop_price=(is_buy ? MathMin(structural,volatility) :
                              MathMax(structural,volatility));
        }
      else if(_params.initial_method==INITIAL_STOP_SETUP_WINDOW ||
              _params.initial_method==INITIAL_STOP_SESSION)
         stop_price=(is_buy ? extreme-buffer : extreme+buffer);
      else
        {
         double multiple=(_params.initial_method==INITIAL_STOP_MAE_ATR ?
                          _params.mae_quantile_atr : _params.atr_multiplier);
         stop_price=(is_buy ? entry_price-multiple*atr : entry_price+multiple*atr);
        }

      stop_price=(is_buy ? MathMin(stop_price,entry_price-minimum_distance) :
                           MathMax(stop_price,entry_price+minimum_distance));
      double tick_count=stop_price/price_tick_size;
      stop_price=(is_buy ? MathFloor(tick_count+1e-10) :
                           MathCeil(tick_count-1e-10))*price_tick_size;
      double distance=MathAbs(entry_price-stop_price);
      if(distance<=0.0 || distance>_params.maximum_distance_atr*atr)
        {
         stop_price=EMPTY_VALUE;
         reason="required stop exceeds the configured maximum; skip the trade";
         return false;
        }
      return true;
     }

   bool Begin(const bool is_buy,const double entry_price,const double initial_stop,
              const datetime entry_bar_time)
     {
      Reset();
      if(!_initialized || entry_price<=0.0 || initial_stop<=0.0 || entry_bar_time<=0 ||
         (is_buy && initial_stop>=entry_price) || (!is_buy && initial_stop<=entry_price))
         return false;
      _active=true;
      _is_buy=is_buy;
      _entry_price=entry_price;
      _initial_stop=initial_stop;
      _current_stop=initial_stop;
      _initial_risk=MathAbs(entry_price-initial_stop);
      _last_bar_time=entry_bar_time;
      return true;
     }

   bool Step(const MqlRates &completed_bars[],const int total,
             const bool trailing_signal,const bool signal_invalidated,
             SStopLossDecision &decision)
     {
      decision.valid=false;
      decision.close_position=false;
      decision.move_stop=false;
      decision.stop_price=_current_stop;
      decision.age_bars=_age_bars;
      decision.maximum_favorable_r=0.0;
      decision.reason="";
      if(!_initialized || !_active || total<=0 || total>ArraySize(completed_bars) ||
         !StopLossChronologicalCandlesValid(completed_bars,total))
        {
         decision.reason="inactive policy or invalid completed OHLC";
         return false;
        }
      MqlRates latest=completed_bars[total-1];
      if(latest.time<=_last_bar_time)
        {
         decision.reason="bar is not newer than the owned position state";
         return false;
        }
      _last_bar_time=latest.time;
      ++_age_bars;
      double favorable=(_is_buy ? latest.high-_entry_price : _entry_price-latest.low);
      _maximum_favorable_excursion=MathMax(_maximum_favorable_excursion,MathMax(0.0,favorable));
      double favorable_r=_maximum_favorable_excursion/_initial_risk;
      decision.valid=true;
      decision.age_bars=_age_bars;
      decision.maximum_favorable_r=favorable_r;

      if(_params.signal_invalidation_enabled && signal_invalidated)
        {
         decision.close_position=true;
         decision.reason="entry signal invalidated";
         return true;
        }
      if(_params.time_exit_enabled && _age_bars>=_params.time_exit_bars &&
         favorable_r<_params.time_exit_minimum_favorable_r)
        {
         decision.close_position=true;
         decision.reason="time stop without sufficient favorable excursion";
         return true;
        }
      if(!_params.trailing_enabled || !trailing_signal)
         return true;

      double atr=StopLossATR(completed_bars,total,_params.atr_period);
      double extreme=0.0;
      if(atr==EMPTY_VALUE || atr<=0.0 ||
         !StopLossWindowExtreme(completed_bars,total,_params.trailing_lookback,
                                _is_buy,extreme))
        {
         decision.valid=false;
         decision.reason="insufficient completed OHLC for trailing stop";
         return false;
        }
      double candidate=(_is_buy ? extreme-_params.trailing_buffer_atr*atr :
                                  extreme+_params.trailing_buffer_atr*atr);
      bool correct_side=(_is_buy ? candidate<latest.close : candidate>latest.close);
      bool tighter=(_is_buy ? candidate>_current_stop : candidate<_current_stop);
      if(correct_side && tighter)
        {
         _current_stop=candidate;
         decision.move_stop=true;
         decision.stop_price=candidate;
         decision.reason="ratcheted to completed-bar structure";
        }
      return true;
     }

   bool Active(void) const { return _active; }
   int AgeBars(void) const { return _age_bars; }
   double CurrentStop(void) const { return _current_stop; }
   double InitialRisk(void) const { return _initial_risk; }
  };

#endif
