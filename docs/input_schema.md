# Input schema

## `weather_daily`

Path in config: `paths.weather_daily`

Required columns:

- `grid_id`: grid-cell identifier
- `year`: simulation year
- `date`: daily date, ISO format recommended
- `crop`: crop name, for example `rice`, `wheat`, `maize`
- `esm`: Earth system model identifier
- `ssp`: scenario identifier
- `tmax`: daily maximum air temperature
- `tmin`: daily minimum air temperature
- `precip`: daily precipitation
- `srad`: daily shortwave radiation

## `phenology_windows`

Path in config: `paths.phenology_windows`

Required columns:

- `grid_id`
- `year`
- `crop`
- `stage`: crop-specific stage label
- `stage_group`: harmonized stage label, normally `early` or `late`
- `start_date`
- `end_date`

Rice stages can be represented as sowing-to-heading and heading-to-maturity.
Wheat stages can be represented as sowing-to-anthesis and anthesis-to-maturity.
Maize stages can be represented as sowing-to-silking and silking-to-maturity.

## `dssat_outputs`

Path in config: `paths.dssat_outputs`

Required columns:

- `grid_id`
- `year`
- `crop`
- `esm`
- `ssp`
- `treatment`: `baseline`, `no_heat`, `no_cold`, `no_precip` or `no_all`
- `yield_dssat`: seasonal DSSAT grain yield
- `n2o_dssat`: seasonal DSSAT N2O emission
- `ch4_dssat`: seasonal DSSAT CH4 emission, set to `NA` or zero for non-rice if not simulated
- `lai_dssat`: DSSAT leaf area index state or seasonal summary
- `soil_moisture_dssat`: DSSAT soil moisture state or seasonal summary
- `soil_n_dssat`: DSSAT soil mineral nitrogen state or seasonal summary

Native DSSAT variable names such as `HWAM`, `N2OEM`, `CH4EM`, `LAIH` and
`NIAM` can be converted with `standardize_dssat_outputs()`.

For counterfactual attribution, DSSAT must be run separately for each weather
treatment. The `treatment` column should therefore identify which DSSAT forcing
was used for each output row.

## `observations`

Path in config: `paths.observations`

Required columns:

- `obs_id`
- `grid_id`
- `year`
- `crop`
- `yield_obs`
- `n2o_obs`
- `ch4_obs`

The observation table is used for residual-model training and validation.

## `climate_background`

Path in config: `paths.climate_background`

Required columns:

- `grid_id`
- `year`
- `crop`
- `esm`
- `ssp`
- `mean_tmax`
- `mean_tmin`
- `total_precip`
- `mean_srad`

## `harvested_area`

Path in config: `paths.harvested_area`

Required columns:

- `grid_id`
- `crop`
- `harvested_area`

This table provides the area weights used in counterfactual attribution.
