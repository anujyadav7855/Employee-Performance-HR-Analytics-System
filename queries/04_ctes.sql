USE HR_Analytics_DB;
GO

IF OBJECT_ID('tempdb..#active_staff') IS NOT NULL DROP TABLE #active_staff;

SELECT e.employee_id, e.department_id, e.job_role_id, s.base_salary
INTO #active_staff
FROM Employees e
JOIN SalaryHistory s ON s.employee_id = e.employee_id
WHERE s.effective_date = (SELECT MAX(s2.effective_date) FROM SalaryHistory s2
                          WHERE s2.employee_id = e.employee_id)
  AND NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id);

SELECT COUNT(*) AS active_staff_rows FROM #active_staff;     -- expect 291

-- D1. Payroll by department, with a TOTAL row (UNION ALL inside a derived table)
SELECT department_name, active_employees, annual_payroll, avg_salary
FROM (
    SELECT d.department_name, 0 AS sort_key,
           COUNT(*) AS active_employees,
           SUM(a.base_salary) AS annual_payroll,
           CAST(AVG(a.base_salary) AS DECIMAL(12,0)) AS avg_salary
    FROM #active_staff a
    JOIN Departments d ON d.department_id = a.department_id
    GROUP BY d.department_name
    UNION ALL
    SELECT 'TOTAL', 1, COUNT(*), SUM(base_salary), CAST(AVG(base_salary) AS DECIMAL(12,0))
    FROM #active_staff
) t
ORDER BY sort_key, annual_payroll DESC;

-- D2. Pay spread within the same role (top 10 roles with 5+ active holders)
SELECT TOP 10 r.job_title,
       COUNT(*) AS holders,
       MIN(a.base_salary) AS lowest,
       CAST(AVG(a.base_salary) AS DECIMAL(12,0)) AS average,
       MAX(a.base_salary) AS highest,
       CAST(1.0 * MAX(a.base_salary) / MIN(a.base_salary) AS DECIMAL(5,2)) AS highest_to_lowest
FROM #active_staff a
JOIN JobRoles r ON r.job_role_id = a.job_role_id
GROUP BY r.job_title
HAVING COUNT(*) >= 5
ORDER BY highest_to_lowest DESC, r.job_title;

-- D3. Average tenure by department (Q3): leavers count until their exit date
SELECT d.department_name,
       COUNT(*) AS employees,
       CAST(AVG(DATEDIFF(DAY, e.hire_date, ISNULL(x.exit_date, '2025-12-31')) / 365.25) AS DECIMAL(4,1)) AS avg_tenure_years
FROM Employees e
JOIN Departments d ON d.department_id = e.department_id
LEFT JOIN Exits  x ON x.employee_id   = e.employee_id
GROUP BY d.department_name
ORDER BY avg_tenure_years DESC, d.department_name;

-- D4. Time to first promotion (Q17)
WITH first_promo AS (
    SELECT employee_id, MIN(promotion_date) AS first_promotion_date
    FROM Promotions
    GROUP BY employee_id
)
SELECT d.department_name,
       COUNT(*) AS promoted_employees,
       CAST(AVG(DATEDIFF(DAY, e.hire_date, fp.first_promotion_date) / 30.4375) AS DECIMAL(5,1)) AS avg_months_to_first_promotion
FROM first_promo fp
JOIN Employees   e ON e.employee_id   = fp.employee_id
JOIN Departments d ON d.department_id = e.department_id
GROUP BY d.department_name
ORDER BY AVG(DATEDIFF(DAY, e.hire_date, fp.first_promotion_date) / 30.4375);

-- D5. Performance decline (Q11): 2022-23 average vs 2024-25 average, 2+ reviews in each window
WITH windows AS (
    SELECT employee_id,
           COUNT(CASE WHEN review_period <  '2024-H1' THEN 1 END)             AS n_early,
           AVG(CASE   WHEN review_period <  '2024-H1' THEN rating * 1.0 END)  AS avg_early,
           COUNT(CASE WHEN review_period >= '2024-H1' THEN 1 END)             AS n_late,
           AVG(CASE   WHEN review_period >= '2024-H1' THEN rating * 1.0 END)  AS avg_late
    FROM PerformanceReviews
    GROUP BY employee_id
)
SELECT w.employee_id,
       CONCAT(e.first_name, ' ', e.last_name) AS employee,
       d.department_name,
       CAST(w.avg_early AS DECIMAL(4,2)) AS avg_2022_23,
       CAST(w.avg_late  AS DECIMAL(4,2)) AS avg_2024_25,
       CAST(w.avg_early - w.avg_late AS DECIMAL(4,2)) AS drop_in_rating
FROM windows w
JOIN Employees   e ON e.employee_id   = w.employee_id
JOIN Departments d ON d.department_id = e.department_id
WHERE w.n_early >= 2 AND w.n_late >= 2
  AND w.avg_early - w.avg_late >= 1.0
ORDER BY drop_in_rating DESC, w.employee_id;

-- D6. Salary vs performance (Q12): chained CTEs, active employees with 4+ reviews
WITH rating_avg AS (
    SELECT employee_id, AVG(rating * 1.0) AS avg_rating
    FROM PerformanceReviews
    GROUP BY employee_id
    HAVING COUNT(*) >= 4
),
banded AS (
    SELECT a.base_salary,
           CASE WHEN ra.avg_rating < 3.0 THEN '1) Below 3.0'
                WHEN ra.avg_rating < 4.0 THEN '2) 3.0-3.99'
                ELSE '3) 4.0 and above' END AS rating_band
    FROM #active_staff a
    JOIN rating_avg ra ON ra.employee_id = a.employee_id
)
SELECT rating_band, COUNT(*) AS employees,
       CAST(AVG(base_salary) AS DECIMAL(12,0)) AS avg_current_salary
FROM banded
GROUP BY rating_band
ORDER BY rating_band;

-- D7. Promotion vs attrition (Q20): all employees, then only people hired before 2022
WITH flags AS (
    SELECT e.employee_id, e.hire_date,
           CASE WHEN EXISTS (SELECT 1 FROM Promotions p WHERE p.employee_id = e.employee_id)
                THEN 'Promoted' ELSE 'Never promoted' END AS promo_status,
           CASE WHEN EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id)
                THEN 1 ELSE 0 END AS left_company
    FROM Employees e
)
SELECT promo_status, COUNT(*) AS employees, SUM(left_company) AS left_company,
       CAST(100.0 * SUM(left_company) / COUNT(*) AS DECIMAL(5,2)) AS exit_share_pct
FROM flags
GROUP BY promo_status
ORDER BY promo_status;
-- Run it again with:  WHERE hire_date < '2022-01-01'  added before GROUP BY

-- union and union all
-- E1. Hires, promotions and exits per year: stack three queries, then pivot with CASE
WITH events AS (
    SELECT YEAR(hire_date) AS event_year, 'Hire' AS event_type
    FROM Employees WHERE hire_date >= '2022-01-01'
    UNION ALL
    SELECT YEAR(promotion_date), 'Promotion' FROM Promotions
    UNION ALL
    SELECT YEAR(exit_date), 'Exit' FROM Exits
)
SELECT event_year,
       SUM(CASE WHEN event_type = 'Hire'      THEN 1 ELSE 0 END) AS hires,
       SUM(CASE WHEN event_type = 'Promotion' THEN 1 ELSE 0 END) AS promotions,
       SUM(CASE WHEN event_type = 'Exit'      THEN 1 ELSE 0 END) AS exits,
       SUM(CASE WHEN event_type = 'Hire' THEN 1 ELSE 0 END)
     - SUM(CASE WHEN event_type = 'Exit' THEN 1 ELSE 0 END)       AS net_headcount_change
FROM events
GROUP BY event_year
ORDER BY event_year;

-- E2. UNION vs UNION ALL: employees who were promoted or left
SELECT COUNT(*) AS union_all_rows
FROM (SELECT employee_id FROM Promotions UNION ALL SELECT employee_id FROM Exits) u;

SELECT COUNT(*) AS union_rows
FROM (SELECT employee_id FROM Promotions UNION     SELECT employee_id FROM Exits) u;