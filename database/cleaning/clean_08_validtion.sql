USE HR_Analytics_DB;
GO

SELECT check_name, violations,
       CASE WHEN violations = 0 THEN 'PASS' ELSE 'REVIEW' END AS status
FROM (
    SELECT 'Employee department = job role department' AS check_name, COUNT(*) AS violations
    FROM Employees e JOIN JobRoles r ON r.job_role_id = e.job_role_id
    WHERE r.department_id <> e.department_id
    UNION ALL
    SELECT 'Every employee has a salary record', COUNT(*)
    FROM Employees e WHERE NOT EXISTS (SELECT 1 FROM SalaryHistory s WHERE s.employee_id = e.employee_id)
    UNION ALL
    SELECT 'Exit date after hire date', COUNT(*)
    FROM Exits x JOIN Employees e ON e.employee_id = x.employee_id WHERE x.exit_date <= e.hire_date
    UNION ALL
    SELECT 'No attendance before hire', COUNT(*)
    FROM Attendance a JOIN Employees e ON e.employee_id = a.employee_id WHERE a.attendance_date < e.hire_date
    UNION ALL
    SELECT 'No attendance after exit', COUNT(*)
    FROM Attendance a JOIN Exits x ON x.employee_id = a.employee_id WHERE a.attendance_date > x.exit_date
    UNION ALL
    SELECT 'No weekend attendance', COUNT(*)
    FROM Attendance WHERE DATEDIFF(DAY, '19000101', attendance_date) % 7 IN (5, 6)
    UNION ALL
    SELECT 'Present with check-out before check-in', COUNT(*)
    FROM Attendance WHERE check_out_time < check_in_time
    UNION ALL
    SELECT 'Reviews between hire and exit', COUNT(*)
    FROM PerformanceReviews r
    JOIN Employees e ON e.employee_id = r.employee_id
    LEFT JOIN Exits x ON x.employee_id = r.employee_id
    WHERE r.review_date < e.hire_date OR r.review_date > COALESCE(x.exit_date, '9999-12-31')
    UNION ALL
    SELECT 'Reviewer is the employee''s department manager', COUNT(*)
    FROM PerformanceReviews r
    JOIN Employees e  ON e.employee_id = r.employee_id
    JOIN Employees m  ON m.employee_id = r.reviewer_id
    WHERE m.department_id <> e.department_id
    UNION ALL
    SELECT 'Promotion after hire', COUNT(*)
    FROM Promotions p JOIN Employees e ON e.employee_id = p.employee_id WHERE p.promotion_date <= e.hire_date
    UNION ALL
    SELECT 'Current role = new role of latest promotion', COUNT(*)
    FROM Employees e
    CROSS APPLY (SELECT TOP 1 p.new_job_role_id FROM Promotions p
                 WHERE p.employee_id = e.employee_id ORDER BY p.promotion_date DESC) lp
    WHERE e.job_role_id <> lp.new_job_role_id
    UNION ALL
    SELECT 'Outlier: salary above every band in its department', COUNT(*)
    FROM SalaryHistory s JOIN Employees e ON e.employee_id = s.employee_id
    WHERE s.base_salary > (SELECT MAX(r.max_salary) FROM JobRoles r WHERE r.department_id = e.department_id)
    UNION ALL
    SELECT 'Outlier: Present shift under 4 hours', COUNT(*)
    FROM Attendance WHERE status = 'Present' AND DATEDIFF(MINUTE, check_in_time, check_out_time) < 240
) v
ORDER BY status DESC, check_name;

-- What the cleaning did, and what was quarantined
SELECT table_name, issue, action_taken, rows_affected FROM stg.CleaningLog ORDER BY log_id;
SELECT table_name, reason, COUNT(*) AS rows_rejected
FROM stg.RejectedRows GROUP BY table_name, reason ORDER BY table_name, rows_rejected DESC;