#include "ForexFactoryNews.mqh"
#include "OfflineNewsUtils.mqh"

void highlight_news_on_the_chart(string pre_fix, ForexFactoryNews &news, datetime &_pre_obj_time, int &_news_index, double price = 0.)
   {
    if(_pre_obj_time == news.release_time) {
        string object_name = pre_fix + IntegerToString(_news_index) + " - ";
        ObjectCreate(0, object_name + "_label", OBJ_TEXT, 0, news.release_time, price);
        ObjectSetString(0, object_name + "_label", OBJPROP_TEXT, ".");
        return;        
    }

    string object_name = pre_fix + IntegerToString(_news_index) + " - ";
    ObjectCreate(0, object_name, OBJ_VLINE, 0, news.release_time, price);
    ObjectSetInteger(0, object_name, OBJPROP_BACK, true);
    ObjectSetInteger(0, object_name, OBJPROP_STYLE, STYLE_DASH);

    ObjectCreate(0, object_name + "_label", OBJ_TEXT, 0, news.release_time, price);
    ObjectSetString(0, object_name + "_label", OBJPROP_TEXT, news.currency + " - " + news.title);
    ObjectSetInteger(0, object_name + "_label", OBJPROP_COLOR, clrWheat);
    ObjectSetInteger(0, object_name + "_label", OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetDouble(0, object_name + "_label", OBJPROP_ANGLE, 90);

    _news_index++;
    _pre_obj_time = news.release_time;
   }