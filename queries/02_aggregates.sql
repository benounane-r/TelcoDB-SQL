-- 02_aggregates.sql: GROUP BY, HAVING and aggregate functions (fictional data)

-- Q: What is the average monthly revenue per customer in each city?
-- Technique: two LEFT JOINs, GROUP BY on COALESCE(city), SUM / COUNT(DISTINCT)
-- Definition: revenue = monthly_fee of ACTIVE lines today. Two averages are shown: over all customers
--             in the city (including those with no active line), and over customers who have one.
-- Expected rows: 9
SELECT COALESCE(customers.city, 'Unknown') AS city,
       COUNT(DISTINCT customers.customer_id) AS customers,
       COUNT(DISTINCT subscriptions.customer_id) AS customers_with_active_line,
       ROUND(COALESCE(SUM(plans.monthly_fee), 0) * 1.0 / COUNT(DISTINCT customers.customer_id), 2)
           AS avg_revenue_per_customer,
       ROUND(SUM(plans.monthly_fee) * 1.0 / COUNT(DISTINCT subscriptions.customer_id), 2)
           AS avg_revenue_per_paying_customer
FROM customers
LEFT JOIN subscriptions
       ON subscriptions.customer_id = customers.customer_id
      AND subscriptions.status = 'active'
LEFT JOIN plans ON plans.plan_id = subscriptions.plan_id
GROUP BY COALESCE(customers.city, 'Unknown')
ORDER BY avg_revenue_per_customer DESC;

-- Q: Which customers hold three or more active lines?
-- Technique: GROUP BY + HAVING
-- Expected rows: 84
SELECT customer_id, COUNT(*) AS active_lines
FROM subscriptions
WHERE status = 'active'
GROUP BY customer_id
HAVING COUNT(*) >= 3
ORDER BY active_lines DESC, customer_id;

-- Q: Which lines used more data in September 2026 than their plan includes?
-- Technique: JOIN + GROUP BY + HAVING comparing a SUM with a plan column
-- Definition: allowance in MB = data_gb * 1024; usage_records stores data in MB
-- Expected rows: 60
SELECT usage_records.sub_id,
       plans.plan_name,
       plans.data_gb * 1024 AS allowance_mb,
       ROUND(SUM(usage_records.quantity), 1) AS used_mb
FROM usage_records
JOIN subscriptions ON subscriptions.sub_id = usage_records.sub_id
JOIN plans ON plans.plan_id = subscriptions.plan_id
WHERE usage_records.kind = 'data'
  AND substr(usage_records.usage_date, 1, 7) = '2026-09'
GROUP BY usage_records.sub_id, plans.plan_name, plans.data_gb
HAVING SUM(usage_records.quantity) > plans.data_gb * 1024
ORDER BY SUM(usage_records.quantity) - plans.data_gb * 1024 DESC;

-- Q: What does the usage table contain, by kind (calls in minutes, SMS in count, data in MB)?
-- Technique: GROUP BY with COUNT, SUM, AVG and a conditional count
-- Expected rows: 3
SELECT kind,
       COUNT(*) AS records,
       ROUND(SUM(quantity), 1) AS total_quantity,
       ROUND(AVG(quantity), 2) AS avg_per_record,
       SUM(CASE WHEN quantity = 0 THEN 1 ELSE 0 END) AS zero_usage_rows
FROM usage_records
GROUP BY kind
ORDER BY kind;
