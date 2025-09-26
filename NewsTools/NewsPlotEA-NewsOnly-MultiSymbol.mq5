//+------------------------------------------------------------------+
//|                                                NewsIndicator.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "Libs/MQL5/Libs.mqh"

input ENUM_TRADE_MODE symbol_mode = TRADE_MODE_ALL_28_PAIRS; // Indicator Symbol Mode

// Constants =========================================================
#define MS_NEWS_INDICATOR_PREFIX "NIP_MS_"

// Globals ===========================================================
datetime last_news_date = 0;
datetime last_news_update_time = 0;

ForexFactoryNewsHandlerClass ffn_handler;
string sym_array[];

long news_index = 0;
datetime pre_obj_time = 0;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
   {
    ArrayFree(sym_array);
    Comment("Initialization...");
    while(!ffn_handler.update_news());
    switch(symbol_mode)
       {
        default:
        case TRADE_MODE_SINGLE:
            ArrayResize(sym_array, 1);
            sym_array[0] = broker_symbol_to_standard_symbol(_Symbol);
            ffn_handler.update_news_filter_with_symbol(sym_array[0]);
            plot_news(sym_array[0], ffn_handler);
            break;

        case TRADE_MODE_ALL_USD_PAIRS:
            ArrayResize(sym_array, 7);
            for(int i = 0; i < 7; i++)
               {
                sym_array[i] = broker_symbol_to_standard_symbol(required_symbols[i]);
                ffn_handler.update_news_filter_with_symbol(sym_array[i], false);
                plot_news(sym_array[i], ffn_handler);
               }
            break;

        case TRADE_MODE_ALL_28_PAIRS:
            ArrayResize(sym_array, 28);
            for(int i = 0; i < 28; i++)
               {
                sym_array[i] = broker_symbol_to_standard_symbol(all_supported_symbols[i]);
                ffn_handler.update_news_filter_with_symbol(sym_array[i], false);
                plot_news(sym_array[i], ffn_handler);
               }
            break;
       }
    news_index = 0;
    pre_obj_time = 0;
    Comment("Done...");
    return(INIT_SUCCEEDED);
   }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
void OnTick() {}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
   {
    Comment("");
    ObjectsDeleteAll(0, MS_NEWS_INDICATOR_PREFIX);
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string pre_sym = "";
void highlight_news_on_the_chart(string sym, ForexFactoryNews &news, double price = 0.)
   {
    if(pre_obj_time == news.release_time) {
        if(StringCompare(pre_sym, sym) == 0) return;
        string object_name = MS_NEWS_INDICATOR_PREFIX + IntegerToString(news_index) + "_" + "(" + sym + ") - ";
        ObjectCreate(0, object_name + "_label", OBJ_TEXT, 0, news.release_time, price);
        ObjectSetString(0, object_name + "_label", OBJPROP_TEXT, ".");
        news_index++;  
        pre_sym = sym;  
        return;        
    }

    string object_name = MS_NEWS_INDICATOR_PREFIX + IntegerToString(news_index) + "_" + "(" + sym + ") - ";
    ObjectCreate(0, object_name, OBJ_VLINE, 0, news.release_time, price);
    ObjectSetInteger(0, object_name, OBJPROP_BACK, true);
    ObjectSetInteger(0, object_name, OBJPROP_STYLE, STYLE_DASH);

    ObjectCreate(0, object_name + "_label", OBJ_TEXT, 0, news.release_time, price);
    ObjectSetString(0, object_name + "_label", OBJPROP_TEXT, news.currency + " - " + news.title);
    ObjectSetInteger(0, object_name + "_label", OBJPROP_COLOR, clrWheat);
    ObjectSetInteger(0, object_name + "_label", OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetDouble(0, object_name + "_label", OBJPROP_ANGLE, 90);

    news_index++;
    pre_obj_time = news.release_time;
    pre_sym = sym;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void plot_news(string sym, ForexFactoryNewsHandlerClass &_ffn_handler)
   {
    _ffn_handler.filter_the_news();
    for(int i = 0; i < ArraySize(_ffn_handler.filtered_forex_factory_news); i++)
       {
        highlight_news_on_the_chart(sym, _ffn_handler.filtered_forex_factory_news[i],
                                    iHigh(_Symbol, PERIOD_CURRENT,
                                          iBarShift(_Symbol, PERIOD_CURRENT, ffn_handler.filtered_forex_factory_news[i].release_time)));
       }
   }
//+------------------------------------------------------------------+
