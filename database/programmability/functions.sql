USE HR_Analytics_DB;
GO

-- Scalar function: exact age on a given date (the formula from Day 7, written once)
CREATE OR ALTER FUNCTION dbo.fn_AgeOn (@dob DATE, @on DATE)
RETURNS INT
WITH SCHEMABINDING
AS
BEGIN
    RETURN CASE WHEN @dob IS NULL THEN NULL
                ELSE DATEDIFF(YEAR, @dob, @on)
                     - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, @dob, @on), @dob) > @on THEN 1 ELSE 0 END
           END;
END;
GO

-- Inline table-valued function: who was employed on a given date (a parameterised view)
CREATE OR ALTER FUNCTION dbo.fn_ActiveEmployeesAsOf (@AsOf DATE)
RETURNS TABLE
AS
RETURN
(
    SELECT e.employee_id, e.department_id, e.job_role_id, e.hire_date
    FROM dbo.Employees e
    WHERE e.hire_date <= @AsOf
      AND NOT EXISTS (SELECT 1 FROM dbo.Exits x
                      WHERE x.employee_id = e.employee_id AND x.exit_date <= @AsOf)
);
GO