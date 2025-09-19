//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include "../TimeBasedModules/TimeUtils.mqh"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void draw_session_on_the_current_chart_if_is_new(string prefix, int start_hour, int end_hour, color bg_clr, color brdr_clr, string session_name = "", int offset = 0)
{
    datetime end_time, start_of_today_time_sec, start_time, mid_time;
    start_of_today_time_sec = get_start_of_today_time_sec();
    start_time = start_of_today_time_sec + start_hour * 3600 + offset;
    if(end_hour >= start_hour) {
        end_time = start_of_today_time_sec + end_hour   * 3600 + offset;
    } else {
        end_time = start_of_today_time_sec + end_hour   * 3600 + offset + 24 * 3600;
    }
    mid_time = int(MathRound((end_time + start_time) * 0.5));

    double last_price = iClose(_Symbol, PERIOD_CURRENT, 0);

    string bg_name = prefix + session_name;
    string brdr_name = prefix + session_name + " border";
    string tag_name = prefix + session_name + " tag";
    double lows[];
    double one_pip = 10 * _Point;
    CopyLow(_Symbol, PERIOD_CURRENT, MathMin(start_time, start_of_today_time_sec), end_time, lows);
    double tag_price  = lows[ArrayMinimum(lows)] - one_pip;

    bool session_is_new = ObjectFind(0, tag_name) < 0 ||
                          ObjectGetInteger(0, tag_name, OBJPROP_TIME) != mid_time;

    if(session_is_new) {
        ObjectDelete(0, bg_name);
        ObjectDelete(0, brdr_name);
        ObjectDelete(0, tag_name);
        ObjectCreate(0, brdr_name, OBJ_RECTANGLE, 0, start_time, last_price * 10, end_time, last_price * -1);
        ObjectSetInteger(0, brdr_name, OBJPROP_COLOR, brdr_clr);
        ObjectSetInteger(0, bg_name, OBJPROP_FILL, 0);
        ObjectSetInteger(0, brdr_name, OBJPROP_BACK, 1);
        ObjectSetInteger(0, brdr_name, OBJPROP_WIDTH, 5);
        ObjectCreate(0, bg_name, OBJ_RECTANGLE, 0, start_time, last_price * 10, end_time, last_price * -1);
        ObjectSetInteger(0, bg_name, OBJPROP_COLOR, bg_clr);
        ObjectSetInteger(0, bg_name, OBJPROP_FILL, 1);
        ObjectSetInteger(0, bg_name, OBJPROP_BACK, 1);
        ObjectCreate(0, tag_name, OBJ_TEXT, 0, mid_time, tag_price);
        ObjectSetString(0, tag_name, OBJPROP_TEXT, session_name);
        ObjectSetInteger(0, tag_name, OBJPROP_ALIGN, ALIGN_CENTER);
        ObjectSetInteger(0, tag_name, OBJPROP_ANCHOR, ANCHOR_CENTER);
        ObjectSetInteger(0, tag_name, OBJPROP_COLOR, clrGold);
        ObjectSetInteger(0, tag_name, OBJPROP_FONTSIZE, 25);
        ObjectSetInteger(0, tag_name, OBJPROP_WIDTH, 5);

    } else if(MathAbs((ObjectGetDouble(0, tag_name, OBJPROP_PRICE) - tag_price)) > one_pip) {
        ObjectSetDouble(0, tag_name, OBJPROP_PRICE, tag_price);
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void update_session_tag_pos_if_needed(string prefix, int start_hour, int end_hour, string session_name = "", int offset = 0)
{
    datetime end_time, start_of_today_time_sec, start_time;
    start_of_today_time_sec = get_start_of_today_time_sec();
    start_time = start_of_today_time_sec + start_hour * 3600 + offset;
    if(end_hour >= start_hour) {
        end_time = start_of_today_time_sec + end_hour   * 3600 + offset;
    } else {
        end_time = start_of_today_time_sec + end_hour   * 3600 + offset + 24 * 3600;
    }

    string tag_name = prefix + session_name + " tag";
    double lows[];
    double one_pip = 10 * _Point;
    CopyLow(_Symbol, PERIOD_CURRENT, MathMin(start_time, start_of_today_time_sec), end_time, lows);
    double tag_price  = lows[ArrayMinimum(lows)] - one_pip;
    if(MathAbs((ObjectGetDouble(0, tag_name, OBJPROP_PRICE) - tag_price)) > one_pip) {
        ObjectSetDouble(0, tag_name, OBJPROP_PRICE, tag_price);
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void clear_session(string prefix, string session_name = "")
{
    string bg_name = prefix + session_name;
    string brdr_name = prefix + session_name + " border";
    string tag_name = prefix + session_name + " tag";
    ObjectDelete(0, bg_name);
    ObjectDelete(0, brdr_name);
    ObjectDelete(0, tag_name);
}
//+------------------------------------------------------------------+
