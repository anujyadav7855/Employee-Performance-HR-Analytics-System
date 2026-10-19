USE HR_Analytics_DB;
GO

/* ===== Views ===== */
SELECT COUNT(*) AS current_salary_rows FROM dbo.vw_CurrentSalary;                      -- 400
SELECT employment_status, COUNT(*) AS employees FROM dbo.vw_EmployeeDetails
GROUP BY employment_status;                                                            -- Active 291, Exited 109
SELECT COUNT(*) AS active_staff FROM dbo.vw_ActiveStaff;                               -- 291
SELECT COUNT(*) AS directory_rows FROM dbo.vw_EmployeeDirectory;                       -- 291
SELECT * FROM dbo.vw_KpiScorecard ORDER BY kpi_year;                                   -- must equal Day 10's table

/* ===== Functions ===== */
SELECT dbo.fn_AgeOn('1990-06-15', '2025-12-31') AS age_1;   -- 35
SELECT dbo.fn_AgeOn('2000-12-31', '2025-12-30') AS age_2;   -- 24 (birthday not yet reached)
SELECT dbo.fn_AgeOn(NULL,         '2025-12-31') AS age_3;   -- NULL
SELECT COUNT(*) AS active_2021 FROM dbo.fn_ActiveEmployeesAsOf('2021-12-31');  -- 263
SELECT COUNT(*) AS active_2023 FROM dbo.fn_ActiveEmployeesAsOf('2023-12-31');  -- 302
SELECT COUNT(*) AS active_2025 FROM dbo.fn_ActiveEmployeesAsOf('2025-12-31');  -- 291

/* ===== Procedures: reports ===== */
EXEC dbo.usp_GetEmployeeProfile @EmployeeId = 112;
EXEC dbo.usp_TopPerformers;
EXEC dbo.usp_TopPerformers @TopN = 5, @DepartmentName = 'Sales';
EXEC dbo.usp_AttritionByDepartment @Year = 2025;

/* ===== Procedures: errors (run each statement on its own) ===== */
EXEC dbo.usp_GetEmployeeProfile @EmployeeId = 9999;                      -- Employee not found.
EXEC dbo.usp_AttritionByDepartment @Year = 2030;                         -- Year must be between 2022 and 2025...
EXEC dbo.usp_PromoteEmployee 9999, 36, 790000, '2025-12-15';             -- Employee does not exist.
EXEC dbo.usp_PromoteEmployee 1,    10, 900000, '2025-12-15';             -- not active
EXEC dbo.usp_PromoteEmployee 112,   5, 3000000,'2025-12-15';             -- role from another department
EXEC dbo.usp_PromoteEmployee 4,    35, 790000, '2025-12-15';             -- same role
EXEC dbo.usp_PromoteEmployee 4,    36, 600000, '2025-12-15';             -- salary not higher
EXEC dbo.usp_PromoteEmployee 4,    36, 790000, '2025-01-01';             -- date before latest salary change

/* ===== The transaction + audit trigger, then undo everything ===== */
BEGIN TRANSACTION;
    EXEC dbo.usp_PromoteEmployee @EmployeeId = 4, @NewJobRoleId = 36,
                                 @NewSalary = 790000, @PromotionDate = '2025-12-15';
    SELECT employee_id, changed_column, old_value, new_value FROM dbo.EmployeeChangeLog WHERE employee_id = 4;
    SELECT job_title FROM dbo.vw_EmployeeDetails WHERE employee_id = 4;
ROLLBACK TRANSACTION;
SELECT job_role_id FROM dbo.Employees WHERE employee_id = 4;               -- back to 35
SELECT COUNT(*) AS log_rows FROM dbo.EmployeeChangeLog;                    -- 0

/* ===== Trigger: untracked column change must NOT be logged ===== */
BEGIN TRANSACTION;
    UPDATE dbo.Employees SET city = 'Pune' WHERE employee_id = 4;
    SELECT COUNT(*) AS log_rows_after_city_change FROM dbo.EmployeeChangeLog;   -- 0
ROLLBACK TRANSACTION;

/* ===== Trigger: exit before hire date is blocked ===== */
BEGIN TRY
    INSERT INTO dbo.Exits (employee_id, exit_date, exit_type) VALUES (3, '2010-01-01', 'Resignation');
    PRINT 'UNEXPECTED SUCCESS';
END TRY
BEGIN CATCH
    PRINT 'Blocked: ' + ERROR_MESSAGE();
END CATCH;
SELECT COUNT(*) AS exits_still FROM dbo.Exits; 

USE HR_Analytics_DB;
SELECT COUNT(*) AS employees FROM dbo.Employees;                        -- expect 400
SELECT TOP 5 employee_id, first_name, last_name FROM dbo.Employees ORDER BY employee_id;
SELECT COUNT(*) AS rows_in_clean_layer FROM clean.Employees;            -- expect 400