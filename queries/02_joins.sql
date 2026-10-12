USE HR_Analytics_DB;
GO

-- A1. INNER vs LEFT on the manager self join: watch the row count
SELECT COUNT(*) AS inner_join_rows
FROM Employees e
JOIN Employees m ON m.employee_id = e.manager_id;            -- employees WITH a manager

SELECT COUNT(*) AS left_join_rows
FROM Employees e
LEFT JOIN Employees m ON m.employee_id = e.manager_id;       -- all employees

-- A2. Roster with job title, department and manager name (self join + LEFT JOIN)
SELECT TOP 8 e.employee_id,
       CONCAT(e.first_name, ' ', e.last_name) AS employee,
       r.job_title,
       d.department_name,
       ISNULL(m.first_name + ' ' + m.last_name, '(department head)') AS manager
FROM Employees e
JOIN JobRoles    r ON r.job_role_id   = e.job_role_id
JOIN Departments d ON d.department_id = e.department_id
LEFT JOIN Employees m ON m.employee_id = e.manager_id
ORDER BY e.employee_id;

-- A3. Anti-join: employees who were never promoted
SELECT COUNT(*) AS never_promoted
FROM Employees e
LEFT JOIN Promotions p ON p.employee_id = e.employee_id
WHERE p.promotion_id IS NULL;

-- A4. RIGHT JOIN: every job role with its headcount (roles with 0 employees would still show)
SELECT TOP 9 r.job_title, COUNT(e.employee_id) AS employees
FROM Employees e
RIGHT JOIN JobRoles r ON r.job_role_id = e.job_role_id
GROUP BY r.job_title
ORDER BY employees, r.job_title;

-- A5. Team size per manager (self join + aggregate)
SELECT m.employee_id AS manager_id,
       CONCAT(m.first_name, ' ', m.last_name) AS manager,
       d.department_name,
       COUNT(e.employee_id)                           AS direct_reports_ever,
       COUNT(e.employee_id) - COUNT(x.employee_id)    AS active_reports
FROM Employees m
JOIN Departments d ON d.department_id = m.department_id
JOIN Employees   e ON e.manager_id    = m.employee_id
LEFT JOIN Exits  x ON x.employee_id   = e.employee_id
GROUP BY m.employee_id, m.first_name, m.last_name, d.department_name
ORDER BY direct_reports_ever DESC;