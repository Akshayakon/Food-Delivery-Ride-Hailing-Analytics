-- Q12: Month-over-month growth per city for both verticals (LAG), plus city GMV share via window total
WITH m AS (
    SELECT city_id, strftime('%Y-%m', order_ts) AS month,
           COUNT(*) AS orders, SUM(order_value) AS gmv
    FROM food_orders WHERE status = 'delivered'
    GROUP BY city_id, month
)
SELECT c.city_name, m.month, m.orders,
       ROUND(100.0 * (m.orders - LAG(m.orders) OVER w) / LAG(m.orders) OVER w, 1) AS orders_mom_pct,
       ROUND(m.gmv, 0) AS gmv_inr,
       ROUND(100.0 * (m.gmv - LAG(m.gmv) OVER w) / LAG(m.gmv) OVER w, 1)          AS gmv_mom_pct,
       ROUND(100.0 * m.gmv / SUM(m.gmv) OVER (PARTITION BY m.month), 1)           AS share_of_month_gmv_pct
FROM m JOIN cities c USING (city_id)
WINDOW w AS (PARTITION BY m.city_id ORDER BY m.month)
ORDER BY c.city_name, m.month;
