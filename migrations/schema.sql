-- Ractive_ordersestaurant Digital Ordering System Database Schema
CREATE DATABASE IF NOT EXISTS restaurant_db;
USE restaurant_db;

-- Drop tables if they exist (for clean setup)
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS menu_items;
DROP TABLE IF EXISTS tables;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS dining_sessions;
DROP TABLE IF EXISTS daily_stats;

-- Categories table
CREATE TABLE categories (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name_en VARCHAR(100) NOT NULL,
    name_th VARCHAR(100) NOT NULL,
    slug VARCHAR(50) UNIQUE NOT NULL,
    sort_order INT DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Users table (for admin authentication)
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100) UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role ENUM('admin', 'staff', 'manager') DEFAULT 'staff',
    is_active BOOLEAN DEFAULT TRUE,
    last_login TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Tables management
CREATE TABLE tables (
    id INT PRIMARY KEY AUTO_INCREMENT,
    table_number VARCHAR(10) UNIQUE NOT NULL,
    qr_code VARCHAR(255) UNIQUE NOT NULL,
    seats INT NOT NULL DEFAULT 4,
    status ENUM('free', 'occupied', 'reserved', 'dirty') DEFAULT 'free',
    current_session_id VARCHAR(100) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Menu items
CREATE TABLE menu_items (
    id INT PRIMARY KEY AUTO_INCREMENT,
    category_id INT NOT NULL,
    name_en VARCHAR(200) NOT NULL,
    name_th VARCHAR(200) NOT NULL,
    description_en TEXT,
    description_th TEXT,
    price DECIMAL(10,2) NOT NULL,
    icon VARCHAR(10) DEFAULT '🍽️',
    image_url VARCHAR(500),
    is_vegetarian BOOLEAN DEFAULT FALSE,
    is_spicy BOOLEAN DEFAULT FALSE,
    is_popular BOOLEAN DEFAULT FALSE,
    is_available BOOLEAN DEFAULT TRUE,
    preparation_time INT DEFAULT 15, -- minutes
    sort_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE,
    INDEX idx_category (category_id),
    INDEX idx_available (is_available),
    INDEX idx_popular (is_popular)
);

-- Customers/Avatars for each dining session
CREATE TABLE customers (
    id INT PRIMARY KEY AUTO_INCREMENT,
    session_id VARCHAR(100) NOT NULL,
    table_id INT NOT NULL,
    avatar_emoji VARCHAR(10) NOT NULL,
    nickname VARCHAR(100) NOT NULL,
    is_ordering BOOLEAN DEFAULT TRUE,
    payment_method ENUM('cash', 'qr', 'card') DEFAULT 'cash',
    avatar_order INT NOT NULL, -- Order of avatar in the group
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (table_id) REFERENCES tables(id) ON DELETE CASCADE,
    INDEX idx_session (session_id),
    INDEX idx_table (table_id)
);

-- Orders
CREATE TABLE orders (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_number VARCHAR(20) UNIQUE NOT NULL,
    session_id VARCHAR(100) NOT NULL,
    table_id INT NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0,
    tax_amount DECIMAL(10,2) DEFAULT 0,
    service_charge DECIMAL(10,2) DEFAULT 0,
    status ENUM('pending', 'preparing', 'cooking', 'ready', 'served', 'cancelled') DEFAULT 'pending',
    payment_status ENUM('unpaid', 'partial', 'paid', 'refunded') DEFAULT 'unpaid',
    queue_number VARCHAR(10) NOT NULL,
    estimated_time INT DEFAULT 20, -- minutes
    special_instructions TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    served_at TIMESTAMP NULL,
    FOREIGN KEY (table_id) REFERENCES tables(id) ON DELETE CASCADE,
    INDEX idx_session (session_id),
    INDEX idx_status (status),
    INDEX idx_queue (queue_number),
    INDEX idx_created (created_at)
);

-- Order items (individual items in an order)
CREATE TABLE order_items (
    id INT PRIMARY KEY AUTO_INCREMENT,
    order_id INT NOT NULL,
    customer_id INT NOT NULL,
    menu_item_id INT NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    total_price DECIMAL(10,2) NOT NULL,

    -- Customizations
    spicy_level INT DEFAULT 0, -- 0-4
    protein_choice VARCHAR(50) DEFAULT 'Original',
    special_notes TEXT,

    status ENUM('pending', 'preparing', 'cooking', 'ready', 'served') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
    FOREIGN KEY (menu_item_id) REFERENCES menu_items(id) ON DELETE CASCADE,
    INDEX idx_order (order_id),
    INDEX idx_customer (customer_id),
    INDEX idx_menu_item (menu_item_id),
    INDEX idx_status (status)
);

-- Sessions tracking (for analytics)
CREATE TABLE dining_sessions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    session_id VARCHAR(100) UNIQUE NOT NULL,
    table_id INT NOT NULL,
    customer_count INT NOT NULL,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP NULL,
    total_amount DECIMAL(10,2) DEFAULT 0,
    total_orders INT DEFAULT 0,
    FOREIGN KEY (table_id) REFERENCES tables(id) ON DELETE CASCADE,
    INDEX idx_session (session_id),
    INDEX idx_table (table_id),
    INDEX idx_started (started_at)
);

-- Analytics table for reporting
CREATE TABLE daily_stats (
    id INT PRIMARY KEY AUTO_INCREMENT,
    date DATE UNIQUE NOT NULL,
    total_orders INT DEFAULT 0,
    total_revenue DECIMAL(10,2) DEFAULT 0,
    total_customers INT DEFAULT 0,
    avg_order_value DECIMAL(10,2) DEFAULT 0,
    avg_wait_time INT DEFAULT 0, -- minutes
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_date (date)
);

-- Triggers for automatic calculations
DELIMITER //

-- Update order total when order_items change
CREATE TRIGGER update_order_total_after_insert
AFTER INSERT ON order_items
FOR EACH ROW
BEGIN
    UPDATE orders 
    SET total_amount = (
        SELECT COALESCE(SUM(total_price), 0) 
        FROM order_items 
        WHERE order_id = NEW.order_id
    )
    WHERE id = NEW.order_id;
END//

CREATE TRIGGER update_order_total_after_update
AFTER UPDATE ON order_items
FOR EACH ROW
BEGIN
    UPDATE orders 
    SET total_amount = (
        SELECT COALESCE(SUM(total_price), 0) 
        FROM order_items 
        WHERE order_id = NEW.order_id
    )
    WHERE id = NEW.order_id;
END//

CREATE TRIGGER update_order_total_after_delete
AFTER DELETE ON order_items
FOR EACH ROW
BEGIN
    UPDATE orders 
    SET total_amount = (
        SELECT COALESCE(SUM(total_price), 0) 
        FROM order_items 
        WHERE order_id = OLD.order_id
    )
    WHERE id = OLD.order_id;
END//

DELIMITER ;

-- Views for common queries
CREATE VIEW active_orders AS
SELECT 
    o.id,
    o.order_number,
    o.queue_number,
    o.table_id,
    t.table_number,
    o.total_amount,
    o.status,
    o.created_at,
    o.estimated_time,
    COUNT(oi.id) as item_count
FROM orders o
JOIN tables t ON o.table_id = t.id
LEFT JOIN order_items oi ON o.id = oi.order_id
WHERE o.status NOT IN ('served', 'cancelled')
GROUP BY o.id, o.order_number, o.queue_number, o.table_id, t.table_number, o.total_amount, o.status, o.created_at, o.estimated_time
ORDER BY o.created_at ASC;

CREATE VIEW menu_with_categories AS
SELECT 
    mi.id,
    mi.name_en,
    mi.name_th,
    mi.description_en,
    mi.description_th,
    mi.price,
    mi.icon,
    mi.image_url,
    mi.is_vegetarian,
    mi.is_spicy,
    mi.is_popular,
    mi.is_available,
    mi.preparation_time,
    c.name_en as category_en,
    c.name_th as category_th,
    c.slug as category_slug
FROM menu_items mi
JOIN categories c ON mi.category_id = c.id
WHERE mi.is_available = TRUE AND c.is_active = TRUE
ORDER BY c.sort_order, mi.sort_order, mi.name_en;
