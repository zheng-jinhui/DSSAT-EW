# Variable dictionary

## Identifiers

| Variable | Description |
|---|---|
| `grid_id` | Spatial grid-cell identifier |
| `year` | Simulation year |
| `crop` | Crop type |
| `esm` | Earth system model identifier |
| `ssp` | Shared socioeconomic pathway identifier |
| `treatment` | Counterfactual weather treatment |

## Weather forcing

| Variable | Description |
|---|---|
| `tmax` | Daily maximum air temperature |
| `tmin` | Daily minimum air temperature |
| `precip` | Daily precipitation |
| `srad` | Daily shortwave radiation |

## Extreme thresholds

| Variable | Description |
|---|---|
| `tmax_p90` | Historical 90th percentile of daily maximum temperature |
| `tmin_p10` | Historical 10th percentile of daily minimum temperature |
| `precip_p95` | Historical 95th percentile of daily precipitation |
| `sd_tmax` | Historical standard deviation of daily maximum temperature |
| `sd_tmin` | Historical standard deviation of daily minimum temperature |
| `sd_precip` | Historical standard deviation of daily precipitation |

## Event flags and intensity

| Variable | Description |
|---|---|
| `heat_event` | Whether daily maximum temperature exceeds `tmax_p90` |
| `cold_event` | Whether daily minimum temperature falls below `tmin_p10` |
| `precip_event` | Whether daily precipitation exceeds `precip_p95` |
| `heat_intensity` | Positive exceedance above `tmax_p90`, normalized by historical SD |
| `cold_intensity` | Positive exceedance below `tmin_p10`, normalized by historical SD |
| `precip_intensity` | Positive exceedance above `precip_p95`, normalized by historical SD |

## Stage exposure

| Variable | Description |
|---|---|
| `stage` | Crop-specific phenological stage |
| `stage_group` | Harmonized stage group, typically `early` or `late` |
| `stage_days` | Number of daily records within the stage |
| `heat_frequency` | Fraction of stage days with extreme heat |
| `cold_frequency` | Fraction of stage days with extreme cold |
| `precip_frequency` | Fraction of stage days with heavy precipitation |
| `heat_exposure` | Mean normalized heat exceedance intensity over the stage or season |
| `cold_exposure` | Mean normalized cold exceedance intensity over the stage or season |
| `precip_exposure` | Mean normalized precipitation exceedance intensity over the stage or season |

## DSSAT state predictors

| Variable | Description |
|---|---|
| `yield_dssat` | DSSAT-simulated seasonal crop yield |
| `n2o_dssat` | DSSAT-simulated seasonal N2O emission |
| `ch4_dssat` | DSSAT-simulated seasonal CH4 emission |
| `lai_dssat` | DSSAT leaf area index predictor |
| `soil_moisture_dssat` | DSSAT soil moisture predictor |
| `soil_n_dssat` | DSSAT mineral nitrogen predictor |

## Observation and residual variables

| Variable | Description |
|---|---|
| `yield_obs` | Observationally constrained crop yield |
| `n2o_obs` | Observationally constrained N2O emission |
| `ch4_obs` | Observationally constrained CH4 emission |
| `residual` | Observation minus DSSAT simulation |
| `*_residual_raw` | RF-predicted raw residual for the target variable |
| `*_residual_bounded` | Bounded RF residual after tanh operator |
| `*_dssat_ew` | Final DSSAT-EW corrected target variable |

