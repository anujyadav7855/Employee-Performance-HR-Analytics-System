USE HR_Analytics_DB;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

/* ---------- T1: non-sargable vs sargable date filter ---------- */
-- T1a. Function applied to the column
SELECT MONTH(attendance_date) AS month_no, COUNT(*) AS records,
       SUM(CASE WHEN status = 'Absent' THEN 1 ELSE 0 END) AS absent_days
FROM Attendance
WHERE YEAR(attendance_date) = 2025
GROUP BY MONTH(attendance_date);

-- T1b. Range on the bare column
SELECT MONTH(attendance_date) AS month_no, COUNT(*) AS records,
       SUM(CASE WHEN status = 'Absent' THEN 1 ELSE 0 END) AS absent_days
FROM Attendance
WHERE attendance_date >= '2025-01-01' AND attendance_date < '2026-01-01'
GROUP BY MONTH(attendance_date);

/* ---------- T2: department attendance: join first vs aggregate first ---------- */
-- T2a. Join 296k rows, then group (Day 7 query E2)
SELECT d.department_name, COUNT(*) AS records,
       SUM(CASE WHEN a.status = 'Present' THEN 1 ELSE 0 END) AS present_days,
       SUM(CASE WHEN a.status = 'Absent'  THEN 1 ELSE 0 END) AS absent_days,
       CAST(100.0 * SUM(CASE WHEN a.status = 'Present' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS attendance_rate_pct,
       CAST(100.0 * SUM(CASE WHEN a.status = 'Absent'  THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS absenteeism_rate_pct
FROM Attendance a
JOIN Employees   e ON e.employee_id   = a.employee_id
JOIN Departments d ON d.department_id = e.department_id
GROUP BY d.department_name
ORDER BY absenteeism_rate_pct DESC;

-- T2b. Collapse attendance to one row per employee first, then join the 400 rows
WITH per_employee AS (
    SELECT employee_id, COUNT(*) AS records,
           SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) AS present_days,
           SUM(CASE WHEN status = 'Absent'  THEN 1 ELSE 0 END) AS absent_days
    FROM Attendance
    GROUP BY employee_id
)
SELECT d.department_name, SUM(p.records) AS records,
       SUM(p.present_days) AS present_days, SUM(p.absent_days) AS absent_days,
       CAST(100.0 * SUM(p.present_days) / SUM(p.records) AS DECIMAL(5,2)) AS attendance_rate_pct,
       CAST(100.0 * SUM(p.absent_days)  / SUM(p.records) AS DECIMAL(5,2)) AS absenteeism_rate_pct
FROM per_employee p
JOIN Employees   e ON e.employee_id   = p.employee_id
JOIN Departments d ON d.department_id = e.department_id
GROUP BY d.department_name
ORDER BY absenteeism_rate_pct DESC;

/* ---------- T3: "current salary", three ways (no index change needed) ---------- */
-- T3a. Correlated MAX (Day 8)
SELECT s.employee_id, s.base_salary
FROM SalaryHistory s
WHERE s.effective_date = (SELECT MAX(s2.effective_date) FROM SalaryHistory s2
                          WHERE s2.employee_id = s.employee_id);

-- T3b. ROW_NUMBER (Day 9)
WITH r AS (
    SELECT employee_id, base_salary,
           ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY effective_date DESC) AS rn
    FROM SalaryHistory
)
SELECT employee_id, base_salary FROM r WHERE rn = 1;

-- T3c. CROSS APPLY with TOP 1
SELECT e.employee_id, s.base_salary
FROM Employees e
CROSS APPLY (SELECT TOP 1 sh.base_salary
             FROM SalaryHistory sh
             WHERE sh.employee_id = e.employee_id
             ORDER BY sh.effective_date DESC) s;

-- Correctness check: all three must give the same 400 rows. Expect 0 rows from each EXCEPT.
SELECT s.employee_id, s.base_salary FROM SalaryHistory s
WHERE s.effective_date = (SELECT MAX(s2.effective_date) FROM SalaryHistory s2 WHERE s2.employee_id = s.employee_id)
EXCEPT
SELECT e.employee_id, x.base_salary FROM Employees e
CROSS APPLY (SELECT TOP 1 sh.base_salary FROM SalaryHistory sh
             WHERE sh.employee_id = e.employee_id ORDER BY sh.effective_date DESC) x;

/* ---------- T4: yearly headcount: repeated subqueries vs one pass ---------- */
-- T4a. Day 10 style: two correlated subqueries per year
WITH years AS (
    SELECT yr, DATEFROMPARTS(yr, 1, 1) AS y_start, DATEFROMPARTS(yr, 12, 31) AS y_end
    FROM (VALUES (2022), (2023), (2024), (2025)) v(yr)
)
SELECT y.yr,
       (SELECT COUNT(*) FROM Employees e WHERE e.hire_date < y.y_start
          AND NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id AND x.exit_date < y.y_start))  AS opening,
       (SELECT COUNT(*) FROM Employees e WHERE e.hire_date <= y.y_end
          AND NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id AND x.exit_date <= y.y_end)) AS closing,
       (SELECT COUNT(*) FROM Exits x WHERE x.exit_date BETWEEN y.y_start AND y.y_end) AS exits
FROM years y
ORDER BY y.yr;

-- T4b. Read Employees and Exits once, then count with CASE
WITH years AS (
    SELECT yr, DATEFROMPARTS(yr, 1, 1) AS y_start, DATEFROMPARTS(yr, 12, 31) AS y_end
    FROM (VALUES (2022), (2023), (2024), (2025)) v(yr)
),
roster AS (
    SELECT e.employee_id, e.hire_date, x.exit_date
    FROM Employees e
    LEFT JOIN Exits x ON x.employee_id = e.employee_id
)
SELECT y.yr,
       SUM(CASE WHEN r.hire_date <  y.y_start AND (r.exit_date IS NULL OR r.exit_date >= y.y_start) THEN 1 ELSE 0 END) AS opening,
       SUM(CASE WHEN r.hire_date <= y.y_end   AND (r.exit_date IS NULL OR r.exit_date >  y.y_end)   THEN 1 ELSE 0 END) AS closing,
       SUM(CASE WHEN r.exit_date BETWEEN y.y_start AND y.y_end THEN 1 ELSE 0 END) AS exits
FROM years y
CROSS JOIN roster r
GROUP BY y.yr
ORDER BY y.yr;

/* ---------- T5: SELECT * and covering ---------- */
-- T5a. Every column
SELECT * FROM Attendance WHERE attendance_date = '2025-03-10';

-- T5b. Only what the question needs
SELECT employee_id, status FROM Attendance WHERE attendance_date = '2025-03-10';

-- T5c. Needs one column that a narrow index would not contain
SELECT employee_id, status, check_in_time FROM Attendance WHERE attendance_date = '2025-03-10';