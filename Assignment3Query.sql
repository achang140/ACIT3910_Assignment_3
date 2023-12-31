-- Import the bigtoys database (Using CMD) 
-- mysql -u root -p < bigtoys.sql 

USE bigtoys; 

-- 2. Confirm that the import was fully successful (confirm each table was created and has the correct number of rows).
SELECT count(*) FROM toy; -- 8013
SELECT count(*) FROM toy_category;  -- 217
SELECT count(*) FROM purchase; -- 200,000
SELECT count(*) FROM purchase_status; -- 4
SELECT count(*) FROM purchase_item; -- 380,164
SELECT count(*) FROM user; -- 50,000
SELECT count(*) FROM sales_person; -- 100 

-- 3. Create summary tables.
-- DROP TABLE sales_by_sales_person_summary, sales_by_status_summary, sales_by_user_summary;
DROP TABLE sales_by_user_summary; 

CREATE TABLE sales_by_sales_person_summary (
	sales_by_sales_person_summary_id INT AUTO_INCREMENT PRIMARY KEY,
    num_toys_sold INT,
    sales_dollars DECIMAL(29,2),
    frn_sales_person_id INT,
    Year SMALLINT,
    Month TINYINT,
    FOREIGN KEY (frn_sales_person_id) REFERENCES sales_person(sales_person_id)
) ENGINE=InnoDB;

CREATE TABLE sales_by_status_summary (
	sales_by_status_summary_id INT AUTO_INCREMENT PRIMARY KEY,
    total_sales INT,
    frn_purchase_status_id INT,
    Year SMALLINT,
    Month TINYINT,
    FOREiGN KEY (frn_purchase_status_id) REFERENCES purchase_status(purchase_status_id)
) ENGINE=InnoDB;

CREATE TABLE sales_by_user_summary (
	sales_by_user_summary_id INT AUTO_INCREMENT PRIMARY KEY,
    num_toys_sold BIGINT,
    sales_total DECIMAL(29,2),
    birth_year SMALLINT,
    purchase_year SMALLINT,
    purchase_month TINYINT
) ENGINE=InnoDB;

-- 3. Populate summary tables.
INSERT INTO sales_by_sales_person_summary (num_toys_sold, sales_dollars, frn_sales_person_id, Year, Month) 
SELECT 
	COUNT(purchase_item.purchase_item_id),
    SUM(toy.price),
    purchase.frn_sales_person_id,
    YEAR(purchase.purchase_date) as Year,
    MONTH(purchase.purchase_date) as Month 
FROM purchase 
JOIN purchase_item ON purchase.purchase_id = purchase_item.frn_purchase_id
JOIN toy ON purchase_item.frn_toy_id = toy.toy_id
GROUP BY purchase.frn_sales_person_id, Year, Month; 

INSERT INTO sales_by_status_summary (total_sales, frn_purchase_status_id, Year, Month)
SELECT 
	COUNT(purchase.purchase_id),
    purchase.frn_purchase_status_id,
	YEAR(purchase.purchase_date) as Year,
    MONTH(purchase.purchase_date) as Month 
FROM purchase 
GROUP BY purchase.frn_purchase_status_id, Year, Month;

INSERT INTO sales_by_user_summary (num_toys_sold, sales_total, birth_year, purchase_year, purchase_month)
SELECT 
	COUNT(purchase_item.purchase_item_id),
    SUM(toy.price),
    YEAR(user.birth_date) AS birth_year, 
	YEAR(purchase.purchase_date) AS Year,
    MONTH(purchase.purchase_date) AS Month
FROM purchase 
JOIN purchase_item ON purchase.purchase_id = purchase_item.frn_purchase_id
JOIN toy ON purchase_item.frn_toy_id = toy.toy_id
JOIN user ON purchase.frn_user_id = user.user_id
GROUP BY birth_year, Year, Month;

SELECT COUNT(*) FROM sales_by_sales_person_summary; -- 1600 
SELECT COUNT(*) FROM sales_by_status_summary; -- 64 
SELECT COUNT(*) FROM sales_by_user_summary; -- 1040

SELECT * FROM sales_by_sales_person_summary; 
SELECT * FROM sales_by_status_summary;
SELECT * FROM sales_by_user_summary; 

-- 4. Rewrite queries written for base table to use the new summary tables.
-- 5. Compare the result of the existing base table queries to the new summary table queries to ensure they match.

-- (1) Greatest Number of Toys Sold: List top 5 employees that sold the greatest number of toys (total all toy, not just total sales) for Dec 2018. For all of 2018. 
-- Base Table 
SELECT frn_sales_person_id, first_name, last_name,
 count(purchase_item_id) as numToysSold
FROM purchase
INNER JOIN purchase_item
 ON purchase.purchase_id = purchase_item.frn_purchase_id
INNER JOIN sales_person
 ON purchase.frn_sales_person_id = sales_person.sales_person_id
WHERE YEAR(purchase_date) = 2018
 AND MONTH(purchase_date) = 12 #exclude month for yearly report
GROUP BY frn_sales_person_id
ORDER BY numToysSold desc
LIMIT 5;

-- Summary Table 
SELECT 
    s.frn_sales_person_id, 
    sp.first_name,
    sp.last_name, 
    SUM(s.num_toys_sold) AS numToysSold
FROM sales_by_sales_person_summary AS s
JOIN sales_person AS sp ON s.frn_sales_person_id = sp.sales_person_id
WHERE s.Year = 2018 AND s.Month = 12 
GROUP BY s.frn_sales_person_id
ORDER BY numToysSold DESC
LIMIT 5;

-- (2) Greatest Sales Total: List top 5 employees that have the highest sales total by dollar amount (sum of all toy prices) for Dec 2018. For all of 2018. 
-- Base Table 
SELECT frn_sales_person_id, first_name, last_name, 
 sum(toy.price) as salesTotal
FROM purchase
INNER JOIN purchase_item
 ON purchase.purchase_id = purchase_item.frn_purchase_id
INNER JOIN sales_person 
 ON purchase.frn_sales_person_id = sales_person.sales_person_id
INNER JOIN toy
 ON purchase_item.frn_toy_id = toy.toy_id
WHERE YEAR(purchase_date) = 2018 
 AND MONTH(purchase_date) = 12 #exclude month for yearly report
GROUP BY frn_sales_person_id
ORDER BY salesTotal desc
LIMIT 5;

-- Summary Table 
SELECT 
    s.frn_sales_person_id, 
    sp.first_name,
    sp.last_name, 
    SUM(s.sales_dollars) AS salesTotal
FROM sales_by_sales_person_summary AS s
JOIN sales_person AS sp ON s.frn_sales_person_id = sp.sales_person_id
WHERE s.Year = 2018 AND s.Month = 12 
GROUP BY s.frn_sales_person_id
ORDER BY salesTotal DESC
LIMIT 5;

-- (3) Percentage of Completed Sales: 
-- What percentage of sales were completed for Dec 2018? For all of 2018? 
-- Note that sales are considered completed only if their status is shipped (frn_purchase_status_id = 3).

-- Base Table 
SELECT COUNT(purchase_id) AS totalSales, 
 COUNT(IF(frn_purchase_status_id=3,1,NULL)) AS Shipped, 
 CONCAT(COUNT(IF(frn_purchase_status_id=3,1,NULL))/
 COUNT(purchase_id)*100,"%") AS CompletedPercent
FROM purchase
WHERE YEAR(purchase_date) = 2018 
 AND MONTH(purchase_date) = 12; #exclude month for yearly report
 
 -- Summary Table 
SELECT 
    SUM(total_sales) AS totalSales,
	SUM(CASE WHEN frn_purchase_status_id = 3 THEN total_sales ELSE 0 END) AS Shipped,
    CONCAT(SUM(CASE WHEN frn_purchase_status_id = 3 THEN total_sales ELSE 0 END) / SUM(total_sales) * 100, "%") AS CompletedPercent
FROM sales_by_status_summary 
WHERE Year = 2018 AND Month = 12;

-- -- (4) Most Popular Ages of Buyers: List top 5 ages of users spending the most 
-- (top spenders – highest sales dollars) in Dec 2018. For all of 2018.

-- Base Table 
SELECT COUNT(purchase_item_id) AS numToysSold, 
 SUM(toy.price) AS salesTotal,
 YEAR(birth_date) AS birth_year, 
 YEAR(purchase_date)-YEAR(birth_date) AS Age,
 YEAR(purchase_date) AS purchase_year
FROM purchase
INNER JOIN purchase_item 
 ON purchase_item.frn_purchase_id = purchase.purchase_id
INNER JOIN toy 
 ON purchase_item.frn_toy_id = toy.toy_id
INNER JOIN user 
 ON purchase.frn_user_id = user.user_id
WHERE YEAR(purchase_date) = 2018 
 AND MONTH(purchase_date) = 12 #exclude month for yearly report
GROUP BY YEAR(birth_date), YEAR(purchase_date), 
YEAR(purchase_date)-YEAR(birth_date)
ORDER BY salesTotal DESC
LIMIT 5;

-- Summary Table 
SELECT 
	SUM(num_toys_sold) AS numToysSold, 
    SUM(sales_total) AS salesTotal,
    birth_year,
    purchase_year - birth_year AS Age,
    purchase_year
FROM sales_by_user_summary
WHERE purchase_year = 2018 AND purchase_month = 12
GROUP BY birth_year
ORDER BY salesTotal DESC
LIMIT 5; 

-- 6. Create scheduled event to keep the summary table up-to-date.
-- DROP EVENT Monthly_Sales_Person_Summary_Data;
-- DROP EVENT Monthly_Sales_Status_Summary_Data;
-- DROP EVENT Monthly_Sales_User_Summary_Data;

DELIMITER // 
CREATE EVENT Monthly_Sales_Person_Summary_Data
ON SCHEDULE 
	EVERY 1 MONTH 
    STARTS TIMESTAMP(DATE_FORMAT(CURRENT_DATE, '%Y-%m-15') + INTERVAL 1 MONTH, '23:00:00') -- Monthly on the 15th, 11:00PM, Previous month 
DO 
	BEGIN 
		INSERT INTO sales_by_sales_person_summary (num_toys_sold, sales_dollars, frn_sales_person_id, Year, Month) 
		SELECT 
			COUNT(purchase_item.purchase_item_id),
			SUM(toy.price),
			purchase.frn_sales_person_id,
			YEAR(purchase.purchase_date) as Year,
			MONTH(purchase.purchase_date) as Month 
		FROM purchase 
		JOIN purchase_item ON purchase.purchase_id = purchase_item.frn_purchase_id
		JOIN toy ON purchase_item.frn_toy_id = toy.toy_id
        WHERE Year = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) 
			AND Month = MONTH(CURRENT_DATE - INTERVAL 1 MONTH) 
		GROUP BY purchase.frn_sales_person_id, Year, Month; 
	END //
DELIMITER ; 

-- 

DELIMITER // 
CREATE EVENT Monthly_Sales_Status_Summary_Data
ON SCHEDULE 
	EVERY 1 MONTH 
    STARTS TIMESTAMP(DATE_FORMAT(CURRENT_DATE, '%Y-%m-15') + INTERVAL 1 MONTH, '23:20:00') -- Monthly on the 15th, 11:20PM, Previous month 
DO 
	BEGIN 
		INSERT INTO sales_by_status_summary (total_sales, frn_purchase_status_id, Year, Month)
		SELECT 
			COUNT(purchase.purchase_id),
			purchase.frn_purchase_status_id,
			YEAR(purchase.purchase_date) as Year,
			MONTH(purchase.purchase_date) as Month 
		FROM purchase 
		WHERE Year = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) 
			AND Month = MONTH(CURRENT_DATE - INTERVAL 1 MONTH) 
		GROUP BY purchase.frn_purchase_status_id, Year, Month;
	END //
DELIMITER ; 

--

DELIMITER // 
CREATE EVENT Monthly_Sales_User_Summary_Data
ON SCHEDULE 
	EVERY 1 MONTH 
    STARTS TIMESTAMP(DATE_FORMAT(CURRENT_DATE, '%Y-%m-15') + INTERVAL 1 MONTH, '23:40:00') -- Monthly on the 15th, 11:40PM, Previous month 
DO 
	BEGIN
		INSERT INTO sales_by_user_summary (num_toys_sold, sales_total, birth_year, purchase_year, purchase_month)
		SELECT 
			COUNT(purchase_item.purchase_item_id),
			SUM(toy.price),
			YEAR(user.birth_date) AS birth_year, 
			YEAR(purchase.purchase_date) AS Year,
			MONTH(purchase.purchase_date) AS Month
		FROM purchase 
		JOIN purchase_item ON purchase.purchase_id = purchase_item.frn_purchase_id
		JOIN toy ON purchase_item.frn_toy_id = toy.toy_id
		JOIN user ON purchase.frn_user_id = user.user_id
		WHERE Year = YEAR(CURRENT_DATE - INTERVAL 1 MONTH) 
			AND Month = MONTH(CURRENT_DATE - INTERVAL 1 MONTH) 
		GROUP BY birth_year, Year, Month;
	END //
DELIMITER ; 

--

-- 380,164
SELECT COUNT(*) AS sales_by_sales_person_summary_base_table_row_count
FROM purchase
JOIN purchase_item ON purchase.purchase_id = purchase_item.frn_purchase_id
JOIN toy ON purchase_item.frn_toy_id = toy.toy_id;

-- 200,000
SELECT COUNT(*) AS sales_by_status_summary_base_table_row_count
FROM purchase; 

-- 380,164
SELECT COUNT(*) AS sales_by_user_summary_base_table_row_count
FROM purchase 
JOIN purchase_item ON purchase.purchase_id = purchase_item.frn_purchase_id
JOIN toy ON purchase_item.frn_toy_id = toy.toy_id
JOIN user ON purchase.frn_user_id = user.user_id;

