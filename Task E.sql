USE restaurant_db;

DROP TRIGGER IF EXISTS trg_status_history;
DROP TRIGGER IF EXISTS trg_prevent_menu_delete;
DROP TRIGGER IF EXISTS trg_reduce_inventory;

DELIMITER $$

CREATE TRIGGER trg_status_history
AFTER UPDATE ON orders
FOR EACH ROW
BEGIN
    IF NEW.status <> OLD.status THEN
        INSERT INTO order_status_history(order_id, old_status, new_status, changed_by_id)
        VALUES(OLD.order_id, OLD.status, NEW.status, NEW.cashier_id);
    END IF;
END$$

CREATE TRIGGER trg_prevent_menu_delete
BEFORE DELETE ON menu_items
FOR EACH ROW
BEGIN
    IF EXISTS (SELECT 1 FROM order_items WHERE menu_item_id = OLD.menu_item_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'This menu item has been used in orders and cannot be deleted.';
    END IF;
END$$

CREATE TRIGGER trg_reduce_inventory
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE inventory_items i
    JOIN menu_item_ingredients m
        ON m.inventory_item_id = i.inventory_item_id
    SET i.current_quantity =
        i.current_quantity - (NEW.quantity * m.quantity_per_unit)
    WHERE m.menu_item_id = NEW.menu_item_id;
END$$

DELIMITER ;
