USE HR_Analytics_DB;
GO

BULK INSERT stg.Departments FROM 'D:\Employee Performance & HR Analytics System\DATA\RAW\Departments.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001');

BULK INSERT stg.JobRoles FROM 'D:\Employee Performance & HR Analytics System\DATA\RAW\JobRoles.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001');

BULK INSERT stg.Employees FROM 'D:\Employee Performance & HR Analytics System\DATA\RAW\employees.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001');

BULK INSERT stg.SalaryHistory FROM 'D:\Employee Performance & HR Analytics System\DATA\RAW\salary_history.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001');

BULK INSERT stg.Attendance FROM 'D:\Employee Performance & HR Analytics System\DATA\RAW\attendance.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001', TABLOCK);

BULK INSERT stg.PerformanceReviews FROM 'D:\Employee Performance & HR Analytics System\DATA\RAW\performance_reviews.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001');

BULK INSERT stg.Promotions FROM 'D:\Employee Performance & HR Analytics System\DATA\RAW\Promotions.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001');

BULK INSERT stg.Exits FROM 'D:\Employee Performance & HR Analytics System\DATA\RAW\exits.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, CODEPAGE = '65001');
GO

-- Give every staging row a unique ID (needed for de-duplication on Day 6).
-- Added AFTER loading, because BULK INSERT expects the table to match the file.
ALTER TABLE stg.Employees          ADD stg_row_id INT IDENTITY(1,1);
ALTER TABLE stg.SalaryHistory      ADD stg_row_id INT IDENTITY(1,1);
ALTER TABLE stg.Attendance         ADD stg_row_id INT IDENTITY(1,1);
ALTER TABLE stg.PerformanceReviews ADD stg_row_id INT IDENTITY(1,1);
ALTER TABLE stg.Promotions         ADD stg_row_id INT IDENTITY(1,1);
ALTER TABLE stg.Exits              ADD stg_row_id INT IDENTITY(1,1);
GO