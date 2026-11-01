USE HR_Analytics_DB;
SELECT 'Departments' AS tbl, COUNT(*) AS n FROM dbo.Departments          -- 7
UNION ALL SELECT 'JobRoles', COUNT(*) FROM dbo.JobRoles                   -- 37
UNION ALL SELECT 'Employees', COUNT(*) FROM dbo.Employees                 -- 400
UNION ALL SELECT 'SalaryHistory', COUNT(*) FROM dbo.SalaryHistory         -- 1,775
UNION ALL SELECT 'Attendance', COUNT(*) FROM dbo.Attendance               -- 296,726
UNION ALL SELECT 'PerformanceReviews', COUNT(*) FROM dbo.PerformanceReviews -- 2,206
UNION ALL SELECT 'Promotions', COUNT(*) FROM dbo.Promotions               -- 132
UNION ALL SELECT 'Exits', COUNT(*) FROM dbo.Exits;                        -- 109

SELECT * FROM dbo.vw_KpiScorecard ORDER BY kpi_year;                      -- the scorecard table
