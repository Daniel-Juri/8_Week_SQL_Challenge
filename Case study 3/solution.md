--Solved on PostgreSQL 14 by Daniel Mogbojuri--

/* --------------------
   Case Study Questions
   --------------------*/
   
-------A. Customer Journey -------
--Based off the 8 sample customers provided in the sample from the subscriptions table, 
--write a brief description about each customer’s onboarding journey.
--Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!

-- Customer-ID 1 started with a free trial subscription, then downgraded to a basic monthly subscription after the 7-day trial 

-- Customer-ID 2 started with a free trial subscription, then upgraded to a pro annual subscription after the 7-day trial 

-- Customer-ID 11 started with a free trial subscription, then cancelled their Foodie-Fi subscription after the 7-day trial 

-- Customer-ID 13 started with a free trial subscription, then downgraded to a basic monthly subscription after the 7-day trial. 3 months later, upgraded to a pro monthly subscription

-- Customer-ID 15 started with a free trial subscription, then automatically continued with the pro monthly subscription after the 7-day trial. A month later, they cancelled their Foodie-Fi subscription

-- Customer-ID 16 started with a free trial subscription, then downgraded to a basic monthly subscription after the 7-day trial. 4 months later, they upgraded to a pro annual subscription

-- Customer-ID 18 started with a free trial subscription and then automatically continued with the pro monthly subscription after the 7-day trial

-- Customer-ID 19 started with a free trial subscription and then automatically continued with the pro monthly subscription after the 7-day trial. 2 months later, they upgraded to the pro annual subscription.


-------B. Data Analysis Questions -------

--1. How many customers has Foodie-Fi ever had?
SELECT COUNT (DISTINCT customer_id) AS Foodie_Fi_customers
FROM Foodie_Fi.subscriptions

--2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
WITH monthly_distribution AS (
    SELECT DATE_TRUNC('month', start_date)::DATE AS Starting_month,  plan_name, COUNT(start_date) AS number_of_customers
    FROM Foodie_Fi.subscriptions
        INNER JOIN Foodie_Fi.plans
            USING (plan_id)
    WHERE plan_id = '0'
    GROUP BY start_date, plan_name
    ORDER BY Starting_month
    )
SELECT Starting_month, plan_name, SUM(number_of_customers)
FROM monthly_distribution
GROUP BY Starting_month, plan_name
ORDER BY Starting_month

--3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT plan_name, COUNT(plan_name) AS Subscription_count
FROM Foodie_Fi.subscriptions
     INNER JOIN Foodie_Fi.plans
            USING (plan_id)
WHERE DATE_PART ('year', start_date) > '2020'
GROUP BY plan_name
ORDER BY plan_name

--4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
SELECT COUNT(customer_id) AS Churned_customers, 
        ROUND(COUNT(customer_id) * 100/(SELECT COUNT(DISTINCT customer_id) FROM Foodie_Fi.subscriptions)::NUMERIC, 1) AS Churn_percentage
FROM Foodie_Fi.subscriptions 
            INNER JOIN Foodie_Fi.plans
                USING (plan_id)
WHERE plan_name = 'churn'


--5. How many customers have churned straight after their initial free trial
-- what percentage is this rounded to the nearest whole number?
WITH subscribers AS (
    SELECT *,
    LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS lead_plan
    FROM foodie_fi.subscriptions
    ORDER BY customer_id
),
churned AS (
    SELECT
        COUNT(CASE WHEN plan_id = 0 AND lead_plan = 4 THEN 1 END) AS churned_straight,
        COUNT(CASE WHEN plan_id = 0 THEN 1 END) AS total_customers
    FROM subscribers
)
SELECT churned_straight, total_customers,
        ROUND(churned_straight  * 100/total_customers)::NUMERIC AS Percent_churned_straight
FROM churned

--6. What is the number and percentage of customer plans after their initial free trial?
WITH next_plan AS (
        SELECT customer_id, plan_id, 
          LEAD(plan_id, 1) OVER(PARTITION BY customer_id ORDER BY plan_id) as lead_plan
        FROM foodie_fi.subscriptions
            INNER JOIN foodie_fi.plans  
                USING(plan_id)
)

SELECT lead_plan, COUNT(*) AS customer_count,
       ROUND((COUNT(customer_id) * 100)::NUMERIC / (SELECT COUNT(DISTINCT customer_id) FROM foodie_fi.subscriptions),1) AS percentage_count
FROM next_plan
WHERE plan_id = 0
GROUP BY lead_plan
ORDER BY lead_plan

--7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH next_plan AS (
    SELECT *, RANK() OVER(PARTITION BY customer_id ORDER BY start_date DESC) AS RANK
    FROM foodie_fi.subscriptions
        INNER JOIN foodie_fi.plans  
            USING(plan_id)
    WHERE start_date <= '2020-12-31' ::DATE
)

SELECT plan_name, COUNT(plan_name), 
        ROUND((COUNT(plan_name) * 100)::NUMERIC / (SELECT COUNT(DISTINCT customer_id) FROM foodie_fi.subscriptions),1)::NUMERIC AS percentage 
FROM next_plan
WHERE rank = 1
GROUP BY plan_name
ORDER BY plan_name

--8. How many customers have upgraded to an annual plan in 2020?
SELECT COUNT (DISTINCT customer_id) AS pro_annual_customers
FROM foodie_fi.subscriptions
WHERE plan_id = 3
    AND DATE_PART ('year', start_date) = 2020
    
--9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH trial_plan AS (
        SELECT customer_id, start_date AS trial_date
        FROM foodie_fi.subscriptions
        WHERE plan_id = 0
),
pro_annual_plan AS (
    SELECT customer_id, start_date AS annual_date
    FROM foodie_fi.subscriptions
    WHERE plan_id = 3
)
SELECT ROUND(AVG(annual_date - trial_date),0) AS average_days_to_upgrade
FROM trial_plan 
    INNER JOIN pro_annual_plan
        USING(customer_id)
        
--10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH trial_plan AS (
        SELECT customer_id, start_date AS trial_date
        FROM foodie_fi.subscriptions
        WHERE plan_id = 0
),
pro_annual_plan AS (
    SELECT customer_id, start_date AS annual_date
    FROM foodie_fi.subscriptions
    WHERE plan_id = 3
),
periods AS (
SELECT CASE
        WHEN annual_date - trial_date < 31 THEN '0-30 days'
        WHEN annual_date - trial_date BETWEEN 31
        AND 60 THEN '31-60 days'
        WHEN annual_date - trial_date BETWEEN 61
        AND 90 THEN '61-90 days'
        WHEN annual_date - trial_date BETWEEN 91
        AND 120 THEN '91-120 days'
        WHEN annual_date - trial_date BETWEEN 121
        AND 150 THEN '121-150 days'
        WHEN annual_date - trial_date BETWEEN 151
        AND 180 THEN '151-180 days'
        WHEN annual_date - trial_date BETWEEN 181
        AND 210 THEN '181-210 days'
        WHEN annual_date - trial_date BETWEEN 211
        AND 240 THEN '211-240 days'
        WHEN annual_date - trial_date BETWEEN 241
        AND 270 THEN '241-270 days'
        WHEN annual_date - trial_date BETWEEN 271
        AND 300 THEN '271-300 days'
        WHEN annual_date - trial_date BETWEEN 301
        AND 330 THEN '301-330 days'
        WHEN annual_date - trial_date BETWEEN 331
        AND 360 THEN '331-360 days'
        WHEN annual_date - trial_date > 360 THEN '360+ days' 
      END AS upgrade_days,
      COUNT(annual_date - trial_date) AS number_of_customers,
      ROUND(AVG(annual_date - trial_date), 0) AS average_days_to_upgrade
FROM trial_plan 
    JOIN pro_annual_plan
        USING(customer_id)
GROUP BY upgrade_days
)

SELECT upgrade_days, number_of_customers, average_days_to_upgrade
FROM periods
ORDER BY CASE
        WHEN upgrade_days = '0-30 days' THEN 1
        WHEN upgrade_days = '31-60 days' THEN 2
        WHEN upgrade_days = '61-90 days' THEN 3
        WHEN upgrade_days = '91-120 days' THEN 4
        WHEN upgrade_days = '121-150 days' THEN 5
        WHEN upgrade_days = '151-180 days' THEN 6
        WHEN upgrade_days = '181-210 days' THEN 7
        WHEN upgrade_days = '211-240 days' THEN 8
        WHEN upgrade_days = '241-270 days' THEN 9
        WHEN upgrade_days = '271-300 days' THEN 10
        WHEN upgrade_days = '301-330 days' THEN 11
        WHEN upgrade_days = '331-360 days' THEN 12
        WHEN upgrade_days = '360+ days' THEN 13
        ELSE number_of_customers
    END 
    
--11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH next_plan AS (
  SELECT customer_id, plan_id, start_date,
        LEAD(plan_id, 1) OVER(PARTITION BY customer_id ORDER BY plan_id) as lead_plan
  FROM foodie_fi.subscriptions
  WHERE DATE_PART ('year', start_date) = 2020
    )
SELECT COUNT(customer_id) AS Downgraded
FROM next_plan
WHERE plan_id = 2 
  AND lead_plan = 1


-------C. Challenge Payment Question -------
DROP TABLE IF EXISTS payments_table;
CREATE TABLE payments_table AS (
        SELECT customer_id, s.plan_id, plan_name,  
                 generate_series(start_date,
                                    CASE
                                      WHEN s.plan_id = 3 THEN start_date
                                      WHEN s.plan_id = 4 THEN NULL
                                      WHEN LEAD(start_date) OVER(PARTITION BY customer_id ORDER BY start_date) IS NOT NULL 
                                        THEN LEAD(start_date) OVER(PARTITION BY customer_id ORDER BY start_date)
                                      ELSE '2020-12-31'::DATE
                                    END,
                                    '1 month' + '1 second'::INTERVAL) AS payment_date,
                  price AS Amount    
        FROM foodie_fi.subscriptions s
            INNER JOIN foodie_fi.plans p
                USING (plan_id)
        WHERE plan_id <> 0
            AND DATE_PART ('year', start_date) = 2020
    )
    
SELECT customer_id, plan_id, plan_name, payment_date::DATE :: varchar,
          CASE
            WHEN LAG(plan_id) OVER (PARTITION BY customer_id ORDER BY plan_id) <> plan_id
                AND DATE_PART('day', payment_date - LAG(payment_date) OVER(PARTITION BY customer_id ORDER BY plan_id)) < 30 
                    THEN Amount - LAG(Amount) OVER(PARTITION BY customer_id ORDER BY plan_id)
            ELSE Amount
            END AS Amount,
        ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY payment_date) AS payment_order 
FROM payments_table


-------D. Outside The Box Questions -------

--1. How would you calculate the rate of growth for Foodie-Fi?
--The current revenue subtracted by the previous revenue then divided by the previous revenue multiplied by 100 to get the percentage growth of the business.
--Values greater than 0 indicates a positive growth (profit) in business. Values less than 0 then indicate a negative growth (loss) in business. If the Value is 0 then their is no growth in the business (no profit or loss).
--Period over period(PoP) analysis is used to compare a measurement from one time period to that same measurement in a similar time period
--In this example we can do a month-over-month analysis or week-over-week analysis
--To calculate the revenue we would need to consider the change in plans, deductions, and cancellations.
--For this example I would calculate the monthly customer growth (outside the trial mode) instead of the revenue growth

WITH Monthly_customers AS (
                SELECT EXTRACT('Month' FROM start_date) AS Month,
                       TO_CHAR(start_date, 'Month') AS Months, 
                       COUNT(DISTINCT customer_id) AS Number_of_customers
                FROM foodie_fi.subscriptions
                    INNER JOIN foodie_fi.plans 
                        USING (plan_id)
                WHERE plan_name <> 'trial' 
                    AND plan_name <> 'churn'
                GROUP BY EXTRACT('Month' FROM start_date), TO_CHAR(start_date, 'Month')
                ORDER BY EXTRACT('Month' FROM start_date)
)

SELECT Months, Number_of_customers, 
        LAG(Number_of_customers, 1) OVER(ORDER BY Month) AS Previous_number_of_customers,
        (100 * (Number_of_customers - LAG(Number_of_customers, 1) OVER(ORDER BY Month)) / LAG(Number_of_customers, 1) OVER(ORDER BY Month)) || '%' AS percentage_growth
FROM Monthly_customers

--2. What key metrics would you recommend Foodie-Fi management to track over time to assess performance of their overall business?
--Customer retention (after trial period)
--Sales Revenue
--Sales Growth Year-to-date
--Monthly churn rate
--Average customer lifetime
--Rate of new customers
--Ratio new customers to paying customers

--3. What are some key customer journeys or experiences that you would analyse further to improve customer retention?
--Finding out the rate of customer retention post trial period
--Finding out what is the most used plan after the trial and why
--Finding out what is the most downgraded plan and why
--Finding out what is the most upgraded plan and why
--Finding out the months or quarters that produce the most customers and why

--4. If the Foodie-Fi team were to create an exit survey shown to customers who wish to cancel their subscription, what questions would you include in the survey?
--What prompted you to cancel your subscription
--What did you like the best and least about your subscription plan?
--Would you recommend this company to a friend? Why or why not?
--Did Foodie-Fi meet your expectations?  
--What suggestions do you have that the company can improve on?

--5. What business levers could the Foodie-Fi team use to reduce the customer churn rate? How would you validate the effectiveness of your ideas?
--To reduce customer churn rate after trial period one could:
    --Improve trial service/on-boarding period as first impressions is key
    -- Implement a customer feedback loop to improve the business and get an understanding of the customers feelings
    -- Email marketing by sending company newsletter to remind customers about the service and improve company's reputation. This can be achieved through email automation
    -- Establishing loyalty programs where long-standing active customers(users) are given discount prices for products as a sign of appreciation 
-- This can be analysed using descriptive analytics such as summary statistics, clustering, and Cohort analysis
