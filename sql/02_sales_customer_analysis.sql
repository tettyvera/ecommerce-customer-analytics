-- Project #2: Olist E-Commerce Customer & Sales Analytics


CREATE OR REPLACE VIEW orders AS
SELECT * FROM read_csv_auto('data/olist_orders_dataset.csv', header=true);
CREATE OR REPLACE VIEW customers AS
SELECT * FROM read_csv_auto('data/olist_customers_dataset.csv', header=true);
CREATE OR REPLACE VIEW order_items AS
SELECT * FROM read_csv_auto('data/olist_order_items_dataset.csv', header=true);
CREATE OR REPLACE VIEW order_payments AS
SELECT * FROM read_csv_auto('data/olist_order_payments_dataset.csv', header=true);

-- One row per order_id BEFORE joining to orders.
CREATE OR REPLACE VIEW v_item_totals AS
SELECT
    order_id,
    COUNT(*) AS item_rows,
    SUM(TRY_CAST(price AS DOUBLE)) AS merchandise_value,
    SUM(TRY_CAST(freight_value AS DOUBLE)) AS freight_value
FROM order_items
GROUP BY order_id;

CREATE OR REPLACE VIEW v_payment_totals AS
SELECT
    order_id,
    COUNT(*) AS payment_rows,
    SUM(TRY_CAST(payment_value AS DOUBLE)) AS payment_value
FROM order_payments
GROUP BY order_id;

-- Analysis grain: exactly one row per delivered order.
CREATE OR REPLACE VIEW v_order_sales AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_state,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    i.item_rows,
    i.merchandise_value,
    i.freight_value,
    p.payment_rows,
    p.payment_value
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN v_item_totals i ON o.order_id = i.order_id
LEFT JOIN v_payment_totals p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered';

-- 01 Status Summary
SELECT
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE order_status = 'delivered') AS delivered_orders,
    COUNT(DISTINCT order_id) AS unique_order_ids
FROM orders;

-- 02 Grain Check
SELECT
    (SELECT COUNT(*) FROM order_items) AS item_rows,
    (SELECT COUNT(DISTINCT order_id) FROM order_items) AS orders_with_items,
    (SELECT COUNT(*) FROM order_payments) AS payment_rows,
    (SELECT COUNT(DISTINCT order_id) FROM order_payments) AS orders_with_payments;

-- 03 Validate Order Grain
SELECT
    COUNT(*) AS delivered_rows,
    COUNT(DISTINCT order_id) AS unique_orders,
    COUNT(*) FILTER (WHERE merchandise_value IS NULL) AS orders_missing_items,
    COUNT(*) FILTER (WHERE payment_value IS NULL) AS orders_missing_payments,
    COUNT(*) FILTER (WHERE customer_unique_id IS NULL) AS orders_missing_customer_id
FROM v_order_sales;

-- 04 Sales Kpis
SELECT
    COUNT(*) AS delivered_orders,
    ROUND(SUM(COALESCE(merchandise_value, 0)), 2) AS merchandise_gmv_brl,
    ROUND(SUM(COALESCE(freight_value, 0)), 2) AS shipping_charges_brl,
    ROUND(SUM(COALESCE(payment_value, 0)), 2) AS recorded_payments_brl,
    ROUND(SUM(COALESCE(merchandise_value, 0)) / NULLIF(COUNT(*), 0), 2) AS aov_merchandise_brl
FROM v_order_sales;

-- 05 Monthly Sales
SELECT
    DATE_TRUNC('month', TRY_CAST(order_purchase_timestamp AS TIMESTAMP))::DATE AS purchase_month,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(COALESCE(merchandise_value, 0)), 2) AS merchandise_gmv_brl,
    ROUND(SUM(COALESCE(merchandise_value, 0)) / NULLIF(COUNT(*), 0), 2) AS aov_brl
FROM v_order_sales
GROUP BY 1
ORDER BY 1;

-- 06 Repeat Customers
WITH customer_orders AS (
    SELECT
        customer_unique_id,
        COUNT(DISTINCT order_id) AS delivered_order_count
    FROM v_order_sales
    WHERE customer_unique_id IS NOT NULL
    GROUP BY 1
)
SELECT
    COUNT(*) AS unique_customers,
    COUNT(*) FILTER (WHERE delivered_order_count > 1) AS repeat_customers,
    ROUND(100.0 * COUNT(*) FILTER (WHERE delivered_order_count > 1)
        / NULLIF(COUNT(*), 0), 2) AS observed_repeat_rate_pct
FROM customer_orders;

-- 07 Sales By State
SELECT
    customer_state,
    COUNT(*) AS delivered_orders,
    ROUND(SUM(COALESCE(merchandise_value, 0)), 2) AS merchandise_gmv_brl,
    ROUND(AVG(merchandise_value), 2) AS avg_order_merchandise_value_brl
FROM v_order_sales
WHERE customer_state IS NOT NULL
GROUP BY 1
ORDER BY merchandise_gmv_brl DESC;

-- 08 Naive Join Warning
SELECT
    ROUND(SUM(TRY_CAST(i.price AS DOUBLE)), 2) AS incorrect_merchandise_gmv_brl
FROM orders o
LEFT JOIN order_items i ON o.order_id = i.order_id
LEFT JOIN order_payments p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered';
