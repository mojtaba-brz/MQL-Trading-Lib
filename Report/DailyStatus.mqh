//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_earned_daily_profit()
{
   double daily_profit = 0.;
    MqlDateTime start_of_the_day_struct;
    TimeCurrent(start_of_the_day_struct);
    start_of_the_day_struct.hour = 0;
    start_of_the_day_struct.min = 0;
    start_of_the_day_struct.sec = 0;

    datetime start_of_the_day = StructToTime(start_of_the_day_struct);
    datetime current_time     = TimeCurrent();

    HistorySelect(start_of_the_day, current_time);
    for(int i = HistoryDealsTotal(); i >= 0; i--) {
       ulong ticket = HistoryDealGetTicket(i);
       if(HistoryDealSelect(ticket)){
         daily_profit += HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                         HistoryDealGetDouble(ticket, DEAL_COMMISSION) + 
                         HistoryDealGetDouble(ticket, DEAL_SWAP);
       }
    }
    
    // daily_profit += AccountInfoDouble(ACCOUNT_PROFIT);
    
    return daily_profit;
}
//+------------------------------------------------------------------+
