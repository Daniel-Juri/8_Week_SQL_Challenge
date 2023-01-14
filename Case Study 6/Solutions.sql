--Solved on PostgreSQL 14 by Daniel Mogbojuri--

/* --------------------
   Case Study Questions
   --------------------*/
   
-------2. Digital Analysis-------

--I. How many users are there?
SELECT COUNT (DISTINCT user_id) AS Number_of_Users
FROM clique_bait.users

--II. How many cookies does each user have on average?
WITH Cookies AS (
	SELECT user_id AS Users 
		 , COUNT(cookie_id)::NUMERIC AS Number_of_cookies
	FROM clique_bait.users
	GROUP BY Users
	ORDER BY Users
	)

SELECT ROUND(AVG(Number_of_cookies), 2)
FROM Cookies

--III. What is the unique number of visits by all users per month?
SELECT TO_CHAR (event_time, 'MONTH') AS month, COUNT(DISTINCT visit_id) AS Number_of_visits
FROM clique_bait.users
	JOIN clique_bait.events
		USING (cookie_id)
GROUP BY month
ORDER BY MIN(event_time)

--IV. What is the number of events for each event type?
SELECT event_name, COUNT(event_type) AS Number_of_event
FROM clique_bait.event_identifier
	JOIN clique_bait.events
		USING (event_type)
GROUP BY event_name
ORDER BY Number_of_event desc

--V. What is the percentage of visits which have a purchase event?
SELECT ROUND(100 * COUNT( DISTINCT visit_id)::NUMERIC / (SELECT COUNT(DISTINCT visit_id)::NUMERIC FROM clique_bait.events), 2) AS purchase_percent
FROM clique_bait.event_identifier 
	JOIN clique_bait.events 
		USING (event_type)
WHERE event_name = 'Purchase'

--VI. What is the percentage of visits which view the checkout page but do not have a purchase event?
WITH checkout_page AS (
	SELECT COUNT(visit_id) AS visits
	FROM clique_bait.event_identifier ei
		JOIN clique_bait.events e 
			USING (event_type) 
		JOIN clique_bait.page_hierarchy p
			USING (page_id)
	WHERE ei.event_name = 'Page View'
		AND p.page_name = 'Checkout'
)

SELECT ROUND(100-(100 * COUNT(DISTINCT e.visit_id)::NUMERIC / (SELECT visits FROM checkout_page)), 2) AS Not_purchase_event
FROM clique_bait.events e 
	JOIN clique_bait.event_identifier ei
		USING (event_type)
WHERE ei.event_name = 'Purchase'

--VII. What are the top 3 pages by number of views?
SELECT page_name, COUNT(page_id) AS Number_of_views
FROM clique_bait.event_identifier ei
	JOIN clique_bait.events e 
		USING (event_type) 
	JOIN clique_bait.page_hierarchy p
		USING (page_id)
WHERE e.event_type = '1'
GROUP BY page_name
ORDER BY Number_of_views desc
LIMIT 3;

--VII. What is the number of views and cart adds for each product category?
SELECT product_category, 
		SUM(CASE WHEN e.event_type = '1' THEN 1 ELSE 0 END) AS Number_of_views,
		SUM(CASE WHEN e.event_type = '2' THEN 1 ELSE 0 END) AS Cart_Adds
FROM clique_bait.event_identifier ei
	JOIN clique_bait.events e 
		USING (event_type) 
	JOIN clique_bait.page_hierarchy p
		USING (page_id)
WHERE product_category <> 'null'
GROUP BY product_category
ORDER BY Number_of_views desc

--VIII. What are the top 3 products by purchases?
WITH Purchased_products AS (
	SELECT page_name, product_category, event_name, COUNT(*) AS Number_of_purchases, 
			ROW_NUMBER()OVER(ORDER BY COUNT(event_name) DESC) AS align
	FROM clique_bait.event_identifier ei
		JOIN clique_bait.events e 
			USING (event_type) 
		JOIN clique_bait.page_hierarchy p
			USING (page_id)
	WHERE visit_id IN (
			SELECT DISTINCT visit_id
			FROM clique_bait.events e
			WHERE event_type = '3'
			)
		AND p.product_id IS NOT NULL
		AND event_name = 'Add to Cart'
	GROUP BY page_name, product_category, event_name
)

SELECT page_name, product_category, Number_of_purchases
FROM Purchased_products
WHERE align IN (1, 2, 3)



-------3. Product Funnel Analysis-------

--Using a single SQL query - create a new output table which has the following details:
---I.  How many times was each product viewed?
---II. How many times was each product added to cart?
---III. How many times was each product added to a cart but not purchased (abandoned)?
---IV.  How many times was each product purchased?

WITH products AS (
	SELECT product_id, page_name AS product_name, product_category, 
		SUM(CASE WHEN e.event_type = '1' THEN 1 ELSE 0 END) AS Number_of_views,
		SUM(CASE WHEN e.event_type = '2' THEN 1 ELSE 0 END) AS Added_to_Cart
	FROM clique_bait.event_identifier ei
		JOIN clique_bait.events e 
			USING (event_type) 
		JOIN clique_bait.page_hierarchy p
			USING (page_id)
	WHERE product_category IS NOT NULL
	GROUP BY product_id, page_name, product_category
),

Abandoned_products AS (
	 SELECT product_id, page_name AS product_name, product_category, COUNT(*) AS abandoned
     FROM clique_bait.event_identifier ei
		JOIN clique_bait.events e 
			USING (event_type) 
		JOIN clique_bait.page_hierarchy p
			USING (page_id)
 	 WHERE event_type = '2'
  		AND e.visit_id NOT IN (
    			SELECT e.visit_id
				FROM clique_bait.events e
					JOIN clique_bait.event_identifier ei 
						USING (event_type) 
				WHERE event_type = '3')
	 GROUP BY product_id, page_name, product_category
),

Purchased_products AS (
	SELECT product_id, page_name AS product_name, product_category, COUNT(*) AS purchased
     FROM clique_bait.event_identifier ei
		JOIN clique_bait.events e 
			USING (event_type) 
		JOIN clique_bait.page_hierarchy p
			USING (page_id)
 	 WHERE event_type = '2'
  		AND e.visit_id IN (
    			SELECT e.visit_id
				FROM clique_bait.events e
					JOIN clique_bait.event_identifier ei 
						USING (event_type) 
				WHERE event_type = '3')
	 GROUP BY product_id, page_name, product_category
)

SELECT ps.product_name, ps.number_of_views, ps.added_to_cart, pa.abandoned, pp.purchased
INTO agg_products
FROM products ps
	JOIN Abandoned_products pa 
		USING (product_id)
	JOIN Purchased_products pp 
		USING (product_id);
		
SELECT *
FROM agg_products;
		
		
--Additionally, create another table which further aggregates the data for the above points but this time for each product category instead of individual products.
WITH product_category AS (
	SELECT p.product_category, 
		SUM(CASE WHEN e.event_type = '1' THEN 1 ELSE 0 END) AS Number_of_views,
		SUM(CASE WHEN e.event_type = '2' THEN 1 ELSE 0 END) AS Added_to_Cart
	FROM clique_bait.event_identifier ei
		JOIN clique_bait.events e 
			USING (event_type) 
		JOIN clique_bait.page_hierarchy p
			USING (page_id)
	WHERE product_category IS NOT NULL
	GROUP BY product_category
),

Abandoned_category AS (
	 SELECT p.product_category, COUNT(*) AS abandoned
     FROM clique_bait.event_identifier ei
		JOIN clique_bait.events e 
			USING (event_type) 
		JOIN clique_bait.page_hierarchy p
			USING (page_id)
 	 WHERE event_type = '2'
  		AND e.visit_id NOT IN (
    			SELECT e.visit_id
				FROM clique_bait.events e
					JOIN clique_bait.event_identifier ei 
						USING (event_type) 
				WHERE event_type = '3')
	 GROUP BY product_category
),

Purchased_category AS (
	SELECT p.product_category, COUNT(*) AS purchased
     FROM clique_bait.event_identifier ei
		JOIN clique_bait.events e 
			USING (event_type) 
		JOIN clique_bait.page_hierarchy p
			USING (page_id)
 	 WHERE event_type = '2'
  		AND e.visit_id IN (
    			SELECT e.visit_id
				FROM clique_bait.events e
					JOIN clique_bait.event_identifier ei 
						USING (event_type) 
				WHERE event_type = '3')
	 GROUP BY product_category
)

SELECT pc.product_category, pp.number_of_views, pp.added_to_cart, ac.abandoned, pc.purchased
FROM product_category pp
	JOIN Abandoned_category ac 
		USING (product_category)
	JOIN Purchased_category pc 
		USING (product_category);
		

----Use your 2 new output tables - answer the following questions:

--Which product had the most views, cart adds and purchases?
WITH highest_info AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY number_of_views DESC) AS views,
      ROW_NUMBER() OVER (ORDER BY added_to_cart DESC) AS carts,
      ROW_NUMBER() OVER (ORDER BY purchased DESC) AS purchases
    FROM agg_products  
  )
  
SELECT product_name, number_of_views, added_to_cart, purchased
FROM highest_info
WHERE views = 1 
	OR carts = 1
  	OR purchases = 1
	
--Which product was most likely to be abandoned?
SELECT product_name, MAX(abandoned) as Most_abandoned
FROM agg_products
GROUP BY 1
ORDER BY MAX(abandoned) DESC
LIMIT 1;

--Which product had the highest view to purchase percentage?
SELECT product_name, ROUND((100.0 * purchased::NUMERIC / Number_of_views::NUMERIC), 2) AS purchase_per_view
FROM agg_products
ORDER BY purchase_per_view DESC
LIMIT 1

--What is the average conversion rate from view to cart add?
SELECT ROUND(AVG(100.0 * added_to_cart / Number_of_views)::NUMERIC, 2) AS avg_cart_per_view
FROM agg_products

--What is the average conversion rate from cart add to purchase?
SELECT ROUND(AVG(100.0 * purchased/added_to_cart)::NUMERIC, 2) AS avg_purchase_per_cart
FROM agg_products


-------4. Campaigns Analysis-------

--Generate a table that has 1 single row for every unique visit_id record and has the following columns:

--user_id
--visit_id
--visit_start_time: the earliest event_time for each visit
--page_views: count of page views for each visit
--cart_adds: count of product cart add events for each visit
--purchase: 1/0 flag if a purchase event exists for each visit
--campaign_name: map the visit to a campaign if the visit_start_time falls between the start_date and end_date
--impression: count of ad impressions for each visit
--click: count of ad clicks for each visit
--(Optional column) cart_products: a comma separated text value with products added to the cart sorted by the order they were added to the cart (hint: use the sequence_number)

SELECT u.user_id, e.visit_id,
    MIN(event_time) AS visit_start_time,
    SUM(CASE WHEN ei.event_type = '1' THEN 1 ELSE 0 END) AS page_views,
    SUM(CASE WHEN ei.event_type = '2' THEN 1 ELSE 0 END) AS cart_adds,
    SUM(CASE WHEN ei.event_type = '3' THEN 1 ELSE 0 END) AS purchase,
    c.campaign_name,
    SUM(CASE WHEN ei.event_type = '4' THEN 1 ELSE 0 END) AS impression,
    SUM(CASE WHEN ei.event_type = '5' THEN 1 ELSE 0 END) AS click,
    STRING_AGG ((CASE WHEN ei.event_type = '2' THEN ph.page_name END)::CHAR, ', ' ORDER BY e.sequence_number) 
INTO Joined_table
FROM clique_bait.events e
	JOIN clique_bait.users u 
		ON e.cookie_id = u.cookie_id
	JOIN clique_bait.event_identifier ei 
		ON e.event_type = ei.event_type
	JOIN clique_bait.page_hierarchy ph 
		ON e.page_id = ph.page_id
	LEFT JOIN clique_bait.campaign_identifier c 
		ON e.event_time BETWEEN c.start_date AND c.end_date
GROUP BY u.user_id, e.visit_id, c.campaign_name;

SELECT *
FROM Joined_table;