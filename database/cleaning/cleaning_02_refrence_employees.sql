USE HR_Analytics_DB;
GO
SET NOCOUNT ON;
DECLARE @DataEnd DATE = '2025-12-31';          -- last day covered by the dataset

DELETE FROM stg.CleaningLog  WHERE table_name IN ('Departments','JobRoles','Employees');
DELETE FROM stg.RejectedRows WHERE table_name IN ('Departments','JobRoles','Employees');
DROP TABLE IF EXISTS clean.Employees, clean.JobRoles, clean.Departments;

/* ---- Reference tables: typed and trimmed (profiled clean on Day 5) ---- */
SELECT CAST(department_id AS INT)            AS department_id,
       LTRIM(RTRIM(department_name))         AS department_name,
       NULLIF(LTRIM(RTRIM(location)), '')    AS location
INTO clean.Departments FROM stg.Departments;

SELECT CAST(job_role_id AS INT)    AS job_role_id,
       LTRIM(RTRIM(job_title))     AS job_title,
       CAST(department_id AS INT)  AS department_id,
       LTRIM(RTRIM(job_level))     AS job_level,
       CAST(min_salary AS DECIMAL(12,2)) AS min_salary,
       CAST(max_salary AS DECIMAL(12,2)) AS max_salary
INTO clean.JobRoles FROM stg.JobRoles;

/* ---- 1. Employees: de-duplicate + standardize + convert types ---- */
WITH ranked AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY stg_row_id) AS rn
    FROM stg.Employees
)
SELECT
    stg_row_id,
    CAST(employee_id AS INT) AS employee_id,
    UPPER(LEFT(LTRIM(RTRIM(first_name)), 1)) + LOWER(SUBSTRING(LTRIM(RTRIM(first_name)), 2, 100)) AS first_name,
    UPPER(LEFT(LTRIM(RTRIM(last_name)), 1))  + LOWER(SUBSTRING(LTRIM(RTRIM(last_name)), 2, 100))  AS last_name,
    CASE UPPER(LEFT(LTRIM(gender), 1))
         WHEN 'M' THEN 'Male' WHEN 'F' THEN 'Female' WHEN 'O' THEN 'Other' END AS gender,
    COALESCE(TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(date_of_birth)), ''), 23),
             TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(date_of_birth)), ''), 103)) AS date_of_birth,
    COALESCE(TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(hire_date)), ''), 23),
             TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(hire_date)), ''), 105))     AS hire_date,
    LOWER(NULLIF(LTRIM(RTRIM(email)), ''))                   AS email,
    NULLIF(LTRIM(RTRIM(city)), '')                           AS city,
    TRY_CAST(NULLIF(LTRIM(RTRIM(department_id)), '') AS INT) AS department_id,
    TRY_CAST(NULLIF(LTRIM(RTRIM(job_role_id)),  '') AS INT)  AS job_role_id,
    TRY_CAST(NULLIF(LTRIM(RTRIM(manager_id)),   '') AS INT)  AS manager_id
INTO clean.Employees
FROM ranked
WHERE rn = 1;
DECLARE @kept INT = @@ROWCOUNT;

INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Employees', 'Exact duplicate rows (same employee_id)', 'REMOVED',
        (SELECT COUNT(*) FROM stg.Employees) - @kept);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Employees', 'Names/gender/e-mail case, spaces and 2 date formats standardized (all rows)', 'FIXED', @kept);

/* ---- 2. Impossible hire date -> first salary date (derived) ---- */
UPDATE e SET hire_date = s.first_salary_date
FROM clean.Employees e
JOIN (SELECT TRY_CAST(employee_id AS INT) AS employee_id,
             MIN(TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(effective_date)), ''), 23)) AS first_salary_date
      FROM stg.SalaryHistory
      GROUP BY TRY_CAST(employee_id AS INT)) s ON s.employee_id = e.employee_id
WHERE e.hire_date > @DataEnd OR e.hire_date IS NULL;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Employees', 'hire_date after dataset end: replaced with first salary record date', 'FIXED', @@ROWCOUNT);

/* ---- 3. Under 18 at hire -> true DOB unknown, set NULL (column becomes nullable) ---- */
UPDATE clean.Employees SET date_of_birth = NULL
WHERE date_of_birth IS NOT NULL AND DATEADD(YEAR, 18, date_of_birth) > hire_date;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Employees', 'Under 18 at hire: date_of_birth set to NULL (true value unknown)', 'FIXED', @@ROWCOUNT);

/* ---- 4. Department that does not exist -> department of the job role ---- */
UPDATE e SET department_id = r.department_id
FROM clean.Employees e
JOIN clean.JobRoles r ON r.job_role_id = e.job_role_id
WHERE e.department_id IS NULL
   OR NOT EXISTS (SELECT 1 FROM clean.Departments d WHERE d.department_id = e.department_id);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Employees', 'Unknown department_id: taken from the job role''s department', 'FIXED', @@ROWCOUNT);

/* ---- 5. Manager that does not exist -> manager of the employee's department ---- */
UPDATE e SET manager_id = m.employee_id
FROM clean.Employees e
JOIN clean.Employees m  ON m.department_id = e.department_id
JOIN clean.JobRoles  jr ON jr.job_role_id = m.job_role_id AND jr.job_level = 'Manager'
WHERE e.manager_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM clean.Employees x WHERE x.employee_id = e.manager_id);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Employees', 'Unknown manager_id: replaced by the department manager', 'FIXED', @@ROWCOUNT);

/* ---- 6. E-mail: blank, then duplicates across different employees ---- */
UPDATE clean.Employees
SET email = LOWER(first_name) + '.' + LOWER(last_name) + '.' + CAST(employee_id AS VARCHAR(10)) + '@company.com'
WHERE email IS NULL;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Employees', 'Blank e-mail: rebuilt as first.last.<id>@company.com', 'FIXED', @@ROWCOUNT);

;WITH d AS (
    SELECT employee_id, ROW_NUMBER() OVER (PARTITION BY email ORDER BY employee_id) AS rn
    FROM clean.Employees)
UPDATE e
SET email = LOWER(e.first_name) + '.' + LOWER(e.last_name) + '.' + CAST(e.employee_id AS VARCHAR(10)) + '@company.com'
FROM clean.Employees e JOIN d ON d.employee_id = e.employee_id
WHERE d.rn > 1;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Employees', 'E-mail shared by two employees: later employee_id rebuilt', 'FIXED', @@ROWCOUNT);

/* ---- 7. Optional column left as NULL ---- */
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
SELECT 'Employees', 'Blank city left as NULL (column is optional)', 'KEPT', COUNT(*)
FROM clean.Employees WHERE city IS NULL;

/* ---- 8. Safety net: anything still unusable is quarantined ---- */
DELETE e
OUTPUT 'Employees', deleted.stg_row_id, 'No usable hire_date, job_role_id or department_id',
       CAST(deleted.employee_id AS VARCHAR(100)), NULL
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.Employees e
WHERE e.hire_date IS NULL OR e.job_role_id IS NULL OR e.department_id IS NULL
   OR NOT EXISTS (SELECT 1 FROM clean.JobRoles r WHERE r.job_role_id = e.job_role_id);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Employees', 'Unusable employee rows (safety net)', 'REJECTED', @@ROWCOUNT);