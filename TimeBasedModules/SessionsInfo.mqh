//+------------------------------------------------------------------+
//|                                                 SessionsInfo.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// Sessions Reference: https://www.babypips.com/tools/forex-market-hours
#define SYDNEY_SESSION_START_HOUR_FOREX (0)
#define SYDNEY_SESSION_END_HOUR_FOREX (9)
#define JAPAN_SESSION_START_HOUR_FOREX (3)
#define JAPAN_SESSION_END_HOUR_FOREX (12)
#define LONDON_SESSION_START_HOUR_FOREX (10)
#define LONDON_SESSION_END_HOUR_FOREX (19)
#define NY_SESSION_START_HOUR_FOREX (15)
#define NY_SESSION_END_HOUR_FOREX (23)

#define SYDNEY_SESSION_START_HOUR_NY (17)
#define SYDNEY_SESSION_END_HOUR_NY (2)
#define JAPAN_SESSION_START_HOUR_NY (20)
#define JAPAN_SESSION_END_HOUR_NY (5)
#define LONDON_SESSION_START_HOUR_NY (3)
#define LONDON_SESSION_END_HOUR_NY (12)
#define NY_SESSION_START_HOUR_NY (8)
#define NY_SESSION_END_HOUR_NY (16)

#define ONE_HOUR_SEC (3600)
#define NY_TIME_OFFSET_SEC (-5 * ONE_HOUR_SEC)
#define FOREX_TIME_OFFSET_HOUR (3)
#define FOREX_TIME_OFFSET_SEC (FOREX_TIME_OFFSET_HOUR * ONE_HOUR_SEC)
#define ONE_DAY_SEC (24 * ONE_HOUR_SEC)

enum SessionEnum {
    SESSION_SYDNEY,
    SESSION_JAPAN,
    SESSION_LONDON,
    SESSION_NY,
    SESSION_ALL
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int get_ny_day_light_saving_offset_sec(datetime current_time_ny = 0)
{
// In the United States, the shift occurs at 02:00 local time on the second Sunday in March
// and the clock jumps backward at 02:00 on the first Sunday in November.
// ref : https://www.mql5.com/en/articles/599#time_zones
    if(current_time_ny == 0) {
        current_time_ny = TimeGMT() + NY_TIME_OFFSET_SEC;
    }
    MqlDateTime current_time_struct_ny;
    TimeToStruct(current_time_ny, current_time_struct_ny);

    if(current_time_struct_ny.mon > 11 || current_time_struct_ny.mon < 3) // No shift
        return 0;

    if(current_time_struct_ny.mon < 11 && current_time_struct_ny.mon > 3) // +1 Hour shift
        return ONE_HOUR_SEC;

    if(current_time_struct_ny.mon == 11) { // In November
        if(current_time_struct_ny.day > 7) // After 7 days
            return 0;

        if(current_time_struct_ny.day_of_week == 0) { // First Sunday
            if(current_time_struct_ny.hour >= 2)
                return 0;
            else
                return ONE_HOUR_SEC;
        }

        if(current_time_struct_ny.day_of_week - current_time_struct_ny.day < 0) // After Sunday in first week
            return 0;

        return ONE_HOUR_SEC; // Before first Sunday in November

    }

    if(current_time_struct_ny.mon == 3) { // In March
        if(current_time_struct_ny.day <= 7) // In first 7 days
            return 0;

        if(current_time_struct_ny.day <= 14) { // In second 7 days
            if(current_time_struct_ny.day_of_week == 0) { // Second Sunday
                if(current_time_struct_ny.hour >= 2)
                    return ONE_HOUR_SEC;
                else
                    return 0;
            }

            if(current_time_struct_ny.day_of_week - current_time_struct_ny.day - 7 > 0) // Before Second Sunday in
                return 0;
        }


        return ONE_HOUR_SEC; // After second Sunday in March

    }

    return 0;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_in_session(SessionEnum session_name)
{
    MqlDateTime current_time_struct;
    TimeCurrent(current_time_struct);
    switch(session_name) {
    case SESSION_JAPAN:
        return current_time_struct.hour < JAPAN_SESSION_END_HOUR_FOREX && current_time_struct.hour >= JAPAN_SESSION_START_HOUR_FOREX;
        break;
    case SESSION_SYDNEY:
        return current_time_struct.hour < SYDNEY_SESSION_END_HOUR_FOREX && current_time_struct.hour >= SYDNEY_SESSION_START_HOUR_FOREX;
        break;
    case SESSION_LONDON:
        return current_time_struct.hour < LONDON_SESSION_END_HOUR_FOREX && current_time_struct.hour >= LONDON_SESSION_START_HOUR_FOREX;
        break;
    case SESSION_NY:
        return current_time_struct.hour < NY_SESSION_END_HOUR_FOREX && current_time_struct.hour >= NY_SESSION_START_HOUR_FOREX;
        break;
    case  SESSION_ALL:
    default:
        return true;
        break;
    }
}
//+------------------------------------------------------------------+
