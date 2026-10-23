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
