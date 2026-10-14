-- TelcoDB: Mobile Subscriber & Usage Analytics
-- FICTIONAL, synthetic data. Not affiliated with any real operator.
-- Built by build_db.py (do not run by hand unless you also load data).

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS usage_records;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS plans;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
  customer_id INTEGER PRIMARY KEY,
  full_name   TEXT NOT NULL,
  city        TEXT,                                   -- NULL = unknown
  signup_date TEXT NOT NULL
              CHECK (signup_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  segment     TEXT NOT NULL CHECK (segment IN ('consumer', 'business'))
);

CREATE TABLE plans (
  plan_id     INTEGER PRIMARY KEY,
  plan_name   TEXT NOT NULL UNIQUE,
  monthly_fee REAL NOT NULL CHECK (monthly_fee >= 0),  -- TRY
  data_gb     INTEGER NOT NULL CHECK (data_gb >= 0),
  minutes     INTEGER NOT NULL CHECK (minutes >= 0),
  plan_type   TEXT NOT NULL CHECK (plan_type IN ('prepaid', 'postpaid'))
);

CREATE TABLE subscriptions (
  sub_id       INTEGER PRIMARY KEY,
  customer_id  INTEGER NOT NULL REFERENCES customers(customer_id),
  plan_id      INTEGER NOT NULL REFERENCES plans(plan_id),
  msisdn       TEXT NOT NULL UNIQUE,                   -- the phone number
  activated_on TEXT NOT NULL
               CHECK (activated_on GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  status       TEXT NOT NULL CHECK (status IN ('active', 'suspended', 'cancelled')),
  cancelled_on TEXT,                                   -- NULL unless cancelled
  CHECK ((status = 'cancelled') = (cancelled_on IS NOT NULL)),
  CHECK (cancelled_on IS NULL OR cancelled_on >= activated_on)
);

CREATE TABLE usage_records (
  usage_id   INTEGER PRIMARY KEY,
  sub_id     INTEGER NOT NULL REFERENCES subscriptions(sub_id),
  usage_date TEXT NOT NULL
             CHECK (usage_date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'),
  kind       TEXT NOT NULL CHECK (kind IN ('call', 'sms', 'data')),  -- minutes / count / MB
  quantity   REAL NOT NULL CHECK (quantity >= 0)
);
