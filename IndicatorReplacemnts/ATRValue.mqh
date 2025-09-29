//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_atr_value(string sym, ENUM_TIMEFRAMES timeframe = PERIOD_D1, int period = 14, int shift = 1)
{
    MqlRates rates[];
    double sum_true_range = 0;
    if(CopyRates(sym, timeframe, shift, period, rates)) {
        for(int i = 0; i < period; i++) {
            sum_true_range += (rates[i].high - rates[i].low);
        }
    } else {
        Print("No Rates found...Function:get_atr_value.");
    }
    return sum_true_range / period;

}
//+------------------------------------------------------------------+
