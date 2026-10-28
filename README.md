# DSSAT-EW supplementary code

This repository contains the implementation of the DSSAT-EW hybrid framework
for correcting DSSAT crop and greenhouse-gas simulations under extreme weather.
The framework combines DSSAT state variables, phenology-dependent weather
exposure, observational residual learning, and counterfactual attribution.

## Associated manuscript

This code supports the manuscript *Extreme heat drives future crop losses while heavy rain drives GHG emissions*.

Authors, in manuscript order:

- Jinhui Zheng
- Le Yu
- Xinan Zhang
- Matthew Tom Harrison
- Pete Smith
- Ke Liu
- Min Kang
- Hanyi Wu
- Liujun Xiao

## Model mechanism

The calculation proceeds through seven linked stages:

```text
Daily weather and phenology
            |
            v
Historical extreme-weather thresholds
            |
            v
Stage and seasonal exposure features
            |
            +--------------------+
            |                    |
            v                    v
DSSAT simulation outputs     Observations
            |                    |
            +---------> Residual learning
                              |
                              v
                    Bounded residual correction
                              |
                              v
                       DSSAT-EW predictions
                              |
                              v
                    Area-weighted attribution
```

For each grid cell and crop, historical weather defines the 90th percentile
of daily maximum temperature, the 10th percentile of daily minimum temperature,
and the 95th percentile of daily precipitation. Extreme-day intensity is the
positive threshold exceedance divided by the corresponding historical standard
deviation. Stage-level values are summarized to seasonal features using
stage-day weights.

The residual-learning module defines the training residual as:

```text
residual = observation - DSSAT simulation
```

A Random Forest predicts this residual from DSSAT state variables, weather
exposure features, and background-climate variables. The predicted residual is
bounded with a smooth hyperbolic-tangent operator before being added to the
DSSAT value:

```text
bounded_residual = lambda * tanh(raw_residual / lambda)
DSSAT-EW = DSSAT + bounded_residual
```

Counterfactual treatments cap the relevant weather tail while retaining all
other daily values. The resulting DSSAT-EW treatment differences are aggregated
with harvested-area weights for climate-extreme attribution.

## Folder layout

```text
DSSAT_EW/
|-- R/
|   |-- packages.R
|   |-- utils.R
|   |-- schema.R
|   |-- climate_thresholds.R
|   |-- phenology_exposure.R
|   |-- dssat_bridge.R
|   |-- residual_learning.R
|   |-- dssat_ew_predict.R
|   |-- counterfactual_attribution.R
|   `-- uncertainty.R
|-- workflows/
|   |-- 01_prepare_inputs/run_prepare_inputs.R
|   |-- 02_train_residual_models/run_train_residual_models.R
|   |-- 03_apply_dssat_ew/run_apply_dssat_ew.R
|   `-- 04_counterfactual_attribution/run_counterfactual_attribution.R
|-- config/
|   `-- dssat_ew_config.yml
|-- docs/
|   |-- input_schema.md
|   |-- method_implementation.md
|   `-- variable_dictionary.md
|-- data/
|-- models/
`-- results/
```

The equations and implementation locations are documented in
[`docs/method_implementation.md`](docs/method_implementation.md). Input fields
and units are described in [`docs/input_schema.md`](docs/input_schema.md) and
[`docs/variable_dictionary.md`](docs/variable_dictionary.md).

## Data roles

The configuration file connects six input tables to the workflow:

- `weather_daily.csv`: daily weather forcing;
- `phenology_windows.csv`: crop-stage date windows;
- `dssat_outputs.csv`: standardized DSSAT state and target outputs;
- `gcor_observations.csv`: observational target values used for residual learning;
- `climate_background.csv`: seasonal background-climate predictors;
- `harvested_area.csv`: area weights for regional attribution.

DSSAT simulations are supplied through `dssat_outputs.csv`. The bridge helpers
standardize common DSSAT variable names, while the remaining modules construct
exposure features, fit residual models, apply the correction, and summarize
counterfactual differences.

## Typical workflow

Run the workflow scripts from the repository root:

```r
source("workflows/01_prepare_inputs/run_prepare_inputs.R")
source("workflows/02_train_residual_models/run_train_residual_models.R")
source("workflows/03_apply_dssat_ew/run_apply_dssat_ew.R")
source("workflows/04_counterfactual_attribution/run_counterfactual_attribution.R")
```

The scripts are intentionally thin. Reusable calculations are implemented in
`R/`, and paths, thresholds, model settings, predictor groups, and attribution
settings are controlled by `config/dssat_ew_config.yml`.

## Trained model objects

Workflow 02 writes one fitted Random Forest object per response to `models/`:

```text
models/dssat_ew_rf_yield.rds
models/dssat_ew_rf_n2o.rds
models/dssat_ew_rf_ch4.rds
models/model_manifest.csv
```

Each object stores the predictor list, truncation parameter, model settings,
software versions, and a fingerprint of the training table. The manifest stores
the SHA-256 checksum for each serialized model object.

## Tests

From the repository root, run:

```sh
Rscript tests/run_tests.R
```

The test script checks the smooth residual-truncation operator and the three
single-process counterfactual weather-capping operations.

## Citation and DOI

Record the version-specific DOI from the archival release in this section and
in the associated manuscript when the archive is created.
