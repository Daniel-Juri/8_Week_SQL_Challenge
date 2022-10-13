--Solved on PostgreSQL 12 by Daniel Mogbojuri

/* --------------------
   Case Study Questions
   --------------------*/
   
-- 1. What is the total amount each customer spent at the restaurant?

SELECT customer_id, SUM(price) as total_sales
FROM dannys_diner.sales
JOIN dannys_diner.menu
    USING (product_id)
GROUP BY customer_id
ORDER BY customer_id

-- 2. How many days has each customer visited the restaurant?

SELECT customer_id, COUNT(DISTINCT order_date) as days_visited
FROM dannys_diner.sales
GROUP BY customer_id
ORDER BY customer_id

-- 3. What was the first item from the menu purchased by each customer?

WITH firstorder as (
      SELECT *, ROW_NUMBER()OVER(partition by customer_id order by order_date) as ranks
      FROM dannys_diner.menu
        JOIN dannys_diner.sales
            USING (product_id)
 )
 
 SELECT customer_id, order_date, product_name
 FROM firstorder
 WHERE ranks = 1
 
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

SELECT product_name, COUNT(product_id) as purchases
FROM dannys_diner.menu
    JOIN dannys_diner.sales
        USING (product_id)
GROUP BY product_name
ORDER BY purchases desc
LIMIT 1

-- 5. Which item was the most popular for each customer?

WITH item_rank as (
    SELECT s.customer_ID, m.product_name, COUNT(s.product_id) as Product_Count,
      DENSE_RANK()OVER(Partition by s.Customer_ID order by COUNT(s.product_id) DESC) as rank
    FROM dannys_diner.menu m
        JOIN dannys_diner.sales s
            USING(product_id)
    GROUP BY s.customer_ID, m.product_name
)

SELECT Customer_id,Product_name,Product_Count
FROM item_rank
WHERE rank = 1

-- 6. Which item was purchased first by the customer after they became a member?

WITH first_item as (
    SELECT s.customer_ID, u.product_name, s.order_date, m.join_date, RANK()OVER(Partition by s.Customer_ID order by s.order_date) as rank
    FROM dannys_diner.sales s
        JOIN dannys_diner.members m
            USING(customer_id)
        JOIN dannys_diner.menu u
            USING (product_id)
    WHERE s.order_date >= m.join_date
)

SELECT customer_id, product_name
FROM first_item
WHERE rank = 1

-- 7. Which item was purchased just before the customer became a member?

WITH first_item as
(
    SELECT s.customer_ID, u.product_name, s.order_date, m.join_date, RANK()OVER(Partition by s.Customer_ID order by s.order_date desc) as rank
    FROM dannys_diner.sales s
        JOIN dannys_diner.members m
            USING(customer_id)
        JOIN dannys_diner.menu u
            USING (product_id)
    WHERE s.order_date < m.join_date
)

SELECT customer_id, product_name
FROM first_item
WHERE rank = 1

-- 8. What is the total items and amount spent for each member before they became a member?

SELECT s.customer_id, COUNT(u.product_name) as total_items, SUM(u.price) as amount_spent
FROM dannys_diner.sales s 
    JOIN dannys_diner.menu u
        USING(product_id)
    JOIN dannys_diner.members m
        USING(customer_id)
WHERE s.order_date < m.join_date
GROUP BY s.customer_id
ORDER BY s.customer_id

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

WITH Total_points as (
        SELECT product_id, 
                CASE   
                    WHEN product_id = 1 THEN price * 20 ELSE price * 10 END AS points
        FROM dannys_diner.menu
   )
   
SELECT s.customer_id, T.product_id, SUM(T.points) as total_points
FROM dannys_diner.sales s
    JOIN Total_points T
        USING(product_id)
GROUP BY s.customer_id, T.product_id
ORDER BY s.customer_id

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

SELECT s.customer_id, 
            SUM(CASE 
                 WHEN order_date BETWEEN join_date AND (join_date + INTERVAL '6' DAY)
                   THEN 20 * price
                 WHEN product_id = 1
                   THEN 20 * price
                   ELSE 10 * price
                   END
              ) AS total_points
FROM dannys_diner.sales s
    JOIN dannys_diner.members m
        USING (customer_id)
    JOIN dannys_diner.menu u
        USING (product_id)
WHERE order_date BETWEEN '2021-01-01' AND '2021-01-31'
GROUP BY s.customer_id
ORDER BY s.customer_id

--BONUS QUESTIONS--

-- 11. JOIN ALL THE THINGS

SELECT s.customer_id, s.order_date, u.product_name, u.price,
        (CASE
            WHEN s.order_date >= m.join_date THEN 'Y'
            ELSE 'N'
            END) AS member
FROM dannys_diner.sales s
    LEFT JOIN dannys_diner.menu u
        USING (product_id)
    LEFT JOIN dannys_diner.members m
        USING (customer_id)
ORDER BY s.customer_id, s.order_date, u.product_name

-- 12. RANK ALL THE THINGS

WITH ranking as (
    SELECT s.customer_id, s.order_date, u.product_name, u.price,
            (CASE
                WHEN s.order_date >= m.join_date THEN 'Y'
                ELSE 'N'
                END) AS member
    FROM dannys_diner.sales s
        JOIN dannys_diner.menu u
            USING (product_id)
        JOIN dannys_diner.members m
            USING (customer_id)
    ORDER BY s.customer_id, s.order_date, u.product_name
) 
   
SELECT *, CASE 
            WHEN member = 'Y' THEN 
            RANK()OVER(partition by ranking.customer_id, member order by order_date)
            ELSE NULL 
            END
FROM ranking




