Olist E-commerce: SQL + Power BI Analysis

An end-to-end analysis of the Olist Brazilian e-commerce dataset. I built a PostgreSQL database, ran 8 data-quality checks and 8 business queries, shaped the data into a star schema of five views, and built a two-page Power BI report whose numbers reconcile to the SQL results.

Tools: PostgreSQL 16, pgAdmin 4, Power BI Desktop (DAX)
SQL used: joins, CTEs, window functions (LAG, rolling averages, NTILE, FIRST_VALUE), FILTER, PERCENTILE_CONT, cohort analysis, views

Business questions
How has monthly revenue grown, and when did it peak?
Which product categories bring in the most revenue?
How does delivery time and lateness differ by customer state?
How many customers ordered more than once?
How well are customers retained month after month (2017 cohorts)?
How do customers pay (method, value, instalments)?
How concentrated is revenue among sellers?
How far do orders progress through the pipeline, and how long does each stage take?
Data
Source: Olist Brazilian E-Commerce dataset on Kaggle. See the dataset page for licence terms. The CSV files are not included in this repository.
7 tables used: customers (99,441), sellers (3,095), products (32,951), orders (99,441), order items (112,650), order payments (103,886) and a category-name translation table.
Orders run from 4 Sep 2016 to 17 Oct 2018; 97% have status delivered. Time-trend analysis uses the reliable range Jan 2017 to Aug 2018.
Approach
sql/01_schema.sql: creates the olist schema and seven tables with keys and constraints.
sql/02_load.sql: loads the CSV files with \copy (run in psql).
sql/03_checks.sql: eight data-quality checks (C1 to C8), each with its expected result.
sql/04_analysis.sql: eight business queries (Q1 to Q8), each with a written finding.
sql/05_views.sql: five views that form a star schema for Power BI.
powerbi/olist_powerbi.pbix: the data model, DAX measures and a two-page report.
Data quality checks
775 orders have no items (mostly unavailable or canceled).
8 delivered orders have no delivery date, and 6 canceled orders carry one. Delivery metrics therefore filter on order_status = 'delivered'.
610 products have no category and 13 have a category with no English translation. Handled with a LEFT JOIN and COALESCE(english, portuguese, 'unknown').
customer_id is created per order. The real person is customer_unique_id: 96,096 people across 99,441 orders.
Item totals (price + freight) and payment totals disagree by more than R$0.01 on 303 of 98,665 orders, so payment values are not used as revenue.
No order has a delivery date earlier than its purchase date.

Revenue is defined as SUM(price) on delivered orders (freight excluded), in Brazilian reais.

Key findings
Q	Topic	Finding
1	Revenue trend	Monthly revenue grew from R$112k (Jan 2017) to R$0.83M to 0.98M a month through 2018. It peaked at R$988k in Nov 2017 (+52% on Oct), fell 26.5% in Dec, then plateaued in 2018.
2	Categories	The top 10 of 74 categories earn 62.4% of revenue, led by health_beauty (9.3%), watches_gifts (8.8%) and bed_bath_table (7.7%).
3	Delivery by state	SP (about 42% of orders) delivers in 8.8 days with 5.9% late. AL is the worst on lateness at 23.9%, then MA 19.7% and PI 16.0%. AM and AP take 26 to 27 days but are rarely late (about 4%).
4	Repeat customers	97.0% of 93,358 customers ordered once; only 3.0% came back.
5	Retention	Of 2017 first-time customers, only 0.1% to 0.7% order again in any single later month. Growth came from acquiring new customers.
6	Payment mix	Credit card is 78.5% of payment value (3.5 instalments on average), boleto 18.0%, voucher 2.2%, debit card 1.4%.
7	Seller concentration	The top 10% of sellers (297 of 2,970) earn 67.1% of revenue; the top 20% earn 82.3%.
8	Order pipeline	97.0% of orders reach delivery. The median purchase-to-delivery time is 10.22 days: approval 0.01, seller hand-over 1.82, carrier 7.10. Boleto orders wait a median 1.21 days for approval, against 0.01 for credit card.
Data model

Data model

The model is a star schema. The fact view v_fact_order_items has one row per order item (112,650) and links to four dimensions: product, seller, customer and date. All relationships are one-to-many with a single filter direction. The customer dimension has one row per customer_id (one per order) rather than per person, because 39 people shipped to more than one state; real customers are counted with DISTINCTCOUNT(customer_unique_id).

DAX measures: Revenue, Orders, Customers, Avg Delivery Days, Late %. Delivery measures are calculated per order, since the fact table repeats order-level values on each item row.

Power BI report

Sales overview

Sales overview: revenue, orders and customers (Jan 2017 to Aug 2018), monthly revenue, top 10 categories and a customer-state filter. These reconcile to Q1, Q2 and Q4.

Delivery performance

Delivery performance: late % and average delivery days by state, and late % by month. State figures match Q3 within rounding (the report is filtered to Jan 2017 to Aug 2018).

How to reproduce
Download the data from the Kaggle link above and put the CSV files in one folder.
Create a PostgreSQL 16 database named olist, then run sql/01_schema.sql.
Edit the folder path in sql/02_load.sql and run it in psql (\copy is a psql command).
Run sql/03_checks.sql, sql/04_analysis.sql and sql/05_views.sql in pgAdmin 4 (each tab needs SET search_path = olist;).
Open powerbi/olist_powerbi.pbix. The data is embedded, so it opens without a database. To refresh it, point the PostgreSQL connection at localhost / olist.
Limitations
Payment data is not in the Power BI model; the payment analysis (Q6) is in SQL only.
Revenue excludes freight. Payment totals include freight, so the two are not comparable.
Time trends cover Jan 2017 to Aug 2018 only; earlier and later months have too few orders.
The findings are descriptive. For example, the monthly late-delivery chart shows spikes around Nov 2017 and early 2018, but the data cannot tell the cause, and the link between seller location and delivery time was not tested.
Cohort cells in Q5 are small (2 to 40 people), and small states such as RR have very few orders, so their percentages are noisy.