--Solved on PostgreSQL 14 by Daniel Mogbojuri--

/* --------------------
   Case Study Questions
   --------------------*/
   
-------1. Data Cleansing Steps -------

/*
In a single query, perform the following operations and generate a new table in the data_mart schema named clean_weekly_sales:

A. Convert the week_date to a DATE format

B. Add a week_number as the second column for each week_date value, for example any value from the 1st of January to 7th of January will be 1, 8th to 14th will be 2 etc

C. Add a month_number with the calendar month for each week_date value as the 3rd column

D. Add a calendar_year column as the 4th column containing either 2018, 2019 or 2020 values

E. Add a new column called age_band after the original segment column using the following mapping on the number inside the segment value

    segment	age_band
    1	Young Adults
    2	Middle Aged
    3 or 4	Retirees
F. Add a new demographic column using the following mapping for the first letter in the segment values:
    segment	demographic
    C	Couples
    F	Families
G. Ensure all null string values with an "unknown" string value in the original segment column as well as the new age_band and demographic columns

H. Generate a new avg_transaction column as the sales value divided by transactions rounded to 2 decimal places for each record
*/
CREATE TABLE Cleaned_weekly_sales AS 
SELECT *,
    TO_CHAR(dates_week, 'W' )::integer AS week_number,
    EXTRACT(WEEK FROM dates_week) ::integer AS tot_week_number,
    EXTRACT('month' FROM dates_week) AS month_number,
    EXTRACT('year'FROM dates_week) AS calendar_year,
    CASE 
        WHEN RIGHT(segment,1)='1' THEN 'Young Adults'
        WHEN RIGHT(segment,1)='2' THEN 'Middle Aged'
        WHEN RIGHT(segment,1) IN ('3','4') THEN 'Retirees'
        ELSE segment END AS age_band,
    CASE 
        WHEN LEFT(segment,1)='C' THEN 'Couples'
        WHEN LEFT(segment,1)='F' THEN 'Families'
        ELSE segment END AS demographic,
    ROUND(sales/transactions::NUMERIC, 2) AS avg_transaction
FROM (
	SELECT TO_DATE(week_date, 'DD/MM/YY') AS dates_week,
	       region, platform,
	       CASE 
                WHEN segment = 'null' OR segment IS NULL THEN 'Unknown'
                ELSE segment 
                END AS segment,
           customer_type, transactions, sales
	FROM data_mart.weekly_sales
) AS clean_data;


-------2. Data Exploration -------

--What day of the week is used for each week_date value?
SELECT to_char(dates_week, 'Day') as wkday
from Cleaned_weekly_sales;

--What range of week numbers are missing from the dataset?
WITH date_range AS (
    SELECT MIN(dates_week) AS first_date,
    MAX(dates_week) AS last_date
    FROM cleaned_weekly_sales
),

week_date_series AS (
	SELECT GENERATE_SERIES(first_date, last_date, '1 week') AS dates_week
	FROM date_range
)
SELECT * 
FROM week_date_series
WHERE dates_week NOT IN (SELECT DISTINCT dates_week FROM Cleaned_weekly_sales)
ORDER BY dates_week;

--How many total transactions were there for each year in the dataset?
SELECT Extract('year' FROM dates_week) AS years, SUM(transactions) AS total_transactions
FROM Cleaned_weekly_sales
GROUP BY years

--What is the total sales for each region for each month?
SELECT Extract('month' FROM dates_week) AS monthly, region,  SUM(transactions) AS total_transactions
FROM Cleaned_weekly_sales
GROUP BY monthly, region
ORDER BY region, monthly

--What is the percentage of sales for Retail vs Shopify for each month?
WITH Category AS (
    SELECT TO_CHAR(dates_week, 'month') AS Months, 
           SUM(CASE WHEN platform = 'Retail' THEN sales END) AS retail,
           SUM(CASE WHEN platform = 'Shopify' THEN sales END) AS shopify,
	       SUM(sales) AS total_sales
    FROM Cleaned_weekly_sales
    GROUP BY Months
    )
    
SELECT Months, ROUND(retail/total_sales::NUMERIC, 2) * 100 AS retail_percent,
       ROUND(shopify/total_sales::NUMERIC, 2) * 100 AS shopify_percent
FROM Category

--What is the percentage of sales by demographic for each year in the dataset?

WITH Category AS (
    SELECT EXTRACT('year'FROM dates_week) AS Years, 
           SUM(CASE WHEN demographic = 'Couples' THEN sales END) AS Couples_demographic,
           SUM(CASE WHEN demographic = 'Families' THEN sales END) AS Families_demographic,
           SUM(CASE WHEN demographic = 'Unknown' THEN sales END) AS Unknown_demographic,
	       SUM(sales) AS total_sales
    FROM Cleaned_weekly_sales
    GROUP BY Years
    )
    
SELECT Years, ROUND(Couples_demographic/total_sales::NUMERIC, 2) * 100 AS Couples_percent,
       ROUND(Families_demographic/total_sales::NUMERIC, 2) * 100 AS Families_percent,
       ROUND(Unknown_demographic/total_sales::NUMERIC, 2) * 100 AS Unknown_percent
FROM Category
ORDER BY Years

--Which age_band and demographic values contribute the most to Retail sales?
SELECT age_band, demographic, SUM(sales) as total_sales, RANK() OVER (ORDER BY SUM(sales) DESC) AS cumulative_sales
FROM Cleaned_weekly_sales
GROUP BY age_band, demographic
ORDER  BY total_sales DESC;


--Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?

--We cannot use the avg_transaction column to find the average transaction size because we need to aggregate the values to get the correct data. If we aggregate an averaged value we would be getting a wrong data because we are averaging an already averaged value.
SELECT calendar_year, platform,
        ROUND(SUM(sales::NUMERIC) / SUM(transactions), 1) AS correct_avg,
        ROUND(AVG(avg_transaction), 1) AS incorrect_avg
FROM Cleaned_weekly_sales
GROUP BY calendar_year, platform
ORDER BY calendar_year, platform
    
    
-------3. Before & After Analysis -------
-- What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?

WITH dates_schedule AS (
        SELECT dates_week, sales, 
                ROUND((dates_week - '2020-06-15'::DATE)/7.0)+1 AS week_number	
        FROM cleaned_weekly_sales
    ),
    
    Date_date AS (
        SELECT SUM(CASE WHEN week_number BETWEEN -3 AND 0 THEN sales END) AS previous_dates,
               SUM(CASE WHEN week_number BETWEEN 1 AND 4 THEN sales END) AS after_dates
        FROM dates_schedule
    )


SELECT previous_dates, after_dates, after_dates - previous_dates AS change_effect,
        ROUND(((After_dates/previous_dates::NUMERIC) - 1)*100, 2) AS percent_change
FROM Date_date


--What about the entire 12 weeks before and after?

WITH dates_schedule AS (
        SELECT dates_week, sales, 
                ROUND((dates_week - '2020-06-15'::DATE)/7.0)+1 AS week_number	
        FROM cleaned_weekly_sales
    ),
    
    Date_date AS (
        SELECT SUM(CASE WHEN week_number BETWEEN -11 AND 0 THEN sales END) AS previous_dates,
               SUM(CASE WHEN week_number BETWEEN 1 AND 12 THEN sales END) AS after_dates
        FROM dates_schedule
    )


SELECT previous_dates, after_dates, after_dates - previous_dates AS change_effect,
        ROUND(((After_dates/previous_dates::NUMERIC) - 1)*100, 2) AS percent_change
FROM Date_date

--How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
WITH sales_before AS (
        SELECT calendar_year, SUM(sales) AS total_sales_before
        FROM Cleaned_weekly_sales,
          LATERAL(SELECT EXTRACT(WEEK FROM '2020-06-15'::DATE) AS base_week) bw
        WHERE tot_week_number BETWEEN (base_week - 12) AND (base_week - 1)
        GROUP BY calendar_year     
  ),
    sales_after AS (
        SELECT calendar_year, SUM(sales) AS total_sales_after
        FROM Cleaned_weekly_sales,
            LATERAL(SELECT EXTRACT(WEEK FROM '2020-06-15':: DATE) AS base_week) bw
        WHERE tot_week_number BETWEEN (base_week) AND (base_week + 11)
        GROUP BY calendar_year
  )
  
SELECT
  calendar_year, total_sales_before, total_sales_after,
  total_sales_after - total_sales_before AS change_effect,
  ROUND(((total_sales_after/total_sales_before::NUMERIC) - 1)*100, 2) AS percent_change
FROM sales_before 
  JOIN sales_after  
    USING(calendar_year)
GROUP BY calendar_year, total_sales_before, total_sales_after


-------4. Bonus Question-------
---Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?
--region
WITH sales_before AS (
        SELECT region, SUM(sales) AS total_sales_before
        FROM Cleaned_weekly_sales,
          LATERAL(SELECT EXTRACT(WEEK FROM '2020-06-15'::DATE) AS base_week) bw
        WHERE calendar_year = 2020
            AND tot_week_number BETWEEN (base_week - 12) AND (base_week - 1)
        GROUP BY region    
  ),
    sales_after AS (
        SELECT region, SUM(sales) AS total_sales_after
        FROM Cleaned_weekly_sales,
            LATERAL(SELECT EXTRACT(WEEK FROM '2020-06-15':: DATE) AS base_week) bw
        WHERE calendar_year = 2020
            AND tot_week_number BETWEEN (base_week) AND (base_week + 11)
        GROUP BY region
  )  
SELECT
  region, total_sales_before, total_sales_after,
  total_sales_after - total_sales_before AS change_effect,
  ROUND(((total_sales_after/total_sales_before::NUMERIC) - 1)*100, 2) AS percent_change
FROM sales_before
  JOIN sales_after 
    USING(region)
GROUP BY region, total_sales_before, total_sales_after

--platform
WITH sales_before AS (
        SELECT platform, SUM(sales) AS total_sales_before
        FROM Cleaned_weekly_sales,
          LATERAL(SELECT EXTRACT(WEEK FROM '2020-06-15'::DATE) AS base_week) bw
        WHERE calendar_year = 2020
            AND tot_week_number BETWEEN (base_week - 12) AND (base_week - 1)
        GROUP BY platform   
  ),
    sales_after AS (
        SELECT platform, SUM(sales) AS total_sales_after
        FROM Cleaned_weekly_sales,
            LATERAL(SELECT EXTRACT(WEEK FROM '2020-06-15':: DATE) AS base_week) bw
        WHERE calendar_year = 2020
            AND tot_week_number BETWEEN (base_week) AND (base_week + 11)
        GROUP BY platform
  )
  
SELECT
  platform, total_sales_before, total_sales_after,
  total_sales_after - total_sales_before AS change_effect,
  ROUND(((total_sales_after/total_sales_before::NUMERIC) - 1)*100, 2) AS percent_change
FROM sales_before 
  JOIN sales_after 
    USING(platform)
GROUP BY platform, total_sales_before, total_sales_after


--age_band
WITH sales_before AS (
        SELECT age_band, SUM(sales) AS total_sales_before
        FROM Cleaned_weekly_sales,
          LATERAL(SELECT EXTRACT(WEEK FROM '2020-06-15'::DATE) AS base_week) bw
        WHERE calendar_year = 2020
            AND tot_week_number BETWEEN (base_week - 12) AND (base_week - 1)
        GROUP BY age_band  
  ),
    sales_after AS (
        SELECT age_band, SUM(sales) AS total_sales_after
        FROM Cleaned_weekly_sales,
            LATERAL(SELECT EXTRACT(WEEK FROM '2020-06-15':: DATE) AS base_week) bw
        WHERE calendar_year = 2020
            AND tot_week_number BETWEEN (base_week) AND (base_week + 11)
        GROUP BY age_band
  )
  
SELECT
  age_band, total_sales_before, total_sales_after,
  total_sales_after - total_sales_before AS change_effect,
  ROUND(((total_sales_after/total_sales_before::NUMERIC) - 1)*100, 2) AS percent_change
FROM sales_before 
  JOIN sales_after 
    USING(age_band)
GROUP BY age_band, total_sales_before, total_sales_after


--demographic
WITH sales_before AS (
        SELECT demographic, SUM(sales) AS total_sales_before
        FROM Cleaned_weekly_sales,
          LATERAL(SELECT EXTRACT(WEEK FROM '2020-06-15'::DATE) AS base_week) bw
        WHERE calendar_year = 2020
            AND tot_week_number BETWEEN (base_week - 12) AND (base_week - 1)
        GROUP BY demographic  
  ),
    sales_after AS (
        SELECT demographic, SUM(sales) AS total_sales_after
        FROM Cleaned_weekly_sales,
            LATERAL(SELECT EXTRACT(WEEK FROM '2020-06-15':: DATE) AS base_week) bw
        WHERE calendar_year = 2020
            AND tot_week_number BETWEEN (base_week) AND (base_week + 11)
        GROUP BY demographic
  )
  
SELECT
  demographic, total_sales_before, total_sales_after,
  total_sales_after - total_sales_before AS change_effect,
  ROUND(((total_sales_after/total_sales_before::NUMERIC) - 1)*100, 2) AS percent_change
FROM sales_before 
  JOIN sales_after 
    USING(demographic)
GROUP BY demographic, total_sales_before, total_sales_after


--customer_type
WITH sales_before AS (
        SELECT customer_type, SUM(sales) AS total_sales_before
        FROM Cleaned_weekly_sales,
          LATERAL(SELECT EXTRACT(WEEK FROM '2020-06-15'::DATE) AS base_week) bw
        WHERE calendar_year = 2020
            AND tot_week_number BETWEEN (base_week - 12) AND (base_week - 1)
        GROUP BY customer_type  
  ),
    sales_after AS (
        SELECT customer_type, SUM(sales) AS total_sales_after
        FROM Cleaned_weekly_sales,
            LATERAL(SELECT EXTRACT(WEEK FROM '2020-06-15':: DATE) AS base_week) bw
        WHERE calendar_year = 2020
            AND tot_week_number BETWEEN (base_week) AND (base_week + 11)
        GROUP BY customer_type
  )
  
SELECT
  customer_type, total_sales_before, total_sales_after,
  total_sales_after - total_sales_before AS change_effect,
  ROUND(((total_sales_after/total_sales_before::NUMERIC) - 1)*100, 2) AS percent_change
FROM sales_before 
  JOIN sales_after 
    USING(customer_type)
GROUP BY customer_type, total_sales_before, total_sales_after

--Analysis show that unknown age_band and unknown demographic had the highest negative percent change in sales for 2020 based off the 2020-06-15 timeframe
--Shopify platform had the highest positive percent change in sales for 2020 based off the 2020-06-15 timeframe.
--Europe shows the highest positive percent change in sales for 2020
--Reducing the number of unknown in age_bands and demographic would help grow the business
--The retail platform generates the highest sale so focusing on reducing the percent change would profit the business
--Asia has the highest sales and negative percent change amongst the other region, so focusing on reducing this percent change would profit the business
--