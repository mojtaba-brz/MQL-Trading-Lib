#property strict

// Streaming Pearson correlation with explicit lifecycle and a compatibility
// adapter for the original constructor/addData/getCorrelation API.
class CorrelationCalculator
  {
private:
   double            _signal1[];
   double            _signal2[];
   double            _sum1;
   double            _sum2;
   double            _sum1_sq;
   double            _sum2_sq;
   double            _sum_product;
   int               _window;
   int               _index;
   int               _count;
   bool              _initialized;

   void ClearSums(void)
     {
      _sum1=0.0;
      _sum2=0.0;
      _sum1_sq=0.0;
      _sum2_sq=0.0;
      _sum_product=0.0;
      _index=0;
      _count=0;
     }

public:
                     CorrelationCalculator(void)
     {
      _window=0;
      _initialized=false;
      ClearSums();
     }

   // Retained for existing consumers. New code should call SetParams then Init.
                     CorrelationCalculator(const int N)
     {
      _window=0;
      _initialized=false;
      ClearSums();
      SetParams(N);
      Init();
     }

   bool SetParams(const int N)
     {
      if(N<2)
         return false;
      _window=N;
      Reset();
      return true;
     }

   bool Init(void)
     {
      if(_window<2)
         return false;
      if(ArrayResize(_signal1,_window)!=_window ||
         ArrayResize(_signal2,_window)!=_window)
         return false;
      ArrayInitialize(_signal1,0.0);
      ArrayInitialize(_signal2,0.0);
      ClearSums();
      _initialized=true;
      return true;
     }

   void Reset(void)
     {
      ArrayFree(_signal1);
      ArrayFree(_signal2);
      ClearSums();
      _initialized=false;
     }

   bool Step(const double data1,const double data2)
     {
      if(!_initialized || !MathIsValidNumber(data1) || !MathIsValidNumber(data2))
         return false;
      if(_count==_window)
        {
         _sum1-=_signal1[_index];
         _sum2-=_signal2[_index];
         _sum1_sq-=_signal1[_index]*_signal1[_index];
         _sum2_sq-=_signal2[_index]*_signal2[_index];
         _sum_product-=_signal1[_index]*_signal2[_index];
        }
      else
         ++_count;

      _signal1[_index]=data1;
      _signal2[_index]=data2;
      _sum1+=data1;
      _sum2+=data2;
      _sum1_sq+=data1*data1;
      _sum2_sq+=data2*data2;
      _sum_product+=data1*data2;
      _index=(_index+1)%_window;
      return true;
     }

   int Count(void) const
     {
      return _count;
     }

   bool IsReady(void) const
     {
      return _initialized && _count==_window;
     }

   double Value(void) const
     {
      if(!_initialized || _count<2)
         return EMPTY_VALUE;
      double count=(double)_count;
      double covariance=_sum_product-_sum1*_sum2/count;
      double variance1=_sum1_sq-_sum1*_sum1/count;
      double variance2=_sum2_sq-_sum2*_sum2/count;
      if(variance1<=0.0 || variance2<=0.0)
         return EMPTY_VALUE;
      double value=covariance/MathSqrt(variance1*variance2);
      return MathMax(-1.0,MathMin(1.0,value));
     }

   void addData(const double data1,const double data2)
     {
      Step(data1,data2);
     }

   double getCorrelation(void) const
     {
      return Value();
     }
  };

double PearsonCorrelation(const double &values1[],
                          const double &values2[],
                          const int count)
  {
   if(count<2 || ArraySize(values1)<count || ArraySize(values2)<count)
      return EMPTY_VALUE;
   double sum1=0.0,sum2=0.0,sum1_sq=0.0,sum2_sq=0.0,sum_product=0.0;
   for(int index=0;index<count;++index)
     {
      double value1=values1[index];
      double value2=values2[index];
      if(!MathIsValidNumber(value1) || !MathIsValidNumber(value2))
         return EMPTY_VALUE;
      sum1+=value1;
      sum2+=value2;
      sum1_sq+=value1*value1;
      sum2_sq+=value2*value2;
      sum_product+=value1*value2;
     }
   double observations=(double)count;
   double covariance=sum_product-sum1*sum2/observations;
   double variance1=sum1_sq-sum1*sum1/observations;
   double variance2=sum2_sq-sum2*sum2/observations;
   if(variance1<=0.0 || variance2<=0.0)
      return EMPTY_VALUE;
   return MathMax(-1.0,MathMin(1.0,covariance/MathSqrt(variance1*variance2)));
  }

bool AssetCorrelationClockMinute(const string value,int &minute_of_day)
  {
   minute_of_day=0;
   if(StringLen(value)!=5 || StringSubstr(value,2,1)!=":")
      return false;
   int hour=(int)StringToInteger(StringSubstr(value,0,2));
   int minute=(int)StringToInteger(StringSubstr(value,3,2));
   if(hour<0 || hour>23 || minute<0 || minute>59)
      return false;
   minute_of_day=hour*60+minute;
   return true;
  }

bool AssetCorrelationInClockWindow(const datetime broker_bar_open,
                                   const int start_minute,
                                   const int end_minute)
  {
   MqlDateTime decoded={};
   if(!TimeToStruct(broker_bar_open,decoded))
      return false;
   int current=decoded.hour*60+decoded.min;
   if(start_minute==0 && end_minute==1439)
      return true;
   if(start_minute<=end_minute)
      return current>=start_minute && current<=end_minute;
   return current>=start_minute || current<=end_minute;
  }

// Pearson correlation of completed-bar close-to-close log returns. MQL5 rate
// timestamps are broker time, so the Symbol 1 clock window needs no conversion.
// Positive shift pairs Symbol1[t] with an earlier Symbol2 bar. Negative shifts
// are retrospective and must not be used as a causal runtime input.
double CalculateAssetCorrelation(const string symbol1,
                                 const string symbol2,
                                 const ENUM_TIMEFRAMES timeframe,
                                 const int symbol2_bar_shift=0,
                                 const string symbol1_period_start="00:00",
                                 const string symbol1_period_end="23:59",
                                 const int maximum_completed_bars=10000)
  {
   if(symbol1=="" || symbol2=="" || maximum_completed_bars<3)
      return EMPTY_VALUE;
   int period_seconds=PeriodSeconds(timeframe);
   if(period_seconds<=0)
      return EMPTY_VALUE;
   int start_minute=0,end_minute=0;
   if(!AssetCorrelationClockMinute(symbol1_period_start,start_minute) ||
      !AssetCorrelationClockMinute(symbol1_period_end,end_minute))
      return EMPTY_VALUE;

   MqlRates rates1[],rates2[];
   int extra=MathAbs(symbol2_bar_shift)+2;
   int copied1=CopyRates(symbol1,timeframe,1,maximum_completed_bars+1,rates1);
   int copied2=CopyRates(symbol2,timeframe,1,maximum_completed_bars+extra,rates2);
   if(copied1<3 || copied2<3)
      return EMPTY_VALUE;
   ArraySetAsSeries(rates1,false);
   ArraySetAsSeries(rates2,false);

   double values1[],values2[];
   int capacity=MathMin(copied1-1,copied2-1);
   ArrayResize(values1,capacity);
   ArrayResize(values2,capacity);
   int count=0;
   int index2=1;
   for(int index1=1;index1<copied1;++index1)
     {
      if(rates1[index1].time-rates1[index1-1].time!=period_seconds)
         continue;
      if(timeframe!=PERIOD_D1 &&
         !AssetCorrelationInClockWindow(rates1[index1].time,start_minute,end_minute))
         continue;
      datetime target=rates1[index1].time-symbol2_bar_shift*period_seconds;
      while(index2<copied2 && rates2[index2].time<target)
         ++index2;
      if(index2>=copied2)
         break;
      if(rates2[index2].time!=target ||
         rates2[index2].time-rates2[index2-1].time!=period_seconds)
         continue;
      if(rates1[index1-1].close<=0.0 || rates1[index1].close<=0.0 ||
         rates2[index2-1].close<=0.0 || rates2[index2].close<=0.0)
         continue;
      if(count>=capacity)
         break;
      values1[count]=MathLog(rates1[index1].close/rates1[index1-1].close);
      values2[count]=MathLog(rates2[index2].close/rates2[index2-1].close);
      ++count;
     }
   return PearsonCorrelation(values1,values2,count);
  }
