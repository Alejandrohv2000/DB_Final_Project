USE restaurant_db;

DROP USER IF EXISTS 'cashier_user'@'localhost';
DROP USER IF EXISTS 'cook_user'@'localhost';
DROP USER IF EXISTS 'manager_user'@'localhost';

CREATE USER 'cashier_user'@'localhost' IDENTIFIED BY 'Cashier123!';
CREATE USER 'cook_user'@'localhost' IDENTIFIED BY 'Cook123!';
CREATE USER 'manager_user'@'localhost' IDENTIFIED BY 'Manager123!';

GRANT ALL PRIVILEGES ON restaurant_db.* TO 'manager_user'@'localhost';

GRANT SELECT ON restaurant_db.menu_items TO 'cashier_user'@'localhost';
GRANT SELECT ON restaurant_db.categories TO 'cashier_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON restaurant_db.customers TO 'cashier_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON restaurant_db.addresses TO 'cashier_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON restaurant_db.orders TO 'cashier_user'@'localhost';
GRANT SELECT, INSERT, UPDATE ON restaurant_db.order_items TO 'cashier_user'@'localhost';

GRANT SELECT ON restaurant_db.orders TO 'cook_user'@'localhost';
GRANT SELECT ON restaurant_db.order_items TO 'cook_user'@'localhost';
GRANT UPDATE (status) ON restaurant_db.orders TO 'cook_user'@'localhost';

FLUSH PRIVILEGES;
