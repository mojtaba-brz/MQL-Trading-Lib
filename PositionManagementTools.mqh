//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#include "MQL_Easy/MQL_Easy/MQL_Easy.mqh"
#include "typedefs.mqh"
#include "ExchangeTools.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
PositionState get_current_position_state(string symbol, long magic)
{
    CPosition cp(symbol, magic);

    if(cp.get_total_specified_positions() >= 1) {
        int pos_type = cp.get_position_type();
        if(pos_type == POSITION_TYPE_BUY) {
            return POS_STATE_LONG_POSITION;
        }
        if(pos_type == POSITION_TYPE_SELL) {
            return POS_STATE_SHORT_POSITION;
        }
        return POS_STATE_NO_POSITION;
    } else {
        return POS_STATE_NO_POSITION;
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
PositionState get_current_position_state_cp(CPosition &cp)
{

    if(cp.get_total_specified_positions() >= 1) {
        int pos_type = cp.get_position_type();
        if(pos_type == POSITION_TYPE_BUY) {
            return POS_STATE_LONG_POSITION;
        }
        if(pos_type == POSITION_TYPE_SELL) {
            return POS_STATE_SHORT_POSITION;
        }
        return POS_STATE_NO_POSITION;
    } else {
        return POS_STATE_NO_POSITION;
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void manage_the_trailing_sl_of_position(CPosition &cp, const double sl_diff, ENUM_TIMEFRAMES time_frame)
{
    PositionState cp_state = get_current_position_state_cp(cp);
    if(cp_state == POS_STATE_NO_POSITION) {
        return;
    }

    double pre_stop_loss = cp.GetStopLoss();
    bool pre_stop_loss_is_valid = pre_stop_loss > 0.0 && pre_stop_loss != EMPTY_VALUE;
    double sl = EMPTY_VALUE;
    if(cp_state == POS_STATE_LONG_POSITION) {
        sl = SymbolInfoDouble(cp.GetSymbol(), SYMBOL_BID) - sl_diff;
        if(pre_stop_loss_is_valid)
            sl = MathMax(sl, pre_stop_loss);
    } else if(cp_state == POS_STATE_SHORT_POSITION) {
        sl = SymbolInfoDouble(cp.GetSymbol(), SYMBOL_ASK) + sl_diff;
        if(pre_stop_loss_is_valid)
            sl = MathMin(sl, pre_stop_loss);
    }

    if((MathAbs(pre_stop_loss - sl) > 10 * SymbolInfoDouble(cp.GetSymbol(), SYMBOL_POINT) && pre_stop_loss_is_valid) ||
       (sl > 0. && !pre_stop_loss_is_valid)) {
        cp.Modify(sl);
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void manage_the_trailing_sl(long ticket, double sl_diff, double min_profit_of_tsl_point = -1)
{
    CPosition position;
    if(!(PositionSelectByTicket(ticket) && position.SelectByTicket(ticket)) || is_zero(sl_diff)) {
        return;
    }

    if(min_profit_of_tsl_point >= 0) {
        double open_price = position.GetPriceOpen();
        string sym = position.GetSymbol();
        double current_price = SymbolInfoDouble(sym, position.GetType() == TYPE_POSITION_BUY ? SYMBOL_BID : SYMBOL_ASK);
        double sl_effect = (position.GetType() == TYPE_POSITION_BUY ? 1 : -1) * sl_diff;
        double profit_diff = (position.GetType() == TYPE_POSITION_BUY ? 1 : -1) * (current_price - (open_price + sl_effect));
        double min_profit_of_tsl_diff = min_profit_of_tsl_point * SymbolInfoDouble(sym, SYMBOL_POINT);
        if(profit_diff < min_profit_of_tsl_diff)
            return;
    }

    double pre_stop_loss = position.GetStopLoss();
    bool pre_stop_loss_is_valid = pre_stop_loss > 0.0 && pre_stop_loss != EMPTY_VALUE;
    double sl = EMPTY_VALUE;
    if(position.GetType() == TYPE_POSITION_BUY) {
        sl = SymbolInfoDouble(position.GetSymbol(), SYMBOL_BID) - sl_diff;
        if(pre_stop_loss_is_valid)
            sl = MathMax(sl, pre_stop_loss);
    } else if(position.GetType() == TYPE_POSITION_SELL) {
        sl = SymbolInfoDouble(position.GetSymbol(), SYMBOL_ASK) + sl_diff;
        if(pre_stop_loss_is_valid)
            sl = MathMin(sl, pre_stop_loss);
    }

    if((MathAbs(pre_stop_loss - sl) > 10 * SymbolInfoDouble(position.GetSymbol(), SYMBOL_POINT) && pre_stop_loss_is_valid) ||
       (sl > 0. && !pre_stop_loss_is_valid)) {
        position.Modify(sl);
    }

    pre_stop_loss = sl;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_trade_volume_based_on_risk_percent(double sl_diff, double _risk_percent = 2, string sym = NULL)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double lot;

    if(sym == NULL)
        sym = _Symbol;

    if(sym[0] == 'X') {
        lot = (balance * _risk_percent * 0.01) /
              (100 * sl_diff * get_currency_base_in_balance_currency(sym));

    } else {
        lot = (balance * _risk_percent * 0.01) /
              (100000 * sl_diff * get_currency_base_in_balance_currency(sym));
    }

    lot = MathMin(lot, SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX));
    lot = MathMin(lot, (balance / 100000) * 50);
    lot = MathMax(lot, 0.01);
    lot = NormalizeDouble(lot, 2);

    return lot;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool has_open_positions(string sym, long _ea_magic_number)
{
    ulong ticket;
    for(int i = 0; i < PositionsTotal(); i++) {
        ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) &&
           PositionGetString(POSITION_SYMBOL) == sym &&
           PositionGetInteger(POSITION_MAGIC) == _ea_magic_number)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool has_open_orders(string sym, long _ea_magic_number)
{
    ulong ticket;
    for(int i = 0; i < OrdersTotal(); i++) {
        ticket = OrderGetTicket(i);
        if(OrderSelect(ticket) &&
           OrderGetString(ORDER_SYMBOL) == sym &&
           OrderGetInteger(ORDER_MAGIC) == _ea_magic_number)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_zero(double val)
{
    return MathAbs(val) < 0.0000000000001;
}
//+------------------------------------------------------------------+
