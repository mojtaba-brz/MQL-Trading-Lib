//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2018, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include "ObjectLib.mqh"


#define MAX_GRID_DASHBOARD_COLUMNS                    (15)
#define GRID_DASHBOEARD_DEFAULT_COL_X_DISTANCE        (20)
#define GRID_DASHBOEARD_DEFAULT_ROW_Y_DISTANCE        (20)
#define GRID_DASHBOEARD_DEFAULT_FONT_SIZE             (12)
#define GRID_DASHBOEARD_DEFAULT_FONT_NAME             "Arial"

struct GridDashboardCell
  {
   string            name;
   string            text;
   int               x_distance;
   int               y_distance;
   int               x_size;
   int               y_size;
   color             background_clr;
   color             text_clr;
   bool              selectable;
   color             border_clr;
   int               font_size;
   bool              selected;
   ENUM_BASE_CORNER  corner;
   string            font_name;

  };

struct GridDashboardColumn
  {
   int               x_distance;
   int               x_size;
  };

struct GridDashboardRow
  {
   int               y_distance;
   int               y_size;
  };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class GridDashboardClass
  {
private:
   int                  _n_rows, _n_cols, _x_offset, _y_offset, _font_size, _total_x_size, _total_y_size,
                        _headers_font_size;
   ENUM_BASE_CORNER     _corner;
   GridDashboardCell    _cells[][MAX_GRID_DASHBOARD_COLUMNS];
   GridDashboardColumn  _cols[];
   GridDashboardRow     _rows[];
   string               _font_name, _rec_name;
public:
                     GridDashboardClass();

                    ~GridDashboardClass(void);

   void              init_dashboard(int &row_y_sizes[], int &col_x_sizes[], ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER,
                                    int x_offset = GRID_DASHBOEARD_DEFAULT_COL_X_DISTANCE,
                                    int y_offset = GRID_DASHBOEARD_DEFAULT_ROW_Y_DISTANCE,
                                    int font_size = GRID_DASHBOEARD_DEFAULT_FONT_SIZE,
                                    int headers_font_size = GRID_DASHBOEARD_DEFAULT_FONT_SIZE,
                                    string font_name = GRID_DASHBOEARD_DEFAULT_FONT_NAME);

   void              delete_all_dasboard_objs();
   void              initialze_the_cells();
   void              create_cells_on_the_chart();
   int               get_row_y_distance(int row_index);
   int               get_col_x_distance(int col_index);
   void              initialize_rows_and_cols();
   void              set_text_and_bgcolor(string text, color bgcolor, int row_idx, int col_idx);
   void              update_cell(int row_idx, int col_idx);
   void              create_background_rectangle();

  };


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
GridDashboardClass::GridDashboardClass()
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GridDashboardClass::init_dashboard(int &row_y_sizes[], int &col_x_sizes[], ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER,
                                        int x_offset = GRID_DASHBOEARD_DEFAULT_COL_X_DISTANCE,
                                        int y_offset = GRID_DASHBOEARD_DEFAULT_ROW_Y_DISTANCE,
                                        int font_size = GRID_DASHBOEARD_DEFAULT_FONT_SIZE,
                                        int headers_font_size = GRID_DASHBOEARD_DEFAULT_FONT_SIZE,
                                        string font_name = GRID_DASHBOEARD_DEFAULT_FONT_NAME)
  {
   _n_rows = ArraySize(row_y_sizes);

   _n_cols = MathMin(ArraySize(col_x_sizes), MAX_GRID_DASHBOARD_COLUMNS);
   if(_n_cols > MAX_GRID_DASHBOARD_COLUMNS)
     {
      Alert("Increase MAX_GRID_DASHBOARD_COLUMNS");
     }

   _corner = corner;

   _x_offset = x_offset;
   _y_offset = y_offset;
   _font_name = font_name;
   
   _font_size = font_size;
   _headers_font_size = headers_font_size;
   _rec_name = "Grid_Backgroung";

   ArrayResize(_cells, _n_rows);
   ArrayResize(_rows, _n_rows);
   ArrayResize(_cols, _n_cols);

   _total_x_size = 0;
   _total_y_size = 0;
   int i;
   for(i=0; i<_n_cols; i++)
     {
      _cols[i].x_size = col_x_sizes[i];
      _total_x_size += col_x_sizes[i];
     }
   for(i=0; i<_n_rows; i++)
     {
      _rows[i].y_size = row_y_sizes[i];
      _total_y_size += row_y_sizes[i];
     }

   initialze_the_cells();
   delete_all_dasboard_objs();

   create_background_rectangle();
   create_cells_on_the_chart();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
GridDashboardClass::~GridDashboardClass()
  {
   delete_all_dasboard_objs();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GridDashboardClass::delete_all_dasboard_objs()
  {
   for(int i=0; i<_n_rows; i++)
     {
      for(int j=0; j<_n_cols; j++)
        {
         ObjectDelete(0, _cells[i][j].name);
        }
     }
   ObjectDelete(0, _rec_name);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GridDashboardClass::initialze_the_cells()
  {
   initialize_rows_and_cols();
   for(int i=0; i<_n_rows; i++)
     {
      for(int j=0; j<_n_cols; j++)
        {
         _cells[i][j].name           = StringFormat("Cell_%i_%i", i+1, j+1);
         _cells[i][j].text           = StringFormat("", i+1, j+1);
         _cells[i][j].background_clr = clrGray;
         _cells[i][j].border_clr     = clrGray;
         _cells[i][j].font_size      = i == 0? _headers_font_size:_font_size;
         _cells[i][j].selectable     = false;
         _cells[i][j].selected       = false;
         _cells[i][j].text_clr       = clrWhite;
         _cells[i][j].x_size         = _cols[j].x_size;
         _cells[i][j].y_size         = _rows[i].y_size;
         _cells[i][j].x_distance     = _cols[j].x_distance;
         _cells[i][j].y_distance     = _rows[i].y_distance;
         _cells[i][j].corner         = _corner;
         _cells[i][j].font_name      = _font_name;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GridDashboardClass::create_cells_on_the_chart()
  {
   for(int i=0; i<_n_rows; i++)
     {
      for(int j=0; j<_n_cols; j++)
        {
         create_button(_cells[i][j].name,
                       _cells[i][j].text,
                       _cells[i][j].corner,
                       _cells[i][j].x_distance,
                       _cells[i][j].y_distance,
                       _cells[i][j].x_size,
                       _cells[i][j].y_size,
                       _cells[i][j].background_clr,
                       _cells[i][j].text_clr,
                       _cells[i][j].selectable,
                       _cells[i][j].border_clr,
                       _cells[i][j].font_size,
                       _cells[i][j].selected,
                       _cells[i][j].font_name);
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GridDashboardClass::get_row_y_distance(int row_index)
  {
   int upper_required_distance = _y_offset;
   int i;
   if(_corner == CORNER_RIGHT_UPPER || _corner == CORNER_LEFT_UPPER)
     {
      for(i=0; i<row_index; i++)
        {
         upper_required_distance += _rows[i].y_size;
        }
     }
   else
     {
      for(i=_n_rows - 1; i>=row_index; i--)
        {
         upper_required_distance += _rows[i].y_size;
        }
     }

   return upper_required_distance;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GridDashboardClass::get_col_x_distance(int col_index)
  {
   int left_required_distance = _x_offset;
   int i;

   if(_corner == CORNER_LEFT_LOWER || _corner == CORNER_LEFT_UPPER)
     {
      for(i=0; i<col_index; i++)
        {
         left_required_distance += _cols[i].x_size;
        }
     }
   else
     {
      for(i=_n_cols - 1; i>=col_index; i--)
        {
         left_required_distance += _cols[i].x_size;
        }
     }

   return left_required_distance;

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GridDashboardClass::initialize_rows_and_cols()
  {
   int i;
// Columns -----------------------------------------------------------------
   if(_corner == CORNER_LEFT_LOWER || _corner == CORNER_LEFT_UPPER)
     {
      for(i=0; i<_n_cols; i++)
        {
         _cols[i].x_distance = get_col_x_distance(i);
        }
     }
   else
     {
      for(i=_n_cols - 1; i>=0; i--)
        {
         _cols[i].x_distance = get_col_x_distance(i);
        }
     }

// Rows -------------------------------------------------------------------
   if(_corner == CORNER_RIGHT_UPPER || _corner == CORNER_LEFT_UPPER)
     {
      for(i=0; i<_n_rows; i++)
        {
         _rows[i].y_distance = get_row_y_distance(i);
        }
     }
   else
     {
      for(i=_n_rows - 1; i>=0; i--)
        {
         _rows[i].y_distance = get_row_y_distance(i);
        }
     }
  }
//+------------------------------------------------------------------+
void GridDashboardClass::set_text_and_bgcolor(string text, color bgcolor, int row_idx, int col_idx)
  {
   _cells[row_idx][col_idx].text = text;
   _cells[row_idx][col_idx].background_clr = bgcolor;
   update_cell(row_idx, col_idx);

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GridDashboardClass::update_cell(int row_idx, int col_idx)
  {
   set_btn_params(_cells[row_idx][col_idx].name,
                  _cells[row_idx][col_idx].text,
                  _cells[row_idx][col_idx].corner,
                  _cells[row_idx][col_idx].x_distance,
                  _cells[row_idx][col_idx].y_distance,
                  _cells[row_idx][col_idx].x_size,
                  _cells[row_idx][col_idx].y_size,
                  _cells[row_idx][col_idx].background_clr,
                  _cells[row_idx][col_idx].text_clr,
                  _cells[row_idx][col_idx].selectable,
                  _cells[row_idx][col_idx].border_clr,
                  _cells[row_idx][col_idx].font_size,
                  _cells[row_idx][col_idx].selected,
                  _cells[row_idx][col_idx].font_name);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void GridDashboardClass::create_background_rectangle()
  {
   int x_offset = _x_offset, y_offset = _y_offset;
// Columns -----------------------------------------------------------------
   if(_corner == CORNER_RIGHT_UPPER || _corner == CORNER_RIGHT_LOWER)
     {
      _x_offset += _total_x_size;
     }

// Rows -------------------------------------------------------------------
   if(_corner == CORNER_RIGHT_LOWER || _corner == CORNER_LEFT_LOWER)
     {
      _y_offset += _total_y_size;
     }

   create_button(_rec_name, "", _corner, _x_offset, _y_offset, _total_x_size, _total_y_size,
                 _cells[0][0].background_clr, _cells[0][0].text_clr, _cells[0][0].selectable,
                 _cells[0][0].border_clr, _cells[0][0].font_size, _cells[0][0].selected);
  }
//+------------------------------------------------------------------+
