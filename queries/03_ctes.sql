-- 03_ctes.sql: common table expressions, including a recursive one (fictional data)
-- Month definitions: the data runs from 2023-01 to 2026-09 (45 months).

-- Q: What is the monthly revenue by customer segment?
-- Technique: recursive CTE to generate a month calendar, then a join to subscriptions
-- Definition: a line is billed for a month if it was active on any day of that month; revenue is its
--             plan's monthly_fee. Suspended lines count as billed, because the data has no suspension date.
-- Expected rows: 90
WITH RECURSIVE months(month_start) AS (
  SELECT '2023-01-01'
  UNION ALL
  SELECT date(month_start, '+1 month') FROM months WHERE month_start < '2026-09-01'
),
billed AS (
  SELECT months.month_start, customers.segment, plans.monthly_fee
  FROM months
  JOIN subscriptions
    ON subscriptions.activated_on < date(months.month_start, '+1 month')
   AND (subscriptions.cancelled_on IS NULL OR subscriptions.cancelled_on >= months.month_start)
  JOIN customers ON customers.customer_id = subscriptions.customer_id
  JOIN plans ON plans.plan_id = subscriptions.plan_id
)
SELECT substr(month_start, 1, 7) AS month,
       segment,
       COUNT(*) AS billed_lines,
       SUM(monthly_fee) AS revenue_try
FROM billed
GROUP BY month_start, segment
ORDER BY month_start, segment;

-- Q: What share of lines cancelled in each month?
-- Technique: recursive CTE + correlated subqueries, NULLIF to avoid dividing by zero
-- Definition: rate = lines cancelled in the month / lines active at the start of the month
--             (a line counts only if it was activated before the month began)
-- Expected rows: 45
WITH RECURSIVE months(month_start) AS (
  SELECT '2023-01-01'
  UNION ALL
  SELECT date(month_start, '+1 month') FROM months WHERE month_start < '2026-09-01'
),
monthly AS (
  SELECT months.month_start,
         (SELECT COUNT(*) FROM subscriptions s
           WHERE s.activated_on < months.month_start
             AND (s.cancelled_on IS NULL OR s.cancelled_on >= months.month_start)) AS active_at_start,
         (SELECT COUNT(*) FROM subscriptions s
           WHERE s.activated_on < months.month_start
             AND s.cancelled_on >= months.month_start
             AND s.cancelled_on < date(months.month_start, '+1 month')) AS cancelled_in_month
  FROM months
)
SELECT substr(month_start, 1, 7) AS month,
       active_at_start,
       cancelled_in_month,
       ROUND(100.0 * cancelled_in_month / NULLIF(active_at_start, 0), 2) AS cancellation_rate_pct
FROM monthly
ORDER BY month_start;

-- Q: For each signup month, how many customers joined and how many still have an active line?
-- Technique: two CTEs joined together (signup-month cohorts)
-- Definition: "still has an active line" = at least one subscription with status 'active' today
-- Expected rows: 45
WITH cohort AS (
  SELECT customer_id, substr(signup_date, 1, 7) AS signup_month
  FROM customers
),
active_customers AS (
  SELECT DISTINCT customer_id
  FROM subscriptions
  WHERE status = 'active'
)
SELECT cohort.signup_month,
       COUNT(*) AS customers,
       COUNT(active_customers.customer_id) AS with_active_line,
       ROUND(100.0 * COUNT(active_customers.customer_id) / COUNT(*), 1) AS pct_with_active_line
FROM cohort
LEFT JOIN active_customers ON active_customers.customer_id = cohort.customer_id
GROUP BY cohort.signup_month
ORDER BY cohort.signup_month;

-- Q: For each plan, in how many line-months did data usage exceed the plan allowance?
-- Technique: two chained CTEs (monthly totals per line, then the allowance comparison)
-- Definition: a line-month counts only if the line has at least one data record that month
-- Expected rows: 5
WITH monthly_data AS (
  SELECT sub_id, substr(usage_date, 1, 7) AS month, SUM(quantity) AS used_mb
  FROM usage_records
  WHERE kind = 'data'
  GROUP BY sub_id, substr(usage_date, 1, 7)
),
with_allowance AS (
  SELECT plans.plan_name, monthly_data.used_mb, plans.data_gb * 1024 AS allowance_mb
  FROM monthly_data
  JOIN subscriptions ON subscriptions.sub_id = monthly_data.sub_id
  JOIN plans ON plans.plan_id = subscriptions.plan_id
)
SELECT plan_name,
       COUNT(*) AS line_months_with_data,
       SUM(CASE WHEN used_mb > allowance_mb THEN 1 ELSE 0 END) AS line_months_over_allowance,
       ROUND(100.0 * SUM(CASE WHEN used_mb > allowance_mb THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_over
FROM with_allowance
GROUP BY plan_name
ORDER BY pct_over DESC;

-- Q: Which 10 lines exceeded their data allowance in the most months?
-- Technique: the same two CTEs, reused for a different summary
-- Expected rows: 10
WITH monthly_data AS (
  SELECT sub_id, substr(usage_date, 1, 7) AS month, SUM(quantity) AS used_mb
  FROM usage_records
  WHERE kind = 'data'
  GROUP BY sub_id, substr(usage_date, 1, 7)
),
with_allowance AS (
  SELECT monthly_data.sub_id, plans.plan_name, monthly_data.used_mb, plans.data_gb * 1024 AS allowance_mb
  FROM monthly_data
  JOIN subscriptions ON subscriptions.sub_id = monthly_data.sub_id
  JOIN plans ON plans.plan_id = subscriptions.plan_id
)
SELECT sub_id,
       plan_name,
       COUNT(*) AS months_over_allowance,
       ROUND(MAX(100.0 * used_mb / allowance_mb), 0) AS worst_month_pct_of_allowance
FROM with_allowance
WHERE used_mb > allowance_mb
GROUP BY sub_id, plan_name
ORDER BY months_over_allowance DESC, sub_id
LIMIT 10;
