#ifndef DAILY_STATUS_MQH
#define DAILY_STATUS_MQH

datetime BrokerDayStart(const datetime broker_time)
  {
   MqlDateTime decoded={};
   if(broker_time<=0 || !TimeToStruct(broker_time,decoded))
      return 0;
   decoded.hour=0;
   decoded.min=0;
   decoded.sec=0;
   return StructToTime(decoded);
  }

bool DailyEquityPercentFromValues(const double current_equity,
                                  const double midnight_balance,
                                  double &daily_percent)
  {
   daily_percent=0.0;
   if(!MathIsValidNumber(current_equity) ||
      !MathIsValidNumber(midnight_balance) || midnight_balance<=0.0)
      return false;
   daily_percent=100.0*(current_equity-midnight_balance)/midnight_balance;
   return MathIsValidNumber(daily_percent);
  }

bool AccountBalanceChangeSince(const datetime from_time,const datetime to_time,
                               double &net_change)
  {
   net_change=0.0;
   if(from_time<=0 || to_time<from_time)
      return false;
   // At an exact broker-midnight tester start there is no interval to query.
   // Its balance change is deterministically zero; some tester builds return
   // false for HistorySelect(t,t), which must not disable trading all day.
   if(to_time==from_time)
      return true;
   if(!HistorySelect(from_time,to_time))
      return false;

   int total=HistoryDealsTotal();
   for(int i=0;i<total;++i)
     {
      ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0)
         return false;
      double contribution=HistoryDealGetDouble(ticket,DEAL_PROFIT)+
                          HistoryDealGetDouble(ticket,DEAL_COMMISSION)+
                          HistoryDealGetDouble(ticket,DEAL_SWAP)+
                          HistoryDealGetDouble(ticket,DEAL_FEE);
      if(!MathIsValidNumber(contribution))
         return false;
      net_change+=contribution;
     }
   return MathIsValidNumber(net_change);
  }

bool GetMidnightBalance(const datetime broker_time,double &midnight_balance)
  {
   midnight_balance=0.0;
   datetime midnight=BrokerDayStart(broker_time);
   double current_balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double balance_change=0.0;
   if(midnight<=0 || current_balance<=0.0 ||
      !AccountBalanceChangeSince(midnight,broker_time,balance_change))
      return false;
   midnight_balance=current_balance-balance_change;
   return MathIsValidNumber(midnight_balance) && midnight_balance>0.0;
  }

bool GetDailyEquityPercent(const datetime broker_time,double &daily_percent,
                           double &midnight_balance)
  {
   daily_percent=0.0;
   midnight_balance=0.0;
   if(!GetMidnightBalance(broker_time,midnight_balance))
      return false;
   return DailyEquityPercentFromValues(AccountInfoDouble(ACCOUNT_EQUITY),
                                       midnight_balance,daily_percent);
  }

// Legacy compatibility: returns the net balance change since broker midnight.
double get_earned_daily_profit()
  {
   datetime broker_time=TimeCurrent();
   datetime midnight=BrokerDayStart(broker_time);
   double net_change=0.0;
   if(midnight<=0 || !AccountBalanceChangeSince(midnight,broker_time,net_change))
      return 0.0;
   return net_change;
  }

#endif
