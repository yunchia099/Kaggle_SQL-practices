CREATE DATABASE bike_store;
USE bike_store;

-- Import tables
-- Set PRIMARY KEYs and check if any column types need adjustment

SELECT * FROM brands;
-- Check whether PRIMARY KEY is already set
SHOW CREATE TABLE brands;
-- Set PRIMARY KEY
ALTER TABLE brands
ADD PRIMARY KEY (brand_id);

-- 
SELECT * FROM categories;
SHOW CREATE TABLE categories;
ALTER TABLE categories
ADD PRIMARY KEY (category_id);

--
SELECT * FROM customers;
SHOW CREATE TABLE customers;
ALTER TABLE customers
ADD PRIMARY KEY (customer_id);
ALTER TABLE customers
MODIFY COLUMN phone VARCHAR(20);

--
SELECT * FROM order_items;
SHOW CREATE TABLE order_items;
-- Initially failed to set a composite key and suspected duplicate values, 
-- so checked for duplicates in (order_id + item_id)
WITH checking AS
(
SELECT *, 
ROW_NUMBER() OVER(PARTITION BY order_id, item_id ORDER BY order_id) AS rownum
FROM order_items
)
SELECT * FROM checking
WHERE rownum > 1
;
-- Found that the original order_items table allows NULLs in order_id and item_id,
-- but primary keys cannot be NULL. Need to modify those fields before setting a composite key.
ALTER TABLE order_items
MODIFY COLUMN order_id INT NOT NULL,
MODIFY COLUMN item_id INT NOT NULL,
ADD PRIMARY KEY (order_id, item_id);

ALTER TABLE order_items
MODIFY COLUMN list_price DECIMAL(10,2),
MODIFY COLUMN discount DECIMAL(10,2);

--
SELECT * FROM orders;
SHOW CREATE TABLE orders;

-- This method cannot remove the TIME part from the original DATETIME field
UPDATE orders
SET order_date = DATE(order_date);
-- Must use ALTER to change the data type directly to DATE
ALTER TABLE orders 
MODIFY COLUMN order_date DATE,
MODIFY COLUMN required_date DATE,
MODIFY COLUMN shipped_date DATE,
ADD PRIMARY KEY (order_id);

-- During later EDA, discovered that the orders table was not imported correctly.
-- Backed up the original table, removed the faulty data, and re-imported it.
CREATE TABLE orders_old_backup AS SELECT * FROM orders;
DROP TABLE orders;

--
SELECT * FROM products;
SHOW CREATE TABLE products;

ALTER TABLE products
ADD PRIMARY KEY (product_id),
MODIFY COLUMN list_price DECIMAL(10,2);

--
SELECT * FROM staffs;
SHOW CREATE TABLE staffs;

ALTER TABLE staffs
ADD PRIMARY KEY (staff_id),
MODIFY COLUMN phone VARCHAR(20);

--
SELECT * FROM stocks;
SHOW CREATE TABLE stocks;

ALTER TABLE stocks
MODIFY COLUMN store_id INT NOT NULL,
MODIFY COLUMN product_id INT NOT NULL;

ALTER TABLE stocks
ADD PRIMARY KEY (store_id, product_id);

--
SELECT * FROM stores;
SHOW CREATE TABLE stores;

ALTER TABLE stores
ADD PRIMARY KEY (store_id),
MODIFY COLUMN phone VARCHAR(20);




-- Perform EDA (Exploratory Data Analysis)
 # NOTE: For most sales-related calculations, exclude rows without a shipped date (e.g., WHERE shipped_date IS NOT NULL).
 # Be sure to apply appropriate time filters in Power BI or Excel as needed.
 
SELECT * FROM stores;

-- Sales Analysis
-- 1.Find monthly sales totals (excluding unshipped orders)
SELECT SUBSTRING(orders.order_date,1,7) OrderMth,
    SUM(order_items.quantity * order_items.list_price * (1 - order_items.discount)) TotalAmount
FROM orders
JOIN order_items ON orders.order_id = order_items.order_id
WHERE orders.shipped_date IS NOT NULL
GROUP BY SUBSTRING(orders.order_date,1,7)
ORDER BY OrderMth;

-- 2.Total sales per store
SELECT o.store_id StoreID,
       SUM(oi.quantity * oi.list_price * (1 - oi.discount)) earnings
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.shipped_date IS NOT NULL
GROUP BY o.store_id
ORDER BY StoreID;

-- 3.Top 3 best-selling items per store
WITH total_sale AS (
SELECT orders.store_id StoreID,
	products.product_id ProductID,
    products.product_name ProductName,
    SUM(order_items.quantity) Total_Units
FROM orders
JOIN order_items ON orders.order_ID = order_items.order_ID
JOIN products ON order_items.product_id = products.product_id
WHERE orders.shipped_date IS NOT NULL
GROUP BY orders.store_id, products.product_id
), 
BestSell AS
(
SELECT StoreID, ProductID, ProductName, Total_Units,
DENSE_RANK() OVER (PARTITION BY StoreID ORDER BY Total_Units DESC) AS best_seller
FROM total_sale
)
SELECT * FROM BestSell
WHERE best_seller <= 3;

-- 4.Cumulative ranking of sold items
SELECT orders.store_id StoreID,
	   order_items.order_id OrderID,
       products.product_id ProductID,
       products.product_name ProductName,
       order_items.quantity,
       DENSE_RANK() OVER(PARTITION BY orders.store_id, products.product_id ORDER BY order_items.order_id) AS Total_Units
FROM orders
JOIN order_items ON orders.order_ID = order_items.order_ID
JOIN products ON order_items.product_id = products.product_id
WHERE orders.shipped_date IS NOT NULL
ORDER BY StoreID, ProductID, Total_Units;

-- 5.Calculate the purchase amount for each order
SELECT order_items.order_id OrderID,
    orders.customer_id CustomerID,
    orders.order_date OrderDate,
    SUM(order_items.quantity * order_items.list_price *(1 - order_items.discount)) Amount
FROM orders
JOIN order_items ON orders.order_id = order_items.order_id
WHERE orders.shipped_date IS NOT NULL
GROUP BY order_items.order_id, orders.customer_id, orders.order_date
ORDER BY CustomerID;

-- 6.Monthly product sales summary by store (for extended analysis in Excel)
SELECT orders.store_id,
	order_items.product_id pd_ID,
    order_items.list_price,
    SUBSTRING(orders.order_date,1 ,7) SaleMth,
    SUM(order_items.quantity) SaleQuant,
    ROUND(SUM(order_items.quantity * order_items.list_price * (1 - order_items.discount)) / 
      NULLIF(SUM(order_items.quantity), 0), 4) AS avg_price
FROM order_items
LEFT JOIN orders ON order_items.order_id = orders.order_id
WHERE orders.shipped_date IS NOT NULL
GROUP BY orders.store_id, order_items.product_id, SUBSTRING(orders.order_date,1 ,7), order_items.list_price
ORDER BY orders.store_id, order_items.product_id, SUBSTRING(orders.order_date,1 ,7);



-- Employee Performance Analysis
-- 1.Calculate each employee’s total sales and ranking
SELECT staffs.staff_id StaffID, 
	   SUM(oi.quantity * oi.list_price * (1 - oi.discount)) staff_sale,
       RANK() OVER(ORDER BY SUM(oi.quantity * oi.list_price * (1 - oi.discount))DESC) AS ranking
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
RIGHT JOIN staffs ON o.staff_id = staffs.staff_id
WHERE o.shipped_date IS NOT NULL
GROUP BY staffs.staff_id
ORDER BY ranking;

-- 2.Number of orders per employee
SELECT staffs.staff_id, COUNT(orders.order_ID)
FROM orders
RIGHT JOIN staffs ON orders.staff_id = staffs.staff_id
WHERE orders.shipped_date IS NOT NULL
GROUP BY staffs.staff_id
ORDER BY 1;

-- 3.Cumulative sales per employee
 # Method 1: Using CTE provides better readability. 
 # If the staff_sale calculation will be reused in other queries, CTE is a better choice.
WITH sale_count AS(
SELECT o.staff_id StaffID, 
	   o.order_ID OrderID,
	   SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS staff_sale
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.shipped_date IS NOT NULL
GROUP BY o.staff_id,  o.order_ID
)
SELECT *, 
	SUM(staff_sale) OVER(PARTITION BY StaffID ORDER BY OrderID) rolling_total
FROM sale_count
ORDER BY StaffID, OrderID;

 # Method 2: If it's just a one-time calculation of cumulative sales, 
 # directly using SUM() with a window function is faster.
SELECT o.staff_id StaffID, 
       o.order_ID OrderID,
       SUM(SUM(oi.quantity * oi.list_price * (1 - oi.discount)))
       OVER(PARTITION BY o.staff_id ORDER BY o.order_ID) rolling_total
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.shipped_date IS NOT NULL
GROUP BY o.staff_id,  o.order_ID
ORDER BY StaffID;


-- Inventory and Product Analysis
-- 1.Current inventory quantity per store (where inventory < 10)
SELECT stores.store_id, 
stores.store_name, 
products.product_id, 
products.product_name, 
stocks.quantity FROM stocks
JOIN stores ON stocks.store_id = stores.store_id
JOIN products ON stocks.product_id = products.product_id
WHERE stores.store_id = 1
HAVING stocks.quantity < 10;

-- 2.Product categories currently in stock at each store
SELECT stores.store_id StoreId, 
	stores.store_name StoreName, 
	products.product_id ProductID, 
	products.product_name ProductName, 
    stocks.quantity Quantity,
	categories.category_name CategoryName FROM stores
JOIN stocks ON stocks.store_id = stores.store_id
JOIN products ON stocks.product_id = products.product_id
JOIN categories ON products.category_id = categories.category_id;

-- 3.List product categories with inventory < 5 for each store
WITH store_stocking AS(
SELECT stores.store_id StoreId, 
	stores.store_name StoreName, 
	products.product_id ProductID, 
	products.product_name ProductName, 
    stocks.quantity Quantity,
	categories.category_name CategoryName FROM stores
JOIN stocks ON stocks.store_id = stores.store_id
JOIN products ON stocks.product_id = products.product_id
JOIN categories ON products.category_id = categories.category_id
)
SELECT StoreId, StoreName, CategoryName, COUNT(ProductID)
FROM store_stocking
WHERE Quantity < 5
GROUP BY StoreId, StoreName, CategoryName
ORDER BY StoreId;



-- This SQL section mainly focuses on data exploration and deriving key metrics to support further analysis.
-- Most of the business findings are presented via dashboards and visualizations. 
-- You can find them here: https://www.notion.so/Bike-Store-Database-1-1f3eda9dcf8b80708a22def50ccebfe6?pvs=4
