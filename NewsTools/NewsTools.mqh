//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

#include "../ArrayFunctions.mqh"

enum NewsImpact
   {
    ENUM_NEWS_IMPACT_GREY,
    ENUM_NEWS_IMPACT_MEDIUM,
    ENUM_NEWS_IMPACT_RED,
    ENUM_NEWS_IMPACT_HOLIDAY
   };

struct ForexFactoryNews
   {
    string            title, currency, date, impact_str, forecast, previous;
    MqlDateTime       datatime;
    NewsImpact        impact;
   };


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class ForexFactoryNewsHandlerClass
   {
private:
    int               num_of_news;
    string            news_filter_currencies[],
                      news_filter_titles[];

public:
    ForexFactoryNews  forex_factory_news[];
                     ForexFactoryNewsHandlerClass() {update_news();}
                    ~ForexFactoryNewsHandlerClass() {}
    void              update_news();
    bool              in_news_zone(string currency, NewsImpact impact, double time_margin_left_s, double time_margin_right_s);
    bool              in_filtered_news_zone(double time_margin_left_s, double time_margin_right_s, datetime &news_date);
    void              print_news(int index);
    void             update_news_filter_with_symbol(string sym);
    void             filter_the_news();
   };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ForexFactoryNewsHandlerClass::update_news()
   {
    char data[], server_resp[];
    string header, data_string = "";

    int http_code = WebRequest("GET", "https://nfs.faireconomy.media/ff_calendar_thisweek.json", NULL, 20, data, server_resp, header);
    if(http_code < 0)
       {
        Alert("Please add \"https://nfs.faireconomy.media/ff_calendar_thisweek.json\"\nto Tools > Options > Expert Advisors > \nAllow WebRequestes for listed URL and don't forget to enable it.");
       }
    else
       {
        num_of_news = parse_ff_jason_char_array(server_resp, ArraySize(server_resp), forex_factory_news);
       }
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ForexFactoryNewsHandlerClass::in_news_zone(string currency, NewsImpact impact, double time_margin_left_s, double time_margin_right_s)
   {
    for(int i = 0; i < ArraySize(forex_factory_news); i++)
       {
        if(forex_factory_news[i].currency == currency && forex_factory_news[i].impact == impact)
           {
            datetime current_time = TimeGMT();
            datetime news_time = StructToTime(forex_factory_news[i].datatime);
            if(news_time <= (current_time + time_margin_right_s) && news_time >= (current_time - time_margin_left_s))
               {
                return true;
               }
           }
       }
    return false;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ForexFactoryNewsHandlerClass::filter_the_news()
   {
    int i = 0;
    while(ArraySize(forex_factory_news) > i)
       {
        if((StringCompare(forex_factory_news[i].currency, news_filter_currencies[0]) == 0 ||
           StringCompare(forex_factory_news[i].currency, news_filter_currencies[1]) == 0 ||
           StringCompare(forex_factory_news[i].currency, news_filter_currencies[2]) == 0) &&
           (forex_factory_news[i].impact == ENUM_NEWS_IMPACT_RED || forex_factory_news[i].impact == ENUM_NEWS_IMPACT_MEDIUM))
           {
            int j = 0;
            for(j = 0; j < ArraySize(news_filter_titles); j++)
               {
                if(StringCompare(forex_factory_news[i].title, news_filter_titles[j]) == 0)
                   {
                    i++;
                    break;
                   }
               }
            if(j == ArraySize(news_filter_titles))
               {
                EraseOrdered(forex_factory_news, i);
               }
           }
        else
           {
            EraseOrdered(forex_factory_news, i);
           }
       }
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ForexFactoryNewsHandlerClass::in_filtered_news_zone(double time_margin_left_s, double time_margin_right_s, datetime &news_date)
   {
    for(int i = 0; i < ArraySize(forex_factory_news); i++)
       {
        datetime current_time = TimeCurrent();
        datetime server_offset = TimeGMT() - TimeCurrent();
        news_date = StructToTime(forex_factory_news[i].datatime) - server_offset;
        if(news_date <= (current_time + time_margin_right_s) && news_date >= (current_time - time_margin_left_s))
           {
            return true;
           }
       }
    return false;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ForexFactoryNewsHandlerClass::print_news(int index)
   {
    PrintFormat("Currency : %s, Impact : %s, TimeOriginal : %s, DateTime: %i/%i/%i  %i:%i", forex_factory_news[index].currency,
                forex_factory_news[index].impact_str, forex_factory_news[index].date, forex_factory_news[index].datatime.year
                , forex_factory_news[index].datatime.mon, forex_factory_news[index].datatime.day, forex_factory_news[index].datatime.hour
                , forex_factory_news[index].datatime.min, forex_factory_news[index].datatime.sec);
   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int parse_ff_jason_char_array(char &server_resp[], int len, ForexFactoryNews &forex_factory_news[])
   {
    int num_of_news = 0, start_index = 0, end_index = 0;
    for(int i = 0; i < len; i++)
       {
        if(server_resp[i] == '{')
           {
            start_index = i;
           }
        else
            if(server_resp[i] == '}')
               {
                end_index = i;
                num_of_news++;
                ArrayResize(forex_factory_news, num_of_news);
                forex_factory_news[num_of_news - 1] = parse_single_ff_news_string(CharArrayToString(server_resp, start_index + 1, end_index - 1));
               }
       }

    return num_of_news;
   }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ForexFactoryNews parse_single_ff_news_string(string news)
   {
    ForexFactoryNews ffn;
    string news_parts[], news_parts_2[];
    StringSplit(news, '"', news_parts);

    ffn.title      = news_parts[3];
    ffn.currency   = news_parts[7];
    ffn.date       = news_parts[11];
    ffn.impact_str = news_parts[15];
    ffn.forecast   = news_parts[19];
    ffn.previous   = news_parts[23];


    TimeToStruct(StringToTime(ffn.date), ffn.datatime);
    StringSplit(ffn.date, 'T', news_parts);
    StringSplit(news_parts[1], '-', news_parts_2);
    StringSplit(news_parts_2[0], ':', news_parts);
    ffn.datatime.hour = (int)StringToInteger(news_parts[0]) + 4;
    ffn.datatime.min = (int)StringToInteger(news_parts[1]);
    ffn.datatime.sec = (int)StringToInteger(news_parts[2]);

    ffn.impact = ffn.impact_str == "Holiday" ? ENUM_NEWS_IMPACT_HOLIDAY :
                 ffn.impact_str == "High"    ? ENUM_NEWS_IMPACT_RED    :
                 ffn.impact_str == "Medium"  ? ENUM_NEWS_IMPACT_MEDIUM : ENUM_NEWS_IMPACT_GREY;

    return ffn;
   }

//+------------------------------------------------------------------+
void ForexFactoryNewsHandlerClass::update_news_filter_with_symbol(string sym)
   {
    if(StringCompare(sym, "AUDJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 1);
        news_filter_currencies[0] = "AUD";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "JPY";
        news_filter_titles[0] = "BOJ Policy Rate";
        return;
       }

    if(StringCompare(sym, "AUDNZD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 3);
        news_filter_currencies[0] = "AUD";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "NZD";
        news_filter_titles[0] = "Official Cash Rate";
        news_filter_titles[1] = "RBNZ Monetary Policy Statement";
        news_filter_titles[2] = "RBNZ Rate Statement";
        return;
       }

    if(StringCompare(sym, "AUDUSD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 7);
        news_filter_currencies[0] = "AUD";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "USD";
        news_filter_titles[0] = "Building Permits";
        news_filter_titles[1] = "CPI m\\/m";
        news_filter_titles[2] = "CPI y\\/y";
        news_filter_titles[3] = "Core CPI m\\/m";
        news_filter_titles[4] = "Existing Home Sales";
        news_filter_titles[5] = "FOMC Economic Projections";
        news_filter_titles[6] = "Treasury Currency Report";
        return;
       }

    if(StringCompare(sym, "CADJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 1);
        news_filter_currencies[0] = "CAD";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "JPY";
        news_filter_titles[0] = "BOJ Policy Rate";
        return;
       }

    if(StringCompare(sym, "CHFJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 5);
        news_filter_currencies[0] = "CHF";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "JPY";
        news_filter_titles[0] = "BOJ Outlook Report";
        news_filter_titles[1] = "BOJ Policy Rate";
        news_filter_titles[2] = "Monetary Policy Statement";
        news_filter_titles[3] = "SNB Monetary Policy Assessment";
        news_filter_titles[4] = "SNB Policy Rate";
        return;
       }

    if(StringCompare(sym, "EURAUD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 5);
        news_filter_currencies[0] = "AUD";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "EUR";
        news_filter_titles[0] = "CPI q\\/q";
        news_filter_titles[1] = "CPI y\\/y";
        news_filter_titles[2] = "Cash Rate";
        news_filter_titles[3] = "RBA Rate Statement";
        news_filter_titles[4] = "Trimmed Mean CPI q\\/q";
        return;
       }

    if(StringCompare(sym, "EURCAD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 3);
        news_filter_currencies[0] = "CAD";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "EUR";
        news_filter_titles[0] = "BOC Monetary Policy Report";
        news_filter_titles[1] = "BOC Rate Statement";
        news_filter_titles[2] = "Overnight Rate";
        return;
       }

    if(StringCompare(sym, "EURCHF") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 2);
        news_filter_currencies[0] = "CHF";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "EUR";
        news_filter_titles[0] = "SNB Monetary Policy Assessment";
        news_filter_titles[1] = "SNB Policy Rate";
        return;
       }

    if(StringCompare(sym, "EURGBP") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 1);
        news_filter_currencies[0] = "GBP";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "EUR";
        news_filter_titles[0] = "BOE Inflation Letter";
        return;
       }

    if(StringCompare(sym, "EURJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 2);
        news_filter_currencies[0] = "JPY";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "EUR";
        news_filter_titles[0] = "BOJ Outlook Report";
        news_filter_titles[1] = "BOJ Policy Rate";
        return;
       }

    if(StringCompare(sym, "EURNZD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 6);
        news_filter_currencies[0] = "NZD";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "EUR";
        news_filter_titles[0] = "CPI q\\/q";
        news_filter_titles[1] = "Employment Change q\\/q";
        news_filter_titles[2] = "Official Cash Rate";
        news_filter_titles[3] = "RBNZ Monetary Policy Statement";
        news_filter_titles[4] = "RBNZ Rate Statement";
        news_filter_titles[5] = "Unemployment Rate";
        return;
       }

    if(StringCompare(sym, "EURUSD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 18);
        news_filter_currencies[0] = "EUR";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "EUR";
        news_filter_titles[0] = "Average Hourly Earnings m\\/m";
        news_filter_titles[1] = "CPI m\\/m";
        news_filter_titles[2] = "CPI y\\/y";
        news_filter_titles[3] = "Core CPI m\\/m";
        news_filter_titles[4] = "Core Retail Sales m\\/m";
        news_filter_titles[5] = "Empire State Manufacturing Index";
        news_filter_titles[6] = "Existing Home Sales";
        news_filter_titles[7] = "FOMC Economic Projections";
        news_filter_titles[8] = "French Flash Manufacturing PMI";
        news_filter_titles[9] = "French Flash Services PMI";
        news_filter_titles[10] = "German Flash Manufacturing PMI";
        news_filter_titles[11] = "German Flash Services PMI";
        news_filter_titles[12] = "Industrial Production m\\/m";
        news_filter_titles[13] = "Non-Farm Employment Change";
        news_filter_titles[14] = "Retail Sales m\\/m";
        news_filter_titles[15] = "S&P/CS Composite-20 HPI y\\/y";
        news_filter_titles[16] = "Treasury Currency Report";
        news_filter_titles[17] = "Unemployment Rate";
        return;
       }

    if(StringCompare(sym, "GBPAUD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 13);
        news_filter_currencies[0] = "GBP";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "AUD";
        news_filter_titles[0] = "Asset Purchase Facility";
        news_filter_titles[1] = "BOE Inflation Letter";
        news_filter_titles[2] = "BOE Monetary Policy Report";
        news_filter_titles[3] = "CPI q\\/q";
        news_filter_titles[4] = "Cash Rate";
        news_filter_titles[5] = "Employment Change";
        news_filter_titles[6] = "MPC Asset Purchase Facility Votes";
        news_filter_titles[7] = "MPC Official Bank Rate Votes";
        news_filter_titles[8] = "Monetary Policy Summary";
        news_filter_titles[9] = "Official Bank Rate";
        news_filter_titles[10] = "RBA Rate Statement";
        news_filter_titles[11] = "Trimmed Mean CPI q\\/q";
        news_filter_titles[12] = "Unemployment Rate";
        return;
       }

    if(StringCompare(sym, "GBPCAD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 10);
        news_filter_currencies[0] = "GBP";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "CAD";
        news_filter_titles[0] = "Asset Purchase Facility";
        news_filter_titles[1] = "BOE Inflation Letter";
        news_filter_titles[2] = "BOE Monetary Policy Report";
        news_filter_titles[3] = "BOC Monetary Policy Report";
        news_filter_titles[4] = "BOC Rate Statement";
        news_filter_titles[5] = "MPC Asset Purchase Facility Votes";
        news_filter_titles[6] = "MPC Official Bank Rate Votes";
        news_filter_titles[7] = "Monetary Policy Summary";
        news_filter_titles[8] = "Official Bank Rate";
        news_filter_titles[9] = "Overnight Rate";
        return;
       }

    if(StringCompare(sym, "GBPCHF") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 8);
        news_filter_currencies[0] = "GBP";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "CHF";
        news_filter_titles[0] = "Asset Purchase Facility";
        news_filter_titles[1] = "BOE Inflation Letter";
        news_filter_titles[2] = "BOE Monetary Policy Report";
        news_filter_titles[3] = "MPC Asset Purchase Facility Votes";
        news_filter_titles[4] = "Monetary Policy Summary";
        news_filter_titles[5] = "Official Bank Rate";
        news_filter_titles[6] = "SNB Monetary Policy Assessment";
        news_filter_titles[7] = "SNB Policy Rate";
        return;
       }

    if(StringCompare(sym, "GBPJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 10);
        news_filter_currencies[0] = "GBP";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "JPY";
        news_filter_titles[0] = "Asset Purchase Facility";
        news_filter_titles[1] = "BOE Inflation Letter";
        news_filter_titles[2] = "BOE Monetary Policy Report";
        news_filter_titles[3] = "BOJ Outlook Report";
        news_filter_titles[4] = "BOJ Policy Rate";
        news_filter_titles[5] = "MPC Asset Purchase Facility Votes";
        news_filter_titles[6] = "MPC Official Bank Rate Votes";
        news_filter_titles[7] = "Monetary Policy Statement";
        news_filter_titles[8] = "Monetary Policy Summary";
        news_filter_titles[9] = "Official Bank Rate";
        return;
       }

    if(StringCompare(sym, "GBPNZD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 14);
        news_filter_currencies[0] = "GBP";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "NZD";
        news_filter_titles[0] = "Asset Purchase Facility";
        news_filter_titles[1] = "BOE Inflation Letter";
        news_filter_titles[2] = "BOE Monetary Policy Report";
        news_filter_titles[3] = "CPI q\\/q";
        news_filter_titles[4] = "Current Account";
        news_filter_titles[5] = "Employment Change q\\/q";
        news_filter_titles[6] = "MPC Asset Purchase Facility Votes";
        news_filter_titles[7] = "MPC Official Bank Rate Votes";
        news_filter_titles[8] = "Monetary Policy Summary";
        news_filter_titles[9] = "Official Bank Rate";
        news_filter_titles[10] = "Official Cash Rate";
        news_filter_titles[11] = "PPI Input m\\/m";
        news_filter_titles[12] = "RBNZ Monetary Policy Statement";
        news_filter_titles[13] = "RBNZ Rate Statement";
        return;
       }

    if(StringCompare(sym, "GBPUSD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 12);
        news_filter_currencies[0] = "GBP";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "USD";
        news_filter_titles[0] = "Asset Purchase Facility";
        news_filter_titles[1] = "Average Hourly Earnings m\\/m";
        news_filter_titles[2] = "BOE Inflation Letter";
        news_filter_titles[3] = "BOE Monetary Policy Report";
        news_filter_titles[4] = "CPI m\\/m";
        news_filter_titles[5] = "Core CPI m\\/m";
        news_filter_titles[6] = "FOMC Economic Projections";
        news_filter_titles[7] = "MPC Asset Purchase Facility Votes";
        news_filter_titles[8] = "MPC Official Bank Rate Votes";
        news_filter_titles[9] = "Monetary Policy Summary";
        news_filter_titles[10] = "Non-Farm Employment Change";
        news_filter_titles[11] = "Official Bank Rate";
        return;
       }

    if(StringCompare(sym, "NZDCAD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 3);
        news_filter_currencies[0] = "NZD";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "CAD";
        news_filter_titles[0] = "Official Cash Rate";
        news_filter_titles[1] = "RBNZ Monetary Policy Statement";
        news_filter_titles[2] = "RBNZ Rate Statement";
        return;
       }

    if(StringCompare(sym, "NZDCHF") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 1);
        news_filter_currencies[0] = "NZD";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "CHF";
        news_filter_titles[0] = "RBNZ Monetary Policy Statement";
        return;
       }

    if(StringCompare(sym, "NZDJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 4);
        news_filter_currencies[0] = "NZD";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "JPY";
        news_filter_titles[0] = "BOJ Policy Rate";
        news_filter_titles[1] = "Official Cash Rate";
        news_filter_titles[2] = "RBNZ Monetary Policy Statement";
        news_filter_titles[3] = "RBNZ Rate Statement";
        return;
       }

    if(StringCompare(sym, "NZDUSD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 1);
        news_filter_currencies[0] = "NZD";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "USD";
        news_filter_titles[0] = "RBNZ Monetary Policy Statement";
        return;
       }

    if(StringCompare(sym, "USDCAD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 6);
        news_filter_currencies[0] = "CAD";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "USD";
        news_filter_titles[0] = "BOC Monetary Policy Report";
        news_filter_titles[1] = "BOC Rate Statement";
        news_filter_titles[2] = "CPI y\\/y";
        news_filter_titles[3] = "Core CPI m\\/m";
        news_filter_titles[4] = "FOMC Economic Projections";
        news_filter_titles[5] = "Overnight Rate";
        return;
       }

    if(StringCompare(sym, "USDCHF") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 2);
        news_filter_currencies[0] = "CHF";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "USD";
        news_filter_titles[0] = "SNB Monetary Policy Assessment";
        news_filter_titles[1] = "SNB Policy Rate";
        return;
       }

    if(StringCompare(sym, "USDJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 9);
        news_filter_currencies[0] = "JPY";
        news_filter_currencies[1] = "USD";
        news_filter_currencies[2] = "USD";
        news_filter_titles[0] = "Average Hourly Earnings m\\/m";
        news_filter_titles[1] = "BOJ Policy Rate";
        news_filter_titles[2] = "CPI m\\/m";
        news_filter_titles[3] = "CPI y\\/y";
        news_filter_titles[4] = "Core CPI m\\/m";
        news_filter_titles[5] = "FOMC Economic Projections";
        news_filter_titles[6] = "Monetary Policy Statement";
        news_filter_titles[7] = "Non-Farm Employment Change";
        news_filter_titles[8] = "Unemployment Rate";
        return;
       }


    Alert("No news filter was found for ", sym);
   }
//+------------------------------------------------------------------+
