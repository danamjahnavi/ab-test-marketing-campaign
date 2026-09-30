# Independent check of the primary result in R (base R only, no packages).
# Run from the repo root:  Rscript r/check_ztest.R
#
# What should match Python (notebooks/01_ab_test.ipynb):
#   * X-squared from prop.test (correct = FALSE) equals z^2 from the pooled z-test,
#     because a 2x2 chi-square test without continuity correction is the squared z-test.
#   * The one-sided p-value matches Python's proportions_ztest(alternative="larger").
#   * The two-sided 95% CI from prop.test is the unpooled Wald interval, which matches
#     confint_proportions_2indep(method="wald"). A one-sided prop.test returns a one-sided
#     interval, so the CI is taken from a separate two-sided call.

df <- read.csv("data/marketing_AB.csv", check.names = FALSE)
stopifnot(nrow(df) == 588101)

# "converted" is stored as the text True/False; as.logical() parses it.
conv <- as.logical(df$converted)
grp  <- df$`test group`

x <- c(ad = sum(conv[grp == "ad"]), psa = sum(conv[grp == "psa"]))
n <- c(ad = sum(grp == "ad"),       psa = sum(grp == "psa"))

one_sided <- prop.test(x, n, alternative = "greater", correct = FALSE)
two_sided <- prop.test(x, n, alternative = "two.sided", correct = FALSE)

rates    <- x / n
abs_lift <- unname(rates["ad"] - rates["psa"])
rel_lift <- abs_lift / unname(rates["psa"])

cat("Users        ad:", n["ad"], " psa:", n["psa"], "\n")
cat("Conversions  ad:", x["ad"], " psa:", x["psa"], "\n")
cat(sprintf("Rates        ad: %.4f%%  psa: %.4f%%\n", 100 * rates["ad"], 100 * rates["psa"]))
cat(sprintf("Absolute lift: %.4f pp   Relative lift: %.2f%%\n", 100 * abs_lift, 100 * rel_lift))
cat(sprintf("X-squared: %.4f   (sqrt = z = %.4f)\n", one_sided$statistic, sqrt(one_sided$statistic)))
cat(sprintf("One-sided p-value: %.4e\n", one_sided$p.value))
cat(sprintf("Two-sided 95%% CI for the difference: [%.4f, %.4f] pp\n",
            100 * two_sided$conf.int[1], 100 * two_sided$conf.int[2]))

# Compare with the numbers the Python notebook saved, if they exist.
json_path <- "reports/results.json"
if (file.exists(json_path)) {
  txt <- paste(readLines(json_path, warn = FALSE), collapse = "")
  grab <- function(key) as.numeric(sub(paste0('.*"', key, '": ([-0-9.eE+]+).*'), "\\1", txt))
  grab_pair <- function(key) {
    inner <- sub(paste0('.*"', key, '": \\[([^]]*)\\].*'), "\\1", txt)
    as.numeric(strsplit(inner, ",")[[1]])
  }
  py_z <- grab("z"); py_p <- grab("p_value"); py_ci <- grab_pair("abs_lift_ci")
  checks <- c(
    z        = isTRUE(all.equal(sqrt(unname(one_sided$statistic)), py_z, tolerance = 1e-8)),
    p_value  = isTRUE(all.equal(one_sided$p.value, py_p, tolerance = 1e-6)),
    ci_lower = isTRUE(all.equal(two_sided$conf.int[1], py_ci[1], tolerance = 1e-8)),
    ci_upper = isTRUE(all.equal(two_sided$conf.int[2], py_ci[2], tolerance = 1e-8))
  )
  cat("\nMatch with Python (reports/results.json):\n"); print(checks)
  if (!all(checks)) stop("R and Python disagree. Investigate before reporting results.")
  cat("All checks passed: R and Python agree.\n")
}
