"""End-to-end pipeline: generate data -> load SQLite -> run every SQL query -> save CSVs -> draw charts.

    python run_pipeline.py
"""
import sqlite3
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

import generate_data

ROOT = Path(__file__).parent
DB = ROOT / "food_ride.db"
QUERIES = sorted((ROOT / "sql" / "queries").glob("q*.sql"))
RES = ROOT / "outputs"
CHARTS = RES / "charts"

PEAK, BASE, ACC = "#d1495b", "#8fa3b8", "#2e6f95"
plt.rcParams.update({"figure.dpi": 130, "axes.spines.top": False, "axes.spines.right": False,
                     "axes.grid": True, "grid.alpha": 0.25, "font.size": 9})


def build_db():
    generate_data.main()
    DB.unlink(missing_ok=True)
    con = sqlite3.connect(DB)
    con.executescript((ROOT / "sql" / "schema.sql").read_text())
    for t in ["cities", "weather", "restaurants", "delivery_partners", "drivers", "food_orders", "rides"]:
        df = pd.read_csv(ROOT / "data" / f"{t}.csv")
        df.to_sql(t, con, if_exists="append", index=False)
    con.commit()
    return con


def run_queries(con):
    out = {}
    RES.mkdir(exist_ok=True)
    CHARTS.mkdir(exist_ok=True)
    for q in QUERIES:
        df = pd.read_sql_query(q.read_text(), con)
        df.to_csv(RES / f"{q.stem}.csv", index=False)
        out[q.stem[:3]] = df
        print(f"\n=== {q.stem}  ({len(df)} rows) ===")
        print(df.head(12).to_string(index=False))
    return out


def save(fig, name):
    fig.tight_layout()
    fig.savefig(CHARTS / name)
    plt.close(fig)


def charts(r):
    # 1 hourly food demand + delivery time
    d = r["q02"]
    fig, ax = plt.subplots(figsize=(9, 4))
    ax.bar(d.hr, d.orders, color=np.where(d.band == "PEAK", PEAK, BASE))
    ax.set_xlabel("Hour of day"); ax.set_ylabel("Orders"); ax.set_xticks(range(24))
    ax2 = ax.twinx(); ax2.grid(False)
    ax2.plot(d.hr, d.avg_delivery_min, color="black", marker="o", ms=3)
    ax2.set_ylabel("Avg delivery (min)")
    ax.set_title("Food delivery: demand by hour (red = top-5 DENSE_RANK peak hours) and delivery time")
    save(fig, "01_hourly_food_peak.png")

    # 2 daily orders w/ rolling avg
    d = r["q03"]; d["day"] = pd.to_datetime(d.day); w = d[d.window_days == 7]
    fig, (a, b) = plt.subplots(2, 1, figsize=(9, 6), sharex=True)
    a.plot(d.day, d.orders, color=BASE, lw=1, label="Daily")
    a.plot(w.day, w.orders_7d_avg, color=ACC, lw=2.2, label="7-day rolling avg")
    a.set_ylabel("Orders"); a.legend(); a.set_title("Daily order volume")
    b.plot(d.day, d.avg_delivery_min, color=BASE, lw=1, label="Daily")
    b.plot(w.day, w.delivery_min_7d_avg, color=PEAK, lw=2.2, label="7-day rolling avg")
    b.set_ylabel("Avg delivery (min)"); b.legend(); b.set_title("Average delivery time")
    save(fig, "02_daily_rolling_trend.png")

    # 3 city delivery time
    d = r["q04"].sort_values("avg_min"); x = np.arange(len(d))
    fig, ax = plt.subplots(figsize=(9, 4))
    for i, (col, lab, c) in enumerate([("p50_min", "Median", ACC), ("avg_min", "Mean", BASE), ("p90_min", "p90", PEAK)]):
        ax.bar(x + (i - 1) * 0.27, d[col], 0.27, label=lab, color=c)
    ax.axhline(30, ls="--", color="black", lw=0.8); ax.text(len(d) - 0.5, 30.5, "30-min SLA", ha="right", fontsize=8)
    ax.set_xticks(x); ax.set_xticklabels(d.city_name); ax.set_ylabel("Minutes"); ax.legend()
    ax.set_title("Delivery time by city: median, mean and p90")
    save(fig, "03_city_delivery_time.png")

    # 4 heatmap
    d = r["q10"].pivot(index="weekday", columns="hr", values="orders")
    fig, ax = plt.subplots(figsize=(10, 3.6))
    im = ax.imshow(d.values, aspect="auto", cmap="YlOrRd")
    ax.set_yticks(range(len(d))); ax.set_yticklabels([s[2:] for s in d.index])
    ax.set_xticks(range(24)); ax.set_xticklabels(range(24)); ax.grid(False)
    fig.colorbar(im, label="Orders"); ax.set_xlabel("Hour"); ax.set_title("Food orders: weekday x hour")
    save(fig, "04_weekday_hour_heatmap.png")

    # 5 rides hourly
    d = r["q08"]
    fig, ax = plt.subplots(figsize=(9, 4))
    ax.bar(d.hr, d.requests, color=np.where(d.band == "PEAK", PEAK, BASE))
    ax.plot(d.hr, d.requests_3h_avg, color="black", lw=1.2, label="3-hour rolling avg")
    ax.set_xticks(range(24)); ax.set_xlabel("Hour"); ax.set_ylabel("Ride requests"); ax.legend(loc="upper left")
    ax2 = ax.twinx(); ax2.grid(False)
    ax2.plot(d.hr, d.avg_surge, color=ACC, marker="o", ms=3); ax2.set_ylabel("Avg surge (x)", color=ACC)
    ax.set_title("Ride hailing: requests (red = peak), rolling demand and surge by hour")
    save(fig, "05_hourly_rides_surge.png")

    # 6 surge vs completion
    d = r["q13"]
    fig, ax = plt.subplots(figsize=(8, 4))
    for wth, c in [("dry", ACC), ("rain", PEAK)]:
        s = d[d.weather == wth]
        ax.plot(s.surge_bucket, s.completion_pct, marker="o", color=c, label=wth)
    ax.set_ylabel("Completion %"); ax.set_xlabel("Surge bucket"); ax.legend()
    ax.set_title("Ride completion rate by surge bucket")
    save(fig, "06_surge_vs_completion.png")

    # 7 daypart
    d = r["q05"].pivot(index="city_name", columns="daypart", values="avg_delivery_min")
    fig, ax = plt.subplots(figsize=(9, 4)); d.plot.bar(ax=ax, rot=0, width=0.8)
    ax.set_ylabel("Avg delivery (min)"); ax.set_xlabel(""); ax.set_title("Delivery time by daypart and city"); ax.legend(title="")
    save(fig, "07_daypart_city.png")


def main():
    con = build_db()
    res = run_queries(con)
    charts(res)
    print(f"\nDone. DB: {DB.name} | CSVs + charts in {RES}")


if __name__ == "__main__":
    main()
