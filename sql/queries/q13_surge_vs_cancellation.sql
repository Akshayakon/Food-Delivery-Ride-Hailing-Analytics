-- Q13: Does surge pricing hurt conversion? Cancellations, wait and fare by surge bucket, and by rain vs dry
SELECT CASE WHEN w.is_rainy = 1 THEN 'rain' ELSE 'dry' END AS weather,
       CASE WHEN r.surge_multiplier < 1.25 THEN '1.00-1.24x'
            WHEN r.surge_multiplier < 1.5  THEN '1.25-1.49x'
            WHEN r.surge_multiplier < 2.0  THEN '1.50-1.99x'
            ELSE '2.00x+' END                                              AS surge_bucket,
       COUNT(*)                                                            AS requests,
       ROUND(100.0 * SUM(r.status = 'completed') / COUNT(*), 1)            AS completion_pct,
       ROUND(100.0 * SUM(r.status = 'cancelled_by_driver') / COUNT(*), 1)  AS driver_cancel_pct,
       ROUND(100.0 * SUM(r.status = 'cancelled_by_rider') / COUNT(*), 1)   AS rider_cancel_pct,
       ROUND(AVG(r.pickup_wait_min), 1)                                    AS avg_wait_min,
       ROUND(AVG(r.fare), 0)                                               AS avg_fare_inr,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY w.is_rainy), 1) AS pct_of_weather_requests
FROM rides r
JOIN weather w ON w.city_id = r.city_id AND w.weather_date = date(r.request_ts)
GROUP BY weather, surge_bucket
ORDER BY weather, surge_bucket;
