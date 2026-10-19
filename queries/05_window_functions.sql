---SUM(salary) OVER (PARTITION BY department ORDER BY hire_date ROWS UNBOUNDED PRECEDING)
--  ^ what to calculate   ^ restart per group     ^ order inside the group   ^ which rows to include

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

SELECT COUNT(*) AS rows_in_temp FROM #active_staff;     -- expect 291

-- A1. Top 3 earners per department (this was the Day 8 stretch exercise)
WITH ranked AS (
    SELECT d.department_name, a.employee_id,
           CONCAT(e.first_name, ' ', e.last_name) AS employee,
           r.job_title, a.base_salary,
           ROW_NUMBER() OVER (PARTITION BY a.department_id
                              ORDER BY a.base_salary DESC, a.employee_id) AS salary_rank
    FROM #active_staff a
    JOIN Employees   e ON e.employee_id   = a.employee_id
    JOIN Departments d ON d.department_id = a.department_id
    JOIN JobRoles    r ON r.job_role_id   = a.job_role_id
)
SELECT department_name, salary_rank, employee_id, employee, job_title, base_salary
FROM ranked
WHERE salary_rank <= 3
ORDER BY department_name, salary_rank;

-- A2. ROW_NUMBER vs RANK vs DENSE_RANK with real ties
--     (employees with 6+ reviews, ranked by average rating)
WITH emp_rating AS (
    SELECT employee_id, COUNT(*) AS reviews, AVG(rating * 1.0) AS avg_rating
    FROM PerformanceReviews
    GROUP BY employee_id
    HAVING COUNT(*) >= 6
)
SELECT TOP 14 er.employee_id,
       CONCAT(e.first_name, ' ', e.last_name) AS employee,
       er.reviews,
       CAST(er.avg_rating AS DECIMAL(4,2)) AS avg_rating,
       ROW_NUMBER() OVER (ORDER BY er.avg_rating DESC, er.employee_id) AS row_num,
       RANK()       OVER (ORDER BY er.avg_rating DESC)                 AS rnk,
       DENSE_RANK() OVER (ORDER BY er.avg_rating DESC)                 AS dense_rnk
FROM emp_rating er
JOIN Employees e ON e.employee_id = er.employee_id
ORDER BY er.avg_rating DESC, er.employee_id;

-- A3. Salary quartiles of active employees, with each quartile's share of payroll
WITH q AS (
    SELECT base_salary,
           NTILE(4) OVER (ORDER BY base_salary, employee_id) AS quartile
    FROM #active_staff
)
SELECT quartile,
       COUNT(*)           AS employees,
       MIN(base_salary)   AS lowest,
       MAX(base_salary)   AS highest,
       SUM(base_salary)   AS payroll,
       CAST(100.0 * SUM(base_salary) / SUM(SUM(base_salary)) OVER () AS DECIMAL(5,2)) AS payroll_share_pct
FROM q
GROUP BY quartile
ORDER BY quartile;

-- A4. Latest salary per employee with ROW_NUMBER (alternative to Day 8's correlated MAX)
--     and a check that it agrees with #active_staff
WITH latest AS (
    SELECT employee_id, base_salary,
           ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY effective_date DESC) AS rn
    FROM SalaryHistory
)
SELECT COUNT(*) AS employees_with_latest_salary,
       SUM(CASE WHEN a.employee_id IS NOT NULL AND a.base_salary <> l.base_salary THEN 1 ELSE 0 END) AS differs_from_day8
FROM latest l
LEFT JOIN #active_staff a ON a.employee_id = l.employee_id
WHERE l.rn = 1;

-- B1. Size of each salary change, using LAG (previous row within the employee)
WITH changes AS (
    SELECT employee_id, effective_date, change_reason, base_salary,
           LAG(base_salary) OVER (PARTITION BY employee_id ORDER BY effective_date) AS previous_salary
    FROM SalaryHistory
)
SELECT change_reason,
       COUNT(*) AS records,
       CAST(AVG((base_salary - previous_salary) * 100.0 / previous_salary) AS DECIMAL(5,2)) AS avg_change_pct,
       CAST(MIN((base_salary - previous_salary) * 100.0 / previous_salary) AS DECIMAL(5,2)) AS min_change_pct,
       CAST(MAX((base_salary - previous_salary) * 100.0 / previous_salary) AS DECIMAL(5,2)) AS max_change_pct
FROM changes
WHERE previous_salary IS NOT NULL
GROUP BY change_reason
ORDER BY avg_change_pct DESC;


-- B2. Rating change between consecutive reviews (LAG), and two declines in a row (LAG 1 and 2)
/*WITH s AS (
    SELECT employee_id, review_period, rating,
           LAG(rating, 1) OVER (PARTITION BY employee_id ORDER BY review_period) AS prev_rating,
           LAG(rating, 2) OVER (PARTITION BY employee_id ORDER BY review_period) AS prev_prev_rating
    FROM PerformanceReviews
)
SELECT rating - prev_rating AS change_vs_previous_review, COUNT(*) AS review_pairs
FROM s
WHERE prev_rating IS NOT NULL
GROUP BY rating - prev_rating
ORDER BY change_vs_previous_review;

-- (new statement: repeat the same WITH seq AS (...) definition, then:)
SELECT s.employee_id, CONCAT(e.first_name, ' ', e.last_name) AS employee, d.department_name,
       s.review_period, s.prev_prev_rating, s.prev_rating, s.rating
FROM  s
JOIN Employees   e ON e.employee_id   = s.employee_id
JOIN Departments d ON d.department_id = e.department_id
WHERE s.rating < s.prev_rating AND s.prev_rating < s.prev_prev_rating
ORDER BY s.employee_id, s.review_period;*/

-- B3. LEAD: months between consecutive promotions
WITH seq AS (
    SELECT employee_id, promotion_date,
           LEAD(promotion_date) OVER (PARTITION BY employee_id ORDER BY promotion_date) AS next_promotion_date
    FROM Promotions
)
SELECT COUNT(*) AS promotion_pairs,
       COUNT(DISTINCT employee_id) AS employees,
       CAST(AVG(DATEDIFF(DAY, promotion_date, next_promotion_date) / 30.4375) AS DECIMAL(5,1)) AS avg_months_between,
       CAST(MIN(DATEDIFF(DAY, promotion_date, next_promotion_date) / 30.4375) AS DECIMAL(5,1)) AS min_months,
       CAST(MAX(DATEDIFF(DAY, promotion_date, next_promotion_date) / 30.4375) AS DECIMAL(5,1)) AS max_months
FROM seq
WHERE next_promotion_date IS NOT NULL;

-- B4. First vs latest rating: FIRST_VALUE and LAST_VALUE
WITH ordered AS (
    SELECT employee_id,
           FIRST_VALUE(rating) OVER (PARTITION BY employee_id ORDER BY review_period) AS first_rating,
           LAST_VALUE(rating)  OVER (PARTITION BY employee_id ORDER BY review_period
                                     ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS latest_rating,
           COUNT(*)            OVER (PARTITION BY employee_id) AS n_reviews
    FROM PerformanceReviews
),
per_employee AS (
    SELECT DISTINCT employee_id,
           CASE WHEN latest_rating > first_rating THEN 'Improved'
                WHEN latest_rating < first_rating THEN 'Declined'
                ELSE 'Unchanged' END AS trend
    FROM ordered
    WHERE n_reviews >= 2
)
SELECT trend, COUNT(*) AS employees
FROM per_employee
GROUP BY trend
ORDER BY employees DESC;


-- C1. Monthly hires, exits, running headcount and a 3-month moving average of exits
WITH months AS (                                   -- recursive CTE: one row per month
    SELECT CAST('2022-01-01' AS DATE) AS month_start
    UNION ALL
    SELECT DATEADD(MONTH, 1, month_start) FROM months WHERE month_start < '2025-12-01'
),
monthly AS (
    SELECT m.month_start,
           (SELECT COUNT(*) FROM Employees e
            WHERE e.hire_date >= m.month_start AND e.hire_date < DATEADD(MONTH, 1, m.month_start)) AS hires,
           (SELECT COUNT(*) FROM Exits x
            WHERE x.exit_date >= m.month_start AND x.exit_date < DATEADD(MONTH, 1, m.month_start)) AS exits
    FROM months m
),
opening AS (SELECT COUNT(*) AS headcount FROM Employees WHERE hire_date < '2022-01-01'),
with_windows AS (
    SELECT mo.month_start, mo.hires, mo.exits,
           o.headcount + SUM(mo.hires - mo.exits)
                         OVER (ORDER BY mo.month_start ROWS UNBOUNDED PRECEDING) AS headcount_end,
           CAST(AVG(mo.exits * 1.0)
                OVER (ORDER BY mo.month_start ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS DECIMAL(4,2)) AS exits_3m_avg
    FROM monthly mo
    CROSS JOIN opening o
)
SELECT month_start, hires, exits, headcount_end, exits_3m_avg
FROM with_windows
WHERE month_start >= '2025-01-01'            -- filter AFTER the windows are computed
ORDER BY month_start
OPTION (MAXRECURSION 100);


-- C2. Monthly absenteeism for 2025 with a 3-month moving average
WITH monthly AS (
    SELECT MONTH(attendance_date) AS month_no,
           CAST(100.0 * SUM(CASE WHEN status = 'Absent' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS absenteeism_rate_pct
    FROM Attendance
    WHERE attendance_date >= '2025-01-01' AND attendance_date < '2026-01-01'
    GROUP BY MONTH(attendance_date)
)
SELECT month_no, absenteeism_rate_pct,
       CAST(AVG(absenteeism_rate_pct)
            OVER (ORDER BY month_no ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS DECIMAL(5,2)) AS moving_avg_3m
FROM monthly
ORDER BY month_no;

-- D1. Compa-ratio: an employee's salary divided by the average of their role (active staff)
WITH pay AS (
    SELECT employee_id, base_salary,
           base_salary / AVG(base_salary) OVER (PARTITION BY job_role_id) AS compa_ratio
    FROM #active_staff
),
banded AS (
    SELECT CASE WHEN compa_ratio < 0.85  THEN '1) Below 85% of role average'
                WHEN compa_ratio <= 1.15 THEN '2) 85%-115%'
                ELSE '3) Above 115%' END AS pay_position
    FROM pay
)
SELECT pay_position, COUNT(*) AS employees
FROM banded
GROUP BY pay_position
ORDER BY pay_position;

-- D2. Talent matrix: performance band x pay position (active staff with 4+ reviews)
WITH pay AS (
    SELECT employee_id, job_role_id, department_id, base_salary,
           AVG(base_salary) OVER (PARTITION BY job_role_id)               AS role_avg,
           base_salary / AVG(base_salary) OVER (PARTITION BY job_role_id) AS compa_ratio
    FROM #active_staff
),
perf AS (
    SELECT employee_id, AVG(rating * 1.0) AS avg_rating
    FROM PerformanceReviews
    GROUP BY employee_id
    HAVING COUNT(*) >= 4
),
segments AS (
    SELECT p.employee_id, p.job_role_id, p.department_id, p.base_salary, p.role_avg, p.compa_ratio, f.avg_rating,
           CASE WHEN f.avg_rating >= 4.0 THEN '1) High' WHEN f.avg_rating >= 3.0 THEN '2) Core' ELSE '3) Low' END AS performance,
           CASE WHEN p.compa_ratio < 0.90 THEN '1) Under' WHEN p.compa_ratio <= 1.10 THEN '2) At' ELSE '3) Over' END AS pay_position
    FROM pay p
    JOIN perf f ON f.employee_id = p.employee_id
)
SELECT * INTO #talent FROM segments;

SELECT performance, pay_position, COUNT(*) AS employees
FROM #talent
GROUP BY performance, pay_position
ORDER BY performance, pay_position;

-- High performers paid well below their role average: the 10 most underpaid
SELECT TOP 10 t.employee_id,
       CONCAT(e.first_name, ' ', e.last_name) AS employee,
       d.department_name, r.job_title,
       CAST(t.avg_rating AS DECIMAL(4,2))     AS avg_rating,
       t.base_salary,
       CAST(t.role_avg AS DECIMAL(12,0))      AS role_average,
       CAST(t.compa_ratio AS DECIMAL(4,2))    AS compa_ratio
FROM #talent t
JOIN Employees   e ON e.employee_id   = t.employee_id
JOIN Departments d ON d.department_id = t.department_id
JOIN JobRoles    r ON r.job_role_id   = t.job_role_id
WHERE t.performance = '1) High' AND t.pay_position = '1) Under'
ORDER BY t.compa_ratio, t.employee_id;


