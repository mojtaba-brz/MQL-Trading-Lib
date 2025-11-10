//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include "../typedefs.mqh"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool parse_news_file(string sym, NewsStruct &_news_list[])
{
    string csv_file_name = broker_symbol_to_standard_symbol(sym) + "-NewsIndicatorFile.csv";
    ResetLastError();
    int csv_file_handle = -1, counter = 0;
    while (csv_file_handle < 0 && counter < 500000) {
        csv_file_handle = FileOpen(csv_file_name, FILE_ANSI | FILE_CSV | FILE_COMMON | FILE_READ, "\n");
        counter++;
    }
    if(csv_file_handle < 0) {
        Print("Could not read " + csv_file_name + ". Error : " + IntegerToString(GetLastError()));
        MessageBox("Could not read " + csv_file_name + ". Error : " + IntegerToString(GetLastError()));
        FileClose(csv_file_handle);
        return(false);
    } else {
        int line_count = 0;
        ArrayFree(_news_list);
        NewsStruct news_struc_temp;
        MqlDateTime time_temp_struct;
        string line_items[];
        while(!FileIsEnding(csv_file_handle)) {
            string line = FileReadString(csv_file_handle);
            if(line_count > 0) {
                StringSplit(line, ',', line_items);

                time_temp_struct.year = (int)StringToInteger(line_items[1]);
                time_temp_struct.mon = (int)StringToInteger(line_items[2]);
                time_temp_struct.day = (int)StringToInteger(line_items[3]);
                time_temp_struct.hour = (int)StringToInteger(line_items[4]);
                time_temp_struct.min = (int)StringToInteger(line_items[5]);
                time_temp_struct.sec = 0;
                news_struc_temp.time = StructToTime(time_temp_struct);

                news_struc_temp.title = line_items[6];
                news_struc_temp.impact = line_items[7];
                if(ArraySize(line_items) > 9) {
                    news_struc_temp.mean_im_profit_pp = StringToDouble(line_items[8]);
                    news_struc_temp.max_spread_pp = StringToDouble(line_items[9]);
                    news_struc_temp.std_im_profit_pp = StringToDouble(line_items[10]);
                }

                ArrayResize(_news_list, ArraySize(_news_list) + 1);
                _news_list[ArraySize(_news_list) - 1] = news_struc_temp;
            } else {
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
int get_time_to_the_nearest_news_list(long current_time, NewsStruct &_news_list[], int &last_news_index)
{
    if(ArraySize(_news_list) == 0) return -1;

    int min_time_to_news = INT_MAX;
    for(int i = last_news_index; i < ArraySize(_news_list); i++) {
        long news_date_temp = (long)_news_list[i].time;
        int diff = (int)(news_date_temp - current_time);
        if(MathAbs(diff) <= MathAbs(min_time_to_news)) {
            min_time_to_news = diff;
        } else {
            last_news_index = i - 1;
            return min_time_to_news;
        }
    }

    return min_time_to_news;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_max_spread_of_the_nearest_news_list(long current_time, NewsStruct &_news_list[], int &last_news_index)
{
    if(ArraySize(_news_list) == 0) return -1;

    int min_time_to_news = INT_MAX;
    for(int i = last_news_index; i < ArraySize(_news_list); i++) {
        long news_date_temp = (long)_news_list[i].time;
        int diff = (int)(news_date_temp - current_time);
        if(MathAbs(diff) <= MathAbs(min_time_to_news)) {
            min_time_to_news = diff;
        } else {
            last_news_index = i - 1;
            return _news_list[last_news_index].max_spread_pp;
        }
    }

    last_news_index = MathMax(0, MathMin(last_news_index, ArraySize(_news_list) - 1));
    return _news_list[last_news_index].max_spread_pp;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_ave_profit_of_the_nearest_news_list(long current_time, NewsStruct &_news_list[], int &last_news_index)
{
    if(ArraySize(_news_list) == 0) return -1;

    int min_time_to_news = INT_MAX;
    for(int i = last_news_index; i < ArraySize(_news_list); i++) {
        long news_date_temp = (long)_news_list[i].time;
        int diff = (int)(news_date_temp - current_time);
        if(MathAbs(diff) <= MathAbs(min_time_to_news)) {
            min_time_to_news = diff;
        } else {
            last_news_index = i - 1;
            return _news_list[last_news_index].mean_im_profit_pp;
        }
    }

    last_news_index = MathMax(0, MathMin(last_news_index, ArraySize(_news_list) - 1));
    return _news_list[last_news_index].mean_im_profit_pp;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string get_nearest_news_list_str_from_news_list(long current_time, NewsStruct &_news_list[], int &last_news_index)
{
    if(ArraySize(_news_list) == 0) return "";

    int min_time_to_news = INT_MAX;
    for(int i = last_news_index; i < ArraySize(_news_list); i++) {
        long news_date_temp = (long)_news_list[i].time;
        int diff = (int)(news_date_temp - current_time);
        if(MathAbs(diff) > MathAbs(min_time_to_news)) {
            last_news_index = i - 1;
            break;
        }
    }

    last_news_index = MathMax(0, MathMin(last_news_index, ArraySize(_news_list) - 1));

    string nearest_news_list = "[";
    int idx = last_news_index;
    datetime news_time = _news_list[idx].time;

    while(idx >= 0 && news_time == _news_list[idx].time) {
        nearest_news_list += "\'" + _news_list[idx].title + "\'" + ";";
        idx--;
    }
    if(StringLen(nearest_news_list) > 80) {
        Print(StringLen(nearest_news_list));
    }
    nearest_news_list = StringSubstr(nearest_news_list, 0, StringLen(nearest_news_list) - 1);
    nearest_news_list += "]";

    return nearest_news_list;
}
//+------------------------------------------------------------------+
