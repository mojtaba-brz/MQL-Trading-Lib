//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#include "MQL_Easy/MQL_Easy/MQL_Easy.mqh"
#include "typedefs.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
PositionState get_current_position_state(string symbol, long magic)
   {
    CPosition cp(symbol, magic);

    if(cp.get_total_specified_positions() >= 1)
       {
        int pos_type = cp.get_position_type();
        if(pos_type == POSITION_TYPE_BUY)
           {
            return POS_STATE_LONG_POSITION;
           }
        if(pos_type == POSITION_TYPE_SELL)
           {
            return POS_STATE_SHORT_POSITION;
           }
        return POS_STATE_NO_POSITION;
       }
    else
       {
        return POS_STATE_NO_POSITION;
       }
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
PositionState get_current_position_state_cp(CPosition &cp)
   {

    if(cp.get_total_specified_positions() >= 1)
       {
        int pos_type = cp.get_position_type();
        if(pos_type == POSITION_TYPE_BUY)
           {
            return POS_STATE_LONG_POSITION;
           }
        if(pos_type == POSITION_TYPE_SELL)
           {
            return POS_STATE_SHORT_POSITION;
           }
        return POS_STATE_NO_POSITION;
       }
    else
       {
        return POS_STATE_NO_POSITION;
       }
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void manage_the_trailing_sl_of_position(CPosition &cp, const double sl_diff, ENUM_TIMEFRAMES time_frame)
   {
    PositionState cp_state = get_current_position_state_cp(cp);
    if(cp_state == POS_STATE_NO_POSITION)
       {
        return;
       }

    double pre_stop_loss = cp.GetStopLoss();
    double sl = EMPTY_VALUE;
    if(cp_state == POS_STATE_LONG_POSITION)
       {
        sl = SymbolInfoDouble(cp.GetSymbol(), SYMBOL_BID) - sl_diff;
        if(pre_stop_loss != EMPTY_VALUE)
            sl = MathMax(sl, pre_stop_loss);
       }
    else
        if(cp_state == POS_STATE_SHORT_POSITION)
           {
            sl = SymbolInfoDouble(cp.GetSymbol(), SYMBOL_ASK) + sl_diff;
            if(pre_stop_loss != EMPTY_VALUE)
                sl = MathMin(sl, pre_stop_loss);
           }

    if(MathAbs(pre_stop_loss - sl) > 10 * SymbolInfoDouble(cp.GetSymbol(), SYMBOL_POINT) && pre_stop_loss != EMPTY_VALUE)
       {
        cp.Modify(sl);
       }
    pre_stop_loss = sl;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void manage_the_trailing_sl(long ticket, double sl_diff)
   {
    CPosition position;
    if(!(PositionSelectByTicket(ticket) && position.SelectByTicket(ticket)) || is_zero(sl_diff))
       {
        return;
       }

    double pre_stop_loss = position.GetStopLoss();
    double sl = EMPTY_VALUE;
    if(position.GetType() == TYPE_POSITION_BUY)
       {
        sl = SymbolInfoDouble(position.GetSymbol(), SYMBOL_BID) - sl_diff;
        if(pre_stop_loss != EMPTY_VALUE)
            sl = MathMax(sl, pre_stop_loss);
       }
    else
        if(position.GetType() == TYPE_POSITION_SELL)
           {
            sl = SymbolInfoDouble(position.GetSymbol(), SYMBOL_ASK) + sl_diff;
            if(pre_stop_loss != EMPTY_VALUE)
                sl = MathMin(sl, pre_stop_loss);
           }

    if(MathAbs(pre_stop_loss - sl) > 10 * SymbolInfoDouble(position.GetSymbol(), SYMBOL_POINT) && pre_stop_loss != EMPTY_VALUE)
       {
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

    double lot = (balance * _risk_percent * 0.01) /
                 (100000 * sl_diff * get_currency_base_in_balance_currency(sym));

    lot = MathMin(lot, SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX));
    lot = MathMin(lot, (balance / 100000) * 50);
    lot = MathMax(lot, 0.01);
    lot = NormalizeDouble(lot, 2);

    return lot;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_zero(double val)
   {
    return MathAbs(val) < 0.0000000000001;
   }
//+------------------------------------------------------------------+
