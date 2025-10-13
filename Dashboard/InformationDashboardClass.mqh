//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <Controls/Dialog.mqh>
#include <Controls/Defines.mqh> // Types and handlres
#include <Controls/Label.mqh>
#include "../Report/Report.mqh"

#define WIDTH (300)
#define HEIGHT (180)

#define X_OFFSET (30)
#define Y_OFFSET (40)
#define X_INNER_PADDING (8)
#define Y_INNER_PADDNG (6)

#define LABELS_Y_PADDING (22)
#define VALUE_LABELS_X_PADDING ((int) (WIDTH * 0.5))

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CInformationDashboard : public CAppDialog
{
public:
    CInformationDashboard(void) {}
    ~CInformationDashboard(void) {}

// Main Functions ====================================================
    bool init(string name);
    void on_event();

// Utitlity Functions ================================================
    bool create_dashboard();
    bool create_labels();
    bool update_value_labels();
    virtual bool OnEvent(const int id, const long &lparam, const double &dparam, const string &sparam); // Inheritance
    virtual bool Run();

    bool create_label_and_add_it_to_the_dialog(CLabel &label, string name, int pos_idx, bool is_value);
private:
    string _name,
           _label_time_name,
           _label_ac_name_name,
           _label_daily_pl_name,
           _label_daily_drawdown_p_name,
           _label_total_drawdown_p_name;

    CLabel _label_time,
           _label_ac_name,
           _label_daily_pl,
           _label_daily_drawdown_p,
           _label_total_drawdown_p,
           _label_time_value,
           _label_ac_name_value,
           _label_daily_pl_value,
           _label_daily_drawdown_p_value,
           _label_total_drawdown_p_value;
};
//+------------------------------------------------------------------+

// Event Mapping ---------------------
EVENT_MAP_BEGIN(CInformationDashboard)
EVENT_MAP_END(CAppDialog)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CInformationDashboard::init(string name)
{
    m_chart_id = 0;
    m_subwin = 0;

    _name = name;
    _label_time_name = _name + " label Time";
    _label_ac_name_name = _name + " label Account Name";
    _label_daily_pl_name = _name + " label P/L";
    _label_daily_drawdown_p_name = _name + " label Drawdown P";
    _label_total_drawdown_p_name = _name + " label Total Drawdown P";

    if(!create_dashboard()) return false;
    if(!create_labels()) return false;
    if(!update_value_labels()) return false;

    ChartRedraw(0);

    Run();
    return true;

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CInformationDashboard::on_event()
{
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CInformationDashboard::Run()
{
    return CAppDialog::Run();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CInformationDashboard::create_dashboard()
{
    int x1 = X_OFFSET;
    int y1 = Y_OFFSET;
    int x2 = x1 + WIDTH;
    int y2 = y1 + HEIGHT;

    if(!CAppDialog::Create(m_chart_id, _name, m_subwin, x1, y1, x2, y2)) return false;
    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CInformationDashboard::create_labels()
{
    if(!create_label_and_add_it_to_the_dialog(_label_time, _label_time_name, 0, false)) return false;
    if(!create_label_and_add_it_to_the_dialog(_label_ac_name, _label_ac_name_name, 1, false)) return false;
    if(!create_label_and_add_it_to_the_dialog(_label_daily_pl, _label_daily_pl_name, 2, false)) return false;
    if(!create_label_and_add_it_to_the_dialog(_label_daily_drawdown_p, _label_daily_drawdown_p_name, 3, false)) return false;
    if(!create_label_and_add_it_to_the_dialog(_label_total_drawdown_p, _label_total_drawdown_p_name, 4, false)) return false;

    if(!create_label_and_add_it_to_the_dialog(_label_time_value, _label_time_name + " - Value", 0, true)) return false;
    if(!create_label_and_add_it_to_the_dialog(_label_ac_name_value, _label_ac_name_name + " - Value", 1, true)) return false;
    if(!create_label_and_add_it_to_the_dialog(_label_daily_pl_value, _label_daily_pl_name + " - Value", 2, true)) return false;
    if(!create_label_and_add_it_to_the_dialog(_label_daily_drawdown_p_value, _label_daily_drawdown_p_name + " - Value", 3, true)) return false;
    if(!create_label_and_add_it_to_the_dialog(_label_total_drawdown_p_value, _label_total_drawdown_p_name + " - Value", 4, true)) return false;

    if(!_label_time.Text("Time :")) return false;
    if(!_label_ac_name.Text("Account :")) return false;
    if(!_label_daily_pl.Text("Daily P/L :")) return false;
    if(!_label_daily_drawdown_p.Text("Drawdown :")) return false;
    if(!_label_total_drawdown_p.Text("Total Drawdown :")) return false;

    return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CInformationDashboard::update_value_labels()
{
    string time_str = TimeToString(TimeCurrent());
    string acc_name = AccountInfoString(ACCOUNT_NAME);
    double daily_pl = get_earned_daily_profit();
    // double daily_drawdown = get_daily_drawdown();
    // double total_drawdown = get_total_drawdown();

    if(!_label_time_value.Text(time_str)) return false;
    if(!_label_ac_name_value.Text(acc_name)) return false;
    if(!_label_daily_pl_value.Text(StringFormat("%.2f", daily_pl))) return false;
    if(!_label_daily_pl_value.Color(daily_pl > 0 ? clrDarkGreen : daily_pl < 0 ? clrDarkRed : clrBlack)) return false;

       return true;
}

//+------------------------------------------------------------------+
bool CInformationDashboard::create_label_and_add_it_to_the_dialog(CLabel &label, string name, int pos_idx, bool is_value)
{
    int x1 = X_INNER_PADDING + (is_value ? VALUE_LABELS_X_PADDING : 0);
    int y1 = pos_idx * LABELS_Y_PADDING + Y_INNER_PADDNG;
    int x2 = x1 + (WIDTH - 2 * X_INNER_PADDING);
    int y2 = y1 + LABELS_Y_PADDING;

    if(!label.Create(m_chart_id, name, m_subwin, x1, y1, x2, y2)) return false;
    if(!Add(label)) return false;
    if(!label.Text("Initial Text!")) return false;
    if(!label.Visible(true)) return false;
    return true;
}
//+------------------------------------------------------------------+
