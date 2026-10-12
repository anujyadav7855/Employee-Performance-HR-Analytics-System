/* =====================================================
   File    : 03_constraints.sql
   Purpose : Add FOREIGN KEY, UNIQUE, CHECK and DEFAULT constraints
   Run     : After 02_create_tables.sql (tables must exist)
   ===================================================== */
USE HR_Analytics_DB;
GO

/* ---------- UNIQUE ---------- */
ALTER TABLE Departments        ADD CONSTRAINT UQ_Departments_name
    UNIQUE (department_name);
ALTER TABLE JobRoles           ADD CONSTRAINT UQ_JobRoles_title_dept
    UNIQUE (job_title, department_id);
ALTER TABLE Employees          ADD CONSTRAINT UQ_Employees_email
    UNIQUE (email);
ALTER TABLE SalaryHistory      ADD CONSTRAINT UQ_SalaryHistory_emp_date
    UNIQUE (employee_id, effective_date);
ALTER TABLE Attendance         ADD CONSTRAINT UQ_Attendance_emp_date
    UNIQUE (employee_id, attendance_date);
ALTER TABLE PerformanceReviews ADD CONSTRAINT UQ_PerformanceReviews_emp_period
    UNIQUE (employee_id, review_period);
ALTER TABLE Exits              ADD CONSTRAINT UQ_Exits_employee
    UNIQUE (employee_id);

/* ---------- FOREIGN KEYS ---------- */
ALTER TABLE JobRoles ADD CONSTRAINT FK_JobRoles_Departments
    FOREIGN KEY (department_id) REFERENCES Departments(department_id);

ALTER TABLE Employees ADD CONSTRAINT FK_Employees_Departments
    FOREIGN KEY (department_id) REFERENCES Departments(department_id);
ALTER TABLE Employees ADD CONSTRAINT FK_Employees_JobRoles
    FOREIGN KEY (job_role_id) REFERENCES JobRoles(job_role_id);
ALTER TABLE Employees ADD CONSTRAINT FK_Employees_Manager
    FOREIGN KEY (manager_id) REFERENCES Employees(employee_id);

ALTER TABLE SalaryHistory ADD CONSTRAINT FK_SalaryHistory_Employees
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id);

ALTER TABLE Attendance ADD CONSTRAINT FK_Attendance_Employees
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id);

ALTER TABLE PerformanceReviews ADD CONSTRAINT FK_PerformanceReviews_Employee
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id);
ALTER TABLE PerformanceReviews ADD CONSTRAINT FK_PerformanceReviews_Reviewer
    FOREIGN KEY (reviewer_id) REFERENCES Employees(employee_id);

ALTER TABLE Promotions ADD CONSTRAINT FK_Promotions_Employees
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id);
ALTER TABLE Promotions ADD CONSTRAINT FK_Promotions_OldRole
    FOREIGN KEY (old_job_role_id) REFERENCES JobRoles(job_role_id);
ALTER TABLE Promotions ADD CONSTRAINT FK_Promotions_NewRole
    FOREIGN KEY (new_job_role_id) REFERENCES JobRoles(job_role_id);

ALTER TABLE Exits ADD CONSTRAINT FK_Exits_Employees
    FOREIGN KEY (employee_id) REFERENCES Employees(employee_id);

/* ---------- CHECK ---------- */
ALTER TABLE JobRoles ADD CONSTRAINT CK_JobRoles_level
    CHECK (job_level IN ('Junior','Mid','Senior','Lead','Manager'));
ALTER TABLE JobRoles ADD CONSTRAINT CK_JobRoles_salary_band
    CHECK (min_salary > 0 AND max_salary >= min_salary);

ALTER TABLE Employees ADD CONSTRAINT CK_Employees_gender
    CHECK (gender IN ('Male','Female','Other'));
ALTER TABLE Employees ADD CONSTRAINT CK_Employees_not_own_manager
    CHECK (manager_id IS NULL OR manager_id <> employee_id);
ALTER TABLE Employees ADD CONSTRAINT CK_Employees_min_age
    CHECK (DATEADD(YEAR, 18, date_of_birth) <= hire_date);

ALTER TABLE SalaryHistory ADD CONSTRAINT CK_SalaryHistory_salary
    CHECK (base_salary > 0);
ALTER TABLE SalaryHistory ADD CONSTRAINT CK_SalaryHistory_reason
    CHECK (change_reason IN ('Hire','Annual Increment','Promotion','Adjustment'));

ALTER TABLE Attendance ADD CONSTRAINT CK_Attendance_status
    CHECK (status IN ('Present','Absent','Leave','Half-Day'));
ALTER TABLE Attendance ADD CONSTRAINT CK_Attendance_times
    CHECK (check_in_time IS NULL OR check_out_time IS NULL
           OR check_out_time > check_in_time);

ALTER TABLE PerformanceReviews ADD CONSTRAINT CK_PerformanceReviews_rating
    CHECK (rating BETWEEN 1 AND 5);
ALTER TABLE PerformanceReviews ADD CONSTRAINT CK_PerformanceReviews_period
    CHECK (review_period LIKE '[0-9][0-9][0-9][0-9]-H[12]');
ALTER TABLE PerformanceReviews ADD CONSTRAINT CK_PerformanceReviews_not_self
    CHECK (employee_id <> reviewer_id);

ALTER TABLE Promotions ADD CONSTRAINT CK_Promotions_roles_differ
    CHECK (old_job_role_id <> new_job_role_id);

ALTER TABLE Exits ADD CONSTRAINT CK_Exits_type
    CHECK (exit_type IN ('Resignation','Termination','Retirement'));

/* ---------- DEFAULT ---------- */
ALTER TABLE Attendance ADD CONSTRAINT DF_Attendance_status
    DEFAULT 'Present' FOR status;
ALTER TABLE SalaryHistory ADD CONSTRAINT DF_SalaryHistory_reason
    DEFAULT 'Annual Increment' FOR change_reason;
GO