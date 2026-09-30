# Decisions Log

A dated record of every analysis choice and the reason for it. Each entry doubles as an interview talking point.

## 2026-09-29: Setup and framing

- **Hypotheses fixed before looking at results.** H1 is one-sided (ad > PSA) because the business question is whether the ad *increased* conversions. α = 0.05, target power = 0.80.
- **Known limits recorded up front:** no timestamps, no cost/revenue, no user attributes, no guardrail metrics, exposure measured after assignment. Writing these first stops them from being rationalized away later.
- **Data file integrity.** The CSV used has SHA-256 `de6ce8de…c7e17f2` (full hash in README), so anyone can confirm they are analysing the same file.
- **The CSV is not committed** (`data/*.csv` in `.gitignore`); the README links to Kaggle instead of redistributing the data.

## 2026-09-29: Data audit

| Check | Outcome |
|---|---|
| Rows | 588,101 |
| Missing values | 0 |
| Duplicate `user_id` | 0 |
| Fully duplicated rows | 0 |
| Groups | ad 564,577 (96.00%), psa 23,524 (4.00%) |
| `total_ads` range | 1 to 2,065 (median 13), long right tail |
| `most_ads_day` / `most_ads_hour` | all valid weekdays / hours 0–23 |

- **No sample ratio mismatch (SRM) test.** SRM needs the *designed* split. It is undocumented, and testing against the observed split passes by construction. I documented this instead of running a meaningless test.
- **Why the split might be 96/4:** a small holdout is common when a company wants to limit revenue lost by not advertising. This cannot be confirmed from the data.
- **Consequence of the split:** the standard error is dominated by the PSA group. The equivalent balanced sample is about 45K per arm, which I report so the 588K figure is not over-sold.
- **Exposure balance check with effect sizes.** Day, hour and `total_ads` distributions differ slightly between groups (tiny p-values, but Cramér's V / KS D at most 0.04). Reporting effect sizes avoids calling a trivial difference a problem just because n is huge.
- **Exposure variables treated as post-treatment.** `total_ads`, `most_ads_day`, `most_ads_hour` describe what users saw during the test, so any slicing by them is exploratory.

## 2026-09-29: SQL

- Loaded into PostgreSQL with the connection string in an environment variable (`DATABASE_URL`), never in code.
- Wrote 5 queries: group KPIs, lift by day (pivot with `FILTER` + `RANK`), hour ranking (`RANK` + `PARTITION BY`), the full z-test and CI, and exposure buckets with a running share (`SUM() OVER (ORDER BY …)`).
- **Every SQL result is checked against pandas** by `scripts/verify_sql.py` (8 of 8 checks pass).
- Lesson learned: psycopg2 treats `%` as a parameter marker even inside SQL comments, so comments avoid the symbol.

## 2026-09-29: Primary test

- **Pooled z-test for the p-value, unpooled (Wald) SE for the CI.** Under H0 the groups share one rate, so pooling is right for the test. The CI describes the observed difference, so it uses each group's own variance.
- **`method="wald"` chosen explicitly** in `confint_proportions_2indep`. The statsmodels default is Newcombe, which would not match R's `prop.test` interval and would look like a discrepancy.
- **The R check uses two calls.** A one-sided `prop.test` returns a one-sided interval, so the CI comes from a separate two-sided call. With `correct = FALSE`, R's X-squared equals z² exactly.
- **Relative lift gets its own CI** (log method on the ratio). Reporting a relative lift next to an absolute-difference CI would mix units.
- **Bootstrap described accurately.** For a 0/1 outcome, resampling users with replacement is mathematically identical to drawing Binomial(n, p̂), so the "parametric" shortcut *is* the nonparametric bootstrap, computed faster.
- **Exposure-adjusted logistic regression as a sensitivity check only.** It adjusts for post-treatment variables, which can bias estimates, so it is not the headline. It matters because it agrees (+0.76 pp vs +0.77 pp), showing the result does not depend on the exposure imbalance.

## 2026-09-29: Power

- **MDE computed by inverting Cohen's h exactly** instead of the grid search in the original plan. A grid can silently return its first value when nothing passes the threshold. A closed-form normal approximation (0.219 pp) cross-checks the exact value (0.226 pp).
- Observed lift is about 3.4× the MDE, with power effectively 1 to detect it.

## 2026-09-29: Segmentation

- **Hours grouped into 4 dayparts for testing.** Several hours have 0 PSA conversions; 24 per-hour tests would have almost no power and inflate the multiple-comparison burden. The 24-hour view is kept as a descriptive chart with no tests.
- **Segment list fixed before viewing segment results:** 7 days + 4 dayparts + 4 exposure buckets = 15 tests.
- **Fisher's exact test and Newcombe intervals** per segment, because some segments have very few PSA conversions (Night has 1).
- **Holm correction** across all 15 tests (11 remain significant). Holm is uniformly more powerful than Bonferroni while still controlling the family-wise error rate.
- **Added interaction likelihood-ratio tests.** "Is the lift positive in segment X?" differs from "does the lift differ across segments?" The second needs an interaction test. All three dimensions show heterogeneity; exposure most strongly (p = 2.3 × 10⁻⁵).
- **Exposure finding framed as association.** Users with ≤20 ads (66% of users) show no detectable lift. Not claimed as causal, because heavy viewers may be more active users.

## 2026-09-29: Business impact

- **Break-even framing instead of an invented revenue figure.** The data has no value per conversion, so the model solves for the value at which the campaign pays off.
- **Cost built from data plus one assumption:** impressions come from summing `total_ads` for ad users (14.0M, data); CPM of $2 / $5 / $10 is labeled an illustrative assumption.
- **Low / mid / high scenarios use the 95% CI bounds of the lift**, so the uncertainty in the estimate carries into the money figures.

## 2026-09-29: Recommendation

- **Continue, conditional on finance's conversion value, with a ~10% randomized holdout**, and run a randomized frequency test before scaling. The exposure pattern is the reason the frequency test comes first.
