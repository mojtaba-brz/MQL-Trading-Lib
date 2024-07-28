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
    datetime          release_time;
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
    NewsImpact        news_filter_impact[];

public:
    ForexFactoryNews  forex_factory_news[];
                     ForexFactoryNewsHandlerClass() {update_news();}
                    ~ForexFactoryNewsHandlerClass() {}
    void              update_news();
    bool              in_news_zone(string currency, NewsImpact impact, double time_margin_left_s, double time_margin_right_s);
    bool              in_filtered_news_zone(double time_margin_left_s, double time_margin_right_s, datetime &news_date, datetime current_time);
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
    int http_code = 0;

    while(1)
       {
        http_code = WebRequest("GET", "https://nfs.faireconomy.media/ff_calendar_thisweek.json", NULL, 20, data, server_resp, header);
        if(http_code < 0)
           {
            Alert("Please add \"https://nfs.faireconomy.media/ff_calendar_thisweek.json\"\nto Tools > Options > Expert Advisors > \nAllow WebRequestes for listed URL and don't forget to enable it.");
            return;
           }
        if(http_code != 200)
           {
            Print("Forex Factory Request Retry...");
            Sleep(500);
           }
        else
           {
            num_of_news = parse_ff_jason_char_array(server_resp, ArraySize(server_resp), forex_factory_news);
            if(num_of_news > 0)
               {
                break;
               }
            Print("Forex Factory Has Returned No News...");
            Sleep(500);
           }
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
        int j = 0;
        for(j = 0; j < ArraySize(news_filter_titles); j++)
           {
            if(StringCompare(forex_factory_news[i].title, news_filter_titles[j]) == 0        &&
               StringCompare(forex_factory_news[i].currency, news_filter_currencies[j]) == 0 &&
               forex_factory_news[i].impact == news_filter_impact[j])
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
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ForexFactoryNewsHandlerClass::in_filtered_news_zone(double time_margin_left_s, double time_margin_right_s, datetime &news_date, datetime current_time)
   {
    for(int i = 0; i < ArraySize(forex_factory_news); i++)
       {
        datetime news_date_temp = forex_factory_news[i].release_time;
        if(current_time <= (news_date_temp + time_margin_right_s) && current_time >= (news_date_temp - time_margin_left_s))
           {
            news_date = news_date_temp;
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

    ffn.datatime.hour = (int)StringToInteger(news_parts[0]);
    ffn.datatime.min = (int)StringToInteger(news_parts[1]);
    ffn.datatime.sec = (int)StringToInteger(news_parts[2]);
    ffn.release_time = StructToTime(ffn.datatime);
    datetime server_offset = TimeGMT() - TimeTradeServer();
    ffn.release_time -= server_offset;
    ffn.release_time += 4 * 3600;
    TimeToStruct(ffn.release_time, ffn.datatime);

    ffn.impact = ffn.impact_str == "Holiday" ? ENUM_NEWS_IMPACT_HOLIDAY :
                 ffn.impact_str == "High"    ? ENUM_NEWS_IMPACT_RED    :
                 ffn.impact_str == "Medium"  ? ENUM_NEWS_IMPACT_MEDIUM : ENUM_NEWS_IMPACT_GREY;

    return ffn;
   }

//+------------------------------------------------------------------+
void ForexFactoryNewsHandlerClass::update_news_filter_with_symbol(string sym)
   {
    if(StringCompare(sym, "EURUSD") == 0)
       {
        ArrayResize(news_filter_currencies, 33);
        ArrayResize(news_filter_titles, 33);
        ArrayResize(news_filter_impact, 33);
        news_filter_titles[0] = "Common CPI y\\/y";
        news_filter_currencies[0] = "CAD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[1] = "CPI m\\/m";
        news_filter_currencies[1] = "CAD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Median CPI y\\/y";
        news_filter_currencies[2] = "CAD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Trimmed CPI y\\/y";
        news_filter_currencies[3] = "CAD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "CPI y\\/y";
        news_filter_currencies[4] = "AUD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "SNB Monetary Policy Assessment";
        news_filter_currencies[5] = "CHF";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "SNB Policy Rate";
        news_filter_currencies[6] = "CHF";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Flash Manufacturing PMI";
        news_filter_currencies[7] = "EUR";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[8] = "Flash Services PMI";
        news_filter_currencies[8] = "EUR";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[9] = "French Flash Manufacturing PMI";
        news_filter_currencies[9] = "EUR";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "French Flash Services PMI";
        news_filter_currencies[10] = "EUR";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "German Flash Manufacturing PMI";
        news_filter_currencies[11] = "EUR";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "German Flash Services PMI";
        news_filter_currencies[12] = "EUR";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Flash Manufacturing PMI";
        news_filter_currencies[13] = "GBP";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Flash Services PMI";
        news_filter_currencies[14] = "GBP";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "Existing Home Sales";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[16] = "Industrial Production m\\/m";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[17] = "S&P\\/CS Composite-20 HPI y";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[18] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[18] = "USD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "CPI m\\/m";
        news_filter_currencies[19] = "USD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "CPI y\\/y";
        news_filter_currencies[20] = "USD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[21] = "Core CPI m\\/m";
        news_filter_currencies[21] = "USD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[22] = "Core Retail Sales m\\/m";
        news_filter_currencies[22] = "USD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[23] = "Empire State Manufacturing Index";
        news_filter_currencies[23] = "USD";
        news_filter_impact[23] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[24] = "FOMC Economic Projections";
        news_filter_currencies[24] = "USD";
        news_filter_impact[24] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[25] = "FOMC Statement";
        news_filter_currencies[25] = "USD";
        news_filter_impact[25] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[26] = "Federal Funds Rate";
        news_filter_currencies[26] = "USD";
        news_filter_impact[26] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[27] = "Flash Manufacturing PMI";
        news_filter_currencies[27] = "USD";
        news_filter_impact[27] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[28] = "Flash Services PMI";
        news_filter_currencies[28] = "USD";
        news_filter_impact[28] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[29] = "New Home Sales";
        news_filter_currencies[29] = "USD";
        news_filter_impact[29] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[30] = "Non-Farm Employment Change";
        news_filter_currencies[30] = "USD";
        news_filter_impact[30] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[31] = "Retail Sales m\\/m";
        news_filter_currencies[31] = "USD";
        news_filter_impact[31] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[32] = "Treasury Currency Report";
        news_filter_currencies[32] = "USD";
        news_filter_impact[32] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "GBPAUD") == 0)
       {
        ArrayResize(news_filter_currencies, 21);
        ArrayResize(news_filter_titles, 21);
        ArrayResize(news_filter_impact, 21);
        news_filter_titles[0] = "Employment Change";
        news_filter_currencies[0] = "AUD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[1] = "GDP q\\/q";
        news_filter_currencies[1] = "AUD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[2] = "CPI q\\/q";
        news_filter_currencies[2] = "AUD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "CPI y\\/y";
        news_filter_currencies[3] = "AUD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Cash Rate";
        news_filter_currencies[4] = "AUD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Employment Change";
        news_filter_currencies[5] = "AUD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "RBA Monetary Policy Statement";
        news_filter_currencies[6] = "AUD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "RBA Rate Statement";
        news_filter_currencies[7] = "AUD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Trimmed Mean CPI q\\/q";
        news_filter_currencies[8] = "AUD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Unemployment Rate";
        news_filter_currencies[9] = "AUD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "BOE Monetary Policy Report";
        news_filter_currencies[10] = "GBP";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "CPI y\\/y";
        news_filter_currencies[11] = "GBP";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "MPC Official Bank Rate Votes";
        news_filter_currencies[12] = "GBP";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Monetary Policy Summary";
        news_filter_currencies[13] = "GBP";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Official Bank Rate";
        news_filter_currencies[14] = "GBP";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "CPI m\\/m";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "CPI y\\/y";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "Core CPI m\\/m";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "FOMC Economic Projections";
        news_filter_currencies[18] = "USD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "FOMC Statement";
        news_filter_currencies[19] = "USD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "Federal Funds Rate";
        news_filter_currencies[20] = "USD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "NZDJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 6);
        ArrayResize(news_filter_titles, 6);
        ArrayResize(news_filter_impact, 6);
        news_filter_titles[0] = "Official Cash Rate";
        news_filter_currencies[0] = "NZD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "RBNZ Monetary Policy Statement";
        news_filter_currencies[1] = "NZD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "RBNZ Rate Statement";
        news_filter_currencies[2] = "NZD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "BOJ Policy Rate";
        news_filter_currencies[3] = "JPY";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[4] = "BOJ Outlook Report";
        news_filter_currencies[4] = "JPY";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Monetary Policy Statement";
        news_filter_currencies[5] = "JPY";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "AUDUSD") == 0)
       {
        ArrayResize(news_filter_currencies, 34);
        ArrayResize(news_filter_titles, 34);
        ArrayResize(news_filter_impact, 34);
        news_filter_titles[0] = "Common CPI y\\/y";
        news_filter_currencies[0] = "CAD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[1] = "CPI m\\/m";
        news_filter_currencies[1] = "CAD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Median CPI y\\/y";
        news_filter_currencies[2] = "CAD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Trimmed CPI y\\/y";
        news_filter_currencies[3] = "CAD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "CPI y\\/y";
        news_filter_currencies[4] = "AUD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "RBA Monetary Policy Statement";
        news_filter_currencies[5] = "AUD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "GDP q\\/q";
        news_filter_currencies[6] = "NZD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Flash Manufacturing PMI";
        news_filter_currencies[7] = "EUR";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[8] = "Flash Services PMI";
        news_filter_currencies[8] = "EUR";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[9] = "German ifo Business Climate";
        news_filter_currencies[9] = "EUR";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[10] = "French Flash Manufacturing PMI";
        news_filter_currencies[10] = "EUR";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "French Flash Services PMI";
        news_filter_currencies[11] = "EUR";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "German Flash Manufacturing PMI";
        news_filter_currencies[12] = "EUR";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "German Flash Services PMI";
        news_filter_currencies[13] = "EUR";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Flash Manufacturing PMI";
        news_filter_currencies[14] = "GBP";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "Flash Services PMI";
        news_filter_currencies[15] = "GBP";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "MPC Official Bank Rate Votes";
        news_filter_currencies[16] = "GBP";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "Monetary Policy Summary";
        news_filter_currencies[17] = "GBP";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "Official Bank Rate";
        news_filter_currencies[18] = "GBP";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "Building Permits";
        news_filter_currencies[19] = "USD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[20] = "Existing Home Sales";
        news_filter_currencies[20] = "USD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[21] = "Philly Fed Manufacturing Index";
        news_filter_currencies[21] = "USD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[22] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[22] = "USD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[23] = "CPI m\\/m";
        news_filter_currencies[23] = "USD";
        news_filter_impact[23] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[24] = "CPI y\\/y";
        news_filter_currencies[24] = "USD";
        news_filter_impact[24] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[25] = "Core CPI m\\/m";
        news_filter_currencies[25] = "USD";
        news_filter_impact[25] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[26] = "FOMC Economic Projections";
        news_filter_currencies[26] = "USD";
        news_filter_impact[26] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[27] = "FOMC Statement";
        news_filter_currencies[27] = "USD";
        news_filter_impact[27] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[28] = "Federal Funds Rate";
        news_filter_currencies[28] = "USD";
        news_filter_impact[28] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[29] = "Flash Manufacturing PMI";
        news_filter_currencies[29] = "USD";
        news_filter_impact[29] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[30] = "Flash Services PMI";
        news_filter_currencies[30] = "USD";
        news_filter_impact[30] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[31] = "New Home Sales";
        news_filter_currencies[31] = "USD";
        news_filter_impact[31] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[32] = "Non-Farm Employment Change";
        news_filter_currencies[32] = "USD";
        news_filter_impact[32] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[33] = "Treasury Currency Report";
        news_filter_currencies[33] = "USD";
        news_filter_impact[33] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "GBPCHF") == 0)
       {
        ArrayResize(news_filter_currencies, 6);
        ArrayResize(news_filter_titles, 6);
        ArrayResize(news_filter_impact, 6);
        news_filter_titles[0] = "SNB Monetary Policy Assessment";
        news_filter_currencies[0] = "CHF";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "SNB Policy Rate";
        news_filter_currencies[1] = "CHF";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "BOE Monetary Policy Report";
        news_filter_currencies[2] = "GBP";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "MPC Official Bank Rate Votes";
        news_filter_currencies[3] = "GBP";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Monetary Policy Summary";
        news_filter_currencies[4] = "GBP";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Official Bank Rate";
        news_filter_currencies[5] = "GBP";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "EURCHF") == 0)
       {
        ArrayResize(news_filter_currencies, 2);
        ArrayResize(news_filter_titles, 2);
        ArrayResize(news_filter_impact, 2);
        news_filter_titles[0] = "SNB Monetary Policy Assessment";
        news_filter_currencies[0] = "CHF";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "SNB Policy Rate";
        news_filter_currencies[1] = "CHF";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "CHFJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 8);
        ArrayResize(news_filter_titles, 8);
        ArrayResize(news_filter_impact, 8);
        news_filter_titles[0] = "BOJ Policy Rate";
        news_filter_currencies[0] = "JPY";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[1] = "BOJ Outlook Report";
        news_filter_currencies[1] = "JPY";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "BOJ Policy Rate";
        news_filter_currencies[2] = "JPY";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Monetary Policy Statement";
        news_filter_currencies[3] = "JPY";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "SNB Monetary Policy Assessment";
        news_filter_currencies[4] = "CHF";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "SNB Policy Rate";
        news_filter_currencies[5] = "CHF";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "German Flash Manufacturing PMI";
        news_filter_currencies[6] = "EUR";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "German Flash Services PMI";
        news_filter_currencies[7] = "EUR";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "AUDCAD") == 0)
       {
        ArrayResize(news_filter_currencies, 3);
        ArrayResize(news_filter_titles, 3);
        ArrayResize(news_filter_impact, 3);
        news_filter_titles[0] = "Cash Rate";
        news_filter_currencies[0] = "AUD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "RBA Monetary Policy Statement";
        news_filter_currencies[1] = "AUD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "RBA Rate Statement";
        news_filter_currencies[2] = "AUD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "AUDNZD") == 0)
       {
        ArrayResize(news_filter_currencies, 6);
        ArrayResize(news_filter_titles, 6);
        ArrayResize(news_filter_impact, 6);
        news_filter_titles[0] = "Employment Change";
        news_filter_currencies[0] = "AUD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[1] = "GDP q\\/q";
        news_filter_currencies[1] = "AUD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[2] = "RBA Monetary Policy Statement";
        news_filter_currencies[2] = "AUD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Official Cash Rate";
        news_filter_currencies[3] = "NZD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "RBNZ Monetary Policy Statement";
        news_filter_currencies[4] = "NZD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "RBNZ Rate Statement";
        news_filter_currencies[5] = "NZD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "USDCHF") == 0)
       {
        ArrayResize(news_filter_currencies, 7);
        ArrayResize(news_filter_titles, 7);
        ArrayResize(news_filter_impact, 7);
        news_filter_titles[0] = "SNB Monetary Policy Assessment";
        news_filter_currencies[0] = "CHF";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "SNB Policy Rate";
        news_filter_currencies[1] = "CHF";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[2] = "USD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "CPI m\\/m";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "CPI y\\/y";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Core CPI m\\/m";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Non-Farm Employment Change";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "GBPJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 13);
        ArrayResize(news_filter_titles, 13);
        ArrayResize(news_filter_impact, 13);
        news_filter_titles[0] = "BOJ Policy Rate";
        news_filter_currencies[0] = "JPY";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[1] = "BOJ Outlook Report";
        news_filter_currencies[1] = "JPY";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "BOJ Policy Rate";
        news_filter_currencies[2] = "JPY";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Monetary Policy Statement";
        news_filter_currencies[3] = "JPY";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "BOE Monetary Policy Report";
        news_filter_currencies[4] = "GBP";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "CPI y\\/y";
        news_filter_currencies[5] = "GBP";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Flash Manufacturing PMI";
        news_filter_currencies[6] = "GBP";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Flash Services PMI";
        news_filter_currencies[7] = "GBP";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "MPC Official Bank Rate Votes";
        news_filter_currencies[8] = "GBP";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Monetary Policy Summary";
        news_filter_currencies[9] = "GBP";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Official Bank Rate";
        news_filter_currencies[10] = "GBP";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "Non-Farm Employment Change";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "GBPNZD") == 0)
       {
        ArrayResize(news_filter_currencies, 18);
        ArrayResize(news_filter_titles, 18);
        ArrayResize(news_filter_impact, 18);
        news_filter_titles[0] = "CPI q\\/q";
        news_filter_currencies[0] = "NZD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "Employment Change q\\/q";
        news_filter_currencies[1] = "NZD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "GDP q\\/q";
        news_filter_currencies[2] = "NZD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Official Cash Rate";
        news_filter_currencies[3] = "NZD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "RBNZ Monetary Policy Statement";
        news_filter_currencies[4] = "NZD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "RBNZ Rate Statement";
        news_filter_currencies[5] = "NZD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "BOE Monetary Policy Report";
        news_filter_currencies[6] = "GBP";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "CPI y\\/y";
        news_filter_currencies[7] = "GBP";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "MPC Official Bank Rate Votes";
        news_filter_currencies[8] = "GBP";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Monetary Policy Summary";
        news_filter_currencies[9] = "GBP";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Official Bank Rate";
        news_filter_currencies[10] = "GBP";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "CPI m\\/m";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "CPI y\\/y";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Core CPI m\\/m";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "FOMC Economic Projections";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "FOMC Member Waller Speaks";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "FOMC Statement";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "Federal Funds Rate";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "NZDCAD") == 0)
       {
        ArrayResize(news_filter_currencies, 6);
        ArrayResize(news_filter_titles, 6);
        ArrayResize(news_filter_impact, 6);
        news_filter_titles[0] = "Official Cash Rate";
        news_filter_currencies[0] = "NZD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "RBNZ Monetary Policy Statement";
        news_filter_currencies[1] = "NZD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "RBNZ Rate Statement";
        news_filter_currencies[2] = "NZD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "CPI m\\/m";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "CPI y\\/y";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Core CPI m\\/m";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "EURNZD") == 0)
       {
        ArrayResize(news_filter_currencies, 11);
        ArrayResize(news_filter_titles, 11);
        ArrayResize(news_filter_impact, 11);
        news_filter_titles[0] = "CPI q\\/q";
        news_filter_currencies[0] = "NZD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "Employment Change q\\/q";
        news_filter_currencies[1] = "NZD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Official Cash Rate";
        news_filter_currencies[2] = "NZD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "RBNZ Monetary Policy Statement";
        news_filter_currencies[3] = "NZD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "RBNZ Rate Statement";
        news_filter_currencies[4] = "NZD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "CPI m\\/m";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "CPI y\\/y";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Core CPI m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "FOMC Economic Projections";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "FOMC Statement";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Federal Funds Rate";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "GBPUSD") == 0)
       {
        ArrayResize(news_filter_currencies, 14);
        ArrayResize(news_filter_titles, 14);
        ArrayResize(news_filter_impact, 14);
        news_filter_titles[0] = "Employment Change";
        news_filter_currencies[0] = "CAD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "BOE Monetary Policy Report";
        news_filter_currencies[1] = "GBP";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CPI y\\/y";
        news_filter_currencies[2] = "GBP";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "MPC Official Bank Rate Votes";
        news_filter_currencies[3] = "GBP";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Monetary Policy Summary";
        news_filter_currencies[4] = "GBP";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Official Bank Rate";
        news_filter_currencies[5] = "GBP";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "CPI m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "CPI y\\/y";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Core CPI m\\/m";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "FOMC Economic Projections";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "FOMC Statement";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "Federal Funds Rate";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Non-Farm Employment Change";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "EURAUD") == 0)
       {
        ArrayResize(news_filter_currencies, 12);
        ArrayResize(news_filter_titles, 12);
        ArrayResize(news_filter_impact, 12);
        news_filter_titles[0] = "Employment Change";
        news_filter_currencies[0] = "AUD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[1] = "CPI q\\/q";
        news_filter_currencies[1] = "AUD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CPI y\\/y";
        news_filter_currencies[2] = "AUD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Cash Rate";
        news_filter_currencies[3] = "AUD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Employment Change";
        news_filter_currencies[4] = "AUD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "RBA Monetary Policy Statement";
        news_filter_currencies[5] = "AUD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "RBA Rate Statement";
        news_filter_currencies[6] = "AUD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Trimmed Mean CPI q\\/q";
        news_filter_currencies[7] = "AUD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Unemployment Rate";
        news_filter_currencies[8] = "AUD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "CPI m\\/m";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "CPI y\\/y";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "Core CPI m\\/m";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "NZDUSD") == 0)
       {
        ArrayResize(news_filter_currencies, 8);
        ArrayResize(news_filter_titles, 8);
        ArrayResize(news_filter_impact, 8);
        news_filter_titles[0] = "Official Cash Rate";
        news_filter_currencies[0] = "NZD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "RBNZ Monetary Policy Statement";
        news_filter_currencies[1] = "NZD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "RBNZ Rate Statement";
        news_filter_currencies[2] = "NZD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "CPI m\\/m";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "CPI y\\/y";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Core CPI m\\/m";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Non-Farm Employment Change";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "AUDCHF") == 0)
       {
        ArrayResize(news_filter_currencies, 2);
        ArrayResize(news_filter_titles, 2);
        ArrayResize(news_filter_impact, 2);
        news_filter_titles[0] = "SNB Monetary Policy Assessment";
        news_filter_currencies[0] = "CHF";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "SNB Policy Rate";
        news_filter_currencies[1] = "CHF";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "AUDJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 8);
        ArrayResize(news_filter_titles, 8);
        ArrayResize(news_filter_impact, 8);
        news_filter_titles[0] = "CPI q\\/q";
        news_filter_currencies[0] = "AUD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "Cash Rate";
        news_filter_currencies[1] = "AUD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "RBA Monetary Policy Statement";
        news_filter_currencies[2] = "AUD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "RBA Rate Statement";
        news_filter_currencies[3] = "AUD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Trimmed Mean CPI q\\/q";
        news_filter_currencies[4] = "AUD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "BOJ Policy Rate";
        news_filter_currencies[5] = "JPY";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[6] = "BOJ Outlook Report";
        news_filter_currencies[6] = "JPY";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Monetary Policy Statement";
        news_filter_currencies[7] = "JPY";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "EURJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 5);
        ArrayResize(news_filter_titles, 5);
        ArrayResize(news_filter_impact, 5);
        news_filter_titles[0] = "BOJ Policy Rate";
        news_filter_currencies[0] = "JPY";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[1] = "BOJ Outlook Report";
        news_filter_currencies[1] = "JPY";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Monetary Policy Statement";
        news_filter_currencies[2] = "JPY";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "German Flash Manufacturing PMI";
        news_filter_currencies[3] = "EUR";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "German Flash Services PMI";
        news_filter_currencies[4] = "EUR";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "CADJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 5);
        ArrayResize(news_filter_titles, 5);
        ArrayResize(news_filter_impact, 5);
        news_filter_titles[0] = "BOJ Policy Rate";
        news_filter_currencies[0] = "JPY";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[1] = "BOJ Outlook Report";
        news_filter_currencies[1] = "JPY";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Monetary Policy Statement";
        news_filter_currencies[2] = "JPY";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Non-Farm Employment Change";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "NZDCHF") == 0)
       {
        ArrayResize(news_filter_currencies, 5);
        ArrayResize(news_filter_titles, 5);
        ArrayResize(news_filter_impact, 5);
        news_filter_titles[0] = "Official Cash Rate";
        news_filter_currencies[0] = "NZD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "RBNZ Monetary Policy Statement";
        news_filter_currencies[1] = "NZD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "RBNZ Rate Statement";
        news_filter_currencies[2] = "NZD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "SNB Monetary Policy Assessment";
        news_filter_currencies[3] = "CHF";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "SNB Policy Rate";
        news_filter_currencies[4] = "CHF";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "USDJPY") == 0)
       {
        ArrayResize(news_filter_currencies, 18);
        ArrayResize(news_filter_titles, 18);
        ArrayResize(news_filter_impact, 18);
        news_filter_titles[0] = "Employment Change";
        news_filter_currencies[0] = "CAD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "BOJ Policy Rate";
        news_filter_currencies[1] = "JPY";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[2] = "BOJ Outlook Report";
        news_filter_currencies[2] = "JPY";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Monetary Policy Statement";
        news_filter_currencies[3] = "JPY";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "CPI m\\/m";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "CPI y\\/y";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Core CPI m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Core PPI m\\/m";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Core Retail Sales m\\/m";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "FOMC Economic Projections";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "FOMC Statement";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "Federal Funds Rate";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "ISM Services PMI";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "JOLTS Job Openings";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "Non-Farm Employment Change";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "PPI m\\/m";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "Retail Sales m\\/m";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "USDCAD") == 0)
       {
        ArrayResize(news_filter_currencies, 9);
        ArrayResize(news_filter_titles, 9);
        ArrayResize(news_filter_impact, 9);
        news_filter_titles[0] = "BOC Rate Statement";
        news_filter_currencies[0] = "CAD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "Employment Change";
        news_filter_currencies[1] = "CAD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Overnight Rate";
        news_filter_currencies[2] = "CAD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "CPI m\\/m";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "CPI y\\/y";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Core CPI m\\/m";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "FOMC Economic Projections";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Non-Farm Employment Change";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "GBPCAD") == 0)
       {
        ArrayResize(news_filter_currencies, 13);
        ArrayResize(news_filter_titles, 13);
        ArrayResize(news_filter_impact, 13);
        news_filter_titles[0] = "BOC Rate Statement";
        news_filter_currencies[0] = "CAD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "CPI m\\/m";
        news_filter_currencies[1] = "CAD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Employment Change";
        news_filter_currencies[2] = "CAD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Median CPI y\\/y";
        news_filter_currencies[3] = "CAD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Overnight Rate";
        news_filter_currencies[4] = "CAD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Trimmed CPI y\\/y";
        news_filter_currencies[5] = "CAD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "BOE Monetary Policy Report";
        news_filter_currencies[6] = "GBP";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "CPI y\\/y";
        news_filter_currencies[7] = "GBP";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "MPC Official Bank Rate Votes";
        news_filter_currencies[8] = "GBP";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Monetary Policy Summary";
        news_filter_currencies[9] = "GBP";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Official Bank Rate";
        news_filter_currencies[10] = "GBP";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "Non-Farm Employment Change";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "XAUUSD") == 0)
       {
        ArrayResize(news_filter_currencies, 33);
        ArrayResize(news_filter_titles, 33);
        ArrayResize(news_filter_impact, 33);
        news_filter_titles[0] = "BOC Monetary Policy Report";
        news_filter_currencies[0] = "CAD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "Employment Change";
        news_filter_currencies[1] = "CAD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "GDP m\\/m";
        news_filter_currencies[2] = "CAD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Annual Budget Release";
        news_filter_currencies[3] = "GBP";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Advance GDP Price Index q\\/q";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[5] = "Final GDP Price Index q\\/q";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[6] = "ISM Manufacturing Prices";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[7] = "Prelim GDP Price Index q\\/q";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_MEDIUM;
        news_filter_titles[8] = "ADP Non-Farm Employment Change";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Advance GDP q\\/q";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "CPI m\\/m";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "CPI y\\/y";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Core CPI m\\/m";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Core PPI m\\/m";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "Core Retail Sales m\\/m";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "Empire State Manufacturing Index";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "Employment Cost Index q\\/q";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "FOMC Economic Projections";
        news_filter_currencies[18] = "USD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "FOMC Statement";
        news_filter_currencies[19] = "USD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "Federal Funds Rate";
        news_filter_currencies[20] = "USD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[21] = "Final GDP q\\/q";
        news_filter_currencies[21] = "USD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[22] = "Flash Manufacturing PMI";
        news_filter_currencies[22] = "USD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[23] = "Flash Services PMI";
        news_filter_currencies[23] = "USD";
        news_filter_impact[23] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[24] = "ISM Manufacturing PMI";
        news_filter_currencies[24] = "USD";
        news_filter_impact[24] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[25] = "ISM Services PMI";
        news_filter_currencies[25] = "USD";
        news_filter_impact[25] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[26] = "JOLTS Job Openings";
        news_filter_currencies[26] = "USD";
        news_filter_impact[26] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[27] = "New Home Sales";
        news_filter_currencies[27] = "USD";
        news_filter_impact[27] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[28] = "Non-Farm Employment Change";
        news_filter_currencies[28] = "USD";
        news_filter_impact[28] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[29] = "PPI m\\/m";
        news_filter_currencies[29] = "USD";
        news_filter_impact[29] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[30] = "Prelim GDP q\\/q";
        news_filter_currencies[30] = "USD";
        news_filter_impact[30] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[31] = "Retail Sales m\\/m";
        news_filter_currencies[31] = "USD";
        news_filter_impact[31] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[32] = "Unemployment Claims";
        news_filter_currencies[32] = "USD";
        news_filter_impact[32] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "CADCHF") == 0)
       {
        ArrayResize(news_filter_currencies, 2);
        ArrayResize(news_filter_titles, 2);
        ArrayResize(news_filter_impact, 2);
        news_filter_titles[0] = "SNB Monetary Policy Assessment";
        news_filter_currencies[0] = "CHF";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "SNB Policy Rate";
        news_filter_currencies[1] = "CHF";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    Alert("No news filter was found for ", sym);
   }
//+------------------------------------------------------------------+
