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