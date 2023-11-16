//|                                                                  |
//+------------------------------------------------------------------+
double currency_base_in_dollar(string symbol = NULL)
  {
   if(symbol == NULL)
     {
      symbol = Symbol();
     }
   double price;
   switch(symbol[3])
     {
      case  'U':
         return 1.;
         break;

      case 'A':
         SymbolInfoDouble("AUDUSD", SYMBOL_ASK, price);
         return price;
         break;

      case 'E':
         SymbolInfoDouble("EURUSD", SYMBOL_ASK, price);
         return price;
         break;

      case 'J':
         SymbolInfoDouble("USDJPY", SYMBOL_ASK, price);
         return NormalizeDouble(1/price, 5);
         break;

      case 'G':
         SymbolInfoDouble("GBPUSD", SYMBOL_ASK, price);
         return price;
         break;

      case 'N':
         SymbolInfoDouble("NZDUSD", SYMBOL_ASK, price);
         return price;
         break;

      case 'C':
         if(symbol[4] == 'A')
            SymbolInfoDouble("USDCAD", SYMBOL_ASK, price);
         else
            SymbolInfoDouble("USDCHF", SYMBOL_ASK, price);
         return NormalizeDouble(1/price, 5);
         break;

      default:
         Print("warning : symbol not found in price_of_currency_base_in_dollar function");
         return 1.;
         break;
     }

  }