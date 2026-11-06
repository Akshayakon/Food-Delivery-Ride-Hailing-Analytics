"""Generate a realistic synthetic dataset for Indian food delivery + ride hailing.

Patterns baked in (so the analysis has real signal to find):
  * lunch (12-14h) and dinner (19-22h) peaks for food; office-commute peaks for rides
  * weekend lift, slow growth over the quarter
  * rainy days: more demand, slower delivery, higher surge, more cancellations
  * peak hours slow down delivery and raise cancellations
  * city-specific traffic; per-partner / per-driver productivity differences
Run:  python generate_data.py   ->  data/*.csv
"""
from pathlib import Path
import numpy as np
import pandas as pd

SEED = 42
START = pd.Timestamp("2026-01-01")
DAYS = 90
OUT = Path(__file__).parent / "data"

CITIES = [  # id, name, demand weight, traffic factor (>1 = slower)
    (1, "Bengaluru", 1.00, 1.25), (2, "Mumbai", 0.95, 1.20), (3, "Delhi NCR", 1.00, 1.10),
    (4, "Hyderabad", 0.70, 1.00), (5, "Chennai", 0.55, 1.00), (6, "Pune", 0.50, 0.95),
]
CUISINES = ["North Indian", "South Indian", "Biryani", "Chinese", "Pizza", "Burgers", "Desserts", "Healthy", "Street Food"]
NAME_A = ["Spice", "Tandoor", "Curry", "Dosa", "Biryani", "Wok", "Slice", "Chaat", "Royal", "Urban", "Mumbai", "Madras", "Punjabi", "Green", "Golden"]
NAME_B = ["House", "Junction", "Kitchen", "Express", "Corner", "Palace", "Hub", "Bhavan", "Point", "Dhaba"]
FIRST = ["Aarav", "Vivaan", "Aditya", "Rohan", "Karthik", "Suresh", "Imran", "Manoj", "Deepak", "Ravi", "Arjun", "Sanjay", "Faisal", "Vikram", "Naveen", "Prakash"]
LAST = ["Sharma", "Reddy", "Iyer", "Khan", "Patil", "Singh", "Nair", "Kumar", "Das", "Yadav", "Gupta", "Naidu"]
VEHICLES = ["bike", "auto", "cab_mini", "cab_sedan"]
VEHICLE_P = [0.30, 0.30, 0.28, 0.12]

FOOD_HOURS = np.array([1.5, .8, .4, .2, .2, .3, .8, 2, 3, 3.5, 4, 6, 10, 10, 6, 4.5, 4.5, 5.5, 7.5, 10.5, 11.5, 10, 6.5, 3.5])
RIDE_HOURS = np.array([2, 1.2, .8, .8, 1.2, 2.5, 4.5, 8, 10.5, 9, 6, 5.5, 5.5, 5, 5, 5.5, 7, 9.5, 11, 9.5, 7, 5.5, 4.5, 3.2])
FOOD_PEAK = np.isin(np.arange(24), [12, 13, 14, 19, 20, 21, 22])
RIDE_PEAK = np.isin(np.arange(24), [8, 9, 17, 18, 19])


def norm(x):
    return x / x.sum()


def weekend_food():
    w = FOOD_HOURS.copy()
    w[11:16] *= 1.3
    return norm(w)


def make_masters(rng):
    cities = pd.DataFrame(CITIES, columns=["city_id", "city_name", "demand_weight", "traffic_factor"])
    rest, part, drv = [], [], []
    for c in cities.itertuples():
        for _ in range(40):
            rest.append((c.city_id, f"{rng.choice(NAME_A)} {rng.choice(NAME_B)}", rng.choice(CUISINES), round(float(rng.uniform(6, 14)), 1)))
        for _ in range(60):
            part.append((c.city_id, f"{rng.choice(FIRST)} {rng.choice(LAST)}"))
        for _ in range(100):
            drv.append((c.city_id, f"{rng.choice(FIRST)} {rng.choice(LAST)}", rng.choice(VEHICLES, p=VEHICLE_P)))
    restaurants = pd.DataFrame(rest, columns=["city_id", "restaurant_name", "cuisine", "base_prep_min"])
    restaurants.insert(0, "restaurant_id", range(1, len(restaurants) + 1))
    partners = pd.DataFrame(part, columns=["city_id", "partner_name"])
    partners.insert(0, "partner_id", range(1, len(partners) + 1))
    drivers = pd.DataFrame(drv, columns=["city_id", "driver_name", "vehicle_type"])
    drivers.insert(0, "driver_id", range(1, len(drivers) + 1))
    # latent traits (not exported): popularity / productivity / speed
    restaurants["_pop"] = rng.lognormal(0, 0.9, len(restaurants))
    partners["_prod"] = rng.lognormal(0, 0.5, len(partners))
    partners["_speed"] = rng.normal(1.0, 0.08, len(partners)).clip(0.8, 1.2)
    drivers["_prod"] = rng.lognormal(0, 0.5, len(drivers))
    return cities, restaurants, partners, drivers


def make_weather(rng, cities):
    rows = [(c, (START + pd.Timedelta(days=d)).strftime("%Y-%m-%d"), int(rng.random() < 0.13))
            for c in cities.city_id for d in range(DAYS)]
    return pd.DataFrame(rows, columns=["city_id", "weather_date", "is_rainy"])


def sample_skeleton(rng, cities, weather, base, hour_w_fn, growth):
    """Per (day, city): number of events and their timestamps."""
    rain = {(r.city_id, r.weather_date): r.is_rainy for r in weather.itertuples()}
    parts = []
    for d in range(DAYS):
        date = START + pd.Timedelta(days=d)
        wk = date.dayofweek >= 5
        for c in cities.itertuples():
            r = rain[(c.city_id, date.strftime("%Y-%m-%d"))]
            lam = base * c.demand_weight * (1.18 if wk else 1.0) * (1 + growth * d) * (1.12 if r else 1.0)
            n = rng.poisson(lam)
            hours = rng.choice(24, n, p=hour_w_fn(wk))
            ts = date + pd.to_timedelta(hours * 3600 + rng.integers(0, 3600, n), unit="s")
            parts.append(pd.DataFrame({"city_id": c.city_id, "order_ts": ts, "hour": hours, "rain": r}))
    return pd.concat(parts, ignore_index=True).sort_values("order_ts", kind="stable").reset_index(drop=True)


def gen_food(rng, cities, restaurants, partners, weather):
    df = sample_skeleton(rng, cities, weather, 150, lambda wk: weekend_food() if wk else norm(FOOD_HOURS), 0.004)
    n = len(df)
    tf = df.city_id.map(cities.set_index("city_id").traffic_factor).to_numpy()
    peak = FOOD_PEAK[df.hour.to_numpy()]
    rain = df.rain.to_numpy().astype(bool)

    rest_id = np.empty(n, int)
    part_id = np.empty(n, int)
    for c in cities.city_id:
        idx = np.where(df.city_id.to_numpy() == c)[0]
        rc = restaurants[restaurants.city_id == c]
        pc = partners[partners.city_id == c]
        rest_id[idx] = rng.choice(rc.restaurant_id, len(idx), p=norm(rc._pop.to_numpy()))
        part_id[idx] = rng.choice(pc.partner_id, len(idx), p=norm(pc._prod.to_numpy()))
    base_prep = restaurants.set_index("restaurant_id").base_prep_min.reindex(rest_id).to_numpy()
    pspeed = partners.set_index("partner_id")._speed.reindex(part_id).to_numpy()

    dist = rng.gamma(3.0, 1.1, n).clip(0.5, 12)
    speed = 22 / tf * np.where(peak, 0.85, 1.0) * np.where(rain, 0.8, 1.0) * pspeed
    travel = dist / speed * 60
    prep = base_prep * np.where(peak, 1.3, 1.0) * rng.lognormal(0, 0.2, n)
    assign = rng.exponential(2.0 * np.where(peak, 1.6, 1.0) * np.where(rain, 1.3, 1.0))
    dm = assign + prep + rng.uniform(3, 6, n) + travel + 2
    cancel = rng.random(n) < np.minimum(0.02 + 0.004 * np.maximum(0, dm - 35), 0.3)
    value = rng.lognormal(5.7, 0.5, n).round(0)
    fee = (20 + 5 * dist + np.where(rain, 15, 0) + np.where(peak, 8, 0)).round(0)
    rating = np.clip(np.round(4.5 - 0.05 * np.maximum(0, dm - 30) + rng.normal(0, 0.8, n)), 1, 5)
    rated = rng.random(n) < 0.6

    out = pd.DataFrame({
        "order_id": np.arange(1, n + 1), "city_id": df.city_id, "restaurant_id": rest_id, "partner_id": part_id,
        "order_ts": df.order_ts.dt.strftime("%Y-%m-%d %H:%M:%S"),
        "delivered_ts": (df.order_ts + pd.to_timedelta(dm * 60, unit="s")).dt.strftime("%Y-%m-%d %H:%M:%S"),
        "prep_minutes": prep.round(1), "delivery_minutes": dm.round(1), "distance_km": dist.round(2),
        "order_value": value, "delivery_fee": fee, "status": np.where(cancel, "cancelled", "delivered"),
        "rating": pd.array(np.where(rated & ~cancel, rating, np.nan), dtype="Int64"),
    })
    out.loc[cancel, ["delivered_ts", "prep_minutes", "delivery_minutes"]] = np.nan
    return out


def gen_rides(rng, cities, drivers, weather):
    df = sample_skeleton(rng, cities, weather, 95, lambda wk: norm(RIDE_HOURS), 0.003)
    n = len(df)
    tf = df.city_id.map(cities.set_index("city_id").traffic_factor).to_numpy()
    peak = RIDE_PEAK[df.hour.to_numpy()]
    rain = df.rain.to_numpy().astype(bool)
    vt = rng.choice(VEHICLES, n, p=VEHICLE_P)

    drv_id = np.zeros(n, int)
    cc = df.city_id.to_numpy()
    for c in cities.city_id:
        for v in VEHICLES:
            idx = np.where((cc == c) & (vt == v))[0]
            dg = drivers[(drivers.city_id == c) & (drivers.vehicle_type == v)]
            drv_id[idx] = rng.choice(dg.driver_id, len(idx), p=norm(dg._prod.to_numpy()))

    dist = rng.gamma(2.5, 2.6, n).clip(0.8, 35)
    speed = 24 / tf * np.where(peak, 0.75, 1.0) * np.where(rain, 0.8, 1.0)
    trip = dist / speed * 60 + rng.uniform(1, 4, n)
    surge = 1 + 0.35 * peak + 0.3 * rain + rng.normal(0, 0.12, n)
    surge = np.clip(np.round(surge * 4) / 4, 1.0, 2.5)
    base = pd.Series(vt).map({"bike": 20, "auto": 30, "cab_mini": 50, "cab_sedan": 60}).to_numpy()
    perkm = pd.Series(vt).map({"bike": 6, "auto": 11, "cab_mini": 13, "cab_sedan": 17}).to_numpy()
    fare = ((base + perkm * dist + 1.5 * trip) * surge).round(0)
    wait = rng.exponential(4.0 * np.where(peak, 1.5, 1.0) * np.where(rain, 1.3, 1.0)) + 1

    u = rng.random(n)
    p_nodrv = 0.03 + 0.04 * peak + 0.03 * rain
    p_rider = 0.03 + 0.01 * np.maximum(0, wait - 6)
    p_driver = 0.04 + 0.03 * peak + 0.03 * (surge > 1.5)
    status = np.where(u < p_nodrv, "no_driver_found",
             np.where(u < p_nodrv + p_rider, "cancelled_by_rider",
             np.where(u < p_nodrv + p_rider + p_driver, "cancelled_by_driver", "completed")))
    done = status == "completed"
    nodrv = status == "no_driver_found"
    rating = np.clip(np.round(4.6 - 0.04 * np.maximum(0, wait - 5) + rng.normal(0, 0.7, n)), 1, 5)
    rated = rng.random(n) < 0.5

    return pd.DataFrame({
        "ride_id": np.arange(1, n + 1), "city_id": df.city_id,
        "driver_id": pd.array(np.where(nodrv, np.nan, drv_id), dtype="Int64"),
        "request_ts": df.order_ts.dt.strftime("%Y-%m-%d %H:%M:%S"), "vehicle_type": vt,
        "distance_km": dist.round(2), "surge_multiplier": surge,
        "pickup_wait_min": np.where(nodrv, np.nan, wait).round(1),
        "trip_minutes": np.where(done, trip, np.nan).round(1), "fare": np.where(done, fare, np.nan),
        "status": status, "rating": pd.array(np.where(done & rated, rating, np.nan), dtype="Int64"),
    })


def main():
    rng = np.random.default_rng(SEED)
    OUT.mkdir(exist_ok=True)
    cities, restaurants, partners, drivers = make_masters(rng)
    weather = make_weather(rng, cities)
    food = gen_food(rng, cities, restaurants, partners, weather)
    rides = gen_rides(rng, cities, drivers, weather)
    tables = {
        "cities": cities, "weather": weather, "food_orders": food, "rides": rides,
        "restaurants": restaurants.drop(columns="_pop"),
        "delivery_partners": partners.drop(columns=["_prod", "_speed"]),
        "drivers": drivers.drop(columns="_prod"),
    }
    for name, t in tables.items():
        t.to_csv(OUT / f"{name}.csv", index=False)
        print(f"{name:18s} {len(t):>7,} rows")


if __name__ == "__main__":
    main()
