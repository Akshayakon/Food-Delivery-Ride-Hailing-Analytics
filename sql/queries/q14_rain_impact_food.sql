-- Q14: Rain impact on food delivery by city (join to weather): demand per day, delivery time, cancellations
WITH x AS (
    SELECT c.city_name, w.is_rainy, date(f.order_ts) AS day, f.status, f.delivery_minutes
    FROM food_orders f
    JOIN cities c USING (city_id)
    JOIN weather w ON w.city_id = f.city_id AND w.weather_date = date(f.order_ts)
)
SELECT city_name,
       CASE WHEN is_rainy = 1 THEN 'rain' ELSE 'dry' END                   AS weather,
       COUNT(DISTINCT day)                                                 AS days,
       ROUND(1.0 * COUNT(*) / COUNT(DISTINCT day), 0)                      AS orders_per_day,
       ROUND(AVG(delivery_minutes), 1)                                     AS avg_delivery_min,
       ROUND(100.0 * SUM(status = 'cancelled') / COUNT(*), 2)              AS cancel_pct,
       ROUND(AVG(delivery_minutes) - LAG(AVG(delivery_minutes)) OVER (PARTITION BY city_name ORDER BY is_rainy), 1) AS rain_penalty_min
FROM x
GROUP BY city_name, is_rainy
ORDER BY city_name, is_rainy;
