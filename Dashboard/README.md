# Dashboard Components

## Responsive button layout

`ResponsiveButtonLayout.mqh` provides deterministic placement for fixed-size chart controls across all `ENUM_BASE_CORNER` values.

It:

- wraps a logical button row to the available chart width;
- preserves left-to-right logical order at right-side corners;
- accounts for the top-left anchor used by fixed-size MQL chart objects;
- grows wrapped rows inward from lower chart corners;
- has no dependency on a particular EA, label, color, or object-creation API.

Configure `SResponsiveButtonLayout` once after reading the chart width, then call `ResponsiveButtonPosition()` for every control. Reconfigure on `CHARTEVENT_CHART_CHANGE`.

`../Tests/ResponsiveButtonLayoutTests.mq5` covers narrow lower-right wrapping, wide upper-left placement, and invalid inputs.
