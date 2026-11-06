-- Q05: Delivery performance by daypart and city, with the penalty vs the city's own average
WITH tagged AS (
    SELECT c.city_name,
           CASE WHEN h BETWEEN 12 AND 14 THEN '2 Lunch rush (12-14)'
                WHEN h BETWEEN 19 AND 22 THEN '3 Dinner rush (19-22)'
                WHEN h BETWEEN 0  AND 4  THEN '4 Late night (0-4)'
                ELSE '1 Other' END                                   AS daypart,
           f.status, f.delivery_minutes
    FROM (SELECT *, CAST(strftime('%H', order_ts) AS INTEGER) AS h FROM food_orders) f
    JOIN cities c USING (city_id)
),
agg AS (
    SELECT city_name, daypart,
           COUNT(*)                                                  AS orders,
           ROUND(AVG(delivery_minutes), 1)                           AS avg_delivery_min,
           ROUND(100.0 * SUM(status = 'cancelled') / COUNT(*), 2)    AS cancel_pct,
           SUM(delivery_minutes)                                     AS tot_min,
           SUM(status = 'delivered')                                 AS delivered
    FROM tagged
    GROUP BY city_name, daypart
)
SELECT city_name, SUBSTR(daypart, 3) AS daypart, orders, avg_delivery_min, cancel_pct,
       ROUND(avg_delivery_min - 1.0 * SUM(tot_min) OVER (PARTITION BY city_name)
                                    / SUM(delivered) OVER (PARTITION BY city_name), 1) AS vs_city_avg_min
FROM agg
ORDER BY city_name, daypart;
