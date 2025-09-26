import os
import time
import sys
from datetime import datetime, timedelta

import pandas as pd
import numpy as np

# Constants ==================================================================================
_30_DAYS_MONTH   = {4, 6, 9, 11}

PAIR_NAMES = ("AUDCAD", "AUDCHF", "AUDJPY", "AUDNZD", "AUDUSD",
              "CADCHF", "CADJPY", "CHFJPY", 
              "EURAUD", "EURCAD", "EURCHF", "EURGBP", "EURJPY", "EURNZD", "EURUSD",
              "GBPAUD", "GBPCAD", "GBPCHF", "GBPJPY", "GBPNZD", "GBPUSD",
              "NZDCAD", "NZDCHF", "NZDJPY", "NZDUSD",
              "USDCAD", "USDCHF", "USDJPY", "XAUUSD")
ALL_CURRENCY_NAMES = ("USD", "CAD", "EUR", "GBP", "JPY", "CHF", "AUD", "NZD")
ALL_IMPORTANT_IMPACTS = ("High Impact Expected", "Medium Impact Expected")

# Utility Functions ==========================================================================
def is_leap_year(year):
    if ( year % 4 == 0 and year % 100 != 0 ) or ( year % 400 == 0 ): 
        return True
    return False

def get_last_available_news_date():
    this_file_address, _ = os.path.split(__file__)
    curr_year, curr_month, curr_day = time.strftime("%Y-%m-%d", time.localtime()).split("-")
    
    news_folder_address = os.path.join(this_file_address, "..", "..", "ForexAnalyzer", "News")
    
    last_date_64 = pd.Timestamp("1970-01-01").to_datetime64()
    
    for f in os.listdir(news_folder_address):
        f_parts = f.split("-")
        if f_parts[0] == "NewsTable":
            end_date = f_parts[3].split(".xls")[0].strip()
            end_date_parts = end_date.split(".")
            
            if len(end_date_parts) < 3: # A deprecated naming rule   --------------------             
                end_year = int(end_date_parts[0])
                end_month = int(end_date_parts[1])
                if end_month in _30_DAYS_MONTH:
                    end_date_parts += ["30"]
                elif end_month == 2 :
                    if is_leap_year(end_year):
                        end_date_parts += ["29"]
                    else :
                        end_date_parts += ["28"]
                else : 
                    end_date_parts += ["31"]
            # ---------------------------------------------------------------------------
            try:
                end_date_64 = pd.Timestamp(f"{end_date_parts[0]}-{end_date_parts[1]}-{end_date_parts[2]}").to_datetime64()
            except:
                try:
                    end_date_64 = pd.Timestamp(f"{end_date_parts[0]}-{end_date_parts[1]}-{int(end_date_parts[2])-1}").to_datetime64()
                except:
                    try:
                        end_date_64 = pd.Timestamp(f"{end_date_parts[0]}-{end_date_parts[1]}-{int(end_date_parts[2])-2}").to_datetime64()
                    except:
                        end_date_64 = pd.Timestamp(f"{end_date_parts[0]}-{end_date_parts[1]}-{int(end_date_parts[2])-3}").to_datetime64()
            last_date_64 = max(last_date_64, end_date_64)
                
    return pd.Timestamp(last_date_64)

def get_end_of_this_week_date():
    today = datetime.today()
    end_of_week = today + timedelta((6 - today.weekday() + 7) % 7) + timedelta(7)
    return pd.Timestamp(end_of_week.date())
    
# Main Functions =============================================================================
def update_news_in_forex_analyzer_till_next_week() :
    this_file_address, _ = os.path.split(__file__)    
    # 1. Read ForexAnalyzer News Folder
    last_available_news_date = get_last_available_news_date()
    
    # 2. Get News of current week if is not available
    expected_last_available_news_date = get_end_of_this_week_date()
    if last_available_news_date.to_datetime64() < expected_last_available_news_date.to_datetime64():
        start_date = pd.Timestamp(last_available_news_date.to_datetime64() + 24 * 60 * 60)
        command = f"python \"{os.path.join(f"{this_file_address}", "..", "..", "ForexAnalyzer", "News", "ForexFactoryScraper.py")}\""
        command += f" {start_date.day} {start_date.month} {start_date.year}"
        command += f" {expected_last_available_news_date.day} {expected_last_available_news_date.month} {expected_last_available_news_date.year}"
        os.system(command)

def update_pair_news_indicator_file():
    this_file_address, _ = os.path.split(__file__)
    # 3. Filter them based on this data in ForexAnalyzer's News/Result folder
    news_table  = pd.read_excel(os.path.join(f"{this_file_address}", "..", "..", "ForexAnalyzer", "News", "LastAvailable - NewsTable.xlsx"))
    
    for pair in PAIR_NAMES:
        result_file = pd.read_csv(os.path.join(f"{this_file_address}", "..", "..", "ForexAnalyzer", "Analysis", "TicksAnalysisResults", f"{pair}-Result.csv"))
        news_table_temp = news_table.copy()
        filter_idx = np.zeros(len(news_table_temp))
        
        if len(result_file) == 0:
            result_file = pd.read_csv(os.path.join(f"{this_file_address}", "..", "..", "ForexAnalyzer", "News", "Results", "Fake-Result.csv"))
        
        for currency, impact, title in zip(result_file.currency, result_file.impact, result_file.title):
                    filter_idx = np.logical_or(np.logical_and(np.logical_and(
                                                              news_table_temp.currency == currency, 
                                                              news_table_temp.impact == impact), 
                                                              news_table_temp.title == title), filter_idx)
        news_table_temp = news_table_temp[filter_idx]
        
        # 4. Create csv files for each pair based on the file was available in News/Result folder
        indicator_dict_list = []
        news_table_temp.index = np.arange(0, len(news_table_temp))
        for i in range(len(news_table_temp)):
            if np.isnan(news_table_temp.hour[i]):
                continue
            # TODO: hour correction needs to be adapted to non-DLS situation 
            time_of_news = pd.Timestamp(f"{news_table_temp.year[i]}.{news_table_temp.month[i]}.{news_table_temp.day[i]} {news_table_temp.hour[i]}:{news_table_temp.minute[i]}")
            time_of_news = pd.Timestamp(time_of_news.to_datetime64() + 2 * 3600)
            
            indicator_dict_list += [{"year" : time_of_news.year,
                                     "month" : time_of_news.month,
                                     "day" : time_of_news.day,
                                     "hour" : time_of_news.hour,
                                     "minute" : time_of_news.minute,
                                     "title" : news_table_temp.title[i],
                                     "impact" : news_table_temp.impact[i],
                                     "mean_im_profit_pp" : result_file.mean_im_profit_pp[result_file.title == news_table_temp.title[i]].values[0],
                                     "max_spread_pp" : result_file.max_spread_pp[result_file.title == news_table_temp.title[i]].values[0],
                                     "std_im_profit_pp" : result_file.std_im_profit_pp[result_file.title == news_table_temp.title[i]].values[0],
                                    }]
        
        # 5. Put them in the "Files folder" of MT5
        try:
            pd.DataFrame(indicator_dict_list).to_csv(os.path.join(f"{this_file_address}", "..", "..", "..", "..", "..", "..", "Common", "Files", f"{pair}-NewsIndicatorFile.csv"))
        except:
            pd.DataFrame(indicator_dict_list).to_csv(os.path.join(f"{this_file_address}", "..", "..", "..", "..", "..", "..", "..", f"users/{os.getlogin()}/AppData/Roaming/MetaQuotes/Terminal", "Common", "Files", f"{pair}-NewsIndicatorFile.csv"))