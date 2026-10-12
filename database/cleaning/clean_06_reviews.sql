USE HR_Analytics_DB;
GO
SET NOCOUNT ON;

DELETE FROM stg.CleaningLog  WHERE table_name = 'PerformanceReviews';
DELETE FROM stg.RejectedRows WHERE table_name = 'PerformanceReviews';
DROP TABLE IF EXISTS clean.PerformanceReviews;

SELECT stg_row_id,
       TRY_CAST(NULLIF(LTRIM(RTRIM(employee_id)), '') AS INT) AS employee_id,
       TRY_CAST(NULLIF(LTRIM(RTRIM(reviewer_id)), '') AS INT) AS reviewer_id,
       -- '2024 H1', '2024-h1', 'H1-2024', '2024-H1'  ->  '2024-H1'
       CASE WHEN PATINDEX('%[0-9][0-9][0-9][0-9]%', review_period) > 0
             AND PATINDEX('%[Hh][12]%', review_period) > 0
            THEN SUBSTRING(review_period, PATINDEX('%[0-9][0-9][0-9][0-9]%', review_period), 4)
                 + '-H' + SUBSTRING(review_period, PATINDEX('%[Hh][12]%', review_period) + 1, 1)
       END AS review_period,
       TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(review_date)), ''), 23) AS review_date,
       TRY_CAST(NULLIF(LTRIM(RTRIM(rating)), '') AS TINYINT)        AS rating,
       rating AS raw_rating
INTO clean.PerformanceReviews
FROM stg.PerformanceReviews;

INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
SELECT 'PerformanceReviews', 'review_period variants converted to YYYY-H1/H2 (all rows processed)', 'FIXED', COUNT(*)
FROM clean.PerformanceReviews;

/* Quarantine */
DELETE r
OUTPUT 'PerformanceReviews', deleted.stg_row_id, 'Rating missing, non-numeric or outside 1-5',
       CAST(deleted.employee_id AS VARCHAR(100)), CAST(deleted.raw_rating AS VARCHAR(300))
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.PerformanceReviews r
WHERE r.rating IS NULL OR r.rating NOT BETWEEN 1 AND 5;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('PerformanceReviews', 'Invalid rating (not imputed)', 'REJECTED', @@ROWCOUNT);

DELETE r
OUTPUT 'PerformanceReviews', deleted.stg_row_id, 'Unknown employee or unreadable period/date',
       CAST(deleted.employee_id AS VARCHAR(100)), NULL
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.PerformanceReviews r
WHERE r.review_period IS NULL OR r.review_date IS NULL
   OR NOT EXISTS (SELECT 1 FROM clean.Employees e WHERE e.employee_id = r.employee_id);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('PerformanceReviews', 'Unknown employee or unreadable period/date', 'REJECTED', @@ROWCOUNT);

DELETE r
OUTPUT 'PerformanceReviews', deleted.stg_row_id, 'Review dated after the employee''s exit',
       CAST(deleted.employee_id AS VARCHAR(100)), CONVERT(VARCHAR(10), deleted.review_date, 23)
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.PerformanceReviews r
JOIN clean.Exits x ON x.employee_id = r.employee_id
WHERE r.review_date > x.exit_date;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('PerformanceReviews', 'Review after exit date', 'REJECTED', @@ROWCOUNT);

/* Duplicates on (employee_id, review_period) */
;WITH d AS (SELECT ROW_NUMBER() OVER (PARTITION BY employee_id, review_period ORDER BY stg_row_id) AS rn
            FROM clean.PerformanceReviews)
DELETE FROM d WHERE rn > 1;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('PerformanceReviews', 'Duplicate (employee_id, review_period)', 'REMOVED', @@ROWCOUNT);

/* Blank / self / unknown reviewer -> the employee's department manager */
UPDATE r SET reviewer_id = m.employee_id
FROM clean.PerformanceReviews r
JOIN clean.Employees e  ON e.employee_id = r.employee_id
JOIN clean.Employees m  ON m.department_id = e.department_id
JOIN clean.JobRoles  jr ON jr.job_role_id = m.job_role_id AND jr.job_level = 'Manager'
WHERE r.reviewer_id IS NULL OR r.reviewer_id = r.employee_id
   OR NOT EXISTS (SELECT 1 FROM clean.Employees x WHERE x.employee_id = r.reviewer_id);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('PerformanceReviews', 'Blank/self/unknown reviewer replaced by department manager', 'FIXED', @@ROWCOUNT);