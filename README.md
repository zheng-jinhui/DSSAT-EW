# DSSAT-EW code

This folder contains the implementation framework for the DSSAT-EW model
described in the manuscript. It provides the computational logic for
extreme-weather correction of DSSAT crop and greenhouse-gas simulations.

The code focuses only on DSSAT-EW:

- historical percentile thresholds for extreme heat, cold and precipitation
- counterfactual no-extreme weather treatments
- phenology-dependent extreme-weather exposure metrics
- Random Forest residual correction for yield, N2O and rice CH4
- leave-one-out validation for the residual-correction module
- bounded residual correction and DSSAT-EW prediction
- counterfactual attribution of climate-extreme impacts
- uncertainty-decomposition helper functions

## Folder layout

```text
DSSAT_EW_public_framework/
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
|   `-- variable_dictionary.md
|-- data/
|-- models/
`-- results/
```

## Input configuration

Input, model and output paths are controlled by `config/dssat_ew_config.yml`.
The default project layout uses `data/`, `models/` and `results/`, and these
paths can be adjusted for a local computing environment.

## Typical workflow

```r
source("workflows/01_prepare_inputs/run_prepare_inputs.R")
source("workflows/02_train_residual_models/run_train_residual_models.R")
source("workflows/03_apply_dssat_ew/run_apply_dssat_ew.R")
source("workflows/04_counterfactual_attribution/run_counterfactual_attribution.R")
```

The workflow scripts are intentionally thin. Most reusable logic is in `R/`.
