//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double currency_base_in_dollar(string symbol = NULL, datetime time = 0)
  {
   if(symbol == NULL)
     {
      symbol = Symbol();
     }
   double price;
   MqlRates rates[];

   switch(symbol[3])
     {
      case  'U':
         return 1.;
         break;

      case 'A':
         if(time == 0)
            SymbolInfoDouble(standard_symbol_to_broker_symbol("AUDUSD"), SYMBOL_BID, price);
         else
           {
            CopyRates(standard_symbol_to_broker_symbol("AUDUSD"), PERIOD_M1, time, 1, rates);
            price = rates[0].close;
           }
         return price;
         break;

      case 'E':
         if(time == 0)
            SymbolInfoDouble(standard_symbol_to_broker_symbol("EURUSD"), SYMBOL_BID, price);
         else
           {
            CopyRates(standard_symbol_to_broker_symbol("EURUSD"), PERIOD_M1, time, 1, rates);
            price = rates[0].close;
           }
         return price;
         break;

      case 'J':
         if(time == 0)
            SymbolInfoDouble(standard_symbol_to_broker_symbol("USDJPY"), SYMBOL_BID, price);
         else
           {
            CopyRates(standard_symbol_to_broker_symbol("USDJPY"), PERIOD_M1, time, 1, rates);
            price = rates[0].close;
           }
         return NormalizeDouble(1/price, 5);
         break;

      case 'G':
         if(time == 0)
            SymbolInfoDouble(standard_symbol_to_broker_symbol("GBPUSD"), SYMBOL_BID, price);
         else
           {
            CopyRates(standard_symbol_to_broker_symbol("GBPUSD"), PERIOD_M1, time, 1, rates);
            price = rates[0].close;
           }
         return price;
         break;

      case 'N':
         if(time == 0)
            SymbolInfoDouble(standard_symbol_to_broker_symbol("NZDUSD"), SYMBOL_BID, price);
         else
           {
            CopyRates(standard_symbol_to_broker_symbol("NZDUSD"), PERIOD_M1, time, 1, rates);
            price = rates[0].close;
           }
         return price;
         break;

      case 'C':
         if(symbol[4] == 'A')
           {
            if(time == 0)
               SymbolInfoDouble(standard_symbol_to_broker_symbol("USDCAD"), SYMBOL_BID, price);
            else
              {
               CopyRates(standard_symbol_to_broker_symbol("USDCAD"), PERIOD_M1, time, 1, rates);
               price = rates[0].close;
              }
           }
         else
           {
            if(time == 0)
               SymbolInfoDouble(standard_symbol_to_broker_symbol("USDCHF"), SYMBOL_BID, price);
            else
              {
               CopyRates(standard_symbol_to_broker_symbol("USDCHF"), PERIOD_M1, time, 1, rates);
               price = rates[0].close;
              }
           }
         return NormalizeDouble(1/price, 5);
         break;

      default:
         Alert("warning : symbol was not found in price_of_currency_base_in_dollar function.\nCheck the MarketWatch, all 28 main pairs should be in the MarketWatch.");
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
                                  "USDJPY",
                                  "XAUUSD"
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
double get_currency_base_in_balance_currency(string symbol = NULL, datetime time = 0)
  {
   string balance_currency = AccountInfoString(ACCOUNT_CURRENCY);
   char bc_char[];
   double price;
   MqlRates rates[];

   switch(balance_currency[0])
     {
      case 'U':
         return currency_base_in_dollar(symbol, time);
         break;

      case 'A':
         if(time == 0)
            SymbolInfoDouble(standard_symbol_to_broker_symbol("AUDUSD"), SYMBOL_BID, price);
         else
           {
            CopyRates(standard_symbol_to_broker_symbol("AUDUSD"), PERIOD_M1, time, 1, rates);
            price = rates[0].close;
           }
         price = currency_base_in_dollar(symbol, time)/price;
         return price;
         break;

      case 'E':
         if(time == 0)
            SymbolInfoDouble(standard_symbol_to_broker_symbol("EURUSD"), SYMBOL_BID, price);
         else
           {
            CopyRates(standard_symbol_to_broker_symbol("EURUSD"), PERIOD_M1, time, 1, rates);
            price = rates[0].close;
           }
         price = currency_base_in_dollar(symbol, time)/price;
         return price;
         break;

      case 'J':
         if(time == 0)
            SymbolInfoDouble(standard_symbol_to_broker_symbol("USDJPY"), SYMBOL_BID, price);
         else
           {
            CopyRates(standard_symbol_to_broker_symbol("USDJPY"), PERIOD_M1, time, 1, rates);
            price = rates[0].close;
           }
         price = currency_base_in_dollar(symbol, time)*price;
         return price;
         break;

      case 'G':
         if(time == 0)
            SymbolInfoDouble(standard_symbol_to_broker_symbol("GBPUSD"), SYMBOL_BID, price);
         else
           {
            CopyRates(standard_symbol_to_broker_symbol("GBPUSD"), PERIOD_M1, time, 1, rates);
            price = rates[0].close;
           }
         price = currency_base_in_dollar(symbol, time)/price;
         return price;
         break;

      case 'N':
         if(time == 0)
            SymbolInfoDouble(standard_symbol_to_broker_symbol("NZDUSD"), SYMBOL_BID, price);
         else
           {
            CopyRates(standard_symbol_to_broker_symbol("NZDUSD"), PERIOD_M1, time, 1, rates);
            price = rates[0].close;
           }
         price = currency_base_in_dollar(symbol, time)/price;
         return price;
         break;

      case 'C':
         if(symbol[4] == 'A')
           {
            if(time == 0)
               SymbolInfoDouble(standard_symbol_to_broker_symbol("USDCAD"), SYMBOL_BID, price);
            else
              {
               CopyRates(standard_symbol_to_broker_symbol("USDCAD"), PERIOD_M1, time, 1, rates);
               price = rates[0].close;
              }
           }
         else
           {
            if(time == 0)
               SymbolInfoDouble(standard_symbol_to_broker_symbol("USDCHF"), SYMBOL_BID, price);
            else
              {
               CopyRates(standard_symbol_to_broker_symbol("USDCHF"), PERIOD_M1, time, 1, rates);
               price = rates[0].close;
              }
           }
         price = currency_base_in_dollar(symbol, time)*price;
         return price;
         break;

      default:
         Alert("warning : symbol was not found in get_currency_base_in_balance_currency function.\nCheck the MarketWatch, all 28 main pairs should be in the MarketWatch.");
         return 1.;
         break;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double convert_lot_to_currency(string symbol, double vol, double open_price, datetime time = 0)
  {
   double pos_price_in_balance_currency = open_price * get_currency_base_in_balance_currency(symbol, time);
   double leverage = AccountInfoInteger(ACCOUNT_LEVERAGE) * 1.;
   double one_lot  = StringCompare(symbol, "BITCOIN") == 0? 1.:100000;
   return ((vol * one_lot)/leverage * pos_price_in_balance_currency);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double convert_diff_to_profit(string symbol, double vol, double diff, double open_price, datetime time)
  {
   double leverage = AccountInfoInteger(ACCOUNT_LEVERAGE) * 1.;
   return convert_lot_to_currency(symbol, vol, open_price, time) * (diff/open_price) * leverage;
  }
//+------------------------------------------------------------------+

double diff_to_points(double diff, string sym = NULL)
{
    return diff * MathPow(10, SymbolInfoInteger(sym, SYMBOL_DIGITS));
}

string broker_symbol_to_standard_symbol(string sym)
{
   string splited_sym_array[];
   StringSplit(sym, '_', splited_sym_array);
   return splited_sym_array[0];
}