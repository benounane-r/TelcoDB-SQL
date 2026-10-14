-- 04_window.sql: window functions (fictional data)
-- Data usage is in MB in the table; these queries report GB (MB / 1024).

-- Q: How does monthly data volume change from one month to the next?
-- Technique: LAG() over a month-ordered window (the first month has no previous month, so NULL)
-- Expected rows: 45
WITH monthly AS (
  SELECT substr(usage_date, 1, 7) AS month, SUM(quantity) / 1024.0 AS data_gb
  FROM usage_records
  WHERE kind = 'data'
  GROUP BY substr(usage_date, 1, 7)
)
SELECT month,
       ROUND(data_gb, 1) AS data_gb,
       ROUND(LAG(data_gb) OVER (ORDER BY month), 1) AS prev_month_gb,
       ROUND(data_gb - LAG(data_gb) OVER (ORDER BY month), 1) AS change_gb,
       ROUND(100.0 * (data_gb - LAG(data_gb) OVER (ORDER BY month))
             / LAG(data_gb) OVER (ORDER BY month), 1) AS change_pct
FROM monthly
ORDER BY month;

-- Q: What is the running total of data usage over time?
-- Technique: SUM() OVER with an explicit cumulative frame
-- Expected rows: 45
WITH monthly AS (
  SELECT substr(usage_date, 1, 7) AS month, SUM(quantity) / 1024.0 AS data_gb
  FROM usage_records
  WHERE kind = 'data'
  GROUP BY substr(usage_date, 1, 7)
)
SELECT month,
       ROUND(data_gb, 1) AS data_gb,
       ROUND(SUM(data_gb) OVER (ORDER BY month ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 1)
           AS cumulative_gb
FROM monthly
ORDER BY month;

-- Q: Who are the top 3 data users in each city?
-- Technique: ROW_NUMBER() and RANK() with PARTITION BY city, filtered in an outer query
-- Definition: usage = total data across all of a customer's lines; customers with no data usage are left out
-- Expected rows: 27
WITH customer_data AS (
  SELECT customers.customer_id,
         customers.full_name,
         COALESCE(customers.city, 'Unknown') AS city,
         SUM(usage_records.quantity) AS data_mb
  FROM customers
  JOIN subscriptions ON subscriptions.customer_id = customers.customer_id
  JOIN usage_records ON usage_records.sub_id = subscriptions.sub_id
  WHERE usage_records.kind = 'data'
  GROUP BY customers.customer_id, customers.full_name, COALESCE(customers.city, 'Unknown')
),
ranked AS (
  SELECT city, customer_id, full_name,
         ROUND(data_mb / 1024.0, 2) AS data_gb,
         ROW_NUMBER() OVER (PARTITION BY city ORDER BY data_mb DESC) AS row_num,
         RANK() OVER (PARTITION BY city ORDER BY data_mb DESC) AS rank_in_city
  FROM customer_data
)
SELECT city, row_num, rank_in_city, customer_id, full_name, data_gb
FROM ranked
WHERE row_num <= 3
ORDER BY city, row_num;

-- Q: Who are the most active customers in each city by number of usage records, and how do ties rank?
-- Technique: ROW_NUMBER vs RANK vs DENSE_RANK on a column with many ties
-- Definition: top ranks only (RANK <= 3), so tied customers can push a city above 3 rows
-- Expected rows: 28
WITH customer_activity AS (
  SELECT customers.customer_id,
         customers.full_name,
         COALESCE(customers.city, 'Unknown') AS city,
         COUNT(usage_records.usage_id) AS records
  FROM customers
  JOIN subscriptions ON subscriptions.customer_id = customers.customer_id
  JOIN usage_records ON usage_records.sub_id = subscriptions.sub_id
  GROUP BY customers.customer_id, customers.full_name, COALESCE(customers.city, 'Unknown')
),
ranked AS (
  SELECT city, customer_id, full_name, records,
         ROW_NUMBER() OVER (PARTITION BY city ORDER BY records DESC) AS row_num,
         RANK() OVER (PARTITION BY city ORDER BY records DESC) AS rank_in_city,
         DENSE_RANK() OVER (PARTITION BY city ORDER BY records DESC) AS dense_rank_in_city
  FROM customer_activity
)
SELECT city, row_num, rank_in_city, dense_rank_in_city, customer_id, full_name, records
FROM ranked
WHERE rank_in_city <= 3
ORDER BY city, row_num;
