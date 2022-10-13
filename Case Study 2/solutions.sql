--Solved on PostgreSQL 14 by Daniel Mogbojuri--

--DATA WRANGLING--

--View customer_orders Data--
SELECT *
FROM pizza_runner.customer_orders

--View runner_orders Data--
SELECT *
FROM pizza_runner.runner_orders

--Inspect exclusions column in customer_orders--
SELECT DISTINCT exclusions 
FROM pizza_runner.customer_orders

--Inspect extras column in runner_orders--
SELECT DISTINCT extras
FROM pizza_runner.customer_orders

--Inspect extras column in runner_orders--
SELECT *
FROM pizza_runner.customer_orders

--Create temp table and clean new customer_orders table--
DROP TABLE IF EXISTS temp_customer_orders;
CREATE TEMP TABLE temp_customer_orders AS (
        SELECT order_id, customer_id, pizza_id, exclusions, extras, order_time
        FROM pizza_runner.customer_orders
)

--Cleaning data--
UPDATE temp_customer_orders
SET exclusions = CASE WHEN exclusions IN ('null', '') THEN NULL ELSE exclusions END,
    extras = CASE WHEN extras IN ('null', '') THEN NULL ELSE extras END
    
--Check cleaned temp_customer_orders table--
SELECT *
FROM temp_customer_orders

--Create temp table and clean new runner_orders table--
DROP TABLE IF EXISTS temp_runner_orders;
CREATE TEMP TABLE temp_runner_orders AS (
            SELECT order_id, runner_id, pickup_time,
                CASE
                    WHEN distance LIKE '%km' THEN TRIM ('km' FROM distance)
                    ELSE distance
                    END AS distance,
                CASE
                    WHEN duration LIKE '%minutes' THEN TRIM ('minutes' FROM duration)
                    WHEN duration LIKE '%mins' THEN TRIM ('mins' FROM duration)
                    WHEN duration LIKE '%minute' THEN TRIM ('minute' FROM duration)
                    ELSE duration
                    END AS duration,
                cancellation
            FROM pizza_runner.runner_orders
)

--Cleaning data--
UPDATE temp_runner_orders
SET pickup_time = CASE WHEN pickup_time LIKE 'null' THEN NULL ELSE pickup_time END,
    distance = CASE WHEN distance  LIKE 'null' THEN NULL ELSE distance END,
    duration = CASE WHEN duration LIKE 'null' THEN NULL ELSE duration END,
    cancellation = CASE WHEN cancellation IN ('null', '') THEN NULL ELSE cancellation END
    
--Changing datatypes--
ALTER TABLE temp_runner_orders
    ALTER COLUMN pickup_time TYPE TIMESTAMP USING pickup_time:: timestamp,
    ALTER COLUMN distance TYPE DECIMAL USING distance:: decimal,
    ALTER COLUMN duration TYPE INT USING duration:: integer
        
--Check cleaned temp_customer_orders table--
SELECT *
FROM temp_runner_orders

/* --------------------
   Case Study Questions
   --------------------*/
   
-------A. Pizza Metrics-------

--1. How many pizzas were ordered?
SELECT COUNT(order_id) AS Pizza_Orders
FROM temp_customer_orders

--2. How many unique customer orders were made?
SELECT COUNT (DISTINCT order_id) AS Customer_Orders
FROM temp_customer_orders
   
--3. How many successful orders were delivered by each runner?
SELECT DISTINCT runner_id, COUNT(order_id) as Successful_Orders
FROM temp_runner_orders
WHERE cancellation IS NULL
GROUP BY runner_id
   
--4. How many of each type of pizza was delivered?
SELECT DISTINCT p.pizza_name, COUNT(c.pizza_id) AS delivered
FROM temp_customer_orders c
    INNER JOIN temp_runner_orders o
        USING(order_id)
    INNER JOIN pizza_runner.pizza_names p
        USING(pizza_id)
WHERE cancellation IS NULL
GROUP BY p.pizza_name
ORDER BY p.pizza_name

--5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT DISTINCT customer_id, 
        SUM(CASE 
                WHEN pizza_id = 1 THEN 1 ELSE 0 END) AS Meat_lovers,
        SUM(CASE 
                WHEN pizza_id = 2 THEN 1 ELSE 0 END) AS Vegetarian
FROM temp_customer_orders
GROUP BY customer_id
ORDER BY customer_id

--6. What was the maximum number of pizzas delivered in a single order?
SELECT order_id, Pizza_Delivered
FROM (
    SELECT order_id, customer_id, COUNT(pizza_id) as Pizza_Delivered
    FROM temp_customer_orders c
        INNER JOIN temp_runner_orders r
            USING (order_id)
    WHERE cancellation IS NULL 
    GROUP BY order_id, customer_id) AS p
ORDER BY Pizza_Delivered DESC
LIMIT 1

--7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT DISTINCT customer_id, 
            SUM(CASE
                    WHEN (exclusions IS NOT NULL) OR 
                    (extras IS NOT NULL) THEN 1
                    ELSE 0 
                    END) AS Changes,
            SUM(CASE
                    WHEN (exclusions IS NULL) AND  
                    (extras IS NULL) THEN 1
                    ELSE 0 
                    END) AS No_Changes
FROM temp_customer_orders
    INNER JOIN temp_runner_orders
        USING (order_id)
WHERE cancellation IS NULL
GROUP BY customer_id
ORDER BY customer_id

--8. How many pizzas were delivered that had both exclusions and extras?
SELECT SUM(CASE WHEN (exclusions IS NOT NULL) AND (extras IS NOT NULL) THEN 1 ELSE 0 END) AS All_changes
FROM temp_customer_orders
    INNER JOIN temp_runner_orders
        USING (order_id)
WHERE cancellation is NULL

--9. What was the total volume of pizzas ordered for each hour of the day?
SELECT EXTRACT ('hour' FROM order_time) AS hour_day, COUNT(order_id) AS Total_Pizza_Ordered
FROM temp_customer_orders
GROUP BY hour_day
ORDER BY hour_day

--10. What was the volume of orders for each day of the week?
SELECT TO_CHAR(order_time, 'DAY') AS day_of_the_week, COUNT(order_id) AS Total_Pizza_Ordered
FROM temp_customer_orders
GROUP BY day_of_the_week
ORDER BY day_of_the_week desc


-------B. Runner and Customer Experience-------

--1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT DATE_TRUNC('week', registration_date)::DATE + 4 AS week,
       COUNT(runner_id) AS runners
FROM pizza_runner.runners
GROUP BY week
ORDER BY week

--2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
WITH runner_pickup AS (
  SELECT r.runner_id, r.order_id, c.order_time, r.pickup_time,
        AGE(pickup_time, order_time) AS pickup_minute
  FROM temp_customer_orders c
    INNER JOIN temp_runner_orders r
        USING(order_id)
)

SELECT runner_id, EXTRACT('minutes' FROM AVG(pickup_minute)) AS Average_arrival_minutes
FROM runner_pickup
GROUP BY runner_id
ORDER BY runner_id

--3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
WITH pizza_count AS (   
        SELECT order_id, order_time, COUNT(pizza_id) AS pizza_order_count
        FROM temp_customer_orders
        GROUP BY order_id, order_time
        ORDER BY order_id
), 
order_time AS (
        SELECT r.order_id, p.order_time, r.pickup_time, p.pizza_order_count,
               AGE(pickup_time, order_time) AS preparation_time
        FROM temp_runner_orders r
            INNER JOIN pizza_count p
                USING (order_id)
        WHERE pickup_time IS NOT NULL
)

SELECT pizza_order_count, EXTRACT('minutes' FROM AVG(preparation_time)) AS Average_time
FROM order_time
GROUP BY pizza_order_count
ORDER BY pizza_order_count

--4. What was the average distance travelled for each customer?
SELECT customer_id, ROUND(AVG(distance), 2) AS distance_travelled
FROM temp_customer_orders
    INNER JOIN temp_runner_orders
        USING (order_id)
GROUP BY customer_id
ORDER BY customer_id

--5. What was the difference between the longest and shortest delivery times for all orders?
SELECT MAX(duration)-MIN(duration) AS Delivery_difference
FROM temp_runner_orders
    INNER JOIN temp_customer_orders
        USING(order_id)
WHERE duration IS NOT NULL

--6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT runner_id, order_id, distance AS distance_in_Km, duration AS duration_in_minutes, 
        ROUND(AVG(distance * 60/duration), 2) AS Average_speed_Kmh
FROM temp_runner_orders
WHERE distance IS NOT NULL
    AND duration IS NOT NULL
GROUP BY runner_id, order_id, distance_in_Km, duration_in_minutes
ORDER BY runner_id, order_id, distance_in_Km, duration_in_minutes


--7. What is the successful delivery percentage for each runner?
SELECT runner_id, COUNT(order_id) AS Total_order_sent , COUNT(pickup_time) AS Order_taken, 
        ROUND(100 * COUNT(pickup_time) / COUNT(order_id))
FROM temp_runner_orders
GROUP BY runner_id
ORDER BY runner_id

-------C. Ingredient Optimisation-------

--1. What are the standard ingredients for each pizza?
WITH pizza_ingredient AS (
        SELECT pizza_id,
            UNNEST(STRING_TO_ARRAY(toppings, ','))::INT AS topping_id
        FROM pizza_runner.pizza_recipes
    ),
    toppings AS (
      SELECT pizza_name, topping_name
      FROM pizza_runner.pizza_names 
        INNER JOIN pizza_ingredient
            USING (pizza_id)
        INNER JOIN pizza_runner.pizza_toppings 
            USING (topping_id)
)
SELECT pizza_name, 
STRING_AGG (topping_name, ', ') AS ingredients
FROM toppings
GROUP BY pizza_name 
  
--2. What was the most commonly added extra?
--String_to_array splits the extra columns strings based on the delimiter (,) then convert it back to an Integer.
--UNNEST expands the result from the string_to_array to a set of rows. Converts comma seperated values in extras to set of rows.
--Join pizza topping with extras_table to get the name and count of extras in the orders. 
--Rank the count of toppings
WITH extras_table AS (
      SELECT order_id,
        UNNEST(STRING_TO_ARRAY(extras, ','))::INT AS topping_id
      FROM temp_customer_orders 
      WHERE extras <> 'NULL'
    ),
    extra_ingredient AS (
    SELECT
      topping_name AS extra_toppings,
      COUNT(topping_name) AS number_of_pizzas,
      RANK() OVER(ORDER BY COUNT(topping_name) DESC) AS ranks
    FROM extras_table 
      INNER JOIN pizza_runner.pizza_toppings 
        USING (topping_id)
    GROUP BY topping_name
)

SELECT extra_toppings, number_of_pizzas
FROM extra_ingredient
WHERE ranks = 1

--3. What was the most common exclusion?
WITH exclusions_table AS (
      SELECT order_id,
        UNNEST(STRING_TO_ARRAY(exclusions, ','))::INT AS topping_id
      FROM temp_customer_orders 
      WHERE exclusions <> 'NULL'
    ),
    exclusions_ingredient AS (
    SELECT
      topping_name AS exclusions_toppings,
      COUNT(topping_name) AS number_of_pizzas,
      RANK() OVER(ORDER BY COUNT(topping_name) DESC) AS ranks
    FROM exclusions_table 
      INNER JOIN pizza_runner.pizza_toppings 
        USING (topping_id)
    GROUP BY topping_name
)

SELECT exclusions_toppings, number_of_pizzas
FROM exclusions_ingredient
WHERE ranks = 1

--4. Generate an order item for each record in the customers_orders table in the format of one of the following:
--Meat Lovers
--Meat Lovers - Exclude Beef
--Meat Lovers - Extra Bacon
--Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

WITH ranking AS (
    SELECT *, ROW_NUMBER()OVER() AS ranker 
    FROM temp_customer_orders
),
pizza_join AS (
    SELECT ra.ranker, ra.order_id, pizza_name,
        CASE
            WHEN exclusions <> 'NULL' 
            AND topping_id IN (
                        SELECT
                              UNNEST(STRING_TO_ARRAY(exclusions, ','))::INT
                         ) THEN topping_name
            END AS exclusions,
        CASE 
            WHEN extras <> 'NULL'
            AND topping_id IN (
                        SELECT
                             UNNEST(STRING_TO_ARRAY(extras, ','))::INT
                        ) THEN topping_name
            END AS extras
    FROM pizza_runner.pizza_toppings AS t
        CROSS JOIN ranking as ra
        LEFT JOIN pizza_runner.pizza_names AS n 
            USING (pizza_id)
)

SELECT order_id, CONCAT(
                        pizza_name,
                        ' ',
                        CASE
                          WHEN COUNT(exclusions) > 0 THEN '- Exclude '
                          ELSE ''
                        END,
                        STRING_AGG(exclusions, ', '),
                        CASE
                          WHEN COUNT(extras) > 0 THEN ' - Extra '
                          ELSE ''
                        END,
                        STRING_AGG(extras, ', ')
                      ) AS pizza_with_toppings
FROM pizza_join
GROUP BY pizza_name, ranker, order_id
ORDER BY ranker

--5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
--For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

WITH ranking AS (
          SELECT *, ROW_NUMBER()OVER() AS ranker
          FROM temp_customer_orders
    ),
    All_one AS (
        SELECT ranker, ra.order_id, pizza_name, topping_name,
          CASE
            WHEN exclusions <> 'NULL'
            AND t.topping_id IN (
                          SELECT
                            UNNEST(STRING_TO_ARRAY(exclusions, ','))::INT
                        ) THEN NULL
            ELSE 
          CASE
             WHEN t.topping_id IN (
                            SELECT
                              UNNEST(STRING_TO_ARRAY(r.toppings, ','))::INT
                          ) THEN COUNT(topping_name)
              ELSE NULL
            END
          END AS count_toppings,
          CASE
            WHEN extras <> 'NULL'
            AND t.topping_id IN (
                          SELECT
                            UNNEST(string_to_array(extras, ','))::INT
                        ) THEN COUNT(topping_name)
            ELSE NULL
          END AS count_extra
        FROM pizza_runner.pizza_toppings AS t
          CROSS JOIN ranking AS ra
          CROSS JOIN pizza_runner.pizza_recipes AS r
          LEFT JOIN pizza_runner.pizza_names AS n 
            ON r.pizza_id = n.pizza_id
        WHERE
          ra.pizza_id = n.pizza_id
        GROUP BY
          pizza_name,
          ranker,
          ra.order_id,
          topping_name,
          toppings,
          exclusions,
          extras,
          t.topping_id
      ),
    ingredients AS (
        SELECT ranker, order_id, pizza_name, 
                CONCAT(
                        CASE
                          WHEN (SUM(count_toppings) + SUM(count_extra)) > 1 
                          THEN CONCAT((SUM(count_toppings) + SUM(count_extra)), 'x')
                        END,
                        topping_name
                      ) AS topping_name
        FROM All_one
        WHERE count_toppings > 0 OR count_extra > 0
        GROUP BY
      pizza_name,
      ranker,
      order_id,
      topping_name
    )
SELECT
  order_id,
  CONCAT(
    pizza_name,
    ': ',
    STRING_AGG(
      topping_name,
      ', '
      ORDER BY
        topping_name)
      )
FROM ingredients
GROUP BY
  pizza_name,
  ranker,
  order_id
ORDER BY
  ranker
      
--6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
WITH ranking AS (
        SELECT *, ROW_NUMBER() OVER() AS ranker
        FROM temp_customer_orders
    ),
    quantity AS (
        SELECT ranker, topping_name,
               CASE
                   WHEN exclusions <> 'NULL'
                   AND topping_id IN (
                                SELECT
                                   UNNEST(STRING_TO_ARRAY(exclusions, ','))::INT
                 ) THEN 0
                 ELSE CASE
                     WHEN topping_id IN (
                                   SELECT
                                        UNNEST(STRING_TO_ARRAY(toppings, ','))::INT
                 ) THEN COUNT(topping_name)
               END
               END AS count_toppings,
               CASE
                   WHEN extras <> 'NULL'
                   AND topping_id IN (
                                SELECT
                                    UNNEST(STRING_TO_ARRAY(extras, ','))::INT
                ) THEN COUNT(topping_name)
                  ELSE 0 
                  END AS count_extras
    FROM pizza_runner.pizza_toppings AS t
        CROSS JOIN pizza_runner.pizza_recipes AS r
        CROSS JOIN ranking as ra
        LEFT JOIN temp_runner_orders AS ro
            USING (order_id)
    WHERE
      ro.order_id = ra.order_id
      AND ra.pizza_id = r.pizza_id
      AND pickup_time IS NOT NULL 
      AND distance IS NOT NULL
      AND duration IS NOT NULL
    GROUP BY
      topping_name,
      exclusions,
      extras,
      toppings,
      topping_id,
      ranker   
 )
SELECT
  topping_name,
  (SUM(count_toppings) + SUM(count_extras)) AS total_ingredients
FROM quantity
GROUP BY
  topping_name
ORDER BY
  total_ingredients DESC
   
-------D. Ingredient Optimisation-------

--1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
SELECT SUM(CASE WHEN pizza_id = 1 THEN 12
                WHEN pizza_id = 2 THEN 10
           END) AS Total_dollar_gains
FROM temp_customer_orders
    INNER JOIN temp_runner_orders
        USING (order_id)
WHERE cancellation IS NULL

--2. What if there was an additional $1 charge for any pizza extras?
--Add cheese is $1 extra
WITH Charges AS (
        SELECT *, (CASE WHEN pizza_id = 1 THEN 12
                     WHEN pizza_id = 2 THEN 10
                END) AS price
FROM temp_customer_orders
    INNER JOIN temp_runner_orders
        USING (order_id)
WHERE cancellation IS NULL
)
SELECT SUM(CASE WHEN extras IS NULL THEN price
                WHEN length(extras) = 1 THEN price + 1
                ELSE price + 2 
                END) AS Price_Extra_Charges
FROM Charges
   
--3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset 
-- generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
DROP TABLE IF EXISTS runner_rating;
CREATE TABLE runner_rating (
    id SMALLSERIAL PRIMARY KEY,
    order_id INTEGER,
    customer_id INTEGER,
    runner_id INTEGER,
    rating INTEGER,
    rating_time TIMESTAMP
  );
  
INSERT INTO runner_rating (
    order_id,
    customer_id,
    runner_id,
    rating,
    rating_time
  )
VALUES
  ('1', '101', '1', '4', '2020-01-01 19:51:34'),
  ('2', '101', '1', '4', '2020-01-01 20:10:03'),
  ('3', '102', '1', '2', '2020-01-03 8:43:18'),
  ('4', '103', '2', '3', '2020-01-04 15:22:58'),
  ('5', '104', '3', '1', '2020-01-08 21:33:27'),
  ('7', '105', '2', '5', '2020-01-08 23:34:54'),
  ('8', '102', '2', '3', '2020-01-10 1:05:46'),
  ('10', '104', '1', '2', '2020-01-11 19:35:25');
  
--4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
-- customer_id, order_id, runner_id, rating, order_time, pickup_time, Time between order and pickup, Delivery duration, Average speed, Total number of pizzas
SELECT c.customer_id, c.order_id, o.runner_id, r.rating, c.order_time, o.pickup_time, 
    AGE (o.pickup_time, c.order_time) AS delivery_period, o.duration AS Delivery_duration, ROUND(AVG(o.distance * 60/o.duration), 1) AS Average_Speed, COUNT(o.order_id)
FROM temp_customer_orders c
    INNER JOIN temp_runner_orders o
        USING(order_id)
    INNER JOIN runner_rating r
        USING (order_id)
GROUP BY c.customer_id, c.order_id, o.runner_id, r.rating, c.order_time, o.pickup_time,
          delivery_period, Delivery_duration
          
--5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled 
-- how much money does Pizza Runner have left over after these deliveries?
WITH Charges AS (
        SELECT *, (CASE WHEN pizza_id = 1 THEN 12
                     WHEN pizza_id = 2 THEN 10
                END) AS price
FROM temp_customer_orders
    INNER JOIN temp_runner_orders
        USING (order_id)
WHERE cancellation IS NULL
),
expenses AS (
  SELECT
   SUM(distance) * 0.3 as expense
  FROM
    temp_runner_orders
      WHERE
       cancellation IS NULL
    ) 
SELECT
  SUM(price) - expense AS net_profit_in_dollars
FROM charges
  CROSS JOIN expenses
GROUP BY expense

-------E. Bonus Questions-------
--If Danny wants to expand his range of pizzas 
--how would this impact the existing data design? 
--Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?
INSERT INTO pizza_runner.pizza_names (
    pizza_id, 
    pizza_name
)

VALUES
  (3, 'Supreme');
  
INSERT INTO pizza_runner.pizza_recipes (
    pizza_id, 
    toppings
)

VALUES
  (3, '1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12');
  
  
SELECT *
FROM pizza_runner.pizza_names AS n
  LEFT JOIN pizza_runner.pizza_recipes AS r 
   USING (pizza_id) 