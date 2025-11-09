#ifdef __MQL4__
#define POSITION_TYPE_BUY ORDER_TYPE_BUY
#define POSITION_TYPE_SELL ORDER_TYPE_SELL
#endif

#define MAX_DOUBLE_VALUE (1.7976931348623158e+308)
#define MIN_DOUBLE_VALUE (2.2250738585072014e-308)
#define MAX_FLOAT_VALUE (3.402823466e+38)
#define MIN_FLOAT_VALUE (1.175494351e-38)
#define MAX_INT_VALUE (2147483647)
#define MIN_INT_VALUE (-2147483648)
#define MAX_LONG_VALUE (9223372036854775807)
#define MIN_LONG_VALUE (-9223372036854775808)

#include "MQL_Easy/MQL_Easy/MQL_Easy.mqh"

enum TradingAction
{
    TRADING_ACTION_DO_NOTHING,
    TRADING_ACTION_BUY,
    TRADING_ACTION_SELL,
    TRADING_ACTION_MANAGE_POSITIONS,
    TRADING_ACTION_CLOSE_POSITIONS
};

enum PositionState
{
    POS_STATE_NO_POSITION,
    POS_STATE_LONG_POSITION,
    POS_STATE_SHORT_POSITION,
    POS_STATE_MORE_THAN_ONE_POSITION
};

enum IndicatorSignalType
{
    INDICATOR_SIGNAL_TYPE_DUMMY,
    INDICATOR_SIGNAL_TYPE_ZERO_CROSS,
    INDICATOR_SIGNAL_TYPE_SLOPE_CHANGE,
    INDICATOR_SIGNAL_TYPE_TWO_LINE_CROSS,
    INDICATOR_SIGNAL_TYPE_CLOSE_PRICE_CROSS
};

enum GeneralSignal
{
    NO_SIGNAL,
    NO_INDICATOR,
    BUY_SIGNAL,
    SELL_SIGNAL
};

enum PosCloseMode
{
    POS_CLOSE_ALL,
    POS_CLOSE_BUY,
    POS_CLOSE_SELL
};

enum OrderCloseMode
{
    ORDER_CLOSE_ALL,
    ORDER_CLOSE_BUY,
    ORDER_CLOSE_SELL
};

struct NewsStruct
  {
   datetime          time;
   string            title, impact, currency;
   double            mean_im_profit_pp, std_im_profit_pp, max_spread_pp;
  };

struct OrderSpecs {
    double order_price, sl;
    ENUM_TYPE_ORDER order_type;
    ulong  ticket;
};

struct PosSpecs {
    double pos_price, sl, tp;
    ENUM_TYPE_POSITION pos_type;
    ulong  ticket;
};