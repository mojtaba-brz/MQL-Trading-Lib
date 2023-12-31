//+------------------------------------------------------------------+
//|                                                   Mql Side TRBot |
//|                              Email : mojtababahrami147@gmail.com |
//+------------------------------------------------------------------+
#property description "Main TRBot EA"
#property description "Athur : Mojtaba Bahrami"
#property description "Email : mojtababahrami147@gmail.com"
#property copyright "MIT"

#ifdef __MQL5__
double get_indicator_value(int indicator_handle, int shift = 1, int line_index = 0)
  {
   if(indicator_handle < 0) return EMPTY_VALUE;

   double temp_buffer[];
   ArraySetAsSeries(temp_buffer, true);
   CopyBuffer(indicator_handle, line_index, shift, 1, temp_buffer);

   return temp_buffer[0];
  }
  
GeneralSignal get_close_price_cross_general_signal(string sym, int &handle, ENUM_TIMEFRAMES time_frame, int shift = 1)
  {
   if(handle < 0) return NO_SIGNAL;

   double last_close = iClose(sym, time_frame, shift);
   double last_base_value = get_indicator_value(handle, shift);

   if(last_close > last_base_value)
      return BUY_SIGNAL;
   else
      return SELL_SIGNAL;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
GeneralSignal get_zero_cross_general_signal(int &handle, int shift = 1)
  {
   if(handle < 0) return NO_SIGNAL;
   
   double last_indicator_value = get_indicator_value(handle, shift);

   if(last_indicator_value > 0)
      return BUY_SIGNAL;
   else
      return SELL_SIGNAL;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
GeneralSignal get_change_slope_general_signal(int &handle, int shift = 1)
  {
   if(handle < 0) return NO_SIGNAL;

// gather data ==========================================
   double last_indicator_value = get_indicator_value(handle, shift);
   double pre_indicator_value = get_indicator_value(handle, shift + 1);

   int i = 1;
   while(last_indicator_value == pre_indicator_value){
      i++;
      pre_indicator_value = get_indicator_value(handle, shift + i);
      if(i > 500){
         return NO_SIGNAL;
      }
   }

   if(last_indicator_value > pre_indicator_value)
      return BUY_SIGNAL;
   else
      return SELL_SIGNAL;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
GeneralSignal get_two_line_cross_general_signal(int &handle, int shift = 1)
  {
   if(handle < 0) return NO_SIGNAL;

// gather data ==========================================
   double line1 = get_indicator_value(handle, shift, 0);
   double line2 = get_indicator_value(handle, shift, 1);

   if(line1 > line2)
      return BUY_SIGNAL;
   else
      return SELL_SIGNAL;
  }

#else

#endif

  
