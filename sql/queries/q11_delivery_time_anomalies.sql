-- Q11: Anomaly detection - city-days whose avg delivery time is > 2 std-dev above the PRIOR 14 days
-- The window excludes the current day (14 PRECEDING .. 1 PRECEDING) so a spike cannot mask itself.
-- Variance = E[x^2] - E[x]^2 (SQLite has no STDDEV); comparing squares avoids needing SQRT.
-- LEFT JOIN to weather tests whether rain explains the spikes.
WITH daily AS (
    SELECT city_id, date(order_ts) AS day, AVG(delivery_minutes) AS m, COUNT(*) AS orders
    FROM food_orders WHERE status = 'delivered'
    GROUP BY city_id, day
),
roll AS (
    SELECT city_id, day, m, orders,
           AVG(m)     OVER w AS mu,
           AVG(m * m) OVER w AS mm,
           COUNT(*)   OVER w AS k
    FROM daily
    WINDOW w AS (PARTITION BY city_id ORDER BY day ROWS BETWEEN 14 PRECEDING AND 1 PRECEDING)
)
SELECT c.city_name, r.day, ROUND(r.m, 1) AS avg_delivery_min, ROUND(r.mu, 1) AS prior_14d_avg,
       ROUND(r.m - r.mu, 1) AS excess_min, r.orders,
       CASE WHEN w.is_rainy = 1 THEN 'rain' ELSE 'dry' END AS weather
FROM roll r
JOIN cities c USING (city_id)
LEFT JOIN weather w ON w.city_id = r.city_id AND w.weather_date = r.day
WHERE r.k >= 7
  AND r.m > r.mu
  AND (r.m - r.mu) * (r.m - r.mu) > 4 * (r.mm - r.mu * r.mu)
ORDER BY excess_min DESC;
