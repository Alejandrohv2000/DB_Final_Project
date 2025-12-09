-- Task B: CRUD Operations for Restaurant & Delivery Management System
USE restaurant_db;

-- Categories
INSERT INTO categories (name, description) VALUES
('Pizza', 'Pizzas and flatbreads'),
('Burgers', 'All burgers'),
('Drinks', 'Sodas, water, juices')
ON DUPLICATE KEY UPDATE name = name; 

-- Inventory (for triggers/tests)
INSERT INTO inventory_items (name, unit, current_quantity, reorder_level) VALUES
('Flour (kg)', 'kg', 100.00, 10.00),
('Tomato sauce (L)', 'L', 50.00, 5.00),
('Cheese (kg)', 'kg', 40.00, 5.00)
ON DUPLICATE KEY UPDATE name = name;

-- Menu items
INSERT INTO menu_items (category_id, name, description, unit_price, available)
SELECT c.category_id, m.name, m.description, m.unit_price, TRUE
FROM (SELECT 'Pizza' AS cat, 'Margherita' AS name, 'Tomato, mozzarella, basil' AS description, 12.50 AS unit_price
      UNION ALL
      SELECT 'Pizza','Pepperoni','Tomato, mozzarella, pepperoni',14.00
      UNION ALL
      SELECT 'Burgers','Classic Burger','Beef patty, lettuce, tomato',11.00
      UNION ALL
      SELECT 'Drinks','Cola','330ml can',2.50) AS m
JOIN categories c ON c.name = m.cat
ON DUPLICATE KEY UPDATE name = name;

-- Roles
INSERT INTO roles (name, description) VALUES
('Cashier','Handles orders and payments'),
('Cook','Prepares orders'),
('Manager','Admin and management')
ON DUPLICATE KEY UPDATE name = name;

-- Employees 
INSERT INTO employees (role_id, first_name, last_name, phone, hire_date, active)
SELECT r.role_id, e.fname, e.lname, e.phone, CURDATE(), TRUE
FROM (SELECT 'Manager' AS role, 'Alice' AS fname, 'Wong' AS lname, '514-111-2222' AS phone
      UNION ALL SELECT 'Cashier','Bob','Smith','514-222-3333'
      UNION ALL SELECT 'Cook','Carlos','Rivera','514-333-4444'
      UNION ALL SELECT 'Cashier','Dina','Lopez','514-444-5555'
) AS e
JOIN roles r ON r.name = e.role
ON DUPLICATE KEY UPDATE first_name = first_name;

-- Customers
INSERT INTO customers (first_name, last_name, email, phone)
VALUES
('John','Doe','john.doe@example.com','514-555-0101'),
('Mary','Johnson','mary.j@example.com','514-555-0202')
ON DUPLICATE KEY UPDATE email = email;

-- Addresses
INSERT INTO addresses (customer_id, line1, city, province, postal_code, is_default)
SELECT c.customer_id, CONCAT('123 ', c.last_name, ' St') AS line1, 'Sherbrooke', 'Quebec', 'J1H0A1', TRUE
FROM customers c
WHERE c.email = 'john.doe@example.com'
ON DUPLICATE KEY UPDATE line1 = line1;

-- 1) INSERT new menu item
INSERT INTO menu_items (category_id, name, description, unit_price, available)
VALUES (
  (SELECT category_id FROM categories WHERE name = 'Burgers' LIMIT 1),
  'Garden Salad', 'Mixed greens, tomatoes, vinaigrette', 7.00, TRUE
);

-- Verify insert
SELECT * FROM menu_items WHERE name = 'Garden Salad';

-- 2) UPDATE prices

UPDATE menu_items m
JOIN categories c ON m.category_id = c.category_id
SET m.unit_price = ROUND(m.unit_price + 1.00,2)
WHERE c.name = 'Pizza';

-- b) Update a single item price directly
UPDATE menu_items SET unit_price = 13.99 WHERE name = 'Margherita';

-- Verify updates
SELECT name, unit_price FROM menu_items WHERE name IN ('Margherita','Pepperoni');

-- 3) REMOVE discontinued dishes (two approaches shown)
UPDATE menu_items SET available = FALSE WHERE name = 'Garden Salad';
SELECT name, available FROM menu_items WHERE name = 'Garden Salad';

SELECT mi.menu_item_id, mi.name, COUNT(oi.order_item_id) AS usage_count
FROM menu_items mi
LEFT JOIN order_items oi ON oi.menu_item_id = mi.menu_item_id
WHERE mi.name = 'Garden Salad'
GROUP BY mi.menu_item_id, mi.name;

DELETE mi FROM menu_items mi
LEFT JOIN order_items oi ON oi.menu_item_id = mi.menu_item_id
WHERE mi.name = 'Garden Salad' AND oi.order_item_id IS NULL;

-- 4) Place a new order with multiple items (transaction)
START TRANSACTION;

-- 4.1 Create a new order 
INSERT INTO orders (customer_id, cashier_id, order_type, payment_method, total_amount)
VALUES (
  (SELECT customer_id FROM customers WHERE email = 'john.doe@example.com' LIMIT 1),
  (SELECT employee_id FROM employees WHERE first_name = 'Bob' AND last_name = 'Smith' LIMIT 1),
  'DELIVERY', 'CARD', 0.00
);

SET @new_order_id = LAST_INSERT_ID();

-- 4.2 Add multiple items to order 
INSERT INTO order_items (order_id, menu_item_id, quantity, unit_price, line_total)
SELECT @new_order_id, m.menu_item_id, t.qty, m.unit_price, ROUND(t.qty * m.unit_price,2)
FROM (
  SELECT 'Margherita' AS name, 1 AS qty
  UNION ALL SELECT 'Classic Burger', 2
) AS t
JOIN menu_items m ON m.name = t.name;

-- 4.3 Recalculate total and update the order
UPDATE orders o
SET o.total_amount = (SELECT IFNULL(SUM(oi.line_total),0) FROM order_items oi WHERE oi.order_id = o.order_id)
WHERE o.order_id = @new_order_id;

COMMIT;

-- Verify created order and its items
SELECT * FROM orders WHERE order_id = @new_order_id;
SELECT * FROM order_items WHERE order_id = @new_order_id;

-- 5) Assign a delivery driver
INSERT INTO deliveries (order_id, driver_id, delivery_address_id, assigned_at, status)
VALUES (
  @new_order_id,
  (SELECT e.employee_id FROM employees e WHERE e.first_name = 'Dina' AND e.last_name = 'Lopez' LIMIT 1),
  (SELECT a.address_id FROM addresses a JOIN customers c ON a.customer_id = c.customer_id WHERE c.email = 'john.doe@example.com' LIMIT 1),
  NOW(), 'ASSIGNED'
)
ON DUPLICATE KEY UPDATE assigned_at = VALUES(assigned_at), status = VALUES(status);

-- Also updates order status to OUT_FOR_DELIVERY when picked up 
SET @old_status = (SELECT status FROM orders WHERE order_id = @new_order_id);
UPDATE orders SET status = 'OUT_FOR_DELIVERY' WHERE order_id = @new_order_id;

-- Insert into order_status_history (capture actual previous status)
INSERT INTO order_status_history (order_id, old_status, new_status, changed_by_id)
VALUES (@new_order_id, @old_status, 'OUT_FOR_DELIVERY', (SELECT employee_id FROM employees WHERE first_name = 'Bob' LIMIT 1));

-- Verify delivery record
SELECT * FROM deliveries WHERE order_id = @new_order_id;

-- 6) Update order status (required operation)

-- 6.1 Cook sets PREPARING
SET @old_status = (SELECT status FROM orders WHERE order_id = @new_order_id);
UPDATE orders SET status = 'PREPARING' WHERE order_id = @new_order_id;
INSERT INTO order_status_history (order_id, old_status, new_status, changed_by_id)
VALUES (@new_order_id, @old_status, 'PREPARING', (SELECT employee_id FROM employees WHERE first_name = 'Carlos' LIMIT 1));

-- 6.2 Manager or system marks DELIVERED and sets delivered_at timestamp in deliveries
SET @old_status = (SELECT status FROM orders WHERE order_id = @new_order_id);
UPDATE orders SET status = 'DELIVERED' WHERE order_id = @new_order_id;
UPDATE deliveries SET delivered_at = NOW(), status = 'DELIVERED' WHERE order_id = @new_order_id;
INSERT INTO order_status_history (order_id, old_status, new_status, changed_by_id)
VALUES (@new_order_id, @old_status, 'DELIVERED', (SELECT employee_id FROM employees WHERE first_name = 'Alice' LIMIT 1));

-- Verify final statuses
SELECT o.order_id, o.status, o.total_amount, d.status AS delivery_status, d.delivered_at
FROM orders o LEFT JOIN deliveries d ON o.order_id = d.order_id WHERE o.order_id = @new_order_id;

-- 7) List sales per day and sales per category 
SELECT DATE(order_datetime) AS sale_date, COUNT(*) AS orders_count, ROUND(SUM(total_amount),2) AS total_sales
FROM orders
WHERE order_datetime >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY DATE(order_datetime)
ORDER BY sale_date DESC;

-- b) Sales per category 
SELECT c.name AS category, COUNT(DISTINCT oi.order_id) AS orders_with_category,
       SUM(oi.line_total) AS total_sales, SUM(oi.quantity) AS total_items_sold
FROM order_items oi
JOIN menu_items m ON oi.menu_item_id = m.menu_item_id
JOIN categories c ON m.category_id = c.category_id
GROUP BY c.name
ORDER BY total_sales DESC;

-- 8) Delete an order (only if permitted by business rules)
-- Business rule example: An order cannot be hard-deleted if status = 'DELIVERED'
-- If allowed: delete order_items first, deliveries, then orders
SET @target_order = @new_order_id;

SELECT order_id, status FROM orders WHERE order_id = @target_order;

-- Check business rule
SELECT CASE WHEN status = 'DELIVERED' THEN 'CANNOT_DELETE' ELSE 'OK_TO_DELETE' END AS allowed
FROM orders WHERE order_id = @target_order;

-- If allowed, perform deletion in transaction
START TRANSACTION;
-- Only delete related rows when the order is not DELIVERED. Use JOIN to ensure business rule is enforced atomically.
DELETE d FROM deliveries d
JOIN orders o ON d.order_id = o.order_id
WHERE d.order_id = @target_order AND o.status <> 'DELIVERED';

DELETE oi FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
WHERE oi.order_id = @target_order AND o.status <> 'DELIVERED';

DELETE osh FROM order_status_history osh
JOIN orders o ON osh.order_id = o.order_id
WHERE osh.order_id = @target_order AND o.status <> 'DELIVERED';

DELETE o FROM orders o WHERE o.order_id = @target_order AND o.status <> 'DELIVERED';
COMMIT;

-- Verify deletion
SELECT * FROM orders WHERE order_id = @target_order;

-- 9) Convenience: Example SELECTs to demonstrate reading operations
-- List full order details with customer and items
SELECT o.order_id, o.order_datetime, o.status, o.total_amount,
       CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
       GROUP_CONCAT(CONCAT(mi.name, ' x', oi.quantity) SEPARATOR '; ') AS items
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN menu_items mi ON oi.menu_item_id = mi.menu_item_id
GROUP BY o.order_id
ORDER BY o.order_datetime DESC
LIMIT 20;

-- Show menu items by category and availability
SELECT c.name AS category, m.name AS item, m.unit_price, m.available
FROM menu_items m JOIN categories c ON m.category_id = c.category_id
ORDER BY c.name, m.name;
