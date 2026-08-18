#ifndef MQLTRADINGLIB_RUNTIME_INPUT_CONTRACTS_MQH
#define MQLTRADINGLIB_RUNTIME_INPUT_CONTRACTS_MQH

// Production input contract shared by research exporters and live EAs.
// Every value consumed by a production model must be generated in MQL5 at the
// decision timestamp. Python may validate these values, but it must not provide
// a second production implementation of the same feature.

#define RUNTIME_INPUT_CONTRACT_VERSION "1.0.0"
#define BANKS_EFFECTS_TIMEFRAME_COUNT 5

enum ENUM_RUNTIME_INPUT_STATUS
  {
   RUNTIME_INPUT_UNAVAILABLE=0,
   RUNTIME_INPUT_READY=1,
   RUNTIME_INPUT_STALE=2,
   RUNTIME_INPUT_INVALID=3
  };

struct SRuntimeInputContext
  {
   string            symbol;
   datetime          decision_time;
   datetime          latest_complete_m1;
   string            broker_profile_hash;
  };

struct SRuntimeInputValue
  {
   string                    feature_id;
   double                    value;
   datetime                  as_of;
   ENUM_TIMEFRAMES           timeframe;
   ENUM_RUNTIME_INPUT_STATUS status;
   string                    generator_id;
   string                    generator_version;
   string                    reason;
  };

struct STrajectoryPoint
  {
   string            symbol;
   ENUM_TIMEFRAMES   timeframe;
   datetime          event_time;
   datetime          baseline_time;
   datetime          endpoint_time;
   double            baseline_price;
   double            endpoint_price;
   double            signed_log_response;
   int               contributing_m1_bars;
   bool              complete;
  };

int BanksEffectsRequiredTimeframes(ENUM_TIMEFRAMES &timeframes[])
  {
   ArrayResize(timeframes,BANKS_EFFECTS_TIMEFRAME_COUNT);
   timeframes[0]=PERIOD_M1;
   timeframes[1]=PERIOD_M15;
   timeframes[2]=PERIOD_H1;
   timeframes[3]=PERIOD_H4;
   timeframes[4]=PERIOD_D1;
   return ArraySize(timeframes);
  }

bool BanksEffectsIsRequiredTimeframe(const ENUM_TIMEFRAMES timeframe)
  {
   ENUM_TIMEFRAMES required[];
   BanksEffectsRequiredTimeframes(required);
   for(int i=0; i<ArraySize(required); ++i)
      if(required[i]==timeframe)
         return true;
   return false;
  }

bool RuntimeInputIsUsable(const SRuntimeInputValue &candidate,
                          const datetime decision_time,
                          const int maximum_age_seconds)
  {
   if(candidate.status!=RUNTIME_INPUT_READY)
      return false;
   if(candidate.as_of<=0 || candidate.as_of>decision_time)
      return false;
   if(maximum_age_seconds>=0 && decision_time-candidate.as_of>maximum_age_seconds)
      return false;
   if(candidate.generator_id=="" || candidate.generator_version=="")
      return false;
   return true;
  }

#endif
