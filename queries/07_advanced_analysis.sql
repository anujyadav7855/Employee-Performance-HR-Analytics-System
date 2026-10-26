USE HR_Analytics_DB;
GO

WITH cohort AS (
    SELECT e.employee_id,
           COALESCE(pa.old_job_role_id, e.job_role_id) AS role_at_asof,
           s.base_salary AS salary_at_asof,
           CASE WHEN x.exit_date BETWEEN '2025-01-01' AND '2025-12-31' THEN 1 ELSE 0 END AS left_2025
    FROM dbo.Employees e
    LEFT JOIN dbo.Exits x ON x.employee_id = e.employee_id
    JOIN dbo.SalaryHistory s ON s.employee_id = e.employee_id
         AND s.effective_date = (SELECT MAX(s2.effective_date) FROM dbo.SalaryHistory s2
                                 WHERE s2.employee_id = e.employee_id AND s2.effective_date <= '2024-12-31')
    OUTER APPLY (SELECT TOP 1 p.old_job_role_id FROM dbo.Promotions p
                 WHERE p.employee_id = e.employee_id AND p.promotion_date > '2024-12-31'
                 ORDER BY p.promotion_date) pa
    WHERE e.hire_date <= '2024-12-31' AND (x.exit_date IS NULL OR x.exit_date > '2024-12-31')
),
pay AS (
    SELECT left_2025, salary_at_asof / AVG(salary_at_asof) OVER (PARTITION BY role_at_asof) AS compa_ratio
    FROM cohort
),
banded AS (
    SELECT left_2025,
           CASE WHEN compa_ratio < 0.90 THEN '1) Under 90% of role average'
                WHEN compa_ratio <= 1.10 THEN '2) 90%-110%'
                ELSE '3) Over 110%' END AS pay_band
    FROM pay
)
SELECT pay_band, COUNT(*) AS employees, SUM(left_2025) AS left_in_2025,
       CAST(100.0 * SUM(left_2025) / COUNT(*) AS DECIMAL(5,2)) AS exit_rate_pct
FROM banded
GROUP BY pay_band
ORDER BY pay_band;

WITH cohort AS (
    SELECT e.employee_id, e.hire_date,
           CASE WHEN x.exit_date BETWEEN '2025-01-01' AND '2025-12-31' THEN 1 ELSE 0 END AS left_2025,
           (SELECT MAX(p.promotion_date) FROM dbo.Promotions p
            WHERE p.employee_id = e.employee_id AND p.promotion_date <= '2024-12-31') AS last_promo
    FROM dbo.Employees e
    LEFT JOIN dbo.Exits x ON x.employee_id = e.employee_id
    WHERE e.hire_date <= '2024-12-31' AND (x.exit_date IS NULL OR x.exit_date > '2024-12-31')
),
banded AS (
    SELECT left_2025,
           CASE WHEN DATEDIFF(DAY, ISNULL(last_promo, hire_date), '2024-12-31') / 30.4375 < 12 THEN '1) Under 12 months'
                WHEN DATEDIFF(DAY, ISNULL(last_promo, hire_date), '2024-12-31') / 30.4375 < 36 THEN '2) 12-35 months'
                ELSE '3) 36+ months' END AS months_since_last_change
    FROM cohort
)
SELECT months_since_last_change, COUNT(*) AS employees, SUM(left_2025) AS left_in_2025,
       CAST(100.0 * SUM(left_2025) / COUNT(*) AS DECIMAL(5,2)) AS exit_rate_pct
FROM banded GROUP BY months_since_last_change ORDER BY months_since_last_change;

SELECT d.department_name,
       CONCAT(m.first_name, ' ', m.last_name) AS manager,
       ms.base_salary AS manager_salary,
       CONCAT(e.first_name, ' ', e.last_name) AS report, r.job_title,
       es.base_salary AS report_salary,
       es.base_salary - ms.base_salary AS above_manager
FROM dbo.Employees e
JOIN dbo.Employees m ON m.employee_id = e.manager_id
JOIN dbo.vw_CurrentSalary es ON es.employee_id = e.employee_id
JOIN dbo.vw_CurrentSalary ms ON ms.employee_id = m.employee_id
JOIN dbo.JobRoles    r ON r.job_role_id   = e.job_role_id
JOIN dbo.Departments d ON d.department_id = e.department_id
WHERE NOT EXISTS (SELECT 1 FROM dbo.Exits x WHERE x.employee_id = e.employee_id)
  AND es.base_salary > ms.base_salary
ORDER BY above_manager DESC;

SELECT tenure_band, COUNT(*) AS exits,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS pct_of_exits
FROM (
    SELECT CASE WHEN t.years < 1 THEN '1) Under 1 year'
                WHEN t.years < 3 THEN '2) 1-3 years'
                WHEN t.years < 5 THEN '3) 3-5 years'
                WHEN t.years < 8 THEN '4) 5-8 years'
                ELSE '5) 8+ years' END AS tenure_band
    FROM dbo.Exits x
    JOIN dbo.Employees e ON e.employee_id = x.employee_id
    CROSS APPLY (SELECT DATEDIFF(DAY, e.hire_date, x.exit_date) / 365.25 AS years) t
) b
GROUP BY tenure_band ORDER BY tenure_band;