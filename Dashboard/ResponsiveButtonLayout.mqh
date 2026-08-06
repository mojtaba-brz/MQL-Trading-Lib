//+------------------------------------------------------------------+
//|                                  ResponsiveButtonLayout.mqh      |
//|        Deterministic corner-aware layout for fixed-size controls|
//+------------------------------------------------------------------+
#ifndef MQL_TRADING_LIB_RESPONSIVE_BUTTON_LAYOUT_MQH
#define MQL_TRADING_LIB_RESPONSIVE_BUTTON_LAYOUT_MQH

struct SResponsiveButtonLayout
  {
   int              item_count;
   int              columns;
   int              rows;
   int              item_width;
   int              item_height;
   int              gap_x;
   int              gap_y;
   int              margin_x;
   int              upper_y;
   int              lower_y;
   int              group_height;
   ENUM_BASE_CORNER corner;
  };

//+------------------------------------------------------------------+
//| Configure a row that wraps to the available chart width.         |
//+------------------------------------------------------------------+
bool ConfigureResponsiveButtonLayout(const int item_count,
                                     const int chart_width,
                                     const ENUM_BASE_CORNER corner,
                                     const int margin_x,
                                     const int upper_y,
                                     const int lower_y,
                                     const int item_width,
                                     const int item_height,
                                     const int gap_x,
                                     const int gap_y,
                                     SResponsiveButtonLayout &layout)
  {
   ZeroMemory(layout);
   if(item_count < 1 || item_width < 1 || item_height < 1 ||
      margin_x < 0 || upper_y < 0 || lower_y < 0 || gap_x < 0 || gap_y < 0)
      return(false);

   int columns=item_count;
   if(chart_width > 0)
     {
      int available_width=chart_width-margin_x;
      columns=(available_width+gap_x)/(item_width+gap_x);
      if(columns < 1)
         columns=1;
      if(columns > item_count)
         columns=item_count;
     }

   layout.item_count=item_count;
   layout.columns=columns;
   layout.rows=(item_count+columns-1)/columns;
   layout.item_width=item_width;
   layout.item_height=item_height;
   layout.gap_x=gap_x;
   layout.gap_y=gap_y;
   layout.margin_x=margin_x;
   layout.upper_y=upper_y;
   layout.lower_y=lower_y;
   layout.group_height=layout.rows*item_height+(layout.rows-1)*gap_y;
   layout.corner=corner;
   return(true);
  }

//+------------------------------------------------------------------+
//| Return top-left anchor distances for one fixed-size control.     |
//+------------------------------------------------------------------+
bool ResponsiveButtonPosition(const SResponsiveButtonLayout &layout,
                              const int index,
                              int &x_distance,
                              int &y_distance)
  {
   x_distance=0;
   y_distance=0;
   if(index < 0 || index >= layout.item_count || layout.columns < 1)
      return(false);

   int row=index/layout.columns;
   int column=index%layout.columns;
   int items_in_row=layout.columns;
   int remaining=layout.item_count-row*layout.columns;
   if(remaining < items_in_row)
      items_in_row=remaining;

   int row_width=items_in_row*layout.item_width+(items_in_row-1)*layout.gap_x;
   int logical_x=column*(layout.item_width+layout.gap_x);
   bool right_corner=(layout.corner == CORNER_RIGHT_UPPER ||
                      layout.corner == CORNER_RIGHT_LOWER);
   bool lower_corner=(layout.corner == CORNER_LEFT_LOWER ||
                      layout.corner == CORNER_RIGHT_LOWER);

   // OBJ_BUTTON and other fixed-size controls always use their top-left
   // point as the anchor, even when distances are counted from the right or
   // lower chart corner. Include the row dimensions to keep them in bounds.
   x_distance=right_corner
              ? layout.margin_x+row_width-logical_x
              : layout.margin_x+logical_x;
   y_distance=lower_corner
              ? layout.lower_y+layout.group_height-row*(layout.item_height+layout.gap_y)
              : layout.upper_y+row*(layout.item_height+layout.gap_y);
   return(true);
  }

#endif
