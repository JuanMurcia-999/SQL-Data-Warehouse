
CREATE OR ALTER PROCEDURE silver.load_silver AS

BEGIN
	DECLARE @start_time DATETIME, @end_time DATETIME, @bacth_start_time DATETIME, @bacth_end_time DATETIME;
	BEGIN TRY
	SET @bacth_start_time = GETDATE()
		PRINT '================================================';
		PRINT 'Loading Bronze Layer';
		PRINT '================================================';


		PRINT '------------------------------------------------';
		PRINT 'Loading CRM Tables';
		PRINT '------------------------------------------------';


		-------------------------------------------------------------------------------------
		/* Clean and Load for crm_cust_info */
		SET @start_time = GETDATE();
		PRINT '>> Tuncating Table: silver.crm_cust_info'
		TRUNCATE TABLE silver.crm_cust_info;
		PRINT '>> Inserting Data Into: silver.crm_cust_info '
		INSERT INTO silver.crm_cust_info (
			cst_id,
			cst_key,
			cst_firstname,
			cst_lastname,
			cst_marital_status,
			cst_gndr,
			cst_create_date )

		SELECT  
			cst_id,
			cst_key,
			TRIM(cst_firstname) AS cst_firstname,
			TRIM(cst_lastname) AS cst_lastname,
				CASE UPPER(TRIM(cst_marital_status))
					WHEN 'S' THEN 'Single'
					WHEN 'M' THEN 'Married'
					ELSE 'n/a'
				END cst_marital_status,

				CASE UPPER(TRIM(cst_gndr))
					WHEN 'F' THEN 'Female'
					WHEN 'M' THEN 'Male'
					ELSE 'n/a'
				END cst_gndr,
			cst_create_date
			FROM (

				SELECT *, 
					ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) as flag_last
					FROM bronze.crm_cust_info
					WHERE cst_id IS NOT NULL
			) t 
			WHERE flag_last =1 ;
			SET @end_time = GETDATE();
			PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR)+ ' seconds'
			PRINT '>>-------------'

		-------------------------------------------------------------------------------------
		/* Clean and Load for crm_prd_info */

		SET @start_time = GETDATE();
		PRINT '>> Tuncating Table: silver.crm_prd_info'
		TRUNCATE TABLE silver.crm_prd_info;
		PRINT '>> Inserting Data Into: silver.crm_prd_info'
		INSERT INTO silver.crm_prd_info (
			prd_id,
			cat_id,
			prd_key,
			prd_nm,
			prd_cost,
			prd_line,
			prd_start_dt, 
			prd_end_dt    
		)

		SELECT 
				prd_id,
				REPLACE( SUBSTRING(prd_key,1,5), '-', '_')AS cat_id,  -- Extract category ID
				SUBSTRING(prd_key, 7, LEN(prd_key)) AS prd_key,       -- Extract product key
				prd_nm, 
				ISNULL(prd_cost, 0) as prd_cost,
	
				CASE UPPER(TRIM(prd_line))
					WHEN 'M' THEN 'Mountain'
					WHEN 'R' THEN 'Road'
					WHEN 'S' THEN 'Other Sales'
					WHEN 'T' THEN 'Touring'
				ELSE 'n/a'
				END AS prd_line,  -- Map product line codes to descriptive values
				CAST(prd_start_dt AS DATE) AS prd_start_dt,
				CAST(
					LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) -1 
					AS DATE
				) AS prd_end_dt   -- Calculate end date as one day before the next start date
			FROM bronze.crm_prd_info
			SET @end_time = GETDATE();
			PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR)+ ' seconds'
			PRINT '>>-------------'

		-------------------------------------------------------------------------------------
		/* Clean and Load for crm_sales_details */

		SET @start_time = GETDATE();
		PRINT '>> Tuncating Table: silver.crm_sales_details'
		TRUNCATE TABLE silver.crm_sales_details;
		PRINT '>> Inserting Data Into: silver.crm_sales_details'
		INSERT INTO silver.crm_sales_details (
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,  
			sls_order_dt, 
			sls_ship_dt,  
			sls_due_dt,   
			sls_sales,    
			sls_quantity, 
			sls_price  
		)

		SELECT 
			sls_ord_num,
			sls_prd_key,
			sls_cust_id,

			CASE WHEN sls_order_dt = 0 OR LEN(sls_order_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
			END AS sls_due_dt,

			CASE WHEN sls_ship_dt = 0 OR LEN(sls_ship_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE)
			END AS sls_ship_dt,

			CASE WHEN sls_due_dt = 0 OR LEN(sls_due_dt) != 8 THEN NULL
				 ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE)
			END AS sls_due_dt,

			CASE 
				WHEN sls_sales IS NULL OR sls_sales  <= 0 OR sls_sales != sls_quantity * ABS(sls_price)
					THEN sls_quantity *ABS(sls_price)
				ELSE sls_sales
			END AS sls_sales,
			sls_quantity,
			CASE 
				WHEN sls_price IS NULl OR sls_price <= 0
					THEN sls_sales / NULLIF(sls_quantity,0)
				ELSE sls_price
			END AS sls_price
			FROM bronze.crm_sales_details;
			SET @end_time = GETDATE();
			PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR)+ ' seconds'
			PRINT '>>-------------'


	
			--=========================For ERP Sources =============================

		/* Clean and Load for erp_cust_az12 */

		SET @start_time = GETDATE();
		PRINT '>> Tuncating Table: silver.erp_cust_az12'
		TRUNCATE TABLE silver.erp_cust_az12;
		PRINT '>> Inserting Data Into: silver.erp_cust_az12 '
		INSERT INTO silver.erp_cust_az12 (
			cid,
			bdate,
			gen
		)

		SELECT 
			CASE 
				WHEN cid LIKE 'NAS%'
					THEN SUBSTRING(cid, 4, LEN(cid))
				ELSE cid
			END AS cid,

			CASE 
				WHEN bdate > GETDATE() 
					THEN NULL
				ELSE bdate
			END AS bdate,

			CASE 
				WHEN UPPER(REPLACE(gen, CHAR(13), '')) IN ('F','FEMALE') THEN 'Female'
				WHEN UPPER(REPLACE(gen, CHAR(13), '')) IN ('M','MALE') THEN 'Male'
				ELSE 'n/a'
			END AS gen
		FROM bronze.erp_cust_az12
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR)+ ' seconds'
		PRINT '>>-------------'


		/* Clean and Load for erp_loc_a101 */

		SET @start_time = GETDATE();
		PRINT '>> Tuncating Table: silver.erp_loc_a101'
		TRUNCATE TABLE silver.erp_loc_a101;
		PRINT '>> Inserting Data Into: silver.erp_loc_a101'
		INSERT INTO silver.erp_loc_a101 (
			cid,
			cntry
		)


		SELECT 
			REPLACE(cid,'-','') AS cid ,
			CASE 
				WHEN TRIM(REPLACE(cntry, CHAR(13), '')) = 'DE' THEN 'Germany'
				WHEN TRIM(REPLACE(cntry, CHAR(13), '')) IN('US','USA') THEN 'United States'
				WHEN TRIM(REPLACE(cntry, CHAR(13), '')) = '' OR cntry IS NULL THEN 'n/a'
				ELSE TRIM(REPLACE(cntry, CHAR(13), ''))
			END AS cntry
		FROM bronze.erp_loc_a101 
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR)+ ' seconds'
		PRINT '>>-------------'


		/* Clean and Load for erp_px_cat_g1v2 */

		SET @start_time = GETDATE();
		PRINT '>> Tuncating Table: silver.erp_px_cat_g1v2'
		TRUNCATE TABLE silver.erp_px_cat_g1v2;
		PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2'
		INSERT INTO silver.erp_px_cat_g1v2 (
			id,
			cat,
			subcat,
			maintenance
		)

		SELECT 
			id,
			cat,
			subcat,
			TRIM(REPLACE(maintenance, CHAR(13), '')) AS maintenance
		FROM bronze.erp_px_cat_g1v2
		SET @end_time = GETDATE();
		PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR)+ ' seconds'
		PRINT '>>-------------'
		
		SET @bacth_end_time = GETDATE();
		PRINT '=========================================='
		PRINT 'Loading silver Layer is completed'
		PRINT '		- Total load Duration: ' + CAST(DATEDIFF(second, @bacth_start_time, @bacth_end_time) AS NVARCHAR)+ ' seconds'
		PRINT '=========================================='


	END TRY
	BEGIN CATCH
	PRINT '=========================================='
	PRINT 'ERROR COURRED DURING LOADING SILVER LAYER'
	PRINT 'Error' + ERROR_MESSAGE();
	PRINT 'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR)
	PRINT '=========================================='
	END CATCH
END
