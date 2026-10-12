USE HR_Analytics_DB;
GO

-- B1. Scalar subquery: reviews above the company's overall average rating
SELECT CAST((SELECT AVG(rating * 1.0) FROM PerformanceReviews) AS DECIMAL(4,2)) AS overall_avg,
       COUNT(*) AS reviews_above_avg
FROM PerformanceReviews
WHERE rating > (SELECT AVG(rating * 1.0) FROM PerformanceReviews);

-- B2. IN subquery: employees who ever received a rating of 5
SELECT COUNT(*) AS employees_ever_rated_5
FROM Employees
WHERE employee_id IN (SELECT employee_id FROM PerformanceReviews WHERE rating = 5);

-- B3. The NOT IN trap: employees who are not anyone's manager
SELECT COUNT(*) AS not_in_result
FROM Employees
WHERE employee_id NOT IN (SELECT manager_id FROM Employees);          -- manager_id contains NULLs!

SELECT COUNT(*) AS not_exists_result
FROM Employees e
WHERE NOT EXISTS (SELECT 1 FROM Employees r WHERE r.manager_id = e.employee_id);

-- correlated subquery and exists--

-- C1. Current salary = the LATEST salary record (correlated subquery)
--     Top 10 active employees by current salary
SELECT TOP 10 e.employee_id,
       CONCAT(e.first_name, ' ', e.last_name) AS employee,
       d.department_name, r.job_title,
       s.base_salary AS current_salary
FROM Employees e
JOIN SalaryHistory s ON s.employee_id   = e.employee_id
JOIN Departments   d ON d.department_id = e.department_id
JOIN JobRoles      r ON r.job_role_id   = e.job_role_id
WHERE s.effective_date = (SELECT MAX(s2.effective_date)
                          FROM SalaryHistory s2
                          WHERE s2.employee_id = s.employee_id)          -- correlated
  AND NOT EXISTS (SELECT 1 FROM Exits x WHERE x.employee_id = e.employee_id)
ORDER BY s.base_salary DESC, e.employee_id;

-- C2. Raise on promotion (Q7): salary on the promotion date vs the record just before it
SELECT COUNT(*) AS promotions_measured,
       CAST(AVG((n.base_salary - pv.base_salary) * 100.0 / pv.base_salary) AS DECIMAL(5,2)) AS avg_raise_pct,
       CAST(MIN((n.base_salary - pv.base_salary) * 100.0 / pv.base_salary) AS DECIMAL(5,2)) AS min_raise_pct,
       CAST(MAX((n.base_salary - pv.base_salary) * 100.0 / pv.base_salary) AS DECIMAL(5,2)) AS max_raise_pct
FROM Promotions p
JOIN SalaryHistory n  ON n.employee_id  = p.employee_id AND n.effective_date = p.promotion_date
JOIN SalaryHistory pv ON pv.employee_id = p.employee_id
                     AND pv.effective_date = (SELECT MAX(s2.effective_date)
                                              FROM SalaryHistory s2
                                              WHERE s2.employee_id = p.employee_id
                                                AND s2.effective_date < p.promotion_date);

-- C3. EXISTS: promoted AND later left the company
SELECT COUNT(*) AS promoted_then_left
FROM Employees e
WHERE EXISTS (SELECT 1 FROM Promotions p WHERE p.employee_id = e.employee_id)
  AND EXISTS (SELECT 1 FROM Exits      x WHERE x.employee_id = e.employee_id);

-- C4. NOT EXISTS + CASE: why were some employees never reviewed?
WITH unreviewed AS (
    SELECT e.employee_id,
           CASE WHEN e.manager_id IS NULL        THEN 'Department head (not reviewed)'
                WHEN x.employee_id IS NOT NULL   THEN 'Left before first review'
                ELSE 'Hired too recently' END AS reason
    FROM Employees e
    LEFT JOIN Exits x ON x.employee_id = e.employee_id
    WHERE NOT EXISTS (SELECT 1 FROM PerformanceReviews r WHERE r.employee_id = e.employee_id)
)
SELECT reason, COUNT(*) AS employees
FROM unreviewed
GROUP BY reason
ORDER BY employees DESC;