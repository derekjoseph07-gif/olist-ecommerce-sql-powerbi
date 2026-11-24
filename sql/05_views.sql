SET search_path = olist;
CREATE OR REPLACE VIEW v_dim_product AS (
		SELECT product_id, 
		COALESCE(category_name_english,product_category_name,'unknown') category,
		product_weight_g,
		product_photos_qty
FROM products p
LEFT JOIN category_name_translation cnt ON cnt.category_name_port = p.product_category_name);
SELECT COUNT(*) FROM v_dim_product;                            
SELECT COUNT(*) FROM v_dim_product WHERE category = 'unknown';
CREATE OR REPLACE VIEW v_dim_seller AS (
	SELECT seller_id, seller_city, seller_state
	FROM sellers
);
SELECT seller_state, COUNT(*) AS sellers
FROM v_dim_seller
GROUP BY 1
ORDER BY 2 DESC;
CREATE OR REPLACE VIEW v_dim_customer AS(
	SELECT customer_id, customer_unique_id, city customer_city, state customer_state
	FROM customers
);
SELECT COUNT(*), COUNT(DISTINCT customer_unique_id) FROM v_dim_customer;
CREATE OR REPLACE VIEW v_dim_date AS
WITH days AS (
    SELECT g::date AS full_date
    FROM generate_series('2016-01-01'::date, '2018-12-31'::date, interval '1 day') AS g
)
SELECT full_date,
       EXTRACT(YEAR FROM full_date)::int AS year,
       EXTRACT(QUARTER FROM full_date)::int AS quarter,
       EXTRACT(MONTH FROM full_date)::int AS month_num,
       TO_CHAR(full_date,'Mon') AS month_name,
       DATE_TRUNC('month',full_date)::date AS month_start,
       EXTRACT(ISODOW FROM full_date)::int AS day_of_week_num,
       TO_CHAR(full_date,'Dy') AS day_name
FROM days;
SELECT COUNT(*), MIN(full_date), MAX(full_date) FROM v_dim_date;
SELECT * FROM v_dim_date LIMIT 5;
CREATE OR REPLACE VIEW v_fact_order_items AS
SELECT oi.order_id,
       oi.order_item_id,
       o.customer_id,
       oi.product_id,
       oi.seller_id,
       o.order_purchase_timestamp::date AS purchase_date,
       o.order_status,
       oi.price,
       oi.freight_value,
       CASE WHEN o.order_status = 'delivered'
            THEN ROUND(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)) / 86400, 1)
       END AS delivery_days,
       CASE WHEN o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
            THEN (o.order_delivered_customer_date > o.order_estimated_delivery_date)::int
       END AS is_late
FROM order_items oi
JOIN orders o USING (order_id);
SELECT COUNT(*) FROM v_fact_order_items;
SELECT COUNT(DISTINCT order_id) FILTER (WHERE delivery_days IS NOT NULL) FROM v_fact_order_items;
SELECT table_name FROM information_schema.views WHERE table_schema = 'olist' ORDER BY 1; 
-- VIEWS SUMMARY (star schema for Power BI)
-- v_fact_order_items: one row per order item (112,650). Keys: customer_id, product_id, seller_id,
--   purchase_date -> the four dimensions below. All order statuses kept; Power BI filters to
--   order_status = 'delivered' to match the SQL analysis. Revenue = SUM(price), freight excluded.
--   delivery_days and is_late are order-level values repeated on each item row and NULL unless the
--   order is delivered with a delivery date; for order counts use DISTINCT order_id.
-- v_dim_product: one row per product (32,951). English category; falls back to the Portuguese name
--   (13 products), then 'unknown' (610). Some English names carry typos from the source file.
-- v_dim_seller: one row per seller (3,095). SP holds ~60% of sellers; SP, PR and MG ~79%.
-- v_dim_customer: one row per customer_id (= one per order, 99,441) with customer_unique_id
--   (96,096 real people) as a column. 39 people shipped to more than one state, so one row per person
--   would need an arbitrary rule; count real customers with DISTINCTCOUNT(customer_unique_id).
-- v_dim_date: one row per day, 2016-01-01 to 2018-12-31 (1,096 days); month_start sorts month charts.

