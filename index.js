import env from "dotenv";
import express from "express";
import mysql from "mysql2/promise";
import bcrypt from "bcrypt";
import session from "express-session";
env.config();
const app = express();
const port = process.env.PORT || 3000;
const saltRounds = 10;


const pool = mysql.createPool({
  host: process.env.HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT || 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

app.set("view engine", "ejs");

app.use(express.urlencoded({ extended: true }));
app.use(express.static("public"));
app.use(session({
    secret: process.env.SESSION_SECRET,
    resave: false,
    saveUninitialized: false
}));


app.get("/",async (req,res) => {
    res.redirect("/home");
})

function requireLogin(req, res, next) {
    if (!req.session.isLoggedIn) return res.redirect("/login");
    next();
}

async function getUser(userId) {
    const [rows] = await pool.execute(
        "SELECT full_name FROM users WHERE user_id = ?",
        [userId]
    );
    return rows[0];
}

async function getSections() {
    const [rows] = await pool.execute(
        "SELECT category_id, category_name FROM Categories WHERE parent_category_id IS NULL ORDER BY category_id"
    );
    return rows;
}

async function getFilters(sectionName) {
    const [rows] = await pool.execute(
        `SELECT g.category_id AS group_id, g.category_name AS group_name,
                v.category_id, v.category_name
           FROM Categories root
           JOIN Categories g ON g.parent_category_id = root.category_id
           JOIN Categories v ON v.parent_category_id = g.category_id
          WHERE root.parent_category_id IS NULL AND root.category_name = ?
          ORDER BY g.category_id, v.category_name`,
        [sectionName]
    );
    const filters = [];
    for (const row of rows) {
        let group = filters.find((g) => g.id === row.group_id);
        if (!group) {
            group = { id: row.group_id, name: row.group_name, values: [] };
            filters.push(group);
        }
        group.values.push({ category_id: row.category_id, category_name: row.category_name });
    }
    return filters;
}

// Return the id of a brand with this name; create it if it doesn't exist yet.
async function findOrCreateBrand(conn, brandName) {
    const [rows] = await conn.execute(
        "SELECT brand_id FROM Brands WHERE LOWER(brand_name) = LOWER(?)",
        [brandName]
    );
    if (rows.length > 0) {
        return rows[0].brand_id; // already exists -> reuse it, no duplicates
    }
    const [result] = await conn.execute(
        "INSERT INTO Brands (brand_name) VALUES (?)",
        [brandName]
    );
    return result.insertId;
}

// Same idea for a category value (e.g. a new colour) under a filter group.
async function findOrCreateCategory(conn, groupId, categoryName) {
    const [rows] = await conn.execute(
        "SELECT category_id FROM Categories WHERE parent_category_id = ? AND LOWER(category_name) = LOWER(?)",
        [groupId, categoryName]
    );
    if (rows.length > 0) {
        return rows[0].category_id;
    }
    // copy category_type from a sibling value, so the new row looks like its neighbours
    const [siblings] = await conn.execute(
        "SELECT category_type FROM Categories WHERE parent_category_id = ? LIMIT 1",
        [groupId]
    );
    const categoryType = siblings.length > 0 ? siblings[0].category_type : null;

    const [result] = await conn.execute(
        "INSERT INTO Categories (parent_category_id, category_name, category_type) VALUES (?, ?, ?)",
        [groupId, categoryName, categoryType]
    );
    return result.insertId;
}

function toDateInput(value) {
    if (!value) return "";
    if (typeof value === "string") return value.slice(0, 10);
    const y = value.getFullYear();
    const m = String(value.getMonth() + 1).padStart(2, "0");
    const d = String(value.getDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
}

// Which section (Clothing / Footwear / ...) does this item belong to?
// We look at the item's categories and walk up: value -> group -> section.
async function getItemSection(itemId, sections) {
    const [rows] = await pool.execute(
        `SELECT g.parent_category_id AS root_id
           FROM ItemCategories ic
           JOIN Categories v ON v.category_id = ic.category_id
           JOIN Categories g ON g.category_id = v.parent_category_id
          WHERE ic.item_id = ?
          LIMIT 1`,
        [itemId]
    );
    const section = rows.length > 0
        ? sections.find((s) => s.category_id === rows[0].root_id)
        : null;
    return (section || sections[0]).category_name;
}

// Same logic the add form uses: read what was chosen in each dropdown.
function readPicks(body, filters) {
    const picks = [];
    for (const group of filters) {
        const picked = body["group_" + group.id];
        if (picked === "__new__") {
            const typed = (body["new_" + group.id] || "").trim();
            if (typed) picks.push({ group, newName: typed });
        } else if (picked) {
            const id = Number(picked);
            if (group.values.some((v) => v.category_id === id)) {
                picks.push({ group, categoryId: id });
            }
        }
    }
    return picks;
}

async function getPickerItems(userId) {
    const [rows] = await pool.execute(
        `SELECT ci.item_id, ci.item_name, ci.image_url, ci.availability_status, b.brand_name,
                (SELECT root.category_name
                   FROM ItemCategories ic
                   JOIN Categories v ON v.category_id = ic.category_id
                   JOIN Categories g ON g.category_id = v.parent_category_id
                   JOIN Categories root ON root.category_id = g.parent_category_id
                  WHERE ic.item_id = ci.item_id
                  LIMIT 1) AS section,
                (SELECT GROUP_CONCAT(c.category_name ORDER BY c.category_name SEPARATOR ',')
                   FROM ItemCategories ic2
                   JOIN Categories c ON c.category_id = ic2.category_id
                  WHERE ic2.item_id = ci.item_id) AS tags
           FROM ClothingItems ci
           LEFT JOIN Brands b ON b.brand_id = ci.brand_id
          WHERE ci.user_id = ?
          ORDER BY ci.item_name`,
        [userId]
    );
    rows.forEach((row) => {
        row.tags = row.tags ? row.tags.split(",") : [];
    });
    return rows;
}

// Same idea as findOrCreateBrand: reuse an occasion with this name, or create it.
async function findOrCreateOccasion(conn, occasionName) {
    const [rows] = await conn.execute(
        "SELECT occasion_id FROM Occasions WHERE LOWER(occasion_name) = LOWER(?)",
        [occasionName]
    );
    if (rows.length > 0) {
        return rows[0].occasion_id;
    }
    const [result] = await conn.execute(
        "INSERT INTO Occasions (occasion_name) VALUES (?)",
        [occasionName]
    );
    return result.insertId;
} 

// Today (or today + offset days) as "YYYY-MM-DD", using the server's local date.
// toDateInput is the helper you already have (it turns a Date into "YYYY-MM-DD").
function todayString(offset = 0) {
    const d = new Date();
    d.setDate(d.getDate() + offset);
    return toDateInput(d);
}

// Is this text a real calendar date like "2026-11-20"?  (rejects things like 2026-02-31)
function isValidDate(text) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return false;
    const [y, m, d] = text.split("-").map(Number);
    const date = new Date(y, m - 1, d);
    return date.getFullYear() === y && date.getMonth() === m - 1 && date.getDate() === d;
}

// Turns an error code from the address (?error=past) into a message
const plannerErrors = {
    missing: "Please choose an outfit, an occasion and a date.",
    date: "That date is not valid.",
    past: "You can only plan outfits for today or a future date.",
    dup: "That outfit is already planned for that day.",
};

// How much each rating matters. Every rating counts the same for now.
// Later, when you add preference columns to the Users table, this is the ONLY function you change:
//
//   const [rows] = await pool.execute(
//       "SELECT weight_colour, weight_size, weight_comfort, weight_style FROM Users WHERE user_id = ?",
//       [userId]
//   );
//   return { colour: rows[0].weight_colour, size: rows[0].weight_size,
//            comfort: rows[0].weight_comfort, style: rows[0].weight_style };
// Reads the user's four weights from the Users table (the columns from profile-setup.sql).
async function getRatingWeights(userId) {
    const [rows] = await pool.execute(
        "SELECT weight_colour, weight_size, weight_comfort, weight_style FROM Users WHERE user_id = ?",
        [userId]
    );
    if (rows.length === 0) {
        return { colour: 1, size: 1, comfort: 1, style: 1 };
    }
    return {
        colour: rows[0].weight_colour,
        size: rows[0].weight_size,
        comfort: rows[0].weight_comfort,
        style: rows[0].weight_style,
    };
}

// Score of ONE wear log, from 1 to 5.
// Weighted average = (w1*r1 + w2*r2 + ...) / (w1 + w2 + ...)
// We divide by the SUM of the weights (not by 4), so the result always stays between 1 and 5.
// Example: colour weight 5, others 1, ratings 5,3,3,3 -> (25+3+3+3) / 8 = 4.25
function weightedScore(log, w) {
    const total = w.colour + w.size + w.comfort + w.style;
    return (
        w.colour * log.colour_rating +
        w.size * log.size_rating +
        w.comfort * log.comfort_rating +
        w.style * log.style_rating
    ) / total;
}



















app.get("/home",async (req,res) => {
    if(req.session.isLoggedIn){
        return res.redirect("/wardobe")
    }
    res.render("home.ejs");
    
})
app.get("/login",(req,res) =>{
    const error = req.query.error ? 'Incorrect email or password.' : null;
    res.render('login.ejs', { error });
})

app.post("/login",async (req,res) => {
    const enteredId = req.body.email;
    const enteredPass = req.body.password;
    const [rows] = await pool.execute('SELECT * FROM users where email = ?',[enteredId]);
    if(rows.length == 0){
        return res.redirect('/login?error=1');
    }
    else{
        const user = rows[0];
        const result = await bcrypt.compare(enteredPass,user.password_hash);
        if(result){
            req.session.user_id = user.user_id;
            req.session.isLoggedIn = true;
            res.redirect("/wardrobe");
        }
        else{
            return res.redirect('/login?error=1');
        }
    }
})

app.post("/logout", (req, res) => {
    req.session.destroy(() => {
        res.redirect("/home");
    });
});

app.get('/register', (req, res) => {
    let error = null;
    let userExists = false;
    if (req.query.error === 'exists') {
        error = 'An account with this email already exists.';
        userExists = true;
    }
    res.render('register', { error, userExists });
});

app.post("/register",async (req,res) => {
    const enteredId = req.body.email;
    const enteredPass = req.body.password;
    const enteredName = req.body.full_name;

    const [rows] = await pool.execute("SELECT * FROM users WHERE email = ?",[enteredId]);
    if(rows.length == 0){
        try{
            const hash = await bcrypt.hash(enteredPass, saltRounds);
            await pool.execute("INSERT INTO users(full_name,email,password_hash) VALUES(?,?,?)",
                [enteredName,enteredId,hash]
            )
            req.session.user_id = result.insertId;
            req.session.isLoggedIn = true;          
            res.redirect("/wardrobe");
        }
        catch(error){
            console.log(error);
            res.status(500).send("Something went wrong. Please try again.");
        }
    }
    else{
        return res.redirect('/register?error=exists');
    }
})

app.get("/wardrobe", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const search = (req.query.search || "").trim();
        const selected = [].concat(req.query.category || []).map(Number).filter(Number.isInteger);

        const [userRows] = await pool.execute(
            "SELECT full_name FROM users WHERE user_id = ?",
            [userId]
        );
        if (userRows.length === 0) {
            return res.redirect("/login");
        }
        const user = userRows[0];

        const [sections] = await pool.execute(
            "SELECT category_id, category_name FROM Categories WHERE parent_category_id IS NULL ORDER BY category_id"
        );
        const currentSection = sections.find((s) => s.category_name === req.query.section) || sections[0];
        const section = currentSection.category_name;

        const [filterRows] = await pool.execute(
            `SELECT g.category_id AS group_id, g.category_name AS group_name,
                    v.category_id, v.category_name
               FROM Categories root
               JOIN Categories g ON g.parent_category_id = root.category_id
               JOIN Categories v ON v.parent_category_id = g.category_id
              WHERE root.parent_category_id IS NULL AND root.category_name = ?
              ORDER BY g.category_id, v.category_name`,
            [section]
        );

        const filters = [];
        for (const row of filterRows) {
            let group = filters.find((g) => g.id === row.group_id);
            if (!group) {
                group = { id: row.group_id, name: row.group_name, values: [] };
                filters.push(group);
            }
            group.values.push({ category_id: row.category_id, category_name: row.category_name });
        }

        let sql = `
            SELECT ci.item_id, ci.item_name, ci.size, ci.purchase_price,
                   ci.availability_status, ci.image_url, b.brand_name,
                   (SELECT GROUP_CONCAT(c.category_name ORDER BY c.category_name SEPARATOR ',')
                      FROM ItemCategories ic
                      JOIN Categories c ON c.category_id = ic.category_id
                     WHERE ic.item_id = ci.item_id) AS tags
              FROM ClothingItems ci
              LEFT JOIN Brands b ON b.brand_id = ci.brand_id
             WHERE ci.user_id = ?`;
        const params = [userId];

        sql += ` AND EXISTS (
                    SELECT 1 FROM ItemCategories ic3
                    JOIN Categories v3 ON v3.category_id = ic3.category_id
                    JOIN Categories g3 ON g3.category_id = v3.parent_category_id
                    WHERE ic3.item_id = ci.item_id
                    AND g3.parent_category_id = ?)`;
        params.push(currentSection.category_id);

        if (search) {
            sql += " AND (ci.item_name LIKE ? OR b.brand_name LIKE ?)";
            params.push(`%${search}%`, `%${search}%`);
        }

        for (const group of filters) {
            const ticked = group.values
                .map((v) => v.category_id)
                .filter((id) => selected.includes(id));
            if (ticked.length > 0) {
                const marks = ticked.map(() => "?").join(",");
                sql += ` AND EXISTS (
                            SELECT 1 FROM ItemCategories ic2
                             WHERE ic2.item_id = ci.item_id
                               AND ic2.category_id IN (${marks}))`;
                params.push(...ticked);
            }
        }

        sql += " ORDER BY ci.item_id DESC";

        const [items] = await pool.execute(sql, params);
        items.forEach((item) => {
            item.tags = item.tags ? item.tags.split(",") : [];
        });

        res.render("wardrobe.ejs", { user, items, filters, selected, search, sections, section });
    } catch (error) {
        console.log(error);
        res.status(500).send("Could not load your wardrobe.");
    }
});
    

app.post("/items/:id/delete", requireLogin, async (req, res) => {
    const itemId = req.params.id;
    const userId = req.session.user_id;
    const conn = await pool.getConnection();
    try {
        // A transaction = all the deletes happen together, or none do.
        await conn.beginTransaction();

        // Make sure the item belongs to THIS user before touching anything.
        const [owned] = await conn.execute(
            "SELECT item_id FROM ClothingItems WHERE item_id = ? AND user_id = ?",
            [itemId, userId]
        );
        if (owned.length > 0) {
            // Child rows first, then the item itself.
            await conn.execute("DELETE FROM ItemCategories WHERE item_id = ?", [itemId]);
            await conn.execute("DELETE FROM OutfitItems WHERE item_id = ?", [itemId]);
            await conn.execute("DELETE FROM ClothingItems WHERE item_id = ?", [itemId]);
        }
        await conn.commit();
        res.redirect("/wardrobe");
    } catch (error) {
        await conn.rollback();
        console.log(error);
        res.status(500).send("Could not delete the item.");
    } finally {
        conn.release(); // always give the connection back to the pool
    }
});

// ---------- STEP 2: add item - show the form ----------
app.get("/items/new", requireLogin, async (req, res) => {
    try {
        const user = await getUser(req.session.user_id);
        if (!user) {
            return res.redirect("/login");
        }
        const sections = await getSections();
        const currentSection = sections.find((s) => s.category_name === req.query.section) || sections[0];
        const filters = await getFilters(currentSection.category_name);
        const [brands] = await pool.execute(
            "SELECT brand_id, brand_name FROM Brands ORDER BY brand_name"
        );
        const error = req.query.error
            ? "Please enter an item name and choose the first option under Describe it."
            : null;

        res.render("add-item.ejs", {
            user, sections, section: currentSection.category_name, filters, brands, error
        });
    } catch (error) {
        console.log(error);
        res.status(500).send("Could not load the page.");
    }
});

// ---------- STEP 2: add item - save it ----------
app.post("/items", requireLogin, async (req, res) => {
    const userId = req.session.user_id;
    const body = req.body;
    let conn;
    try {
        const sections = await getSections();
        const currentSection = sections.find((s) => s.category_name === body.section) || sections[0];
        const filters = await getFilters(currentSection.category_name);
        const backToForm = `/items/new?section=${encodeURIComponent(currentSection.category_name)}&error=1`;

        const name = (body.item_name || "").trim();
        const addingNewBrand = body.brand_id === "__new__";
        const newBrand = (body.new_brand || "").trim();

        // Work out what the user chose in EACH dropdown:
        //   an existing value -> { group, categoryId }
        //   "+ Add new..."    -> { group, newName }
        const picks = [];
        for (const group of filters) {
            const picked = body["group_" + group.id];
            if (picked === "__new__") {
                const typed = (body["new_" + group.id] || "").trim();
                if (typed) picks.push({ group, newName: typed });
            } else if (picked) {
                const id = Number(picked);
                // the id must really be one of THIS dropdown's values
                if (group.values.some((v) => v.category_id === id)) {
                    picks.push({ group, categoryId: id });
                }
            }
        }

        if (!name || picks.length === 0 || (addingNewBrand && !newBrand)) {
            return res.redirect(backToForm);
        }

        conn = await pool.getConnection();
        await conn.beginTransaction();

        // 1) brand: existing id, a brand typed by the user, or none
        let brandId = null;
        if (addingNewBrand) {
            brandId = await findOrCreateBrand(conn, newBrand);
        } else if (body.brand_id) {
            brandId = Number(body.brand_id);
        }

        // 2) the item
        const [result] = await conn.execute(
            `INSERT INTO ClothingItems
                (user_id, brand_id, item_name, size, purchase_date, purchase_price,
                 availability_status, notes)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                userId,
                brandId,
                name,
                (body.size || "").trim() || null,
                body.purchase_date || null,
                body.purchase_price || null,
                body.availability_status || "Available",
                (body.notes || "").trim() || null
            ]
        );

        // 3) categories: create any new ones, then link every choice to the item
        const categoryIds = new Set();
        for (const pick of picks) {
            const categoryId = pick.categoryId
                ? pick.categoryId
                : await findOrCreateCategory(conn, pick.group.id, pick.newName);
            categoryIds.add(categoryId);
        }
        for (const categoryId of categoryIds) {
            await conn.execute(
                "INSERT INTO ItemCategories (item_id, category_id) VALUES (?, ?)",
                [result.insertId, categoryId]
            );
        }

        await conn.commit(); // brand + categories + item + links: all saved together
        res.redirect(`/wardrobe?section=${encodeURIComponent(currentSection.category_name)}`);
    } catch (error) {
        if (conn) await conn.rollback();
        console.log(error);
        res.status(500).send("Could not save the item.");
    } finally {
        if (conn) conn.release();
    }
});

app.get("/items/:id/edit", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const user = await getUser(userId);
        if (!user) {
            return res.redirect("/login");
        }

        // user_id in the WHERE: you can only open YOUR OWN items
        const [rows] = await pool.execute(
            `SELECT item_id, brand_id, item_name, size, purchase_date, purchase_price,
                    availability_status, notes
               FROM ClothingItems
              WHERE item_id = ? AND user_id = ?`,
            [req.params.id, userId]
        );
        if (rows.length === 0) {
            return res.redirect("/wardrobe");
        }
        const item = rows[0];
        item.purchase_date = toDateInput(item.purchase_date);

        const sections = await getSections();
        const sectionName = await getItemSection(item.item_id, sections);
        const filters = await getFilters(sectionName);
        const [brands] = await pool.execute(
            "SELECT brand_id, brand_name FROM Brands ORDER BY brand_name"
        );
        const [categoryRows] = await pool.execute(
            "SELECT category_id FROM ItemCategories WHERE item_id = ?",
            [item.item_id]
        );
        const selectedIds = categoryRows.map((r) => r.category_id);

        const error = req.query.error
            ? "Please enter an item name and choose the first option under Describe it."
            : null;

        res.render("add-item.ejs", {
            user, sections, section: sectionName, filters, brands, error, item, selectedIds
        });
    } catch (error) {
        console.log(error);
        res.status(500).send("Could not load the page.");
    }
});

// ---------- EDIT: save the changes ----------
app.post("/items/:id/edit", requireLogin, async (req, res) => {
    const userId = req.session.user_id;
    const itemId = req.params.id;
    const body = req.body;
    let conn;
    try {
        const [owned] = await pool.execute(
            "SELECT item_id FROM ClothingItems WHERE item_id = ? AND user_id = ?",
            [itemId, userId]
        );
        if (owned.length === 0) {
            return res.redirect("/wardrobe");
        }

        const sections = await getSections();
        const sectionName = await getItemSection(itemId, sections);
        const filters = await getFilters(sectionName);

        const name = (body.item_name || "").trim();
        const addingNewBrand = body.brand_id === "__new__";
        const newBrand = (body.new_brand || "").trim();
        const picks = readPicks(body, filters);

        if (!name || picks.length === 0 || (addingNewBrand && !newBrand)) {
            return res.redirect(`/items/${itemId}/edit?error=1`);
        }

        conn = await pool.getConnection();
        await conn.beginTransaction();

        let brandId = null;
        if (addingNewBrand) {
            brandId = await findOrCreateBrand(conn, newBrand);
        } else if (body.brand_id) {
            brandId = Number(body.brand_id);
        }

        // 1) update the item (user_id in the WHERE again, for safety)
        await conn.execute(
            `UPDATE ClothingItems
                SET brand_id = ?, item_name = ?, size = ?, purchase_date = ?,
                    purchase_price = ?, availability_status = ?, notes = ?
              WHERE item_id = ? AND user_id = ?`,
            [
                brandId,
                name,
                (body.size || "").trim() || null,
                body.purchase_date || null,
                body.purchase_price || null,
                body.availability_status || "Available",
                (body.notes || "").trim() || null,
                itemId,
                userId
            ]
        );

        // 2) replace the item's categories: remove the old links, add the chosen ones
        await conn.execute("DELETE FROM ItemCategories WHERE item_id = ?", [itemId]);

        const categoryIds = new Set();
        for (const pick of picks) {
            const categoryId = pick.categoryId
                ? pick.categoryId
                : await findOrCreateCategory(conn, pick.group.id, pick.newName);
            categoryIds.add(categoryId);
        }
        for (const categoryId of categoryIds) {
            await conn.execute(
                "INSERT INTO ItemCategories (item_id, category_id) VALUES (?, ?)",
                [itemId, categoryId]
            );
        }

        await conn.commit();
        res.redirect(`/wardrobe?section=${encodeURIComponent(sectionName)}`);
    } catch (error) {
        if (conn) await conn.rollback();
        console.log(error);
        res.status(500).send("Could not save the changes.");
    } finally {
        if (conn) conn.release();
    }
});

app.get("/outfits/new", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const user = await getUser(userId);
        if (!user) {
            return res.redirect("/login");
        }

        const sections = await getSections();
        const items = await getPickerItems(userId);
        const [occasions] = await pool.execute(
            "SELECT occasion_id, occasion_name FROM Occasions ORDER BY occasion_name"
        );

        // "Add to Outfit" on a wardrobe card sends ?item=ID -> start with that item ticked
        const wanted = Number(req.query.item);
        const preselected = items.some((i) => i.item_id === wanted) ? [wanted] : [];

        const error = req.query.error
            ? "Please give the outfit a name and pick at least one item."
            : null;

        res.render("outfit-builder.ejs", { user, items, sections, occasions, preselected, error });
    } catch (error) {
        console.log(error);
        res.status(500).send("Could not load the page.");
    }
});

// ---------- OUTFIT BUILDER: save the outfit ----------
app.post("/outfits", requireLogin, async (req, res) => {
    const userId = req.session.user_id;
    const body = req.body;
    let conn;
    try {
        const name = (body.outfit_name || "").trim();

        // Item ids from the form. Checkboxes/hidden inputs arrive as one value or an array.
        const requestedItems = [...new Set(
            [].concat(body.item || []).map(Number).filter(Number.isInteger)
        )];

        // Keep only items that really belong to THIS user (never trust ids from the browser)
        let itemIds = [];
        if (requestedItems.length > 0) {
            const marks = requestedItems.map(() => "?").join(",");
            const [owned] = await pool.execute(
                `SELECT item_id FROM ClothingItems WHERE user_id = ? AND item_id IN (${marks})`,
                [userId, ...requestedItems]
            );
            itemIds = owned.map((row) => row.item_id);
        }

        if (!name || itemIds.length === 0) {
            return res.redirect("/outfits/new?error=1");
        }

        // Ticked occasions: keep only ids that exist in the Occasions table
        const requestedOccasions = [...new Set(
            [].concat(body.occasion || []).map(Number).filter(Number.isInteger)
        )];
        let occasionIds = [];
        if (requestedOccasions.length > 0) {
            const marks = requestedOccasions.map(() => "?").join(",");
            const [found] = await pool.execute(
                `SELECT occasion_id FROM Occasions WHERE occasion_id IN (${marks})`,
                requestedOccasions
            );
            occasionIds = found.map((row) => row.occasion_id);
        }

        conn = await pool.getConnection();
        await conn.beginTransaction();

        // an occasion typed by the user
        const newOccasion = (body.new_occasion || "").trim();
        if (newOccasion) {
            const newId = await findOrCreateOccasion(conn, newOccasion);
            if (!occasionIds.includes(newId)) occasionIds.push(newId);
        }

        // 1) the outfit
        const [result] = await conn.execute(
            "INSERT INTO Outfits (user_id, outfit_name, description, is_favorite) VALUES (?, ?, ?, ?)",
            [userId, name, (body.description || "").trim() || null, body.is_favorite ? 1 : 0]
        );
        const outfitId = result.insertId;

        // 2) its items (OutfitItems is the junction table)
        for (const itemId of itemIds) {
            await conn.execute(
                "INSERT INTO OutfitItems (outfit_id, item_id) VALUES (?, ?)",
                [outfitId, itemId]
            );
        }

        // 3) its occasions
        for (const occasionId of occasionIds) {
            await conn.execute(
                "INSERT INTO OutfitOccasions (outfit_id, occasion_id) VALUES (?, ?)",
                [outfitId, occasionId]
            );
        }

        await conn.commit(); // outfit + items + occasions saved together
        res.redirect("/outfits");
    } catch (error) {
        if (conn) await conn.rollback();
        console.log(error);
        res.status(500).send("Could not save the outfit.");
    } finally {
        if (conn) conn.release();
    }
});

// Does this outfit belong to this user? Used before every change to an outfit.
async function ownsOutfit(outfitId, userId) {
    const [rows] = await pool.execute(
        "SELECT outfit_id FROM Outfits WHERE outfit_id = ? AND user_id = ?",
        [outfitId, userId]
    );
    return rows.length > 0;
}

// Occasion ids ticked in a form (only ids that really exist in the Occasions table)
async function readOccasionIds(body) {
    const requested = [...new Set(
        [].concat(body.occasion || []).map(Number).filter(Number.isInteger)
    )];
    if (requested.length === 0) return [];
    const marks = requested.map(() => "?").join(",");
    const [found] = await pool.execute(
        `SELECT occasion_id FROM Occasions WHERE occasion_id IN (${marks})`,
        requested
    );
    return found.map((row) => row.occasion_id);
}

// ---------- OUTFITS PAGE: the list ----------
app.get("/outfits", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const user = await getUser(userId);
        if (!user) {
            return res.redirect("/login");
        }

        const search = (req.query.search || "").trim();
        const selectedOccasion = Number(req.query.occasion) || 0;
        const onlyFavorites = req.query.favorites === "1";

        // Build the query piece by piece (only "?" placeholders are added to the SQL)
        let sql = `SELECT o.outfit_id, o.outfit_name, o.description, o.created_at, o.is_favorite
                     FROM Outfits o
                    WHERE o.user_id = ?`;
        const params = [userId];

        if (search) {
            sql += " AND (o.outfit_name LIKE ? OR o.description LIKE ?)";
            params.push(`%${search}%`, `%${search}%`);
        }
        if (onlyFavorites) {
            sql += " AND o.is_favorite = 1";
        }
        if (selectedOccasion) {
            sql += ` AND EXISTS (SELECT 1 FROM OutfitOccasions oo
                                  WHERE oo.outfit_id = o.outfit_id AND oo.occasion_id = ?)`;
            params.push(selectedOccasion);
        }
        sql += " ORDER BY o.created_at DESC, o.outfit_id DESC";

        const [outfits] = await pool.execute(sql, params);

        // Load the items and occasions of ALL these outfits with two queries
        // (instead of two queries per outfit), then hand them out to each outfit.
        outfits.forEach((outfit) => {
            outfit.items = [];
            outfit.occasions = [];
        });

        if (outfits.length > 0) {
            const ids = outfits.map((o) => o.outfit_id);
            const marks = ids.map(() => "?").join(",");

            const [itemRows] = await pool.execute(
                `SELECT oi.outfit_id, ci.item_id, ci.item_name, ci.image_url
                   FROM OutfitItems oi
                   JOIN ClothingItems ci ON ci.item_id = oi.item_id
                  WHERE oi.outfit_id IN (${marks})
                  ORDER BY ci.item_name`,
                ids
            );
            const [occasionRows] = await pool.execute(
                `SELECT oo.outfit_id, oc.occasion_name
                   FROM OutfitOccasions oo
                   JOIN Occasions oc ON oc.occasion_id = oo.occasion_id
                  WHERE oo.outfit_id IN (${marks})
                  ORDER BY oc.occasion_name`,
                ids
            );

            const byId = new Map(outfits.map((o) => [o.outfit_id, o]));
            itemRows.forEach((row) => byId.get(row.outfit_id).items.push(row));
            occasionRows.forEach((row) => byId.get(row.outfit_id).occasions.push(row.occasion_name));
        }
        outfits.forEach((outfit) => {
            outfit.itemCount = outfit.items.length;
        });

        const [occasions] = await pool.execute(
            "SELECT occasion_id, occasion_name FROM Occasions ORDER BY occasion_name"
        );

        res.render("outfits.ejs", { user, outfits, occasions, selectedOccasion, search, onlyFavorites });
    } catch (error) {
        console.log(error);
        res.status(500).send("Could not load your outfits.");
    }
});

// ---------- favourite heart (called by the page with fetch, answers with JSON) ----------
app.post("/outfits/:id/favorite", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        // NOT flips 1 -> 0 and 0 -> 1. user_id in the WHERE: only YOUR outfits.
        await pool.execute(
            "UPDATE Outfits SET is_favorite = NOT is_favorite WHERE outfit_id = ? AND user_id = ?",
            [req.params.id, userId]
        );
        const [rows] = await pool.execute(
            "SELECT is_favorite FROM Outfits WHERE outfit_id = ? AND user_id = ?",
            [req.params.id, userId]
        );
        if (rows.length === 0) {
            return res.status(404).json({ message: "Outfit not found." });
        }
        res.json({ is_favorite: Boolean(rows[0].is_favorite) });
    } catch (error) {
        console.log(error);
        res.status(500).json({ message: "Could not update the favourite." });
    }
});

// ---------- delete an outfit ----------
app.post("/outfits/:id/delete", requireLogin, async (req, res) => {
    const outfitId = req.params.id;
    const userId = req.session.user_id;
    const conn = await pool.getConnection();
    try {
        await conn.beginTransaction();

        // only continue if this outfit belongs to the logged-in user
        const [owned] = await conn.execute(
            "SELECT outfit_id FROM Outfits WHERE outfit_id = ? AND user_id = ?",
            [outfitId, userId]
        );
        if (owned.length > 0) {
            // child tables first, then the outfit itself
            await conn.execute("DELETE FROM OutfitOccasions WHERE outfit_id = ?", [outfitId]);
            await conn.execute("DELETE FROM OutfitItems WHERE outfit_id = ?", [outfitId]);
            await conn.execute("DELETE FROM OutfitPlans WHERE outfit_id = ?", [outfitId]);
            await conn.execute("DELETE FROM WearLogs WHERE outfit_id = ?", [outfitId]);
            // If SuggestedOutfits also points at outfits, add a DELETE for it here too.
            await conn.execute("DELETE FROM Outfits WHERE outfit_id = ?", [outfitId]);
        }
        await conn.commit();
        res.redirect("/outfits");
    } catch (error) {
        await conn.rollback();
        console.log(error);
        res.status(500).send("Could not delete the outfit.");
    } finally {
        conn.release();
    }
});

app.get("/outfits/:id", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const outfitId = Number(req.params.id);
        if (!Number.isInteger(outfitId)) {
            return res.redirect("/outfits");
        }

        const user = await getUser(userId);
        if (!user) {
            return res.redirect("/login");
        }

        // user_id in the WHERE: you can only open YOUR OWN outfits
        const [outfitRows] = await pool.execute(
            `SELECT outfit_id, outfit_name, description, created_at, is_favorite
               FROM Outfits
              WHERE outfit_id = ? AND user_id = ?`,
            [outfitId, userId]
        );
        if (outfitRows.length === 0) {
            return res.redirect("/outfits");
        }
        const outfit = outfitRows[0];

        // All the user's items, split into "in this outfit" and "not in this outfit"
        const allItems = await getPickerItems(userId);
        const [linked] = await pool.execute(
            "SELECT item_id FROM OutfitItems WHERE outfit_id = ?",
            [outfitId]
        );
        const inOutfit = new Set(linked.map((row) => row.item_id));
        const items = allItems.filter((item) => inOutfit.has(item.item_id));
        const availableItems = allItems.filter((item) => !inOutfit.has(item.item_id));

        const [occasions] = await pool.execute(
            "SELECT occasion_id, occasion_name FROM Occasions ORDER BY occasion_name"
        );
        const [occasionRows] = await pool.execute(
            "SELECT occasion_id FROM OutfitOccasions WHERE outfit_id = ?",
            [outfitId]
        );
        const selectedOccasionIds = occasionRows.map((row) => row.occasion_id);

        const messages = {
            name: "Please give the outfit a name.",
            last: "An outfit needs at least one item. Delete the outfit if you don't want it."
        };
        const error = messages[req.query.error] || null;

        res.render("outfit-details.ejs", {
            user, outfit, items, availableItems, occasions, selectedOccasionIds, error
        });
    } catch (error) {
        console.log(error);
        res.status(500).send("Could not load the outfit.");
    }
});

// ---------- OUTFIT DETAILS: save name, description and occasions ----------
app.post("/outfits/:id/edit", requireLogin, async (req, res) => {
    const userId = req.session.user_id;
    const outfitId = Number(req.params.id);
    const body = req.body;
    let conn;
    try {
        if (!Number.isInteger(outfitId) || !(await ownsOutfit(outfitId, userId))) {
            return res.redirect("/outfits");
        }

        const name = (body.outfit_name || "").trim();
        if (!name) {
            return res.redirect(`/outfits/${outfitId}?error=name`);
        }
        const occasionIds = await readOccasionIds(body);

        conn = await pool.getConnection();
        await conn.beginTransaction();

        // an occasion typed by the user
        const newOccasion = (body.new_occasion || "").trim();
        if (newOccasion) {
            const newId = await findOrCreateOccasion(conn, newOccasion);
            if (!occasionIds.includes(newId)) occasionIds.push(newId);
        }

        // 1) name + description
        await conn.execute(
            "UPDATE Outfits SET outfit_name = ?, description = ? WHERE outfit_id = ? AND user_id = ?",
            [name, (body.description || "").trim() || null, outfitId, userId]
        );

        // 2) occasions: remove the old links, add the ticked ones
        await conn.execute("DELETE FROM OutfitOccasions WHERE outfit_id = ?", [outfitId]);
        for (const occasionId of occasionIds) {
            await conn.execute(
                "INSERT INTO OutfitOccasions (outfit_id, occasion_id) VALUES (?, ?)",
                [outfitId, occasionId]
            );
        }

        await conn.commit();
        res.redirect(`/outfits/${outfitId}`);
    } catch (error) {
        if (conn) await conn.rollback();
        console.log(error);
        res.status(500).send("Could not save the changes.");
    } finally {
        if (conn) conn.release();
    }
});

// ---------- OUTFIT DETAILS: add items ----------
app.post("/outfits/:id/items/add", requireLogin, async (req, res) => {
    const userId = req.session.user_id;
    const outfitId = Number(req.params.id);
    let conn;
    try {
        if (!Number.isInteger(outfitId) || !(await ownsOutfit(outfitId, userId))) {
            return res.redirect("/outfits");
        }

        const requested = [...new Set(
            [].concat(req.body.item || []).map(Number).filter(Number.isInteger)
        )];

        if (requested.length > 0) {
            // keep only items that belong to this user...
            const marks = requested.map(() => "?").join(",");
            const [owned] = await pool.execute(
                `SELECT item_id FROM ClothingItems WHERE user_id = ? AND item_id IN (${marks})`,
                [userId, ...requested]
            );
            // ...and that are not already in the outfit
            const [existing] = await pool.execute(
                "SELECT item_id FROM OutfitItems WHERE outfit_id = ?",
                [outfitId]
            );
            const already = new Set(existing.map((row) => row.item_id));
            const toAdd = owned.map((row) => row.item_id).filter((id) => !already.has(id));

            if (toAdd.length > 0) {
                conn = await pool.getConnection();
                await conn.beginTransaction();
                for (const itemId of toAdd) {
                    await conn.execute(
                        "INSERT INTO OutfitItems (outfit_id, item_id) VALUES (?, ?)",
                        [outfitId, itemId]
                    );
                }
                await conn.commit();
            }
        }
        res.redirect(`/outfits/${outfitId}`);
    } catch (error) {
        if (conn) await conn.rollback();
        console.log(error);
        res.status(500).send("Could not add the items.");
    } finally {
        if (conn) conn.release();
    }
});

// ---------- OUTFIT DETAILS: remove one item from the outfit ----------
// This only removes the link in OutfitItems. The item stays in the wardrobe.
app.post("/outfits/:id/items/:itemId/remove", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const outfitId = Number(req.params.id);
        const itemId = Number(req.params.itemId);
        if (!Number.isInteger(outfitId) || !Number.isInteger(itemId)
            || !(await ownsOutfit(outfitId, userId))) {
            return res.redirect("/outfits");
        }

        // an outfit must keep at least one item
        const [count] = await pool.execute(
            "SELECT COUNT(*) AS total FROM OutfitItems WHERE outfit_id = ?",
            [outfitId]
        );
        if (count[0].total <= 1) {
            return res.redirect(`/outfits/${outfitId}?error=last`);
        }

        await pool.execute(
            "DELETE FROM OutfitItems WHERE outfit_id = ? AND item_id = ?",
            [outfitId, itemId]
        );
        res.redirect(`/outfits/${outfitId}`);
    } catch (error) {
        console.log(error);
        res.status(500).send("Could not remove the item.");
    }
});

// NOTE: OutfitPlans is assumed to have: plan_id, outfit_id, occasion_id, planned_date, notes
// (no user_id - we find the owner through Outfits.user_id). Run DESCRIBE OutfitPlans;
// and change the names below if yours are different.
app.get("/planner", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const user = await getUser(userId);
        if (!user) {
            return res.redirect("/login");
        }

        const today = todayString(0);
        const tomorrow = todayString(1);

        // the user's outfits, for the "Plan an outfit" dropdown
        const [outfits] = await pool.execute(
            "SELECT outfit_id, outfit_name FROM Outfits WHERE user_id = ? ORDER BY outfit_name",
            [userId]
        );

        // which occasions each outfit already has (used to pre-select the occasion)
        const [links] = await pool.execute(
            `SELECT oo.outfit_id, oo.occasion_id
             FROM OutfitOccasions oo
             JOIN Outfits o ON o.outfit_id = oo.outfit_id
             WHERE o.user_id = ?
             ORDER BY oo.occasion_id`,
            [userId]
        );
        outfits.forEach((outfit) => {
            outfit.occasionIds = links
                .filter((l) => l.outfit_id === outfit.outfit_id)
                .map((l) => l.occasion_id);
        });

        const [occasions] = await pool.execute(
            "SELECT occasion_id, occasion_name FROM Occasions ORDER BY occasion_name"
        );

        // every plan of this user (DATE_FORMAT gives a plain "YYYY-MM-DD" text, no time-zone surprises)
        const [plans] = await pool.execute(
            `SELECT p.plan_id, p.outfit_id, p.occasion_id, p.notes,
                    DATE_FORMAT(p.planned_date, '%Y-%m-%d') AS planned_date,
                    o.outfit_name, oc.occasion_name
             FROM OutfitPlans p
             JOIN Outfits o ON o.outfit_id = p.outfit_id
             LEFT JOIN Occasions oc ON oc.occasion_id = p.occasion_id
             WHERE o.user_id = ?
             ORDER BY p.planned_date, p.plan_id`,
            [userId]
        );

        // up to 3 items per outfit, for the little pictures
        const [itemRows] = await pool.execute(
            `SELECT oi.outfit_id, i.item_name, i.image_url
             FROM OutfitItems oi
             JOIN ClothingItems i ON i.item_id = oi.item_id
             JOIN Outfits o ON o.outfit_id = oi.outfit_id
             WHERE o.user_id = ?
             ORDER BY i.item_id`,
            [userId]
        );
        plans.forEach((plan) => {
            plan.items = itemRows.filter((r) => r.outfit_id === plan.outfit_id).slice(0, 3);
        });

        // split into upcoming (grouped by date) and past
        const groups = [];
        const past = [];
        const calendarData = {};
        plans.forEach((plan) => {
            calendarData[plan.planned_date] = (calendarData[plan.planned_date] || 0) + 1;
            if (plan.planned_date < today) {
                past.push(plan);
                return;
            }
            let group = groups.find((g) => g.date === plan.planned_date);
            if (!group) {
                group = { date: plan.planned_date, plans: [] };
                groups.push(group);
            }
            group.plans.push(plan);
        });
        past.reverse();   // newest first
        past.splice(20);  // show at most 20 old plans

        res.render("planner", {
            user, outfits, occasions, groups, past, calendarData, today, tomorrow,
            error: plannerErrors[req.query.error] || null,
        });
    } catch (err) {
        console.error(err);
        res.status(500).send("Could not load the planner.");
    }
});

// ---------- PLANNER: add a plan ----------
app.post("/planner", requireLogin, async (req, res) => {
    let conn;
    try {
        const userId = req.session.user_id;
        const outfitId = Number(req.body.outfit_id);
        const planDate = (req.body.plan_date || "").trim();
        const notes = (req.body.notes || "").trim() || null;
        const newOccasion = (req.body.new_occasion || "").trim();

        if (!Number.isInteger(outfitId) || !req.body.occasion_id || !planDate) {
            return res.redirect("/planner?error=missing");
        }
        if (!isValidDate(planDate)) {
            return res.redirect("/planner?error=date");
        }
        if (planDate < todayString(0)) {
            return res.redirect("/planner?error=past");
        }
        // the outfit must be this user's
        if (!(await ownsOutfit(outfitId, userId))) {
            return res.redirect("/planner");
        }

        conn = await pool.getConnection();
        await conn.beginTransaction();

        // occasion: "__new__" means use the typed text, otherwise it must exist
        let occasionId;
        if (req.body.occasion_id === "__new__") {
            if (!newOccasion) {
                await conn.rollback();
                return res.redirect("/planner?error=missing");
            }
            occasionId = await findOrCreateOccasion(conn, newOccasion);
        } else {
            occasionId = Number(req.body.occasion_id);
            const [found] = await conn.execute(
                "SELECT occasion_id FROM Occasions WHERE occasion_id = ?",
                [occasionId]
            );
            if (found.length === 0) {
                await conn.rollback();
                return res.redirect("/planner?error=missing");
            }
        }

        // the same outfit twice on one day makes no sense
        const [dup] = await conn.execute(
            "SELECT plan_id FROM OutfitPlans WHERE outfit_id = ? AND planned_date = ?",
            [outfitId, planDate]
        );
        if (dup.length > 0) {
            await conn.rollback();
            return res.redirect("/planner?error=dup");
        }

        await conn.execute(
            "INSERT INTO OutfitPlans (outfit_id, occasion_id, planned_date, notes) VALUES (?, ?, ?, ?)",
            [outfitId, occasionId, planDate, notes]
        );

        await conn.commit();
        res.redirect("/planner");
    } catch (err) {
        if (conn) await conn.rollback();
        console.error(err);
        res.status(500).send("Could not save the plan.");
    } finally {
        if (conn) conn.release();
    }
});

// ---------- PLANNER: edit a plan (occasion, date, notes) ----------
app.post("/planner/:id/edit", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const planId = Number(req.params.id);
        const occasionId = Number(req.body.occasion_id);
        const planDate = (req.body.plan_date || "").trim();
        const notes = (req.body.notes || "").trim() || null;

        if (!Number.isInteger(planId) || !Number.isInteger(occasionId) || !planDate) {
            return res.redirect("/planner?error=missing");
        }
        if (!isValidDate(planDate)) {
            return res.redirect("/planner?error=date");
        }
        if (planDate < todayString(0)) {
            return res.redirect("/planner?error=past");
        }

        // is there already the same outfit on that day (in a different plan)?
        const [dup] = await pool.execute(
            `SELECT p2.plan_id
             FROM OutfitPlans p
             JOIN Outfits o ON o.outfit_id = p.outfit_id
             JOIN OutfitPlans p2 ON p2.outfit_id = p.outfit_id
                  AND p2.planned_date = ? AND p2.plan_id <> p.plan_id
             WHERE p.plan_id = ? AND o.user_id = ?`,
            [planDate, planId, userId]
        );
        if (dup.length > 0) {
            return res.redirect("/planner?error=dup");
        }

        // JOIN to Outfits so only the owner's plans can be changed
        await pool.execute(
            `UPDATE OutfitPlans p
             JOIN Outfits o ON o.outfit_id = p.outfit_id
             SET p.occasion_id = ?, p.planned_date = ?, p.notes = ?
             WHERE p.plan_id = ? AND o.user_id = ?`,
            [occasionId, planDate, notes, planId, userId]
        );
        res.redirect("/planner");
    } catch (err) {
        console.error(err);
        res.status(500).send("Could not update the plan.");
    }
});

// ---------- PLANNER: delete a plan (the outfit itself stays) ----------
app.post("/planner/:id/delete", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const planId = Number(req.params.id);
        if (Number.isInteger(planId)) {
            await pool.execute(
                `DELETE p FROM OutfitPlans p
                 JOIN Outfits o ON o.outfit_id = p.outfit_id
                 WHERE p.plan_id = ? AND o.user_id = ?`,
                [planId, userId]
            );
        }
        res.redirect("/planner");
    } catch (err) {
        console.error(err);
        res.status(500).send("Could not remove the plan.");
    }
});

app.get("/wear-log", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const user = await getUser(userId);
        if (!user) {
            return res.redirect("/login");
        }

        const [outfits] = await pool.execute(
            "SELECT outfit_id, outfit_name FROM Outfits WHERE user_id = ? ORDER BY outfit_name",
            [userId]
        );

        const [logs] = await pool.execute(
            `SELECT w.wear_log_id, w.outfit_id, o.outfit_name, w.feedback,
                    DATE_FORMAT(w.worn_at, '%Y-%m-%d') AS worn_at,
                    w.colour_rating, w.size_rating, w.comfort_rating, w.style_rating
             FROM WearLogs w
             JOIN Outfits o ON o.outfit_id = w.outfit_id
             WHERE o.user_id = ?
             ORDER BY w.worn_at DESC, w.wear_log_id DESC`,
            [userId]
        );

        // average of the four ratings for each entry, and overall
        let sum = 0;
        logs.forEach((log) => {
            log.average = (log.colour_rating + log.size_rating + log.comfort_rating + log.style_rating) / 4;
            sum += log.average;
        });
        const stats = {
            total: logs.length,
            average: logs.length ? sum / logs.length : null,
        };

        const errors = {
            missing: "Please choose an outfit, a date and rate all four things.",
            date: "That date is not valid, or it is in the future.",
        };

        res.render("wear-log", {
            user, outfits, logs, stats,
            today: todayString(0),
            error: errors[req.query.error] || null,
        });
    } catch (err) {
        console.error(err);
        res.status(500).send("Could not load the wear log.");
    }
});

// ---------- WEAR LOG: add an entry ----------
app.post("/wear-log", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const outfitId = Number(req.body.outfit_id);
        const wornAt = (req.body.worn_at || "").trim();

        // each rating must be a whole number from 1 to 5
        const ratings = ["colour_rating", "size_rating", "comfort_rating", "style_rating"]
            .map((field) => Number(req.body[field]));
        const ratingsOk = ratings.every((n) => Number.isInteger(n) && n >= 1 && n <= 5);

        if (!Number.isInteger(outfitId) || !wornAt || !ratingsOk) {
            return res.redirect("/wear-log?error=missing");
        }
        if (!isValidDate(wornAt) || wornAt > todayString(0)) {
            return res.redirect("/wear-log?error=date");
        }
        if (!(await ownsOutfit(outfitId, userId))) {
            return res.redirect("/wear-log");
        }

        await pool.execute(
            `INSERT INTO WearLogs
               (outfit_id, worn_at, feedback, colour_rating, size_rating, comfort_rating, style_rating)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [outfitId, wornAt, (req.body.feedback || "").trim().slice(0, 500) || null, ...ratings]
        );
        res.redirect("/wear-log");
    } catch (err) {
        console.error(err);
        res.status(500).send("Could not save the log entry.");
    }
});

// ---------- WEAR LOG: delete an entry ----------
app.post("/wear-log/:id/delete", requireLogin, async (req, res) => {
    try {
        const logId = Number(req.params.id);
        if (Number.isInteger(logId)) {
            // JOIN to Outfits so you can only delete your own entries
            await pool.execute(
                `DELETE w FROM WearLogs w
                 JOIN Outfits o ON o.outfit_id = w.outfit_id
                 WHERE w.wear_log_id = ? AND o.user_id = ?`,
                [logId, req.session.user_id]
            );
        }
        res.redirect("/wear-log");
    } catch (err) {
        console.error(err);
        res.status(500).send("Could not delete the log entry.");
    }
});

// ---------- RECOMMENDATIONS ----------
// Top 3 outfits by average weighted score. Ties go to the outfit worn more often.
// Optional filter: /recommendations?occasion=3
app.get("/recommendations", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const user = await getUser(userId);
        if (!user) {
            return res.redirect("/login");
        }

        const weights = await getRatingWeights(userId);

        const [occasions] = await pool.execute(
            "SELECT occasion_id, occasion_name FROM Occasions ORDER BY occasion_name"
        );
        const selectedOccasion = Number(req.query.occasion) || null;

        // all wear logs of this user (optionally only outfits that have the chosen occasion)
        let sql =
            `SELECT w.outfit_id, o.outfit_name,
                    DATE_FORMAT(w.worn_at, '%Y-%m-%d') AS worn_at,
                    w.colour_rating, w.size_rating, w.comfort_rating, w.style_rating
             FROM WearLogs w
             JOIN Outfits o ON o.outfit_id = w.outfit_id
             WHERE o.user_id = ?`;
        const params = [userId];
        if (selectedOccasion) {
            sql += " AND EXISTS (SELECT 1 FROM OutfitOccasions oo WHERE oo.outfit_id = o.outfit_id AND oo.occasion_id = ?)";
            params.push(selectedOccasion);
        }
        const [logs] = await pool.execute(sql, params);

        // group the logs by outfit and add up the numbers
        const byOutfit = {};
        logs.forEach((log) => {
            if (!byOutfit[log.outfit_id]) {
                byOutfit[log.outfit_id] = {
                    outfit_id: log.outfit_id, outfit_name: log.outfit_name,
                    wearCount: 0, scoreSum: 0, lastWorn: null,
                    sumColour: 0, sumSize: 0, sumComfort: 0, sumStyle: 0,
                };
            }
            const o = byOutfit[log.outfit_id];
            o.wearCount++;
            o.scoreSum += weightedScore(log, weights);
            o.sumColour += log.colour_rating;
            o.sumSize += log.size_rating;
            o.sumComfort += log.comfort_rating;
            o.sumStyle += log.style_rating;
            if (!o.lastWorn || log.worn_at > o.lastWorn) o.lastWorn = log.worn_at;
        });

        // turn the sums into averages, sort, keep the top 3
        const picks = Object.values(byOutfit).map((o) => ({
            outfit_id: o.outfit_id, outfit_name: o.outfit_name,
            wearCount: o.wearCount, lastWorn: o.lastWorn,
            score: o.scoreSum / o.wearCount,
            avgColour: o.sumColour / o.wearCount,
            avgSize: o.sumSize / o.wearCount,
            avgComfort: o.sumComfort / o.wearCount,
            avgStyle: o.sumStyle / o.wearCount,
            items: [], unavailable: false,
        }));
        picks.sort((a, b) => (b.score - a.score) || (b.wearCount - a.wearCount));
        picks.splice(3);

        // items of the chosen outfits (for the pictures + the "unavailable" warning)
        if (picks.length > 0) {
            const marks = picks.map(() => "?").join(",");
            const [itemRows] = await pool.execute(
                `SELECT oi.outfit_id, i.item_name, i.image_url, i.availability_status
                 FROM OutfitItems oi
                 JOIN ClothingItems i ON i.item_id = oi.item_id
                 WHERE i.user_id = ? AND oi.outfit_id IN (${marks})
                 ORDER BY i.item_id`,
                [userId, ...picks.map((p) => p.outfit_id)]
            );
            picks.forEach((pick) => {
                const mine = itemRows.filter((r) => r.outfit_id === pick.outfit_id);
                pick.items = mine.slice(0, 3);
                pick.unavailable = mine.some((r) => r.availability_status !== "Available");
            });
        }

        res.render("recommendations", { user, picks, occasions, selectedOccasion, weights });
    } catch (err) {
        console.error(err);
        res.status(500).send("Could not load recommendations.");
    }
});


// ---------- PROFILE: show the page ----------
app.get("/profile", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const user = await getUser(userId);
        if (!user) {
            return res.redirect("/login");
        }
        const [rows] = await pool.execute("SELECT email FROM Users WHERE user_id = ?", [userId]);
        const weights = await getRatingWeights(userId);

        res.render("profile", {
            user,
            email: rows.length ? rows[0].email : "",
            weights,
            saved: req.query.saved === "1",
            error: req.query.error === "invalid" ? "Each priority must be a whole number from 1 to 5." : null,
        });
    } catch (err) {
        console.error(err);
        res.status(500).send("Could not load your profile.");
    }
});

// ---------- PROFILE: save the rating priorities ----------
app.post("/profile/preferences", requireLogin, async (req, res) => {
    try {
        // the form sends weight_colour, weight_size, weight_comfort, weight_style
        const values = ["weight_colour", "weight_size", "weight_comfort", "weight_style"]
            .map((field) => Number(req.body[field]));

        // never trust the browser: each value must be a whole number from 1 to 5
        if (!values.every((n) => Number.isInteger(n) && n >= 1 && n <= 5)) {
            return res.redirect("/profile?error=invalid");
        }

        await pool.execute(
            `UPDATE Users
             SET weight_colour = ?, weight_size = ?, weight_comfort = ?, weight_style = ?
             WHERE user_id = ?`,
            [...values, req.session.user_id]
        );
        res.redirect("/profile?saved=1");
    } catch (err) {
        console.error(err);
        res.status(500).send("Could not save your preferences.");
    }
});

// ---------- ANALYTICS DASHBOARD (final version: wardrobe + items + outfits) ----------
// Every query only uses THIS user's data (user_id = ?, or through Outfits.user_id).
// Assumes the Categories tree: root (Clothing...) -> group (Colour, Type...) -> value (Red, Shirt...).
// The colour chart looks for a group named "Colour" - change the word in query 3 if yours differs.
//
// "Wears" of an item = how many wear-log entries belong to outfits that contain the item.
// Cost per wear = purchase_price / wears.
app.get("/dashboard", requireLogin, async (req, res) => {
    try {
        const userId = req.session.user_id;
        const user = await getUser(userId);
        if (!user) {
            return res.redirect("/login");
        }

        // 1) number tiles
        const [[itemStats]] = await pool.execute(
            "SELECT COUNT(*) AS items, COALESCE(SUM(purchase_price), 0) AS value FROM ClothingItems WHERE user_id = ?",
            [userId]
        );
        const [[outfitStats]] = await pool.execute(
            "SELECT COUNT(*) AS outfits FROM Outfits WHERE user_id = ?",
            [userId]
        );
        const [[wearStats]] = await pool.execute(
            `SELECT COUNT(*) AS wears,
                    AVG(w.colour_rating) AS colour, AVG(w.size_rating) AS size,
                    AVG(w.comfort_rating) AS comfort, AVG(w.style_rating) AS style
             FROM WearLogs w
             JOIN Outfits o ON o.outfit_id = w.outfit_id
             WHERE o.user_id = ?`,
            [userId]
        );

        // 2) items per section: walk up value -> group -> root
        const [sectionRows] = await pool.execute(
            `SELECT r.category_name AS label, COUNT(DISTINCT i.item_id) AS total
             FROM ClothingItems i
             JOIN ItemCategories ic ON ic.item_id = i.item_id
             JOIN Categories v ON v.category_id = ic.category_id
             JOIN Categories g ON g.category_id = v.parent_category_id
             JOIN Categories r ON r.category_id = g.parent_category_id
             WHERE i.user_id = ? AND r.parent_category_id IS NULL
             GROUP BY r.category_id, r.category_name
             ORDER BY total DESC`,
            [userId]
        );

        // 3) items per colour (top 8)
        const [colourRows] = await pool.execute(
            `SELECT v.category_name AS label, COUNT(DISTINCT i.item_id) AS total
             FROM ClothingItems i
             JOIN ItemCategories ic ON ic.item_id = i.item_id
             JOIN Categories v ON v.category_id = ic.category_id
             JOIN Categories g ON g.category_id = v.parent_category_id
             WHERE i.user_id = ? AND LOWER(g.category_name) = 'colour'
             GROUP BY v.category_id, v.category_name
             ORDER BY total DESC
             LIMIT 8`,
            [userId]
        );

        // 4) money spent per brand (top 6)
        const [brandRows] = await pool.execute(
            `SELECT COALESCE(b.brand_name, 'No brand') AS label, SUM(i.purchase_price) AS total
             FROM ClothingItems i
             LEFT JOIN Brands b ON b.brand_id = i.brand_id
             WHERE i.user_id = ? AND i.purchase_price IS NOT NULL
             GROUP BY b.brand_id, b.brand_name
             ORDER BY total DESC
             LIMIT 6`,
            [userId]
        );

        // 5) items by availability (Available / In Laundry / Unavailable)
        const [statusRows] = await pool.execute(
            `SELECT availability_status AS label, COUNT(*) AS total
             FROM ClothingItems WHERE user_id = ?
             GROUP BY availability_status ORDER BY total DESC`,
            [userId]
        );

        // 6) wears and price of EVERY item (this one query feeds the item charts + cost per wear)
        const [itemRows] = await pool.execute(
            `SELECT i.item_id, i.item_name, i.purchase_price, COUNT(w.wear_log_id) AS wears
             FROM ClothingItems i
             LEFT JOIN OutfitItems oi ON oi.item_id = i.item_id
             LEFT JOIN WearLogs w ON w.outfit_id = oi.outfit_id
             WHERE i.user_id = ?
             GROUP BY i.item_id, i.item_name, i.purchase_price`,
            [userId]
        );
        const items = itemRows.map((row) => ({
            item_id: row.item_id,
            item_name: row.item_name,
            price: row.purchase_price === null ? 0 : Number(row.purchase_price),
            wears: Number(row.wears),
        }));

        // most worn items (top 8)
        const topItems = items
            .filter((i) => i.wears > 0)
            .sort((a, b) => b.wears - a.wears || a.item_name.localeCompare(b.item_name))
            .slice(0, 8);

        // cost per wear: only items that have a price AND were worn at least once
        const costed = items
            .filter((i) => i.wears > 0 && i.price > 0)
            .map((i) => ({ ...i, cpw: i.price / i.wears }));
        const bestValue = [...costed].sort((a, b) => a.cpw - b.cpw).slice(0, 5);
        const worstValue = [...costed].sort((a, b) => b.cpw - a.cpw).slice(0, 5);
        const avgCpw = costed.length
            ? costed.reduce((sum, i) => sum + i.cpw, 0) / costed.length
            : null;

        // items never worn
        const unusedItems = items.filter((i) => i.wears === 0).sort((a, b) => b.item_id - a.item_id);

        // 7) outfits worn per month, last 6 months (months with no wears are filled in as 0)
        const monthKeys = [];      // "2026-11"
        const monthLabels = [];    // "Nov 2026"
        const now = new Date();
        for (let back = 5; back >= 0; back--) {
            const d = new Date(now.getFullYear(), now.getMonth() - back, 1);
            monthKeys.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`);
            monthLabels.push(d.toLocaleDateString("en-IN", { month: "short", year: "numeric" }));
        }
        const [monthRows] = await pool.execute(
            `SELECT DATE_FORMAT(w.worn_at, '%Y-%m') AS ym, COUNT(*) AS total
             FROM WearLogs w
             JOIN Outfits o ON o.outfit_id = w.outfit_id
             WHERE o.user_id = ? AND w.worn_at >= ?
             GROUP BY ym`,
            [userId, monthKeys[0] + "-01"]
        );

        // 8) most worn outfits (top 5)
        const [topOutfitRows] = await pool.execute(
            `SELECT o.outfit_name AS label, COUNT(*) AS total
             FROM WearLogs w
             JOIN Outfits o ON o.outfit_id = w.outfit_id
             WHERE o.user_id = ?
             GROUP BY o.outfit_id, o.outfit_name
             ORDER BY total DESC, o.outfit_name
             LIMIT 5`,
            [userId]
        );

        const wears = wearStats.wears;
        const round1 = (n) => Math.round(Number(n) * 10) / 10;

        const stats = {
            items: itemStats.items,
            outfits: outfitStats.outfits,
            wears,
            value: Number(itemStats.value),
            avgCpw,
            avgRating: wears
                ? (Number(wearStats.colour) + Number(wearStats.size) + Number(wearStats.comfort) + Number(wearStats.style)) / 4
                : null,
        };

        const charts = {
            sections: { labels: sectionRows.map((r) => r.label), values: sectionRows.map((r) => r.total) },
            colours: { labels: colourRows.map((r) => r.label), values: colourRows.map((r) => r.total) },
            brands: { labels: brandRows.map((r) => r.label), values: brandRows.map((r) => Number(r.total)) },
            status: { labels: statusRows.map((r) => r.label), values: statusRows.map((r) => r.total) },
            topItems: { labels: topItems.map((i) => i.item_name), values: topItems.map((i) => i.wears) },
            months: {
                labels: monthLabels,
                values: monthKeys.map((key) => {
                    const row = monthRows.find((r) => r.ym === key);
                    return row ? row.total : 0;
                }),
            },
            ratings: {
                labels: ["Colour", "Fit / size", "Comfort", "Style"],
                values: wears ? [wearStats.colour, wearStats.size, wearStats.comfort, wearStats.style].map(round1) : [],
            },
            topOutfits: { labels: topOutfitRows.map((r) => r.label), values: topOutfitRows.map((r) => r.total) },
        };

        res.render("dashboard", {
            user, stats, charts,
            best: bestValue,
            worst: worstValue,
            unused: {
                total: unusedItems.length,
                value: unusedItems.reduce((sum, i) => sum + i.price, 0),
                list: unusedItems.slice(0, 12),
            },
        });
    } catch (err) {
        console.error(err);
        res.status(500).send("Could not load the dashboard.");
    }
});

app.listen(port,() =>{
    console.log(`Server running on port ${port}`);
})