//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void draw_major_and_minor_round_number_level_line_if_is_new(string prefix, int major_level_pips, int minor_level_pips, int num_of_major_levels_on_one_side = 3)
{
    double major_level_price_array[], minor_level_price_array[];
    calc_current_major_and_minor_levels(num_of_major_levels_on_one_side, major_level_pips, minor_level_pips, major_level_price_array, minor_level_price_array);
    for(int i = 0; i < ArraySize(major_level_price_array); i++) {
        string h_line_prefix = prefix + "_" + IntegerToString(i);
        draw_major_level(h_line_prefix, major_level_price_array[i]);
    }
    for(int i = 0; i < ArraySize(major_level_price_array)-1; i++) {
        string h_line_prefix = prefix + "_" + IntegerToString(i);
        draw_mid_level(h_line_prefix, (major_level_price_array[i]+major_level_price_array[i+1])*0.5);
    }
    for(int i = 0; i < ArraySize(minor_level_price_array); i++) {
        string h_line_prefix = prefix + "_" + IntegerToString(i);
        draw_minor_level(h_line_prefix, minor_level_price_array[i]);
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
void draw_major_level(string prefix, double level_price)
{
    string name = prefix + "major_h_line";
    if(ObjectFind(0, name) < 0) {
        if(ObjectGetDouble(0, name, OBJPROP_PRICE) == level_price) {
            return;
        } else {
            ObjectDelete(0, name);
        }
    }
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, level_price);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
    ObjectSetInteger(0, name, OBJPROP_BACK, 1);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrOliveDrab);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void draw_mid_level(string prefix, double level_price)
{
    string name = prefix + "mid_h_line";
    if(ObjectFind(0, name) < 0) {
        if(ObjectGetDouble(0, name, OBJPROP_PRICE) == level_price) {
            return;
        } else {
            ObjectDelete(0, name);
        }
    }
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, level_price);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASHDOTDOT);
    ObjectSetInteger(0, name, OBJPROP_BACK, 1);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrDarkRed);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void draw_minor_level(string prefix, double level_price)
{
    string name = prefix + "minor_h_line";
    if(ObjectFind(0, name) < 0) {
        if(ObjectGetDouble(0, name, OBJPROP_PRICE) == level_price) {
            return;
        } else {
            ObjectDelete(0, name);
        }
    }
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, level_price);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, name, OBJPROP_BACK, 1);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrOlive);
}