# Correlation

`CorrelationClass.mqh` provides two APIs:

- `CorrelationCalculator` owns a rolling Pearson window through `SetParams`,
  `Init`, `Step`, and `Reset`. The original constructor, `addData`, and
  `getCorrelation` remain available as compatibility adapters.
- `CalculateAssetCorrelation(symbol1, symbol2, timeframe, shift, start, end,
  maximum_completed_bars)` returns Pearson correlation of completed-bar
  close-to-close log returns. The Symbol 1 time window is broker time. D1
  ignores it. Positive shifts use earlier Symbol 2 bars; negative shifts are
  retrospective/look-ahead. Returns across missing timestamps or market
  closures are rejected, and only exact timestamps are paired.

The formal statistic is intentionally close-only because Pearson return
correlation is defined on closes. It does not measure open, range, body, wick,
gap, or true-range dependence. The function returns `EMPTY_VALUE` for invalid
arguments, insufficient observations, constant inputs, or unavailable history.
