-- Keep source CSV files in local data/ when using this SQL script independently.
CREATE OR REPLACE VIEW orders AS
SELECT * FROM read_csv_auto('data/olist_orders_dataset.csv', header=true);
CREATE OR REPLACE VIEW customers AS
SELECT * FROM read_csv_auto('data/olist_customers_dataset.csv', header=true);

-- ===============================================================
-- Lesson 4: Customer Cohort & Monthly Retention (Olist)
-- DuckDB SQL | Reporting cutoff: 2018-08-31 (inclusive)
-- Grain: one delivered order -> one customer-month -> one cohort cell
-- Definition: first observed delivered order's PURCHASE month.
-- Uses customer_unique_id; customer_id is specific to an order.
-- ===============================================================

-- 01. Source customer purchase events: one row per delivered order.
-- Cutoff makes the analysis reproducible and avoids the very last
-- partial observation months. "delivered" is a final order status,
-- so these are not point-in-time delivery states as of the cutoff.
CREATE OR REPLACE VIEW v_delivered_customer_orders AS
SELECT
    o.order_id,
    c.customer_unique_id,
    TRY_CAST(o.order_purchase_timestamp AS TIMESTAMP) AS purchase_ts,
    DATE_TRUNC('month', TRY_CAST(o.order_purchase_timestamp AS TIMESTAMP))::DATE AS purchase_month
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND c.customer_unique_id IS NOT NULL
  AND TRY_CAST(o.order_purchase_timestamp AS TIMESTAMP) IS NOT NULL
  AND TRY_CAST(o.order_purchase_timestamp AS TIMESTAMP) < TIMESTAMP '2018-09-01 00:00:00';

-- 02. Deduplicate customers within each purchase month.
-- Multiple orders by the same buyer in one month count once
-- towards that month's active buyers.
CREATE OR REPLACE VIEW v_customer_months AS
SELECT DISTINCT customer_unique_id, purchase_month
FROM v_delivered_customer_orders;

-- 03. First purchase month and elapsed month index for each buyer.
CREATE OR REPLACE VIEW v_customer_cohorts AS
WITH first_month AS (
    SELECT customer_unique_id, MIN(purchase_month) AS cohort_month
    FROM v_customer_months
    GROUP BY customer_unique_id
)
SELECT
    cm.customer_unique_id,
    fm.cohort_month,
    cm.purchase_month,
    DATE_DIFF('month', fm.cohort_month, cm.purchase_month) AS month_number
FROM v_customer_months cm
JOIN first_month fm USING (customer_unique_id);

-- 04. Retention matrix: months 0 to 6, with zero for observed
-- months with no return purchases. Unobserved future months
-- are not included (never interpreted as 0% retention).
CREATE OR REPLACE VIEW v_cohort_retention AS
WITH cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS cohort_size
    FROM v_customer_cohorts
    WHERE month_number = 0
    GROUP BY cohort_month
),
active_by_age AS (
    SELECT cohort_month, month_number,
           COUNT(DISTINCT customer_unique_id) AS active_customers
    FROM v_customer_cohorts
    GROUP BY cohort_month, month_number
),
ages AS (
    SELECT range AS month_number
    FROM range(0, 7)
)
SELECT
    c.cohort_month,
    a.month_number,
    c.cohort_size,
    COALESCE(x.active_customers, 0) AS active_customers,
    ROUND(100.0 * COALESCE(x.active_customers, 0)
          / NULLIF(c.cohort_size, 0), 2) AS retention_pct
FROM cohort_sizes c
CROSS JOIN ages a
LEFT JOIN active_by_age x
    ON x.cohort_month = c.cohort_month
   AND x.month_number = a.month_number
WHERE a.month_number <= DATE_DIFF('month', c.cohort_month, DATE '2018-08-01');

-- 05. Sanity check: month 0 retention is 100% for every cohort.
SELECT
    COUNT(*) AS cohort_count,
    MIN(retention_pct) AS lowest_month_0,
    MAX(retention_pct) AS highest_month_0
FROM v_cohort_retention
WHERE month_number = 0;

-- 06. Raw cohort output, useful for Tableau later.
SELECT * FROM v_cohort_retention
ORDER BY cohort_month, month_number;

-- 07. Check observed repeat customer rate before cutoff.
-- This is different from month-one retention.
WITH customer_orders AS (
  SELECT customer_unique_id, COUNT(DISTINCT order_id) AS n_orders
  FROM v_delivered_customer_orders
  GROUP BY customer_unique_id
)
SELECT
  COUNT(*) AS unique_customers,
  COUNT(*) FILTER (WHERE n_orders > 1) AS repeat_customers,
  ROUND(100.0 * COUNT(*) FILTER (WHERE n_orders > 1)
        / NULLIF(COUNT(*), 0), 2) AS repeat_customer_rate_pct
FROM customer_orders;

-- 08. Cohort sizes and Month-1 retention (matured cohorts only).
SELECT cohort_month, cohort_size, active_customers, retention_pct
FROM v_cohort_retention
WHERE month_number = 1
ORDER BY cohort_month;
