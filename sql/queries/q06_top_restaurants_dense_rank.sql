-- Q06: Top restaurants per city by delivered-order count using DENSE_RANK
-- DENSE_RANK keeps every restaurant tied on a rank (so a city can show >3 rows) and never skips ranks,
-- unlike RANK (gaps) or ROW_NUMBER (arbitrary tie-break).
WITH rest AS (
    SELECT c.city_name, r.restaurant_name, r.cuisine,
           COUNT(*)                          AS delivered_orders,
           ROUND(SUM(f.order_value), 0)      AS revenue_inr,
           ROUND(AVG(f.delivery_minutes), 1) AS avg_delivery_min,
           ROUND(AVG(f.rating), 2)           AS avg_rating,
           r.restaurant_id
    FROM food_orders f
    JOIN restaurants r USING (restaurant_id)
    JOIN cities c ON c.city_id = f.city_id
    WHERE f.status = 'delivered'
    GROUP BY c.city_name, r.restaurant_id
),
ranked AS (
    SELECT *, DENSE_RANK() OVER (PARTITION BY city_name ORDER BY delivered_orders DESC) AS city_rank
    FROM rest
)
SELECT city_name, city_rank, restaurant_name, cuisine, delivered_orders, revenue_inr, avg_delivery_min, avg_rating
FROM ranked
WHERE city_rank <= 3
ORDER BY city_name, city_rank, restaurant_name;
