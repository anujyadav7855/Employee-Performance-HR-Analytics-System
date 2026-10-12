/* =====================================================
   File    : 02_create_tables.sql
   Purpose : Create the 8 core tables (columns + primary keys)
   Note    : Dropping tables in child -> parent order makes the
             script re-runnable. WARNING: this deletes all data.
   ===================================================== */
USE HR_Analytics_DB;
GO

-- Drop in reverse dependency order (children first)
DROP TABLE IF EXISTS Exits;
DROP TABLE IF EXISTS Promotions;
DROP TABLE IF EXISTS PerformanceReviews;
DROP TABLE IF EXISTS Attendance;
DROP TABLE IF EXISTS SalaryHistory;
DROP TABLE IF EXISTS Employees;
DROP TABLE IF EXISTS JobRoles;
DROP TABLE IF EXISTS Departments;
GO

-- 1. Departments
CREATE TABLE Departments (
    department_id    INT IDENTITY(1,1) NOT NULL,
    department_name  VARCHAR(50)       NOT NULL,
    location         VARCHAR(50)       NULL,
    CONSTRAINT PK_Departments PRIMARY KEY (department_id)
);

-- 2. JobRoles
CREATE TABLE JobRoles (
    job_role_id     INT IDENTITY(1,1) NOT NULL,
    job_title       VARCHAR(80)       NOT NULL,
    department_id   INT               NOT NULL,
    job_level       VARCHAR(20)       NOT NULL,
    min_salary      DECIMAL(12,2)     NOT NULL,
    max_salary      DECIMAL(12,2)     NOT NULL,
    CONSTRAINT PK_JobRoles PRIMARY KEY (job_role_id)
);

-- 3. Employees
CREATE TABLE Employees (
    employee_id     INT IDENTITY(1,1) NOT NULL,
    first_name      VARCHAR(50)       NOT NULL,
    last_name       VARCHAR(50)       NOT NULL,
    gender          VARCHAR(10)       NULL,
    date_of_birth   DATE              NOT NULL,
    hire_date       DATE              NOT NULL,
    email           VARCHAR(100)      NOT NULL,
    city            VARCHAR(50)       NULL,
    department_id   INT               NOT NULL,
    job_role_id     INT               NOT NULL,
    manager_id      INT               NULL,       -- NULL for the top manager
    CONSTRAINT PK_Employees PRIMARY KEY (employee_id)
);

-- 4. SalaryHistory
CREATE TABLE SalaryHistory (
    salary_id       INT IDENTITY(1,1) NOT NULL,
    employee_id     INT               NOT NULL,
    effective_date  DATE              NOT NULL,
    base_salary     DECIMAL(12,2)     NOT NULL,   -- annual salary
    change_reason   VARCHAR(30)       NOT NULL,
    CONSTRAINT PK_SalaryHistory PRIMARY KEY (salary_id)
);

-- 5. Attendance (largest table, hence BIGINT)
CREATE TABLE Attendance (
    attendance_id    BIGINT IDENTITY(1,1) NOT NULL,
    employee_id      INT                  NOT NULL,
    attendance_date  DATE                 NOT NULL,
    status           VARCHAR(10)          NOT NULL,
    check_in_time    TIME(0)              NULL,
    check_out_time   TIME(0)              NULL,
    CONSTRAINT PK_Attendance PRIMARY KEY (attendance_id)
);

-- 6. PerformanceReviews
CREATE TABLE PerformanceReviews (
    review_id       INT IDENTITY(1,1) NOT NULL,
    employee_id     INT               NOT NULL,   -- who was reviewed
    reviewer_id     INT               NOT NULL,   -- who reviewed
    review_period   VARCHAR(7)        NOT NULL,   -- e.g. '2024-H1'
    review_date     DATE              NOT NULL,
    rating          TINYINT           NOT NULL,
    CONSTRAINT PK_PerformanceReviews PRIMARY KEY (review_id)
);

-- 7. Promotions
CREATE TABLE Promotions (
    promotion_id     INT IDENTITY(1,1) NOT NULL,
    employee_id      INT               NOT NULL,
    promotion_date   DATE              NOT NULL,
    old_job_role_id  INT               NOT NULL,
    new_job_role_id  INT               NOT NULL,
    CONSTRAINT PK_Promotions PRIMARY KEY (promotion_id)
);

-- 8. Exits
CREATE TABLE Exits (
    exit_id       INT IDENTITY(1,1) NOT NULL,
    employee_id   INT               NOT NULL,
    exit_date     DATE              NOT NULL,
    exit_type     VARCHAR(20)       NOT NULL,
    exit_reason   VARCHAR(60)       NULL,
    CONSTRAINT PK_Exits PRIMARY KEY (exit_id)
);
GO