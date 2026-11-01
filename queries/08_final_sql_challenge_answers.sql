/* =====================================================================
   FINAL SQL CHALLENGE: ANSWERS (do not open before attempting all 10)
   Database: HR_Analytics_DB (SQL Server)
   The "expected" results were computed by re-running the project's cleaning
   rules on the dataset. If yours differ by a small amount, check your
   cleaning choices; if they differ a lot, check your logic.
   Several solutions are possible; any query that returns the same result
   is correct.
   ===================================================================== */
USE HR_Analytics_DB;
GO

/* ---------------------------------------------------------------------
   P1: Resignation tenure
   Technique: join, filter before grouping (WHERE), filter groups (HAVING),
   date arithmetic.
   --------------------------------------------------------------------- */
SELECT d.department_name,
       COUNT(*) AS resignations,
       CAST(AVG(DATEDIFF(DAY, e.hire_date, x.exit_date) / 365.25) AS DECIMAL(4,1)) AS avg_tenure_years
FROM dbo.Exits x
JOIN dbo.Employees   e ON e.employee_id   = x.employee_id
JOIN dbo.Departments d ON d.department_id = e.department_id
WHERE x.exit_type = 'Resignation'
GROUP BY d.department_name
HAVING COUNT(*) >= 5
ORDER BY avg_tenure_years DESC, d.department_name;
/* Expected (6 rows; HR is excluded because it has fewer than 5):
   Operations        13   6.0
   IT                20   4.8
   Marketing          6   4.3
   Customer Support  14   4.0
   Sales             35   4.0
   Finance            6   3.2
   Note: dividing by 365.25 (not 365) keeps leap years from skewing the result. */
GO

/* ---------------------------------------------------------------------
   P2: Hires and exits by department and year
   Technique: build a grid with CROSS JOIN so zero rows appear, then count.
   --------------------------------------------------------------------- */
WITH years AS (
    SELECT yr FROM (VALUES (2022), (2023), (2024), (2025)) v(yr)
),
grid AS (
    SELECT d.department_id, d.department_name, y.yr
    FROM dbo.Departments d CROSS JOIN years y
),
counts AS (
    SELECT g.department_name, g.yr,
           (SELECT COUNT(*) FROM dbo.Employees e
            WHERE e.department_id = g.department_id AND YEAR(e.hire_date) = g.yr) AS hires,
           (SELECT COUNT(*) FROM dbo.Exits x
            JOIN dbo.Employees e ON e.employee_id = x.employee_id
            WHERE e.department_id = g.department_id AND YEAR(x.exit_date) = g.yr) AS exits
    FROM grid g
)
SELECT department_name, yr, hires, exits, hires - exits AS net_change
FROM counts
ORDER BY department_name, yr;
/* Expected: 28 rows. Hires / exits by year (2022, 2023, 2024, 2025):
   Customer Support   hires 3, 6, 4, 4     exits 1, 3, 5, 6
   Finance            hires 4, 2, 1, 1     exits 1, 2, 2, 2
   HR                 hires 3, 1, 1, 0     exits 1, 0, 0, 1
   IT                 hires 8, 8, 7, 5     exits 6, 5, 5, 8
   Marketing          hires 5, 7, 5, 1     exits 0, 2, 2, 3
   Operations         hires 9, 7, 5, 3     exits 2, 6, 3, 6
   Sales              hires 13, 10, 9, 5   exits 11, 7, 12, 7
   Check: column totals by year are hires 45, 41, 32, 19 and exits 22, 25, 29, 33
   (net +23, +16, +3, -14), matching the KPI scorecard. */
GO

/* ---------------------------------------------------------------------
   P3: Consecutive top ratings
   Technique: LAG within each employee, ordered by review period.
   --------------------------------------------------------------------- */
WITH seq AS (
    SELECT employee_id, review_period, rating,
           LAG(rating) OVER (PARTITION BY employee_id ORDER BY review_period) AS prev_rating
    FROM dbo.PerformanceReviews
)
SELECT COUNT(*) AS consecutive_pairs,
       COUNT(DISTINCT employee_id) AS employees
FROM seq
WHERE rating = 5 AND prev_rating = 5;
/* Expected: consecutive_pairs = 62, employees = 34.
   (Employee 4, Kritika Verma, has two such pairs: 2024-H2/2025-H1 and 2025-H1/2025-H2.) */
GO

/* ---------------------------------------------------------------------
   P4: Well paid and well rated
   Technique: window average per department over ACTIVE staff, a rated
   CTE with HAVING, then a join.
   --------------------------------------------------------------------- */
WITH rated AS (
    SELECT employee_id
    FROM dbo.PerformanceReviews
    GROUP BY employee_id
    HAVING COUNT(*) >= 4 AND AVG(rating * 1.0) >= 4.0
),
staff AS (
    SELECT employee_id, department_id, base_salary,
           AVG(base_salary) OVER (PARTITION BY department_id) AS dept_avg_salary
    FROM dbo.vw_ActiveStaff
)
SELECT s.employee_id,
       CONCAT(e.first_name, ' ', e.last_name) AS employee,
       d.department_name,
       s.base_salary AS current_salary
FROM staff s
JOIN rated r ON r.employee_id = s.employee_id
JOIN dbo.Employees   e ON e.employee_id   = s.employee_id
JOIN dbo.Departments d ON d.department_id = s.department_id
WHERE s.base_salary > s.dept_avg_salary
ORDER BY s.base_salary DESC, s.employee_id;
/* Expected: 33 rows (Customer Support 5, Finance 1, HR 4, IT 6, Marketing 5,
   Operations 6, Sales 6). The first five rows:
   112  Neeraj Kohli      IT   2,487,000
    38  Deepak Kulkarni   IT   1,841,000
   118  Manish Mukherjee  IT   1,755,000
   150  Mayank Sethi      IT   1,678,000
   287  Naveen Chopra     IT   1,510,000
   Note: the department average includes the department manager's salary, and
   managers are not reviewed, so they never appear in the result. */
GO

/* ---------------------------------------------------------------------
   P5: Worst absence month of each year
   Technique: aggregate to year-month, ROW_NUMBER per year, keep rn = 1.
   --------------------------------------------------------------------- */
WITH monthly AS (
    SELECT YEAR(attendance_date)  AS yr,
           MONTH(attendance_date) AS month_no,
           CAST(100.0 * SUM(CASE WHEN status = 'Absent' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS absenteeism_rate_pct
    FROM dbo.Attendance
    GROUP BY YEAR(attendance_date), MONTH(attendance_date)
),
ranked AS (
    SELECT yr, month_no, absenteeism_rate_pct,
           ROW_NUMBER() OVER (PARTITION BY yr ORDER BY absenteeism_rate_pct DESC, month_no) AS rn
    FROM monthly
)
SELECT yr, month_no, absenteeism_rate_pct
FROM ranked
WHERE rn = 1
ORDER BY yr;
/* Expected:
   2022   8 (August)    3.08
   2023  10 (October)   3.04
   2024   4 (April)     3.06
   2025   2 (February)  3.27
   Note: the monthly rates never differ by more than about half a percentage point,
   so "worst month" is a weak signal. */
GO

/* ---------------------------------------------------------------------
   P6: Running total of exits
   Technique: aggregate by month, then SUM() OVER with a running frame.
   --------------------------------------------------------------------- */
WITH m AS (
    SELECT MONTH(exit_date) AS month_no, COUNT(*) AS exits
    FROM dbo.Exits
    WHERE exit_date >= '2025-01-01' AND exit_date < '2026-01-01'
    GROUP BY MONTH(exit_date)
)
SELECT month_no, exits,
       SUM(exits) OVER (ORDER BY month_no ROWS UNBOUNDED PRECEDING) AS cumulative_exits
FROM m
ORDER BY month_no;
/* Expected (12 rows):
   month   1   2   3   4   5   6   7   8   9  10  11  12
   exits   2   4   3   3   2   3   5   3   2   3   1   2
   cumul.  2   6   9  12  14  17  22  25  27  30  31  33
   Note: if a month had no exits it would be missing; to include it, join to a month list. */
GO

/* ---------------------------------------------------------------------
   P7: Big first-promotion raises
   Technique: MIN per employee, join salary on the promotion date, correlated
   MAX for the previous record.
   --------------------------------------------------------------------- */
WITH first_promo AS (
    SELECT employee_id, MIN(promotion_date) AS promotion_date
    FROM dbo.Promotions
    GROUP BY employee_id
),
raises AS (
    SELECT fp.employee_id,
           100.0 * (n.base_salary - pv.base_salary) / pv.base_salary AS raise_pct
    FROM first_promo fp
    JOIN dbo.SalaryHistory n  ON n.employee_id  = fp.employee_id
                             AND n.effective_date = fp.promotion_date
    JOIN dbo.SalaryHistory pv ON pv.employee_id = fp.employee_id
                             AND pv.effective_date = (SELECT MAX(s2.effective_date)
                                                      FROM dbo.SalaryHistory s2
                                                      WHERE s2.employee_id = fp.employee_id
                                                        AND s2.effective_date < fp.promotion_date)
)
SELECT r.employee_id,
       CONCAT(e.first_name, ' ', e.last_name) AS employee,
       d.department_name,
       CAST(r.raise_pct AS DECIMAL(5,2)) AS raise_pct
FROM raises r
JOIN dbo.Employees   e ON e.employee_id   = r.employee_id
JOIN dbo.Departments d ON d.department_id = e.department_id
WHERE r.raise_pct > 30
ORDER BY r.raise_pct DESC, r.employee_id;
/* Expected: 22 rows (of 118 employees whose first promotion could be measured).
   The first five rows:
   293  Komal Rathore   Marketing   62.60
   353  Trisha Joshi     HR          61.29
   264  Harsh Mehta      Operations  59.57
    83  Tushar Menon     HR          53.06
   329  Sunita Desai     Sales       52.28 */
GO

/* ---------------------------------------------------------------------
   P8: Departments where ratings fell
   Technique: yearly average per department, LAG across years, filter.
   --------------------------------------------------------------------- */
WITH yearly AS (
    SELECT d.department_name,
           YEAR(r.review_date) AS yr,
           AVG(r.rating * 1.0) AS avg_rating
    FROM dbo.PerformanceReviews r
    JOIN dbo.Employees   e ON e.employee_id   = r.employee_id
    JOIN dbo.Departments d ON d.department_id = e.department_id
    WHERE r.review_date >= '2024-01-01' AND r.review_date < '2026-01-01'
    GROUP BY d.department_name, YEAR(r.review_date)
),
cmp AS (
    SELECT department_name, yr, avg_rating,
           LAG(avg_rating) OVER (PARTITION BY department_name ORDER BY yr) AS prev_avg
    FROM yearly
)
SELECT department_name,
       CAST(prev_avg   AS DECIMAL(4,2)) AS avg_2024,
       CAST(avg_rating AS DECIMAL(4,2)) AS avg_2025
FROM cmp
WHERE yr = 2025 AND avg_rating < prev_avg
ORDER BY avg_rating - prev_avg;
/* Expected (3 rows):
   Customer Support   3.77   3.59
   HR                 3.94   3.79
   Marketing          3.24   3.17 */
GO

/* ---------------------------------------------------------------------
   P9: Hired 2023, still here, never promoted
   Technique: NOT EXISTS twice (an anti-join), grouped count.
   --------------------------------------------------------------------- */
SELECT d.department_name, COUNT(*) AS employees
FROM dbo.Employees e
JOIN dbo.Departments d ON d.department_id = e.department_id
WHERE e.hire_date >= '2023-01-01' AND e.hire_date < '2024-01-01'
  AND NOT EXISTS (SELECT 1 FROM dbo.Exits x       WHERE x.employee_id = e.employee_id)
  AND NOT EXISTS (SELECT 1 FROM dbo.Promotions p  WHERE p.employee_id = e.employee_id)
GROUP BY d.department_name
ORDER BY employees DESC, d.department_name;
/* Expected (6 rows, total 25):
   Operations 7, IT 5, Marketing 5, Sales 4, Customer Support 3, Finance 1
   (HR has none.) */
GO

/* ---------------------------------------------------------------------
   P10: Exit reasons and tenure
   Technique: filter NULLs, group, HAVING, date arithmetic.
   --------------------------------------------------------------------- */
SELECT x.exit_reason,
       COUNT(*) AS exits,
       CAST(AVG(DATEDIFF(DAY, e.hire_date, x.exit_date) / 365.25) AS DECIMAL(4,1)) AS avg_tenure_years
FROM dbo.Exits x
JOIN dbo.Employees e ON e.employee_id = x.employee_id
WHERE x.exit_reason IS NOT NULL
GROUP BY x.exit_reason
HAVING COUNT(*) >= 5
ORDER BY exits DESC, x.exit_reason;
/* Expected (6 rows):
   Better Pay           24   3.2
   Work-Life Balance    24   5.1
   Career Growth        17   5.1
   Personal Reasons      7   4.4
   Management Issues     5   6.3
   Performance           5   3.8
   Note: people who leave for "Better Pay" have the shortest average tenure (3.2 years),
   while those citing Work-Life Balance or Career Growth have about 5 years. */
GO
