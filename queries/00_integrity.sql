-- 00_integrity.sql: data-quality checks for TelcoDB (fictional data)
-- Every check below should return 0 rows. The constraints in schema.sql already block
-- bad data, and these queries prove it.

-- Q: Are there subscriptions that point to a customer who does not exist?
-- Technique: LEFT JOIN anti-join (keep rows with no match)
-- Expected rows: 0
SELECT subscriptions.sub_id, subscriptions.customer_id
FROM subscriptions
LEFT JOIN customers ON customers.customer_id = subscriptions.customer_id
WHERE customers.customer_id IS NULL;

-- Q: Are there subscriptions that point to a plan that does not exist?
-- Technique: LEFT JOIN anti-join
-- Expected rows: 0
SELECT subscriptions.sub_id, subscriptions.plan_id
FROM subscriptions
LEFT JOIN plans ON plans.plan_id = subscriptions.plan_id
WHERE plans.plan_id IS NULL;

-- Q: Are there usage records that point to a subscription that does not exist?
-- Technique: LEFT JOIN anti-join
-- Expected rows: 0
SELECT usage_records.usage_id, usage_records.sub_id
FROM usage_records
LEFT JOIN subscriptions ON subscriptions.sub_id = usage_records.sub_id
WHERE subscriptions.sub_id IS NULL;

-- Q: Is any phone number used by more than one subscription?
-- Technique: GROUP BY + HAVING
-- Expected rows: 0
SELECT msisdn, COUNT(*) AS times_used
FROM subscriptions
GROUP BY msisdn
HAVING COUNT(*) > 1;

-- Q: Are there look-alike customers (same name, city and signup date)?
-- Technique: GROUP BY + HAVING on several columns
-- Expected rows: 0
SELECT full_name, city, signup_date, COUNT(*) AS times_recorded
FROM customers
GROUP BY full_name, city, signup_date
HAVING COUNT(*) > 1;

-- Q: Is there usage dated before the line was activated?
-- Technique: INNER JOIN + date comparison
-- Expected rows: 0
SELECT usage_records.usage_id, usage_records.usage_date, subscriptions.activated_on
FROM usage_records
JOIN subscriptions ON subscriptions.sub_id = usage_records.sub_id
WHERE usage_records.usage_date < subscriptions.activated_on;

-- Q: Is there usage dated after the line was cancelled?
-- Technique: INNER JOIN + date comparison (cancelled_on is NULL for most lines)
-- Expected rows: 0
SELECT usage_records.usage_id, usage_records.usage_date, subscriptions.cancelled_on
FROM usage_records
JOIN subscriptions ON subscriptions.sub_id = usage_records.sub_id
WHERE subscriptions.cancelled_on IS NOT NULL
  AND usage_records.usage_date > subscriptions.cancelled_on;

-- Q: Does SQLite itself report any foreign key violation?
-- Technique: PRAGMA foreign_key_check (returns nothing when clean)
-- Expected rows: 0
PRAGMA foreign_key_check;
