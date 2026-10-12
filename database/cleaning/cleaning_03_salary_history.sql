USE HR_Analytics_DB;
GO
SET NOCOUNT ON;

DELETE FROM stg.CleaningLog  WHERE table_name = 'SalaryHistory';
DELETE FROM stg.RejectedRows WHERE table_name = 'SalaryHistory';
DROP TABLE IF EXISTS clean.SalaryHistory;

/* 1. Typed copy: 'INR 650000' / '1,00,000' -> number */
SELECT stg_row_id,
       TRY_CAST(NULLIF(LTRIM(RTRIM(employee_id)), '') AS INT)                  AS employee_id,
       TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(effective_date)), ''), 23)         AS effective_date,
       TRY_CAST(NULLIF(LTRIM(RTRIM(REPLACE(REPLACE(base_salary, 'INR', ''), ',', ''))), '')
                AS DECIMAL(12,2))                                              AS base_salary,
       NULLIF(LTRIM(RTRIM(change_reason)), '')                                 AS change_reason
INTO clean.SalaryHistory
FROM stg.SalaryHistory;

/* 2. Quarantine what cannot be trusted */
DELETE s
OUTPUT 'SalaryHistory', deleted.stg_row_id, 'Unreadable employee_id, date or salary',
       CAST(deleted.employee_id AS VARCHAR(100)), CAST(deleted.base_salary AS VARCHAR(300))
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.SalaryHistory s
WHERE s.employee_id IS NULL OR s.effective_date IS NULL OR s.base_salary IS NULL;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('SalaryHistory', 'Unreadable employee_id, date or salary', 'REJECTED', @@ROWCOUNT);

DELETE s
OUTPUT 'SalaryHistory', deleted.stg_row_id, 'employee_id not in Employees',
       CAST(deleted.employee_id AS VARCHAR(100)), CAST(deleted.base_salary AS VARCHAR(300))
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.SalaryHistory s
WHERE NOT EXISTS (SELECT 1 FROM clean.Employees e WHERE e.employee_id = s.employee_id);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('SalaryHistory', 'Orphan employee_id', 'REJECTED', @@ROWCOUNT);

DELETE s
OUTPUT 'SalaryHistory', deleted.stg_row_id, 'Zero salary (true value unknown)',
       CAST(deleted.employee_id AS VARCHAR(100)), CAST(deleted.base_salary AS VARCHAR(300))
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.SalaryHistory s
WHERE s.base_salary = 0;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('SalaryHistory', 'Zero salary', 'REJECTED', @@ROWCOUNT);

/* 3. Negative salary = sign typo (the magnitude is plausible) */
UPDATE clean.SalaryHistory SET base_salary = ABS(base_salary) WHERE base_salary < 0;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('SalaryHistory', 'Negative salary: sign removed', 'FIXED', @@ROWCOUNT);

/* 4. Outlier: above every band in the department, but /10 lands inside the bands = extra zero */
UPDATE s SET base_salary = s.base_salary / 10
FROM clean.SalaryHistory s
JOIN clean.Employees e ON e.employee_id = s.employee_id
CROSS APPLY (SELECT MIN(r.min_salary) AS lo, MAX(r.max_salary) AS hi
             FROM clean.JobRoles r WHERE r.department_id = e.department_id) b
WHERE s.base_salary > b.hi AND s.base_salary / 10 BETWEEN b.lo * 0.5 AND b.hi;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('SalaryHistory', 'Salary 10x too large (extra zero): divided by 10', 'FIXED', @@ROWCOUNT);

DELETE s
OUTPUT 'SalaryHistory', deleted.stg_row_id, 'Salary above all bands and not a x10 typo',
       CAST(deleted.employee_id AS VARCHAR(100)), CAST(deleted.base_salary AS VARCHAR(300))
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.SalaryHistory s
JOIN clean.Employees e ON e.employee_id = s.employee_id
WHERE s.base_salary > (SELECT MAX(r.max_salary) FROM clean.JobRoles r WHERE r.department_id = e.department_id);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('SalaryHistory', 'Remaining unexplained outliers', 'REJECTED', @@ROWCOUNT);

/* 5. Duplicates on (employee_id, effective_date): keep the first */
;WITH d AS (
    SELECT ROW_NUMBER() OVER (PARTITION BY employee_id, effective_date ORDER BY stg_row_id) AS rn
    FROM clean.SalaryHistory)
DELETE FROM d WHERE rn > 1;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('SalaryHistory', 'Duplicate (employee_id, effective_date)', 'REMOVED', @@ROWCOUNT);

/* 6. Standardize change_reason, then infer the blanks */
UPDATE clean.SalaryHistory
SET change_reason = CASE WHEN LOWER(change_reason) LIKE 'hire%'      THEN 'Hire'
                         WHEN LOWER(change_reason) LIKE 'annual%'    THEN 'Annual Increment'
                         WHEN LOWER(change_reason) LIKE 'promotion%' THEN 'Promotion'
                         WHEN LOWER(change_reason) LIKE 'adjust%'    THEN 'Adjustment' END
WHERE change_reason IS NOT NULL;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('SalaryHistory', 'change_reason spelling/case standardized', 'FIXED', @@ROWCOUNT);

UPDATE s
SET change_reason =
    CASE WHEN s.effective_date = (SELECT MIN(x.effective_date) FROM clean.SalaryHistory x
                                  WHERE x.employee_id = s.employee_id)           THEN 'Hire'
         WHEN EXISTS (SELECT 1 FROM stg.Promotions p
                      WHERE TRY_CAST(p.employee_id AS INT) = s.employee_id
                        AND TRY_CONVERT(date, p.promotion_date, 23) = s.effective_date) THEN 'Promotion'
         WHEN s.effective_date = '2022-01-01'                                     THEN 'Adjustment'  -- opening balance
         ELSE 'Annual Increment' END
FROM clean.SalaryHistory s
WHERE s.change_reason IS NULL;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('SalaryHistory', 'Blank change_reason inferred from position/promotion dates', 'FIXED', @@ROWCOUNT);