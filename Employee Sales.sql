-- 📌 Overview - This SQL query is for practice.  
-- 📊 Data Used - Dataset: [Employee Sales](https://www.kaggle.com/datasets/saharsyed/employee-sales/data) 




-- 1.Extract Data
CREATE DATABASE employee_sales_data;
USE employee_sales_data;

SELECT * FROM sales_data;



-- 2.Transform Data
--  (1) Data Backup
CREATE TABLE sales_data_staging
LIKE sales_data;

SELECT * FROM sales_data_staging;

INSERT sales_data_staging
SELECT * FROM sales_data;


--  (2) Remove Duplicates
SELECT *, 
ROW_NUMBER() OVER(
PARTITION BY Emp_ID, Emp_Name, SaleDate, SaleAmount) AS row_num
FROM sales_data_staging;

WITH duplicate_staging AS
(SELECT *, 
ROW_NUMBER() OVER(
PARTITION BY Emp_ID, Emp_Name, SaleDate, SaleAmount) AS row_num
FROM sales_data_staging)
SELECT * 
FROM duplicate_staging
WHERE row_num > 1;
-- This dataset contains no duplicates.


--  (3) Standaradize data
SELECT * FROM sales_data_staging;

SELECT DISTINCT Emp_name
FROM sales_data_staging;

-- Convert DATETIME format
SELECT SaleDate,
STR_TO_DATE(SaleDate, '%m/%d/%Y %H:%i')
FROM sales_data_staging;

UPDATE sales_data_staging
SET SaleDate = STR_TO_DATE(SaleDate, '%m/%d/%Y %H:%i');

-- Change datatype from TEXT to DATETIME
ALTER TABLE sales_data_staging
MODIFY COLUMN SaleDate DATETIME;

-- Alter the datatype of SaleAmount
ALTER TABLE sales_data_staging
MODIFY COLUMN SaleAmount DECIMAL(10,2);


--  (4) Null Values and Blank Values
SELECT *
FROM sales_data_staging
WHERE (Emp_ID IS NULL OR ' ')
	OR (Emp_Name IS NULL OR ' ')
	OR (SaleDate IS NULL OR ' ')
    OR (SaleAmount IS NULL OR ' ');
    
--  (5) Remove unnecessary columns and rows (No removal needed for this dataset, skipping this step).



-- 3.Explore Data Analysis
SELECT * FROM sales_data_staging;

-- Q1.Calculate total sales for each month. (Question from Kaggle dataset)
SELECT SUBSTRING(SaleDate,1 ,7) AS sold_mth, SUM(SaleAmount) AS total_amount
FROM sales_data_staging
GROUP BY sold_mth
ORDER BY sold_mth DESC;


-- Q2.Calculate Sales in the Last 30 Days. (Question from Kaggle dataset)

-- This following SQL query is designed to calculate sales in the last 30 days.
-- However, since the dataset I am working on is from much earlier, there are no recent records within the last 30 days.
SELECT SUM(SaleAmount)
FROM sales_data_staging
WHERE SaleDate >= DATE_SUB(NOW(), INTERVAL 30 DAY);

-- Therefore, I calculated the total sales amount for the period between 2024-06-01 and 2024-08-31.
SELECT SUM(SaleAmount)
FROM sales_data_staging
WHERE SaleDate BETWEEN '2024-06-01 00:00:00' AND '2024-08-31 23:59:59';

-- Bonus: Calculate each employee's total sales amount for the three-month period from 2024-06-01 to 2024-08-31.
SELECT Emp_ID, Emp_Name, SUM(SaleAmount)
FROM sales_data_staging
WHERE SaleDate BETWEEN '2024-06-01 00:00:00' AND '2024-08-31 23:59:59'
GROUP BY Emp_ID, Emp_Name
ORDER BY Emp_ID, Emp_Name;

    
-- Q3.What is the Total Sales per Employee? (Question from Kaggle dataset)
SELECT Emp_ID, Emp_Name, SUM(SaleAmount) AS total_amount
FROM sales_data_staging
GROUP BY Emp_ID, Emp_Name
ORDER BY total_amount DESC;


-- Q4.Find the highest sale amount for each employee.
SELECT Emp_ID, Emp_Name, MAX(SaleAmount)
FROM sales_data_staging
GROUP BY Emp_ID, Emp_Name
ORDER BY 3 DESC;


-- Q5.Find the top 3 employees with the highest total sales.
SELECT Emp_ID, Emp_Name, SUM(SaleAmount)
FROM sales_data_staging
GROUP BY Emp_ID, Emp_Name
ORDER BY SUM(SaleAmount) DESC
LIMIT 3;


-- Q6.Find Employees with Sales Above the Average. (Question from Kaggle dataset)
-- Solution 1: CTE+JOIN
SELECT AVG(SaleAmount)
FROM sales_data_staging;

WITH cal_1 AS (
SELECT Emp_ID, Emp_Name, SUM(SaleAmount) AS emp_sum_amount
FROM sales_data_staging
GROUP BY Emp_ID, Emp_Name
), 
better_amount AS (
SELECT AVG(emp_sum_amount) AS avg_emp_amount
FROM cal_1
)
SELECT c.Emp_ID, c.Emp_Name, c.emp_sum_amount
FROM cal_1 c
JOIN better_amount ON c.emp_sum_amount > better_amount.avg_emp_amount
ORDER BY c.emp_sum_amount DESC;
-- Note: The JOIN clause can also be used with >, <, and !=.

-- Solution 2: Subquery
SELECT Emp_ID, Emp_Name, SUM(SaleAmount) AS TotalSales
FROM sales_data_staging
GROUP BY Emp_ID, Emp_Name
HAVING SUM(SaleAmount) > (
    SELECT AVG(TotalSales) 
    FROM (
        SELECT Emp_ID, SUM(SaleAmount) AS TotalSales
        FROM sales_data_staging
        GROUP BY Emp_ID
    ) AS subquery
);


-- Q7.Calculate each employee's average sales amount for each month.
SELECT Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m') AS `Month`, AVG(SaleAmount) AS Avg_Sales
FROM sales_data_staging
GROUP BY Emp_Name, `Month`
ORDER BY 2 DESC;


-- Q8.Find the employee with the highest total sales in January 2024.

-- Solution 1: Use the HAVING clause.
SELECT Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m') AS sale_mth, SUM(SaleAmount)
FROM sales_data_staging
GROUP BY Emp_ID, Emp_Name, sale_mth
HAVING sale_mth = '2024-01'
ORDER BY SUM(SaleAmount) DESC
LIMIT 1;

-- Solution 2: Use WHERE to filter and optimize the calculation process.
SELECT Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m') AS sale_mth, SUM(SaleAmount)
FROM sales_data_staging
WHERE DATE_FORMAT(SaleDate, '%Y-%m') = '2024-01'
GROUP BY Emp_ID, Emp_Name, sale_mth
ORDER BY SUM(SaleAmount) DESC
LIMIT 1;

-- Solution 3: Use RANK() for flexible applications, and switch to DENSE_RANK() if needed.
WITH MonthlySales AS (
    SELECT Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m') AS sale_mth,
           SUM(SaleAmount) AS TotalSales,
           RANK() OVER (PARTITION BY DATE_FORMAT(SaleDate, '%Y-%m') ORDER BY SUM(SaleAmount) DESC) AS ranking
    FROM sales_data_staging
    WHERE DATE_FORMAT(SaleDate, '%Y-%m') = '2024-01'
    GROUP BY Emp_ID, Emp_Name, sale_mth
)
SELECT Emp_ID, Emp_Name, sale_mth, TotalSales
FROM MonthlySales
WHERE ranking = 1;


-- Q8-1.Find the employee with the highest sales in each month.
WITH montly_saleamount AS
(
SELECT Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m') AS sale_mth, SUM(SaleAmount) AS sum_amount,
  RANK() OVER(PARTITION BY DATE_FORMAT(SaleDate, '%Y-%m') ORDER BY SUM(SaleAmount) DESC) AS ranking
FROM sales_data_staging
GROUP BY Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m')
)
SELECT *
FROM montly_saleamount
WHERE ranking = 1
ORDER BY sale_mth
;


-- Q9.Calculate the rolling total of each employee’s sales per month.
-- Solution 1：
SELECT Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m') AS sale_mth, SUM(SaleAmount),
SUM(SUM(SaleAmount)) OVER (PARTITION BY Emp_ID ORDER BY DATE_FORMAT(SaleDate, '%Y-%m')) AS rolling_total
FROM sales_data_staging
GROUP BY Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m')
ORDER BY Emp_ID, sale_mth;

-- Solution 2: Use CTE
WITH CTE_1 AS
(
SELECT Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m') AS sale_mth, SUM(SaleAmount) AS monthly_sales
FROM sales_data_staging
GROUP BY Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m')
ORDER BY Emp_ID
)
SELECT Emp_ID, Emp_Name, sale_mth, monthly_sales, 
SUM(monthly_sales) OVER(PARTITION BY Emp_ID ORDER BY sale_mth) AS rolling_total
FROM CTE_1
ORDER BY Emp_ID, sale_mth;

-- Solution 3: Subquery
SELECT Emp_ID, Emp_Name, sale_mth, monthly_sales,
       SUM(monthly_sales) OVER (PARTITION BY Emp_ID ORDER BY sale_mth) AS rolling_total
FROM (
    SELECT Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m') AS sale_mth, SUM(SaleAmount) AS monthly_sales
    FROM sales_data_staging
    GROUP BY Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m')
) AS subquery
ORDER BY Emp_ID, sale_mth;


-- Q10.Find each employee’s total sales per month and calculate the change compared to the previous month (increase or decrease).
SELECT Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m') AS sale_mth, 
SUM(SaleAmount) AS sum_amount, 
LAG(SUM(SaleAmount), 1, 0) OVER(PARTITION BY Emp_ID ORDER BY DATE_FORMAT(SaleDate, '%Y-%m')) AS prev_mth,
(SUM(SaleAmount) - LAG(SUM(SaleAmount), 1, 0) OVER(PARTITION BY Emp_ID ORDER BY DATE_FORMAT(SaleDate, '%Y-%m'))) AS sale_change
FROM sales_data_staging
GROUP BY Emp_ID, Emp_Name, DATE_FORMAT(SaleDate, '%Y-%m')
ORDER BY Emp_ID, Emp_Name, sale_mth;

