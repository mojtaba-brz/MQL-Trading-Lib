//+------------------------------------------------------------------+
//|                                                 SessionsInfo.mqh |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

// Sessions Reference: https://www.babypips.com/tools/forex-market-hours
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
#define ONE_DAY_SEC (24 * ONE_HOUR_SEC)

int get_ny_day_light_saving_offset_sec()
  {
// In the United States, the shift occurs at 02:00 local time on the second Sunday in March
// and the clock jumps backward at 02:00 on the first Sunday in November.
// ref : https://www.mql5.com/en/articles/599#time_zones

   datetime current_time_ny = TimeGMT() + NY_TIME_OFFSET_SEC;
   MqlDateTime current_time_struct_ny;
   TimeToStruct(current_time_ny, current_time_struct_ny);

   if(current_time_struct_ny.mon > 11 || current_time_struct_ny.mon < 3) // No shift
      return 0;

   if(current_time_struct_ny.mon < 11 && current_time_struct_ny.mon > 3) // +1 Hour shift
      return ONE_HOUR_SEC;

   if(current_time_struct_ny.mon == 11) // In November
     {
      if(current_time_struct_ny.day > 7) // After 7 days
         return 0;

      if(current_time_struct_ny.day_of_week == 0) // First Sunday
        {
         if(current_time_struct_ny.hour >= 2)
            return 0;
         else
            return ONE_HOUR_SEC;
        }

      if(current_time_struct_ny.day_of_week - current_time_struct_ny.day < 0) // After Sunday in first week
         return 0;

      return ONE_HOUR_SEC; // Before first Sunday in November

     }

   if(current_time_struct_ny.mon == 3) // In March
     {
      if(current_time_struct_ny.day <= 7) // In first 7 days
         return 0;

      if(current_time_struct_ny.day <= 14) // In second 7 days
        {
         if(current_time_struct_ny.day_of_week == 0) // Second Sunday
           {
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
