//+------------------------------------------------------------------+
//|                                                NewsIndicator.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_separate_window

#include "../MQL-Trading-Lib.mqh"

#property indicator_buffers 4

#property indicator_plots 1

#property indicator_minimum -0.1
#property indicator_maximum 1.1

#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrBlue
#property indicator_width1  5

// Constants =========================================================
#define NEWS_INDICATOR_PREFIX "NIP_"

// Globals ===========================================================
double is_there_news[],
       mean_im_profit_pp[],
       max_spread_pp[],
       std_im_profit_pp[];

datetime dt;
NewsStruct news_list[];
int last_news_idx;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(!parse_news_file())
      return INIT_FAILED;
      
   SetIndexBuffer(0, is_there_news, INDICATOR_DATA);

   SetIndexBuffer(1, mean_im_profit_pp, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, max_spread_pp, INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, std_im_profit_pp, INDICATOR_CALCULATIONS);


   for(int i = 0; i < ArraySize(news_list); i++)
     {
      highlight_news_on_the_chart(news_list[i]);
     }

   last_news_idx = 0;
   dt = get_dt();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//---
   if(rates_total <= 0)
      return 0;
   if(last_news_idx >= ArraySize(news_list))
      return(prev_calculated);

   for(int i = MathMax(prev_calculated, 1); i < rates_total; i++)
     {
      is_there_news[i]    = 0.;
      while((time[i] + dt) > news_list[last_news_idx].time)
        {
         last_news_idx++;

         if(last_news_idx >= ArraySize(news_list))
            return(i);
        }

      while((time[i] + (2 * dt)) > news_list[last_news_idx].time)
        {
         is_there_news[i]    = 1.;
         mean_im_profit_pp[i] = news_list[last_news_idx].mean_im_profit_pp;
         max_spread_pp[i] = news_list[last_news_idx].max_spread_pp;
         std_im_profit_pp[i]  = news_list[last_news_idx].std_im_profit_pp;
         last_news_idx++;
         if(last_news_idx >= ArraySize(news_list))
            return(i);
        }
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, NEWS_INDICATOR_PREFIX);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
static long news_index = 0;
static datetime pre_obj_time = 0;
void highlight_news_on_the_chart(NewsStruct &news)
  {
   if(pre_obj_time == news.time)
      return;
    
    double price = iHigh(_Symbol, PERIOD_CURRENT, iBarShift(_Symbol, PERIOD_CURRENT, news.time));
    string object_name = NEWS_INDICATOR_PREFIX + IntegerToString(news_index);
    ObjectCreate(0, object_name, OBJ_VLINE, 0, news.time, price);
    ObjectSetInteger(0, object_name, OBJPROP_BACK, true);
    ObjectSetInteger(0, object_name, OBJPROP_STYLE, STYLE_DASH);

    ObjectCreate(0, object_name + "_label", OBJ_TEXT, 0, news.time, price);
    ObjectSetString(0, object_name + "_label", OBJPROP_TEXT, news.title);
    ObjectSetInteger(0, object_name + "_label", OBJPROP_COLOR, clrWheat);
    ObjectSetInteger(0, object_name + "_label", OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetDouble(0, object_name + "_label", OBJPROP_ANGLE, 90);

   news_index++;
   pre_obj_time = news.time;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool parse_news_file()
  {
   string csv_file_name = broker_symbol_to_standard_symbol(_Symbol) + "-NewsIndicatorFile.csv";
   ResetLastError();
   int csv_file_handle = FileOpen(csv_file_name, FILE_ANSI | FILE_CSV | FILE_COMMON | FILE_READ, "\n");
   if(csv_file_handle < 0)
     {
      Alert("Could not read " + csv_file_name + ". Error : " + IntegerToString(GetLastError()));
      FileClose(csv_file_handle);
      return(false);
     }
   else
     {
      int line_count = 0;
      ArrayFree(news_list);
      NewsStruct news_struc_temp;
      MqlDateTime time_temp_struct;
      string line_items[];
      while(!FileIsEnding(csv_file_handle))
        {
         string line = FileReadString(csv_file_handle);
         if(line_count > 0)
           {
            StringSplit(line, ',', line_items);

            time_temp_struct.year = (int)StringToInteger(line_items[1]);
            time_temp_struct.mon = (int)StringToInteger(line_items[2]);
            time_temp_struct.day = (int)StringToInteger(line_items[3]);
            time_temp_struct.hour = (int)StringToInteger(line_items[4]);
            time_temp_struct.min = (int)StringToInteger(line_items[5]);
            news_struc_temp.time = StructToTime(time_temp_struct);

            news_struc_temp.title = line_items[6];
            news_struc_temp.impact = line_items[7];
            if(ArraySize(line_items) > 9) {
               news_struc_temp.mean_im_profit_pp = StringToDouble(line_items[8]);
               news_struc_temp.max_spread_pp = StringToDouble(line_items[9]);
               news_struc_temp.std_im_profit_pp = StringToDouble(line_items[10]);
            }

            ArrayResize(news_list, ArraySize(news_list) + 1);
            news_list[ArraySize(news_list) - 1] = news_struc_temp;
           }
         else
           {
            line_count++;
           }
        }
      FileClose(csv_file_handle);
      return true;
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime get_dt()
  {
   switch(_Period)
     {
      case PERIOD_D1:
         return 24 * 60 * 60;

      case PERIOD_H1:
         return 60 * 60;

      case PERIOD_H2:
         return 2 * 60 * 60;

      case PERIOD_H3:
         return 3 * 60 * 60;

      case PERIOD_H4:
         return 4 * 60 * 60;

      case PERIOD_H6:
         return 6 * 60 * 60;

      case PERIOD_H8:
         return 8 * 60 * 60;

      case PERIOD_H12:
         return 12 * 60 * 60;

      case PERIOD_M1:
         return 60;

      case PERIOD_M2:
         return 2 * 60;

      case PERIOD_M3:
         return 3 * 60;

      case PERIOD_M4:
         return 4 * 60;

      case PERIOD_M5:
         return 5 * 60;

      case PERIOD_M6:
         return 6 * 60;

      case PERIOD_M10:
         return 10 * 60;

      case PERIOD_M12:
         return 12 * 60;

      case PERIOD_M15:
         return 15 * 60;

      case PERIOD_M20:
         return 20 * 60;

      case PERIOD_M30:
         return 20 * 60;

      case PERIOD_MN1:
         return 30 * 24 * 60 * 60;

      case PERIOD_W1:
         return 7 * 24 * 60 * 60;

      default :
         return 60;
     }
  }
//+------------------------------------------------------------------+
