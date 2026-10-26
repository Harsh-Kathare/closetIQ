-- Login
SELECT user_id, full_name, email, password_hash
FROM Users
WHERE email = 'aanya@example.com';

-- Register a new user
INSERT INTO Users
    (full_name, email, password_hash)
VALUES
    ('Rahul Verma', 'rahul@example.com', '$2b$10$examplehashedpassword123456789');
SELECT LAST_INSERT_ID() AS user_id;

-- show wardrobe to user 1
SELECT
    ci.item_id,
    ci.item_name,
    b.brand_name,
    ci.size,
    ci.purchase_date,
    ci.purchase_price,
    ci.availability_status,
    ci.notes,
    ci.image_url,
    GROUP_CONCAT(
        CONCAT(c.category_type, ': ', c.category_name)
        ORDER BY c.category_type
        SEPARATOR ', '
    ) AS categories
FROM ClothingItems ci
LEFT JOIN Brands b
    ON ci.brand_id = b.brand_id
LEFT JOIN ItemCategories ic
    ON ci.item_id = ic.item_id
LEFT JOIN Categories c
    ON ic.category_id = c.category_id
WHERE ci.user_id = 1
GROUP BY
    ci.item_id,
    ci.item_name,
    b.brand_name,
    ci.size,
    ci.purchase_date,
    ci.purchase_price,
    ci.availability_status,
    ci.notes,
    ci.image_url
ORDER BY ci.item_id;

-- insert item
INSERT INTO ClothingItems
(
    user_id,
    brand_id,
    item_name,
    size,
    purchase_date,
    purchase_price,
    availability_status,
    notes,
    image_url
)
VALUES
(
    1,
    2,
    'White Casual Shirt',
    'M',
    '2026-10-20',
    1499.00,
    'Available',
    'Cotton shirt for casual wear',
    'images/white-shirt.jpg'
);

SET @new_item_id = LAST_INSERT_ID();

INSERT INTO ItemCategories (item_id, category_id)
VALUES
    (@new_item_id, 8),
    (@new_item_id, 12),
    (@new_item_id, 16),
    (@new_item_id, 20);

-- edit item
UPDATE ClothingItems
SET
    item_name = 'Blue Denim Jacket',
    size = 'L',
    purchase_price = 2699.00,
    availability_status = 'Available',
    notes = 'Updated size and price information'
WHERE item_id = 1
  AND user_id = 1;
  
-- delete item
DELETE FROM ClothingItems
WHERE item_id = 1
  AND user_id = 1;

-- add outfit
INSERT INTO Outfits
(
    user_id,
    outfit_name,
    description,
    is_favorite
)
VALUES
(
    1,
    'Casual College Look',
    'Comfortable outfit for college',
    TRUE
);

INSERT INTO OutfitItems (outfit_id, item_id)
VALUES
    (7, 2),
    (7, 5),
    (7, 8);
    
-- view outfit
 SELECT
    o.outfit_id,
    o.outfit_name,
    o.description,
    o.is_favorite,

    ci.item_id,
    ci.item_name,
    b.brand_name,
    ci.size,
    ci.availability_status,
    ci.image_url

FROM Outfits o

INNER JOIN OutfitItems oi
    ON o.outfit_id = oi.outfit_id

INNER JOIN ClothingItems ci
    ON oi.item_id = ci.item_id

LEFT JOIN Brands b
    ON ci.brand_id = b.brand_id

WHERE o.outfit_id = 1
  AND o.user_id = 1;

-- view oufit related to occasion
SELECT
    o.outfit_id,
    o.outfit_name,
    o.description,
    o.is_favorite
FROM Outfits o
INNER JOIN OutfitOccasions oo
    ON o.outfit_id = oo.outfit_id
INNER JOIN Occasions oc
    ON oo.occasion_id = oc.occasion_id
WHERE o.user_id = 1
  AND oc.occasion_name = 'College'
ORDER BY o.outfit_name;

-- filtering
SELECT DISTINCT
    ci.item_id,
    ci.item_name,
    b.brand_name,
    ci.size,
    ci.purchase_price,
    ci.availability_status,
    ci.image_url
FROM ClothingItems ci
LEFT JOIN Brands b
    ON ci.brand_id = b.brand_id
INNER JOIN ItemCategories ic1
    ON ci.item_id = ic1.item_id
INNER JOIN Categories c1
    ON ic1.category_id = c1.category_id
INNER JOIN ItemCategories ic2
    ON ci.item_id = ic2.item_id
INNER JOIN Categories c2
    ON ic2.category_id = c2.category_id
WHERE ci.user_id = 1
  AND c1.category_name = 'T-Shirt'
  AND c1.category_type = 'FILTER_VALUE'
  AND c2.category_name = 'Blue'
  AND c2.category_type = 'FILTER_VALUE'
ORDER BY ci.item_name;

-- create a plan
INSERT INTO OutfitPlans
(
    outfit_id,
    occasion_id,
    planned_date,
    plan_status,
    notes
)
VALUES
(
    1,
    2,
    '2026-11-05',
    'Planned',
    'College presentation'
);

-- view upcoming plan
SELECT
    op.plan_id,
    op.planned_date,
    op.plan_status,
    op.notes,

    o.outfit_id,
    o.outfit_name,

    oc.occasion_name

FROM OutfitPlans op

INNER JOIN Outfits o
    ON op.outfit_id = o.outfit_id

LEFT JOIN Occasions oc
    ON op.occasion_id = oc.occasion_id

WHERE o.user_id = 1
  AND op.planned_date >= CURDATE()

ORDER BY op.planned_date ASC;

-- record wear log
INSERT INTO WearLogs
(
    outfit_id,
    worn_at,
    feedback,
    colour_rating,
    size_rating,
    comfort_rating,
    style_rating
)
VALUES
(
    1,
    '2026-10-25 09:30:00',
    'Very comfortable and looked good.',
    5,
    4,
    5,
    5
);

-- view wear log
SELECT
    wl.wear_log_id,
    wl.worn_at,
    o.outfit_id,
    o.outfit_name,
    wl.feedback,
    wl.colour_rating,
    wl.size_rating,
    wl.comfort_rating,
    wl.style_rating

FROM WearLogs wl
INNER JOIN Outfits o
    ON wl.outfit_id = o.outfit_id
WHERE o.user_id = 1
ORDER BY wl.worn_at DESC;
