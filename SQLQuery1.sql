/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    This script creates a new database named 'DataWarehouseAnalytics' after checking if it already exists. 
    If the database exists, it is dropped and recreated. Additionally, this script creates a schema called gold
	
WARNING:
    Running this script will drop the entire 'DataWarehouseAnalytics' database if it exists. 
    All data in the database will be permanently deleted. Proceed with caution 
    and ensure you have proper backups before running this script.
*/

USE master;
GO

-- Drop and recreate the 'DataWarehouseAnalytics' database
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouseAnalytics')
BEGIN
    ALTER DATABASE DataWarehouseAnalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouseAnalytics;
END;
GO

-- Create the 'DataWarehouseAnalytics' database
CREATE DATABASE DataWarehouseAnalytics;
GO

USE DataWarehouseAnalytics;
GO

-- Create Schemas

CREATE SCHEMA gold;
GO

CREATE TABLE gold.dim_customers(
	customer_key int,
	customer_id int,
	customer_number nvarchar(50),
	first_name nvarchar(50),
	last_name nvarchar(50),
	country nvarchar(50),
	marital_status nvarchar(50),
	gender nvarchar(50),
	birthdate date,
	create_date date
);
GO

CREATE TABLE gold.dim_products(
	product_key int ,
	product_id int ,
	product_number nvarchar(50) ,
	product_name nvarchar(50) ,
	category_id nvarchar(50) ,
	category nvarchar(50) ,
	subcategory nvarchar(50) ,
	maintenance nvarchar(50) ,
	cost int,
	product_line nvarchar(50),
	start_date date 
);
GO

CREATE TABLE gold.fact_sales(
	order_number nvarchar(50),
	product_key int,
	customer_key int,
	order_date date,
	shipping_date date,
	due_date date,
	sales_amount int,
	quantity tinyint,
	price int 
);
GO

TRUNCATE TABLE gold.dim_customers;
GO

BULK INSERT gold.dim_customers
FROM 'D:\sql\sql-data-analytics-project\datasets\csv-files\gold.dim_customers.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	TABLOCK
);
GO

TRUNCATE TABLE gold.dim_products;
GO

BULK INSERT gold.dim_products
FROM 'D:\sql\sql-data-analytics-project\datasets\csv-files\gold.dim_products.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	TABLOCK
);
GO

TRUNCATE TABLE gold.fact_sales;
GO

BULK INSERT gold.fact_sales
FROM 'D:\sql\sql-data-analytics-project\datasets\csv-files\gold.fact_sales.csv'
WITH (
	FIRSTROW = 2,
	FIELDTERMINATOR = ',',
	TABLOCK
);
GO

SELECT 
YEAR(order_date) as order_year,
MONTH(order_date) as order_month,
SUM(sales_amount) as total_Sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date)

SELECT 
DATETRUNC(MONTH, order_date) as order_date,
SUM(sales_amount) as total_Sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
ORDER BY DATETRUNC(MONTH, order_date)

-- Calculate the total sales per month
-- and the running total of sales over time

SELECT
order_date,
total_sales,
SUM(total_sales) OVER (PARTITION BY order_date ORDER BY order_date) AS running_total_sales,
AVG(avg_price) OVER (ORDER BY order_date) AS moving_average_price
-- window functiom
FROM 
(
SELECT
DATETRUNC(MONTH, order_date) AS order_date,
SUM(sales_amount) AS total_sales,
AVG(price) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
) t

/* Analyze the yearly performance of products by comparing their sales
to bith the average salees performance of the product and the previous year's sales */

;WITH yearly_product_sales AS (
SELECT
YEAR(f.order_date) AS order_year, 
p.product_name,
SUM(f.sales_amount) AS current_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY
YEAR(f.order_date),
p.product_name
)

SELECT
order_year, 
product_name,
current_sales,
AVG(current_sales) OVER  (PARTITION BY product_name) avg_sales,
current_sales - AVG(current_sales) OVER  (PARTITION BY product_name) AS diff_avg,
CASE WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above AVG'
	 WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below AVG'
	 ELSE 'Avg'
END avg_change,
LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) py_sales,
current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_py,
CASE WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
	 WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
	 ELSE 'No change'
END py_change
FROM yearly_product_sales
ORDER BY product_name, order_year;

-- which categories contribute the most to overall sales? 
WITH category_sales AS (
SELECT
category, 
SUM(sales_amount) total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
GROUP BY category)

SELECT
category,
total_sales,
SUM(total_sales) OVER () overall_sales,
CONCAT(ROUND((CAST (total_sales AS FLOAT) / SUM (total_sales) OVER ())*100, 2), '%') AS percentage_of_total 
FROM category_sales
ORDER BY total_sales DESC

/* Segment products into cost rangess and
how many products fall into each segment*/
;WITH product_segments AS (
SELECT
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'Below 100'
	 WHEN cost BETWEEN 100 AND 500 THEN '100-500'
	 WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
	 ELSE 'Above 1000'
END cost_range
FROM gold.dim_products)

SELECT
cost_range, 
COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER By total_products DESC;

/*Group customers into three segments based on their spending behavior 
	- VIP : Customers with at least 12 months of history and spending more than 5000 euros.
	- Regular : Customerd with at least 12 months of history but spending 5000 euros and less
	- New: Customers with a lifespan less than 12 months
And find the total number of customers by each group
*/

WITH customer_spending AS (
SELECT 
c.customer_key, 
SUM(f.sales_amount) AS total_spending, 
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
DATEDIFF (month, MIN(order_date), MAX(order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)

SELECT
customer_segment,
COUNT(customer_key) AS total_customers
FROM(
	SELECT
	customer_key,
	CASE WHEN lifespan > 12 AND total_spending > 5000 THEN 'VIP'
		WHEN lifespan > 12 AND total_spending <= 5000 THEN 'Regular'
		ELSE 'New'
	END customer_segment
	FROM customer_spending ) t
GROUP BY customer_segment
ORDER BY total_customers DESC


/*
CUSTOMER REPORT
Purpose :
	- This report consodilates key customer metrics and behaviors.
Highlights :
	1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers iinto categories (VIP, Regular, New) and age groups.
	3. Aggregates customer-level metrics:
		- total orders
		- total sales 
		- total quantity
		- total quantity purcashed
		- total products
		- lifespan (in months)
	4. Calculates
		- recency (months since last order)
		- average order value 
		- average monthly spend 
	*/
GO
CREATE VIEW gold.report_customer
AS
-- Define CTEs directly after CREATE VIEW (no GO before this)
WITH base_query AS (
    /* 1) Base Query: Retrieve core columns from tables */
    SELECT 
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount, 
        f.quantity,
        c.customer_key,
        c.customer_number,
        CONCAT(c.first_name, ' ', c.birthdate) AS customer_name,
        DATEDIFF(YEAR, c.birthdate, GETDATE()) AS age
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customers c
        ON c.customer_key = f.customer_key
    WHERE f.order_date IS NOT NULL
),
customer_aggregation AS (
    SELECT
        customer_key,
        customer_number,
        customer_name,
        age,
        COUNT(DISTINCT order_number) AS total_orders,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT product_key) AS total_products,
        MAX(order_date) AS last_order_date,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan
    FROM base_query
    GROUP BY 
        customer_key,
        customer_number,
        customer_name,
        age
)
SELECT 
    customer_key,
    customer_number,
    customer_name,
    age,
    CASE 
        WHEN age < 20 THEN 'Under 20'
        WHEN age BETWEEN 20 AND 29 THEN '20-29'
        WHEN age BETWEEN 30 AND 39 THEN '30-39'
        WHEN age BETWEEN 40 AND 49 THEN '40-49'
        ELSE '50 and above'
    END AS age_group,
    CASE
        WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
        WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
        ELSE 'New'
    END AS customer_segment,
    last_order_date,
    DATEDIFF(MONTH, last_order_date, GETDATE()) AS recency,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan,
    -- compute average order value (AOV)
    CASE WHEN total_orders = 0 THEN 0
         ELSE total_sales / total_orders
    END AS avg_order_value,
    -- compute average monthly spend
    CASE WHEN lifespan = 0 THEN total_sales
         ELSE total_sales / lifespan
    END AS avg_monthly_spend
FROM customer_aggregation;
GO

SELECT *
FROM gold.report_customer

/*
PRODUCT REPORT
Purpose :
	- This report consodilates key product metrics and behaviors.
Highlights :
	1. Gathers essential fields such as name, category. subcategory, and cost.
	2. Segments products by revenue to identify High-performers, mid-range, or low performers.
	3. Aggregates product-level metrics:
		- total orders
		- total sales 
		- total quantity sold
		- total quantity customers (unique)
		- lifespan (in months)
	4. Calculates valuabele KPIs:
		- recency (months since last sale)
		- average order revenue (AOR)
		- average monthly revenue
	*/

		
GO
CREATE VIEW gold.report_product
AS
WITH base_query AS (
    /* 1) Base Query: Retrieve core columns from tables */
    SELECT 
        f.order_number,
        f.order_date,
        f.customer_key,
        f.sales_amount,
        f.quantity,
        p.product_key,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_products p
        ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
),
product_aggregation AS (
    SELECT
        product_key,
        product_name,
        category,
        subcategory,
        cost,
        DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS lifespan,
        MAX(order_date) AS last_sale_date,
        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity, 0)), 1) AS avg_selling_price     
    FROM base_query
    GROUP BY 
        product_key,
        product_name,
        category,
        subcategory,
        cost
)
SELECT 
    product_key,
    product_name,
    category,
    subcategory,
    cost, 
    last_sale_date,   
    DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_in_months,
    CASE 
        WHEN total_sales > 50000 THEN 'High-Performer'
        WHEN total_sales >= 10000 THEN 'Mid-Range'
        ELSE 'Low-Performer'
    END AS product_segment,
    lifespan,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    avg_selling_price,  
    -- average order revenue (AOR)
    CASE 
        WHEN total_orders = 0 THEN 0
        ELSE total_sales / total_orders
    END AS avg_order_revenue,
    -- average monthly revenue 
    CASE 
        WHEN lifespan = 0 THEN total_sales
        ELSE total_sales / lifespan
    END AS avg_monthly_revenue
FROM product_aggregation;
GO