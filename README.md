# Food Delivery & Ride-Hailing Analytics (India)

An end-to-end SQL analytics project modelled on Swiggy / Zomato / Uber / Ola operations across six metros
(Bengaluru, Mumbai, Delhi NCR, Hyderabad, Chennai, Pune), Q1 2026 (90 days).

**Skills demonstrated:** time-series analysis · peak-hour analysis · delivery-time metrics (mean / p50 / p90 / SLA) ·
rolling averages · `DENSE_RANK` leaderboards · `LAG` growth · anomaly detection with window frames · CTEs · joins.

> The data is **synthetic** (`generate_data.py`, seeded, reproducible) with realistic patterns deliberately built in
> (lunch/dinner and commute peaks, weekend lift, rain effects, city traffic, partner productivity).
> Findings below are properties of that simulated data, not real company figures.

## Run it

```bash
pip install pandas numpy matplotlib
python run_pipeline.py     # generates data -> builds food_ride.db (SQLite) -> runs 14 queries -> saves CSVs + charts
```

Needs Python 3.9+ and SQLite 3.25+ (window functions). Every query can also be run on its own against `food_ride.db`.

## Project layout

| Path | What it is |
|---|---|
| `generate_data.py` | Synthetic data generator -> `data/*.csv` (80k food orders, 49k rides, 240 restaurants, 360 partners, 600 drivers, daily weather) |
| `sql/schema.sql` | Tables, constraints, indexes |
| `sql/queries/q01…q14*.sql` | The analysis, one commented query per file |
| `run_pipeline.py` | Loads the DB, runs every query, writes `outputs/*.csv`, draws `outputs/charts/*.png` |
| `food_ride.db` | Resulting SQLite database |

## Queries and the SQL technique each one shows

| # | Question | Technique |
|---|---|---|
| 01 | Headline KPIs, both verticals | `UNION ALL`, conditional aggregates |
| 02 | Which hours are peak for food? | `DENSE_RANK() OVER (ORDER BY orders DESC)`, cumulative share |
| 03 | Daily trend, smoothed | 7-day rolling `AVG` (`ROWS BETWEEN 6 PRECEDING`), `LAG(…,7)` week-over-week |
| 04 | Delivery time per city | Manual p50/p90 via `ROW_NUMBER` (SQLite has no percentile), SLA %, `DENSE_RANK` |
| 05 | Peak vs off-peak penalty | Daypart `CASE`, window total per city |
| 06 | Top restaurants per city | `DENSE_RANK() OVER (PARTITION BY city …)` |
| 07 | Delivery-partner leaderboard | Two `DENSE_RANK`s (volume vs speed) |
| 08 | Ride demand by hour | Centred 3-hour rolling avg, `DENSE_RANK` peak flag |
| 09 | Top drivers per vehicle type | `DENSE_RANK … PARTITION BY vehicle_type` |
| 10 | Weekday x hour heatmap | Pre-aggregated CTE + `SUM() OVER (PARTITION BY …)` |
| 11 | Anomalous delivery days | Prior-14-day window excluding today, variance as `E[x²]−E[x]²` |
| 12 | Month-over-month growth by city | `LAG`, share-of-total window |
| 13 | Does surge hurt completion? | Bucketing + join to weather |
| 14 | Rain impact on delivery | Join, `LAG` over aggregate |

## Key findings

**Scale.** 79,992 food orders (3.0% cancelled, ₹2.96 crore GMV, 32.6 min average delivery) and
48,767 ride requests (15.2% not completed, ₹70 lakh fares, 5.9 min average pickup wait).

**1. Demand is highly concentrated** (Q02, chart 01). Five hours, 12-13 and 19-21, carry **46% of all food orders**.
Lunch and dinner hours 14 and 22 fall just outside the top five by volume, which is why the DENSE_RANK cut-off matters:
rank-based peak definitions should be validated against the business "rush" windows.

**2. Peak hours cost ~6 minutes.** Average delivery is **35 min in lunch/dinner rush vs ~29 min otherwise**,
and cancellations rise from ~2.4-2.7% to ~3.5% (Q05). Peak-hour partner supply and kitchen prep time are the levers.

**3. City gap.** Bengaluru is slowest (34.3 min avg, p90 46.8, only **36% within 30 min**), Chennai fastest
(30.9 min, 51% within 30). Bengaluru and Mumbai also have the most orders over 45 minutes (12.7% and 10.9%) (Q04).

**4. Rain is the main source of bad days** (Q11, Q14). 40 of the 43 flagged anomaly city-days are rainy.
Rain adds **3-4 minutes** to delivery in every city and lifts cancellations by 0.4-1.3 points, while order volume rises 3-15%.

**5. Steady growth with a weekly cycle** (Q03, chart 02). The 7-day rolling average rises from ~770 to ~1,025 orders/day;
weekends run ~18% above weekdays, so week-over-week (`LAG 7`) is the right comparison, not day-over-day.
March's +20% month-over-month (Q12) is partly 31 vs 28 days, so use orders/day when reporting growth.

**6. Ride supply is strained at commute peaks** (Q08, chart 05). Hours 8-9 and 17-19 average **1.39x surge** (vs 1.07x off-peak),
longer waits (7.1 vs 5.1 min) and **~20% unfulfilled requests vs ~12%**.

**7. Surge trades completion for price** (Q13, chart 06). On dry days completion falls from **88.3% to 80.8%** between the
lowest and 1.5-1.99x surge buckets as driver cancellations rise from 4.2% to 7.2%. In rain, 1.5x+ surge covers over half of requests
and completion drops to ~77%.

**8. Volume leaders are not speed leaders** (Q07). In Bengaluru the top partner by deliveries (894) ranks 22nd on speed:
raw throughput hides quality, so leaderboards need both ranks.

## Recommendations

1. Pre-position partners and add kitchen-prep SLAs for 12-14h and 19-22h; target the Bengaluru and Mumbai rush.
2. Add a rain trigger (forecast-driven) for partner incentives and customer ETA padding.
3. Cap or smooth surge above 1.5x during commute peaks, or add driver incentives, since driver cancellations climb with surge.
4. Report growth as 7-day rolling and orders/day, not raw month totals.

## Notes and limitations

- Percentiles are exact (row-picking), not interpolated.
- The rolling-average window has fewer than 7 days for the first six days; `window_days` flags this and charts skip it.
- SQLite is used for portability; the same queries run on PostgreSQL with minor changes (`date()`/`strftime` -> `DATE_TRUNC`/`EXTRACT`,
  `PERCENTILE_CONT` for percentiles).
