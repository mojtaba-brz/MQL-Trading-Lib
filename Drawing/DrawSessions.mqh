//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include "../TimeBasedModules/TimeUtils.mqh"
#include "../TimeBasedModules/SessionsInfo.mqh"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void draw_session_on_the_current_chart_if_is_new(string prefix, int start_hour, int end_hour, color bg_clr, color brdr_clr, string session_name = "", int offset = 0)
{
    datetime end_time, start_of_today_time_sec, start_time, mid_time;
    MqlDateTime start_time_struc;
    start_of_today_time_sec = get_start_of_today_time_sec();
    start_time = start_of_today_time_sec + start_hour * 3600 + offset;
    if(end_hour >= start_hour) {
        end_time = start_of_today_time_sec + end_hour   * 3600 + offset;
    } else {
        end_time = start_of_today_time_sec + end_hour   * 3600 + offset + 24 * 3600;
    }

    TimeToStruct(start_time, start_time_struc);
    while(start_time_struc.day_of_week == 0 || start_time_struc.day_of_week == 6) {
        start_time -= ONE_DAY_SEC;
    }

    mid_time = int(MathRound((end_time + start_time) * 0.5));

    double last_price = iClose(_Symbol, PERIOD_M15, 0);

    string bg_name = prefix + session_name;
    string brdr_name = prefix + session_name + " border";
    string tag_name = prefix + session_name + " tag";
    double lows[];
    double one_pip = 10 * _Point;
    datetime begining_time = MathMin(start_time, start_of_today_time_sec);
    int count = CopyLow(_Symbol, PERIOD_M15, begining_time, end_time, lows);
    if(count < 1) return;

    int lowest_low_idx = ArrayMinimum(lows);
    double tag_price  = lows[lowest_low_idx >= 0 ? lowest_low_idx : 0] - one_pip;

    bool session_is_new = ObjectFind(0, tag_name) < 0 || ObjectFind(0, bg_name) < 0 || ObjectFind(0, brdr_name) < 0 ||
                          ObjectGetInteger(0, tag_name, OBJPROP_TIME) != mid_time;

    if(session_is_new) {
        ObjectDelete(0, bg_name);
        ObjectDelete(0, brdr_name);
        ObjectDelete(0, tag_name);
        ResetLastError();
        count = 0;
        while(ObjectFind(0, brdr_name) && count < 50) {
            ObjectCreate(0, brdr_name, OBJ_RECTANGLE, 0, start_time, last_price * 10, end_time, last_price * -1);
            count++;
        }
        ObjectSetInteger(0, brdr_name, OBJPROP_COLOR, brdr_clr);
        ObjectSetInteger(0, bg_name, OBJPROP_FILL, 0);
        ObjectSetInteger(0, brdr_name, OBJPROP_BACK, 1);
        ObjectSetInteger(0, brdr_name, OBJPROP_WIDTH, 5);
        count = 0;
        while(ObjectFind(0, bg_name) && count < 50) {
            ObjectCreate(0, bg_name, OBJ_RECTANGLE, 0, start_time, last_price * 10, end_time, last_price * -1);
            count++;
        }
        ObjectSetInteger(0, bg_name, OBJPROP_COLOR, bg_clr);
        ObjectSetInteger(0, bg_name, OBJPROP_FILL, 1);
        ObjectSetInteger(0, bg_name, OBJPROP_BACK, 1);
        count = 0;
        while(ObjectFind(0, tag_name) && count < 50) {
            ObjectCreate(0, tag_name, OBJ_TEXT, 0, mid_time, tag_price);
            count++;
        }
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
