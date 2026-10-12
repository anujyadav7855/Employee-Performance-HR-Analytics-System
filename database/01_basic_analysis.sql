USE HR_Analytics_DB;
GO

-- explore and filter

-- A1. Look at the data: earliest hires first
SELECT TOP 10 employee_id, first_name, last_name, hire_date
FROM Employees
ORDER BY hire_date, employee_id;

-- A2. DISTINCT: unique values
SELECT DISTINCT job_level FROM JobRoles ORDER BY job_level;
SELECT COUNT(DISTINCT city) AS cities FROM Employees;

-- A3. WHERE toolbox: IN, BETWEEN, AND / OR, LIKE
SELECT COUNT(*) AS it_finance_hires_2023_24
FROM Employees
WHERE department_id IN (2, 3)                        -- 2 = IT, 3 = Finance
  AND hire_date BETWEEN '2023-01-01' AND '2024-12-31';

SELECT COUNT(*) AS same_but_mumbai_or_delhi
FROM Employees
WHERE department_id IN (2, 3)
  AND hire_date BETWEEN '2023-01-01' AND '2024-12-31'
  AND city IN ('Mumbai', 'Delhi');

SELECT COUNT(*) AS last_name_starts_with_s
FROM Employees
WHERE last_name LIKE 'S%';     -- % means "anything after"

-- Workforce overview (business questions 1, 2, 3, 4)

-- B1. Headcount by department (Q1)
SELECT d.department_name, COUNT(*) AS employees
FROM Employees e
JOIN Departments d ON d.department_id = e.department_id
GROUP BY d.department_name
ORDER BY employees DESC;

-- B2. Total, exited and active employees
SELECT COUNT(*)                    AS total_employees,
       COUNT(x.employee_id)        AS exited,
       COUNT(*) - COUNT(x.employee_id) AS active
FROM Employees e
LEFT JOIN Exits x ON x.employee_id = e.employee_id;

-- B3. Hires per year (Q2)
SELECT YEAR(hire_date) AS hire_year, COUNT(*) AS hires
FROM Employees
GROUP BY YEAR(hire_date)
ORDER BY hire_year;

-- B4. Gender distribution with percentage (Q4)
SELECT ISNULL(gender, 'Unknown') AS gender,
       COUNT(*) AS employees,
       CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Employees) AS DECIMAL(5,2)) AS pct
FROM Employees
GROUP BY ISNULL(gender, 'Unknown')
ORDER BY employees DESC;

-- B5. Age groups of ACTIVE employees on 2025-12-31 (Q4)
SELECT age_group, COUNT(*) AS active_employees
FROM (
    SELECT CASE WHEN age IS NULL THEN 'Unknown'
                WHEN age < 25 THEN 'Under 25'
                WHEN age < 35 THEN '25-34'
                WHEN age < 45 THEN '35-44'
                WHEN age < 55 THEN '45-54'
                ELSE '55+' END AS age_group
    FROM (
        SELECT DATEDIFF(YEAR, e.date_of_birth, '2025-12-31')
               - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, e.date_of_birth, '2025-12-31'), e.date_of_birth) > '2025-12-31'
                      THEN 1 ELSE 0 END AS age
        FROM Employees e
        LEFT JOIN Exits x ON x.employee_id = e.employee_id
        WHERE x.employee_id IS NULL                      -- active only
    ) t
) g
GROUP BY age_group
ORDER BY age_group;

-- B6. Tenure bands of ACTIVE employees (years since hire)
SELECT tenure_band, COUNT(*) AS active_employees
FROM (
    SELECT CASE WHEN t.years < 1 THEN '1) Under 1 year'
                WHEN t.years < 3 THEN '2) 1-3 years'
                WHEN t.years < 5 THEN '3) 3-5 years'
                WHEN t.years < 8 THEN '4) 5-8 years'
                ELSE '5) 8+ years' END AS tenure_band
    FROM Employees e
    LEFT JOIN Exits x ON x.employee_id = e.employee_id
    CROSS APPLY (SELECT DATEDIFF(DAY, e.hire_date, '2025-12-31') / 365.25 AS years) t
    WHERE x.employee_id IS NULL
) b
GROUP BY tenure_band
ORDER BY tenure_band;

-- Salary (business question 5, partly)
-- C1. Salary bands by department
SELECT d.department_name,
       COUNT(*) AS roles,
       MIN(r.min_salary) AS lowest_band_start,
       MAX(r.max_salary) AS highest_band_end,
       CAST(AVG((r.min_salary + r.max_salary) / 2) AS DECIMAL(12,0)) AS avg_band_midpoint
FROM JobRoles r
JOIN Departments d ON d.department_id = r.department_id
GROUP BY d.department_name
ORDER BY avg_band_midpoint DESC;

-- C2. Salary records by reason (aggregates)
SELECT change_reason,
       COUNT(*) AS records,
       CAST(AVG(base_salary) AS DECIMAL(12,0)) AS avg_salary,
       MIN(base_salary) AS min_salary,
       MAX(base_salary) AS max_salary
FROM SalaryHistory
GROUP BY change_reason
ORDER BY records DESC;

-- C3. Five highest salary records, with employee names
SELECT TOP 5 s.employee_id,
       CONCAT(e.first_name, ' ', e.last_name) AS employee,
       d.department_name, s.effective_date, s.base_salary, s.change_reason
FROM SalaryHistory s
JOIN Employees   e ON e.employee_id   = s.employee_id
JOIN Departments d ON d.department_id = e.department_id
ORDER BY s.base_salary DESC, s.employee_id;

-- Performance (business questions 9, 10)

-- D1. Rating distribution
SELECT rating, COUNT(*) AS reviews,
       CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM PerformanceReviews) AS DECIMAL(5,2)) AS pct
FROM PerformanceReviews
GROUP BY rating
ORDER BY rating;

-- D2. Average rating by department (Q10)
SELECT d.department_name,
       COUNT(*) AS reviews,
       CAST(AVG(r.rating * 1.0) AS DECIMAL(4,2)) AS avg_rating
FROM PerformanceReviews r
JOIN Employees   e ON e.employee_id   = r.employee_id
JOIN Departments d ON d.department_id = e.department_id
GROUP BY d.department_name
ORDER BY avg_rating DESC;

-- D3. Top 10 performers (Q9): at least 6 reviews so one lucky review can't win
SELECT TOP 10 r.employee_id,
       CONCAT(e.first_name, ' ', e.last_name) AS employee,
       d.department_name,
       COUNT(*) AS reviews,
       CAST(AVG(r.rating * 1.0) AS DECIMAL(4,2)) AS avg_rating
FROM PerformanceReviews r
JOIN Employees   e ON e.employee_id   = r.employee_id
JOIN Departments d ON d.department_id = e.department_id
GROUP BY r.employee_id, e.first_name, e.last_name, d.department_name
HAVING COUNT(*) >= 6
ORDER BY AVG(r.rating * 1.0) DESC, COUNT(*) DESC, r.employee_id;

-- Attendance (business questions 13, 14)

-- E1. Overall status mix
SELECT status, COUNT(*) AS days,
       CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Attendance) AS DECIMAL(5,2)) AS pct
FROM Attendance
GROUP BY status
ORDER BY days DESC;

-- E2. Attendance and absenteeism by department (conditional counting with CASE)
SELECT d.department_name,
       COUNT(*) AS records,
       SUM(CASE WHEN a.status = 'Present'  THEN 1 ELSE 0 END) AS present_days,
       SUM(CASE WHEN a.status = 'Absent'   THEN 1 ELSE 0 END) AS absent_days,
       SUM(CASE WHEN a.status = 'Leave'    THEN 1 ELSE 0 END) AS leave_days,
       SUM(CASE WHEN a.status = 'Half-Day' THEN 1 ELSE 0 END) AS half_days,
       CAST(100.0 * SUM(CASE WHEN a.status = 'Present' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS attendance_rate_pct,
       CAST(100.0 * SUM(CASE WHEN a.status = 'Absent'  THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS absenteeism_rate_pct
FROM Attendance a
JOIN Employees   e ON e.employee_id   = a.employee_id
JOIN Departments d ON d.department_id = e.department_id
GROUP BY d.department_name
ORDER BY absenteeism_rate_pct DESC;

-- E3. Monthly attendance, 2025 (Q13)
SELECT MONTH(attendance_date) AS month_no,
       COUNT(*) AS records,
       SUM(CASE WHEN status = 'Absent' THEN 1 ELSE 0 END) AS absent_days,
       CAST(100.0 * SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS attendance_rate_pct,
       CAST(100.0 * SUM(CASE WHEN status = 'Absent'  THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS absenteeism_rate_pct
FROM Attendance
WHERE attendance_date >= '2025-01-01' AND attendance_date < '2026-01-01'
GROUP BY MONTH(attendance_date)
ORDER BY month_no;

-- E4. Employees with 15+ absent days in 2025 (Q14)
SELECT a.employee_id,
       CONCAT(e.first_name, ' ', e.last_name) AS employee,
       d.department_name,
       COUNT(*) AS absent_days_2025
FROM Attendance a
JOIN Employees   e ON e.employee_id   = a.employee_id
JOIN Departments d ON d.department_id = e.department_id
WHERE a.status = 'Absent'
  AND a.attendance_date >= '2025-01-01' AND a.attendance_date < '2026-01-01'
GROUP BY a.employee_id, e.first_name, e.last_name, d.department_name
HAVING COUNT(*) >= 15
ORDER BY absent_days_2025 DESC, a.employee_id;

-- Promotions and exits (business questions 16, 18, 19)

-- F1. Promotions per year, and per department (Q16)
SELECT YEAR(promotion_date) AS promo_year, COUNT(*) AS promotions
FROM Promotions
GROUP BY YEAR(promotion_date)
ORDER BY promo_year;

SELECT d.department_name, COUNT(*) AS promotions
FROM Promotions p
JOIN Employees   e ON e.employee_id   = p.employee_id
JOIN Departments d ON d.department_id = e.department_id
GROUP BY d.department_name
ORDER BY promotions DESC;

-- F2. Share of employees who left, by department (Q18)
SELECT d.department_name,
       COUNT(*)             AS employees_ever,
       COUNT(x.employee_id) AS exits,
       CAST(100.0 * COUNT(x.employee_id) / COUNT(*) AS DECIMAL(5,2)) AS exit_share_pct
FROM Employees e
JOIN Departments d ON d.department_id = e.department_id
LEFT JOIN Exits  x ON x.employee_id   = e.employee_id
GROUP BY d.department_name
ORDER BY exit_share_pct DESC;

-- F2b. Only departments where more than 25% have left (HAVING on an aggregate)
SELECT d.department_name,
       CAST(100.0 * COUNT(x.employee_id) / COUNT(*) AS DECIMAL(5,2)) AS exit_share_pct
FROM Employees e
JOIN Departments d ON d.department_id = e.department_id
LEFT JOIN Exits  x ON x.employee_id   = e.employee_id
GROUP BY d.department_name
HAVING 100.0 * COUNT(x.employee_id) / COUNT(*) > 25
ORDER BY exit_share_pct DESC;

-- F3. Exit type, reasons (NULL handling), and exits per year (Q19)
SELECT exit_type, COUNT(*) AS exits FROM Exits GROUP BY exit_type ORDER BY exits DESC;

SELECT ISNULL(exit_reason, 'Not specified') AS exit_reason, COUNT(*) AS exits
FROM Exits
GROUP BY ISNULL(exit_reason, 'Not specified')
ORDER BY exits DESC, exit_reason;

SELECT YEAR(exit_date) AS exit_year, COUNT(*) AS exits
FROM Exits GROUP BY YEAR(exit_date) ORDER BY exit_year;

-- String, date and NULL functions

-- G1. String functions
SELECT TOP 5 employee_id,
       CONCAT(first_name, ' ', last_name)            AS full_name,
       UPPER(city)                                   AS city_upper,
       LEN(email)                                    AS email_length,
       LEFT(email, CHARINDEX('@', email) - 1)        AS email_user,
       SUBSTRING(email, CHARINDEX('@', email) + 1, 100) AS email_domain
FROM Employees
ORDER BY employee_id;

-- G2. Date functions
SELECT TOP 5 employee_id, hire_date,
       DATENAME(MONTH, hire_date)              AS hire_month,
       DATEADD(DAY, 90, hire_date)             AS probation_ends,
       EOMONTH(hire_date)                      AS month_end,
       DATEDIFF(YEAR, hire_date, '2025-12-31') AS calendar_years_to_2025
FROM Employees
ORDER BY employee_id;

SELECT MONTH(hire_date) AS month_no, DATENAME(MONTH, hire_date) AS month_name, COUNT(*) AS hires
FROM Employees
GROUP BY MONTH(hire_date), DATENAME(MONTH, hire_date)
ORDER BY month_no;

-- G3. NULL handling
SELECT COUNT(*)                          AS total_rows,
       COUNT(city)                       AS with_city,
       COUNT(*) - COUNT(city)            AS null_city,
       COUNT(date_of_birth)              AS with_dob,
       COUNT(*) - COUNT(date_of_birth)   AS null_dob
FROM Employees;

SELECT COUNT(*) AS wrong_equals_null FROM Employees WHERE city = NULL;     -- always 0 rows!
SELECT COUNT(*) AS is_null           FROM Employees WHERE city IS NULL;
SELECT COUNT(*) AS not_pune          FROM Employees WHERE city <> 'Pune';
SELECT COUNT(*) AS not_pune_or_null  FROM Employees WHERE city <> 'Pune' OR city IS NULL;

