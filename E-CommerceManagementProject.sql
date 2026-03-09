-- =====================================================
-- PROJECT 4: E-COMMERCE MANAGEMENT SYSTEM
-- =====================================================

-- 1. CREATE DATABASE
DROP DATABASE IF EXISTS ecommerce_system;
CREATE DATABASE ecommerce_system;
USE ecommerce_system;

-- =====================================================
-- 2. TABLE CREATION
-- =====================================================

-- Customers
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    phone VARCHAR(15),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Categories (Self-Referencing Hierarchy)
CREATE TABLE categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    parent_category_id INT,
    FOREIGN KEY (parent_category_id) 
        REFERENCES categories(category_id)
        ON DELETE SET NULL
);

-- Products
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    price DECIMAL(10,2) NOT NULL CHECK (price > 0),
    stock INT NOT NULL CHECK (stock >= 0),
    category_id INT,
    attributes JSON,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) 
        REFERENCES categories(category_id)
        ON DELETE SET NULL
);

-- Orders
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('Pending','Shipped','Delivered','Cancelled') DEFAULT 'Pending',
    total_amount DECIMAL(12,2) DEFAULT 0,
    FOREIGN KEY (customer_id) 
        REFERENCES customers(customer_id)
        ON DELETE CASCADE
);

-- Order Items (Many-to-Many)
CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    product_id INT,
    quantity INT CHECK (quantity > 0),
    price DECIMAL(10,2),
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    UNIQUE(order_id, product_id)
);

-- Payments
CREATE TABLE payments (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id INT,
    payment_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    amount DECIMAL(12,2),
    payment_method ENUM('Card','UPI','NetBanking','Cash'),
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE
);

-- =====================================================
-- 3. INDEXES
-- =====================================================

CREATE INDEX idx_customer_email ON customers(email);
CREATE INDEX idx_product_category ON products(category_id);
CREATE INDEX idx_order_customer ON orders(customer_id);
CREATE INDEX idx_order_status_date ON orders(status, order_date);

-- =====================================================
-- 4. TRIGGERS
-- =====================================================

-- Reduce stock after order item insert
DELIMITER //
CREATE TRIGGER reduce_stock
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE products
    SET stock = stock - NEW.quantity
    WHERE product_id = NEW.product_id;
END;
//
DELIMITER ;

-- Update total order amount
DELIMITER //
CREATE TRIGGER update_order_total
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE orders
    SET total_amount = (
        SELECT SUM(quantity * price)
        FROM order_items
        WHERE order_id = NEW.order_id
    )
    WHERE order_id = NEW.order_id;
END;
//
DELIMITER ;

-- =====================================================
-- 5. SAMPLE DATA
-- =====================================================

INSERT INTO customers (full_name,email,phone,address) VALUES
('John Doe','john@email.com','1111111111','New York'),
('Sara Khan','sara@email.com','2222222222','Chicago'),
('Michael Lee','michael@email.com','3333333333','Boston');

INSERT INTO categories (category_name,parent_category_id) VALUES
('Electronics',NULL),
('Mobiles',1),
('Laptops',1),
('Fashion',NULL);

INSERT INTO products (product_name,price,stock,category_id,attributes) VALUES
('iPhone 14',999,50,2,'{"brand":"Apple","color":"Black"}'),
('Dell XPS 13',1200,30,3,'{"brand":"Dell","RAM":"16GB"}'),
('T-Shirt',25,200,4,'{"size":"L","color":"Blue"}');

-- Transaction Example
START TRANSACTION;

INSERT INTO orders (customer_id,status) VALUES (1,'Pending');
INSERT INTO order_items (order_id,product_id,quantity,price)
VALUES (1,1,2,999);

INSERT INTO payments (order_id,amount,payment_method)
VALUES (1,1998,'Card');

COMMIT;

-- =====================================================
-- 6. VIEWS
-- =====================================================

CREATE OR REPLACE VIEW order_summary AS
SELECT 
    o.order_id,
    c.full_name,
    o.order_date,
    o.status,
    o.total_amount
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id;

CREATE OR REPLACE VIEW product_sales AS
SELECT 
    p.product_name,
    SUM(oi.quantity) AS total_sold
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
GROUP BY p.product_name;

-- =====================================================
-- 7. STORED PROCEDURE
-- =====================================================

DELIMITER //
CREATE PROCEDURE PlaceOrder(
    IN cust_id INT,
    IN prod_id INT,
    IN qty INT
)
BEGIN
    DECLARE prod_price DECIMAL(10,2);

    SELECT price INTO prod_price
    FROM products
    WHERE product_id = prod_id;

    START TRANSACTION;

    INSERT INTO orders(customer_id,status)
    VALUES (cust_id,'Pending');

    SET @new_order_id = LAST_INSERT_ID();

    INSERT INTO order_items(order_id,product_id,quantity,price)
    VALUES (@new_order_id, prod_id, qty, prod_price);

    COMMIT;
END;
//
DELIMITER ;

-- =====================================================
-- 8. STORED FUNCTION
-- =====================================================

DELIMITER //
CREATE FUNCTION GetCustomerTotalSpend(cust_id INT)
RETURNS DECIMAL(12,2)
DETERMINISTIC
BEGIN
    DECLARE total DECIMAL(12,2);

    SELECT SUM(total_amount)
    INTO total
    FROM orders
    WHERE customer_id = cust_id;

    RETURN IFNULL(total,0);
END;
//
DELIMITER ;

-- =====================================================
-- 9. WINDOW FUNCTIONS
-- =====================================================

-- Rank customers by total spending
SELECT 
    customer_id,
    SUM(total_amount) AS total_spend,
    RANK() OVER (ORDER BY SUM(total_amount) DESC) AS spending_rank
FROM orders
GROUP BY customer_id;

-- Running daily sales
SELECT 
    DATE(order_date) AS order_day,
    SUM(total_amount) AS daily_sales,
    SUM(SUM(total_amount)) OVER (ORDER BY DATE(order_date)) AS running_total
FROM orders
GROUP BY DATE(order_date);

-- =====================================================
-- 10. CTE (Common Table Expression)
-- =====================================================

WITH high_value_orders AS (
    SELECT order_id, total_amount
    FROM orders
    WHERE total_amount > 1000
)
SELECT * FROM high_value_orders;

-- =====================================================
-- 11. ADVANCED BUSINESS QUERIES
-- =====================================================

-- Top 3 selling products
SELECT product_name, total_sold
FROM product_sales
ORDER BY total_sold DESC
LIMIT 3;

-- Customers who never placed orders
SELECT full_name
FROM customers
WHERE customer_id NOT IN (
    SELECT DISTINCT customer_id FROM orders
);

-- Monthly revenue
SELECT 
    DATE_FORMAT(order_date,'%Y-%m') AS month,
    SUM(total_amount) AS revenue
FROM orders
GROUP BY month
ORDER BY month;

-- =====================================================
-- 12. PROCEDURE CALL EXAMPLE
-- =====================================================

CALL PlaceOrder(2,3,5);
SELECT GetCustomerTotalSpend(1);

-- =====================================================
-- 13. FINAL CHECK
-- =====================================================

SELECT * FROM order_summary;
SELECT * FROM product_sales;