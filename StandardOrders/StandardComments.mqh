//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include "TypeDefs.mqh"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string create_standard_commnet(string pre_fix = "", string group_name = "", int group_index = -1, string desc = "")
{
    return StringFormat("%s,%s,%i,%s", pre_fix, group_name, group_index, desc);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void standard_comment_to_order_order_specs(string order_comment, OrderSTDSpecs &order_std_specs)
{
    string comment_parts[];
    StringSplit(order_comment, ',', comment_parts);
    if(ArraySize(comment_parts) != 4) return;

    order_std_specs.comment  = order_comment;
    order_std_specs.pre_fix  = comment_parts[0];
    order_std_specs.group    = comment_parts[1];
    order_std_specs.group_id_str = comment_parts[2];
    order_std_specs.desc     = comment_parts[3];
    order_std_specs.group_id = (int)StringToInteger(comment_parts[2]);
}
//+------------------------------------------------------------------+
