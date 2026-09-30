# Marketing Campaign A/B Test: Did the Ads Pay Off?

**Business problem:** a company showed an ad campaign to most users and a public service announcement (PSA) to a randomized control group, and needs to know whether the ads increased conversions enough to justify continuing the campaign.

## Key findings

- **The ad worked.** Ad users converted at **2.55%** vs **1.79%** for the PSA group, a **+0.77 percentage point** lift, or **43% relative lift** (95% CI **30% to 58%**, one-sided p = 8.5 × 10⁻¹⁴, n = 588,101). The same result came out of Python, R and SQL, a bootstrap, and an exposure-adjusted logistic model (+0.76 pp).
- **The lift is concentrated among heavily exposed users.** The **66%** of users who saw 20 or fewer ads show no detectable difference between ad and PSA. The gap appears at 21–50 ads and is largest at 51+ ads (+5.5 pp). This is an association, not proof that more ads cause more conversions (exposure was not randomized).
- **Whether it pays depends on one number the data does not contain.** The campaign produced an estimated **4,343** extra conversions (95% CI 3,360 to 5,326) from 14.0M impressions. At an *illustrative, assumed* $5 CPM, it breaks even if one conversion is worth more than about **$16** ($13 to $21 across the confidence interval).

## Best chart

![Lift by exposure](figures/05_lift_by_exposure.png)

## Recommendation

**Continue the campaign if finance confirms a conversion is worth more than the break-even value at the real media cost, and keep a randomized holdout of about 10%.** Before scaling spend, run a follow-up test that randomizes ad frequency, because most users saw too few ads to show any lift and the data cannot say whether more ads would change that.

See the one-page [executive summary](reports/executive_summary.md).

## Approach and tools

| Step | What was done | Where |
|---|---|---|
| Framing | Hypotheses, metric, α = 0.05, power = 0.80, and known limits written before analysis | [notebook, top](notebooks/01_ab_test.ipynb) |
| Data audit | Nulls, duplicates, valid ranges, group split, exposure balance with effect sizes | notebook §1 |
| SQL | Loaded into PostgreSQL; 5 queries using CTEs, `FILTER`, and window functions (`RANK`, `SUM() OVER`); the z-test is recomputed in SQL | [`sql/`](sql/), [`reports/sql_check.md`](reports/sql_check.md) |
| Primary test | Pooled two-proportion z-test; Wald CI for the difference; log-method CI for the relative lift | notebook §2 |
| Robustness | Bootstrap (10,000 resamples); logistic regression adjusting for exposure; independent re-run in R | notebook §2, [`r/check_ztest.R`](r/check_ztest.R) |
| Power | Minimum detectable effect (0.23 pp, 12.6% relative), power curve, effective sample size | notebook §3 |
| Segments | 15 pre-defined segments, Fisher's exact tests, Newcombe CIs, Holm correction, interaction tests for heterogeneity | notebook §4 |
| Business impact | Break-even value per conversion across lift scenarios and assumed CPMs; every assumption labeled | notebook §5 |

**Tools:** Python (pandas, NumPy, SciPy, statsmodels, Matplotlib, seaborn), Jupyter, PostgreSQL, SQLAlchemy, R, Git.

**Three-way verification.** The headline z statistic (7.370), the p-value and the 95% CI match exactly across statsmodels, R's `prop.test` ([output](reports/r_check_output.txt)) and a hand-written SQL query ([output](reports/sql_check.md)).

## Limitations

- **Lopsided split (96% ad / 4% PSA) with no documented intended ratio.** A sample ratio mismatch test is not possible, and precision is limited by the small control group (equivalent to about 45K users per arm in a balanced test, not 588K).
- **No timestamps.** Test duration, novelty effects and trends over time cannot be checked. Day-of-week differences may reflect which dates fell in the test.
- **No cost or revenue data.** All money figures rest on labeled assumptions; the break-even framing keeps them transparent.
- **Exposure variables were measured after assignment.** Segment results are exploratory, and the exposure finding is an association.
- **Small exposure-pattern differences between groups** (largest effect size 0.04). The exposure-adjusted model gives nearly the same lift.
- **No user attributes or guardrail metrics**, so covariate balance and possible harms cannot be checked.

## How to reproduce

Tested with Python 3.11, R 4.3 and PostgreSQL 16.

```bash
git clone https://github.com/<your-username>/ab-test-marketing-campaign.git
cd ab-test-marketing-campaign
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt

# 1. Download marketing_AB.csv from Kaggle into data/ (link below).
#    Optional integrity check; this project used the file with SHA-256
#    de6ce8def1a6559e9e5ab364fce07cfe2e84f02dd407c3586eea55743c7e17f2
sha256sum data/marketing_AB.csv

# 2. Run the analysis (writes figures/ and reports/results.json)
jupyter nbconvert --to notebook --execute --inplace notebooks/01_ab_test.ipynb

# 3. Independent check in R (base R only)
Rscript r/check_ztest.R

# 4. SQL: load into PostgreSQL, then check every query against pandas
export DATABASE_URL="postgresql+psycopg2://USER:PASSWORD@HOST:5432/DBNAME"
python scripts/load_to_postgres.py
python scripts/verify_sql.py
```

## Repository structure

```
├── notebooks/01_ab_test.ipynb     full analysis, runs top to bottom
├── sql/                            5 commented PostgreSQL queries
├── scripts/                        load CSV into Postgres; verify SQL vs pandas
├── r/check_ztest.R                 independent check in R
├── figures/                        8 charts used in the write-up
├── reports/
│   ├── executive_summary.md        one page, non-technical
│   ├── results.json                every headline number, written by the notebook
│   ├── segment_results.csv         all 15 segment tests with Holm-adjusted p-values
│   ├── sql_check.md                SQL vs pandas verification output
│   ├── r_check_output.txt          R verification output
│   └── interview_prep.md           answers to likely interview questions
└── decisions_log.md                dated analysis decisions and reasons
```

## Credits and references

- **Dataset:** faviovaz (Favio Vázquez), "Marketing A/B Testing," Kaggle: https://www.kaggle.com/datasets/faviovaz/marketing-ab-testing. License: see the dataset page. The CSV is not redistributed in this repository (`data/*.csv` is git-ignored).
- Newcombe, R. G. (1998). Interval estimation for the difference between independent proportions. *Statistics in Medicine*, 17(8), 873–890.
- Holm, S. (1979). A simple sequentially rejective multiple test procedure. *Scandinavian Journal of Statistics*, 6(2), 65–70.
- Kohavi, R., Tang, D., & Xu, Y. (2020). *Trustworthy Online Controlled Experiments.* Cambridge University Press. (Sample ratio mismatch, guardrail metrics, holdouts.)
- statsmodels documentation: `proportions_ztest`, `confint_proportions_2indep`, `NormalIndPower`.
