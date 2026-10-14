-- 01_joins.sql: who has what? (fictional data)

-- Q: How many ACTIVE subscribers does each plan have, including plans with none?
-- Technique: LEFT JOIN from plans, status filter in ON, COUNT on the right-hand key
-- Expected rows: 6
SELECT plans.plan_id, plans.plan_name, COUNT(subscriptions.sub_id) AS active_subscribers
FROM plans
LEFT JOIN subscriptions
       ON subscriptions.plan_id = plans.plan_id
      AND subscriptions.status = 'active'
GROUP BY plans.plan_id, plans.plan_name
ORDER BY active_subscribers DESC, plans.plan_id;

-- Q: Which plans have never had a subscriber?
-- Technique: LEFT JOIN anti-join
-- Expected rows: 1
SELECT plans.plan_id, plans.plan_name
FROM plans
LEFT JOIN subscriptions ON subscriptions.plan_id = plans.plan_id
WHERE subscriptions.sub_id IS NULL;

-- Q: Which customers have no subscription at all?
-- Technique: LEFT JOIN anti-join
-- Expected rows: 100
SELECT customers.customer_id, customers.full_name, customers.city
FROM customers
LEFT JOIN subscriptions ON subscriptions.customer_id = customers.customer_id
WHERE subscriptions.sub_id IS NULL
ORDER BY customers.customer_id;

-- Q: Which customers have no ACTIVE subscription (including those with only cancelled or suspended lines)?
-- Technique: LEFT JOIN with the condition in ON, then IS NULL
-- Expected rows: 194
SELECT customers.customer_id, customers.full_name, customers.city
FROM customers
LEFT JOIN subscriptions
       ON subscriptions.customer_id = customers.customer_id
      AND subscriptions.status = 'active'
WHERE subscriptions.sub_id IS NULL
ORDER BY customers.customer_id;

-- Q: Which customers HAVE lines, but none of them active? (the gap between the two queries above)
-- Technique: INNER JOIN plus a second LEFT JOIN to the same table under another alias
-- Expected rows: 94
SELECT customers.customer_id, customers.full_name, COUNT(all_lines.sub_id) AS lines_total
FROM customers
JOIN subscriptions AS all_lines ON all_lines.customer_id = customers.customer_id
LEFT JOIN subscriptions AS active_lines
       ON active_lines.customer_id = customers.customer_id
      AND active_lines.status = 'active'
WHERE active_lines.sub_id IS NULL
GROUP BY customers.customer_id, customers.full_name
ORDER BY customers.customer_id;

-- Q: List every active line with its customer, city, plan and monthly fee.
-- Technique: three-table INNER JOIN
-- Expected rows: 1233
SELECT subscriptions.sub_id, subscriptions.msisdn, customers.full_name, customers.city,
       plans.plan_name, plans.monthly_fee
FROM subscriptions
JOIN customers ON customers.customer_id = subscriptions.customer_id
JOIN plans ON plans.plan_id = subscriptions.plan_id
WHERE subscriptions.status = 'active'
ORDER BY subscriptions.sub_id;
