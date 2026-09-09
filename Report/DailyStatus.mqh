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

bool StrategyBalanceChangeSince(const datetime from_time,const datetime to_time,
                                const string symbol,const long magic_number,
                                double &net_change)
  {
   net_change=0.0;
   if(from_time<=0 || to_time<from_time || symbol=="")
      return false;
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
      if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=symbol ||
         HistoryDealGetInteger(ticket,DEAL_MAGIC)!=magic_number)
         continue;
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

// Returns the closed-deal result for one EA instance over the supplied
// interval. Unlike StrategyBalanceChangeSince, a zero start time intentionally
// means all account history available to the terminal.
bool StrategyRealizedProfitSince(const datetime from_time,const datetime to_time,
                                 const string symbol,const long magic_number,
                                 double &realized_profit)
  {
   realized_profit=0.0;
   if(from_time<0 || to_time<from_time || symbol=="" ||
      !HistorySelect(from_time,to_time))
      return false;
   int total=HistoryDealsTotal();
   for(int i=0;i<total;++i)
     {
      ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0)
         return false;
      if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=symbol ||
         HistoryDealGetInteger(ticket,DEAL_MAGIC)!=magic_number)
         continue;
      double contribution=HistoryDealGetDouble(ticket,DEAL_PROFIT)+
                          HistoryDealGetDouble(ticket,DEAL_COMMISSION)+
                          HistoryDealGetDouble(ticket,DEAL_SWAP)+
                          HistoryDealGetDouble(ticket,DEAL_FEE);
      if(!MathIsValidNumber(contribution))
         return false;
      realized_profit+=contribution;
     }
   return MathIsValidNumber(realized_profit);
  }

bool StrategyFloatingProfit(const string symbol,const long magic_number,
                            double &floating_profit)
  {
   floating_profit=0.0;
   if(symbol=="")
      return false;
   for(int i=0;i<PositionsTotal();++i)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0)
         return false;
      if(PositionGetString(POSITION_SYMBOL)!=symbol ||
         PositionGetInteger(POSITION_MAGIC)!=magic_number)
         continue;
      double contribution=PositionGetDouble(POSITION_PROFIT)+
                          PositionGetDouble(POSITION_SWAP);
      if(!MathIsValidNumber(contribution))
         return false;
      floating_profit+=contribution;
     }
   return MathIsValidNumber(floating_profit);
  }

bool StrategyDailyPercentFromValues(const double realized_change,
                                    const double floating_profit,
                                    const double midnight_balance,
                                    double &daily_percent)
  {
   daily_percent=0.0;
   if(!MathIsValidNumber(realized_change) ||
      !MathIsValidNumber(floating_profit) ||
      !MathIsValidNumber(midnight_balance) || midnight_balance<=0.0)
      return false;
   daily_percent=100.0*(realized_change+floating_profit)/midnight_balance;
   return MathIsValidNumber(daily_percent);
  }

bool GetStrategyDailyPercent(const datetime broker_time,const string symbol,
                             const long magic_number,
                             const double midnight_balance,
                             double &daily_percent)
  {
   daily_percent=0.0;
   datetime midnight=BrokerDayStart(broker_time);
   double realized_change=0.0;
   double floating_profit=0.0;
   if(midnight<=0 || midnight_balance<=0.0 ||
      !StrategyBalanceChangeSince(midnight,broker_time,symbol,magic_number,
                                  realized_change) ||
      !StrategyFloatingProfit(symbol,magic_number,floating_profit))
      return false;
   return StrategyDailyPercentFromValues(realized_change,floating_profit,
                                         midnight_balance,daily_percent);
  }

bool GetStrategyTotalProfit(const datetime broker_time,const string symbol,
                            const long magic_number,double &total_profit)
  {
   total_profit=0.0;
   double realized_profit=0.0;
   double floating_profit=0.0;
   if(broker_time<=0 ||
      !StrategyRealizedProfitSince(0,broker_time,symbol,magic_number,
                                   realized_profit) ||
      !StrategyFloatingProfit(symbol,magic_number,floating_profit))
      return false;
   total_profit=realized_profit+floating_profit;
   return MathIsValidNumber(total_profit);
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
