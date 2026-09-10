# DSSAT-EW method implementation

## 1. Overview

DSSAT-EW is a hybrid simulation and residual-learning framework. DSSAT
provides crop-state and greenhouse-gas simulation outputs. The DSSAT-EW layer
adds daily extreme-weather exposure, phenology, and background-climate
features, then learns an observational residual correction for yield, N2O, and
rice CH4. The same feature construction is used for baseline and counterfactual
weather treatments.

The implementation is organized as:

```text
weather_daily + phenology_windows
              -> thresholds and exposure features

dssat_outputs + exposure_features + climate_background
              -> feature table

observations + feature table
              -> residual models and validation

feature table + residual models
              -> DSSAT-EW predictions

counterfactual predictions + harvested_area
              -> area-weighted attribution
```

## 2. Historical extreme-weather thresholds

For each `grid_id` and `crop`, the historical baseline years in
`config/dssat_ew_config.yml` define three thresholds:

```text
tmax_p90    = Q( daily tmax, 0.90 )
tmin_p10    = Q( daily tmin, 0.10 )
precip_p95  = Q( daily precipitation, 0.95 )
```

The corresponding historical standard deviations are retained as
`sd_tmax`, `sd_tmin`, and `sd_precip`. Threshold calculation is implemented in
`R/climate_thresholds.R` through `calc_extreme_thresholds()`.

For a daily value `x` and threshold `q`, the normalized event intensity is:

```text
heat_intensity   = max(tmax - tmax_p90, 0) / max(sd_tmax, 1e-12)
cold_intensity   = max(tmin_p10 - tmin, 0) / max(sd_tmin, 1e-12)
precip_intensity = max(precip - precip_p95, 0) / max(sd_precip, 1e-12)
```

The event flags identify whether the corresponding threshold is exceeded. The
threshold table and event variables are created by
`calc_extreme_thresholds()`, `attach_extreme_thresholds()`, and
`flag_extreme_days()`.

## 3. Counterfactual weather treatments

The counterfactual operator changes only the selected weather tail and retains
all other daily values:

```text
no_heat    : tmax_cf   = min(tmax, tmax_p90)
no_cold    : tmin_cf   = max(tmin, tmin_p10)
no_precip  : precip_cf = min(precip, precip_p95)
no_all     : apply all three operations
baseline   : retain the original daily weather
```

`make_counterfactual_weather()` creates one treatment table, and
`build_counterfactual_weather_set()` combines the configured treatments while
adding the `treatment` identifier.

## 4. Phenology-dependent exposure

Daily weather is joined to crop-specific phenology windows using
`grid_id`, `year`, and `crop`. Only dates inside each stage window contribute
to the stage summary.

For stage `s`, event frequency is:

```text
frequency_e,s = number of event days_e,s / number of stage days_s
```

Stage exposure is the arithmetic mean of daily normalized intensity, including
zero intensity on non-event days:

```text
exposure_e,s = mean( intensity_e,d ) for d in stage s
```

Seasonal exposure is a stage-day-weighted mean of the stage summaries. Early and
late stage features are widened into columns such as
`heat_exposure_early` and `heat_exposure_late`. These operations are implemented
in `R/phenology_exposure.R`.

## 5. Feature-table construction

`standardize_dssat_outputs()` maps common DSSAT output names to the canonical
fields used by the framework:

```text
HWAM  -> yield_dssat
N2OEM -> n2o_dssat
CH4EM -> ch4_dssat
LAIH  -> lai_dssat
SWM   -> soil_moisture_dssat
NIAM  -> soil_n_dssat
```

`assemble_feature_table()` joins standardized DSSAT outputs with seasonal
exposure features and background-climate predictors using the shared scenario
identifiers. The resulting table contains the predictors configured under
`predictors` in `config/dssat_ew_config.yml`.

## 6. Observational residual learning

For each target `yield`, `n2o`, and `ch4`, the target-specific residual is:

```text
residual_target = target_observation - target_dssat
```

The Random Forest predictor set combines three groups:

1. DSSAT state variables, including yield, N2O, CH4, leaf area index, soil
   moisture, and soil nitrogen;
2. phenology-dependent exposure variables and event frequencies;
3. background-climate variables, including temperature, precipitation, and
   radiation summaries.

Rows with complete target and predictor information are used for model fitting.
The configured `ntree`, `nodesize`, `mtry`, and random seed are stored with each
fitted object. Leave-one-out validation is implemented in
`validate_all_residual_models()`.

The model-training and model-application stages are separated into workflows
02 and 03. Workflow 04 applies the same fitted residual models to the configured
counterfactual treatments.

## 7. Smooth residual correction

The training residual distribution determines a robust scale parameter:

```text
lambda = quantile( abs(residual), lambda_quantile )
```

The raw Random Forest residual is transformed as:

```text
r_bounded = lambda * tanh(r_raw / lambda)
```

This transformation is approximately linear near zero, preserves the sign of
the residual, and approaches `+lambda` or `-lambda` for large predictions. The
final corrected value is:

```text
target_dssat_ew = target_dssat + r_bounded
```

The implementation is in `bounded_response()` and
`apply_dssat_ew_models()`.

## 8. Counterfactual attribution

For target `y`, treatment `c`, and analysis group `g`, the area-weighted
contribution compares baseline and counterfactual predictions:

```text
baseline_mean_g = sum( baseline_y_i * area_i ) / sum( area_i )
cf_mean_g       = sum( counterfactual_y_i * area_i ) / sum( area_i )

contribution_g(%) =
  100 * sum( (baseline_y_i - counterfactual_y_i) * area_i ) /
        sum( baseline_y_i * area_i )
```

The grouping variables and area-weight field are configured under `attribution`.
`compute_counterfactual_contribution()` calculates one target-treatment pair,
and `compute_all_counterfactual_contributions()` evaluates all configured pairs.

## 9. Greenhouse-gas units and conversions

The canonical target fields are `n2o_dssat`, `ch4_dssat`, `n2o_obs`, and
`ch4_obs`. Their units and whether they represent elemental mass, molecular
mass, or CO2-equivalent mass are defined by the input data release. The bridge
helpers provide the molecular conversions:

```text
CH4-C -> CH4   : value * 16 / 12
N2O-N -> N2O   : value * 44 / 28
```

`add_ghg_co2e()` combines CH4 and N2O with the configured 100-year global
warming-potential factors when a combined CO2-equivalent field is required.

## 10. Uncertainty helpers

`R/uncertainty.R` provides three reusable operations:

- `summarise_ensemble()` calculates ensemble means, standard deviations,
  variances, and quantiles;
- `decompose_prediction_uncertainty()` separates squared bias and model
  variance relative to a reference table;
- `partition_variance_by_source()` reports source-specific and total variance.

These functions use the same group identifiers as the main prediction tables.

## 11. Implementation map

| Component | Main implementation |
|---|---|
| Package loading | `R/packages.R` |
| Configuration and utilities | `R/utils.R` |
| Input schema and dates | `R/schema.R` |
| Thresholds and weather treatments | `R/climate_thresholds.R` |
| Phenology exposure | `R/phenology_exposure.R` |
| DSSAT bridge and feature joins | `R/dssat_bridge.R` |
| Residual learning and validation | `R/residual_learning.R` |
| Prediction assembly | `R/dssat_ew_predict.R` |
| Counterfactual attribution | `R/counterfactual_attribution.R` |
| Uncertainty summaries | `R/uncertainty.R` |

The four workflow scripts call these components in sequence and write their
tables to the configured `results/` directory.
