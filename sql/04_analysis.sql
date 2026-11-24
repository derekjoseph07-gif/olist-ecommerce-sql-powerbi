SET search_path = olist;
-- DATA NOTES (from checks C1-C8)
-- Revenue = SUM(order_items.price) for delivered orders (freight excluded). Currency: BRL.
-- Period: orders run Sep 2016 - Oct 2018; reliable range is Jan 2017 - Aug 2018.
-- 775 orders have no items (mostly unavailable/canceled); 8 delivered orders lack a delivery date.
-- products.product_category_name is NULL for 610 products; 13 products have a category with no
-- English translation -> use LEFT JOIN + COALESCE(english, portuguese, 'unknown').
-- customer_id is per order; customer_unique_id is the real person (96,096 people, 99,441 orders).
-- Items and payments disagree by more than 0.01 for 303 of 98,665 orders.
-- 6 canceled orders carry a delivery date; delivery queries filter on status = 'delivered'.
-- payment_value includes freight, so payment totals (Q6) are not comparable to item revenue (Q1, Q7).
-- Convention: every analysis query uses delivered orders only, unless stated.
-- Q1
with m AS (SELECT DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
       SUM(oi.price) AS revenue
FROM orders o
JOIN order_items oi USING (order_id)
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp <  '2018-09-01'
GROUP BY 1
)
SELECT month, revenue, LAG(revenue) OVER (ORDER BY month) AS prev_revenue, 
ROUND((revenue - LAG(revenue) OVER (ORDER BY month))/(LAG(revenue) OVER (ORDER BY month))*100,1) AS mom_growth_pct,
ROUND(AVG(revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) as rolling_avg_3mo
FROM m
ORDER BY 1;
-- Finding: Delivered-order revenue (item prices) grew from R$112k in Jan 2017 to
-- R$0.83-0.98M a month through 2018. Growth was fastest in early 2017 (+110% in Feb,
-- +53% in Mar) and peaked at R$988k in Nov 2017 (+52% vs Oct), then fell 26.5% in Dec.
-- In 2018 revenue plateaued; the 3-month average peaked at R$968k in May and eased to
-- R$854k by Aug.
-- Q2: top 10 categories by revenue
WITH g AS (SELECT COALESCE(cnt.category_name_english,p.product_category_name,'unknown') AS category, sum(oi.price) AS revenue
FROM orders o
JOIN order_items oi using (order_id)
JOIN products p using (product_id)
LEFT JOIN category_name_translation cnt ON cnt.category_name_port = p.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY 1
),
s AS (
	SELECT category, revenue, revenue*100/SUM(revenue) OVER() as share_pct
	FROM g
)
SELECT category, revenue, ROUND(share_pct,1) AS share_pct_round,
		ROUND(SUM(share_pct) OVER (ORDER BY revenue DESC,category ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),1) AS cum_pct
FROM s
ORDER BY 2 DESC
LIMIT 10;
--Finding: the top 10 of 74 categories generate 62.4% of delivered-order revenue (R$ item prices)
--led by health_beauty (9.3%), watches_gifts (8.8%) and bed_bath_table (7.7%)
--the top 26 categories reach about 91%, so revenue is concentrated with a long tail.
--Q3 : delivery performance by customer state
SELECT c.state AS state, COUNT(*) AS orders, 
	ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp))/86400),1) AS delivery_days,
	ROUND(COUNT(*) FILTER (WHERE o.order_delivered_customer_date > o.order_estimated_delivery_date)*100.0/COUNT(*),1) AS pct_late
FROM orders o
LEFT JOIN customers c using(customer_id)
WHERE o.order_status = 'delivered' AND o.order_delivered_customer_date IS NOT NULL
GROUP BY 1
ORDER BY 4 DESC;
-- Finding: Delivery performance varies sharply by state. SP (42% of orders) delivers in 8.8
-- days with 5.9% late, while AL is worst on punctuality at 23.9% late (397 orders),
-- followed by MA 19.7%, PI 16.0%, CE 15.3% and BA 14.0%. RJ, the second-largest state,
-- has 13.5% late (about 1,670 orders). Remote states like AM and AP take 26-27 days
-- but are rarely late (about 4%), possibly because their estimates are longer (hypothesis).
--Q4: how many real customers ordered more than once?
WITH a AS (SELECT c.customer_unique_id, COUNT(*) as orders_placed
FROM orders o
JOIN customers c using(customer_id)
WHERE o.order_status = 'delivered'
GROUP BY 1
)
SELECT orders_placed, COUNT(*) as customers_ordered,
	ROUND(COUNT(*)*100.0/SUM(COUNT(*)) OVER(),1) as customers_share
FROM a
GROUP BY 1
ORDER BY 1;
-- FINDING Q4: Of 93,358 customers with a delivered order, 97.0% (90,557) ordered
-- only once. 2,801 (3.0%) came back: 2,573 ordered twice, 181 three times,
-- and a handful 4+ (max 15). Olist is almost entirely a one-time-purchase
-- marketplace in this data, so growth depends on acquiring new customers, not repeat business.
--Q5 : cohort retention
WITH b AS (SELECT c.customer_unique_id, DATE_TRUNC('month',MIN(order_purchase_timestamp))::date AS month_group
FROM orders o
JOIN customers c using(customer_id)
WHERE o.order_status = 'delivered'
GROUP BY 1),
a AS (
SELECT c.customer_unique_id, month_group,  DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month,
		EXTRACT(YEAR  FROM AGE(DATE_TRUNC('month', o.order_purchase_timestamp), month_group)) * 12
		+ EXTRACT(MONTH FROM AGE(DATE_TRUNC('month', o.order_purchase_timestamp), month_group)) AS months_since
FROM orders o
JOIN customers c using (customer_id)
JOIN b using (customer_unique_id)
WHERE o.order_status = 'delivered'	
),
r AS (
    SELECT month_group AS cohort_month,
           months_since,
           COUNT(DISTINCT customer_unique_id) AS customers
    FROM a
    WHERE month_group >= '2017-01-01' AND month_group < '2018-01-01'
    GROUP BY 1, 2
)
SELECT cohort_month, months_since, customers,
       ROUND(customers * 100.0 /
             FIRST_VALUE(customers) OVER (PARTITION BY cohort_month ORDER BY months_since), 2) AS retention_pct
FROM r
WHERE months_since <= 6
ORDER BY cohort_month, months_since;
-- FINDING Q5: Cohort retention is very low. Of the 42,131 customers who first
-- ordered in 2017, only 0.1%-0.7% ordered again in any single later month
-- (month 1 range 0.18%-0.72%, best: Oct 2017). Retention is flat rather than decaying
-- from a high start, confirming Q4: Olist growth came from acquiring new customers.
-- The Nov 2017 cohort (7,060 new customers, the largest) fell from 0.57% in month 1 to
-- 0.11% by month 6, below earlier cohorts. Counts per cell are small (2-40 people),
-- so small differences between cohorts are noise.
--Q6: Payment Mix
SELECT op.payment_type, 
		COUNT(DISTINCT order_id) orders,
		ROUND(SUM(payment_value),2) total_value,
		ROUND(SUM(payment_value)*100/SUM(SUM(payment_value)) OVER(),2) value_share_pct,
		ROUND(AVG(payment_installments),1) avg_installments
FROM orders o
JOIN order_payments op using (order_id)
WHERE order_status = 'delivered'
GROUP BY 1
ORDER BY 3 DESC;
-- FINDING Q6: Credit card dominates: 78.5% of delivered-order payment value (R$12.1M of
-- R$15.4M) across 74,304 orders, at 3.5 instalments on average. Boleto (bank slip) is second
-- at 18.0%, vouchers 2.2% and debit card 1.4%; all three are single-payment (1.0 instalments).
-- Order counts sum to more than the number of delivered orders because orders paid with
-- two methods are counted under both. payment_value includes freight, so totals are not
-- comparable to Q1 item-price revenue.
--Q7 : seller concentration
WITH s AS (SELECT oi.seller_id, SUM(price) revenue
FROM orders o
JOIN order_items oi using(order_id)
WHERE order_status='delivered'
GROUP BY 1),
t AS (SELECT seller_id, revenue,
NTILE(10) OVER (ORDER BY revenue DESC) decile
FROM s)
SELECT decile, COUNT(*) sellers, ROUND(SUM(revenue),2) revenue,
		ROUND(SUM(revenue)*100/SUM(SUM(revenue)) OVER(),2) share_pct
FROM t
GROUP BY 1
ORDER BY 1;
-- FINDING Q7: Seller revenue is highly concentrated. Of 2,970 sellers with delivered sales
-- (R$13.2M item revenue), the top 10% (297 sellers) earn 67.1%, the top 20% earn 82.3%
-- and the top 30% earn 90.1%. The bottom half of sellers together earn 3.3%.
-- More concentrated than categories (Q2: top 10 of 74 categories = 62.4%). Ranking uses
-- total revenue over the whole period, so late-joining sellers rank low partly because
-- they had less time to sell.
--Q8 : order pipeline
SELECT COUNT(*) AS orders_placed,
       COUNT(order_approved_at) AS approved,
	   ROUND(COUNT(order_approved_at)*100.0/COUNT(*),1) approved_pct,
       COUNT(order_delivered_carrier_date) AS shipped,
	   ROUND(COUNT(order_delivered_carrier_date)*100.0/COUNT(*),1) shipped_pct,
       COUNT(order_delivered_customer_date) AS delivered,
	   ROUND(COUNT(order_delivered_customer_date)*100.0/COUNT(*),1) delivered_pct
FROM orders;
SELECT
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
      ORDER BY EXTRACT(EPOCH FROM (order_approved_at - order_purchase_timestamp)) / 86400
  )::numeric, 2) purchase_to_approval,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
      ORDER BY EXTRACT(EPOCH FROM (order_delivered_carrier_date - order_approved_at)) / 86400
  )::numeric, 2) approval_to_shipped,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
	ORDER BY EXTRACT(EPOCH FROM(order_delivered_customer_date - order_delivered_carrier_date))/86400)
	::numeric,2) shipped_to_delivered,
  ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (
	ORDER BY EXTRACT(EPOCH FROM(order_delivered_customer_date - order_purchase_timestamp))/86400)
	::numeric,2) AS purchase_to_delivered
FROM orders
WHERE order_status = 'delivered';
SELECT op.payment_type,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY
             EXTRACT(EPOCH FROM (o.order_approved_at - o.order_purchase_timestamp)) / 86400)::numeric, 2) AS median_days,
       ROUND(AVG(EXTRACT(EPOCH FROM (o.order_approved_at - o.order_purchase_timestamp)) / 86400)::numeric, 2) AS avg_days
FROM orders o
JOIN order_payments op USING (order_id)
WHERE o.order_status = 'delivered'
GROUP BY 1;
-- FINDING Q8 (pipeline): 97.0% of orders reach a delivery date; 2,965 (3.0%) drop out, the largest
-- loss between approval and shipping (1,623 orders). For delivered orders the median
-- purchase-to-delivery time is 10.22 days: approval takes minutes (median 0.01 days), the seller
-- 1.82 days to hand over to the carrier, and the carrier 7.10 days (about 69% of the total).
-- Boleto (bank slip) orders, about 20% of delivered orders, wait a median 1.21 days for approval
-- vs 0.01 for credit card, which is why the total median is higher than the stage medians
-- suggest (sum 8.93). Orders paid with several methods appear under each method.
