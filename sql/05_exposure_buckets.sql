-- 05_exposure_buckets.sql
-- Lift by exposure bucket (total ads seen). Buckets match the notebook: 1-5, 6-20, 21-50, 51+.
-- EXPLORATORY and NOT CAUSAL: exposure was not randomized within each group, so a bigger lift
-- among heavily exposed users is an association (they may simply be more active users).

WITH bucketed AS (
    SELECT test_group,
           converted,
           CASE WHEN total_ads <= 5  THEN '1-5'
                WHEN total_ads <= 20 THEN '6-20'
                WHEN total_ads <= 50 THEN '21-50'
                ELSE '51+' END                                  AS ads_bucket,
           CASE WHEN total_ads <= 5  THEN 1
                WHEN total_ads <= 20 THEN 2
                WHEN total_ads <= 50 THEN 3
                ELSE 4 END                                      AS bucket_order
    FROM ab_test
),
agg AS (
    SELECT ads_bucket, bucket_order,
           COUNT(*)                         FILTER (WHERE test_group = 'ad')  AS users_ad,
           COUNT(*)                         FILTER (WHERE test_group = 'psa') AS users_psa,
           AVG(converted::int)              FILTER (WHERE test_group = 'ad')  AS rate_ad,
           AVG(converted::int)              FILTER (WHERE test_group = 'psa') AS rate_psa
    FROM bucketed
    GROUP BY ads_bucket, bucket_order
)
SELECT ads_bucket,
       users_ad,
       users_psa,
       ROUND(100.0 * (users_ad + users_psa) / SUM(users_ad + users_psa) OVER (), 2)  AS pct_of_all_users,
       ROUND(100 * rate_ad, 4)                                                      AS rate_ad_pct,
       ROUND(100 * rate_psa, 4)                                                     AS rate_psa_pct,
       ROUND(100 * (rate_ad - rate_psa), 4)                                         AS abs_lift_pp,
       ROUND(100.0 * SUM(users_ad + users_psa) OVER (ORDER BY bucket_order)
                   / SUM(users_ad + users_psa) OVER (), 2)                         AS cumulative_pct_users
FROM agg
ORDER BY bucket_order;
