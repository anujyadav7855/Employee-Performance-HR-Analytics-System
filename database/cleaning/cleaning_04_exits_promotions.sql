USE HR_Analytics_DB;
GO
SET NOCOUNT ON;

DELETE FROM stg.CleaningLog  WHERE table_name IN ('Exits','Promotions');
DELETE FROM stg.RejectedRows WHERE table_name IN ('Exits','Promotions');
DROP TABLE IF EXISTS clean.Exits, clean.Promotions;

/* ================= EXITS ================= */
SELECT stg_row_id,
       TRY_CAST(NULLIF(LTRIM(RTRIM(employee_id)), '') AS INT) AS employee_id,
       COALESCE(TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(exit_date)), ''), 23),
                TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(exit_date)), ''), 103)) AS exit_date,
       CASE WHEN LOWER(LTRIM(exit_type)) LIKE 'resign%'   THEN 'Resignation'
            WHEN LOWER(LTRIM(exit_type)) LIKE 'terminat%' THEN 'Termination'
            WHEN LOWER(LTRIM(exit_type)) LIKE 'retire%'   THEN 'Retirement' END AS exit_type,
       CASE WHEN UPPER(LTRIM(RTRIM(exit_reason))) IN ('', 'N/A') THEN NULL
            ELSE LTRIM(RTRIM(exit_reason)) END AS exit_reason
INTO clean.Exits
FROM stg.Exits;

;WITH d AS (SELECT ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY stg_row_id) AS rn FROM clean.Exits)
DELETE FROM d WHERE rn > 1;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Exits', 'Duplicate exit rows (one exit per employee)', 'REMOVED', @@ROWCOUNT);

DELETE x
OUTPUT 'Exits', deleted.stg_row_id, 'employee_id not in Employees',
       CAST(deleted.employee_id AS VARCHAR(100)), NULL
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.Exits x
WHERE NOT EXISTS (SELECT 1 FROM clean.Employees e WHERE e.employee_id = x.employee_id);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Exits', 'Orphan employee_id', 'REJECTED', @@ROWCOUNT);

-- Exit on/before hire date: the true exit date is unknown -> quarantine for HR to confirm
DELETE x
OUTPUT 'Exits', deleted.stg_row_id, 'Exit date on/before hire date or unreadable (needs HR confirmation)',
       CAST(deleted.employee_id AS VARCHAR(100)),
       CONCAT(CONVERT(VARCHAR(10), deleted.exit_date, 23), ' | ', deleted.exit_type)
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.Exits x
JOIN clean.Employees e ON e.employee_id = x.employee_id
WHERE x.exit_date IS NULL OR x.exit_type IS NULL OR x.exit_date <= e.hire_date;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Exits', 'Exit date on/before hire date or unreadable', 'REJECTED', @@ROWCOUNT);

INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
SELECT 'Exits', 'Blank or N/A exit_reason left as NULL (optional)', 'KEPT', COUNT(*)
FROM clean.Exits WHERE exit_reason IS NULL;

/* ================= PROMOTIONS ================= */
SELECT stg_row_id,
       TRY_CAST(NULLIF(LTRIM(RTRIM(employee_id)), '') AS INT)      AS employee_id,
       TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(promotion_date)), ''), 23) AS promotion_date,
       TRY_CAST(NULLIF(LTRIM(RTRIM(old_job_role_id)), '') AS INT)  AS old_job_role_id,
       TRY_CAST(NULLIF(LTRIM(RTRIM(new_job_role_id)), '') AS INT)  AS new_job_role_id
INTO clean.Promotions
FROM stg.Promotions;

;WITH d AS (
    SELECT ROW_NUMBER() OVER (PARTITION BY employee_id, promotion_date, old_job_role_id, new_job_role_id
                              ORDER BY stg_row_id) AS rn
    FROM clean.Promotions)
DELETE FROM d WHERE rn > 1;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Promotions', 'Exact duplicate rows', 'REMOVED', @@ROWCOUNT);

DELETE p
OUTPUT 'Promotions', deleted.stg_row_id, 'employee_id not in Employees',
       CAST(deleted.employee_id AS VARCHAR(100)), NULL
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.Promotions p
WHERE NOT EXISTS (SELECT 1 FROM clean.Employees e WHERE e.employee_id = p.employee_id);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Promotions', 'Orphan employee_id', 'REJECTED', @@ROWCOUNT);

-- Promotion dated on/before hire: take the date of the employee's unmatched 'Promotion' salary record
UPDATE p SET promotion_date = s.effective_date
FROM clean.Promotions p
JOIN clean.Employees e ON e.employee_id = p.employee_id
CROSS APPLY (SELECT TOP 1 sh.effective_date
             FROM clean.SalaryHistory sh
             WHERE sh.employee_id = p.employee_id AND sh.change_reason = 'Promotion'
               AND NOT EXISTS (SELECT 1 FROM clean.Promotions p2
                               WHERE p2.employee_id = p.employee_id
                                 AND p2.promotion_date = sh.effective_date)
             ORDER BY sh.effective_date) s
WHERE p.promotion_date <= e.hire_date;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Promotions', 'Promotion dated before hire: date taken from salary record', 'FIXED', @@ROWCOUNT);

DELETE p
OUTPUT 'Promotions', deleted.stg_row_id,
       CASE WHEN deleted.old_job_role_id = deleted.new_job_role_id THEN 'Old role equals new role'
            ELSE 'Invalid date or unknown job role' END,
       CAST(deleted.employee_id AS VARCHAR(100)), NULL
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.Promotions p
JOIN clean.Employees e ON e.employee_id = p.employee_id
WHERE p.old_job_role_id = p.new_job_role_id
   OR p.promotion_date IS NULL OR p.promotion_date <= e.hire_date
   OR NOT EXISTS (SELECT 1 FROM clean.JobRoles r WHERE r.job_role_id = p.old_job_role_id)
   OR NOT EXISTS (SELECT 1 FROM clean.JobRoles r WHERE r.job_role_id = p.new_job_role_id);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Promotions', 'Invalid promotions (same role, bad date, unknown role)', 'REJECTED', @@ROWCOUNT);