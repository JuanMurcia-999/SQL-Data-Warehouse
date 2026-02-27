SELECT  
	cst_id,
	COUNT(*) 
		FROM silver.crm_cust_info
		GROUP BY cst_id
		HAVING COUNT(*)>1 OR cst_id IS NULL;


-- Check for unwanted Spaces
-- Expectation: No Results

SELECT cst_lastname
	FROM silver.crm_cust_info
	WHERE cst_firstname != TRIM(cst_firstname)


SELECT prd_nm
	FROM bronze.crm_prd_info
	WHERE  prd_nm != TRIM( prd_nm) OR prd_nm IS NULL

SELECT prd_cost 
	FROM bronze.crm_prd_info
	WHERE prd_cost <0 OR prd_cost IS NULL;

-- Data Standarization & Consistency	
SELECT DISTINCT cst_gndr
	FROM silver.crm_cust_info

SELECT DISTINCT cst_marital_status
	FROM bronze.crm_cust_info
	WHERE cst_marital_status


--Count Duplicates
SELECT 
	prd_id,
	COUNT(*)
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL




SELECT * FROM silver.crm_prd_info
	WHERE prd_key = 'BC-M005';

-- ======================================================================================
-- Validations bronze.crm_sales_details
-- Expectation: No Results
SELECT 
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	sls_order_dt,
	sls_ship_dt,
	sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price
	FROM bronze.crm_sales_details
	WHERE sls_ord_num != TRIM(sls_ord_num);

-- use the sls_prd_key Pk
-- Expectation: No Results
	SELECT 
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	sls_order_dt,
	sls_ship_dt,
	sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price
	FROM bronze.crm_sales_details
	WHERE sls_prd_key NOT IN (
		SELECT prd_key
			FROM silver.crm_prd_info);

			
-- use the sls_cust_id Pk
-- Expectation: No Results
	SELECT 
	sls_ord_num,
	sls_prd_key,
	sls_cust_id,
	sls_order_dt,
	sls_ship_dt,
	sls_due_dt,
	sls_sales,
	sls_quantity,
	sls_price
	FROM bronze.crm_sales_details
	WHERE sls_cust_id NOT IN (
		SELECT cst_id
			FROM silver.crm_cust_info);


-- Check for Invalid Dates
-- Expectation: 

SELECT 
	NULLIF(sls_order_dt ,0 ) sls_order_dt
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0
OR LEN(sls_order_dt) != 8
OR sls_order_dt > 20500101
OR sls_order_dt < 19000101;

-- check for Invalidate Date Orders
-- Expectation: 
SELECT * 
FROM 
	bronze.crm_sales_details
WHERE 
	sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt

/*check sales, quiantity, price
Rules Check:
	- SUM Sales = Quantity * Price
	- Negative,  Zeros, Nulls are not allowed 

Rules Business:
	- If Sales is negative, zero or null, derive it usuing Quantity and price
	- If price is zero or null, calculate it using Sales and quantity
	- if Price is negative, Convert it to a positive value
*/  


SELECT DISTINCT
	sls_sales AS old_sls_sales,
	sls_quantity,
	sls_price AS old_sls_price,
	CASE 
		WHEN sls_sales IS NULL OR sls_sales  <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
			THEN sls_quantity *ABS(sls_price)
		ELSE sls_sales
	END AS sls_sales,
	CASE 
		WHEN sls_price IS NULl OR sls_price <= 0
			THEN sls_sales / NULLIF(sls_quantity,0)
		else sls_price
	END AS sls_price
FROM 
	bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price 
	OR sls_sales IS NULL OR sls_quantity IS NULL OR  sls_price IS NULL
	OR sls_sales < 0 OR sls_quantity < 0 OR  sls_price < 0
ORDER BY 
	sls_sales,sls_quantity,sls_price



	--=========================For ERP Sources =============================

-- TABLE erp_cust_az12

-- Check for Invalid cid
-- Expectation: No results

SELECT 
	cid,
	bdate,
	gen
FROM bronze.erp_cust_az12
WHERE cid != TRIM(cid);



-- Check for Invalid bdate
-- Expectation: No results
SELECT 
	cid,
	bdate,
	gen
FROM bronze.erp_cust_az12
WHERE bdate < '1924-01-01' 
OR bdate >= GETDATE()
GO
-- Check for Invalid gen	
-- Expectation: 



SELECT DISTINCT
    gen,
    CASE 
        WHEN UPPER(REPLACE(gen, CHAR(13), '')) IN ('F','FEMALE') THEN 'Female'
        WHEN UPPER(REPLACE(gen, CHAR(13), '')) IN ('M','MALE') THEN 'Male'
        ELSE 'n/a'
    END AS genn
FROM bronze.erp_cust_az12;



SELECT DISTINCT gen 
FROM silver.erp_cust_az12




-- TABLE erp_loc_a101
SELECT * 
FROM bronze.erp_loc_a101 


-- Check for Invalid cid 	
SELECT * 
FROM bronze.erp_loc_a101 
WHERE cid != TRIM(cid)

SELECT 
	REPLACE(cid,'-','') AS cid ,
	cntry
FROM bronze.erp_loc_a101 



-- Data Standarization and Consistency

SELECT DISTINCT
	cntry AS old_cntry,
	CASE 
		WHEN TRIM(REPLACE(cntry, CHAR(13), '')) = 'DE' THEN 'Germany'
		WHEN TRIM(REPLACE(cntry, CHAR(13), '')) IN('US','USA') THEN 'United States'
		WHEN TRIM(REPLACE(cntry, CHAR(13), '')) = '' OR cntry IS NULL THEN 'n/a'
		ELSE TRIM(REPLACE(cntry, CHAR(13), ''))
	END AS cntry
FROM bronze.erp_loc_a101


SELECT DISTINCT cntry 
FROM bronze.erp_loc_a101 

--==========================================================================


-- TABLE erp_px_cat_g1v2


-- Check for Unwanted cat, subcat and maintenance
SELECT 
	*
FROM bronze.erp_px_cat_g1v2
WHERE cat != TRIM(cat) 
OR subcat != TRIM(subcat)
OR maintenance != TRIM(maintenance)



-- Data Standarization and Consistency
SELECT  DISTINCT cat
FROM bronze.erp_px_cat_g1v2

SELECT  DISTINCT subcat
FROM bronze.erp_px_cat_g1v2


SELECT  DISTINCT TRIM(REPLACE(maintenance, CHAR(13), ''))
FROM bronze.erp_px_cat_g1v2