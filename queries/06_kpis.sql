USE HR_Analytics_DB;
GO

-- A1. Attrition and retention by year (company level)
WITH years AS (
    SELECT yr, DATEFROMPARTS(yr, 1, 1) AS y_start, DATEFROMPARTS(yr, 12, 31) AS y_end
    FROM (VALUES (2022), (2023), (2024), (2025)) v(yr)
),
headcount AS (
    SELECT y.yr,
           (SELECT COUNT(*) FROM Employees e
            WHERE e.hire_date < y.y_start
              AND NOT EXISTS (SELECT 1 FROM Exits x
                              WHERE x.employee_id = e.employee_id AND x.exit_date < y.y_start)) AS opening,
           (SELECT COUNT(*) FROM Employees e
            WHERE e.hire_date <= y.y_end
              AND NOT EXISTS (SELECT 1 FROM Exits x
                              WHERE x.employee_id = e.employee_id AND x.exit_date <= y.y_end))  AS closing
    FROM years y
),
exits_y AS (
    SELECT YEAR(exit_date) AS yr,
           COUNT(*) AS exits,
           SUM(CASE WHEN exit_type = 'Resignation' THEN 1 ELSE 0 END) AS resignations
    FROM Exits
    GROUP BY YEAR(exit_date)
)
SELECT h.yr AS kpi_year,
       h.opening, h.closing,
       (h.opening + h.closing) / 2.0 AS avg_headcount,
       ex.exits,
       CAST(100.0 * ex.exits / ((h.opening + h.closing) / 2.0) AS DECIMAL(5,2))        AS attrition_rate_pct,
       CAST(100.0 - 100.0 * ex.exits / ((h.opening + h.closing) / 2.0) AS DECIMAL(5,2)) AS retention_rate_pct,
       CAST(100.0 * ex.resignations / ((h.opening + h.closing) / 2.0) AS DECIMAL(5,2))  AS voluntary_attrition_pct
FROM headcount h
JOIN exits_y ex ON ex.yr = h.yr
ORDER BY h.yr;

-- A2. Attrition by department and year (28 rows; pivot with conditional aggregation if you want a grid)
WITH grid AS (
    SELECT d.department_id, d.department_name, v.yr,
           DATEFROMPARTS(v.yr, 1, 1) AS y_start, DATEFROMPARTS(v.yr, 12, 31) AS y_end
    FROM Departments d
    CROSS JOIN (VALUES (2022), (2023), (2024), (2025)) v(yr)
),
counts AS (
    SELECT g.department_name, g.yr,
           (SELECT COUNT(*) FROM Employees e
            WHERE e.department_id = g.department_id AND e.hire_date < g.y_start
              AND NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id AND x.exit_date < g.y_start)) AS opening,
           (SELECT COUNT(*) FROM Employees e
            WHERE e.department_id = g.department_id AND e.hire_date <= g.y_end
              AND NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id AND x.exit_date <= g.y_end)) AS closing,
           (SELECT COUNT(*) FROM Exits x JOIN Employees e ON e.employee_id = x.employee_id
            WHERE e.department_id = g.department_id AND x.exit_date BETWEEN g.y_start AND g.y_end) AS exits
    FROM grid g
)
SELECT department_name, yr, opening, closing, exits,
       CAST(100.0 * exits / ((opening + closing) / 2.0) AS DECIMAL(5,2)) AS attrition_rate_pct
FROM counts
ORDER BY department_name, yr;

-- A3. Exits by type and year (voluntary vs involuntary)
SELECT YEAR(exit_date) AS exit_year,
       SUM(CASE WHEN exit_type = 'Resignation' THEN 1 ELSE 0 END) AS resignations,
       SUM(CASE WHEN exit_type = 'Termination' THEN 1 ELSE 0 END) AS terminations,
       SUM(CASE WHEN exit_type = 'Retirement'  THEN 1 ELSE 0 END) AS retirements
FROM Exits
GROUP BY YEAR(exit_date)
ORDER BY exit_year;

-- A4. 12-month retention of new-hire cohorts (only cohorts with a full year observed)
SELECT YEAR(e.hire_date) AS hire_year,
       COUNT(*) AS hires,
       SUM(CASE WHEN DATEDIFF(DAY, e.hire_date, x.exit_date) <= 365 THEN 1 ELSE 0 END) AS left_within_12_months,
       CAST(100.0 * (COUNT(*) - SUM(CASE WHEN DATEDIFF(DAY, e.hire_date, x.exit_date) <= 365 THEN 1 ELSE 0 END))
            / COUNT(*) AS DECIMAL(5,2)) AS retention_12m_pct
FROM Employees e
LEFT JOIN Exits x ON x.employee_id = e.employee_id
WHERE e.hire_date >= '2022-01-01' AND e.hire_date <= '2024-12-31'
GROUP BY YEAR(e.hire_date)
ORDER BY hire_year;

-- A5. Regretted attrition: leavers whose most recent rating was 4 or 5
WITH last_review AS (
    SELECT employee_id, rating,
           ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY review_date DESC) AS rn
    FROM PerformanceReviews
)
SELECT COUNT(*) AS leavers,
       COUNT(lr.employee_id) AS leavers_with_a_review,
       SUM(CASE WHEN lr.rating >= 4 THEN 1 ELSE 0 END) AS last_rating_4_plus,
       CAST(100.0 * SUM(CASE WHEN lr.rating >= 4 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(lr.employee_id), 0) AS DECIMAL(5,2)) AS regretted_attrition_pct,
       SUM(CASE WHEN lr.rating <= 2 THEN 1 ELSE 0 END) AS last_rating_2_or_below
FROM Exits x
LEFT JOIN last_review lr ON lr.employee_id = x.employee_id AND lr.rn = 1;

SELECT 'Active employees (at 2025-12-31)' AS group_name,
       COUNT(*) AS employees,
       CAST(AVG(DATEDIFF(DAY, e.hire_date, '2025-12-31') / 365.25) AS DECIMAL(4,1)) AS avg_tenure_years
FROM Employees e
WHERE NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id)
UNION ALL
SELECT 'Leavers (all)', COUNT(*),
       CAST(AVG(DATEDIFF(DAY, e.hire_date, x.exit_date) / 365.25) AS DECIMAL(4,1))
FROM Exits x JOIN Employees e ON e.employee_id = x.employee_id
UNION ALL
SELECT CONCAT('Leavers: ', x.exit_type), COUNT(*),
       CAST(AVG(DATEDIFF(DAY, e.hire_date, x.exit_date) / 365.25) AS DECIMAL(4,1))
FROM Exits x JOIN Employees e ON e.employee_id = x.employee_id
GROUP BY x.exit_type;

-- C1. Average rating and high-performer % by year
WITH emp_year AS (
    SELECT YEAR(review_date) AS yr, employee_id, AVG(rating * 1.0) AS emp_avg
    FROM PerformanceReviews
    GROUP BY YEAR(review_date), employee_id
),
rating_year AS (
    SELECT YEAR(review_date) AS yr, COUNT(*) AS reviews, AVG(rating * 1.0) AS avg_rating
    FROM PerformanceReviews
    GROUP BY YEAR(review_date)
)
SELECT r.yr AS kpi_year, r.reviews,
       CAST(r.avg_rating AS DECIMAL(4,2)) AS avg_rating,
       COUNT(*) AS employees_reviewed,
       CAST(100.0 * SUM(CASE WHEN ey.emp_avg >= 4.0 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS high_performer_pct
FROM rating_year r
JOIN emp_year ey ON ey.yr = r.yr
GROUP BY r.yr, r.reviews, r.avg_rating
ORDER BY r.yr;

-- C2. Attendance and absenteeism by year
SELECT YEAR(attendance_date) AS kpi_year,
       COUNT(*) AS records,
       CAST(100.0 * SUM(CASE WHEN status = 'Present'  THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS attendance_rate_pct,
       CAST(100.0 * SUM(CASE WHEN status = 'Absent'   THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS absenteeism_rate_pct,
       CAST(100.0 * SUM(CASE WHEN status = 'Leave'    THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS leave_rate_pct,
       CAST(100.0 * SUM(CASE WHEN status = 'Half-Day' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS half_day_pct
FROM Attendance
GROUP BY YEAR(attendance_date)
ORDER BY kpi_year;

-- D1. Promotion rate by year (denominator = average headcount, as defined in Step 0)
WITH years AS (
    SELECT yr, DATEFROMPARTS(yr, 1, 1) AS y_start, DATEFROMPARTS(yr, 12, 31) AS y_end
    FROM (VALUES (2022), (2023), (2024), (2025)) v(yr)
),
headcount AS (
    SELECT y.yr,
           (SELECT COUNT(*) FROM Employees e WHERE e.hire_date < y.y_start
              AND NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id AND x.exit_date < y.y_start))  AS opening,
           (SELECT COUNT(*) FROM Employees e WHERE e.hire_date <= y.y_end
              AND NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id AND x.exit_date <= y.y_end)) AS closing
    FROM years y
),
promo_y AS (
    SELECT YEAR(promotion_date) AS yr, COUNT(DISTINCT employee_id) AS promoted
    FROM Promotions
    GROUP BY YEAR(promotion_date)
)
SELECT h.yr AS kpi_year, p.promoted,
       CAST(100.0 * p.promoted / ((h.opening + h.closing) / 2.0) AS DECIMAL(5,2)) AS promotion_rate_pct
FROM headcount h
JOIN promo_y p ON p.yr = h.yr
ORDER BY h.yr;

-- D2. Payroll, headcount and average salary at each year-end
WITH years AS (
    SELECT yr, DATEFROMPARTS(yr, 12, 31) AS y_end
    FROM (VALUES (2022), (2023), (2024), (2025)) v(yr)
)
SELECT y.yr AS kpi_year,
       COUNT(*)           AS headcount,
       SUM(s.base_salary) AS payroll_cost,
       CAST(AVG(s.base_salary) AS DECIMAL(12,0)) AS avg_salary
FROM years y
JOIN Employees e     ON e.hire_date <= y.y_end
JOIN SalaryHistory s ON s.employee_id = e.employee_id
                    AND s.effective_date = (SELECT MAX(s2.effective_date)
                                            FROM SalaryHistory s2
                                            WHERE s2.employee_id = e.employee_id
                                              AND s2.effective_date <= y.y_end)
WHERE NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id AND x.exit_date <= y.y_end)
GROUP BY y.yr
ORDER BY y.yr;

-- E1. Employees grouped into quartiles of absence rate (2024-2025), with their average rating
WITH att AS (
    SELECT employee_id,
           COUNT(*) AS days,
           SUM(CASE WHEN status = 'Absent' THEN 1 ELSE 0 END) AS absent_days
    FROM Attendance
    WHERE attendance_date >= '2024-01-01'
    GROUP BY employee_id
    HAVING COUNT(*) >= 200                      -- enough days to measure a rate
),
perf AS (
    SELECT employee_id, AVG(rating * 1.0) AS avg_rating
    FROM PerformanceReviews
    WHERE review_period >= '2024-H1'
    GROUP BY employee_id
    HAVING COUNT(*) >= 2
),
joined AS (
    SELECT a.employee_id,
           100.0 * a.absent_days / a.days AS absence_rate_pct,
           p.avg_rating,
           NTILE(4) OVER (ORDER BY 100.0 * a.absent_days / a.days, a.employee_id) AS absence_quartile
    FROM att a
    JOIN perf p ON p.employee_id = a.employee_id
)
SELECT absence_quartile,
       COUNT(*) AS employees,
       CAST(MIN(absence_rate_pct) AS DECIMAL(5,2)) AS lowest_absence_pct,
       CAST(MAX(absence_rate_pct) AS DECIMAL(5,2)) AS highest_absence_pct,
       CAST(AVG(avg_rating) AS DECIMAL(4,2))       AS avg_rating
FROM joined
GROUP BY absence_quartile
ORDER BY absence_quartile;

WITH years AS (
    SELECT yr, DATEFROMPARTS(yr, 1, 1) AS y_start, DATEFROMPARTS(yr, 12, 31) AS y_end
    FROM (VALUES (2022), (2023), (2024), (2025)) v(yr)
),
headcount AS (
    SELECT y.yr,
           (SELECT COUNT(*) FROM Employees e WHERE e.hire_date < y.y_start
              AND NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id AND x.exit_date < y.y_start))  AS opening,
           (SELECT COUNT(*) FROM Employees e WHERE e.hire_date <= y.y_end
              AND NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id AND x.exit_date <= y.y_end)) AS closing
    FROM years y
),
exits_y AS (
    SELECT YEAR(exit_date) AS yr, COUNT(*) AS exits,
           SUM(CASE WHEN exit_type = 'Resignation' THEN 1 ELSE 0 END) AS resignations
    FROM Exits GROUP BY YEAR(exit_date)
),
promo_y AS (
    SELECT YEAR(promotion_date) AS yr, COUNT(DISTINCT employee_id) AS promoted
    FROM Promotions GROUP BY YEAR(promotion_date)
),
emp_year AS (
    SELECT YEAR(review_date) AS yr, employee_id, AVG(rating * 1.0) AS emp_avg
    FROM PerformanceReviews GROUP BY YEAR(review_date), employee_id
),
rating_y AS (
    SELECT YEAR(review_date) AS yr, AVG(rating * 1.0) AS avg_rating
    FROM PerformanceReviews GROUP BY YEAR(review_date)
),
hp_y AS (
    SELECT yr, 100.0 * SUM(CASE WHEN emp_avg >= 4.0 THEN 1 ELSE 0 END) / COUNT(*) AS hp_pct
    FROM emp_year GROUP BY yr
),
att_y AS (
    SELECT YEAR(attendance_date) AS yr,
           100.0 * SUM(CASE WHEN status = 'Present' THEN 1 ELSE 0 END) / COUNT(*) AS attendance_pct,
           100.0 * SUM(CASE WHEN status = 'Absent'  THEN 1 ELSE 0 END) / COUNT(*) AS absenteeism_pct
    FROM Attendance GROUP BY YEAR(attendance_date)
),
pay_y AS (
    SELECT y.yr, SUM(s.base_salary) AS payroll
    FROM years y
    JOIN Employees e     ON e.hire_date <= y.y_end
    JOIN SalaryHistory s ON s.employee_id = e.employee_id
                        AND s.effective_date = (SELECT MAX(s2.effective_date) FROM SalaryHistory s2
                                                WHERE s2.employee_id = e.employee_id AND s2.effective_date <= y.y_end)
    WHERE NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id AND x.exit_date <= y.y_end)
    GROUP BY y.yr
)
SELECT h.yr                                                                   AS kpi_year,
       h.closing                                                              AS headcount_end,
       CAST(100.0 * ex.exits / ((h.opening + h.closing) / 2.0) AS DECIMAL(5,2))        AS attrition_rate_pct,
       CAST(100.0 - 100.0 * ex.exits / ((h.opening + h.closing) / 2.0) AS DECIMAL(5,2)) AS retention_rate_pct,
       CAST(100.0 * ex.resignations / ((h.opening + h.closing) / 2.0) AS DECIMAL(5,2))  AS voluntary_attrition_pct,
       CAST(100.0 * pr.promoted / ((h.opening + h.closing) / 2.0) AS DECIMAL(5,2))      AS promotion_rate_pct,
       CAST(rt.avg_rating AS DECIMAL(4,2))                                    AS avg_rating,
       CAST(hp.hp_pct AS DECIMAL(5,2))                                        AS high_performer_pct,
       CAST(a.attendance_pct AS DECIMAL(5,2))                                 AS attendance_rate_pct,
       CAST(a.absenteeism_pct AS DECIMAL(5,2))                                AS absenteeism_rate_pct,
       p.payroll                                                              AS payroll_cost,
       CAST(1.0 * p.payroll / h.closing AS DECIMAL(12,0))                     AS avg_salary,
       CAST(100.0 * (p.payroll - LAG(p.payroll) OVER (ORDER BY h.yr))
            / LAG(p.payroll) OVER (ORDER BY h.yr) AS DECIMAL(5,2))            AS payroll_growth_pct
FROM headcount h
JOIN exits_y  ex ON ex.yr = h.yr
JOIN promo_y  pr ON pr.yr = h.yr
JOIN rating_y rt ON rt.yr = h.yr
JOIN hp_y     hp ON hp.yr = h.yr
JOIN att_y    a  ON a.yr  = h.yr
JOIN pay_y    p  ON p.yr  = h.yr
ORDER BY h.yr;

