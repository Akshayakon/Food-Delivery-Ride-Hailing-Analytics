-- Q03: Time series - daily orders with 7-day rolling averages and week-over-week change
-- Rolling window = current day + 6 preceding days; window_days < 7 marks the warm-up period.
WITH daily AS (
    SELECT date(order_ts)                                                   AS day,
           COUNT(*)                                                         AS orders,
           ROUND(AVG(CASE WHEN status = 'delivered' THEN delivery_minutes END), 2) AS avg_delivery_min,
           ROUND(SUM(CASE WHEN status = 'delivered' THEN order_value END), 0) AS gmv
    FROM food_orders
    GROUP BY day
)
SELECT day,
       orders,
       ROUND(AVG(orders)           OVER w, 1)                               AS orders_7d_avg,
       avg_delivery_min,
       ROUND(AVG(avg_delivery_min) OVER w, 2)                              AS delivery_min_7d_avg,
       gmv,
       ROUND(AVG(gmv)              OVER w, 0)                               AS gmv_7d_avg,
       COUNT(*)                    OVER w                                   AS window_days,
       LAG(orders, 7) OVER (ORDER BY day)                                   AS orders_same_day_last_week,
       ROUND(100.0 * (orders - LAG(orders, 7) OVER (ORDER BY day))
             / LAG(orders, 7) OVER (ORDER BY day), 1)                      AS wow_pct
FROM daily
WINDOW w AS (ORDER BY day ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
ORDER BY day;
