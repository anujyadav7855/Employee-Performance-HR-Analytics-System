USE HR_Analytics_DB;
GO
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

SELECT OBJECT_NAME(i.object_id) AS table_name,
       i.name                   AS index_name,
       i.type_desc,
       CASE WHEN i.is_primary_key = 1 THEN 'PK'
            WHEN i.is_unique_constraint = 1 THEN 'UNIQUE' ELSE 'other' END AS created_by,
       (SELECT STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal)
        FROM sys.index_columns ic
        JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
        WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id
          AND ic.is_included_column = 0) AS key_columns
FROM sys.indexes i
JOIN sys.objects o ON o.object_id = i.object_id
WHERE o.type = 'U' AND SCHEMA_NAME(o.schema_id) = 'dbo' AND i.type > 0
ORDER BY table_name, i.index_id;


USE HR_Analytics_DB;
GO

DROP INDEX IF EXISTS IX_Attendance_date_status ON dbo.Attendance;
CREATE NONCLUSTERED INDEX IX_Attendance_date_status
    ON dbo.Attendance (attendance_date)
    INCLUDE (employee_id, status);

DROP INDEX IF EXISTS IX_Employees_department_id ON dbo.Employees;
CREATE NONCLUSTERED INDEX IX_Employees_department_id
    ON dbo.Employees (department_id)
    INCLUDE (job_role_id, hire_date);

DROP INDEX IF EXISTS IX_Employees_manager_id ON dbo.Employees;
CREATE NONCLUSTERED INDEX IX_Employees_manager_id
    ON dbo.Employees (manager_id);

DROP INDEX IF EXISTS IX_Promotions_employee_id ON dbo.Promotions;
CREATE NONCLUSTERED INDEX IX_Promotions_employee_id
    ON dbo.Promotions (employee_id)
    INCLUDE (promotion_date);
GO

-- Are your new indexes being used? (counters reset when SQL Server restarts)
SELECT OBJECT_NAME(s.object_id) AS table_name, i.name AS index_name,
       s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i ON i.object_id = s.object_id AND i.index_id = s.index_id
WHERE s.database_id = DB_ID() AND OBJECT_NAME(s.object_id) IN ('Attendance','Employees','Promotions')
ORDER BY table_name, index_name;