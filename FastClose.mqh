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
void close_all_positions(string sym = NULL, long magic_number = 0, int pos_type = -1)
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
           {
            if(pos_type < 0 ||
               (pos_type >= 0 && PositionGetInteger(POSITION_TYPE) == pos_type))
                trade.PositionClose(pos_ticket);
           }
       }
   }
//+------------------------------------------------------------------+
bool is_there_any_order_or_position(string sym = NULL, long magic_number = 0)
   {
    if(is_there_any_position(sym, magic_number))
        return true;
    if(is_there_any_order(sym, magic_number))
        return true;
    return false;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_there_any_order(string sym = NULL, long magic_number = 0)
   {
    for(int i = OrdersTotal() - 1; i >= 0; i--)
       {
        ulong order_ticket = OrderGetTicket(i);
        if(OrderSelect(order_ticket) &&
           (sym == NULL || (OrderGetString(ORDER_SYMBOL) == sym)) &&
           (magic_number == 0 || (magic_number == OrderGetInteger(ORDER_MAGIC))))
           {
            return true;
           }
       }
    return false;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_there_any_position(string sym = NULL, long magic_number = 0)
   {
    for(int i = PositionsTotal() - 1; i >= 0; i--)
       {
        ulong pos_ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(pos_ticket) &&
           (sym == NULL || (PositionGetString(POSITION_SYMBOL) == sym)) &&
           (magic_number == 0 || (magic_number == PositionGetInteger(POSITION_MAGIC))))
            return true;
       }
    return false;
   }
//+------------------------------------------------------------------+
