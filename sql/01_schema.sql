-- Olist schema (PostgreSQL)
CREATE SCHEMA olist;
SET search_path = olist;

CREATE TABLE customers (
    customer_id        text PRIMARY KEY,
    customer_unique_id text NOT NULL,
    zip_code_prefix    integer,
    city               text,
    state              char(2)
);

CREATE TABLE sellers (
    seller_id              text PRIMARY KEY,
    seller_zip_code_prefix integer,
    seller_city            text,
    seller_state           char(2)
);

CREATE TABLE category_name_translation (
    category_name_port    text PRIMARY KEY,
    category_name_english text NOT NULL
);

CREATE TABLE products (
    product_id                 text PRIMARY KEY,
    product_category_name      text,
    product_name_lenght        integer,
    product_description_lenght integer,
    product_photos_qty         integer,
    product_weight_g           integer,
    product_length_cm          integer,
    product_height_cm          integer,
    product_width_cm           integer
);

CREATE TABLE orders (
    order_id                       text PRIMARY KEY,
    customer_id                    text NOT NULL REFERENCES customers(customer_id),
    order_status                   text NOT NULL,
    order_purchase_timestamp       timestamp NOT NULL,
    order_approved_at              timestamp,
    order_delivered_carrier_date   timestamp,
    order_delivered_customer_date  timestamp,
    order_estimated_delivery_date  timestamp
);

CREATE TABLE order_items (
    order_id             text NOT NULL REFERENCES orders(order_id),
    order_item_id        integer NOT NULL,
    product_id           text NOT NULL REFERENCES products(product_id),
    seller_id            text NOT NULL REFERENCES sellers(seller_id),
    shipping_limit_date  timestamp,
    price                numeric(10,2) NOT NULL,
    freight_value        numeric(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id              text NOT NULL REFERENCES orders(order_id),
    payment_sequential    integer NOT NULL,
    payment_type          text NOT NULL,
    payment_installments  integer,
    payment_value         numeric(10,2) NOT NULL,
    PRIMARY KEY (order_id, payment_sequential)
);