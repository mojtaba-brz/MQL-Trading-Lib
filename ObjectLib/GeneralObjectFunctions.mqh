//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool create_chart_object(string obj_name, ENUM_OBJECT obj_type)
  {
   if(!ObjectCreate(0, obj_name, obj_type, 0, 0, 0))
     {
      Alert(__FUNCTION__, " Failed to create ", obj_name, ". Error code : ", GetLastError());
      return false;
     }
   return true;

  }