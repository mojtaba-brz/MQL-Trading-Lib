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
    datetime          _last_ffn_request_time;

public:
    ForexFactoryNews  forex_factory_news[], filtered_forex_factory_news[];
                     ForexFactoryNewsHandlerClass()
       {
        _last_ffn_request_time = 0;
       }
                    ~ForexFactoryNewsHandlerClass() {}
    bool              update_news();
    bool              in_news_zone(string currency, NewsImpact impact, double time_margin_left_s, double time_margin_right_s);
    bool              in_filtered_news_zone(int time_margin_left_s, int time_margin_right_s, datetime &news_date, datetime current_time);
    void              print_news(int index);
    void             update_news_filter_with_symbol(string sym, bool alert_if_no_filter_exists = true);
    void             filter_the_news();
   };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ForexFactoryNewsHandlerClass::update_news()
   {
    char data[], server_resp[];
    string header, data_string = "";
    int http_code = 0;
    bool news_are_already_abailable = read_last_news_file_if_it_is_available(server_resp);
    datetime current_server_time = TimeCurrent();

    if(current_server_time > (_last_ffn_request_time + 6 * 60)) // Last time + 6min to avoid request rejections by FF server
       {
        http_code = news_are_already_abailable ?
                    200 :
                    WebRequest("GET", "https://nfs.faireconomy.media/ff_calendar_thisweek.json", NULL, 20, data, server_resp, header);
       }
    else
       {
        PrintFormat("Forex Factory Too Frequent Requests... Remained wating time: %i sec", ((_last_ffn_request_time + 6 * 60) - current_server_time));
        return false;
       }

    _last_ffn_request_time = current_server_time;
    if(http_code < 0)
       {
        Alert("Please add \"https://nfs.faireconomy.media/ff_calendar_thisweek.json\"\nto Tools > Options > Expert Advisors > \nAllow WebRequestes for listed URL and don't forget to enable it.");
        return true; // To avoid repeated alerts
       }
    if(http_code == 200)
       {
        num_of_news = parse_ff_jason_char_array(server_resp, ArraySize(server_resp), forex_factory_news);
        if(num_of_news > 0)
           {
            if(!news_are_already_abailable)
               {
                save_news_json_file(server_resp);
               }

            return true;
           }
        Print("Forex Factory Has Returned No News...");
       }
    return false;
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
    ArrayFree(filtered_forex_factory_news);
    int i = 0;
    for(i = 0; i < ArraySize(forex_factory_news); i++)
       {
        int j = 0;
        for(j = 0; j < ArraySize(news_filter_titles); j++)
           {
            if(StringCompare(forex_factory_news[i].title, news_filter_titles[j]) == 0        &&
               StringCompare(forex_factory_news[i].currency, news_filter_currencies[j]) == 0 &&
               forex_factory_news[i].impact == news_filter_impact[j])
               {
                ArrayResize(filtered_forex_factory_news, ArraySize(filtered_forex_factory_news) + 1);
                filtered_forex_factory_news[ArraySize(filtered_forex_factory_news) - 1] = forex_factory_news[i];
                break;
               }
           }
       }
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ForexFactoryNewsHandlerClass::in_filtered_news_zone(int time_margin_left_s, int time_margin_right_s, datetime &news_date, datetime current_time)
   {
    for(int i = 0; i < ArraySize(filtered_forex_factory_news); i++)
       {
        datetime news_date_temp = filtered_forex_factory_news[i].release_time;
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
    datetime server_offset = TimeGMT() - TimeCurrent();
    ffn.release_time -= server_offset;
    StringSplit(news_parts_2[1], ':', news_parts);
    ffn.release_time += (int)StringToInteger(news_parts[0]) * 3600;
    TimeToStruct(ffn.release_time, ffn.datatime);

    ffn.impact = ffn.impact_str == "Holiday" ? ENUM_NEWS_IMPACT_HOLIDAY :
                 ffn.impact_str == "High"    ? ENUM_NEWS_IMPACT_RED    :
                 ffn.impact_str == "Medium"  ? ENUM_NEWS_IMPACT_MEDIUM : ENUM_NEWS_IMPACT_GREY;

    return ffn;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool read_last_news_file_if_it_is_available(char &server_resp[])
   {
    string last_datime_str = TimeToString(get_last_date_time_of_week()),
           last_day_and_time[];
    StringSplit(last_datime_str, ' ', last_day_and_time);
    string file_name = "downloaded_news_file_" + last_day_and_time[0] + ".txt";
    int file_handle = FileOpen(file_name, FILE_READ | FILE_TXT);
    if(file_handle < 0)
       {
        Print("News was not read from file : " + file_name);
        return false;
       }
    StringToCharArray(FileReadString(file_handle), server_resp);
    FileClose(file_handle);
    return true;
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void save_news_json_file(char &server_resp[])
   {
    string last_datime_str = TimeToString(get_last_date_time_of_week()),
           last_day_and_time[];
    StringSplit(last_datime_str, ' ', last_day_and_time);
    string file_name = "downloaded_news_file_" + last_day_and_time[0] + ".txt";
    int file_handle = FileOpen(file_name, FILE_WRITE | FILE_TXT);
    if(file_handle < 0)
       {
        Print("News was not saved in file : " + file_name);
        return;
       }
    string file_txt = CharArrayToString(server_resp);
    FileWriteString(file_handle, file_txt);
    FileClose(file_handle);
   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime get_last_date_time_of_week()
   {
// Get the current datetime
    datetime current_time = TimeCurrent();
    MqlDateTime time_struct;
    TimeToStruct(current_time, time_struct);

// Calculate the number of days to add to get to the end of the week (Saturday)
    int days_to_add = 6 - time_struct.day_of_week;
    datetime lastDateTimeOfWeek = current_time + days_to_add * 86400; // 86400 seconds in a day

// Set the time to the end of the day (23:59:59)
    TimeToStruct(lastDateTimeOfWeek, time_struct);
    time_struct.hour = 23;
    time_struct.min = 59;
    time_struct.sec = 59;

    lastDateTimeOfWeek = StructToTime(time_struct);

    return lastDateTimeOfWeek;
   }

//+------------------------------------------------------------------+
void ForexFactoryNewsHandlerClass::update_news_filter_with_symbol(string sym, bool alert_if_no_filter_exists)
   {

    ArrayFree(news_filter_currencies);
    ArrayFree(news_filter_titles);
    ArrayFree(news_filter_impact);
    if(StringCompare(sym, "AUDCAD") == 0) {
        ArrayResize(news_filter_currencies, 26);
        ArrayResize(news_filter_titles, 26);
        ArrayResize(news_filter_impact, 26);
        news_filter_titles[0] = "CPI m\\/m";
        news_filter_currencies[0] = "CAD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "Employment Change";
        news_filter_currencies[1] = "CAD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Median CPI y\\/y";
        news_filter_currencies[2] = "CAD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Trimmed CPI y\\/y";
        news_filter_currencies[3] = "CAD";
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
        news_filter_titles[11] = "FOMC Member Waller Speaks";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "FOMC Statement";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Federal Funds Rate";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "ISM Services PMI";
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
        news_filter_titles[18] = "CPI q\\/q";
        news_filter_currencies[18] = "AUD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "CPI y\\/y";
        news_filter_currencies[19] = "AUD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "Cash Rate";
        news_filter_currencies[20] = "AUD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[21] = "Employment Change";
        news_filter_currencies[21] = "AUD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[22] = "RBA Monetary Policy Statement";
        news_filter_currencies[22] = "AUD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[23] = "RBA Rate Statement";
        news_filter_currencies[23] = "AUD";
        news_filter_impact[23] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[24] = "Trimmed Mean CPI q\\/q";
        news_filter_currencies[24] = "AUD";
        news_filter_impact[24] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[25] = "Unemployment Rate";
        news_filter_currencies[25] = "AUD";
        news_filter_impact[25] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "AUDCHF") == 0) {
        ArrayResize(news_filter_currencies, 26);
        ArrayResize(news_filter_titles, 26);
        ArrayResize(news_filter_impact, 26);
        news_filter_titles[0] = "Advance GDP q\\/q";
        news_filter_currencies[0] = "USD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[1] = "USD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CPI m\\/m";
        news_filter_currencies[2] = "USD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "CPI y\\/y";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Core CPI m\\/m";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Core PPI m\\/m";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Core Retail Sales m\\/m";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "FOMC Economic Projections";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "FOMC Member Waller Speaks";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "FOMC Statement";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Federal Funds Rate";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "ISM Services PMI";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "Non-Farm Employment Change";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "PPI m\\/m";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Retail Sales m\\/m";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "CPI q\\/q";
        news_filter_currencies[15] = "AUD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "CPI y\\/y";
        news_filter_currencies[16] = "AUD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "Cash Rate";
        news_filter_currencies[17] = "AUD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "Employment Change";
        news_filter_currencies[18] = "AUD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "RBA Monetary Policy Statement";
        news_filter_currencies[19] = "AUD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "RBA Rate Statement";
        news_filter_currencies[20] = "AUD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[21] = "Trimmed Mean CPI q\\/q";
        news_filter_currencies[21] = "AUD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[22] = "Unemployment Rate";
        news_filter_currencies[22] = "AUD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[23] = "CPI m\\/m";
        news_filter_currencies[23] = "CHF";
        news_filter_impact[23] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[24] = "SNB Monetary Policy Assessment";
        news_filter_currencies[24] = "CHF";
        news_filter_impact[24] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[25] = "SNB Policy Rate";
        news_filter_currencies[25] = "CHF";
        news_filter_impact[25] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "AUDJPY") == 0) {
        ArrayResize(news_filter_currencies, 26);
        ArrayResize(news_filter_titles, 26);
        ArrayResize(news_filter_impact, 26);
        news_filter_titles[0] = "BOJ Outlook Report";
        news_filter_currencies[0] = "JPY";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "BOJ Policy Rate";
        news_filter_currencies[1] = "JPY";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Advance GDP q\\/q";
        news_filter_currencies[2] = "USD";
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
        news_filter_titles[7] = "Core PPI m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Core Retail Sales m\\/m";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "FOMC Economic Projections";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "FOMC Member Waller Speaks";
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
        news_filter_titles[18] = "CPI q\\/q";
        news_filter_currencies[18] = "AUD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "CPI y\\/y";
        news_filter_currencies[19] = "AUD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "Cash Rate";
        news_filter_currencies[20] = "AUD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[21] = "Employment Change";
        news_filter_currencies[21] = "AUD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[22] = "RBA Monetary Policy Statement";
        news_filter_currencies[22] = "AUD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[23] = "RBA Rate Statement";
        news_filter_currencies[23] = "AUD";
        news_filter_impact[23] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[24] = "Trimmed Mean CPI q\\/q";
        news_filter_currencies[24] = "AUD";
        news_filter_impact[24] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[25] = "Unemployment Rate";
        news_filter_currencies[25] = "AUD";
        news_filter_impact[25] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "AUDNZD") == 0) {
        ArrayResize(news_filter_currencies, 15);
        ArrayResize(news_filter_titles, 15);
        ArrayResize(news_filter_impact, 15);
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
        news_filter_titles[6] = "FOMC Economic Projections";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "CPI q\\/q";
        news_filter_currencies[7] = "AUD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "CPI y\\/y";
        news_filter_currencies[8] = "AUD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Cash Rate";
        news_filter_currencies[9] = "AUD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Employment Change";
        news_filter_currencies[10] = "AUD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "RBA Monetary Policy Statement";
        news_filter_currencies[11] = "AUD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "RBA Rate Statement";
        news_filter_currencies[12] = "AUD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Trimmed Mean CPI q\\/q";
        news_filter_currencies[13] = "AUD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Unemployment Rate";
        news_filter_currencies[14] = "AUD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "AUDUSD") == 0) {
        ArrayResize(news_filter_currencies, 29);
        ArrayResize(news_filter_titles, 29);
        ArrayResize(news_filter_impact, 29);
        news_filter_titles[0] = "Advance GDP q\\/q";
        news_filter_currencies[0] = "USD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[1] = "USD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CPI m\\/m";
        news_filter_currencies[2] = "USD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "CPI y\\/y";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Core CPI m\\/m";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Core PCE Price Index m\\/m";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Core PPI m\\/m";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Core Retail Sales m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Empire State Manufacturing Index";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Employment Cost Index q\\/q";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "FOMC Economic Projections";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "FOMC Member Waller Speaks";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "FOMC Statement";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Federal Funds Rate";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "ISM Manufacturing PMI";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "ISM Services PMI";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "JOLTS Job Openings";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "Non-Farm Employment Change";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "PPI m\\/m";
        news_filter_currencies[18] = "USD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "Retail Sales m\\/m";
        news_filter_currencies[19] = "USD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "Unemployment Claims";
        news_filter_currencies[20] = "USD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[21] = "CPI q\\/q";
        news_filter_currencies[21] = "AUD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[22] = "CPI y\\/y";
        news_filter_currencies[22] = "AUD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[23] = "Cash Rate";
        news_filter_currencies[23] = "AUD";
        news_filter_impact[23] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[24] = "Employment Change";
        news_filter_currencies[24] = "AUD";
        news_filter_impact[24] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[25] = "RBA Monetary Policy Statement";
        news_filter_currencies[25] = "AUD";
        news_filter_impact[25] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[26] = "RBA Rate Statement";
        news_filter_currencies[26] = "AUD";
        news_filter_impact[26] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[27] = "Trimmed Mean CPI q\\/q";
        news_filter_currencies[27] = "AUD";
        news_filter_impact[27] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[28] = "Unemployment Rate";
        news_filter_currencies[28] = "AUD";
        news_filter_impact[28] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "CADCHF") == 0) {
        ArrayResize(news_filter_currencies, 19);
        ArrayResize(news_filter_titles, 19);
        ArrayResize(news_filter_impact, 19);
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
        news_filter_titles[6] = "Advance GDP q\\/q";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "CPI m\\/m";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "CPI y\\/y";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Core CPI m\\/m";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "FOMC Economic Projections";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "FOMC Statement";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Federal Funds Rate";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "ISM Services PMI";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "Non-Farm Employment Change";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "CPI m\\/m";
        news_filter_currencies[16] = "CHF";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "SNB Monetary Policy Assessment";
        news_filter_currencies[17] = "CHF";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "SNB Policy Rate";
        news_filter_currencies[18] = "CHF";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "CADJPY") == 0) {
        ArrayResize(news_filter_currencies, 28);
        ArrayResize(news_filter_titles, 28);
        ArrayResize(news_filter_impact, 28);
        news_filter_titles[0] = "BOJ Outlook Report";
        news_filter_currencies[0] = "JPY";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "BOJ Policy Rate";
        news_filter_currencies[1] = "JPY";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "BOC Rate Statement";
        news_filter_currencies[2] = "CAD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "CPI m\\/m";
        news_filter_currencies[3] = "CAD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Employment Change";
        news_filter_currencies[4] = "CAD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Median CPI y\\/y";
        news_filter_currencies[5] = "CAD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Overnight Rate";
        news_filter_currencies[6] = "CAD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Trimmed CPI y\\/y";
        news_filter_currencies[7] = "CAD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Advance GDP q\\/q";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "CPI m\\/m";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "CPI y\\/y";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "Core CPI m\\/m";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Core PCE Price Index m\\/m";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Core PPI m\\/m";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "Core Retail Sales m\\/m";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "FOMC Economic Projections";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "FOMC Member Waller Speaks";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "FOMC Statement";
        news_filter_currencies[18] = "USD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "Federal Funds Rate";
        news_filter_currencies[19] = "USD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "ISM Manufacturing PMI";
        news_filter_currencies[20] = "USD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[21] = "ISM Services PMI";
        news_filter_currencies[21] = "USD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[22] = "JOLTS Job Openings";
        news_filter_currencies[22] = "USD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[23] = "Non-Farm Employment Change";
        news_filter_currencies[23] = "USD";
        news_filter_impact[23] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[24] = "PPI m\\/m";
        news_filter_currencies[24] = "USD";
        news_filter_impact[24] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[25] = "Prelim GDP q\\/q";
        news_filter_currencies[25] = "USD";
        news_filter_impact[25] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[26] = "Retail Sales m\\/m";
        news_filter_currencies[26] = "USD";
        news_filter_impact[26] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[27] = "Unemployment Claims";
        news_filter_currencies[27] = "USD";
        news_filter_impact[27] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "CHFJPY") == 0) {
        ArrayResize(news_filter_currencies, 14);
        ArrayResize(news_filter_titles, 14);
        ArrayResize(news_filter_impact, 14);
        news_filter_titles[0] = "BOJ Outlook Report";
        news_filter_currencies[0] = "JPY";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "BOJ Policy Rate";
        news_filter_currencies[1] = "JPY";
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
        news_filter_titles[6] = "FOMC Economic Projections";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "FOMC Member Waller Speaks";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "FOMC Statement";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Federal Funds Rate";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Non-Farm Employment Change";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "CPI m\\/m";
        news_filter_currencies[11] = "CHF";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "SNB Monetary Policy Assessment";
        news_filter_currencies[12] = "CHF";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "SNB Policy Rate";
        news_filter_currencies[13] = "CHF";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "EURAUD") == 0) {
        ArrayResize(news_filter_currencies, 16);
        ArrayResize(news_filter_titles, 16);
        ArrayResize(news_filter_impact, 16);
        news_filter_titles[0] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[0] = "USD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "CPI m\\/m";
        news_filter_currencies[1] = "USD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CPI y\\/y";
        news_filter_currencies[2] = "USD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Core CPI m\\/m";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "FOMC Economic Projections";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "FOMC Statement";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Federal Funds Rate";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Non-Farm Employment Change";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "CPI q\\/q";
        news_filter_currencies[8] = "AUD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "CPI y\\/y";
        news_filter_currencies[9] = "AUD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Cash Rate";
        news_filter_currencies[10] = "AUD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "Employment Change";
        news_filter_currencies[11] = "AUD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "RBA Monetary Policy Statement";
        news_filter_currencies[12] = "AUD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "RBA Rate Statement";
        news_filter_currencies[13] = "AUD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Trimmed Mean CPI q\\/q";
        news_filter_currencies[14] = "AUD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "Unemployment Rate";
        news_filter_currencies[15] = "AUD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "EURCAD") == 0) {
        ArrayResize(news_filter_currencies, 10);
        ArrayResize(news_filter_titles, 10);
        ArrayResize(news_filter_impact, 10);
        news_filter_titles[0] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[0] = "USD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "CPI m\\/m";
        news_filter_currencies[1] = "USD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CPI y\\/y";
        news_filter_currencies[2] = "USD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Core CPI m\\/m";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "FOMC Economic Projections";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Non-Farm Employment Change";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "CPI m\\/m";
        news_filter_currencies[6] = "CAD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Employment Change";
        news_filter_currencies[7] = "CAD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Median CPI y\\/y";
        news_filter_currencies[8] = "CAD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Trimmed CPI y\\/y";
        news_filter_currencies[9] = "CAD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "EURCHF") == 0) {
        ArrayResize(news_filter_currencies, 10);
        ArrayResize(news_filter_titles, 10);
        ArrayResize(news_filter_impact, 10);
        news_filter_titles[0] = "German Flash Manufacturing PMI";
        news_filter_currencies[0] = "EUR";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "German Flash Services PMI";
        news_filter_currencies[1] = "EUR";
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
        news_filter_titles[7] = "CPI m\\/m";
        news_filter_currencies[7] = "CHF";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "SNB Monetary Policy Assessment";
        news_filter_currencies[8] = "CHF";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "SNB Policy Rate";
        news_filter_currencies[9] = "CHF";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "EURGBP") == 0) {
        ArrayResize(news_filter_currencies, 6);
        ArrayResize(news_filter_titles, 6);
        ArrayResize(news_filter_impact, 6);
        news_filter_titles[0] = "FOMC Economic Projections";
        news_filter_currencies[0] = "USD";
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
        return;
       }

    if(StringCompare(sym, "EURJPY") == 0) {
        ArrayResize(news_filter_currencies, 18);
        ArrayResize(news_filter_titles, 18);
        ArrayResize(news_filter_impact, 18);
        news_filter_titles[0] = "BOJ Outlook Report";
        news_filter_currencies[0] = "JPY";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "BOJ Policy Rate";
        news_filter_currencies[1] = "JPY";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "French Flash Manufacturing PMI";
        news_filter_currencies[2] = "EUR";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "French Flash Services PMI";
        news_filter_currencies[3] = "EUR";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "German Flash Manufacturing PMI";
        news_filter_currencies[4] = "EUR";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "German Flash Services PMI";
        news_filter_currencies[5] = "EUR";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Advance GDP q\\/q";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "CPI m\\/m";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "CPI y\\/y";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Core CPI m\\/m";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "Core Retail Sales m\\/m";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "FOMC Economic Projections";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "FOMC Statement";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Federal Funds Rate";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "ISM Services PMI";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "Non-Farm Employment Change";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "Retail Sales m\\/m";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "EURNZD") == 0) {
        ArrayResize(news_filter_currencies, 11);
        ArrayResize(news_filter_titles, 11);
        ArrayResize(news_filter_impact, 11);
        news_filter_titles[0] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[0] = "USD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "CPI m\\/m";
        news_filter_currencies[1] = "USD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CPI y\\/y";
        news_filter_currencies[2] = "USD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Core CPI m\\/m";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Non-Farm Employment Change";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "CPI q\\/q";
        news_filter_currencies[5] = "NZD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Employment Change q\\/q";
        news_filter_currencies[6] = "NZD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "GDP q\\/q";
        news_filter_currencies[7] = "NZD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Official Cash Rate";
        news_filter_currencies[8] = "NZD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "RBNZ Monetary Policy Statement";
        news_filter_currencies[9] = "NZD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "RBNZ Rate Statement";
        news_filter_currencies[10] = "NZD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "EURUSD") == 0) {
        ArrayResize(news_filter_currencies, 17);
        ArrayResize(news_filter_titles, 17);
        ArrayResize(news_filter_impact, 17);
        news_filter_titles[0] = "German Flash Manufacturing PMI";
        news_filter_currencies[0] = "EUR";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "German Flash Services PMI";
        news_filter_currencies[1] = "EUR";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Advance GDP q\\/q";
        news_filter_currencies[2] = "USD";
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
        news_filter_titles[7] = "Core PPI m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Core Retail Sales m\\/m";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "FOMC Economic Projections";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "FOMC Member Waller Speaks";
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
        news_filter_titles[14] = "Non-Farm Employment Change";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "PPI m\\/m";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "Retail Sales m\\/m";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "GBPAUD") == 0) {
        ArrayResize(news_filter_currencies, 21);
        ArrayResize(news_filter_titles, 21);
        ArrayResize(news_filter_impact, 21);
        news_filter_titles[0] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[0] = "USD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "CPI m\\/m";
        news_filter_currencies[1] = "USD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CPI y\\/y";
        news_filter_currencies[2] = "USD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Core CPI m\\/m";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "FOMC Economic Projections";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "FOMC Statement";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Federal Funds Rate";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Non-Farm Employment Change";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "CPI q\\/q";
        news_filter_currencies[8] = "AUD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "CPI y\\/y";
        news_filter_currencies[9] = "AUD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Cash Rate";
        news_filter_currencies[10] = "AUD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "Employment Change";
        news_filter_currencies[11] = "AUD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "RBA Monetary Policy Statement";
        news_filter_currencies[12] = "AUD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "RBA Rate Statement";
        news_filter_currencies[13] = "AUD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Trimmed Mean CPI q\\/q";
        news_filter_currencies[14] = "AUD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "Unemployment Rate";
        news_filter_currencies[15] = "AUD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "BOE Monetary Policy Report";
        news_filter_currencies[16] = "GBP";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "CPI y\\/y";
        news_filter_currencies[17] = "GBP";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "MPC Official Bank Rate Votes";
        news_filter_currencies[18] = "GBP";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "Monetary Policy Summary";
        news_filter_currencies[19] = "GBP";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "Official Bank Rate";
        news_filter_currencies[20] = "GBP";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "GBPCAD") == 0) {
        ArrayResize(news_filter_currencies, 17);
        ArrayResize(news_filter_titles, 17);
        ArrayResize(news_filter_impact, 17);
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
        news_filter_titles[11] = "Non-Farm Employment Change";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "BOE Monetary Policy Report";
        news_filter_currencies[12] = "GBP";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "CPI y\\/y";
        news_filter_currencies[13] = "GBP";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "MPC Official Bank Rate Votes";
        news_filter_currencies[14] = "GBP";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "Monetary Policy Summary";
        news_filter_currencies[15] = "GBP";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "Official Bank Rate";
        news_filter_currencies[16] = "GBP";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "GBPCHF") == 0) {
        ArrayResize(news_filter_currencies, 13);
        ArrayResize(news_filter_titles, 13);
        ArrayResize(news_filter_impact, 13);
        news_filter_titles[0] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[0] = "USD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "CPI m\\/m";
        news_filter_currencies[1] = "USD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CPI y\\/y";
        news_filter_currencies[2] = "USD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Core CPI m\\/m";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Non-Farm Employment Change";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "CPI m\\/m";
        news_filter_currencies[5] = "CHF";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "SNB Monetary Policy Assessment";
        news_filter_currencies[6] = "CHF";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "SNB Policy Rate";
        news_filter_currencies[7] = "CHF";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "BOE Monetary Policy Report";
        news_filter_currencies[8] = "GBP";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "CPI y\\/y";
        news_filter_currencies[9] = "GBP";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "MPC Official Bank Rate Votes";
        news_filter_currencies[10] = "GBP";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "Monetary Policy Summary";
        news_filter_currencies[11] = "GBP";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "Official Bank Rate";
        news_filter_currencies[12] = "GBP";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "GBPJPY") == 0) {
        ArrayResize(news_filter_currencies, 20);
        ArrayResize(news_filter_titles, 20);
        ArrayResize(news_filter_impact, 20);
        news_filter_titles[0] = "BOJ Outlook Report";
        news_filter_currencies[0] = "JPY";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "BOJ Policy Rate";
        news_filter_currencies[1] = "JPY";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Advance GDP q\\/q";
        news_filter_currencies[2] = "USD";
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
        news_filter_titles[7] = "Core Retail Sales m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "FOMC Economic Projections";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "FOMC Member Waller Speaks";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "FOMC Statement";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "Federal Funds Rate";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "ISM Services PMI";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Non-Farm Employment Change";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Retail Sales m\\/m";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "BOE Monetary Policy Report";
        news_filter_currencies[15] = "GBP";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "CPI y\\/y";
        news_filter_currencies[16] = "GBP";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "MPC Official Bank Rate Votes";
        news_filter_currencies[17] = "GBP";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "Monetary Policy Summary";
        news_filter_currencies[18] = "GBP";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "Official Bank Rate";
        news_filter_currencies[19] = "GBP";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "GBPNZD") == 0) {
        ArrayResize(news_filter_currencies, 19);
        ArrayResize(news_filter_titles, 19);
        ArrayResize(news_filter_impact, 19);
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
        news_filter_titles[14] = "BOE Monetary Policy Report";
        news_filter_currencies[14] = "GBP";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "CPI y\\/y";
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
        return;
       }

    if(StringCompare(sym, "GBPUSD") == 0) {
        ArrayResize(news_filter_currencies, 20);
        ArrayResize(news_filter_titles, 20);
        ArrayResize(news_filter_impact, 20);
        news_filter_titles[0] = "Advance GDP q\\/q";
        news_filter_currencies[0] = "USD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[1] = "USD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CPI m\\/m";
        news_filter_currencies[2] = "USD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "CPI y\\/y";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Core CPI m\\/m";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Core PPI m\\/m";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Core Retail Sales m\\/m";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "FOMC Economic Projections";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "FOMC Member Waller Speaks";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "FOMC Statement";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Federal Funds Rate";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "ISM Services PMI";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "Non-Farm Employment Change";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "PPI m\\/m";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Retail Sales m\\/m";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "BOE Monetary Policy Report";
        news_filter_currencies[15] = "GBP";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "CPI y\\/y";
        news_filter_currencies[16] = "GBP";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "MPC Official Bank Rate Votes";
        news_filter_currencies[17] = "GBP";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "Monetary Policy Summary";
        news_filter_currencies[18] = "GBP";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "Official Bank Rate";
        news_filter_currencies[19] = "GBP";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "NZDCAD") == 0) {
        ArrayResize(news_filter_currencies, 26);
        ArrayResize(news_filter_titles, 26);
        ArrayResize(news_filter_impact, 26);
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
        news_filter_titles[6] = "Advance GDP q\\/q";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "CPI m\\/m";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "CPI y\\/y";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Core CPI m\\/m";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "Core PPI m\\/m";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "Core Retail Sales m\\/m";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "FOMC Economic Projections";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "FOMC Member Waller Speaks";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "FOMC Statement";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "Federal Funds Rate";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "ISM Manufacturing PMI";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "ISM Services PMI";
        news_filter_currencies[18] = "USD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "Non-Farm Employment Change";
        news_filter_currencies[19] = "USD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "PPI m\\/m";
        news_filter_currencies[20] = "USD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[21] = "Retail Sales m\\/m";
        news_filter_currencies[21] = "USD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[22] = "CPI m\\/m";
        news_filter_currencies[22] = "CAD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[23] = "Employment Change";
        news_filter_currencies[23] = "CAD";
        news_filter_impact[23] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[24] = "Median CPI y\\/y";
        news_filter_currencies[24] = "CAD";
        news_filter_impact[24] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[25] = "Trimmed CPI y\\/y";
        news_filter_currencies[25] = "CAD";
        news_filter_impact[25] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "NZDCHF") == 0) {
        ArrayResize(news_filter_currencies, 21);
        ArrayResize(news_filter_titles, 21);
        ArrayResize(news_filter_impact, 21);
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
        news_filter_titles[6] = "Advance GDP q\\/q";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "CPI m\\/m";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "CPI y\\/y";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Core CPI m\\/m";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "Core PPI m\\/m";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "FOMC Economic Projections";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "FOMC Statement";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Federal Funds Rate";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "ISM Services PMI";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "Non-Farm Employment Change";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "PPI m\\/m";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "CPI m\\/m";
        news_filter_currencies[18] = "CHF";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "SNB Monetary Policy Assessment";
        news_filter_currencies[19] = "CHF";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "SNB Policy Rate";
        news_filter_currencies[20] = "CHF";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "NZDJPY") == 0) {
        ArrayResize(news_filter_currencies, 24);
        ArrayResize(news_filter_titles, 24);
        ArrayResize(news_filter_impact, 24);
        news_filter_titles[0] = "BOJ Outlook Report";
        news_filter_currencies[0] = "JPY";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "BOJ Policy Rate";
        news_filter_currencies[1] = "JPY";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CPI q\\/q";
        news_filter_currencies[2] = "NZD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "Employment Change q\\/q";
        news_filter_currencies[3] = "NZD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "GDP q\\/q";
        news_filter_currencies[4] = "NZD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Official Cash Rate";
        news_filter_currencies[5] = "NZD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "RBNZ Monetary Policy Statement";
        news_filter_currencies[6] = "NZD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "RBNZ Rate Statement";
        news_filter_currencies[7] = "NZD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Advance GDP q\\/q";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "CPI m\\/m";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "CPI y\\/y";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "Core CPI m\\/m";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Core PPI m\\/m";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Core Retail Sales m\\/m";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "FOMC Economic Projections";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "FOMC Member Waller Speaks";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "FOMC Statement";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "Federal Funds Rate";
        news_filter_currencies[18] = "USD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "ISM Services PMI";
        news_filter_currencies[19] = "USD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "Non-Farm Employment Change";
        news_filter_currencies[20] = "USD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[21] = "PPI m\\/m";
        news_filter_currencies[21] = "USD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[22] = "Retail Sales m\\/m";
        news_filter_currencies[22] = "USD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[23] = "Unemployment Claims";
        news_filter_currencies[23] = "USD";
        news_filter_impact[23] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "NZDUSD") == 0) {
        ArrayResize(news_filter_currencies, 29);
        ArrayResize(news_filter_titles, 29);
        ArrayResize(news_filter_impact, 29);
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
        news_filter_titles[6] = "Advance GDP q\\/q";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "CPI m\\/m";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "CPI y\\/y";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Core CPI m\\/m";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "Core PCE Price Index m\\/m";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "Core PPI m\\/m";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Core Retail Sales m\\/m";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Empire State Manufacturing Index";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "Employment Cost Index q\\/q";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "FOMC Economic Projections";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "FOMC Member Waller Speaks";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "FOMC Statement";
        news_filter_currencies[18] = "USD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "Federal Funds Rate";
        news_filter_currencies[19] = "USD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "Flash Manufacturing PMI";
        news_filter_currencies[20] = "USD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[21] = "Flash Services PMI";
        news_filter_currencies[21] = "USD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[22] = "ISM Manufacturing PMI";
        news_filter_currencies[22] = "USD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[23] = "ISM Services PMI";
        news_filter_currencies[23] = "USD";
        news_filter_impact[23] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[24] = "JOLTS Job Openings";
        news_filter_currencies[24] = "USD";
        news_filter_impact[24] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[25] = "Non-Farm Employment Change";
        news_filter_currencies[25] = "USD";
        news_filter_impact[25] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[26] = "PPI m\\/m";
        news_filter_currencies[26] = "USD";
        news_filter_impact[26] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[27] = "Retail Sales m\\/m";
        news_filter_currencies[27] = "USD";
        news_filter_impact[27] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[28] = "Unemployment Claims";
        news_filter_currencies[28] = "USD";
        news_filter_impact[28] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "USDCAD") == 0) {
        ArrayResize(news_filter_currencies, 11);
        ArrayResize(news_filter_titles, 11);
        ArrayResize(news_filter_impact, 11);
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
        news_filter_titles[8] = "FOMC Statement";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Federal Funds Rate";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Non-Farm Employment Change";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "USDCHF") == 0) {
        ArrayResize(news_filter_currencies, 21);
        ArrayResize(news_filter_titles, 21);
        ArrayResize(news_filter_impact, 21);
        news_filter_titles[0] = "Advance GDP q\\/q";
        news_filter_currencies[0] = "USD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[1] = "USD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CPI m\\/m";
        news_filter_currencies[2] = "USD";
        news_filter_impact[2] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[3] = "CPI y\\/y";
        news_filter_currencies[3] = "USD";
        news_filter_impact[3] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[4] = "Core CPI m\\/m";
        news_filter_currencies[4] = "USD";
        news_filter_impact[4] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[5] = "Core PPI m\\/m";
        news_filter_currencies[5] = "USD";
        news_filter_impact[5] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[6] = "Core Retail Sales m\\/m";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Employment Cost Index q\\/q";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "FOMC Economic Projections";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "FOMC Member Waller Speaks";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "FOMC Statement";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "Federal Funds Rate";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "ISM Services PMI";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "JOLTS Job Openings";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Non-Farm Employment Change";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "PPI m\\/m";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "Retail Sales m\\/m";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "Unemployment Claims";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "CPI m\\/m";
        news_filter_currencies[18] = "CHF";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "SNB Monetary Policy Assessment";
        news_filter_currencies[19] = "CHF";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "SNB Policy Rate";
        news_filter_currencies[20] = "CHF";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "USDJPY") == 0) {
        ArrayResize(news_filter_currencies, 25);
        ArrayResize(news_filter_titles, 25);
        ArrayResize(news_filter_impact, 25);
        news_filter_titles[0] = "BOJ Outlook Report";
        news_filter_currencies[0] = "JPY";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "BOJ Policy Rate";
        news_filter_currencies[1] = "JPY";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "Advance GDP q\\/q";
        news_filter_currencies[2] = "USD";
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
        news_filter_titles[7] = "Core PCE Price Index m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Core PPI m\\/m";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Core Retail Sales m\\/m";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Empire State Manufacturing Index";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "FOMC Economic Projections";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "FOMC Member Waller Speaks";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "FOMC Statement";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Federal Funds Rate";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "Flash Manufacturing PMI";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "Flash Services PMI";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "ISM Manufacturing PMI";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "ISM Services PMI";
        news_filter_currencies[18] = "USD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "JOLTS Job Openings";
        news_filter_currencies[19] = "USD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "Non-Farm Employment Change";
        news_filter_currencies[20] = "USD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[21] = "PPI m\\/m";
        news_filter_currencies[21] = "USD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[22] = "Prelim GDP q\\/q";
        news_filter_currencies[22] = "USD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[23] = "Retail Sales m\\/m";
        news_filter_currencies[23] = "USD";
        news_filter_impact[23] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[24] = "Unemployment Claims";
        news_filter_currencies[24] = "USD";
        news_filter_impact[24] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(StringCompare(sym, "XAUUSD") == 0) {
        ArrayResize(news_filter_currencies, 23);
        ArrayResize(news_filter_titles, 23);
        ArrayResize(news_filter_impact, 23);
        news_filter_titles[0] = "Advance GDP q\\/q";
        news_filter_currencies[0] = "USD";
        news_filter_impact[0] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[1] = "Average Hourly Earnings m\\/m";
        news_filter_currencies[1] = "USD";
        news_filter_impact[1] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[2] = "CB Consumer Confidence";
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
        news_filter_titles[6] = "Core PCE Price Index m\\/m";
        news_filter_currencies[6] = "USD";
        news_filter_impact[6] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[7] = "Core PPI m\\/m";
        news_filter_currencies[7] = "USD";
        news_filter_impact[7] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[8] = "Core Retail Sales m\\/m";
        news_filter_currencies[8] = "USD";
        news_filter_impact[8] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[9] = "Empire State Manufacturing Index";
        news_filter_currencies[9] = "USD";
        news_filter_impact[9] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[10] = "Employment Cost Index q\\/q";
        news_filter_currencies[10] = "USD";
        news_filter_impact[10] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[11] = "FOMC Economic Projections";
        news_filter_currencies[11] = "USD";
        news_filter_impact[11] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[12] = "FOMC Statement";
        news_filter_currencies[12] = "USD";
        news_filter_impact[12] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[13] = "Federal Funds Rate";
        news_filter_currencies[13] = "USD";
        news_filter_impact[13] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[14] = "Flash Manufacturing PMI";
        news_filter_currencies[14] = "USD";
        news_filter_impact[14] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[15] = "Flash Services PMI";
        news_filter_currencies[15] = "USD";
        news_filter_impact[15] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[16] = "ISM Manufacturing PMI";
        news_filter_currencies[16] = "USD";
        news_filter_impact[16] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[17] = "ISM Services PMI";
        news_filter_currencies[17] = "USD";
        news_filter_impact[17] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[18] = "JOLTS Job Openings";
        news_filter_currencies[18] = "USD";
        news_filter_impact[18] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[19] = "Non-Farm Employment Change";
        news_filter_currencies[19] = "USD";
        news_filter_impact[19] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[20] = "PPI m\\/m";
        news_filter_currencies[20] = "USD";
        news_filter_impact[20] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[21] = "Retail Sales m\\/m";
        news_filter_currencies[21] = "USD";
        news_filter_impact[21] = ENUM_NEWS_IMPACT_RED;
        news_filter_titles[22] = "Unemployment Claims";
        news_filter_currencies[22] = "USD";
        news_filter_impact[22] = ENUM_NEWS_IMPACT_RED;
        return;
       }

    if(alert_if_no_filter_exists)
        Alert("No news filter was found for ", sym);
   }
//+------------------------------------------------------------------+
