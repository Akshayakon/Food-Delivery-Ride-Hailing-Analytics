-- Q08: Ride-hailing demand by hour: volume, surge, wait time, cancellations, plus 3-hour centred rolling demand
WITH hourly AS (
    SELECT CAST(strftime('%H', request_ts) AS INTEGER)                      AS hr,
           COUNT(*)                                                         AS requests,
           ROUND(AVG(surge_multiplier), 2)                                  AS avg_surge,
           ROUND(AVG(pickup_wait_min), 1)                                   AS avg_pickup_wait_min,
           ROUND(100.0 * SUM(status <> 'completed') / COUNT(*), 2)          AS unfulfilled_pct,
           ROUND(100.0 * SUM(status = 'no_driver_found') / COUNT(*), 2)     AS no_driver_pct
    FROM rides
    GROUP BY hr
)
SELECT hr, requests,
       ROUND(AVG(requests) OVER (ORDER BY hr ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING), 0) AS requests_3h_avg,
       avg_surge, avg_pickup_wait_min, unfulfilled_pct, no_driver_pct,
       DENSE_RANK() OVER (ORDER BY requests DESC)                           AS demand_rank,
       CASE WHEN DENSE_RANK() OVER (ORDER BY requests DESC) <= 5 THEN 'PEAK' ELSE 'off-peak' END AS band
FROM hourly
ORDER BY hr;
