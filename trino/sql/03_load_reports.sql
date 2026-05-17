DROP TABLE IF EXISTS clickhouse.reports.rpt_sales_by_product;
DROP TABLE IF EXISTS clickhouse.reports.rpt_sales_by_customer;
DROP TABLE IF EXISTS clickhouse.reports.rpt_sales_by_time;
DROP TABLE IF EXISTS clickhouse.reports.rpt_sales_by_store;
DROP TABLE IF EXISTS clickhouse.reports.rpt_sales_by_supplier;
DROP TABLE IF EXISTS clickhouse.reports.rpt_product_quality;

CREATE TABLE clickhouse.reports.rpt_sales_by_product (
    report_section VARCHAR,
    rank_in_section INTEGER,
    product_name VARCHAR,
    product_category VARCHAR,
    total_quantity BIGINT,
    revenue DECIMAL(18, 2),
    avg_product_rating DOUBLE,
    total_reviews BIGINT
);

CREATE TABLE clickhouse.reports.rpt_sales_by_customer (
    report_section VARCHAR,
    rank_in_section INTEGER,
    customer_email VARCHAR,
    customer_first_name VARCHAR,
    customer_last_name VARCHAR,
    customer_country VARCHAR,
    country_customer_count BIGINT,
    country_share_pct DOUBLE,
    total_revenue DECIMAL(18, 2),
    order_count BIGINT,
    avg_check DECIMAL(18, 2)
);

CREATE TABLE clickhouse.reports.rpt_sales_by_time (
    report_section VARCHAR,
    cal_year INTEGER,
    cal_month INTEGER,
    revenue DECIMAL(18, 2),
    order_count BIGINT,
    avg_order_value DECIMAL(18, 2),
    compare_year_low INTEGER,
    compare_year_high INTEGER,
    revenue_year_low DECIMAL(18, 2),
    revenue_year_high DECIMAL(18, 2),
    revenue_change_pct DOUBLE
);

CREATE TABLE clickhouse.reports.rpt_sales_by_store (
    report_section VARCHAR,
    rank_in_section INTEGER,
    store_name VARCHAR,
    store_city VARCHAR,
    store_country VARCHAR,
    geo_city VARCHAR,
    geo_country VARCHAR,
    revenue DECIMAL(18, 2),
    order_count BIGINT,
    avg_check DECIMAL(18, 2)
);

CREATE TABLE clickhouse.reports.rpt_sales_by_supplier (
    report_section VARCHAR,
    rank_in_section INTEGER,
    supplier_name VARCHAR,
    supplier_country VARCHAR,
    revenue DECIMAL(18, 2),
    avg_product_price DECIMAL(18, 2),
    revenue_share_in_country_pct DOUBLE
);

CREATE TABLE clickhouse.reports.rpt_product_quality (
    report_section VARCHAR,
    rank_in_section INTEGER,
    product_name VARCHAR,
    product_category VARCHAR,
    extreme_kind VARCHAR,
    avg_rating DOUBLE,
    total_reviews BIGINT,
    total_units_sold BIGINT,
    corr_rating_vs_units DOUBLE,
    rating_popularity_bucket VARCHAR
);

-- 1) Витрина по продуктам
INSERT INTO clickhouse.reports.rpt_sales_by_product
SELECT
    report_section,
    rank_in_section,
    product_name,
    product_category,
    total_quantity,
    revenue,
    avg_product_rating,
    total_reviews
FROM (
    SELECT
        'top10_by_units' AS report_section,
        CAST(row_number() OVER (ORDER BY sum_qty DESC) AS INTEGER) AS rank_in_section,
        product_name,
        product_category,
        sum_qty AS total_quantity,
        rev AS revenue,
        CAST(NULL AS DOUBLE) AS avg_product_rating,
        CAST(NULL AS BIGINT) AS total_reviews
    FROM (
        SELECT
            p.product_name,
            arbitrary(p.product_category) AS product_category,
            CAST(sum(f.quantity) AS BIGINT) AS sum_qty,
            CAST(sum(f.total_price) AS DECIMAL(18, 2)) AS rev
        FROM clickhouse.dwh.fact_sales f
        INNER JOIN clickhouse.dwh.dim_products p ON f.product_id = p.product_id
        GROUP BY p.product_name
    ) x
) t
WHERE rank_in_section <= 10;

INSERT INTO clickhouse.reports.rpt_sales_by_product
SELECT
    'revenue_by_category' AS report_section,
    CAST(NULL AS INTEGER) AS rank_in_section,
    CAST(NULL AS VARCHAR) AS product_name,
    p.product_category AS product_category,
    CAST(sum(f.quantity) AS BIGINT) AS total_quantity,
    CAST(sum(f.total_price) AS DECIMAL(18, 2)) AS revenue,
    CAST(NULL AS DOUBLE) AS avg_product_rating,
    CAST(NULL AS BIGINT) AS total_reviews
FROM clickhouse.dwh.fact_sales f
INNER JOIN clickhouse.dwh.dim_products p ON f.product_id = p.product_id
GROUP BY p.product_category;

INSERT INTO clickhouse.reports.rpt_sales_by_product
SELECT
    'product_avg_rating_and_reviews' AS report_section,
    CAST(NULL AS INTEGER) AS rank_in_section,
    s.product_name,
    arbitrary(s.product_category) AS product_category,
    CAST(NULL AS BIGINT) AS total_quantity,
    CAST(NULL AS DECIMAL(18, 2)) AS revenue,
    avg(CAST(s.product_rating AS DOUBLE)) AS avg_product_rating,
    CAST(sum(CAST(s.product_reviews AS BIGINT)) AS BIGINT) AS total_reviews
FROM clickhouse.dwh.stg_raw_union s
GROUP BY s.product_name;

-- 2) Витрина по клиентам
INSERT INTO clickhouse.reports.rpt_sales_by_customer
SELECT
    report_section,
    rank_in_section,
    customer_email,
    customer_first_name,
    customer_last_name,
    customer_country,
    country_customer_count,
    country_share_pct,
    total_revenue,
    order_count,
    avg_check
FROM (
    SELECT
        'top10_by_spend' AS report_section,
        CAST(row_number() OVER (ORDER BY spent DESC) AS INTEGER) AS rank_in_section,
        customer_email,
        customer_first_name,
        customer_last_name,
        customer_country,
        CAST(NULL AS BIGINT) AS country_customer_count,
        CAST(NULL AS DOUBLE) AS country_share_pct,
        spent AS total_revenue,
        order_cnt AS order_count,
        avg_chk AS avg_check
    FROM (
        SELECT
            c.customer_email,
            arbitrary(c.customer_first_name) AS customer_first_name,
            arbitrary(c.customer_last_name) AS customer_last_name,
            arbitrary(c.customer_country) AS customer_country,
            CAST(sum(f.total_price) AS DECIMAL(18, 2)) AS spent,
            CAST(count(*) AS BIGINT) AS order_cnt,
            CAST(round(avg(f.total_price), 2) AS DECIMAL(18, 2)) AS avg_chk
        FROM clickhouse.dwh.fact_sales f
        INNER JOIN clickhouse.dwh.dim_customers c ON f.customer_id = c.customer_id
        GROUP BY c.customer_email
    ) u0
) u
WHERE rank_in_section <= 10;

INSERT INTO clickhouse.reports.rpt_sales_by_customer
SELECT *
FROM (
    SELECT
        'customer_distribution_by_country' AS report_section,
        CAST(NULL AS INTEGER) AS rank_in_section,
        CAST(NULL AS VARCHAR) AS customer_email,
        CAST(NULL AS VARCHAR) AS customer_first_name,
        CAST(NULL AS VARCHAR) AS customer_last_name,
        customer_country,
        cust_cnt AS country_customer_count,
        CAST(cust_cnt AS DOUBLE) / sum(CAST(cust_cnt AS DOUBLE)) OVER () AS country_share_pct,
        CAST(NULL AS DECIMAL(18, 2)) AS total_revenue,
        CAST(NULL AS BIGINT) AS order_count,
        CAST(NULL AS DECIMAL(18, 2)) AS avg_check
    FROM (
        SELECT customer_country, CAST(count(*) AS BIGINT) AS cust_cnt
        FROM clickhouse.dwh.dim_customers
        GROUP BY customer_country
    ) dc
) v;

INSERT INTO clickhouse.reports.rpt_sales_by_customer
SELECT
    'avg_check_per_customer' AS report_section,
    CAST(NULL AS INTEGER) AS rank_in_section,
    c.customer_email,
    arbitrary(c.customer_first_name) AS customer_first_name,
    arbitrary(c.customer_last_name) AS customer_last_name,
    arbitrary(c.customer_country) AS customer_country,
    CAST(NULL AS BIGINT) AS country_customer_count,
    CAST(NULL AS DOUBLE) AS country_share_pct,
    CAST(sum(f.total_price) AS DECIMAL(18, 2)) AS total_revenue,
    CAST(count(*) AS BIGINT) AS order_count,
    CAST(round(avg(f.total_price), 2) AS DECIMAL(18, 2)) AS avg_check
FROM clickhouse.dwh.fact_sales f
INNER JOIN clickhouse.dwh.dim_customers c ON f.customer_id = c.customer_id
GROUP BY c.customer_email;

-- 3) Витрина по времени
INSERT INTO clickhouse.reports.rpt_sales_by_time
SELECT
    'monthly_trend' AS report_section,
    year(f.sale_date) AS cal_year,
    month(f.sale_date) AS cal_month,
    CAST(sum(f.total_price) AS DECIMAL(18, 2)) AS revenue,
    CAST(count(*) AS BIGINT) AS order_count,
    CAST(round(avg(f.total_price), 2) AS DECIMAL(18, 2)) AS avg_order_value,
    CAST(NULL AS INTEGER) AS compare_year_low,
    CAST(NULL AS INTEGER) AS compare_year_high,
    CAST(NULL AS DECIMAL(18, 2)) AS revenue_year_low,
    CAST(NULL AS DECIMAL(18, 2)) AS revenue_year_high,
    CAST(NULL AS DOUBLE) AS revenue_change_pct
FROM clickhouse.dwh.fact_sales f
GROUP BY year(f.sale_date), month(f.sale_date);

INSERT INTO clickhouse.reports.rpt_sales_by_time
SELECT
    'yearly_trend' AS report_section,
    year(f.sale_date) AS cal_year,
    CAST(NULL AS INTEGER) AS cal_month,
    CAST(sum(f.total_price) AS DECIMAL(18, 2)) AS revenue,
    CAST(count(*) AS BIGINT) AS order_count,
    CAST(round(avg(f.total_price), 2) AS DECIMAL(18, 2)) AS avg_order_value,
    CAST(NULL AS INTEGER) AS compare_year_low,
    CAST(NULL AS INTEGER) AS compare_year_high,
    CAST(NULL AS DECIMAL(18, 2)) AS revenue_year_low,
    CAST(NULL AS DECIMAL(18, 2)) AS revenue_year_high,
    CAST(NULL AS DOUBLE) AS revenue_change_pct
FROM clickhouse.dwh.fact_sales f
GROUP BY year(f.sale_date);

INSERT INTO clickhouse.reports.rpt_sales_by_time
SELECT
    'compare_min_vs_max_year_revenue' AS report_section,
    CAST(NULL AS INTEGER) AS cal_year,
    CAST(NULL AS INTEGER) AS cal_month,
    CAST(NULL AS DECIMAL(18, 2)) AS revenue,
    CAST(NULL AS BIGINT) AS order_count,
    CAST(NULL AS DECIMAL(18, 2)) AS avg_order_value,
    (SELECT min(year(sale_date)) FROM clickhouse.dwh.fact_sales) AS compare_year_low,
    (SELECT max(year(sale_date)) FROM clickhouse.dwh.fact_sales) AS compare_year_high,
    CAST((
        SELECT sum(total_price)
        FROM clickhouse.dwh.fact_sales
        WHERE year(sale_date) = (SELECT min(year(sale_date)) FROM clickhouse.dwh.fact_sales)
    ) AS DECIMAL(18, 2)) AS revenue_year_low,
    CAST((
        SELECT sum(total_price)
        FROM clickhouse.dwh.fact_sales
        WHERE year(sale_date) = (SELECT max(year(sale_date)) FROM clickhouse.dwh.fact_sales)
    ) AS DECIMAL(18, 2)) AS revenue_year_high,
    CAST(
        (
            (SELECT sum(total_price) FROM clickhouse.dwh.fact_sales WHERE year(sale_date) = (SELECT max(year(sale_date)) FROM clickhouse.dwh.fact_sales))
            - (SELECT sum(total_price) FROM clickhouse.dwh.fact_sales WHERE year(sale_date) = (SELECT min(year(sale_date)) FROM clickhouse.dwh.fact_sales))
        ) AS DOUBLE
    )
    / nullif(
        CAST((SELECT sum(total_price) FROM clickhouse.dwh.fact_sales WHERE year(sale_date) = (SELECT min(year(sale_date)) FROM clickhouse.dwh.fact_sales)) AS DOUBLE),
        0
    )
    * 100 AS revenue_change_pct;

-- 4) Витрина по магазинам
INSERT INTO clickhouse.reports.rpt_sales_by_store
SELECT
    report_section,
    rank_in_section,
    store_name,
    store_city,
    store_country,
    geo_city,
    geo_country,
    revenue,
    order_count,
    avg_check
FROM (
    SELECT
        'top5_by_revenue' AS report_section,
        CAST(row_number() OVER (ORDER BY rev DESC) AS INTEGER) AS rank_in_section,
        store_name,
        store_city,
        store_country,
        CAST(NULL AS VARCHAR) AS geo_city,
        CAST(NULL AS VARCHAR) AS geo_country,
        rev AS revenue,
        oc AS order_count,
        ac AS avg_check
    FROM (
        SELECT
            st.store_name,
            arbitrary(st.store_city) AS store_city,
            arbitrary(st.store_country) AS store_country,
            CAST(sum(f.total_price) AS DECIMAL(18, 2)) AS rev,
            CAST(count(*) AS BIGINT) AS oc,
            CAST(round(avg(f.total_price), 2) AS DECIMAL(18, 2)) AS ac
        FROM clickhouse.dwh.fact_sales f
        INNER JOIN clickhouse.dwh.dim_stores st ON f.store_id = st.store_id
        GROUP BY st.store_name
    ) q
) r
WHERE rank_in_section <= 5;

INSERT INTO clickhouse.reports.rpt_sales_by_store
SELECT
    'sales_geo_by_city' AS report_section,
    CAST(NULL AS INTEGER) AS rank_in_section,
    CAST(NULL AS VARCHAR) AS store_name,
    CAST(NULL AS VARCHAR) AS store_city,
    CAST(NULL AS VARCHAR) AS store_country,
    st.store_city AS geo_city,
    st.store_country AS geo_country,
    CAST(sum(f.total_price) AS DECIMAL(18, 2)) AS revenue,
    CAST(count(*) AS BIGINT) AS order_count,
    CAST(round(avg(f.total_price), 2) AS DECIMAL(18, 2)) AS avg_check
FROM clickhouse.dwh.fact_sales f
INNER JOIN clickhouse.dwh.dim_stores st ON f.store_id = st.store_id
GROUP BY st.store_city, st.store_country;

INSERT INTO clickhouse.reports.rpt_sales_by_store
SELECT
    'avg_check_per_store' AS report_section,
    CAST(NULL AS INTEGER) AS rank_in_section,
    st.store_name,
    arbitrary(st.store_city) AS store_city,
    arbitrary(st.store_country) AS store_country,
    CAST(NULL AS VARCHAR) AS geo_city,
    CAST(NULL AS VARCHAR) AS geo_country,
    CAST(sum(f.total_price) AS DECIMAL(18, 2)) AS revenue,
    CAST(count(*) AS BIGINT) AS order_count,
    CAST(round(avg(f.total_price), 2) AS DECIMAL(18, 2)) AS avg_check
FROM clickhouse.dwh.fact_sales f
INNER JOIN clickhouse.dwh.dim_stores st ON f.store_id = st.store_id
GROUP BY st.store_name;

-- 5) Витрина по поставщикам
INSERT INTO clickhouse.reports.rpt_sales_by_supplier
SELECT
    report_section,
    rank_in_section,
    supplier_name,
    supplier_country,
    revenue,
    avg_product_price,
    revenue_share_in_country_pct
FROM (
    SELECT
        'top5_by_revenue' AS report_section,
        CAST(row_number() OVER (ORDER BY rev DESC) AS INTEGER) AS rank_in_section,
        supplier_name,
        supplier_country,
        rev AS revenue,
        avg_p AS avg_product_price,
        CAST(NULL AS DOUBLE) AS revenue_share_in_country_pct
    FROM (
        SELECT
            sup.supplier_name,
            arbitrary(sup.supplier_country) AS supplier_country,
            CAST(sum(f.total_price) AS DECIMAL(18, 2)) AS rev,
            CAST(round(avg(p.product_price), 2) AS DECIMAL(18, 2)) AS avg_p
        FROM clickhouse.dwh.fact_sales f
        INNER JOIN clickhouse.dwh.dim_products p ON f.product_id = p.product_id
        INNER JOIN clickhouse.dwh.dim_suppliers sup ON p.supplier_id = sup.supplier_id
        GROUP BY sup.supplier_name
    ) q
) r
WHERE rank_in_section <= 5;

INSERT INTO clickhouse.reports.rpt_sales_by_supplier
SELECT
    'avg_catalog_price' AS report_section,
    CAST(NULL AS INTEGER) AS rank_in_section,
    sup.supplier_name,
    arbitrary(sup.supplier_country) AS supplier_country,
    CAST(NULL AS DECIMAL(18, 2)) AS revenue,
    CAST(round(avg(p.product_price), 2) AS DECIMAL(18, 2)) AS avg_product_price,
    CAST(NULL AS DOUBLE) AS revenue_share_in_country_pct
FROM clickhouse.dwh.dim_products p
INNER JOIN clickhouse.dwh.dim_suppliers sup ON p.supplier_id = sup.supplier_id
GROUP BY sup.supplier_name;

INSERT INTO clickhouse.reports.rpt_sales_by_supplier
SELECT
    'revenue_mix_by_supplier_country' AS report_section,
    CAST(NULL AS INTEGER) AS rank_in_section,
    CAST(NULL AS VARCHAR) AS supplier_name,
    g.supplier_country AS supplier_country,
    g.revenue AS revenue,
    CAST(NULL AS DECIMAL(18, 2)) AS avg_product_price,
    CAST(g.revenue AS DOUBLE) / sum(CAST(g.revenue AS DOUBLE)) OVER () * 100 AS revenue_share_in_country_pct
FROM (
    SELECT
        sup.supplier_country AS supplier_country,
        CAST(sum(f.total_price) AS DECIMAL(18, 2)) AS revenue
    FROM clickhouse.dwh.fact_sales f
    INNER JOIN clickhouse.dwh.dim_products p ON f.product_id = p.product_id
    INNER JOIN clickhouse.dwh.dim_suppliers sup ON p.supplier_id = sup.supplier_id
    GROUP BY sup.supplier_country
) g;

-- 6) Качество продукции
INSERT INTO clickhouse.reports.rpt_product_quality
SELECT
    'extreme_avg_rating' AS report_section,
    CAST(NULL AS INTEGER) AS rank_in_section,
    z.product_name,
    z.product_category,
    CASE
        WHEN avg_rating = (SELECT max(avg_rating) FROM (SELECT avg(CAST(product_rating AS DOUBLE)) AS avg_rating FROM clickhouse.dwh.stg_raw_union GROUP BY product_name)) THEN 'highest_avg_rating'
        WHEN avg_rating = (SELECT min(avg_rating) FROM (SELECT avg(CAST(product_rating AS DOUBLE)) AS avg_rating FROM clickhouse.dwh.stg_raw_union GROUP BY product_name)) THEN 'lowest_avg_rating'
    END AS extreme_kind,
    avg_rating AS avg_rating,
    CAST(NULL AS BIGINT) AS total_reviews,
    CAST(NULL AS BIGINT) AS total_units_sold,
    CAST(NULL AS DOUBLE) AS corr_rating_vs_units,
    CAST(NULL AS VARCHAR) AS rating_popularity_bucket
FROM (
    SELECT
        product_name,
        arbitrary(product_category) AS product_category,
        avg(CAST(product_rating AS DOUBLE)) AS avg_rating
    FROM clickhouse.dwh.stg_raw_union
    GROUP BY product_name
) z
WHERE avg_rating = (SELECT max(avg_rating) FROM (SELECT avg(CAST(product_rating AS DOUBLE)) AS avg_rating FROM clickhouse.dwh.stg_raw_union GROUP BY product_name))
   OR avg_rating = (SELECT min(avg_rating) FROM (SELECT avg(CAST(product_rating AS DOUBLE)) AS avg_rating FROM clickhouse.dwh.stg_raw_union GROUP BY product_name));

INSERT INTO clickhouse.reports.rpt_product_quality
SELECT
    'rating_vs_volume_correlation' AS report_section,
    CAST(NULL AS INTEGER) AS rank_in_section,
    CAST(NULL AS VARCHAR) AS product_name,
    CAST(NULL AS VARCHAR) AS product_category,
    CAST(NULL AS VARCHAR) AS extreme_kind,
    CAST(NULL AS DOUBLE) AS avg_rating,
    CAST(NULL AS BIGINT) AS total_reviews,
    CAST(NULL AS BIGINT) AS total_units_sold,
    corr(agg.avg_rating, CAST(agg.total_units AS DOUBLE)) AS corr_rating_vs_units,
    CAST(NULL AS VARCHAR) AS rating_popularity_bucket
FROM (
    SELECT
        s.product_name,
        avg(CAST(s.product_rating AS DOUBLE)) AS avg_rating,
        sum(CAST(s.sale_quantity AS BIGINT)) AS total_units
    FROM clickhouse.dwh.stg_raw_union s
    GROUP BY s.product_name
) agg;

INSERT INTO clickhouse.reports.rpt_product_quality
SELECT
    report_section,
    rank_in_section,
    product_name,
    product_category,
    CAST(NULL AS VARCHAR) AS extreme_kind,
    CAST(NULL AS DOUBLE) AS avg_rating,
    total_reviews,
    CAST(NULL AS BIGINT) AS total_units_sold,
    CAST(NULL AS DOUBLE) AS corr_rating_vs_units,
    CAST(NULL AS VARCHAR) AS rating_popularity_bucket
FROM (
    SELECT
        'top_by_review_count' AS report_section,
        CAST(row_number() OVER (ORDER BY u.total_reviews DESC) AS INTEGER) AS rank_in_section,
        u.product_name,
        u.product_category,
        u.total_reviews
    FROM (
        SELECT
            product_name,
            arbitrary(product_category) AS product_category,
            CAST(sum(CAST(product_reviews AS BIGINT)) AS BIGINT) AS total_reviews
        FROM clickhouse.dwh.stg_raw_union
        GROUP BY product_name
    ) u
) t
WHERE rank_in_section <= 10;

-- Кросс-анализ: «корзина» по совокупному рейтингу и популярности (доп. срез к корреляции)
INSERT INTO clickhouse.reports.rpt_product_quality
WITH
    s AS (
        SELECT
            product_name,
            avg(CAST(product_rating AS DOUBLE)) AS avg_rating,
            sum(CAST(sale_quantity AS BIGINT)) AS units
        FROM clickhouse.dwh.stg_raw_union
        GROUP BY product_name
    ),
    stats AS (
        SELECT avg(avg_rating) AS mean_rating, avg(CAST(units AS DOUBLE)) AS mean_units
        FROM s
    ),
    b AS (
        SELECT
            s.product_name,
            s.avg_rating,
            s.units,
            CASE
                WHEN s.avg_rating >= st.mean_rating AND CAST(s.units AS DOUBLE) >= st.mean_units THEN 'high_rating_high_volume'
                WHEN s.avg_rating >= st.mean_rating AND CAST(s.units AS DOUBLE) < st.mean_units THEN 'high_rating_low_volume'
                WHEN s.avg_rating < st.mean_rating AND CAST(s.units AS DOUBLE) >= st.mean_units THEN 'low_rating_high_volume'
                ELSE 'low_rating_low_volume'
            END AS rating_popularity_bucket
        FROM s
        CROSS JOIN stats st
    )
SELECT
    'rating_popularity_quadrants' AS report_section,
    CAST(NULL AS INTEGER) AS rank_in_section,
    product_name,
    CAST(NULL AS VARCHAR) AS product_category,
    CAST(NULL AS VARCHAR) AS extreme_kind,
    avg_rating,
    CAST(NULL AS BIGINT) AS total_reviews,
    units AS total_units_sold,
    CAST(NULL AS DOUBLE) AS corr_rating_vs_units,
    rating_popularity_bucket
FROM b;
