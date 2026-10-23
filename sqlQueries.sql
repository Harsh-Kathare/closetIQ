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
