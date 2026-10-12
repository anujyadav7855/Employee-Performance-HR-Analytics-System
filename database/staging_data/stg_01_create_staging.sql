USE HR_Analytics_DB;
GO

IF SCHEMA_ID('stg') IS NULL EXEC('CREATE SCHEMA stg');
GO

DROP TABLE IF EXISTS stg.Exits, stg.Promotions, stg.PerformanceReviews,
                     stg.Attendance, stg.SalaryHistory, stg.Employees,
                     stg.JobRoles, stg.Departments;
GO

CREATE TABLE stg.Departments (
    department_id VARCHAR(100), department_name VARCHAR(100), location VARCHAR(100));

CREATE TABLE stg.JobRoles (
    job_role_id VARCHAR(100), job_title VARCHAR(100), department_id VARCHAR(100),
    job_level VARCHAR(100), min_salary VARCHAR(100), max_salary VARCHAR(100));

CREATE TABLE stg.Employees (
    employee_id VARCHAR(100), first_name VARCHAR(100), last_name VARCHAR(100),
    gender VARCHAR(100), date_of_birth VARCHAR(100), hire_date VARCHAR(100),
    email VARCHAR(100), city VARCHAR(100), department_id VARCHAR(100),
    job_role_id VARCHAR(100), manager_id VARCHAR(100));

CREATE TABLE stg.SalaryHistory (
    employee_id VARCHAR(100), effective_date VARCHAR(100),
    base_salary VARCHAR(100), change_reason VARCHAR(100));

CREATE TABLE stg.Attendance (
    employee_id VARCHAR(100), attendance_date VARCHAR(100), status VARCHAR(100),
    check_in_time VARCHAR(100), check_out_time VARCHAR(100));

CREATE TABLE stg.PerformanceReviews (
    employee_id VARCHAR(100), reviewer_id VARCHAR(100), review_period VARCHAR(100),
    review_date VARCHAR(100), rating VARCHAR(100));

CREATE TABLE stg.Promotions (
    employee_id VARCHAR(100), promotion_date VARCHAR(100),
    old_job_role_id VARCHAR(100), new_job_role_id VARCHAR(100));

CREATE TABLE stg.Exits (
    employee_id VARCHAR(100), exit_date VARCHAR(100),
    exit_type VARCHAR(100), exit_reason VARCHAR(100));
GO