--CREATING DB and TABLES
--1. Users
CREATE TABLE users (
  user_id int NOT NULL AUTO_INCREMENT,
  full_name varchar(100) NOT NULL,
  email varchar(150) NOT NULL,
  password_hash varchar(255) NOT NULL,
  created_at datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (user_id),
  UNIQUE KEY (email)
);

-- 2. Categories Table 
CREATE TABLE Categories (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    parent_category_id INT DEFAULT NULL,
    category_name VARCHAR(80) NOT NULL,
    category_type ENUM('ROOT', 'FILTER_GROUP', 'FILTER_VALUE') NOT NULL,
    description VARCHAR(255) DEFAULT NULL,
    CONSTRAINT uq_category_name_per_parent UNIQUE (parent_category_id, category_name),
    CONSTRAINT fk_category_parent FOREIGN KEY (parent_category_id)
        REFERENCES Categories(category_id) ON DELETE RESTRICT
);
 
-- 3. Brands Table
CREATE TABLE Brands (
    brand_id INT AUTO_INCREMENT PRIMARY KEY,
    brand_name VARCHAR(100) NOT NULL UNIQUE,
    website VARCHAR(255) DEFAULT NULL
);
 
-- 4. Occasions Table
CREATE TABLE Occasions (
    occasion_id INT AUTO_INCREMENT PRIMARY KEY,
    occasion_name VARCHAR(60) NOT NULL UNIQUE,
    description VARCHAR(255) DEFAULT NULL
);
 
-- 5. ClothingItems Table 
CREATE TABLE ClothingItems (
    item_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    brand_id INT DEFAULT NULL,
    item_name VARCHAR(120) NOT NULL,
    size VARCHAR(30) DEFAULT NULL,
    purchase_date DATE DEFAULT NULL,
    purchase_price DECIMAL(10,2) DEFAULT NULL,
    availability_status ENUM('Available','In Laundry','Lent Out','Donated')
        NOT NULL DEFAULT 'Available',
    notes TEXT DEFAULT NULL,
    image_url VARCHAR(500) DEFAULT NULL,
    CONSTRAINT fk_clothing_user FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    CONSTRAINT fk_clothing_brand FOREIGN KEY (brand_id) REFERENCES Brands(brand_id) ON DELETE SET NULL
);
 
-- 6. ItemCategories Table 
CREATE TABLE ItemCategories (
    item_id INT NOT NULL,
    category_id INT NOT NULL,
    PRIMARY KEY (item_id, category_id),
    CONSTRAINT fk_itemcat_item FOREIGN KEY (item_id) REFERENCES ClothingItems(item_id) ON DELETE CASCADE,
    CONSTRAINT fk_itemcat_category FOREIGN KEY (category_id) REFERENCES Categories(category_id) ON DELETE CASCADE
);
 
-- 7. Outfits Table 
CREATE TABLE Outfits (
    outfit_id INT AUTO_INCREMENT PRIMARY KEY,
    outfit_name VARCHAR(100) NOT NULL,
    user_id INT NOT NULL,
    description TEXT DEFAULT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    is_favorite BOOLEAN NOT NULL DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
);
 
-- 8. OutfitItems Table 
CREATE TABLE OutfitItems (
    outfit_id INT NOT NULL,
    item_id INT NOT NULL,
    PRIMARY KEY (outfit_id, item_id),
    CONSTRAINT fk_outfititems_outfit FOREIGN KEY (outfit_id) REFERENCES Outfits(outfit_id) ON DELETE CASCADE,
    CONSTRAINT fk_outfititems_item FOREIGN KEY (item_id) REFERENCES ClothingItems(item_id) ON DELETE CASCADE
);
 
-- 9. OutfitOccasions Table 
CREATE TABLE OutfitOccasions (
    outfit_id INT NOT NULL,
    occasion_id INT NOT NULL,
    PRIMARY KEY (outfit_id, occasion_id),
    CONSTRAINT fk_outfitoccasions_outfit FOREIGN KEY (outfit_id) REFERENCES Outfits(outfit_id) ON DELETE CASCADE,
    CONSTRAINT fk_outfitoccasions_occasion FOREIGN KEY (occasion_id) REFERENCES Occasions(occasion_id) ON DELETE CASCADE
);
 
-- 10. OutfitPlans Table
CREATE TABLE OutfitPlans (
    plan_id INT AUTO_INCREMENT PRIMARY KEY,
    outfit_id INT NOT NULL,
    occasion_id INT DEFAULT NULL,
    planned_date DATE NOT NULL,
    plan_status ENUM('Planned','Worn','Skipped') NOT NULL DEFAULT 'Planned',
    notes VARCHAR(255) DEFAULT NULL,
    CONSTRAINT fk_plan_outfit FOREIGN KEY (outfit_id) REFERENCES Outfits(outfit_id) ON DELETE CASCADE,
    CONSTRAINT fk_plan_occasion FOREIGN KEY (occasion_id) REFERENCES Occasions(occasion_id) ON DELETE SET NULL
);
 
-- 11. WearLogs Table 
CREATE TABLE WearLogs (
    wear_log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    outfit_id INT NOT NULL,
    worn_at DATETIME NOT NULL,
    feedback VARCHAR(255) DEFAULT NULL,
    colour_rating TINYINT DEFAULT NULL,
    size_rating TINYINT DEFAULT NULL,
    comfort_rating TINYINT DEFAULT NULL,
    style_rating TINYINT DEFAULT NULL,
    CONSTRAINT fk_wearlog_outfit FOREIGN KEY (outfit_id) REFERENCES Outfits(outfit_id) ON DELETE CASCADE,
    CONSTRAINT chk_colour_rating  CHECK (colour_rating  BETWEEN 1 AND 5),
    CONSTRAINT chk_size_rating    CHECK (size_rating    BETWEEN 1 AND 5),
    CONSTRAINT chk_comfort_rating CHECK (comfort_rating BETWEEN 1 AND 5),
    CONSTRAINT chk_style_rating   CHECK (style_rating   BETWEEN 1 AND 5)
);
 
-- 12. SuggestedOutfits Table 
CREATE TABLE SuggestedOutfits (
    suggestion_id INT AUTO_INCREMENT PRIMARY KEY,
    outfit_id INT NOT NULL,
    wear_log_id BIGINT NOT NULL,
    rank_position TINYINT NOT NULL,   
    score DECIMAL(5,3) NOT NULL,         
    suggested_at DATETIME(6) NOT NULL,
    CONSTRAINT fk_suggested_outfit FOREIGN KEY (outfit_id) REFERENCES Outfits(outfit_id) ON DELETE CASCADE,
    CONSTRAINT fk_suggested_wearlog FOREIGN KEY (wear_log_id) REFERENCES WearLogs(wear_log_id) ON DELETE CASCADE,
    CONSTRAINT chk_rank_top3 CHECK (rank_position BETWEEN 1 AND 3)
);

--INSERTING SAMPLE DATA

-- 1. Users
INSERT INTO Users
    (user_id, full_name, email, password_hash, created_at)
VALUES
    (1, 'Aanya Sharma', 'aanya@example.com',
     '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
     '2026-08-01 10:00:00'),
    (2, 'Rohan Mehta', 'rohan@example.com',
     '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy',
     '2026-08-05 11:30:00');


-- 2. Categories

INSERT INTO Categories
    (category_id, parent_category_id, category_name,
     category_type, description)
VALUES
    -- Clothing root
    (1,  NULL, 'Clothing', 'ROOT', 'Clothing items'),
    (2,  1, 'Type', 'FILTER_GROUP', 'Type of clothing'),
    (3,  2, 'T-Shirt', 'FILTER_VALUE', 'T-shirts'),
    (4,  2, 'Shirt', 'FILTER_VALUE', 'Casual and formal shirts'),
    (5,  2, 'Jeans', 'FILTER_VALUE', 'Denim jeans'),
    (6,  2, 'Trousers', 'FILTER_VALUE', 'Trousers'),
    (7,  2, 'Jacket', 'FILTER_VALUE', 'Jackets'),
    (8,  2, 'Hoodie', 'FILTER_VALUE', 'Hoodies'),

    (9,  1, 'Colour', 'FILTER_GROUP', 'Clothing colours'),
    (10, 9, 'Black', 'FILTER_VALUE', 'Black clothing'),
    (11, 9, 'Blue', 'FILTER_VALUE', 'Blue clothing'),
    (12, 9, 'White', 'FILTER_VALUE', 'White clothing'),
    (13, 9, 'Beige', 'FILTER_VALUE', 'Beige clothing'),

    (14, 1, 'Season', 'FILTER_GROUP', 'Suitable season'),
    (15, 14, 'Summer', 'FILTER_VALUE', 'Summer clothing'),
    (16, 14, 'Winter', 'FILTER_VALUE', 'Winter clothing'),
    (17, 14, 'All-season', 'FILTER_VALUE', 'Suitable for multiple seasons'),

    (18, 1, 'Fabric', 'FILTER_GROUP', 'Clothing fabric'),
    (19, 18, 'Cotton', 'FILTER_VALUE', 'Cotton fabric'),
    (20, 18, 'Denim', 'FILTER_VALUE', 'Denim fabric'),
    (21, 18, 'Wool', 'FILTER_VALUE', 'Wool fabric'),
    (22, 18, 'Linen', 'FILTER_VALUE', 'Linen fabric'),
    (23, 18, 'Polyester', 'FILTER_VALUE', 'Polyester fabric'),

    -- Footwear root
    (24, NULL, 'Footwear', 'ROOT', 'Shoes and other footwear'),
    (25, 24, 'Type', 'FILTER_GROUP', 'Type of footwear'),
    (26, 25, 'Sneakers', 'FILTER_VALUE', 'Sneakers'),
    (27, 25, 'Formal Shoes', 'FILTER_VALUE', 'Formal shoes'),
    (28, 25, 'Boots', 'FILTER_VALUE', 'Boots'),
    (29, 25, 'Sandals', 'FILTER_VALUE', 'Sandals'),

    (30, 24, 'Colour', 'FILTER_GROUP', 'Footwear colours'),
    (31, 30, 'Black', 'FILTER_VALUE', 'Black footwear'),
    (32, 30, 'White', 'FILTER_VALUE', 'White footwear'),
    (33, 30, 'Brown', 'FILTER_VALUE', 'Brown footwear'),

    (34, 24, 'Season', 'FILTER_GROUP', 'Suitable season'),
    (35, 34, 'All-season', 'FILTER_VALUE', 'Everyday footwear'),
    (36, 34, 'Winter', 'FILTER_VALUE', 'Winter footwear'),

    -- Accessories root
    (37, NULL, 'Accessories', 'ROOT', 'Personal accessories'),
    (38, 37, 'Type', 'FILTER_GROUP', 'Type of accessory'),
    (39, 38, 'Belt', 'FILTER_VALUE', 'Belts'),
    (40, 38, 'Watch', 'FILTER_VALUE', 'Watches'),
    (41, 38, 'Bag', 'FILTER_VALUE', 'Bags'),
    (42, 38, 'Cap', 'FILTER_VALUE', 'Caps'),

    (43, 37, 'Colour', 'FILTER_GROUP', 'Accessory colours'),
    (44, 43, 'Black', 'FILTER_VALUE', 'Black accessories'),
    (45, 43, 'Brown', 'FILTER_VALUE', 'Brown accessories'),
    (46, 43, 'Silver', 'FILTER_VALUE', 'Silver accessories'),
    (47, 43, 'Blue', 'FILTER_VALUE', 'Blue accessories'),

    (48, 37, 'Material', 'FILTER_GROUP', 'Accessory material'),
    (49, 48, 'Leather', 'FILTER_VALUE', 'Leather accessories'),
    (50, 48, 'Metal', 'FILTER_VALUE', 'Metal accessories'),
    (51, 48, 'Canvas', 'FILTER_VALUE', 'Canvas accessories');


-- 3. Brands
INSERT INTO Brands (brand_id, brand_name, website)
VALUES
    (1, 'Levis', 'https://www.levi.com'),
    (2, 'Zara', 'https://www.zara.com'),
    (3, 'Uniqlo', 'https://www.uniqlo.com'),
    (4, 'Nike', 'https://www.nike.com'),
    (5, 'Bata', 'https://www.bata.com'),
    (6, 'Fossil', 'https://www.fossil.com'),
    (7, 'Adidas', 'https://www.adidas.com'),
    (8, 'H&M', 'https://www.hm.com');

-- 4. Occasions
INSERT INTO Occasions
    (occasion_id, occasion_name, description)
VALUES
    (1, 'Casual', 'Everyday informal wear'),
    (2, 'College', 'College and campus wear'),
    (3, 'Office', 'Office and professional wear'),
    (4, 'Party', 'Party and evening wear'),
    (5, 'Formal Event', 'Formal functions and events'),
    (6, 'Travel', 'Comfortable travel outfits');
    
-- 5. WardrobeItems
INSERT INTO clothingitems
    (item_id, user_id, brand_id, item_name, size,
     purchase_date, purchase_price, availability_status, notes, image_url)
VALUES
    (1,  1, 1, 'Blue Denim Jeans', '30',
     '2025-08-20', 2499.00, 'Available', 'Everyday jeans', NULL),

    (2,  1, 2, 'White Cotton T-Shirt', 'M',
     '2025-10-02', 799.00, 'Available', 'Basic casual T-shirt', NULL),

    (3,  1, 8, 'White Formal Shirt', 'M',
     '2025-07-12', 1599.00, 'Available', 'Formal white shirt', NULL),

    (4,  1, 3, 'Black Trousers', 'M',
     '2025-12-18', 1899.00, 'Available', 'Office trousers', NULL),

    (5,  1, 2, 'Beige Winter Jacket', 'M',
     '2025-11-05', 3499.00, 'Available', 'Warm winter jacket', NULL),

    (6,  1, 4, 'White Sneakers', 'UK 8',
     '2025-09-01', 2999.00, 'Available', 'Everyday sneakers', NULL),

    (7,  1, 5, 'Black Formal Shoes', 'UK 8',
     '2025-06-12', 2799.00, 'Available', 'Formal footwear', NULL),

    (8,  1, 6, 'Silver Wrist Watch', 'One Size',
     '2025-05-04', 4499.00, 'Available', 'Minimal silver watch', NULL),

    (9,  1, 1, 'Black Leather Belt', '32',
     '2025-04-11', 699.00, 'Available', 'Leather belt', NULL),

    (10, 2, 8, 'Blue Casual Shirt', 'L',
     '2025-10-10', 1299.00, 'Available', 'Casual shirt', NULL),

    (11, 2, 1, 'Black Jeans', '32',
     '2025-09-17', 2299.00, 'Available', 'Black denim jeans', NULL),

    (12, 2, 7, 'Brown Boots', 'UK 9',
     '2025-12-01', 3999.00, 'Available', 'Brown winter boots', NULL),

    (13, 2, 3, 'Blue Canvas Backpack', 'One Size',
     '2025-07-20', 1799.00, 'Available', 'Canvas travel backpack', NULL),

    (14, 2, 7, 'Black Hoodie', 'L',
     '2025-11-15', 2199.00, 'Available', 'Warm casual hoodie', NULL);


-- 6. ItemCategories
-- Clothing: item 1 = Jeans + Blue + All-season + Denim
-- Footwear and accessories use their own category branches.

INSERT INTO ItemCategories (item_id, category_id)
VALUES
    -- User 1: clothing
    (1, 5), (1, 11), (1, 17), (1, 20),
    (2, 3), (2, 12), (2, 15), (2, 19),
    (3, 4), (3, 12), (3, 17), (3, 19),
    (4, 6), (4, 10), (4, 17), (4, 23),
    (5, 7), (5, 13), (5, 16), (5, 21),

    -- User 1: footwear
    (6, 26), (6, 32), (6, 35),
    (7, 27), (7, 31), (7, 35),

    -- User 1: accessories
    (8, 40), (8, 46), (8, 50),
    (9, 39), (9, 44), (9, 49),

    -- User 2: clothing
    (10, 4), (10, 11), (10, 17), (10, 19),
    (11, 5), (11, 10), (11, 17), (11, 20),
    (14, 8), (14, 10), (14, 16), (14, 23),

    -- User 2: footwear
    (12, 28), (12, 33), (12, 36),

    -- User 2: accessories
    (13, 41), (13, 47), (13, 51);
    
-- 7. Outfits

INSERT INTO Outfits
    (outfit_id, user_id, outfit_name, description,
     created_at, is_favorite)
VALUES
    (1, 1, 'Campus Casual',
     'A comfortable everyday college outfit',
     '2026-08-10 09:00:00', FALSE),

    (2, 1, 'Office Ready',
     'A polished formal outfit for work',
     '2026-08-11 10:00:00', TRUE),

    (3, 1, 'Winter Layered Look',
     'A layered outfit for cooler weather',
     '2026-08-12 11:00:00', FALSE),

    (4, 2, 'Weekend Streetwear',
     'A relaxed hoodie and jeans combination',
     '2026-08-13 12:00:00', TRUE),

    (5, 2, 'Travel Ready',
     'A practical outfit for travel',
     '2026-08-14 13:00:00', FALSE),

    (6, 1, 'Smart Casual Denim',
     'A denim-based smart casual combination',
     '2026-08-15 14:00:00', FALSE);


-- 8. OutfitItems
INSERT INTO OutfitItems (outfit_id, item_id)
VALUES
    -- Campus Casual
    (1, 1), (1, 2), (1, 6),

    -- Office Ready
    (2, 3), (2, 4), (2, 7), (2, 8), (2, 9),

    -- Winter Layered Look
    (3, 1), (3, 5), (3, 7),

    -- Weekend Streetwear
    (4, 11), (4, 12), (4, 13), (4, 14),

    -- Travel Ready
    (5, 10), (5, 11), (5, 12), (5, 13),

    -- Smart Casual Denim
    (6, 1), (6, 3), (6, 6), (6, 8), (6, 9);


-- 9. OutfitOccasions
INSERT INTO OutfitOccasions (outfit_id, occasion_id)
VALUES
    (1, 1), (1, 2),
    (2, 3), (2, 5),
    (3, 1), (3, 6),
    (4, 1), (4, 6),
    (5, 2), (5, 6),
    (6, 2), (6, 4);

-- 10. OutfitPlans
INSERT INTO OutfitPlans
    (plan_id, outfit_id, occasion_id, planned_date, plan_status, notes)
VALUES
    (1, 1, 2, '2026-10-25', 'Planned', 'College day'),
    (2, 2, 3, '2026-10-26', 'Planned', 'Office meeting'),
    (3, 4, 1, '2026-10-27', 'Planned', 'Weekend outing'),
    (4, 3, 6, '2026-10-15', 'Worn', 'Travel outfit already worn'),
    (5, 6, 4, '2026-10-18', 'Skipped', 'Plan changed');


-- 11. WearLogs
INSERT INTO WearLogs
    (wear_log_id, outfit_id, worn_at, feedback,
     colour_rating, size_rating, comfort_rating, style_rating)
VALUES
    (1, 1, '2026-09-10 08:00:00',
     'Comfortable for a long college day', 5, 4, 5, 5),

    (2, 2, '2026-09-15 08:30:00',
     'Smart and comfortable', 4, 5, 4, 5),

    (3, 4, '2026-09-18 10:00:00',
     'Great casual combination', 5, 5, 4, 4),

    (4, 6, '2026-10-11 18:00:00',
     'Good combination for an evening out', 5, 4, 4, 5),

    (5, 3, '2026-10-15 19:30:00',
     'Warm and stylish', 4, 4, 5, 5);
     
-- 12. SuggestedOutfits
-- Illustrative scores; these are sample results, not calculated scores.

INSERT INTO SuggestedOutfits
    (suggestion_id, outfit_id, wear_log_id,
     rank_position, score, suggested_at)
VALUES
    (1, 2, 1, 1, 0.931, '2026-10-20 09:00:00.000000'),
    (2, 3, 1, 2, 0.884, '2026-10-20 09:00:00.000000'),
    (3, 6, 1, 3, 0.812, '2026-10-20 09:00:00.000000');
-- 1. USER QUERIES

-- 1.1 Get a user's profile

SELECT *
FROM Users
WHERE user_id = 1;

-- 1.2 Login — find user by email

SELECT user_id, full_name, email, password_hash
FROM Users
WHERE email = 'aanya@example.com';

-- 1.3 Register a new user

INSERT INTO Users
    (full_name, email, password_hash)
VALUES
    ('New User', 'newuser@example.com', 'hashed_password_here');

-- 2. CLOTHING ITEM CRUD
-- 2.1 Show all clothing items

SELECT *
FROM ClothingItems
WHERE user_id = 1;

-- 2.2 Show one clothing item

SELECT *
FROM ClothingItems
WHERE item_id = 1
  AND user_id = 1;

-- 2.3 Add a clothing item


INSERT INTO ClothingItems
    (user_id, brand_id, item_name, size,
     purchase_date, purchase_price,
     availability_status, notes, image_url)
VALUES
    (1, 2, 'Blue Casual Shirt', 'M',
     CURDATE(), 1299.00,
     'Available', 'Casual shirt', NULL);


-- 2.4 Update a clothing item

UPDATE ClothingItems
SET
    item_name = 'Blue Casual Shirt',
    size = 'L',
    purchase_price = 1399.00,
    notes = 'Updated size'
WHERE item_id = 1
  AND user_id = 1;


-- 2.5 Change availability

UPDATE ClothingItems
SET availability_status = 'In Laundry'
WHERE item_id = 1
  AND user_id = 1;

-- 2.6 Delete a clothing item

DELETE FROM ClothingItems
WHERE item_id = 1
  AND user_id = 1;

-- 3. CATEGORY / FILTER SYSTEM
-- 3.1 Get main sections

SELECT category_id, category_name
FROM Categories
WHERE category_type = 'ROOT'
ORDER BY category_name;

-- 3.2 Get filters for Clothing

SELECT category_id, category_name
FROM Categories
WHERE parent_category_id = 1
  AND category_type = 'FILTER_GROUP'
ORDER BY category_name;

-- 3.3 Get values for a filter

SELECT category_id, category_name
FROM Categories
WHERE parent_category_id = 9
  AND category_type = 'FILTER_VALUE'
ORDER BY category_name;

-- 3.4 Get all filter hierarchy dynamically

SELECT
    root.category_name AS section,
    filter_group.category_name AS filter_name,
    filter_value.category_name AS filter_value
FROM Categories AS root
JOIN Categories AS filter_group
    ON filter_group.parent_category_id = root.category_id
JOIN Categories AS filter_value
    ON filter_value.parent_category_id = filter_group.category_id
WHERE root.category_type = 'ROOT'
ORDER BY
    root.category_name,
    filter_group.category_name,
    filter_value.category_name;

-- 4. FILTER CLOTHING ITEMS
-- 4.1 Filter by one category

SELECT DISTINCT
    ci.item_id,
    ci.item_name,
    ci.size,
    ci.purchase_price
FROM ClothingItems AS ci
JOIN ItemCategories AS ic
    ON ci.item_id = ic.item_id
JOIN Categories AS c
    ON ic.category_id = c.category_id
WHERE ci.user_id = 1
  AND c.category_name = 'Blue';

-- 4.2 Filter by type

SELECT DISTINCT
    ci.item_id,
    ci.item_name,
    ci.size,
    ci.purchase_price
FROM ClothingItems AS ci
JOIN ItemCategories AS ic
    ON ci.item_id = ic.item_id
JOIN Categories AS c
    ON ic.category_id = c.category_id
WHERE ci.user_id = 1
  AND c.category_name = 'Jeans';

-- 4.3 Filter by multiple categories

SELECT
    ci.item_id,
    ci.item_name,
    ci.size,
    ci.purchase_price
FROM ClothingItems AS ci
JOIN ItemCategories AS ic
    ON ci.item_id = ic.item_id
JOIN Categories AS c
    ON ic.category_id = c.category_id
WHERE ci.user_id = 1
  AND c.category_name IN ('Blue', 'Jeans')
GROUP BY
    ci.item_id,
    ci.item_name,
    ci.size,
    ci.purchase_price
HAVING COUNT(DISTINCT c.category_name) = 2;

-- 4.4 Filter available items only


SELECT *
FROM ClothingItems
WHERE user_id = 1
  AND availability_status = 'Available';




-- 4.5 Search clothing by name


SELECT *
FROM ClothingItems
WHERE user_id = 1
  AND item_name LIKE '%shirt%';




-- 4.6 Sort items by price


SELECT *
FROM ClothingItems
WHERE user_id = 1
ORDER BY purchase_price DESC;




-- 4.7 Sort by newest purchase


SELECT *
FROM ClothingItems
WHERE user_id = 1
ORDER BY purchase_date DESC;




-- 5. BRAND QUERIES

-- 5.1 Get all brands


SELECT *
FROM Brands
ORDER BY brand_name;


-- 5.2 Get items with their brands


SELECT
    ci.item_id,
    ci.item_name,
    b.brand_name
FROM ClothingItems AS ci
LEFT JOIN Brands AS b
    ON ci.brand_id = b.brand_id
WHERE ci.user_id = 1;


-- 5.3 Add a brand


INSERT INTO Brands
    (brand_name, website)
VALUES
    ('Puma', 'https://www.puma.com');




-- 6. ITEM CATEGORY MANAGEMENT


-- 6.1 Add category to an item


INSERT INTO ItemCategories
    (item_id, category_id)
VALUES
    (1, 11);



-- 6.2 Remove a category from an item


DELETE FROM ItemCategories
WHERE item_id = 1
  AND category_id = 11;


-- 6.3 Show all categories of an item


SELECT
    c.category_name,
    c.category_type
FROM ItemCategories AS ic
JOIN Categories AS c
    ON ic.category_id = c.category_id
WHERE ic.item_id = 1;




-- 7. OUTFIT CRUD

-- 7.1 Show user's outfits


SELECT *
FROM Outfits
WHERE user_id = 1
ORDER BY created_at DESC;


-- 7.2 Create an outfit


INSERT INTO Outfits
    (user_id, outfit_name, description, is_favorite)
VALUES
    (1, 'Summer Casual',
     'Simple everyday outfit', FALSE);


-- 7.3 Update an outfit


UPDATE Outfits
SET
    outfit_name = 'Updated Casual',
    description = 'Updated outfit description'
WHERE outfit_id = 1
  AND user_id = 1;


-- 7.4 Delete an outfit


DELETE FROM Outfits
WHERE outfit_id = 1
  AND user_id = 1;


-- 7.5 Mark/unmark favourite


UPDATE Outfits
SET is_favorite = TRUE
WHERE outfit_id = 1
  AND user_id = 1;




-- 8. ADD/REMOVE ITEMS FROM OUTFITS

-- 8.1 Add item to outfit


INSERT INTO OutfitItems
    (outfit_id, item_id)
VALUES
    (1, 2);


-- 8.2 Remove item from outfit


DELETE FROM OutfitItems
WHERE outfit_id = 1
  AND item_id = 2;


-- 8.3 Show complete outfit


SELECT
    o.outfit_name,
    ci.item_id,
    ci.item_name,
    b.brand_name,
    ci.size,
    ci.image_url
FROM Outfits AS o
JOIN OutfitItems AS oi
    ON o.outfit_id = oi.outfit_id
JOIN ClothingItems AS ci
    ON oi.item_id = ci.item_id
LEFT JOIN Brands AS b
    ON ci.brand_id = b.brand_id
WHERE o.outfit_id = 1;




-- 9. OUTFIT OCCASIONS

-- 9.1 Add an occasion to an outfit


INSERT INTO OutfitOccasions
    (outfit_id, occasion_id)
VALUES
    (1, 2);


-- 9.2 Remove an occasion


DELETE FROM OutfitOccasions
WHERE outfit_id = 1
  AND occasion_id = 2;


-- 9.3 Show occasions for an outfit


SELECT
    o.outfit_name,
    oc.occasion_name
FROM Outfits AS o
JOIN OutfitOccasions AS oo
    ON o.outfit_id = oo.outfit_id
JOIN Occasions AS oc
    ON oo.occasion_id = oc.occasion_id
WHERE o.outfit_id = 1;


-- 9.4 Find outfits suitable for an occasion


SELECT
    o.outfit_id,
    o.outfit_name,
    o.description
FROM Outfits AS o
JOIN OutfitOccasions AS oo
    ON o.outfit_id = oo.outfit_id
JOIN Occasions AS oc
    ON oo.occasion_id = oc.occasion_id
WHERE o.user_id = 1
  AND oc.occasion_name = 'Casual';



-- 10. OUTFIT PLANNING
-- 10.1 Create an outfit plan

INSERT INTO OutfitPlans
    (outfit_id, occasion_id, planned_date, plan_status, notes)
VALUES
    (1, 2, '2026-10-30', 'Planned', 'College day');

-- 10.2 Show upcoming plans

SELECT
    op.plan_id,
    op.planned_date,
    o.outfit_name,
    oc.occasion_name,
    op.plan_status,
    op.notes
FROM OutfitPlans AS op
JOIN Outfits AS o
    ON op.outfit_id = o.outfit_id
LEFT JOIN Occasions AS oc
    ON op.occasion_id = oc.occasion_id
WHERE o.user_id = 1
ORDER BY op.planned_date;

-- 10.3 Update plan status

UPDATE OutfitPlans
SET plan_status = 'Worn'
WHERE plan_id = 1;

-- 10.4 Delete a plan

DELETE FROM OutfitPlans
WHERE plan_id = 1;

-- 11. WEAR LOGS / RATINGS
-- 11.1 Record that an outfit was worn
INSERT INTO WearLogs
    (outfit_id, worn_at, feedback,
     colour_rating, size_rating,
     comfort_rating, style_rating)
VALUES
    (1, NOW(),
     'Very comfortable outfit',
     5, 4, 5, 5);

-- 11.2 Show wear history
SELECT
    wl.wear_log_id,
    o.outfit_name,
    wl.worn_at,
    wl.feedback,
    wl.colour_rating,
    wl.size_rating,
    wl.comfort_rating,
    wl.style_rating
FROM WearLogs AS wl
JOIN Outfits AS o
    ON wl.outfit_id = o.outfit_id
WHERE o.user_id = 1
ORDER BY wl.worn_at DESC;


-- 11.3 Calculate average rating for each outfit
SELECT
    o.outfit_name,
    AVG(wl.colour_rating) AS avg_colour,
    AVG(wl.size_rating) AS avg_size,
    AVG(wl.comfort_rating) AS avg_comfort,
    AVG(wl.style_rating) AS avg_style
FROM Outfits AS o
JOIN WearLogs AS wl
    ON o.outfit_id = wl.outfit_id
WHERE o.user_id = 1
GROUP BY o.outfit_id, o.outfit_name;

-- 11.4 Find most-worn outfits
SELECT
    o.outfit_name,
    COUNT(wl.wear_log_id) AS times_worn
FROM Outfits AS o
LEFT JOIN WearLogs AS wl
    ON o.outfit_id = wl.outfit_id
WHERE o.user_id = 1
GROUP BY o.outfit_id, o.outfit_name
ORDER BY times_worn DESC;

-- 11.5 Find outfits that have never been worn
SELECT
    o.outfit_id,
    o.outfit_name
FROM Outfits AS o
LEFT JOIN WearLogs AS wl
    ON o.outfit_id = wl.outfit_id
WHERE o.user_id = 1
  AND wl.wear_log_id IS NULL;
  
-- 12. RECOMMENDATION SYSTEM
-- 12.1 Find outfits suitable for an occasion

SELECT
    o.outfit_id,
    o.outfit_name
FROM Outfits AS o
JOIN OutfitOccasions AS oo
    ON o.outfit_id = oo.outfit_id
JOIN Occasions AS oc
    ON oo.occasion_id = oc.occasion_id
WHERE o.user_id = 1
  AND oc.occasion_name = 'College';

-- 12.2 Calculate average rating for outfits

-- Set these weights according to the user's preference order.
-- Highest priority = 4, second = 3, third = 2, lowest = 1.
-- Example preference order: Colour > Size > Comfort > Style.
-- Your Node.js application should set these variables from the user's selected order.
SET @colour_weight = 4;
SET @size_weight = 3;
SET @comfort_weight = 2;
SET @style_weight = 1;

SELECT
    o.outfit_id,
    o.outfit_name,
    AVG(
        CASE
            WHEN wl.colour_rating = 0
              OR wl.size_rating = 0
              OR wl.comfort_rating = 0
              OR wl.style_rating = 0
            THEN 0
            ELSE (
                wl.colour_rating * @colour_weight +
                wl.size_rating * @size_weight +
                wl.comfort_rating * @comfort_weight +
                wl.style_rating * @style_weight
            ) / (
                @colour_weight + @size_weight +
                @comfort_weight + @style_weight
            )
        END
    ) AS average_rating
FROM Outfits AS o
LEFT JOIN WearLogs AS wl
    ON o.outfit_id = wl.outfit_id
WHERE o.user_id = 1
GROUP BY o.outfit_id, o.outfit_name
ORDER BY average_rating DESC;

-- 12.3 Get the best-rated outfits

SELECT
    o.outfit_id,
    o.outfit_name,
    AVG(
        CASE
            WHEN wl.colour_rating = 0
              OR wl.size_rating = 0
              OR wl.comfort_rating = 0
              OR wl.style_rating = 0
            THEN 0
            ELSE (
                wl.colour_rating * @colour_weight +
                wl.size_rating * @size_weight +
                wl.comfort_rating * @comfort_weight +
                wl.style_rating * @style_weight
            ) / (
                @colour_weight + @size_weight +
                @comfort_weight + @style_weight
            )
        END
    ) AS average_rating
FROM Outfits AS o
JOIN WearLogs AS wl
    ON o.outfit_id = wl.outfit_id
WHERE o.user_id = 1
GROUP BY o.outfit_id, o.outfit_name
ORDER BY average_rating DESC
LIMIT 3;

-- 12.4 Store a recommendation

INSERT INTO SuggestedOutfits
    (outfit_id, wear_log_id, rank_position,
     score, suggested_at)
VALUES
    (2, 1, 1, 0.931, NOW());

-- 12.5 Display Top 3 recommendations
SELECT
    so.rank_position,
    o.outfit_name,
    so.score,
    so.suggested_at
FROM SuggestedOutfits AS so
JOIN Outfits AS o
    ON so.outfit_id = o.outfit_id
WHERE o.user_id = 1
ORDER BY so.rank_position
LIMIT 3;

-- 13. DASHBOARD QUERIES
-- 13.1 Total clothing items

SELECT COUNT(*) AS total_items
FROM ClothingItems
WHERE user_id = 1;

-- 13.2 Total outfits

SELECT COUNT(*) AS total_outfits
FROM Outfits
WHERE user_id = 1;

-- 13.3 Favourite outfits

SELECT *
FROM Outfits
WHERE user_id = 1
  AND is_favorite = TRUE;

-- 13.4 Items by availability

SELECT
    availability_status,
    COUNT(*) AS total
FROM ClothingItems
WHERE user_id = 1
GROUP BY availability_status;

-- 13.5 Total wardrobe value

SELECT
    SUM(purchase_price) AS total_wardrobe_value
FROM ClothingItems
WHERE user_id = 1;

-- 13.6 Average item price

SELECT
    AVG(purchase_price) AS average_price
FROM ClothingItems
WHERE user_id = 1;

-- 13.7 Most expensive item

SELECT *
FROM ClothingItems
WHERE user_id = 1
ORDER BY purchase_price DESC
LIMIT 1;

-- 13.8 Cheapest item

SELECT *
FROM ClothingItems
WHERE user_id = 1
ORDER BY purchase_price ASC
LIMIT 1;
