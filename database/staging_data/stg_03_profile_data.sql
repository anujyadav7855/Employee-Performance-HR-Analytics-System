USE HR_Analytics_DB;
GO

/* ---------- A. Blank / NULL counts (Employees) ---------- */
SELECT
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(city)),  '') IS NULL THEN 1 ELSE 0 END) AS blank_city,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(email)), '') IS NULL THEN 1 ELSE 0 END) AS blank_email,
    SUM(CASE WHEN NULLIF(LTRIM(RTRIM(gender)),'') IS NULL THEN 1 ELSE 0 END) AS blank_gender
FROM stg.Employees;                                  -- expect city 10, email 3

/* ---------- B. Duplicates ---------- */
-- B1. Same employee_id more than once
SELECT employee_id, COUNT(*) AS copies
FROM stg.Employees
GROUP BY employee_id
HAVING COUNT(*) > 1;                                 -- expect 6 ids

-- B2. Same e-mail used by DIFFERENT employees (ignores the duplicated rows above)
SELECT LOWER(LTRIM(RTRIM(email))) AS email_clean,
       COUNT(DISTINCT employee_id) AS different_employees
FROM stg.Employees
WHERE NULLIF(LTRIM(RTRIM(email)), '') IS NOT NULL
GROUP BY LOWER(LTRIM(RTRIM(email)))
HAVING COUNT(DISTINCT employee_id) > 1;              -- expect 2 pairs

-- B3. Duplicate attendance (same employee + same date)
SELECT employee_id, attendance_date, COUNT(*) AS copies
FROM stg.Attendance
GROUP BY employee_id, attendance_date
HAVING COUNT(*) > 1;                                 -- expect about 150 groups

/* ---------- C. Distinct values (spot inconsistent labels) ---------- */
SELECT gender, COUNT(*) AS n FROM stg.Employees GROUP BY gender ORDER BY n DESC;
SELECT status, COUNT(*) AS n FROM stg.Attendance GROUP BY status ORDER BY n DESC;
SELECT exit_type, COUNT(*) AS n FROM stg.Exits GROUP BY exit_type ORDER BY n DESC;
SELECT change_reason, COUNT(*) AS n FROM stg.SalaryHistory GROUP BY change_reason ORDER BY n DESC;
SELECT rating, COUNT(*) AS n FROM stg.PerformanceReviews GROUP BY rating ORDER BY rating;

/* ---------- D. Format / data-type checks ---------- */
-- D1. Dates that are not yyyy-mm-dd (style 23); blanks are flagged too
SELECT employee_id, hire_date
FROM stg.Employees
WHERE TRY_CONVERT(date, NULLIF(LTRIM(RTRIM(hire_date)), ''), 23) IS NULL;
                                                     -- expect 12 (DD-MM-YYYY); also check date_of_birth

-- D2. Salaries that are not plain numbers
SELECT employee_id, base_salary
FROM stg.SalaryHistory
WHERE TRY_CAST(NULLIF(LTRIM(RTRIM(base_salary)), '') AS DECIMAL(12,2)) IS NULL;
                                                     -- expect 4 ('INR ...')

-- D3. Ratings that are not whole numbers
SELECT employee_id, review_period, rating
FROM stg.PerformanceReviews
WHERE TRY_CAST(NULLIF(LTRIM(RTRIM(rating)), '') AS INT) IS NULL;
                                                     -- expect 8 (3 blank, 3 'Good', 2 'N/A')

/* ---------- E. Range / business-rule checks ---------- */
SELECT COUNT(*) AS rating_out_of_range
FROM stg.PerformanceReviews
WHERE TRY_CAST(NULLIF(LTRIM(RTRIM(rating)), '') AS INT) NOT BETWEEN 1 AND 5;      -- expect 9

SELECT COUNT(*) AS salary_zero_or_negative
FROM stg.SalaryHistory
WHERE TRY_CAST(NULLIF(LTRIM(RTRIM(base_salary)), '') AS DECIMAL(12,2)) <= 0;      -- expect 6

-- Highest salaries vs the highest salary band in JobRoles (typo outliers sit here)
SELECT TOP 10 employee_id, effective_date, base_salary, change_reason
FROM stg.SalaryHistory
WHERE TRY_CAST(NULLIF(LTRIM(RTRIM(base_salary)), '') AS DECIMAL(12,2)) IS NOT NULL
ORDER BY TRY_CAST(base_salary AS DECIMAL(12,2)) DESC;

-- Attendance on weekends (company works Mon-Fri). Uses English day names.
SELECT COUNT(*) AS weekend_rows
FROM stg.Attendance
WHERE DATENAME(WEEKDAY, TRY_CONVERT(date, NULLIF(attendance_date,''), 23))
      IN ('Saturday', 'Sunday');                     -- expect 38

-- check_out before check_in
SELECT COUNT(*) AS time_reversed
FROM stg.Attendance
WHERE TRY_CONVERT(time, NULLIF(check_out_time,'')) < TRY_CONVERT(time, NULLIF(check_in_time,''));   -- expect 25

-- Status vs. punch times (first letter normalises P / A / L / H spellings)
SELECT COUNT(*) AS present_without_times
FROM stg.Attendance
WHERE UPPER(LEFT(LTRIM(status), 1)) = 'P'
  AND NULLIF(LTRIM(RTRIM(check_in_time)), '') IS NULL;                              -- expect 60

SELECT COUNT(*) AS absent_or_leave_with_times
FROM stg.Attendance
WHERE UPPER(LEFT(LTRIM(status), 1)) IN ('A', 'L')
  AND NULLIF(LTRIM(RTRIM(check_in_time)), '') IS NOT NULL;                          -- expect 30

/* ---------- F. Orphans (child IDs with no parent) ---------- */
SELECT 'Attendance' AS tbl, COUNT(*) AS orphans FROM stg.Attendance a
WHERE NOT EXISTS (SELECT 1 FROM stg.Employees e WHERE e.employee_id = a.employee_id)        -- expect 20
UNION ALL
SELECT 'SalaryHistory', COUNT(*) FROM stg.SalaryHistory s
WHERE NOT EXISTS (SELECT 1 FROM stg.Employees e WHERE e.employee_id = s.employee_id)         -- expect 6
UNION ALL
SELECT 'Promotions', COUNT(*) FROM stg.Promotions p
WHERE NOT EXISTS (SELECT 1 FROM stg.Employees e WHERE e.employee_id = p.employee_id)         -- expect 1
UNION ALL
SELECT 'Exits', COUNT(*) FROM stg.Exits x
WHERE NOT EXISTS (SELECT 1 FROM stg.Employees e WHERE e.employee_id = x.employee_id)         -- expect 1
UNION ALL
SELECT 'Employees -> Departments', COUNT(*) FROM stg.Employees e
WHERE NOT EXISTS (SELECT 1 FROM stg.Departments d WHERE d.department_id = e.department_id);  -- expect 2

/* ---------- G. Cross-table logic ---------- */
-- G1. Exit date earlier than hire date (dates in mixed formats, so try 23 then 103 / 105)
SELECT DISTINCT x.employee_id, x.exit_date, e.hire_date
FROM stg.Exits x
JOIN stg.Employees e ON e.employee_id = x.employee_id
WHERE COALESCE(TRY_CONVERT(date, x.exit_date, 23), TRY_CONVERT(date, x.exit_date, 103))
    < COALESCE(TRY_CONVERT(date, e.hire_date, 23), TRY_CONVERT(date, e.hire_date, 105));
-- expect at least 3; rows whose hire_date is the bad 2027 value will also show up

-- G2. Attendance recorded after the employee left
SELECT COUNT(DISTINCT a.stg_row_id) AS rows_after_exit
FROM stg.Attendance a
JOIN stg.Exits x ON x.employee_id = a.employee_id
WHERE TRY_CONVERT(date, a.attendance_date, 23)
    > COALESCE(TRY_CONVERT(date, x.exit_date, 23), TRY_CONVERT(date, x.exit_date, 103));  -- expect at least 20