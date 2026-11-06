-- Q09: Top earners per vehicle type: DENSE_RANK over earnings within each vehicle_type (top 3 ranks)
WITH e AS (
    SELECT d.vehicle_type, d.driver_id, d.driver_name, c.city_name,
           COUNT(*)                        AS completed_rides,
           ROUND(SUM(r.fare), 0)           AS earnings_inr,
           ROUND(AVG(r.rating), 2)         AS avg_rating
    FROM rides r
    JOIN drivers d USING (driver_id)
    JOIN cities c ON c.city_id = d.city_id
    WHERE r.status = 'completed'
    GROUP BY d.vehicle_type, d.driver_id
),
r AS (
    SELECT *, DENSE_RANK() OVER (PARTITION BY vehicle_type ORDER BY earnings_inr DESC) AS earnings_rank
    FROM e
)
SELECT vehicle_type, earnings_rank, driver_id, driver_name, city_name, completed_rides, earnings_inr, avg_rating
FROM r
WHERE earnings_rank <= 3
ORDER BY vehicle_type, earnings_rank;
