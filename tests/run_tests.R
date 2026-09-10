source("R/utils.R")

x <- c(-100, -2, 0, 2, 100, NA_real_)
y <- bounded_response(x, lambda = 3)
stopifnot(
  length(y) == length(x),
  is.na(y[6]),
  y[3] == 0,
  all(abs(y[1:5]) <= 3),
  isTRUE(all.equal(y[2], -y[4])),
  inherits(try(bounded_response(1, 0), silent = TRUE), "try-error")
)

source("R/climate_thresholds.R")
w <- data.frame(
  tmax = c(20, 35), tmin = c(0, -10), precip = c(5, 100),
  tmax_p90 = c(30, 30), tmin_p10 = c(-5, -5), precip_p95 = c(50, 50)
)
stopifnot(
  identical(make_counterfactual_weather(w, "no_heat")$tmax, c(20, 30)),
  identical(make_counterfactual_weather(w, "no_cold")$tmin, c(0, -5)),
  identical(make_counterfactual_weather(w, "no_precip")$precip, c(5, 50))
)

message("All DSSAT-EW unit tests passed.")
