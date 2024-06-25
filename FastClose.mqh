//+------------------------------------------------------------------+
//|                                                    FastClose.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
void close_all_orders(string sym = NULL, long magic_number = 0)
   {
    CTrade trade;
    trade.SetAsyncMode(true);
    for(int i = OrdersTotal() - 1; i >= 0; i--)
       {
        ulong order_ticket = OrderGetTicket(i);
        if(OrderSelect(order_ticket) &&
           (sym == NULL || (OrderGetString(ORDER_SYMBOL) == sym)) &&
           (magic_number == 0 || (magic_number == OrderGetInteger(ORDER_MAGIC))))
           {
            trade.OrderDelete(order_ticket);
           }
       }
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void close_all_positions(string sym = NULL, long magic_number = 0)
   {
    CTrade trade();
    trade.SetAsyncMode(true);
    trade.SetExpertMagicNumber(magic_number);
    for(int i = PositionsTotal() - 1; i >= 0; i--)
       {
        ulong pos_ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(pos_ticket) &&
           (sym == NULL || (PositionGetString(POSITION_SYMBOL) == sym)) &&
           (magic_number == 0 || (magic_number == PositionGetInteger(POSITION_MAGIC))))
            trade.PositionClose(pos_ticket);
       }
   }
//+------------------------------------------------------------------+
