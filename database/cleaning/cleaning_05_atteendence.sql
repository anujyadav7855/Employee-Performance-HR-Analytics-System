USE HR_Analytics_DB;
GO
SET NOCOUNT ON;

DELETE FROM stg.CleaningLog  WHERE table_name = 'Attendance';
DELETE FROM stg.RejectedRows WHERE table_name = 'Attendance';
DROP TABLE IF EXISTS clean.Attendance;

SELECT stg_row_id,
       TRY_CAST(NULLIF(LTRIM(RTRIM(employee_id)), '') AS INT)            AS employee_id,
       TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(attendance_date)), ''), 23)  AS attendance_date,
       CASE UPPER(LEFT(LTRIM(status), 1))
            WHEN 'P' THEN 'Present' WHEN 'A' THEN 'Absent'
            WHEN 'L' THEN 'Leave'   WHEN 'H' THEN 'Half-Day' END         AS status,
       TRY_CONVERT(time(0), NULLIF(LTRIM(RTRIM(check_in_time)),  ''))    AS check_in_time,
       TRY_CONVERT(time(0), NULLIF(LTRIM(RTRIM(check_out_time)), ''))    AS check_out_time
INTO clean.Attendance
FROM stg.Attendance;

CREATE INDEX IX_clean_Attendance ON clean.Attendance (employee_id, attendance_date);   -- speeds up the checks below

/* Quarantine */
DELETE a
OUTPUT 'Attendance', deleted.stg_row_id, 'Unreadable employee_id, date or status',
       CAST(deleted.employee_id AS VARCHAR(100)), NULL
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.Attendance a
WHERE a.employee_id IS NULL OR a.attendance_date IS NULL OR a.status IS NULL;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Attendance', 'Blank/unreadable date, employee_id or status', 'REJECTED', @@ROWCOUNT);

DELETE a
OUTPUT 'Attendance', deleted.stg_row_id, 'employee_id not in Employees',
       CAST(deleted.employee_id AS VARCHAR(100)), NULL
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.Attendance a
WHERE NOT EXISTS (SELECT 1 FROM clean.Employees e WHERE e.employee_id = a.employee_id);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Attendance', 'Orphan employee_id', 'REJECTED', @@ROWCOUNT);

-- 1900-01-01 was a Monday, so days-since % 7 = 5 (Sat) or 6 (Sun). Works in any language setting.
DELETE a
OUTPUT 'Attendance', deleted.stg_row_id, 'Saturday/Sunday record (company works Mon-Fri)',
       CAST(deleted.employee_id AS VARCHAR(100)), CONVERT(VARCHAR(10), deleted.attendance_date, 23)
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.Attendance a
WHERE DATEDIFF(DAY, '19000101', a.attendance_date) % 7 IN (5, 6);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Attendance', 'Weekend records', 'REJECTED', @@ROWCOUNT);

DELETE a
OUTPUT 'Attendance', deleted.stg_row_id, 'Dated after the employee''s exit date',
       CAST(deleted.employee_id AS VARCHAR(100)), CONVERT(VARCHAR(10), deleted.attendance_date, 23)
INTO stg.RejectedRows (table_name, stg_row_id, reason, employee_id, raw_value)
FROM clean.Attendance a
JOIN clean.Exits x ON x.employee_id = a.employee_id
WHERE a.attendance_date > x.exit_date;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Attendance', 'Records after exit date', 'REJECTED', @@ROWCOUNT);

/* Duplicates: keep the first (employee_id, attendance_date) */
;WITH d AS (SELECT ROW_NUMBER() OVER (PARTITION BY employee_id, attendance_date ORDER BY stg_row_id) AS rn
            FROM clean.Attendance)
DELETE FROM d WHERE rn > 1;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Attendance', 'Duplicate (employee_id, attendance_date)', 'REMOVED', @@ROWCOUNT);

/* Fixes */
UPDATE clean.Attendance
SET check_in_time = check_out_time, check_out_time = check_in_time   -- right side uses the OLD values: a swap
WHERE check_out_time < check_in_time;
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Attendance', 'check_out before check_in: times swapped', 'FIXED', @@ROWCOUNT);

UPDATE clean.Attendance SET check_in_time = NULL, check_out_time = NULL
WHERE status IN ('Absent', 'Leave') AND (check_in_time IS NOT NULL OR check_out_time IS NOT NULL);
INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
VALUES ('Attendance', 'Absent/Leave with punch times: status trusted, times cleared', 'FIXED', @@ROWCOUNT);

INSERT INTO stg.CleaningLog (table_name, issue, action_taken, rows_affected)
SELECT 'Attendance', 'Present/Half-Day without punch times (kept; times are optional)', 'KEPT', COUNT(*)
FROM clean.Attendance WHERE status IN ('Present', 'Half-Day') AND check_in_time IS NULL;