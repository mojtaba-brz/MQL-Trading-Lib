//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void create_button(const string btn_name,
                   const string btn_text,
                   const ENUM_BASE_CORNER corner,
                   const int x_distance,
                   const int y_distance,
                   const int x_size,
                   const int y_size,
                   const color background_clr,
                   const color text_clr,
                   const bool selectable = false,
                   const color border_clr = clrNONE,
                   const int font_size = 12,
                   const bool selected = false,
                    const string font_name = "Arial"
                  )
  {
   create_chart_object(btn_name, OBJ_BUTTON);
   set_btn_params(btn_name, btn_text, corner, x_distance, y_distance,
                  x_size, y_size, background_clr, text_clr, selectable,
                  border_clr, font_size, selected, font_name);

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void set_btn_params(const string btn_name,
                    const string btn_text,
                    const ENUM_BASE_CORNER corner,
                    const int x_distance,
                    const int y_distance,
                    const int x_size,
                    const int y_size,
                    const color background_clr,
                    const color text_clr,
                    const bool selectable = false,
                    const color border_clr = clrNONE,
                    const int font_size = 12,
                    const bool selected = false,
                    const string font_name = "Arial")
  {
   ObjectSetInteger(0, btn_name, OBJPROP_CORNER,       corner);
   ObjectSetString(0,  btn_name, OBJPROP_TEXT,         btn_text);
   ObjectSetInteger(0, btn_name, OBJPROP_XDISTANCE,    x_distance);
   ObjectSetInteger(0, btn_name, OBJPROP_YDISTANCE,    y_distance);
   ObjectSetInteger(0, btn_name, OBJPROP_XSIZE,        x_size);
   ObjectSetInteger(0, btn_name, OBJPROP_YSIZE,        y_size);
   ObjectSetInteger(0, btn_name, OBJPROP_BGCOLOR,      background_clr);
   ObjectSetInteger(0, btn_name, OBJPROP_COLOR,        text_clr);
   ObjectSetInteger(0, btn_name, OBJPROP_BORDER_COLOR, border_clr);
   ObjectSetInteger(0, btn_name, OBJPROP_FONTSIZE,     font_size);
   ObjectSetInteger(0, btn_name, OBJPROP_SELECTABLE,   selectable);
   ObjectSetInteger(0, btn_name, OBJPROP_SELECTED,     selected);
   ObjectSetInteger(0, btn_name, OBJPROP_BORDER_TYPE,     BORDER_FLAT);
   ObjectSetString(0, btn_name, OBJPROP_FONT,     font_name);
   ObjectSetInteger(0, btn_name, OBJPROP_BACK, false);
  }
//+------------------------------------------------------------------+

void unclick_btn(string btn_name)
{
   ObjectSetInteger(0, btn_name, OBJPROP_STATE, false);
}