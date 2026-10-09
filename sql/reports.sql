-- a) Order totals — COUNT(*), total revenue, and average order value, where revenue per row is 
-- quantity * price * (1 - discount_pct/100) and NULL discount is treated as 0% (COALESCE). 
-- Joins orders to products.
-- Expected: total_orders = 180, total_revenue = 99860.20, avg_order_value = 554.78. 
SELECT
    COUNT(*) AS total_orders,
    ROUND(SUM(o.quantity * p.price * (1 - COALESCE(o.discount_pct, 0) / 100)), 2) AS total_revenue,
    ROUND(AVG(o.quantity * p.price * (1 - COALESCE(o.discount_pct, 0) / 100)), 2) AS avg_order_value
FROM orders o
JOIN products p
    ON o.product_id = p.product_id;
    
-- b) COUNT(*) vs COUNT(column) — one query showing COUNT(*), COUNT(rating), and the difference, on orders.
-- Expected: (180, 165, 15) — 15 orders have no rating yet.
SELECT
    COUNT(*) AS total_orders,
    COUNT(rating) AS rated_orders,
    COUNT(*) - COUNT(rating) AS unrated_orders
FROM orders;

-- c) LEFT JOIN with a genuine zero-match row — LEFT JOIN customers to orders, GROUP BY customer, 
-- HAVING COUNT(order_id) = 0, to find any customer with zero orders. Then write a second, independent 
-- query using NOT IN (SELECT DISTINCT customer_id FROM orders) that must return the same customer, 
-- confirming the LEFT JOIN result rather than trusting it blindly.
-- Expected: both queries return exactly one row — C045, Vihaan.
-- QUERY 1
SELECT
    c.customer_id,
    c.name
FROM customers c
LEFT JOIN orders o
    ON c.customer_id = o.customer_id
GROUP BY
    c.customer_id,
    c.name
HAVING COUNT(o.order_id) = 0;

-- QUERY 2
SELECT
    customer_id,
    name
FROM customers
WHERE customer_id NOT IN (
    SELECT DISTINCT customer_id
    FROM orders
); 

-- d) GROUP BY + HAVING — join orders to customers, group by city, compute total_orders, 
-- returned_orders, and return_rate_pct (rounded to 1 decimal), then filter with HAVING 
-- return_rate_pct > 20, ordered by return_rate_pct DESC.
-- Expected exactly 3 rows: Jaipur (19, 8, 42.1), Lucknow (49, 15, 30.6), Bangalore (33, 8, 24.2). (Mumbai at 17.9% and Delhi at 17.4% are correctly excluded.)
SELECT
    c.city,
    COUNT(*) AS total_orders,
    SUM(o.returned) AS returned_orders,
    ROUND(SUM(o.returned) * 100.0 / COUNT(*), 1) AS return_rate_pct
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
GROUP BY
    c.city
HAVING return_rate_pct > 20
ORDER BY
    return_rate_pct DESC;

-- e) Ranking with ORDER BY + LIMIT/OFFSET — join orders, products, customers; group by customer; 
-- compute total_spend; order by total_spend DESC, customer_id ASC (the tie-break matters — state why 
-- in a one-line comment). Run it once with LIMIT 5 and once with LIMIT 3 OFFSET 2 to get ranks 3–5 without 
-- re-deriving the top 5.
-- Expected top 5: C043 Reyansh 12920.00, C026 Isha 8371.60, C008 Meera 4564.60, C011 Arjun 4111.00, C042 Sanya 3785.00. The LIMIT 3 OFFSET 2 query must return exactly the last three of those five, in the same order.

-- customer_id breaks ties so ranking stays deterministic when two customers have the same spend.
SELECT
    c.customer_id,
    c.name,
    ROUND(SUM(o.quantity * p.price * (1 - COALESCE(o.discount_pct, 0) / 100)), 2) AS total_spend
FROM orders o
JOIN products p
    ON o.product_id = p.product_id
JOIN customers c
    ON o.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.name
ORDER BY
    total_spend DESC,
    c.customer_id ASC
LIMIT 5;

-- FOR RANKS 3 TO 5:
-- customer_id breaks ties so ranking stays deterministic when two customers have the same spend.
SELECT
    c.customer_id,
    c.name,
    ROUND(SUM(o.quantity * p.price * (1 - COALESCE(o.discount_pct, 0) / 100)), 2) AS total_spend
FROM orders o
JOIN products p
    ON o.product_id = p.product_id
JOIN customers c
    ON o.customer_id = c.customer_id
GROUP BY
    c.customer_id,
    c.name
ORDER BY
    total_spend DESC,
    c.customer_id ASC
LIMIT 3 OFFSET 2;

-- f) Three-table JOIN with GROUP BY — join orders, products, customers (only the first two are strictly 
-- needed for this one, but confirm the three-way join compiles cleanly since Part 3 will need it);
-- group by category; compute order_count and category_revenue; order by revenue descending.
-- Expected: Haircare (54, 44956.10), Skincare (60, 27346.00), Babycare (30, 16805.00), PersonalCare (36, 10753.10).
SELECT
    p.category,
    COUNT(*) AS order_count,
    ROUND(SUM(o.quantity * p.price * (1 - COALESCE(o.discount_pct, 0) / 100)), 2) AS category_revenue
FROM orders o
JOIN products p
    ON o.product_id = p.product_id
JOIN customers c
    ON o.customer_id = c.customer_id
GROUP BY
    p.category
ORDER BY
    category_revenue DESC;

-- g) LIKE pattern match — customers whose name starts with 'A'.
-- Expected: exactly 10 rows.
SELECT
    customer_id,
    name
FROM customers
WHERE name LIKE 'A%'
ORDER BY customer_id;

-- h) DISTINCT — distinct acquisition_source values used across all customers.
-- Expected: exactly 4 values — Ad, Organic, Referral, Social.
SELECT DISTINCT
    acquisition_source
FROM customers
ORDER BY acquisition_source;

-- i) ALTER TABLE + UPDATE with CASE — add a loyalty_tier VARCHAR(10) column to customers, 
-- then a single UPDATE ... SET loyalty_tier = CASE WHEN city_tier = 1 THEN 'Gold' ELSE 'Silver' 
-- END (no WHERE clause — every row gets a value).
-- Expected: SELECT loyalty_tier, COUNT(*) FROM customers GROUP BY loyalty_tier; → Gold, 28 and Silver, 17.
ALTER TABLE customers
ADD COLUMN loyalty_tier VARCHAR(10);

SET SQL_SAFE_UPDATES = 0;
UPDATE customers
SET loyalty_tier = CASE
    WHEN city_tier = 1 THEN 'Gold'
    ELSE 'Silver'
END;
SET SQL_SAFE_UPDATES = 1;

SELECT
    loyalty_tier,
    COUNT(*) AS customer_count
FROM customers
GROUP BY loyalty_tier
ORDER BY loyalty_tier;