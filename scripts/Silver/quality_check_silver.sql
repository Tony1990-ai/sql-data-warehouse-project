/*
===============================================================================
Data Quality Checks & Cleaning (Silver Layer ETL)
===============================================================================
Course: SQL Full Course for Beginners (Data with Baraa)
Description: 
    This script performs essential data quality checks and transformations 
    to clean raw data from the Bronze layer before inserting into the Silver layer.
    
Quality Checks Covered:
    1. Check for Unwanted Spaces (TRIM)
    2. Check for NULL or Missing Values
    3. Check for Duplicate Records
    4. Check for Invalid Dates / Out-of-Range Values
    5. Data Standardization & Normalization
===============================================================================
*/

-- ============================================================================
-- 1. Check & Clean Customer Data (e.g., silver.crm_cust_info)
-- ============================================================================

-- Check for leading/trailing whitespace in customer names
SELECT cst_firstname
FROM bronze.crm_cust_info
WHERE cst_firstname != TRIM(cst_firstname);

-- Check for NULLs or missing values in primary key
SELECT cst_id, COUNT(*)
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Standardize Gender and Marital Status (Handling invalid/missing codes)
SELECT DISTINCT 
    cst_gndr,
    CASE 
        WHEN UPPER(TRIM(cst_gndr)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(cst_gndr)) IN ('M', 'MALE') THEN 'Male'
        ELSE 'n/a'
    END AS cleaned_gender
FROM bronze.crm_cust_info;


-- ============================================================================
-- 2. Check & Clean Product Data (e.g., silver.crm_prd_info)
-- ============================================================================

-- Check for NULL or negative product costs
SELECT prd_id, prd_cost
FROM bronze.crm_prd_info
WHERE prd_cost IS NULL OR prd_cost < 0;

-- Extract and clean product sub-category / key fields
SELECT 
    prd_id,
    REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
    TRIM(prd_nm) AS prd_nm,
    COALESCE(prd_cost, 0) AS prd_cost
FROM bronze.crm_prd_info;


-- ============================================================================
-- 3. Check & Clean Sales / Orders Data (e.g., silver.crm_sales_details)
-- ============================================================================

-- Check for invalid order dates (e.g., order date after ship date or zero dates)
SELECT sls_ord_num, sls_order_dt, sls_ship_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt 
   OR sls_order_dt <= 0 
   OR LEN(sls_order_dt) != 8;

-- Check for invalid price / sales calculation inconsistencies
SELECT sls_ord_num, sls_price, sls_quantity, sls_sales
FROM bronze.crm_sales_details
WHERE sls_sales != sls_price * sls_quantity
   OR sls_price IS NULL 
   OR sls_price <= 0;


-- ============================================================================
-- 4. Silver Layer ETL Insert with Integrated Quality Checks
-- ============================================================================

INSERT INTO silver.crm_cust_info (
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
)
SELECT
    cst_id,
    cst_key,
    TRIM(cst_firstname) AS cst_firstname,
    TRIM(cst_lastname) AS cst_lastname,
    CASE 
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
        ELSE 'n/a'
    END AS cst_marital_status,
    CASE 
        WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
        WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        ELSE 'n/a'
    END AS cst_gndr,
    cst_create_date
FROM (
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
) t
WHERE flag_last = 1; -- Filter out duplicate customer records
