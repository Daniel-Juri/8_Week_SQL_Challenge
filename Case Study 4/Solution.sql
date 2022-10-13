--Solved on PostgreSQL 14 by Daniel Mogbojuri--

/* --------------------
   Case Study Questions
   --------------------*/
   
-------A. Customer Nodes Exploration -------

--1. How many unique nodes are there on the Data Bank system?
SELECT COUNT (DISTINCT node_id) AS nodes
FROM Data_bank.customer_nodes

--2. What is the number of nodes per region?
SELECT region_name, COUNT(node_id) AS nodes_per_region
FROM Data_bank.customer_nodes
    INNER JOIN Data_bank.regions
        USING(region_id)
GROUP BY region_name
ORDER BY region_name

--3. How many customers are allocated to each region?
SELECT region_name, COUNT(customer_id) AS nodes_per_customer
FROM Data_bank.customer_nodes
    INNER JOIN Data_bank.regions
        USING(region_id)
GROUP BY region_name
ORDER BY region_name

--4. How many days on average are customers reallocated to a different node?
SELECT ROUND(AVG(start_date - prior_date), 1) AS average_reallocation_days
FROM (
  SELECT customer_id, start_date, 
    LAG(start_date) OVER(PARTITION BY customer_id ORDER BY start_date) AS prior_date
  FROM Data_bank.customer_nodes) AS tmp
  
--5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
SELECT region_name, PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY (start_date - prior_date))::NUMERIC AS Median,
                    PERCENTILE_DISC(0.8) WITHIN GROUP(ORDER BY (start_date - prior_date))::NUMERIC AS percentile_80,
                    PERCENTILE_DISC(0.95) WITHIN GROUP(ORDER BY (start_date - prior_date))::NUMERIC AS percentile_95
FROM (
  SELECT customer_id, region_id, start_date, 
    LAG(start_date) OVER(PARTITION BY customer_id ORDER BY start_date) AS prior_date
  FROM Data_bank.customer_nodes) AS tmp
    INNER JOIN Data_bank.regions 
        USING (region_id)
GROUP BY region_name


-------B. Customer Transactions -------

--1. What is the unique count and total amount for each transaction type?
SELECT DISTINCT txn_type AS Transaction_type, COUNT(*) AS No_of_transactions, CONCAT('$', SUM(txn_amount)) AS Total_amount
FROM Data_bank.customer_transactions
GROUP BY txn_type

--2. What is the average total historical deposit counts and amounts for all customers?
SELECT ROUND(AVG(no_of_transactions),1) AS average_deposit_count,
       ROUND(AVG(total_amount),1) AS average_total_deposit
FROM (
  SELECT customer_id, COUNT(*) AS No_of_transactions, SUM(txn_amount) AS Total_amount 
  FROM Data_bank.customer_transactions
  WHERE txn_type = 'deposit'
  GROUP BY customer_id
  ORDER BY customer_id
) AS tmp

--3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
WITH Customers AS (
    SELECT customer_id, EXTRACT(MONTH FROM txn_date) AS Month_, TO_CHAR(txn_date, 'Month') AS Month_name,
            SUM(CASE WHEN txn_type = 'deposit' THEN 1 ELSE 0 END) AS deposit_count,
            SUM(CASE WHEN txn_type = 'purchase' THEN 1 ELSE 0 END) AS purchase_count,
            SUM(CASE WHEN txn_type = 'withdrawal' THEN 1 ELSE 0 END) AS withdrawal_count
	FROM data_bank.customer_transactions
	GROUP BY customer_id, EXTRACT(MONTH FROM txn_date), TO_CHAR(txn_date, 'Month')
    )
SELECT Month_name, COUNT(customer_id) AS Customer_count
FROM Customers
WHERE deposit_count > 1 AND (purchase_count >= 1 OR withdrawal_count >= 1)
GROUP BY Month_, Month_name
ORDER BY Month_

--4.1. What is the closing balance for each customer at the end of the month?
WITH Customers AS (
        SELECT customer_id, EXTRACT(MONTH FROM txn_date) AS Month_, TO_CHAR(txn_date, 'Month') AS Month_name,
              SUM(CASE WHEN txn_type = 'deposit' THEN txn_amount ELSE 0 END) AS deposit_count,
              SUM(CASE WHEN txn_type = 'purchase' THEN txn_amount ELSE 0 END) AS purchase_count,
              SUM(CASE WHEN txn_type = 'withdrawal' THEN txn_amount ELSE 0 END) AS withdrawal_count
        FROM data_bank.customer_transactions
        GROUP BY  customer_id, EXTRACT(MONTH FROM txn_date), TO_CHAR(txn_date, 'Month')
        ORDER BY customer_id
   )

SELECT customer_id, Month_name, (deposit_count - (purchase_count + withdrawal_count)) AS closing_balance
FROM Customers
ORDER BY customer_id, Month_

--4.2. --RANGE (WITH ORDER BY) OR ROWS (WITHOUT ORDER BY) because as each month appears only once for each customer in the table, the result will be the same for RANGE and ROWS
WITH txn_types AS (
          SELECT *,
                CASE WHEN txn_type = 'deposit' THEN txn_amount
                ELSE -1 * txn_amount 
                END AS txn_balance
          FROM data_bank.customer_Transactions
          ORDER BY customer_id, txn_date
          ), 
          Customers AS (
            SELECT customer_id, EXTRACT(MONTH FROM txn_date) AS Month_, TO_CHAR(txn_date, 'Month') AS Month_name, SUM(txn_balance)AS txn_amount 
            FROM txn_types
            GROUP BY customer_id, EXTRACT(MONTH FROM txn_date), TO_CHAR(txn_date, 'Month')
            ORDER BY customer_id
          )  
SELECT customer_id, Month_, Month_name, txn_amount ,
    SUM(txn_amount) OVER (PARTITION BY customer_id ORDER BY month_ ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS balance
FROM Customers
ORDER BY customer_id, Month_

--5. What is the percentage of customers who increase their closing balance by more than 5%?
WITH txn_types AS (
          SELECT *,
                CASE WHEN txn_type = 'deposit' THEN txn_amount
                ELSE -1 * txn_amount 
                END AS txn_balance
          FROM data_bank.customer_Transactions
          ORDER BY customer_id, txn_date
          ), 
          Customers AS (
            SELECT customer_id, EXTRACT(MONTH FROM txn_date) AS Month_, TO_CHAR(txn_date, 'Month') AS Month_name, SUM(txn_balance)AS txn_amount 
            FROM txn_types
            GROUP BY customer_id, EXTRACT(MONTH FROM txn_date), TO_CHAR(txn_date, 'Month')
            ORDER BY customer_id
          ),
          Closing_balance AS (
           SELECT customer_id, Month_, Month_name, txn_amount ,
                    SUM(txn_amount) OVER (PARTITION BY customer_id ORDER BY month_ ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS balance
           FROM Customers
           ORDER BY customer_id, Month_
          ),
          Previous_balance AS (
            SELECT *, LAG(balance) OVER (PARTITION BY customer_id ORDER BY month_) AS previous_month_balance
            FROM Closing_balance
          ),
        growth_rates AS (
          SELECT customer_id, month_, balance, previous_month_balance, 
          CASE WHEN previous_month_balance IS NULL THEN NULL
               WHEN previous_month_balance = 0 THEN balance*100
          ELSE ROUND(((balance-(previous_month_balance))/ABS(previous_month_balance))*100,1) END AS growth_rate,
          ROW_NUMBER () OVER (PARTITION BY customer_id ORDER BY month_ DESC) AS balance_index
          FROM Previous_balance
         ),
        cust_last_balance AS (
          SELECT customer_id, month_, growth_rate,
          CASE WHEN growth_rate > 5 THEN 1 ELSE 0 END AS growth_rate_check 
          FROM growth_rates
          WHERE balance_index = 1
        )

SELECT (SUM(growth_rate_check)/COUNT(*)::FLOAT)*100||'%' AS Growth_Percentage
FROM cust_last_balance;



-------C. Data Allocation Challenge -------
--To test out a few different hypotheses - the Data Bank team wants to run an experiment where different groups of customers would be allocated data using 3 different options:
--Option 1: data is allocated based off the amount of money at the end of the previous month
--Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
--Option 3: data is updated real-time
--For this multi-part challenge question - you have been requested to generate the following data elements to help the Data Bank team estimate how much data will need to be provisioned for each option:

--running customer balance column that includes the impact each transaction
--customer balance at the end of each month
--minimum, average and maximum values of the running balance for each customer
--Using all of the data available - how much data would have been required for each option on a monthly basis?


WITH customer_txn AS (
  SELECT *,
  CASE WHEN txn_type = 'deposit' THEN txn_amount
  ELSE -1 * txn_amount END AS txn_group
  FROM data_bank.customer_transactions
 ),
customer_date_series AS (
  SELECT customer_id,
  GENERATE_SERIES(first_date, last_date, '1 day') AS date_series
  FROM (
    SELECT customer_id, MIN(txn_date) AS first_date, MAX(txn_date) AS last_date
    FROM customer_txn
    GROUP BY customer_id
  )  AS generate_min_max
),
customer_balance AS (
  SELECT *, 
  SUM(txn_group) OVER (PARTITION BY customer_id ORDER BY date_series) AS balance
  FROM (
    SELECT s.customer_id, date_series, txn_group,
    COUNT(txn_group) OVER (PARTITION BY s.customer_id ORDER BY date_series) AS txn_count
    FROM customer_date_series s
    LEFT JOIN customer_txn b ON s.customer_id = b.customer_id AND s.date_series = b.txn_date 
    ORDER BY s.customer_id, date_series
  ) AS generate_txn_count
),
customer_data AS (
  SELECT customer_id, date_series,
  CASE WHEN txn_row < 30 THEN NULL 
      WHEN avg_last_30 < 0 THEN 0
      ELSE avg_last_30 END AS data_storage
  FROM (
    SELECT *,
    AVG(balance) OVER (PARTITION BY customer_id ORDER BY date_series ROWS BETWEEN 30 PRECEDING AND CURRENT ROW) AS avg_last_30,
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY date_series) AS txn_row
    FROM customer_balance
  ) AS tmp
)
SELECT month, ROUND(SUM(data_allocation),1) AS total_allocation
FROM (
  SELECT customer_id, 
  DATE_TRUNC('month', date_series) AS month, 
  MAX(data_storage) AS data_allocation 
  FROM customer_data 
  GROUP BY customer_id, month
) AS tmp
GROUP BY month ORDER BY month;