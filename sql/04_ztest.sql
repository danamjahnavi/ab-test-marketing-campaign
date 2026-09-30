-- 04_ztest.sql
-- The primary two-proportion z-test computed entirely in SQL, as a third independent
-- check next to Python (statsmodels) and R (prop.test).
--   z uses the POOLED standard error (both groups share one rate under H0).
--   The 95 percent CI uses the UNPOOLED (Wald) standard error around the observed difference.
-- PostgreSQL has no normal CDF built in, so the p-value is not computed here;
-- the z statistic and interval are compared with Python instead.

WITH g AS (
    SELECT SUM(CASE WHEN test_group = 'ad'  THEN 1 ELSE 0 END)::numeric                   AS n_ad,
           SUM(CASE WHEN test_group = 'psa' THEN 1 ELSE 0 END)::numeric                   AS n_psa,
           SUM(CASE WHEN test_group = 'ad'  AND converted THEN 1 ELSE 0 END)::numeric     AS x_ad,
           SUM(CASE WHEN test_group = 'psa' AND converted THEN 1 ELSE 0 END)::numeric     AS x_psa
    FROM ab_test
),
rates AS (
    SELECT *,
           x_ad / n_ad                       AS p_ad,
           x_psa / n_psa                     AS p_psa,
           (x_ad + x_psa) / (n_ad + n_psa)   AS p_pool
    FROM g
),
se AS (
    SELECT *,
           SQRT(p_pool * (1 - p_pool) * (1 / n_ad + 1 / n_psa))            AS se_pooled,
           SQRT(p_ad * (1 - p_ad) / n_ad + p_psa * (1 - p_psa) / n_psa)     AS se_unpooled
    FROM rates
)
SELECT ROUND(100 * p_ad, 4)                                   AS rate_ad_pct,
       ROUND(100 * p_psa, 4)                                  AS rate_psa_pct,
       ROUND(100 * (p_ad - p_psa), 4)                         AS abs_lift_pp,
       ROUND(100 * (p_ad - p_psa) / p_psa, 2)                 AS rel_lift_pct,
       ROUND((p_ad - p_psa) / se_pooled, 4)                   AS z_stat,
       ROUND(100 * (p_ad - p_psa - 1.959964 * se_unpooled), 4) AS ci95_low_pp,    -- 1.959964 = 97.5th pct of N(0,1)
       ROUND(100 * (p_ad - p_psa + 1.959964 * se_unpooled), 4) AS ci95_high_pp
FROM se;
