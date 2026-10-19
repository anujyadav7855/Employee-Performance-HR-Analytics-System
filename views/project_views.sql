USE HR_Analytics_DB;
GO

-- 1. Latest salary per employee
CREATE OR ALTER VIEW dbo.vw_CurrentSalary AS
SELECT employee_id, effective_date AS salary_effective_date, base_salary
FROM (
    SELECT employee_id, effective_date, base_salary,
           ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY effective_date DESC) AS rn
    FROM dbo.SalaryHistory
) s
WHERE rn = 1;
GO

-- 2. One row per employee with everything HR usually asks for
CREATE OR ALTER VIEW dbo.vw_EmployeeDetails AS
SELECT e.employee_id,
       CONCAT(e.first_name, ' ', e.last_name)       AS full_name,
       e.gender, e.date_of_birth, e.hire_date, e.city, e.email,
       e.department_id, d.department_name,
       e.job_role_id, r.job_title, r.job_level,
       e.manager_id, m.first_name + ' ' + m.last_name AS manager_name,
       cs.base_salary                                AS current_salary,
       CASE WHEN x.employee_id IS NULL THEN 'Active' ELSE 'Exited' END AS employment_status,
       x.exit_date, x.exit_type, x.exit_reason
FROM dbo.Employees e
JOIN dbo.Departments d ON d.department_id = e.department_id
JOIN dbo.JobRoles    r ON r.job_role_id   = e.job_role_id
LEFT JOIN dbo.Employees m  ON m.employee_id  = e.manager_id
LEFT JOIN dbo.Exits     x  ON x.employee_id  = e.employee_id
LEFT JOIN dbo.vw_CurrentSalary cs ON cs.employee_id = e.employee_id;
GO

-- 3. Active staff: replaces the #active_staff temp table from Days 8-9
CREATE OR ALTER VIEW dbo.vw_ActiveStaff AS
SELECT employee_id, department_id, job_role_id, hire_date, current_salary AS base_salary
FROM dbo.vw_EmployeeDetails
WHERE employment_status = 'Active';
GO

-- 4. A safe directory for people who must NOT see salary, birth date or gender
CREATE OR ALTER VIEW dbo.vw_EmployeeDirectory AS
SELECT employee_id, full_name, department_name, job_title, manager_name, city, email
FROM dbo.vw_EmployeeDetails
WHERE employment_status = 'Active';
GO

-- 5. The Day 10 KPI scorecard, packaged (single-pass headcount from Day 11, same results)
CREATE OR ALTER VIEW dbo.vw_KpiScorecard AS
WITH years AS (
    SELECT yr, DATEFROMPARTS(yr, 1, 1) AS y_start, DATEFROMPARTS(yr, 12, 31) AS y_end
    FROM (VALUES (2022), (2023), (2024), (2025)) v(yr)
),
roster AS (
    SELECT e.employee_id, e.hire_date, x.exit_date, x.exit_type
    FROM dbo.Employees e
    LEFT JOIN dbo.Exits x ON x.employee_id = e.employee_id
),
headcount AS (
    SELECT y.yr,
           SUM(CASE WHEN r.hire_date <  y.y_start AND (r.exit_date IS NULL OR r.exit_date >= y.y_start) THEN 1 ELSE 0 END) AS opening,
           SUM(CASE WHEN r.hire_date <= y.y_end   AND (r.exit_date IS NULL OR r.exit_date >  y.y_end)   THEN 1 ELSE 0 END) AS closing,
           SUM(CASE WHEN r.exit_date BETWEEN y.y_start AND y.y_end THEN 1 ELSE 0 END) AS exits,
           SUM(CASE WHEN r.exit_type = 'Resignation' AND r.exit_date BETWEEN y.y_start AND y.y_end THEN 1 ELSE 0 END) AS resignations
    FROM years y CROSS JOIN roster r
    GROUP BY y.yr
),
promo_y AS (
    SELECT YEAR(promotion_date) AS yr, COUNT(DISTINCT employee_id) AS promoted
    FROM dbo.Promotions GROUP BY YEAR(promotion_date)
),
emp_year AS (
    SELECT YEAR(review_date) AS yr, employee_id, AVG(rating * 1.0) AS emp_avg
    FROM dbo.PerformanceReviews GROUP BY YEAR(review_date), employee_id
),
rating_y AS (
    SELECT YEAR(review_date) AS yr, AVG(rating * 1.0) AS avg_rating
    FROM dbo.PerformanceReviews GROUP BY YEAR(review_date)
),
hp_y AS (
    SELECT yr, 100.0 * SUM(CASE WHEN emp_avg >= 4.0 THEN 1 ELSE 0 END) / COUNT(*) AS hp_pct
    FROM emp_year GROUP BY yr
),
att_y AS (
    SELECT YEAR(attendance_date) AS yr,
           100.0 * SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) / COUNT(*) AS attendance_pct,
           100.0 * SUM(CASE WHEN status = 'Absent'  THEN 1 ELSE 0 END) / COUNT(*) AS absenteeism_pct
    FROM dbo.Attendance GROUP BY YEAR(attendance_date)
),
pay_y AS (
    SELECT y.yr, SUM(s.base_salary) AS payroll
    FROM years y
    JOIN roster r ON r.hire_date <= y.y_end AND (r.exit_date IS NULL OR r.exit_date > y.y_end)
    JOIN dbo.SalaryHistory s ON s.employee_id = r.employee_id
         AND s.effective_date = (SELECT MAX(s2.effective_date) FROM dbo.SalaryHistory s2
                                 WHERE s2.employee_id = r.employee_id AND s2.effective_date <= y.y_end)
    GROUP BY y.yr
)
SELECT h.yr AS kpi_year,
       h.closing AS headcount_end,
       CAST(100.0 * h.exits / ((h.opening + h.closing) / 2.0) AS DECIMAL(5,2))         AS attrition_rate_pct,
       CAST(100.0 - 100.0 * h.exits / ((h.opening + h.closing) / 2.0) AS DECIMAL(5,2)) AS retention_rate_pct,
       CAST(100.0 * h.resignations / ((h.opening + h.closing) / 2.0) AS DECIMAL(5,2))  AS voluntary_attrition_pct,
       CAST(100.0 * pr.promoted / ((h.opening + h.closing) / 2.0) AS DECIMAL(5,2))     AS promotion_rate_pct,
       CAST(rt.avg_rating AS DECIMAL(4,2))                                             AS avg_rating,
       CAST(hp.hp_pct AS DECIMAL(5,2))                                                 AS high_performer_pct,
       CAST(a.attendance_pct AS DECIMAL(5,2))                                          AS attendance_rate_pct,
       CAST(a.absenteeism_pct AS DECIMAL(5,2))                                         AS absenteeism_rate_pct,
       p.payroll                                                                       AS payroll_cost,
       CAST(1.0 * p.payroll / h.closing AS DECIMAL(12,0))                              AS avg_salary,
       CAST(100.0 * (p.payroll - LAG(p.payroll) OVER (ORDER BY h.yr))
            / LAG(p.payroll) OVER (ORDER BY h.yr) AS DECIMAL(5,2))                     AS payroll_growth_pct
FROM headcount h
JOIN promo_y  pr ON pr.yr = h.yr
JOIN rating_y rt ON rt.yr = h.yr
JOIN hp_y     hp ON hp.yr = h.yr
JOIN att_y    a  ON a.yr  = h.yr
JOIN pay_y    p  ON p.yr  = h.yr;
GO