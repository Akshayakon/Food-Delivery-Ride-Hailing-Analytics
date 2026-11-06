-- Q02: Peak-hour analysis for food delivery
-- DENSE_RANK ranks hours by order volume (ties share a rank, no gaps); top 5 distinct volumes = PEAK.
-- Running share via SUM() OVER shows how concentrated demand is.
WITH hourly AS (
    SELECT CAST(strftime('%H', order_ts) AS INTEGER)                        AS hr,
           COUNT(*)                                                         AS orders,
           ROUND(AVG(CASE WHEN status = 'delivered' THEN delivery_minutes END), 1) AS avg_delivery_min,
           ROUND(100.0 * SUM(status = 'cancelled') / COUNT(*), 2)           AS cancel_pct
    FROM food_orders
    GROUP BY hr
)
SELECT hr,
       orders,
       ROUND(100.0 * orders / SUM(orders) OVER (), 2)                       AS pct_of_orders,
       ROUND(100.0 * SUM(orders) OVER (ORDER BY hr) / SUM(orders) OVER (), 1) AS cumulative_pct,
       avg_delivery_min,
       cancel_pct,
       DENSE_RANK() OVER (ORDER BY orders DESC)                             AS demand_rank,
       CASE WHEN DENSE_RANK() OVER (ORDER BY orders DESC) <= 5 THEN 'PEAK' ELSE 'off-peak' END AS band
FROM hourly
ORDER BY hr;
