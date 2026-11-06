-- Q04: Delivery-time metrics by city: mean, median (p50), p90 and SLA compliance
-- SQLite has no PERCENTILE, so percentiles are picked with ROW_NUMBER over the sorted times:
--   p50 -> row ceil(0.5n) = (n+1)/2 ;  p90 -> row ceil(0.9n) = (9n+9)/10   (integer division)
WITH ranked AS (
    SELECT c.city_name,
           f.delivery_minutes AS dm,
           ROW_NUMBER() OVER (PARTITION BY f.city_id ORDER BY f.delivery_minutes) AS rn,
           COUNT(*)     OVER (PARTITION BY f.city_id)                             AS n
    FROM food_orders f
    JOIN cities c USING (city_id)
    WHERE f.status = 'delivered'
)
SELECT city_name,
       n                                                    AS delivered_orders,
       ROUND(AVG(dm), 1)                                    AS avg_min,
       MAX(CASE WHEN rn = (n + 1) / 2     THEN dm END)      AS p50_min,
       MAX(CASE WHEN rn = (9 * n + 9) / 10 THEN dm END)     AS p90_min,
       ROUND(100.0 * SUM(dm <= 30) / COUNT(*), 1)           AS pct_within_30min,
       ROUND(100.0 * SUM(dm > 45)  / COUNT(*), 1)           AS pct_over_45min,
       DENSE_RANK() OVER (ORDER BY AVG(dm))                 AS speed_rank_1_fastest
FROM ranked
GROUP BY city_name, n
ORDER BY avg_min;
