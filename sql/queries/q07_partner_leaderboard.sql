-- Q07: Delivery-partner leaderboard - top 3 distinct volume ranks per city (DENSE_RANK)
-- Also ranks the same partners on speed so volume vs. speed trade-offs are visible.
WITH p AS (
    SELECT c.city_name, dp.partner_id, dp.partner_name,
           COUNT(*)                          AS deliveries,
           ROUND(AVG(f.delivery_minutes), 1) AS avg_delivery_min,
           ROUND(AVG(f.rating), 2)           AS avg_rating,
           ROUND(SUM(f.delivery_fee), 0)     AS fee_earned_inr
    FROM food_orders f
    JOIN delivery_partners dp USING (partner_id)
    JOIN cities c ON c.city_id = f.city_id
    WHERE f.status = 'delivered'
    GROUP BY c.city_name, dp.partner_id
),
r AS (
    SELECT *,
           DENSE_RANK() OVER (PARTITION BY city_name ORDER BY deliveries DESC)       AS volume_rank,
           DENSE_RANK() OVER (PARTITION BY city_name ORDER BY avg_delivery_min ASC)  AS speed_rank
    FROM p
)
SELECT city_name, volume_rank, speed_rank, partner_id, partner_name, deliveries, avg_delivery_min, avg_rating, fee_earned_inr
FROM r
WHERE volume_rank <= 3
ORDER BY city_name, volume_rank, partner_id;
