//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class NewCandleClassChecker
{
public:
    NewCandleClassChecker(ENUM_TIMEFRAMES period = PERIOD_M1): last_candle_time(0)
    {
        _period = period;
    }
    ~NewCandleClassChecker() {}
    
    void set_params(ENUM_TIMEFRAMES period = PERIOD_M1);
    bool check_step();
private:
    ENUM_TIMEFRAMES _period;
    datetime last_candle_time;
};

//+------------------------------------------------------------------+
void NewCandleClassChecker::set_params(ENUM_TIMEFRAMES period)
{
    _period = period;
}

bool NewCandleClassChecker::check_step()
{
    datetime current_candle_time = iTime(_Symbol, _period, 0);
    if(last_candle_time < current_candle_time){
        last_candle_time = current_candle_time;
        return true;
    }
    return false;
}