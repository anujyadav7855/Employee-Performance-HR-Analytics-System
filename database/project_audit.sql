/* =====================================================================
   Project : Employee Performance & HR Analytics System
   File    : database/project_audit.sql
   Purpose : Final audit. Checks structure, data, business rules and KPIs
             and prints PASS / REVIEW for each check.
   Notes   : "expected" values come from the verified build of this project.
             REVIEW means INVESTIGATE, not necessarily "bug". If your cleaning
             choices legitimately differ, document why and update the expected value.
   ===================================================================== */
USE HR_Analytics_DB;
GO
SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#audit') IS NOT NULL DROP TABLE #audit;
CREATE TABLE #audit (
    check_no    INT IDENTITY(1,1),
    check_group VARCHAR(20),
    check_name  VARCHAR(90),
    expected    INT,
    actual      INT,
    rule_type   VARCHAR(5)          -- 'EQ' = must equal expected, 'MAX' = must be <= expected
);

/* ---------------- 1. STRUCTURE ---------------- */
INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Structure', 'Tables in dbo (8 core + EmployeeChangeLog)', 9, COUNT(*), 'EQ'
FROM sys.tables WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name <> 'sysdiagrams';

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Structure', 'Primary keys', 9, COUNT(*), 'EQ'
FROM sys.key_constraints
WHERE type = 'PK' AND SCHEMA_NAME(schema_id) = 'dbo' AND OBJECT_NAME(parent_object_id) <> 'sysdiagrams';

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Structure', 'Unique constraints', 7, COUNT(*), 'EQ'
FROM sys.key_constraints
WHERE type = 'UQ' AND SCHEMA_NAME(schema_id) = 'dbo';

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Structure', 'Foreign keys (12 core + 1 audit table)', 13, COUNT(*), 'EQ'
FROM sys.foreign_keys
WHERE SCHEMA_NAME(schema_id) = 'dbo' AND OBJECT_NAME(parent_object_id) <> 'sysdiagrams';

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Structure', 'Check constraints', 14, COUNT(*), 'EQ'
FROM sys.check_constraints WHERE SCHEMA_NAME(schema_id) = 'dbo';

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Structure', 'Default constraints (2 core + 2 audit table)', 4, COUNT(*), 'EQ'
FROM sys.default_constraints WHERE SCHEMA_NAME(schema_id) = 'dbo';

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Structure', 'Added indexes (IX_*)', 4, COUNT(*), 'EQ'
FROM sys.indexes i
JOIN sys.objects o ON o.object_id = i.object_id
WHERE SCHEMA_NAME(o.schema_id) = 'dbo' AND o.type = 'U' AND i.name LIKE 'IX[_]%';

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Structure', 'Views', 5, COUNT(*), 'EQ'
FROM sys.views WHERE SCHEMA_NAME(schema_id) = 'dbo';

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Structure', 'Functions', 2, COUNT(*), 'EQ'
FROM sys.objects WHERE type IN ('FN', 'IF', 'TF') AND SCHEMA_NAME(schema_id) = 'dbo';

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Structure', 'Stored procedures (usp_*)', 4, COUNT(*), 'EQ'
FROM sys.procedures WHERE SCHEMA_NAME(schema_id) = 'dbo' AND name LIKE 'usp[_]%';

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Structure', 'Triggers enabled', 3, COUNT(*), 'EQ'
FROM sys.triggers WHERE is_ms_shipped = 0 AND parent_class = 1 AND is_disabled = 0;

/* ---------------- 2. ROW COUNTS ---------------- */
INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Row counts', 'Departments', 7, COUNT(*), 'EQ' FROM dbo.Departments
UNION ALL SELECT 'Row counts', 'JobRoles', 37, COUNT(*), 'EQ' FROM dbo.JobRoles
UNION ALL SELECT 'Row counts', 'Employees', 400, COUNT(*), 'EQ' FROM dbo.Employees
UNION ALL SELECT 'Row counts', 'SalaryHistory', 1775, COUNT(*), 'EQ' FROM dbo.SalaryHistory
UNION ALL SELECT 'Row counts', 'Attendance', 296726, COUNT(*), 'EQ' FROM dbo.Attendance
UNION ALL SELECT 'Row counts', 'PerformanceReviews', 2206, COUNT(*), 'EQ' FROM dbo.PerformanceReviews
UNION ALL SELECT 'Row counts', 'Promotions', 132, COUNT(*), 'EQ' FROM dbo.Promotions
UNION ALL SELECT 'Row counts', 'Exits', 109, COUNT(*), 'EQ' FROM dbo.Exits;

/* ---------------- 3. DATA QUALITY / BUSINESS RULES (0 violations expected) ---------------- */
INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Business rules', 'Employee department = department of job role', 0, COUNT(*), 'MAX'
FROM dbo.Employees e JOIN dbo.JobRoles r ON r.job_role_id = e.job_role_id
WHERE r.department_id <> e.department_id;

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Business rules', 'Every employee has at least one salary record', 0, COUNT(*), 'MAX'
FROM dbo.Employees e
WHERE NOT EXISTS (SELECT 1 FROM dbo.SalaryHistory s WHERE s.employee_id = e.employee_id);

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Business rules', 'Exit date after hire date', 0, COUNT(*), 'MAX'
FROM dbo.Exits x JOIN dbo.Employees e ON e.employee_id = x.employee_id
WHERE x.exit_date <= e.hire_date;

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Business rules', 'No attendance before hire', 0, COUNT(*), 'MAX'
FROM dbo.Attendance a JOIN dbo.Employees e ON e.employee_id = a.employee_id
WHERE a.attendance_date < e.hire_date;

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Business rules', 'No attendance after exit', 0, COUNT(*), 'MAX'
FROM dbo.Attendance a JOIN dbo.Exits x ON x.employee_id = a.employee_id
WHERE a.attendance_date > x.exit_date;

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Business rules', 'No weekend attendance', 0, COUNT(*), 'MAX'
FROM dbo.Attendance
WHERE DATEDIFF(DAY, '19000101', attendance_date) % 7 IN (5, 6);

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Business rules', 'Reviews dated between hire and exit', 0, COUNT(*), 'MAX'
FROM dbo.PerformanceReviews r
JOIN dbo.Employees e ON e.employee_id = r.employee_id
LEFT JOIN dbo.Exits x ON x.employee_id = r.employee_id
WHERE r.review_date < e.hire_date OR r.review_date > COALESCE(x.exit_date, '9999-12-31');

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Business rules', 'Reviewer belongs to the employee''s department', 0, COUNT(*), 'MAX'
FROM dbo.PerformanceReviews r
JOIN dbo.Employees e ON e.employee_id = r.employee_id
JOIN dbo.Employees m ON m.employee_id = r.reviewer_id
WHERE m.department_id <> e.department_id;

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Business rules', 'Promotion after hire date', 0, COUNT(*), 'MAX'
FROM dbo.Promotions p JOIN dbo.Employees e ON e.employee_id = p.employee_id
WHERE p.promotion_date <= e.hire_date;

-- Up to 2 are expected: they trace back to the two same-role promotions quarantined on Day 6
INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Business rules', 'Current role = new role of latest promotion (max 2, see Day 6)', 2, COUNT(*), 'MAX'
FROM dbo.Employees e
CROSS APPLY (SELECT TOP 1 p.new_job_role_id FROM dbo.Promotions p
             WHERE p.employee_id = e.employee_id ORDER BY p.promotion_date DESC) lp
WHERE e.job_role_id <> lp.new_job_role_id;

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Business rules', 'Employees with unknown date of birth (kept as NULL)', 3, COUNT(*), 'EQ'
FROM dbo.Employees WHERE date_of_birth IS NULL;

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'Business rules', 'Audit log rows (0 unless you made real changes)', 0, COUNT(*), 'MAX'
FROM dbo.EmployeeChangeLog;

/* ---------------- 4. KPIs ---------------- */
INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'KPI', 'Scorecard rows (2022-2025)', 4, COUNT(*), 'EQ' FROM dbo.vw_KpiScorecard;

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'KPI', 'Year-end 2025 headcount', 291, headcount_end, 'EQ'
FROM dbo.vw_KpiScorecard WHERE kpi_year = 2025;

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'KPI', '2025 attrition rate x 100 (11.07%)', 1107, CAST(attrition_rate_pct * 100 AS INT), 'EQ'
FROM dbo.vw_KpiScorecard WHERE kpi_year = 2025;

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'KPI', 'Active staff in vw_ActiveStaff (400 - 109 exits)', 291, COUNT(*), 'EQ'
FROM dbo.vw_ActiveStaff;

INSERT INTO #audit (check_group, check_name, expected, actual, rule_type)
SELECT 'KPI', 'Active employees as of 2023-12-31 (function)', 302, COUNT(*), 'EQ'
FROM dbo.fn_ActiveEmployeesAsOf('2023-12-31');

/* ---------------- RESULT ---------------- */
SELECT check_no, check_group, check_name, expected, actual,
       CASE WHEN (rule_type = 'EQ'  AND actual = expected)
              OR (rule_type = 'MAX' AND actual <= expected) THEN 'PASS' ELSE 'REVIEW' END AS status
FROM #audit
ORDER BY check_no;

SELECT SUM(CASE WHEN (rule_type = 'EQ'  AND actual = expected)
                  OR (rule_type = 'MAX' AND actual <= expected) THEN 1 ELSE 0 END) AS passed,
       SUM(CASE WHEN (rule_type = 'EQ'  AND actual <> expected)
                  OR (rule_type = 'MAX' AND actual > expected) THEN 1 ELSE 0 END)  AS to_review,
       COUNT(*) AS total_checks
FROM #audit;

DROP TABLE #audit;
GO
