//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#include "SessionsInfo.mqh"
#include "SessionsColor.mqh"
#include "../Drawing/DrawSessions.mqh"

enum SessionsClassModes {
    SESS_CLASS_MODE_CURRENT,
    SESS_CLASS_MODE_ALL_SELECTED
};

struct SessionData {
    int start_hour, end_hour;
    string name;
    color bg_clr, brdr_clr;
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class SessionsClass
{
public:
    SessionsClass(string prefix_objects, SessionsClassModes mode = SESS_CLASS_MODE_CURRENT,
                  bool draw_sydney = false, bool draw_japan = false, bool draw_london = false, bool draw_ny = false);
    ~SessionsClass()
    {
        ObjectsDeleteAll(0, _prefix_objects);
    };
    void set_params(string prefix_objects, SessionsClassModes mode, bool draw_sydney = false, bool draw_japan = false, bool draw_london = false, bool draw_ny = false);
    void on_tick_step();
private:
    // Variables ----------------------------------------------------------------------------
    string _prefix_objects;
    SessionsClassModes _mode;
    SessionData sessions[4];
    bool _draw_sydney, _draw_japan, _draw_london, _draw_ny;

    // Functions ----------------------------------------------------------------------------
    void draw_sessions(int start_hour, int end_hour, color bg_clr, color brdr_clr, string session_name);
    void draw_sydney_sessions();
    void draw_japan_sessions();
    void draw_london_sessions();
    void draw_ny_sessions();
    void draw_all_selected_sessions();
    void draw_current_sessions();
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
SessionsClass::SessionsClass(string prefix_objects, SessionsClassModes mode,
                             bool draw_sydney = false, bool draw_japan = false, bool draw_london = false, bool draw_ny = false)
{
    set_params(prefix_objects, mode, draw_sydney, draw_japan, draw_london, draw_ny);
    ObjectsDeleteAll(0, _prefix_objects); // In case there were any left overs

    sessions[0].start_hour = SYDNEY_SESSION_START_HOUR_FOREX;
    sessions[0].end_hour   = SYDNEY_SESSION_END_HOUR_FOREX;
    sessions[0].name       = "Sydney";
    sessions[0].bg_clr     = SYDNEY_SESSION_BACKGROUND_COLOR;
    sessions[0].brdr_clr   = SYDNEY_SESSION_BORDER_COLOR;

    sessions[1].start_hour = JAPAN_SESSION_START_HOUR_FOREX;
    sessions[1].end_hour   = JAPAN_SESSION_END_HOUR_FOREX;
    sessions[1].name       = "Japan";
    sessions[1].bg_clr     = JAPAN_SESSION_BACKGROUND_COLOR;
    sessions[1].brdr_clr   = JAPAN_SESSION_BORDER_COLOR;

    sessions[2].start_hour = LONDON_SESSION_START_HOUR_FOREX;
    sessions[2].end_hour   = LONDON_SESSION_END_HOUR_FOREX;
    sessions[2].name       = "London";
    sessions[2].bg_clr     = LONDON_SESSION_BACKGROUND_COLOR;
    sessions[2].brdr_clr   = LONDON_SESSION_BORDER_COLOR;

    sessions[3].start_hour = NY_SESSION_START_HOUR_FOREX;
    sessions[3].end_hour   = NY_SESSION_END_HOUR_FOREX;
    sessions[3].name       = "New York";
    sessions[3].bg_clr     = NY_SESSION_BACKGROUND_COLOR;
    sessions[3].brdr_clr   = NY_SESSION_BORDER_COLOR;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SessionsClass::set_params(string prefix_objects, SessionsClassModes mode,
                               bool draw_sydney = false, bool draw_japan = false, bool draw_london = false, bool draw_ny = false)
{
    _prefix_objects = prefix_objects;
    _mode = mode;
    _draw_sydney = draw_sydney;
    _draw_japan = draw_japan;
    _draw_london = draw_london;
    _draw_ny = draw_ny;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SessionsClass::on_tick_step()
{
    if(_mode == SESS_CLASS_MODE_CURRENT) {
        draw_current_sessions();
    } else if(_mode == SESS_CLASS_MODE_ALL_SELECTED) {
        draw_all_selected_sessions();
    }
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SessionsClass::draw_current_sessions()
{
    MqlDateTime current_time_struct;
    TimeCurrent(current_time_struct);
    int current_hour = current_time_struct.hour;
    for(int i = 0; i < 4; i++) {
        bool in_session = (sessions[i].start_hour < sessions[i].end_hour && current_hour >= sessions[i].start_hour && sessions[i].end_hour > current_hour) ||
                          (sessions[i].start_hour > sessions[i].end_hour && (current_hour >= sessions[i].start_hour || sessions[i].end_hour > current_hour));
        if(in_session) {
            draw_session_on_the_current_chart_if_is_new(_prefix_objects, sessions[i].start_hour, sessions[i].end_hour,
                    sessions[i].bg_clr, sessions[i].brdr_clr, sessions[i].name);
        } else {
            clear_session(_prefix_objects, sessions[i].name);
        }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SessionsClass::draw_sydney_sessions()
{
    draw_sessions(SYDNEY_SESSION_START_HOUR_FOREX, SYDNEY_SESSION_END_HOUR_FOREX, SYDNEY_SESSION_BACKGROUND_COLOR, SYDNEY_SESSION_BORDER_COLOR, "Sydney");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SessionsClass::draw_japan_sessions()
{
    draw_sessions(JAPAN_SESSION_START_HOUR_FOREX, JAPAN_SESSION_END_HOUR_FOREX, JAPAN_SESSION_BACKGROUND_COLOR, JAPAN_SESSION_BORDER_COLOR, "Japan");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SessionsClass::draw_london_sessions()
{
    draw_sessions(LONDON_SESSION_START_HOUR_FOREX, LONDON_SESSION_END_HOUR_FOREX, LONDON_SESSION_BACKGROUND_COLOR, LONDON_SESSION_BORDER_COLOR, "London");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SessionsClass::draw_ny_sessions()
{
    draw_sessions(NY_SESSION_START_HOUR_FOREX, NY_SESSION_END_HOUR_FOREX, NY_SESSION_BACKGROUND_COLOR, NY_SESSION_BORDER_COLOR, "New York");
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SessionsClass::draw_all_selected_sessions()
{
    if(_draw_sydney)
        draw_sydney_sessions();
    if(_draw_japan)
        draw_japan_sessions();
    if(_draw_london)
        draw_london_sessions();
    if(_draw_ny)
        draw_ny_sessions();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SessionsClass::draw_sessions(int start_hour, int end_hour, color bg_clr, color brdr_clr, string session_name)
{
    draw_session_on_the_current_chart_if_is_new(_prefix_objects, start_hour, end_hour, bg_clr, brdr_clr, session_name, 0);
    draw_session_on_the_current_chart_if_is_new(_prefix_objects, start_hour, end_hour, bg_clr, brdr_clr, session_name + " ", 24 * 3600);
    draw_session_on_the_current_chart_if_is_new(_prefix_objects, start_hour, end_hour, bg_clr, brdr_clr, session_name + "  ", -24 * 3600);
}
//+------------------------------------------------------------------+
