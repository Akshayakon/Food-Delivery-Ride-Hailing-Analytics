-- Q01: Headline KPIs for both verticals
-- avg_service_min = avg delivery time (food) / avg pickup wait (rides)
SELECT 'Food delivery' AS vertical,
       COUNT(*)                                                            AS total_requests,
       SUM(status = 'delivered')                                           AS completed,
       ROUND(100.0 * SUM(status = 'cancelled') / COUNT(*), 2)              AS cancel_pct,
       ROUND(AVG(CASE WHEN status = 'delivered' THEN delivery_minutes END), 1) AS avg_service_min,
       ROUND(SUM(CASE WHEN status = 'delivered' THEN order_value + delivery_fee END), 0) AS gmv_inr
FROM food_orders
UNION ALL
SELECT 'Ride hailing',
       COUNT(*),
       SUM(status = 'completed'),
       ROUND(100.0 * SUM(status <> 'completed') / COUNT(*), 2),
       ROUND(AVG(pickup_wait_min), 1),
       ROUND(SUM(fare), 0)
FROM rides;
