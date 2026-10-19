USE HR_Analytics_DB;
GO

/* ---- 1. Everything about one employee (4 result sets) ---- */
CREATE OR ALTER PROCEDURE dbo.usp_GetEmployeeProfile
    @EmployeeId INT
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Employees WHERE employee_id = @EmployeeId)
    BEGIN
        THROW 50001, 'Employee not found.', 1;
    END;

    SELECT employee_id, full_name, department_name, job_title, job_level, manager_name,
           hire_date, city, current_salary, employment_status, exit_date, exit_type, exit_reason
    FROM dbo.vw_EmployeeDetails
    WHERE employee_id = @EmployeeId;

    SELECT effective_date, base_salary, change_reason
    FROM dbo.SalaryHistory WHERE employee_id = @EmployeeId ORDER BY effective_date;

    SELECT review_period, review_date, rating
    FROM dbo.PerformanceReviews WHERE employee_id = @EmployeeId ORDER BY review_period;

    SELECT p.promotion_date, ro.job_title AS from_role, rn.job_title AS to_role
    FROM dbo.Promotions p
    JOIN dbo.JobRoles ro ON ro.job_role_id = p.old_job_role_id
    JOIN dbo.JobRoles rn ON rn.job_role_id = p.new_job_role_id
    WHERE p.employee_id = @EmployeeId
    ORDER BY p.promotion_date;
END;
GO

/* ---- 2. Top performers, with optional filters (defaults reproduce Day 7 query D3) ---- */
CREATE OR ALTER PROCEDURE dbo.usp_TopPerformers
    @TopN INT = 10,
    @MinReviews INT = 6,
    @DepartmentName VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @TopN < 1 OR @TopN > 100
    BEGIN
        THROW 50002, '@TopN must be between 1 and 100.', 1;
    END;
    IF @DepartmentName IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM dbo.Departments WHERE department_name = @DepartmentName)
    BEGIN
        THROW 50003, 'Unknown department name.', 1;
    END;

    SELECT TOP (@TopN) r.employee_id,
           CONCAT(e.first_name, ' ', e.last_name) AS employee,
           d.department_name,
           COUNT(*) AS reviews,
           CAST(AVG(r.rating * 1.0) AS DECIMAL(4,2)) AS avg_rating
    FROM dbo.PerformanceReviews r
    JOIN dbo.Employees   e ON e.employee_id   = r.employee_id
    JOIN dbo.Departments d ON d.department_id = e.department_id
    WHERE (@DepartmentName IS NULL OR d.department_name = @DepartmentName)
    GROUP BY r.employee_id, e.first_name, e.last_name, d.department_name
    HAVING COUNT(*) >= @MinReviews
    ORDER BY AVG(r.rating * 1.0) DESC, COUNT(*) DESC, r.employee_id;
END;
GO

/* ---- 3. Attrition by department for a year ---- */
CREATE OR ALTER PROCEDURE dbo.usp_AttritionByDepartment
    @Year INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @Year NOT BETWEEN 2022 AND 2025
    BEGIN
        THROW 50004, 'Year must be between 2022 and 2025 (the data period).', 1;
    END;

    DECLARE @start DATE = DATEFROMPARTS(@Year, 1, 1),
            @end   DATE = DATEFROMPARTS(@Year, 12, 31);

    WITH c AS (
        SELECT d.department_name,
               SUM(CASE WHEN e.hire_date <  @start AND (x.exit_date IS NULL OR x.exit_date >= @start) THEN 1 ELSE 0 END) AS opening,
               SUM(CASE WHEN e.hire_date <= @end   AND (x.exit_date IS NULL OR x.exit_date >  @end)   THEN 1 ELSE 0 END) AS closing,
               SUM(CASE WHEN x.exit_date BETWEEN @start AND @end THEN 1 ELSE 0 END) AS exits
        FROM dbo.Employees e
        JOIN dbo.Departments d ON d.department_id = e.department_id
        LEFT JOIN dbo.Exits x  ON x.employee_id   = e.employee_id
        GROUP BY d.department_name
    )
    SELECT department_name, opening, closing, exits,
           CAST(100.0 * exits / NULLIF((opening + closing) / 2.0, 0) AS DECIMAL(5,2)) AS attrition_rate_pct
    FROM c
    ORDER BY attrition_rate_pct DESC, department_name;
END;
GO

/* ---- 4. Promote an employee: three changes that must succeed or fail together ---- */
CREATE OR ALTER PROCEDURE dbo.usp_PromoteEmployee
    @EmployeeId    INT,
    @NewJobRoleId  INT,
    @NewSalary     DECIMAL(12,2),
    @PromotionDate DATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;            -- any runtime error rolls the whole transaction back

    DECLARE @HireDate DATE, @DeptId INT, @OldRoleId INT,
            @CurrentSalary DECIMAL(12,2), @LastChange DATE;

    SELECT @HireDate = e.hire_date, @DeptId = e.department_id, @OldRoleId = e.job_role_id,
           @CurrentSalary = cs.base_salary, @LastChange = cs.salary_effective_date
    FROM dbo.Employees e
    LEFT JOIN dbo.vw_CurrentSalary cs ON cs.employee_id = e.employee_id
    WHERE e.employee_id = @EmployeeId;

    /* Validate first: cheap checks before any change */
    IF @HireDate IS NULL
    BEGIN THROW 50030, 'Employee does not exist.', 1; END;

    IF EXISTS (SELECT 1 FROM dbo.Exits WHERE employee_id = @EmployeeId)
    BEGIN THROW 50031, 'Employee is not active (has an exit record).', 1; END;

    IF NOT EXISTS (SELECT 1 FROM dbo.JobRoles WHERE job_role_id = @NewJobRoleId AND department_id = @DeptId)
    BEGIN THROW 50032, 'New role must exist and belong to the employee''s department.', 1; END;

    IF @NewJobRoleId = @OldRoleId
    BEGIN THROW 50033, 'New role must differ from the current role.', 1; END;

    IF @NewSalary <= @CurrentSalary
    BEGIN THROW 50034, 'New salary must be higher than the current salary.', 1; END;

    IF @PromotionDate <= @HireDate OR @PromotionDate <= @LastChange
    BEGIN THROW 50035, 'Promotion date must be after the hire date and the latest salary change.', 1; END;

    /* The transaction: all three changes, or none */
    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Promotions (employee_id, promotion_date, old_job_role_id, new_job_role_id)
        VALUES (@EmployeeId, @PromotionDate, @OldRoleId, @NewJobRoleId);

        INSERT INTO dbo.SalaryHistory (employee_id, effective_date, base_salary, change_reason)
        VALUES (@EmployeeId, @PromotionDate, @NewSalary, 'Promotion');

        UPDATE dbo.Employees SET job_role_id = @NewJobRoleId WHERE employee_id = @EmployeeId;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;                    -- re-raise the original error to the caller
    END CATCH;

    SELECT @EmployeeId AS employee_id, ro.job_title AS old_role, rn.job_title AS new_role,
           @CurrentSalary AS old_salary, @NewSalary AS new_salary,
           CAST(100.0 * (@NewSalary - @CurrentSalary) / @CurrentSalary AS DECIMAL(5,2)) AS raise_pct
    FROM dbo.JobRoles ro
    CROSS JOIN dbo.JobRoles rn
    WHERE ro.job_role_id = @OldRoleId AND rn.job_role_id = @NewJobRoleId;
END;
GO