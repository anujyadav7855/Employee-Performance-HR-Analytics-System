USE HR_Analytics_DB;
GO
-- Children first, then parents
DELETE FROM Exits;
DELETE FROM Promotions;
DELETE FROM PerformanceReviews;
DELETE FROM Attendance;
DELETE FROM SalaryHistory;
DELETE FROM Employees;
DELETE FROM JobRoles;
DELETE FROM Departments;

-- Restart identity counters so new IDs begin at 1 again
DBCC CHECKIDENT ('Exits',              RESEED, 0);
DBCC CHECKIDENT ('Promotions',         RESEED, 0);
DBCC CHECKIDENT ('PerformanceReviews', RESEED, 0);
DBCC CHECKIDENT ('Attendance',         RESEED, 0);
DBCC CHECKIDENT ('SalaryHistory',      RESEED, 0);
DBCC CHECKIDENT ('Employees',          RESEED, 0);
DBCC CHECKIDENT ('JobRoles',           RESEED, 0);
DBCC CHECKIDENT ('Departments',        RESEED, 0);
GO