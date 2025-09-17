#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include "SessionsInfo.mqh"
#include "../Drawing/DrawSessions.mqh"

class Sessions
{
public:    
    Sessions();
    ~Sessions() {};
    draw_sydney_sessions();
    draw_japan_sessions();
    draw_london_sessions();
    draw_ny_sessions();
    draw_all_sessions();
private:    
};

void Sessions::draw_london_sessions()
{

}