/* =====================================================================
   FINAL SQL CHALLENGE: 10 project-specific problems
   Database: HR_Analytics_DB (SQL Server)
   Rules   : Solve WITHOUT looking at 08_final_sql_challenge_answers.sql.
             Write each solution below its problem, run it, then self-check.
   Tools   : You may use the base tables and the views
             (vw_ActiveStaff, vw_CurrentSalary, vw_EmployeeDetails).
   Time    : Aim for about 15 minutes per problem (150 minutes in total).
   ===================================================================== */
USE HR_Analytics_DB;
GO

/* ---------------------------------------------------------------------
   P1 (easy-medium): Resignation tenure
   For each department with AT LEAST 5 resignations, show the department,
   the number of resignations, and the average tenure at resignation in
   years (1 decimal place). Sort by average tenure, highest first, then by
   department name.
   Columns: department_name, resignations, avg_tenure_years
   --------------------------------------------------------------------- */


/* ---------------------------------------------------------------------
   P2 (medium): Hires and exits by department and year
   For every department and every year 2022-2025 (28 rows, including
   combinations with zero hires or zero exits), show hires, exits and the
   net headcount change (hires minus exits).
   Columns: department_name, yr, hires, exits, net_change
   --------------------------------------------------------------------- */


/* ---------------------------------------------------------------------
   P3 (medium): Consecutive top ratings
   Find how many times an employee received a rating of 5 in two
   consecutive reviews (consecutive = the review immediately before it, by
   review period), and how many different employees this involves.
   Columns: consecutive_pairs, employees
   --------------------------------------------------------------------- */


/* ---------------------------------------------------------------------
   P4 (medium-hard): Well paid and well rated
   List ACTIVE employees whose current salary is ABOVE the average current
   salary of ACTIVE employees in their department AND who have at least 4
   reviews with an average rating of 4.0 or higher. Show employee_id,
   full name, department, current salary. Highest salary first
   (tie-break: employee_id).
   --------------------------------------------------------------------- */


/* ---------------------------------------------------------------------
   P5 (medium-hard): Worst absence month of each year
   For each year, find the month with the highest absenteeism rate
   (Absent records / all records x 100, 2 decimals). If two months tie,
   take the earlier month.
   Columns: yr, month_no, absenteeism_rate_pct
   --------------------------------------------------------------------- */


/* ---------------------------------------------------------------------
   P6 (medium): Running total of exits
   For 2025, show for each month the number of exits and the cumulative
   number of exits so far in the year.
   Columns: month_no, exits, cumulative_exits
   --------------------------------------------------------------------- */


/* ---------------------------------------------------------------------
   P7 (hard): Big first-promotion raises
   For each employee, take their FIRST promotion. Compare the salary on
   the promotion date with the salary record immediately before it. List the
   employees whose raise was MORE THAN 30%. Show employee_id, full name,
   department, raise % (2 decimals), highest first (tie-break: employee_id).
   --------------------------------------------------------------------- */


/* ---------------------------------------------------------------------
   P8 (medium-hard): Departments where ratings fell
   Using the YEAR of review_date, find departments whose average rating in
   2025 was LOWER than in 2024. Show the department and both averages
   (2 decimals), largest fall first.
   Columns: department_name, avg_2024, avg_2025
   --------------------------------------------------------------------- */


/* ---------------------------------------------------------------------
   P9 (medium): Hired 2023, still here, never promoted
   Count employees hired during 2023 who are still active and have never been
   promoted, by department (departments with none need not appear). Sort by
   the count (highest first), then by department name.
   Columns: department_name, employees
   --------------------------------------------------------------------- */


/* ---------------------------------------------------------------------
   P10 (medium): Exit reasons and tenure
   For each exit reason (ignore exits with no reason) that appears at least
   5 times, show the number of exits and the average tenure at exit in years
   (1 decimal). Sort by exits (highest first), then by reason.
   Columns: exit_reason, exits, avg_tenure_years
   --------------------------------------------------------------------- */

