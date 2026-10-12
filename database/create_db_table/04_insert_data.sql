/* =====================================================
   File    : 04_insert_data.sql
   Purpose : TEST SEED DATA (Day 4). Replaced by the full
             dataset load on Day 5. Run 03 before this file.
   ===================================================== */
USE HR_Analytics_DB;
GO

-- 1. Departments (the 7 final departments)
INSERT INTO Departments (department_name, location) VALUES
('HR',               'Mumbai'),
('IT',               'Bengaluru'),
('Finance',          'Pune'),
('Sales',            'Delhi'),
('Marketing',        'Hyderabad'),
('Operations',       'Mumbai'),
('Customer Support', 'Delhi');

-- 2. JobRoles (7 test roles; ~35 in the full dataset). Salaries are annual.
INSERT INTO JobRoles (job_title, department_id, job_level, min_salary, max_salary) VALUES
('HR Manager',          1, 'Manager', 1200000, 2000000),   -- job_role_id 1
('HR Executive',        1, 'Junior',   300000,  600000),   -- 2
('Data Analyst',        2, 'Mid',      400000,  800000),   -- 3
('Senior Data Analyst', 2, 'Senior',   700000, 1600000),   -- 4
('IT Manager',          2, 'Manager', 1500000, 2500000),   -- 5
('Sales Executive',     4, 'Junior',   300000,  700000),   -- 6
('Sales Manager',       4, 'Manager', 1000000, 1800000);   -- 7

-- 3a. Employees: managers first (manager_id = NULL)
INSERT INTO Employees
 (first_name, last_name, gender, date_of_birth, hire_date, email, city, department_id, job_role_id, manager_id)
VALUES
('Anita',  'Sharma', 'Female', '1985-04-12', '2022-01-10', 'anita.sharma@company.com',  'Mumbai',    1, 1, NULL),  -- 1
('Rahul',  'Verma',  'Male',   '1983-09-03', '2022-01-17', 'rahul.verma@company.com',   'Bengaluru', 2, 5, NULL),  -- 2
('Vikram', 'Singh',  'Male',   '1982-01-25', '2022-02-01', 'vikram.singh@company.com',  'Delhi',     4, 7, NULL);  -- 3

-- 3b. Employees: staff reporting to those managers
INSERT INTO Employees
 (first_name, last_name, gender, date_of_birth, hire_date, email, city, department_id, job_role_id, manager_id)
VALUES
('Priya',  'Nair',      'Female', '1994-06-21', '2022-06-01', 'priya.nair@company.com',      'Bengaluru', 2, 4, 2),  -- 4 (current role: Senior Data Analyst, promoted 2024)
('Arjun',  'Mehta',     'Male',   '1991-11-30', '2022-03-14', 'arjun.mehta@company.com',     'Bengaluru', 2, 4, 2),  -- 5
('Sneha',  'Iyer',      'Female', '1996-02-08', '2023-01-09', 'sneha.iyer@company.com',      'Delhi',     4, 6, 3),  -- 6
('Karan',  'Malhotra',  'Male',   '1993-07-19', '2022-09-05', 'karan.malhotra@company.com',  'Delhi',     4, 6, 3),  -- 7 (will have an exit record)
('Divya',  'Rao',       'Female', '1997-12-02', '2023-07-24', 'divya.rao@company.com',       'Mumbai',    1, 2, 1);  -- 8

-- 4. SalaryHistory (note employee 4 has three records: hire, increment, promotion)
INSERT INTO SalaryHistory (employee_id, effective_date, base_salary, change_reason) VALUES
(1, '2022-01-10', 1400000, 'Hire'),
(1, '2023-04-01', 1500000, 'Annual Increment'),
(2, '2022-01-17', 1800000, 'Hire'),
(3, '2022-02-01', 1300000, 'Hire'),
(4, '2022-06-01',  600000, 'Hire'),
(4, '2023-04-01',  660000, 'Annual Increment'),
(4, '2024-04-01',  780000, 'Promotion'),
(5, '2022-03-14', 1000000, 'Hire'),
(6, '2023-01-09',  400000, 'Hire'),
(7, '2022-09-05',  380000, 'Hire'),
(8, '2023-07-24',  350000, 'Hire');

-- 5. Attendance: one working week (Mon 3 Mar to Fri 7 Mar 2025) for employees 4 and 5
INSERT INTO Attendance (employee_id, attendance_date, status, check_in_time, check_out_time) VALUES
(4, '2025-03-03', 'Present', '09:02:00', '18:05:00'),
(4, '2025-03-04', 'Present', '09:10:00', '18:00:00'),
(4, '2025-03-05', 'Absent',  NULL,       NULL),
(4, '2025-03-06', 'Present', '09:00:00', '17:55:00'),
(4, '2025-03-07', 'Half-Day','09:05:00', '13:30:00'),
(5, '2025-03-03', 'Present', '08:55:00', '17:50:00'),
(5, '2025-03-04', 'Leave',   NULL,       NULL),
(5, '2025-03-05', 'Present', '09:15:00', '18:20:00'),
(5, '2025-03-06', 'Present', '09:00:00', '18:00:00'),
(5, '2025-03-07', 'Present', '09:05:00', '18:10:00');

-- 6. PerformanceReviews (reviewer = the employee's manager)
INSERT INTO PerformanceReviews (employee_id, reviewer_id, review_period, review_date, rating) VALUES
(4, 2, '2024-H1', '2024-07-15', 4),
(4, 2, '2024-H2', '2025-01-15', 5),
(5, 2, '2024-H1', '2024-07-15', 3),
(5, 2, '2024-H2', '2025-01-15', 4),
(6, 3, '2024-H1', '2024-07-16', 3),
(7, 3, '2024-H1', '2024-07-16', 2),
(8, 1, '2024-H1', '2024-07-17', 4);

-- 7. Promotions: Priya Nair, Data Analyst (3) -> Senior Data Analyst (4)
INSERT INTO Promotions (employee_id, promotion_date, old_job_role_id, new_job_role_id) VALUES
(4, '2024-04-01', 3, 4);

-- 8. Exits: Karan Malhotra resigned
INSERT INTO Exits (employee_id, exit_date, exit_type, exit_reason) VALUES
(7, '2024-08-30', 'Resignation', 'Better Pay');
GO


-- Row counts per table
SELECT 'Departments' AS table_name, COUNT(*) AS row_count FROM Departments
UNION ALL SELECT 'JobRoles',           COUNT(*) FROM JobRoles
UNION ALL SELECT 'Employees',          COUNT(*) FROM Employees
UNION ALL SELECT 'SalaryHistory',      COUNT(*) FROM SalaryHistory
UNION ALL SELECT 'Attendance',         COUNT(*) FROM Attendance
UNION ALL SELECT 'PerformanceReviews', COUNT(*) FROM PerformanceReviews
UNION ALL SELECT 'Promotions',         COUNT(*) FROM Promotions
UNION ALL SELECT 'Exits',              COUNT(*) FROM Exits;

-- Employees with department, role, and manager name
SELECT e.employee_id,
       CONCAT(e.first_name, ' ', e.last_name)  AS employee,
       d.department_name,
       r.job_title,
       CONCAT(m.first_name, ' ', m.last_name)  AS manager
FROM Employees   e
JOIN Departments d ON e.department_id = d.department_id
JOIN JobRoles    r ON e.job_role_id   = r.job_role_id
LEFT JOIN Employees m ON e.manager_id = m.employee_id
ORDER BY e.employee_id;

-- Salary history of one employee (employee 4)
SELECT effective_date, base_salary, change_reason
FROM SalaryHistory
WHERE employee_id = 4
ORDER BY effective_date;



USE HR_Analytics_DB;
GO

-- Test 1: duplicate email  (UQ_Employees_email)
BEGIN TRY
    INSERT INTO Employees (first_name,last_name,gender,date_of_birth,hire_date,email,department_id,job_role_id)
    VALUES ('Test','One','Male','1990-01-01','2023-01-01','anita.sharma@company.com',1,2);
    PRINT 'Test 1 UNEXPECTED SUCCESS';
END TRY
BEGIN CATCH
    PRINT 'Test 1 blocked: ' + ERROR_MESSAGE();
END CATCH;

-- Test 2: rating outside 1-5  (CK_PerformanceReviews_rating)
BEGIN TRY
    INSERT INTO PerformanceReviews (employee_id,reviewer_id,review_period,review_date,rating)
    VALUES (6, 3, '2024-H2', '2025-01-16', 6);
    PRINT 'Test 2 UNEXPECTED SUCCESS';
END TRY
BEGIN CATCH
    PRINT 'Test 2 blocked: ' + ERROR_MESSAGE();
END CATCH;

-- Test 3: department that does not exist  (FK_JobRoles_Departments)
BEGIN TRY
    INSERT INTO JobRoles (job_title, department_id, job_level, min_salary, max_salary)
    VALUES ('Ghost Role', 99, 'Mid', 100000, 200000);
    PRINT 'Test 3 UNEXPECTED SUCCESS';
END TRY
BEGIN CATCH
    PRINT 'Test 3 blocked: ' + ERROR_MESSAGE();
END CATCH;

-- Test 4: duplicate attendance for same employee and day  (UQ_Attendance_emp_date)
BEGIN TRY
    INSERT INTO Attendance (employee_id, attendance_date, status)
    VALUES (4, '2025-03-03', 'Present');
    PRINT 'Test 4 UNEXPECTED SUCCESS';
END TRY
BEGIN CATCH
    PRINT 'Test 4 blocked: ' + ERROR_MESSAGE();
END CATCH;

-- Test 5: employee as their own manager  (CK_Employees_not_own_manager)
BEGIN TRY
    UPDATE Employees SET manager_id = 1 WHERE employee_id = 1;
    PRINT 'Test 5 UNEXPECTED SUCCESS';
END TRY
BEGIN CATCH
    PRINT 'Test 5 blocked: ' + ERROR_MESSAGE();
END CATCH;

-- Test 6: delete a department that still has employees  (FK, NO ACTION)
BEGIN TRY
    DELETE FROM Departments WHERE department_id = 2;
    PRINT 'Test 6 UNEXPECTED SUCCESS';
END TRY
BEGIN CATCH
    PRINT 'Test 6 blocked: ' + ERROR_MESSAGE();
END CATCH;

-- Test 7: second exit record for the same employee  (UQ_Exits_employee)
BEGIN TRY
    INSERT INTO Exits (employee_id, exit_date, exit_type)
    VALUES (7, '2024-09-30', 'Termination');
    PRINT 'Test 7 UNEXPECTED SUCCESS';
END TRY
BEGIN CATCH
    PRINT 'Test 7 blocked: ' + ERROR_MESSAGE();
END CATCH;

-- Test 8: employee younger than 18 at hire  (CK_Employees_min_age)
BEGIN TRY
    INSERT INTO Employees (first_name,last_name,gender,date_of_birth,hire_date,email,department_id,job_role_id)
    VALUES ('Test','Minor','Male','2010-01-01','2023-01-01','test.minor@company.com',1,2);
    PRINT 'Test 8 UNEXPECTED SUCCESS';
END TRY
BEGIN CATCH
    PRINT 'Test 8 blocked: ' + ERROR_MESSAGE();
END CATCH;

-- Test 9: invalid attendance status  (CK_Attendance_status)
BEGIN TRY
    INSERT INTO Attendance (employee_id, attendance_date, status)
    VALUES (6, '2025-03-03', 'Late');
    PRINT 'Test 9 UNEXPECTED SUCCESS';
END TRY
BEGIN CATCH
    PRINT 'Test 9 blocked: ' + ERROR_MESSAGE();
END CATCH;