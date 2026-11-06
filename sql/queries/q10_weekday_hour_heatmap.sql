-- Q10: Weekday x hour order-volume grid (feeds the heatmap chart), with each cell's share of its weekday
WITH cells AS (
    SELECT CASE strftime('%w', order_ts) WHEN '0' THEN '7 Sun' WHEN '1' THEN '1 Mon' WHEN '2' THEN '2 Tue'
                                         WHEN '3' THEN '3 Wed' WHEN '4' THEN '4 Thu' WHEN '5' THEN '5 Fri' ELSE '6 Sat' END AS weekday,
           CAST(strftime('%H', order_ts) AS INTEGER) AS hr,
           COUNT(*)                                  AS orders
    FROM food_orders
    GROUP BY weekday, hr
)
SELECT weekday, hr, orders,
       ROUND(100.0 * orders / SUM(orders) OVER (PARTITION BY weekday), 2) AS pct_of_weekday
FROM cells
ORDER BY weekday, hr;
