
USE Brazil_ecom;
GO

/*====================================================
BRAZILIAN E-COMMERCE ANALYSIS (OLIST DATASET)
====================================================*/

/*====================================================
SECTION 1: BUSINESS KPIs
====================================================*/

-- Total Orders
SELECT COUNT(DISTINCT order_id) AS total_orders
FROM orders_dataset;

-- Total Revenue
SELECT SUM(payment_value) AS total_revenue
FROM order_payments;

-- Total Customers
SELECT COUNT(DISTINCT customer_id) AS total_customers
FROM customers_dataset;

-- Average Revenue Per Order
SELECT
    SUM(payment_value) / COUNT(DISTINCT order_id) AS avg_revenue_per_order
FROM order_payments;

/*====================================================
SECTION 2: CUSTOMER ANALYSIS
====================================================*/

-- Top 10 States by Customers
SELECT TOP 10
    customer_state,
    COUNT(*) AS total_customers
FROM customers_dataset
GROUP BY customer_state
ORDER BY total_customers DESC;

-- Repeat Customer Rate
WITH customer_orders AS
(
    SELECT
        c.customer_unique_id,
        COUNT(o.order_id) AS order_count
    FROM customers_dataset c
    JOIN orders_dataset o
        ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    ROUND(
        COUNT(CASE WHEN order_count > 1 THEN 1 END) * 100.0
        / COUNT(*),2
    ) AS repeat_customer_rate
FROM customer_orders;

-- Customer Segmentation
SELECT
    o.customer_id,
    SUM(op.payment_value) AS total_spending,
    CASE
        WHEN SUM(op.payment_value) > 500 THEN 'HIGH_VALUE'
        WHEN SUM(op.payment_value) BETWEEN 100 AND 500 THEN 'MEDIUM_VALUE'
        ELSE 'LOW_VALUE'
    END AS customer_segment
FROM orders_dataset o
JOIN order_payments op
    ON o.order_id = op.order_id
GROUP BY o.customer_id;

-- Customers Above Average Spending
WITH customer_spending AS
(
    SELECT
        o.customer_id,
        SUM(op.payment_value) AS total_spending
    FROM orders_dataset o
    JOIN order_payments op
        ON o.order_id = op.order_id
    GROUP BY o.customer_id
)
SELECT *
FROM customer_spending
WHERE total_spending >
(
    SELECT AVG(total_spending)
    FROM customer_spending
);

/*====================================================
SECTION 3: ORDER ANALYSIS
====================================================*/

-- Monthly Order Trend
SELECT
    YEAR(order_purchase_timestamp) AS order_year,
    MONTH(order_purchase_timestamp) AS order_month,
    COUNT(order_id) AS total_orders
FROM orders_dataset
GROUP BY YEAR(order_purchase_timestamp),
         MONTH(order_purchase_timestamp)
ORDER BY order_year, order_month;

-- Orders Delivered Late
SELECT
    order_id,
    order_delivered_customer_date,
    order_estimated_delivery_date
FROM orders_dataset
WHERE order_delivered_customer_date >
      order_estimated_delivery_date;

-- Orders Delivered Early
SELECT
    order_id,
    DATEDIFF(
        DAY,
        order_delivered_customer_date,
        order_estimated_delivery_date
    ) AS early_delivery_days
FROM orders_dataset
WHERE order_delivered_customer_date <
      order_estimated_delivery_date;

/*====================================================
SECTION 4: REVENUE ANALYSIS
====================================================*/

-- Top 10 Sellers by Revenue
SELECT TOP 10
    seller_id,
    SUM(price) AS total_revenue
FROM order_items_dataset
GROUP BY seller_id
ORDER BY total_revenue DESC;

-- Top Product Categories by Revenue
SELECT TOP 10
    p.product_category_name,
    SUM(oi.price) AS revenue
FROM order_items_dataset oi
JOIN products_dataset_new p
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY revenue DESC;

-- Revenue by State
SELECT
    c.customer_state,
    SUM(op.payment_value) AS total_revenue
FROM customers_dataset c
JOIN orders_dataset o
    ON c.customer_id = o.customer_id
JOIN order_payments op
    ON o.order_id = op.order_id
GROUP BY c.customer_state
ORDER BY total_revenue DESC;

/*====================================================
SECTION 5: DELIVERY ANALYSIS
====================================================*/

-- Average Delivery Time by State
SELECT
    c.customer_state,
    ROUND(
        AVG(
            DATEDIFF(
                DAY,
                o.order_purchase_timestamp,
                o.order_delivered_customer_date
            )
        ),2
    ) AS avg_delivery_time
FROM orders_dataset o
JOIN customers_dataset c
    ON o.customer_id = c.customer_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state;

-- Delayed Delivery Percentage
SELECT
    ROUND(
        COUNT(
            CASE
                WHEN order_delivered_customer_date >
                     order_estimated_delivery_date
                THEN 1
            END
        ) * 100.0 / COUNT(*),2
    ) AS delayed_delivery_percentage
FROM orders_dataset;

/*====================================================
SECTION 6: REVIEWS ANALYSIS
====================================================*/

-- Seller-wise Average Review Score
SELECT
    oi.seller_id,
    ROUND(AVG(r.review_score),2) AS avg_review_score
FROM order_reviews r
JOIN order_items_dataset oi
    ON r.order_id = oi.order_id
GROUP BY oi.seller_id;

-- Category-wise Average Review Score
SELECT
    p.product_category_name,
    ROUND(AVG(r.review_score),2) AS avg_review_score
FROM order_reviews r
JOIN order_items_dataset oi
    ON r.order_id = oi.order_id
JOIN products_dataset_new p
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name;

/*====================================================
SECTION 7: WINDOW FUNCTIONS
====================================================*/

-- Cumulative Monthly Revenue
WITH monthly_revenue AS
(
    SELECT
        YEAR(o.order_purchase_timestamp) AS order_year,
        MONTH(o.order_purchase_timestamp) AS order_month,
        SUM(oi.price) AS monthly_revenue
    FROM orders_dataset o
    JOIN order_items_dataset oi
        ON o.order_id = oi.order_id
    GROUP BY YEAR(o.order_purchase_timestamp),
             MONTH(o.order_purchase_timestamp)
)
SELECT
    *,
    SUM(monthly_revenue)
    OVER(ORDER BY order_year, order_month)
    AS cumulative_revenue
FROM monthly_revenue;

-- Top 3 Products in Each Category
WITH product_sales AS
(
    SELECT
        p.product_category_name,
        oi.product_id,
        SUM(oi.price) AS total_sales
    FROM order_items_dataset oi
    JOIN products_dataset_new p
        ON oi.product_id = p.product_id
    GROUP BY p.product_category_name,
             oi.product_id
),
ranked_products AS
(
    SELECT *,
           RANK() OVER(
               PARTITION BY product_category_name
               ORDER BY total_sales DESC
           ) AS product_rank
    FROM product_sales
)
SELECT *
FROM ranked_products
WHERE product_rank <= 3;

/*====================================================
SECTION 8: CUSTOMER LIFETIME VALUE (CLV)
====================================================*/

-- Top 10 Customers by Lifetime Spending

SELECT TOP 10
       c.customer_unique_id,
       SUM(op.payment_value) AS total_spent
FROM customers_dataset c
JOIN orders_dataset o
    ON c.customer_id = o.customer_id
JOIN order_payments op
    ON o.order_id = op.order_id
GROUP BY c.customer_unique_id
ORDER BY total_spent DESC;

-- Average Customer Lifetime Value

WITH customer_revenue AS
(
    SELECT
        c.customer_unique_id,
        SUM(op.payment_value) AS lifetime_value
    FROM customers_dataset c
    JOIN orders_dataset o
        ON c.customer_id = o.customer_id
    JOIN order_payments op
        ON o.order_id = op.order_id
    GROUP BY c.customer_unique_id
)
SELECT
    ROUND(AVG(lifetime_value),2) AS avg_customer_lifetime_value
FROM customer_revenue;

/*====================================================
SECTION 9: REVENUE CONTRIBUTION ANALYSIS
====================================================*/

-- Revenue Contribution Percentage by State

WITH state_revenue AS
(
    SELECT
        c.customer_state,
        SUM(op.payment_value) AS revenue
    FROM customers_dataset c
    JOIN orders_dataset o
        ON c.customer_id = o.customer_id
    JOIN order_payments op
        ON o.order_id = op.order_id
    GROUP BY c.customer_state
)

SELECT
    customer_state,
    revenue,
    ROUND(
        revenue * 100.0 /
        SUM(revenue) OVER(),
        2
    ) AS revenue_percentage
FROM state_revenue
ORDER BY revenue DESC;

/*====================================================
SECTION 10: DELIVERY PERFORMANCE ANALYSIS
====================================================*/

-- On-Time Delivery Percentage

SELECT
    ROUND(
        COUNT(
            CASE
                WHEN order_delivered_customer_date
                     <= order_estimated_delivery_date
                THEN 1
            END
        ) * 100.0 /
        COUNT(*),
        2
    ) AS on_time_delivery_percentage
FROM orders_dataset
WHERE order_delivered_customer_date IS NOT NULL;

-- Delivery Time Distribution

SELECT
    CASE
        WHEN DATEDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
             ) <= 5
             THEN '0-5 Days'

        WHEN DATEDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
             ) <= 10
             THEN '6-10 Days'

        WHEN DATEDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
             ) <= 15
             THEN '11-15 Days'

        WHEN DATEDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
             ) <= 20
             THEN '16-20 Days'

        WHEN DATEDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
             ) <= 30
             THEN '21-30 Days'

        ELSE 'More than 30 Days'
    END AS delivery_bucket,

    COUNT(*) AS total_orders

FROM orders_dataset

WHERE order_delivered_customer_date IS NOT NULL

GROUP BY
    CASE
        WHEN DATEDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
             ) <= 5
             THEN '0-5 Days'

        WHEN DATEDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
             ) <= 10
             THEN '6-10 Days'

        WHEN DATEDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
             ) <= 15
             THEN '11-15 Days'

        WHEN DATEDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
             ) <= 20
             THEN '16-20 Days'

        WHEN DATEDIFF(
                DAY,
                order_purchase_timestamp,
                order_delivered_customer_date
             ) <= 30
             THEN '21-30 Days'

        ELSE 'More than 30 Days'
    END

ORDER BY total_orders DESC;