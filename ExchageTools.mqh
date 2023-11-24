//+------------------------------------------------------------------+
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
         SymbolInfoDouble(standard_symbol_to_broker_symbol("AUDUSD"), SYMBOL_ASK, price);
         return price;
         break;

      case 'E':
         SymbolInfoDouble(standard_symbol_to_broker_symbol("EURUSD"), SYMBOL_ASK, price);
         return price;
         break;

      case 'J':
         SymbolInfoDouble(standard_symbol_to_broker_symbol("USDJPY"), SYMBOL_ASK, price);
         return NormalizeDouble(1/price, 5);
         break;

      case 'G':
         SymbolInfoDouble(standard_symbol_to_broker_symbol("GBPUSD"), SYMBOL_ASK, price);
         return price;
         break;

      case 'N':
         SymbolInfoDouble(standard_symbol_to_broker_symbol("NZDUSD"), SYMBOL_ASK, price);
         return price;
         break;

      case 'C':
         if(symbol[4] == 'A')
            SymbolInfoDouble(standard_symbol_to_broker_symbol("USDCAD"), SYMBOL_ASK, price);
         else
            SymbolInfoDouble(standard_symbol_to_broker_symbol("USDCHF"), SYMBOL_ASK, price);
         return NormalizeDouble(1/price, 5);
         break;

      default:
         Alert("warning : symbol was not found in price_of_currency_base_in_dollar function.");
         return 1.;
         break;
     }

  }

string all_supported_symbols[] = {"AUDCAD",
                                  "AUDCHF",
                                  "AUDJPY",
                                  "AUDNZD",
                                  "AUDUSD",
                                  "CADCHF",
                                  "CADJPY",
                                  "CHFJPY",
                                  "EURAUD",
                                  "EURCAD",
                                  "EURCHF",
                                  "EURGBP",
                                  "EURJPY",
                                  "EURNZD",
                                  "EURUSD",
                                  "GBPAUD",
                                  "GBPCAD",
                                  "GBPCHF",
                                  "GBPJPY",
                                  "GBPNZD",
                                  "GBPUSD",
                                  "NZDCAD",
                                  "NZDCHF",
                                  "NZDJPY",
                                  "NZDUSD",
                                  "USDCAD",
                                  "USDCHF",
                                  "USDJPY"
                                 };

string required_symbols[] = { "AUDUSD",
                              "EURUSD",
                              "GBPUSD",
                              "NZDUSD",
                              "USDCAD",
                              "USDCHF",
                              "USDJPY"
                            };

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool is_in_required_symbols(string sym)
  {
   int num_required_symbols = ArraySize(required_symbols);
   for(int i=0; i<num_required_symbols; i++)
     {
      if(StringFind(sym, required_symbols[i]) >= 0)
        {
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool are_all_required_symbols_available()
  {
   int num_required_symbols = ArraySize(required_symbols);
   int num_all_marketwatch_symbols = SymbolsTotal(true);
   int num_required_symbols_in_watchlist = 0;

   for(int i=0; i<num_all_marketwatch_symbols; i++)
     {
      string symbol = SymbolName(i, true);

      if(is_in_required_symbols(symbol))
        {
         num_required_symbols_in_watchlist++;
        }

     }

   if(num_required_symbols_in_watchlist < num_required_symbols)
     {
      Alert("Error :\nMore symbols is needed in Market Watch.\nPlease make sure all of these symbols are there.\n * AUDUSD\n * EURUSD\n * GBPUSD\n * NZDUSD\n * USDCAD\n * USDCHF\n * USDJPY\n\nthere are only " + IntegerToString(num_required_symbols_in_watchlist) + " of them on the Market Watch now.");
      return false;
     }
   return true;
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string standard_symbol_to_broker_symbol(string standard_symbol)
  {

   int num_all_marketwatch_symbols = SymbolsTotal(true);
   for(int i=0; i<num_all_marketwatch_symbols; i++)
     {
      string symbol = SymbolName(i, true);
      if(StringFind(symbol, standard_symbol) >= 0)
        {
         return symbol;
        }
     }
   return NULL;
  }
//+------------------------------------------------------------------+
