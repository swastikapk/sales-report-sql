# 🏗️ Data Warehouse Setup – `DataWarehouseAnalytics`(from watching DataByBara)

This project contains a full SQL Server script to **create and initialize a data warehouse environment** named `DataWarehouseAnalytics`.  
It demonstrates practical **database design, schema management, and analytics view creation** using T-SQL — suitable for portfolio or production demonstration.

---

## 🎯 Project Purpose

This SQL project shows how to:

- Design and initialize a **data warehouse database** from scratch  
- Create **structured schemas** (e.g., `gold`) to separate data layers  
- Build **reporting views** for analytical use (such as `report_product`)  
- Apply **best practices in database recreation, version control, and safety warnings**

---

## ⚙️ What the Script Does

### 1. 🧱 Database Initialization
- Checks if a database named `DataWarehouseAnalytics` exists.  
- If it does, the script **drops and recreates** it safely.  
- Ensures a **clean environment** for rebuilding or testing warehouse components.

### 2. 🗂️ Schema Creation
- Creates a schema called **`gold`**, typically used for:
  - Finalized, ready-for-analysis data
  - Aggregated tables or views
  - Consistent structure across reporting layers

### 3. 🧮 Reporting & Views (example: `gold.report_product`)
Later parts of this warehouse project can include analytical views such as:
- **Product performance view**
- **Customer revenue summary**
- **Sales trend aggregation**

Each view follows a **CTE-based modular structure** for readability and maintainability.

---

## 💡 Key SQL Concepts Demonstrated

| Concept | Description |
|----------|--------------|
| `IF EXISTS` + `DROP DATABASE` | Conditional recreation of environments |
| `CREATE SCHEMA` | Organized data layer separation |
| `WITH (CTE)` | Clean and modular query logic |
| `JOIN` & `GROUP BY` | Combining and summarizing business data |
| `CASE WHEN` | Performance segmentation logic |
| `DATEDIFF` | Recency and lifespan calculations |

---


