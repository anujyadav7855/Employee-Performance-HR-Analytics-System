USE HR_Analytics_DB;
GO
IF EXISTS (SELECT 1 FROM sys.columns
           WHERE object_id = OBJECT_ID('dbo.Employees') AND name = 'date_of_birth' AND is_nullable = 0)
BEGIN
    ALTER TABLE dbo.Employees DROP CONSTRAINT CK_Employees_min_age;
    ALTER TABLE dbo.Employees ALTER COLUMN date_of_birth DATE NULL;
    ALTER TABLE dbo.Employees ADD CONSTRAINT CK_Employees_min_age
        CHECK (DATEADD(YEAR, 18, date_of_birth) <= hire_date);   -- passes when DOB is NULL
END
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;           -- any error rolls back the whole transaction

BEGIN TRY
    BEGIN TRANSACTION;

    -- empty the final tables (children first) and restart identity counters
    DELETE FROM Exits;               DELETE FROM Promotions;
    DELETE FROM PerformanceReviews;  DELETE FROM Attendance;
    DELETE FROM SalaryHistory;       DELETE FROM Employees;
    DELETE FROM JobRoles;            DELETE FROM Departments;
    DBCC CHECKIDENT ('Exits', RESEED, 0)              WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('Promotions', RESEED, 0)         WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('PerformanceReviews', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('Attendance', RESEED, 0)         WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('SalaryHistory', RESEED, 0)      WITH NO_INFOMSGS;

    -- Parent tables keep their SOURCE ids (other tables point to them)
    SET IDENTITY_INSERT Departments ON;
    INSERT INTO Departments (department_id, department_name, location)
    SELECT department_id, department_name, location FROM clean.Departments ORDER BY department_id;
    SET IDENTITY_INSERT Departments OFF;

    SET IDENTITY_INSERT JobRoles ON;
    INSERT INTO JobRoles (job_role_id, job_title, department_id, job_level, min_salary, max_salary)
    SELECT job_role_id, job_title, department_id, job_level, min_salary, max_salary
    FROM clean.JobRoles ORDER BY job_role_id;
    SET IDENTITY_INSERT JobRoles OFF;

    SET IDENTITY_INSERT Employees ON;
    INSERT INTO Employees (employee_id, first_name, last_name, gender, date_of_birth, hire_date,
                           email, city, department_id, job_role_id, manager_id)
    SELECT employee_id, first_name, last_name, gender, date_of_birth, hire_date,
           email, city, department_id, job_role_id, manager_id
    FROM clean.Employees ORDER BY employee_id;
    SET IDENTITY_INSERT Employees OFF;

    -- Child tables get fresh identity ids
    INSERT INTO SalaryHistory (employee_id, effective_date, base_salary, change_reason)
    SELECT employee_id, effective_date, base_salary, change_reason
    FROM clean.SalaryHistory ORDER BY employee_id, effective_date;

    INSERT INTO Attendance (employee_id, attendance_date, status, check_in_time, check_out_time)
    SELECT employee_id, attendance_date, status, check_in_time, check_out_time
    FROM clean.Attendance ORDER BY attendance_date, employee_id;

    INSERT INTO PerformanceReviews (employee_id, reviewer_id, review_period, review_date, rating)
    SELECT employee_id, reviewer_id, review_period, review_date, rating
    FROM clean.PerformanceReviews ORDER BY employee_id, review_period;

    INSERT INTO Promotions (employee_id, promotion_date, old_job_role_id, new_job_role_id)
    SELECT employee_id, promotion_date, old_job_role_id, new_job_role_id
    FROM clean.Promotions ORDER BY promotion_date, employee_id;

    INSERT INTO Exits (employee_id, exit_date, exit_type, exit_reason)
    SELECT employee_id, exit_date, exit_type, exit_reason
    FROM clean.Exits ORDER BY exit_date, employee_id;

    COMMIT TRANSACTION;
    PRINT 'Final load committed.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    PRINT 'LOAD FAILED - rolled back. Final tables unchanged.';
    THROW;
END CATCH;
GO

SELECT 'Departments' AS tbl, COUNT(*) AS final_rows FROM Departments
UNION ALL SELECT 'JobRoles', COUNT(*) FROM JobRoles
UNION ALL SELECT 'Employees', COUNT(*) FROM Employees
UNION ALL SELECT 'SalaryHistory', COUNT(*) FROM SalaryHistory
UNION ALL SELECT 'Attendance', COUNT(*) FROM Attendance
UNION ALL SELECT 'PerformanceReviews', COUNT(*) FROM PerformanceReviews
UNION ALL SELECT 'Promotions', COUNT(*) FROM Promotions
UNION ALL SELECT 'Exits', COUNT(*) FROM Exits;