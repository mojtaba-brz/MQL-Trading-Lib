//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+

enum NewsImpact
  {
   ENUM_NEWS_IMPACT_GREY,
   ENUM_NEWS_IMPACT_YELLOW,
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
   ForexFactoryNews  forex_factory_news[];
   int               num_of_news;

public:
                     ForexFactoryNewsHandlerClass() {update_news();}
                    ~ForexFactoryNewsHandlerClass() {}
   void              update_news();
   bool              in_news_zone(string currency, NewsImpact impact, double time_margin_left_s, double time_margin_right_s);
   void              print_news(int index);
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
   for(int i=0; i<num_of_news; i++)
     {
      if(forex_factory_news[i].currency == currency && forex_factory_news[i].impact == impact)
        {
         datetime current_time = TimeCurrent();
         datetime news_time = StructToTime(forex_factory_news[i].datatime);
         if(news_time <= (current_time + time_margin_right_s) && news_time >= (current_time - time_margin_left_s))
           {
            // print_news(i);
            return true;
           }
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
   for(int i=0; i<len; i++)
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
            forex_factory_news[num_of_news-1] = parse_single_ff_news_string(CharArrayToString(server_resp, start_index+1, end_index-1));
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
   ffn.datatime.hour = (int)StringToInteger(news_parts[0])+4;
   ffn.datatime.min = (int)StringToInteger(news_parts[1]);
   ffn.datatime.sec = (int)StringToInteger(news_parts[2]);

   ffn.impact = ffn.impact_str == "Holiday" ? ENUM_NEWS_IMPACT_HOLIDAY:
                ffn.impact_str == "High"    ? ENUM_NEWS_IMPACT_RED    :
                ffn.impact_str == "Medium"  ? ENUM_NEWS_IMPACT_YELLOW :ENUM_NEWS_IMPACT_GREY;

   return ffn;
  }
//+------------------------------------------------------------------+
