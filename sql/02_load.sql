-- Run in psql after connecting to the olist database
 \cd '<folder containing the Olist CSV files>'
SET client_encoding = 'UTF8';
SET search_path = olist;

\copy customers FROM 'olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy sellers FROM 'olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy category_name_translation FROM 'product_category_name_translation.csv' WITH (FORMAT csv, HEADER true)
\copy products FROM 'olist_products_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy orders FROM 'olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy order_items FROM 'olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true)
\copy order_payments FROM 'olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true)