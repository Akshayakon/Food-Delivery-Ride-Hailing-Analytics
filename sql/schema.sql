-- Food Delivery / Ride-Hailing Analytics: schema (SQLite)
DROP TABLE IF EXISTS food_orders;
DROP TABLE IF EXISTS rides;
DROP TABLE IF EXISTS weather;
DROP TABLE IF EXISTS restaurants;
DROP TABLE IF EXISTS delivery_partners;
DROP TABLE IF EXISTS drivers;
DROP TABLE IF EXISTS cities;

CREATE TABLE cities (
    city_id        INTEGER PRIMARY KEY,
    city_name      TEXT NOT NULL,
    demand_weight  REAL NOT NULL,
    traffic_factor REAL NOT NULL
);

CREATE TABLE restaurants (
    restaurant_id   INTEGER PRIMARY KEY,
    city_id         INTEGER NOT NULL REFERENCES cities(city_id),
    restaurant_name TEXT NOT NULL,
    cuisine         TEXT NOT NULL,
    base_prep_min   REAL NOT NULL
);

CREATE TABLE delivery_partners (
    partner_id   INTEGER PRIMARY KEY,
    city_id      INTEGER NOT NULL REFERENCES cities(city_id),
    partner_name TEXT NOT NULL
);

CREATE TABLE drivers (
    driver_id    INTEGER PRIMARY KEY,
    city_id      INTEGER NOT NULL REFERENCES cities(city_id),
    driver_name  TEXT NOT NULL,
    vehicle_type TEXT NOT NULL CHECK (vehicle_type IN ('bike','auto','cab_mini','cab_sedan'))
);

CREATE TABLE weather (
    city_id      INTEGER NOT NULL REFERENCES cities(city_id),
    weather_date TEXT NOT NULL,            -- YYYY-MM-DD
    is_rainy     INTEGER NOT NULL CHECK (is_rainy IN (0,1)),
    PRIMARY KEY (city_id, weather_date)
);

CREATE TABLE food_orders (
    order_id           INTEGER PRIMARY KEY,
    city_id            INTEGER NOT NULL REFERENCES cities(city_id),
    restaurant_id      INTEGER NOT NULL REFERENCES restaurants(restaurant_id),
    partner_id         INTEGER NOT NULL REFERENCES delivery_partners(partner_id),
    order_ts           TEXT NOT NULL,      -- YYYY-MM-DD HH:MM:SS
    delivered_ts       TEXT,               -- NULL when cancelled
    prep_minutes       REAL,
    delivery_minutes   REAL,               -- order placed -> delivered; NULL when cancelled
    distance_km        REAL NOT NULL,
    order_value        REAL NOT NULL,      -- INR
    delivery_fee       REAL NOT NULL,      -- INR
    status             TEXT NOT NULL CHECK (status IN ('delivered','cancelled')),
    rating             INTEGER             -- 1-5, NULL if not rated
);

CREATE TABLE rides (
    ride_id          INTEGER PRIMARY KEY,
    city_id          INTEGER NOT NULL REFERENCES cities(city_id),
    driver_id        INTEGER REFERENCES drivers(driver_id),  -- NULL when no driver was found
    request_ts       TEXT NOT NULL,
    vehicle_type     TEXT NOT NULL,
    distance_km      REAL NOT NULL,
    surge_multiplier REAL NOT NULL,
    pickup_wait_min  REAL,
    trip_minutes     REAL,
    fare             REAL,                 -- INR, completed rides only
    status           TEXT NOT NULL CHECK (status IN ('completed','cancelled_by_rider','cancelled_by_driver','no_driver_found')),
    rating           INTEGER
);

CREATE INDEX idx_food_ts      ON food_orders(order_ts);
CREATE INDEX idx_food_city    ON food_orders(city_id);
CREATE INDEX idx_food_rest    ON food_orders(restaurant_id);
CREATE INDEX idx_food_partner ON food_orders(partner_id);
CREATE INDEX idx_rides_ts     ON rides(request_ts);
CREATE INDEX idx_rides_city   ON rides(city_id);
CREATE INDEX idx_rides_driver ON rides(driver_id);
