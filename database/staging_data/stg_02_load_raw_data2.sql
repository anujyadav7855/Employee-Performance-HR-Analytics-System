/* =====================================================
   File    : database/staging/stg_02_load_raw_data.sql
   Purpose : Reusable loader: CSV -> stg.* tables (safe to re-run)
   Needs   : stg_01_create_staging.sql ek baar chal chuki ho
   ===================================================== */
USE HR_Analytics_DB;
GO
SET NOCOUNT ON;

/* ========== CONFIG: sirf yahan change karo ========== */
DECLARE @DataPath    NVARCHAR(260) = N'D:\Employee Performance & HR Analytics System\DATA\RAW\';  -- end me '\' zaroori
DECLARE @UseCsvFormat BIT          = 1;  -- 1 = SQL Server 2017+, 0 = purana version
/* ==================================================== */

-- Kaunsi file kis table me jayegi (expected_rows = reconciliation ke liye; NULL = skip)
DECLARE @Files TABLE (
    id INT IDENTITY(1,1), table_name SYSNAME, file_name NVARCHAR(100),
    add_row_id BIT, expected_rows INT);

INSERT INTO @Files (table_name, file_name, add_row_id, expected_rows) VALUES
(N'Departments',        N'departments.csv',         0,      7),
(N'JobRoles',           N'job_roles.csv',           0,     37),
(N'Employees',          N'employees.csv',           1,    406),
(N'SalaryHistory',      N'salary_history.csv',      1,   1786),
(N'Attendance',         N'attendance.csv',          1, 296960),
(N'PerformanceReviews', N'performance_reviews.csv', 1,   2234),
(N'Promotions',         N'promotions.csv',          1,    137),
(N'Exits',              N'exits.csv',               1,    116);

CREATE TABLE #recon (
    table_name SYSNAME, loaded_rows INT, expected_rows INT, status VARCHAR(10));

DECLARE @opts NVARCHAR(300) =
    CASE WHEN @UseCsvFormat = 1
         THEN N'FORMAT = ''CSV'', FIRSTROW = 2, CODEPAGE = ''65001'', TABLOCK'
         ELSE N'FIELDTERMINATOR = '','', ROWTERMINATOR = ''\n'', FIRSTROW = 2, CODEPAGE = ''65001'', TABLOCK'
    END;

DECLARE @i INT = 1, @n INT = (SELECT COUNT(*) FROM @Files);
DECLARE @tbl SYSNAME, @file NVARCHAR(100), @addid BIT, @exp INT;
DECLARE @full NVARCHAR(300), @sql NVARCHAR(MAX), @cnt INT;

WHILE @i <= @n
BEGIN
    SELECT @tbl = table_name, @file = file_name, @addid = add_row_id, @exp = expected_rows
    FROM @Files WHERE id = @i;

    SET @full = N'stg.' + QUOTENAME(@tbl);

    BEGIN TRY
        -- 1. Purana stg_row_id hatao (warna BULK INSERT ka column count match nahi karega)
        IF COL_LENGTH('stg.' + @tbl, 'stg_row_id') IS NOT NULL
            EXEC(N'ALTER TABLE ' + @full + N' DROP COLUMN stg_row_id');

        -- 2. Table khaali karo (double loading se bachne ke liye)
        EXEC(N'TRUNCATE TABLE ' + @full);

        -- 3. Load (BULK INSERT file name variable nahi leta, isliye dynamic SQL)
        SET @sql = N'BULK INSERT ' + @full
                 + N' FROM ''' + REPLACE(@DataPath + @file, '''', '''''') + N''''
                 + N' WITH (' + @opts + N');';
        EXEC sp_executesql @sql;

        -- 4. Unique row id wapas lagao (Day 6 me de-duplication ke kaam aayega)
        IF @addid = 1
            EXEC(N'ALTER TABLE ' + @full + N' ADD stg_row_id INT IDENTITY(1,1)');

        -- 5. Rows count karo
        SET @sql = N'SELECT @c = COUNT(*) FROM ' + @full;
        EXEC sp_executesql @sql, N'@c INT OUTPUT', @c = @cnt OUTPUT;

        INSERT INTO #recon
        VALUES (@tbl, @cnt, @exp,
                CASE WHEN @exp IS NULL THEN 'N/A'
                     WHEN @cnt = @exp  THEN 'OK' ELSE 'MISMATCH' END);

        PRINT 'Loaded  : ' + @tbl + ' (' + CAST(@cnt AS VARCHAR(12)) + ' rows)';
    END TRY
    BEGIN CATCH
        INSERT INTO #recon VALUES (@tbl, NULL, @exp, 'FAILED');
        PRINT 'FAILED  : ' + @tbl + ' -> ' + ERROR_MESSAGE();
    END CATCH;

    SET @i += 1;
END;

-- Final reconciliation report
SELECT table_name, loaded_rows, expected_rows, status FROM #recon ORDER BY table_name;

DROP TABLE #recon;
GO