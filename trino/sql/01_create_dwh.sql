DROP TABLE IF EXISTS clickhouse.dwh.stg_raw_union;
DROP TABLE IF EXISTS clickhouse.dwh.fact_sales;
DROP TABLE IF EXISTS clickhouse.dwh.dim_pets;
DROP TABLE IF EXISTS clickhouse.dwh.dim_products;
DROP TABLE IF EXISTS clickhouse.dwh.dim_sellers;
DROP TABLE IF EXISTS clickhouse.dwh.dim_customers;
DROP TABLE IF EXISTS clickhouse.dwh.dim_stores;
DROP TABLE IF EXISTS clickhouse.dwh.dim_suppliers;

CREATE TABLE clickhouse.dwh.dim_suppliers (
    supplier_id BIGINT,
    supplier_name VARCHAR,
    supplier_contact VARCHAR,
    supplier_email VARCHAR,
    supplier_phone VARCHAR,
    supplier_address VARCHAR,
    supplier_city VARCHAR,
    supplier_country VARCHAR
);

CREATE TABLE clickhouse.dwh.dim_stores (
    store_id BIGINT,
    store_name VARCHAR,
    store_location VARCHAR,
    store_city VARCHAR,
    store_state VARCHAR,
    store_country VARCHAR,
    store_phone VARCHAR,
    store_email VARCHAR
);

CREATE TABLE clickhouse.dwh.dim_customers (
    customer_id BIGINT,
    customer_first_name VARCHAR,
    customer_last_name VARCHAR,
    customer_email VARCHAR,
    customer_age INTEGER,
    customer_country VARCHAR,
    customer_postal_code VARCHAR
);

CREATE TABLE clickhouse.dwh.dim_sellers (
    seller_id BIGINT,
    seller_first_name VARCHAR,
    seller_last_name VARCHAR,
    seller_email VARCHAR,
    store_id BIGINT
);

CREATE TABLE clickhouse.dwh.dim_products (
    product_id BIGINT,
    product_name VARCHAR,
    product_category VARCHAR,
    product_brand VARCHAR,
    product_price DECIMAL(18, 2),
    supplier_id BIGINT
);

CREATE TABLE clickhouse.dwh.dim_pets (
    pet_id BIGINT,
    pet_name VARCHAR,
    pet_type VARCHAR,
    pet_breed VARCHAR,
    customer_id BIGINT
);

CREATE TABLE clickhouse.dwh.fact_sales (
    sale_id BIGINT,
    sale_date DATE,
    customer_id BIGINT,
    seller_id BIGINT,
    product_id BIGINT,
    store_id BIGINT,
    quantity INTEGER,
    total_price DECIMAL(18, 2)
);
