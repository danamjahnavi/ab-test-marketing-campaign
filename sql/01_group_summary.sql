-- 01_group_summary.sql
-- Primary KPI table: users, conversions and conversion rate per test group,
-- plus each group's share of all users (a window function over the grouped rows).
-- Expected to match the pandas group summary in notebooks/01_ab_test.ipynb.

WITH grp AS (
    SELECT test_group,
           COUNT(*)                AS users,
           SUM(converted::int)     AS conversions      -- boolean -> 0/1, then sum
    FROM ab_test
    GROUP BY test_group
)
SELECT test_group,
       users,
       conversions,
       ROUND(100.0 * conversions / users, 4)             AS conversion_rate_pct,
       ROUND(100.0 * users / SUM(users) OVER (), 2)      AS pct_of_all_users   -- share of the grand total
FROM grp
ORDER BY test_group;
