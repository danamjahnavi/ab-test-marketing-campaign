-- 02_lift_by_day.sql
-- Conversion rate for each group by the weekday on which the user saw the most ads,
-- pivoted so ad and PSA sit side by side, with the absolute lift and its rank.
-- EXPLORATORY: most_ads_day is measured after assignment (see README).

WITH daily AS (                                    -- one row per (day, group)
    SELECT most_ads_day,
           test_group,
           COUNT(*)                  AS users,
           AVG(converted::int)       AS conv_rate
    FROM ab_test
    GROUP BY most_ads_day, test_group
),
pivoted AS (                                       -- one row per day, groups as columns
    SELECT most_ads_day,
           MAX(users)     FILTER (WHERE test_group = 'ad')  AS users_ad,
           MAX(users)     FILTER (WHERE test_group = 'psa') AS users_psa,
           MAX(conv_rate) FILTER (WHERE test_group = 'ad')  AS rate_ad,
           MAX(conv_rate) FILTER (WHERE test_group = 'psa') AS rate_psa
    FROM daily
    GROUP BY most_ads_day
)
SELECT most_ads_day,
       users_ad,
       users_psa,
       ROUND(100 * rate_ad, 4)                                 AS rate_ad_pct,
       ROUND(100 * rate_psa, 4)                                AS rate_psa_pct,
       ROUND(100 * (rate_ad - rate_psa), 4)                    AS abs_lift_pp,
       RANK() OVER (ORDER BY rate_ad - rate_psa DESC)          AS lift_rank
FROM pivoted
ORDER BY lift_rank;
