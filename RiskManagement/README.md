# Stop-loss policy

`StopLossPolicy.mqh` owns deterministic, completed-OHLC stop state for one
position. It supports initial stops based on a setup structure with an ATR
floor, a setup window, ATR distance, session structure, or an externally frozen
MAE quantile expressed in ATR units.

Time-based and signal-invalidation exits are management decisions rather than
broker stop prices. Optional trailing starts only when the caller supplies its
strategy trigger, uses completed-bar structure plus an ATR buffer, and can only
ratchet toward profit. `Reset`, `SetParams`, `Init`, `Begin`, and `Step` make the
state lifecycle explicit.

The library deliberately does not calibrate the MAE quantile online and does not
choose parameters. Supply a value frozen from discovery data. Initial-stop
calculation accepts the broker tick size and minimum stop distance, rounds away
from the entry, and rejects a required distance above the configured ATR maximum
instead of moving the stop inside invalidated structure. The caller must refresh
the broker constraints and still use `OrderCheck` immediately before sending.
`StopLossVolumeForRisk` uses `OrderCalcProfit` and the broker's volume limits to
size from balance risk.

`Tests/StopLossPolicyTests.mq5` covers all five initial methods, true-range ATR,
time and signal exits, and non-loosening trailing behavior.
