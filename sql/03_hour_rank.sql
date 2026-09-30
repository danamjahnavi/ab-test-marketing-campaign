-- 03_hour_rank.sql
-- Conversion rate by the hour with the most ads, ranked within each test group.
-- The share column shows how thin some hours are (a reason the notebook tests dayparts, not hours).
-- EXPLORATORY: most_ads_hour is measured after assignment.

WITH hourly AS (
    SELECT test_group,
           most_ads_hour,
           COUNT(*)                AS users,
           SUM(converted::int)     AS conversions,
           AVG(converted::int)     AS conv_rate
    FROM ab_test
    GROUP BY test_group, most_ads_hour
)
SELECT test_group,
       most_ads_hour,
       users,
       conversions,
       ROUND(100 * conv_rate, 4)                                            AS conv_rate_pct,
       ROUND(100.0 * users / SUM(users) OVER (PARTITION BY test_group), 2)  AS pct_of_group_users,
       RANK() OVER (PARTITION BY test_group ORDER BY conv_rate DESC)        AS rank_in_group
FROM hourly
ORDER BY test_group, rank_in_group;
