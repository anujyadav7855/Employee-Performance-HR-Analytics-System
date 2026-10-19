USE HR_Analytics_DB;
GO

/* Audit table: tracks future department / role / manager changes (Day 3 gap) */
IF OBJECT_ID('dbo.EmployeeChangeLog') IS NULL
CREATE TABLE dbo.EmployeeChangeLog (
    change_id      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_EmployeeChangeLog PRIMARY KEY,
    employee_id    INT           NOT NULL CONSTRAINT FK_EmployeeChangeLog_Employees REFERENCES dbo.Employees(employee_id),
    changed_column VARCHAR(30)   NOT NULL,
    old_value      VARCHAR(100)  NULL,
    new_value      VARCHAR(100)  NULL,
    changed_at     DATETIME2     NOT NULL CONSTRAINT DF_EmployeeChangeLog_changed_at DEFAULT SYSDATETIME(),
    changed_by     SYSNAME       NOT NULL CONSTRAINT DF_EmployeeChangeLog_changed_by DEFAULT SUSER_SNAME()
);
GO

/* Rule 1: an exit cannot be on or before the hire date (a CHECK cannot see another table) */
CREATE OR ALTER TRIGGER dbo.trg_Exits_ValidateDates
ON dbo.Exits
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN dbo.Employees e ON e.employee_id = i.employee_id
               WHERE i.exit_date <= e.hire_date)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50020, 'Exit date must be after the employee''s hire date.', 1;
    END;
END;
GO

/* Rule 2: a promotion cannot be on or before the hire date */
CREATE OR ALTER TRIGGER dbo.trg_Promotions_ValidateDates
ON dbo.Promotions
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1
               FROM inserted i
               JOIN dbo.Employees e ON e.employee_id = i.employee_id
               WHERE i.promotion_date <= e.hire_date)
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50021, 'Promotion date must be after the employee''s hire date.', 1;
    END;
END;
GO

/* Audit: log changes to department, role or manager (handles many rows at once) */
CREATE OR ALTER TRIGGER dbo.trg_Employees_TrackChanges
ON dbo.Employees
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(department_id) OR UPDATE(job_role_id) OR UPDATE(manager_id)
    BEGIN
        INSERT INTO dbo.EmployeeChangeLog (employee_id, changed_column, old_value, new_value)
        SELECT i.employee_id, 'department_id', CAST(d.department_id AS VARCHAR(100)), CAST(i.department_id AS VARCHAR(100))
        FROM inserted i JOIN deleted d ON d.employee_id = i.employee_id
        WHERE ISNULL(d.department_id, -1) <> ISNULL(i.department_id, -1)
        UNION ALL
        SELECT i.employee_id, 'job_role_id', CAST(d.job_role_id AS VARCHAR(100)), CAST(i.job_role_id AS VARCHAR(100))
        FROM inserted i JOIN deleted d ON d.employee_id = i.employee_id
        WHERE ISNULL(d.job_role_id, -1) <> ISNULL(i.job_role_id, -1)
        UNION ALL
        SELECT i.employee_id, 'manager_id', CAST(d.manager_id AS VARCHAR(100)), CAST(i.manager_id AS VARCHAR(100))
        FROM inserted i JOIN deleted d ON d.employee_id = i.employee_id
        WHERE ISNULL(d.manager_id, -1) <> ISNULL(i.manager_id, -1);
    END;
END;
GO