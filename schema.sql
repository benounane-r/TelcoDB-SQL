-- TelcoDB: Mobile Subscriber & Usage Analytics
-- Fictional data. Run with:  .read schema.sql

DROP TABLE IF EXISTS usage_records;
DROP TABLE IF EXISTS subscriptions;
DROP TABLE IF EXISTS plans;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
  customer_id INTEGER PRIMARY KEY,
  full_name TEXT NOT NULL,
  city TEXT,
  signup_date TEXT NOT NULL,
  segment TEXT NOT NULL          -- consumer, business
);

CREATE TABLE plans (
  plan_id INTEGER PRIMARY KEY,
  plan_name TEXT NOT NULL,
  monthly_fee REAL NOT NULL,     -- TRY
  data_gb INTEGER NOT NULL,
  minutes INTEGER NOT NULL,
  plan_type TEXT NOT NULL        -- prepaid, postpaid
);

CREATE TABLE subscriptions (
  sub_id INTEGER PRIMARY KEY,
  customer_id INTEGER NOT NULL REFERENCES customers(customer_id),
  plan_id INTEGER NOT NULL REFERENCES plans(plan_id),
  msisdn TEXT UNIQUE NOT NULL,   -- the phone number
  activated_on TEXT NOT NULL,
  status TEXT NOT NULL           -- active, suspended, cancelled
);

CREATE TABLE usage_records (
  usage_id INTEGER PRIMARY KEY,
  sub_id INTEGER NOT NULL REFERENCES subscriptions(sub_id),
  usage_date TEXT NOT NULL,
  kind TEXT NOT NULL,            -- call (minutes), sms (count), data (MB)
  quantity REAL NOT NULL
);

INSERT INTO customers VALUES
 (1,'Ayşe Demir','Istanbul','2024-03-10','consumer'),
 (2,'Karim Haddad','Ankara','2023-11-02','consumer'),
 (3,'Lina Yıldız','Istanbul','2025-01-15','business'),
 (4,'Omar Kaya','Izmir','2025-06-20','consumer'),
 (5,'Selin Arslan','Bursa','2024-09-05','consumer');

INSERT INTO plans VALUES
 (1,'Starter',250,5,500,'postpaid'),
 (2,'Plus',450,20,1000,'postpaid'),
 (3,'Max',750,60,3000,'postpaid'),
 (4,'Prepaid Lite',100,2,200,'prepaid');

INSERT INTO subscriptions VALUES
 (1,1,2,'+90 500 000 0001','2024-03-10','active'),
 (2,1,4,'+90 500 000 0002','2024-05-01','active'),
 (3,2,1,'+90 500 000 0003','2023-11-02','cancelled'),
 (4,3,3,'+90 500 000 0004','2025-01-15','active'),
 (5,3,3,'+90 500 000 0005','2025-01-15','suspended'),
 (6,4,4,'+90 500 000 0006','2025-06-20','active');

INSERT INTO usage_records VALUES
 (1,1,'2026-09-01','call',12),
 (2,1,'2026-09-01','data',850),
 (3,1,'2026-09-02','sms',5),
 (4,2,'2026-09-02','call',3),
 (5,4,'2026-09-03','data',4200),
 (6,4,'2026-09-03','call',45),
 (7,6,'2026-09-04','data',300),
 (8,1,'2026-09-05','call',30),
 (9,4,'2026-09-06','sms',20),
 (10,3,'2026-08-15','call',8);
