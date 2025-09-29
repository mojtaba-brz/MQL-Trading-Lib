//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include "../ArrayFunctions.mqh"
#include "../typedefs.mqh"
#include "../IndicatorUtils.mqh"
#include "../IndicatorReplacemnts/IndicatorReplacemnts.mqh"

#define MAJOR_LEVEL_RESOLUTION_PIPS (10)

struct LevelValidityStruct {
    double level_price;
    int abs_average_swing_diff_pips;
    int num_of_swings;
};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void find_major_and_minor_round_levels_pips(int &major_level_pips, int &minor_level_pips)
{
    LevelValidityStruct found_level_validity_array[], new_validity_level_data;
    double close_price_array[], swing_points[], level;
    int best_major_level_pips, best_minor_level_pips;
    int price_in_pip, below_level_diff_pips, upper_level_diff_pips;
    double levels_loss;
    datetime current_time = TimeCurrent();
    datetime one_month_ago = current_time - 30 * 24 * 3600;
    ArraySetAsSeries(close_price_array, true);
    int copied = CopyClose(_Symbol, PERIOD_M15, one_month_ago, current_time, close_price_array);
    if(copied <= 0) {
        MessageBox("Error: Failed to copy close prices");
        major_level_pips = 100;
        minor_level_pips = 20;
        return;
    }

// Find swing highs and lows (pullback points)
    ArrayResize(swing_points, 0);
    for(int i = 1; i < (ArraySize(close_price_array) - 1); i++) {
        bool is_swing_high = close_price_array[i] > close_price_array[i - 1] && close_price_array[i] > close_price_array[i + 1];
        bool is_swing_low = close_price_array[i] < close_price_array[i - 1] && close_price_array[i] < close_price_array[i + 1];

        if(is_swing_high || is_swing_low) {
            append_element(swing_points, close_price_array[i]);
        }
    }

    if(ArraySize(swing_points) == 0) {
        MessageBox("Warning: No swing points found");
        major_level_pips = 100;
        minor_level_pips = 20;
        return;
    }
      
    double atr_value = get_atr_value(_Symbol, PERIOD_D1, 22, 1);
    int price_to_pip_multiplier = (int)MathRound(MathPow(10, SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) - 1));
    major_level_pips = 50;
    best_major_level_pips = major_level_pips;
    best_minor_level_pips = major_level_pips / 5;
    double best_levels_loss = MAX_DOUBLE_VALUE;
    int max_major_level = (int)MathRound(1.5 * convert_price_to_pips(atr_value));
    max_major_level = max_major_level + (MAJOR_LEVEL_RESOLUTION_PIPS - (max_major_level % MAJOR_LEVEL_RESOLUTION_PIPS));
    int major_level_pips_start_value = MathMax((int)MathRound(0.85 * convert_price_to_pips(atr_value)), 40);
    major_level_pips_start_value -= major_level_pips_start_value % MAJOR_LEVEL_RESOLUTION_PIPS;
    for(major_level_pips = major_level_pips_start_value; major_level_pips <= max_major_level; major_level_pips += MAJOR_LEVEL_RESOLUTION_PIPS) {
        minor_level_pips = major_level_pips / 5;
        for(int i = 0; i < ArraySize(swing_points); i++) {
            price_in_pip = (int)MathRound(swing_points[i] * price_to_pip_multiplier);
            below_level_diff_pips = price_in_pip % minor_level_pips;
            upper_level_diff_pips = minor_level_pips - price_in_pip % minor_level_pips;
            if(below_level_diff_pips < upper_level_diff_pips) {
                level = swing_points[i] - convert_pips_to_price(below_level_diff_pips);
                add_level(found_level_validity_array, level, below_level_diff_pips);
            } else {
                level = swing_points[i] + convert_pips_to_price(upper_level_diff_pips);
                add_level(found_level_validity_array, level, upper_level_diff_pips);
            }
        }

        sort_level_validity_array_based_on_levels_upward(found_level_validity_array);
        levels_loss = calc_level_loss(found_level_validity_array[0]);
        double last_level_price = found_level_validity_array[0].level_price;
        for(int i = 1; i < ArraySize(found_level_validity_array); i++) {
            while(found_level_validity_array[i].level_price > (last_level_price + convert_pips_to_price(minor_level_pips))) {
                last_level_price += convert_pips_to_price(minor_level_pips);
                new_validity_level_data.level_price = last_level_price;
                new_validity_level_data.abs_average_swing_diff_pips = 0;
                new_validity_level_data.num_of_swings = 0;
                levels_loss += calc_level_loss(new_validity_level_data);
            }
            levels_loss += calc_level_loss(found_level_validity_array[i]);
        }

        if(best_levels_loss > levels_loss) {
            best_major_level_pips = major_level_pips;
            best_minor_level_pips = minor_level_pips;
            best_levels_loss = levels_loss;
        }
        // PrintFormat("Major Level: %i,  Loss:%f", major_level_pips, levels_loss);
    }

    major_level_pips = best_major_level_pips;
    minor_level_pips = best_minor_level_pips;

    PrintFormat("Major Level: %ipips,  ATR(D1, 22):%i pips", major_level_pips, convert_price_to_pips(atr_value));
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void calc_current_major_and_minor_levels(int num_of_major_levels_on_one_side, int major_level_pips, int minor_level_pips, double &major_level_price_array[], double &minor_level_price_array[])
{
    ArrayFree(major_level_price_array);
    ArrayFree(minor_level_price_array);
    double current_price = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) * 0.5;
    int current_price_pips = convert_price_to_pips(current_price);

    int the_belowest_line_pips = current_price_pips - current_price_pips % major_level_pips - (num_of_major_levels_on_one_side - 1) * major_level_pips;
    for(int i = 0; i < num_of_major_levels_on_one_side * 2; i++) {
        append_element(major_level_price_array, convert_pips_to_price(the_belowest_line_pips + i * major_level_pips));
    }

    for(int i = 0; i < ArraySize(major_level_price_array) - 1; i++) {
        for(int j = 1; j < 5; j++) {
            append_element(minor_level_price_array, major_level_price_array[i] + j * convert_pips_to_price(minor_level_pips));
        }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int convert_price_to_pips(double price)
{
    int price_to_pip_multiplier = (int)MathRound(MathPow(10, SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) - 1));
    int price_in_pip = (int)MathRound(price * price_to_pip_multiplier);
    return price_in_pip;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double convert_pips_to_price(int pips)
{
    return 10 * _Point * pips;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void add_level(LevelValidityStruct &levels_array[], double level, int diff_pips)
{
    int n = ArraySize(levels_array);
    for(int i = 0; i < n; i++) {
        if(levels_array[i].level_price == level) {
            levels_array[i].num_of_swings++;
            levels_array[i].abs_average_swing_diff_pips += (diff_pips - levels_array[i].abs_average_swing_diff_pips) / levels_array[i].num_of_swings;
            return;
        }
    }

    LevelValidityStruct new_level{level, diff_pips, 1};
    ArrayResize(levels_array, n + 1);
    levels_array[n] = new_level;

}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double calc_level_loss(LevelValidityStruct &level)
{
    return ((-level.num_of_swings) +
            ((level.num_of_swings > 0)  * 1.3 * level.abs_average_swing_diff_pips +
             (level.num_of_swings <= 0) * 3));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void sort_level_validity_array_based_on_levels_upward(LevelValidityStruct &level_validity_array[])
{
    bool not_done = true;
    while(not_done) {
        not_done = false;
        for(int i = 0; i < (ArraySize(level_validity_array) - 1); i++) {
            if(level_validity_array[i].level_price > level_validity_array[i + 1].level_price) {
                swing_element(level_validity_array, i, i + 1);
                not_done = true;
            }
        }
    }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double get_round_level(double price, int level_pips, bool upper_lvl_requied = true)
{
    int price_pips = convert_price_to_pips(price);
    if(upper_lvl_requied) {
        return (convert_pips_to_price(price_pips + level_pips - price_pips % level_pips));
    } else {
        return convert_pips_to_price(price_pips - price_pips % level_pips);
    }
}
//+------------------------------------------------------------------+
