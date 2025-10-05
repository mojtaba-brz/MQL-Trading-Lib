//+------------------------------------------------------------------+
//|                                                    FastClose.mqh |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include <Trade/Trade.mqh>
#include "typedefs.mqh"

//+------------------------------------------------------------------+
void close_all_orders(string sym = NULL, long magic_number = 0, OrderCloseMode mode = ORDER_CLOSE_ALL)
{
    CTrade trade;
    trade.SetAsyncMode(true);
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong order_ticket = OrderGetTicket(i);
        if(OrderSelect(order_ticket) &&
           (sym == NULL || (OrderGetString(ORDER_SYMBOL) == sym)) &&
           (magic_number == 0 || (magic_number == OrderGetInteger(ORDER_MAGIC)))) {
            switch (mode) {
            case ORDER_CLOSE_ALL:
                trade.OrderDelete(order_ticket);
                break;

            case ORDER_CLOSE_BUY:
                if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY ||
                   OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT ||
                   OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP ||
                   OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP_LIMIT) {
                    trade.OrderDelete(order_ticket);
                }
                break;

            case ORDER_CLOSE_SELL:
                if(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL ||
                   OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT ||
                   OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP ||
                   OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP_LIMIT) {
                    trade.OrderDelete(order_ticket);
                }
                break;

            default:
                trade.OrderDelete(order_ticket);
                break;
            }

        }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void close_all_positions(string sym = NULL, long magic_number = 0, PosCloseMode mode = POS_CLOSE_ALL)
{
    CTrade trade();
    trade.SetAsyncMode(true);
    trade.SetExpertMagicNumber(magic_number);
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong pos_ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(pos_ticket) &&
           (sym == NULL || (PositionGetString(POSITION_SYMBOL) == sym)) &&
           (magic_number == 0 || (magic_number == PositionGetInteger(POSITION_MAGIC)))) {
            switch (mode) {
            case POS_CLOSE_ALL:
                trade.PositionClose(pos_ticket);
                break;

            case POS_CLOSE_BUY:
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                    trade.PositionClose(pos_ticket);
                }
                break;

            case POS_CLOSE_SELL:
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                    trade.PositionClose(pos_ticket);
                }
                break;

            default:
                trade.PositionClose(pos_ticket);
                break;
            }
        }
    }
}
//+------------------------------------------------------------------+
bool is_there_any_order_or_position(string sym = NULL, long magic_number = 0)
{
    if(is_there_any_position(sym, magic_number)) return true;
    if(is_there_any_order(sym, magic_number))    return true;
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_there_any_order(string sym = NULL, long magic_number = 0)
{
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong order_ticket = OrderGetTicket(i);
        if(OrderSelect(order_ticket) &&
           (sym == NULL || (OrderGetString(ORDER_SYMBOL) == sym)) &&
           (magic_number == 0 || (magic_number == OrderGetInteger(ORDER_MAGIC)))) {
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
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong pos_ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(pos_ticket) &&
           (sym == NULL || (PositionGetString(POSITION_SYMBOL) == sym)) &&
           (magic_number == 0 || (magic_number == PositionGetInteger(POSITION_MAGIC))))
            return true;
    }
    return false;
}
//+------------------------------------------------------------------+
