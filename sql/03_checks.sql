SET search_path = olist;
-- my checks	
SELECT 'customers' AS table_name, count(*) AS n FROM customers
UNION ALL
SELECT 'sellers', count(*) FROM sellers
UNION ALL 
SELECT 'products', count(*) FROM products
UNION ALL
SELECT 'orders', count(*) FROM orders
UNION ALL
SELECT 'order_items', count(*) FROM order_items
UNION ALL
SELECT 'order_payments', count(*) FROM order_payments;
--C2 
SELECT min(order_purchase_timestamp)::date AS earliest, max(order_purchase_timestamp)::date AS latest FROM orders;
SELECT order_status, COUNT(*) n, ROUND(COUNT(*)*100 / SUM(COUNT(*)) OVER(),1) pct FROM orders GROUP BY order_status ORDER BY 2 DESC;
--C3
SELECT order_status ,COUNT(o.order_id) n FROM orders o LEFT JOIN order_items oi USING(order_id) WHERE order_item_id IS NULL GROUP BY order_status ORDER BY n DESC ;
--C4
SELECT COUNT(*) delivered_no_date FROM orders WHERE order_status='delivered' AND order_delivered_customer_date IS NULL;
--C5 
SELECT COUNT(*) bad_dates FROM orders WHERE order_delivered_customer_date < order_purchase_timestamp;
--C6
SELECT p.product_category_name,COUNT(*) no_translation FROM products p LEFT JOIN category_name_translation cnt ON p.product_category_name = cnt.category_name_port WHERE category_name_english IS NULL GROUP BY p.product_category_name ORDER BY no_translation DESC;
--C7
SELECT COUNT(DISTINCT customer_id) customer_ids, COUNT(DISTINCT customer_unique_id) unique_customers FROM customers;
--C8 prep
SELECT COUNT(order_id), COUNT(DISTINCT order_id) FROM order_payments;
SELECT COUNT(order_id), COUNT(DISTINCT order_id) FROM order_items;
-- C8
WITH i AS (
    SELECT order_id, SUM(price + freight_value) AS item_total
    FROM order_items
    GROUP BY order_id
),
p AS (
    SELECT order_id, SUM(payment_value) AS paid
    FROM order_payments
    GROUP BY order_id
)
SELECT COUNT(*) AS orders_compared,
       COUNT(*) FILTER (WHERE ABS(i.item_total - p.paid) > 0.01) AS mismatched
FROM i
JOIN p USING (order_id);
-- C1: sellers 3095, products 32951, order_payments 103886, customers 99441, orders 99441, order_items 112650
-- C2: 2016-09-04 to 2018-10-17; 97% delivered
-- C3: 775 orders without items (unavailable 603, canceled 164, created 5, invoiced 2, shipped 1)
-- C4: 8 delivered orders without a delivery date
-- C5: 0
-- C6: 610 products with NULL category; 13 products with an untranslated category (10 + 3)
-- C7: 99441 customer_ids, 96096 unique customers
-- C8: 98665 orders compared, 303 mismatched