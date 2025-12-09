-- D - Stored Procedures & Automated Operations
USE restaurant_db;

-- 1) Stored Function: Calculate Order Total
-- Purpose: Sum all line_total values for a given order_id
-- Returns: DECIMAL(10,2) representing the total amount

DELIMITER $$
CREATE FUNCTION calculate_order_total(p_order_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total DECIMAL(10,2);

    SELECT IFNULL(SUM(line_total), 0)
    INTO total
    FROM order_items
    WHERE order_id = p_order_id;

    RETURN total;
END$$
DELIMITER ;

-- Test Function: Calculate Order Total
SELECT calculate_order_total(1) AS order_total_amount;

-- 2) Stored Procedure: Assign a Delivery Driver Automatically
-- Purpose: Assign a driver to an order and create delivery record
-- Parameters: p_order_id (INT), p_driver_id (INT)
-- Error Handling: Validates order exists and is DELIVERY type

DELIMITER $$
CREATE PROCEDURE assign_driver(IN p_order_id INT, IN p_driver_id INT)
BEGIN
    DECLARE order_exists INT;
    DECLARE order_type VARCHAR(20);
    DECLARE driver_exists INT;

    -- Validate order exists
    SELECT COUNT(*) INTO order_exists FROM orders WHERE order_id = p_order_id;
    IF order_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Order does not exist.';
    END IF;

    -- Validate order type is DELIVERY
    SELECT order_type INTO order_type FROM orders WHERE order_id = p_order_id;
    IF order_type <> 'DELIVERY' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Order type is not DELIVERY.';
    END IF;

    -- Validate driver exists
    SELECT COUNT(*) INTO driver_exists FROM employees WHERE employee_id = p_driver_id;
    IF driver_exists = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Error: Driver does not exist.';
    END IF;

    -- Insert delivery record with driver and default address
    INSERT INTO deliveries (order_id, driver_id, delivery_address_id, assigned_at, status)
    SELECT 
        o.order_id,
        p_driver_id,
        a.address_id,
        NOW(),
        'ASSIGNED'
    FROM orders o
    LEFT JOIN addresses a ON a.customer_id = o.customer_id AND a.is_default = TRUE
    WHERE o.order_id = p_order_id;

END$$
DELIMITER ;

-- Test Procedure: Assign a Delivery Driver
-- Assumes order_id=1 exists and is DELIVERY type, and employee_id=1 exists
-- CALL assign_driver(1, 1);
-- SELECT * FROM deliveries WHERE order_id = 1;

CALL assign_driver(1, 1);


-- 3) Stored Procedure: Generate Daily Sales Report
-- Purpose: Summarize sales (count, total revenue) for a given date
-- Parameters: p_report_date (DATE) - defaults to today if NULL
-- Output: Order count, total revenue, average order value

DELIMITER $$
CREATE PROCEDURE generate_daily_sales_report(IN p_report_date DATE)
BEGIN
    DECLARE report_date DATE;
    
    -- If no date provided, use today
    SET report_date = IFNULL(p_report_date, CURDATE());

    -- Main sales summary for the day
    SELECT 
        report_date AS report_date,
        COUNT(DISTINCT o.order_id) AS total_orders,
        ROUND(SUM(o.total_amount), 2) AS total_revenue,
        ROUND(AVG(o.total_amount), 2) AS avg_order_value,
        COUNT(DISTINCT o.customer_id) AS unique_customers
    FROM orders o
    WHERE DATE(o.order_datetime) = report_date
    GROUP BY report_date;

    -- Sales breakdown by category for the day
    SELECT 
        c.name AS category,
        COUNT(DISTINCT oi.order_id) AS orders_with_category,
        SUM(oi.quantity) AS items_sold,
        ROUND(SUM(oi.line_total), 2) AS category_revenue
    FROM order_items oi
    JOIN menu_items m ON oi.menu_item_id = m.menu_item_id
    JOIN categories c ON m.category_id = c.category_id
    JOIN orders o ON oi.order_id = o.order_id
    WHERE DATE(o.order_datetime) = report_date
    GROUP BY c.name
    ORDER BY category_revenue DESC;

END$$
DELIMITER ;

-- Test Procedure: Generate Daily Sales Report
-- CALL generate_daily_sales_report(NULL); -- For today
-- CALL generate_daily_sales_report('2024-06-15'); -- For specific date




