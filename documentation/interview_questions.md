# SQL Interview Questions with Answers (SQL Server / T-SQL)

**How to use this:** read each question, answer aloud in your own words, then compare. Where possible, tie your answer to something you did in the HR Analytics project, because an example beats a definition.
**Sections:** A) 30 basic · B) 30 intermediate · C) 20 advanced

---

## A. Basic (30)

**1. What is SQL?**
Structured Query Language, the standard language for defining, querying and modifying data in relational databases. SQL Server's dialect is T-SQL.

**2. What are DDL, DML, DCL and TCL?**
DDL defines structure (`CREATE`, `ALTER`, `DROP`). DML changes or reads data (`INSERT`, `UPDATE`, `DELETE`, `SELECT`). DCL controls access (`GRANT`, `REVOKE`, `DENY`). TCL controls transactions (`BEGIN`, `COMMIT`, `ROLLBACK`).

**3. What is a primary key?**
A column (or set of columns) that uniquely identifies each row. It can't contain NULL, and a table has only one. In my project, every table uses a narrow identity key such as `employee_id`.

**4. What is a foreign key?**
A column that references the primary key of another table and enforces referential integrity: you can't insert a child row whose parent doesn't exist. Example: `Employees.department_id` references `Departments`.

**5. Primary key vs unique constraint?**
A table has one primary key but can have many unique constraints. A primary key can't be NULL, while SQL Server allows a single NULL in a unique column. I used unique constraints on `(employee_id, attendance_date)` to stop duplicate attendance.

**6. What is NULL, and how does it differ from 0 or an empty string?**
NULL means unknown or missing. 0 is a number and `''` is an empty string. NULL comparisons evaluate to unknown, so use `IS NULL`, not `= NULL`.

**7. WHERE vs HAVING?**
`WHERE` filters rows before grouping. `HAVING` filters groups after aggregation, so it can use aggregates such as `HAVING COUNT(*) >= 5`.

**8. What does DISTINCT do?**
Removes duplicate rows from the result. `COUNT(DISTINCT col)` counts unique non-NULL values.

**9. What does ORDER BY do, and what's the default direction?**
Sorts the result. Default is ascending (`ASC`). Without `ORDER BY`, SQL doesn't guarantee any row order, and `TOP` without `ORDER BY` returns arbitrary rows.

**10. What is the rule for GROUP BY?**
Every selected column must either be in the `GROUP BY` or be wrapped in an aggregate function.

**11. COUNT(*) vs COUNT(column)?**
`COUNT(*)` counts all rows. `COUNT(column)` counts only non-NULL values. That difference is how I counted exited employees with `COUNT(x.employee_id)` after a left join.

**12. Name the common aggregate functions.**
`COUNT`, `SUM`, `AVG`, `MIN`, `MAX`. Note that `AVG` on an integer column returns an integer, so multiply by `1.0` first.

**13. How does LIKE work?**
Pattern matching: `%` matches any number of characters, `_` matches one. `LIKE 'S%'` finds values starting with S.

**14. Are BETWEEN and IN inclusive?**
`BETWEEN a AND b` is inclusive of both ends. `IN (…)` is shorthand for several `OR` equality tests.

**15. What is an INNER JOIN?**
Returns only rows with a match on both sides.

**16. What is a LEFT JOIN?**
Keeps all rows from the left table and fills the right side with NULLs where nothing matches. Filtering the right table in `WHERE` turns it back into an inner join, so put that filter in the `ON` clause.

**17. What is a CROSS JOIN?**
The Cartesian product: every row of one table paired with every row of the other. I used it to build a department-by-year grid so zero-count combinations still appear.

**18. What is a self join?**
Joining a table to itself under two aliases, for example `Employees e` joined to `Employees m ON m.employee_id = e.manager_id` to get manager names.

**19. UNION vs UNION ALL?**
Both stack results. `UNION` removes duplicates (extra work), while `UNION ALL` keeps every row and is faster. Column counts and compatible types must match.

**20. DELETE vs TRUNCATE vs DROP?**
`DELETE` removes selected rows and is logged per row. `TRUNCATE` removes all rows quickly, resets identity, and fails on tables referenced by a foreign key. `DROP` removes the table itself.

**21. CHAR vs VARCHAR?**
`CHAR(n)` is fixed length and padded. `VARCHAR(n)` is variable length. Use `NVARCHAR` when you need Unicode.

**22. DECIMAL vs FLOAT?**
`DECIMAL` is exact, so it's right for money. `FLOAT` is approximate and can give rounding errors. I used `DECIMAL(12,2)` for salaries.

**23. What is an IDENTITY column?**
An auto-incrementing number, usually a surrogate key. It guarantees uniqueness, not gap-free values: failed inserts and rollbacks consume numbers.

**24. What types of constraints exist?**
`PRIMARY KEY`, `FOREIGN KEY`, `UNIQUE`, `NOT NULL`, `CHECK`, `DEFAULT`.

**25. What is a CASE expression?**
Conditional logic inside a query: `CASE WHEN … THEN … ELSE … END`. I used it for age groups and for conditional counting with `SUM(CASE WHEN status = 'Absent' THEN 1 ELSE 0 END)`.

**26. ISNULL vs COALESCE?**
Both replace NULLs. `ISNULL(a, b)` takes two arguments and returns the type of the first. `COALESCE(a, b, c…)` is ANSI standard and returns the first non-NULL of many.

**27. TOP vs OFFSET…FETCH?**
`TOP (n)` returns the first n rows. `OFFSET x ROWS FETCH NEXT n ROWS ONLY` (needs `ORDER BY`) supports paging.

**28. What is an alias?**
A temporary name for a column or table, for readability. You can't use a `SELECT` alias in `WHERE` or `GROUP BY`, but you can in `ORDER BY`.

**29. What is a view?**
A saved query that behaves like a table and stores no data. I used views to hide a repeated five-table join and to expose a directory without salary columns.

**30. What is normalization?**
Organizing tables to reduce redundancy and update anomalies: 1NF (atomic values, no repeating columns), 2NF (no partial dependencies), 3NF (no transitive dependencies). "Every column depends on the key, the whole key, and nothing but the key."

---

## B. Intermediate (30)

**1. Subquery vs join: when would you use each?**
Joins are best when you need columns from both tables. Subqueries suit filtering ("employees in this list") or computing a single value. Many can be rewritten either way, and the optimizer often produces the same plan, so choose for clarity.

**2. What is a correlated subquery?**
An inner query that references the outer row, so it logically runs once per outer row. Example: the latest salary per employee, `WHERE effective_date = (SELECT MAX(...) WHERE s2.employee_id = s.employee_id)`.

**3. EXISTS vs IN?**
`EXISTS` stops at the first match and is NULL-safe. `IN` compares against a list. Performance is often similar today, but `NOT EXISTS` is safer than `NOT IN`.

**4. Why can NOT IN return no rows?**
If the subquery list contains a NULL, `x NOT IN (…, NULL)` is never true. I demonstrated it with `manager_id`, which has NULLs for department heads: `NOT IN` returned 0 rows, while `NOT EXISTS` returned the correct 393.

**5. What is a CTE?**
A named result for one statement (`WITH name AS (…)`). It improves readability and lets you chain steps. It isn't materialised, so if you reference it twice, it can be evaluated twice.

**6. What is a recursive CTE?**
A CTE that references itself: an anchor query plus a recursive member joined by `UNION ALL`. I used one to generate a month calendar, and it's also used for hierarchies. `OPTION (MAXRECURSION n)` limits depth.

**7. Window function vs GROUP BY?**
`GROUP BY` collapses rows. A window function (`OVER (PARTITION BY … ORDER BY …)`) adds a calculation but keeps every row.

**8. ROW_NUMBER vs RANK vs DENSE_RANK?**
`ROW_NUMBER` is always unique. `RANK` gives ties the same number and then skips (1, 2, 2, 4). `DENSE_RANK` gives ties the same number without skipping (1, 2, 2, 3).

**9. What do LAG and LEAD do?**
Access a value from a previous (`LAG`) or following (`LEAD`) row within the partition. I used `LAG(rating)` to find employees with two consecutive rating declines.

**10. How do you compute a running total?**
`SUM(x) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING)`. Specify `ROWS` explicitly, because the default `RANGE` frame treats ties differently and is slower.

**11. How do you compute a moving average?**
`AVG(x) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)` for a 3-period average.

**12. What does NTILE do?**
Splits ordered rows into n roughly equal buckets (quartiles, deciles). Ties can land on both sides of a boundary.

**13. What does PARTITION BY do?**
Restarts the window calculation for each group, like a `GROUP BY` that doesn't collapse rows.

**14. ROWS vs RANGE in a window frame?**
`ROWS` counts physical rows. `RANGE` includes all rows with the same ORDER BY value as the current row (peers).

**15. What's the LAST_VALUE gotcha?**
With an `ORDER BY` and no frame, the default frame ends at the current row, so `LAST_VALUE` returns the current row's value. Add `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING`.

**16. How do you find duplicate rows?**
`GROUP BY` the identifying columns and `HAVING COUNT(*) > 1`. In my cleaning I used `ROW_NUMBER() OVER (PARTITION BY key ORDER BY id)` to number copies.

**17. How do you delete duplicates, keeping one?**
Number the rows with `ROW_NUMBER` in a CTE and delete where `rn > 1`: `WITH d AS (SELECT ROW_NUMBER() OVER (PARTITION BY a, b ORDER BY id) rn FROM t) DELETE FROM d WHERE rn > 1;`

**18. How do you find the second highest salary?**
`DENSE_RANK() OVER (ORDER BY salary DESC)` and filter `= 2` (handles ties), or `OFFSET 1 ROW FETCH NEXT 1 ROW ONLY` on distinct salaries. Mention NULL handling if no second value exists.

**19. How do you get the top N rows per group?**
Rank within each group with `ROW_NUMBER() OVER (PARTITION BY group ORDER BY metric DESC)` in a CTE, then filter `rn <= N`. I used this for the top 3 earners per department.

**20. Clustered vs nonclustered index?**
A clustered index defines the physical order of the table, and there's one per table. A nonclustered index is a separate structure with pointers to the rows, and you can have many.

**21. What is a covering index?**
An index that contains every column a query needs (key columns plus `INCLUDE` columns), so SQL Server never looks up the base table. I created `IX_Attendance_date_status` that way.

**22. Stored procedure vs function?**
A procedure can run multiple statements, change data, use transactions and return several result sets. A function must return a value (scalar or table), can be used inside queries, and generally can't change data.

**23. What is a trigger, and when would you use one?**
Code that runs automatically after or instead of an insert, update or delete. Use it for rules a `CHECK` can't express (cross-table validation) or auditing. Avoid it for business logic that should be visible, and always write it set-based because it fires once per statement.

**24. What are ACID properties?**
Atomicity (all or nothing), Consistency (rules preserved), Isolation (concurrent transactions don't interfere), Durability (committed data survives failure).

**25. What are the isolation levels?**
`READ UNCOMMITTED`, `READ COMMITTED` (default), `REPEATABLE READ`, `SERIALIZABLE`, and snapshot isolation (including `READ COMMITTED SNAPSHOT`). Higher levels prevent more anomalies (dirty, non-repeatable, phantom reads) at the cost of concurrency.

**26. TRY_CAST and TRY_CONVERT: why use them?**
They return NULL instead of raising an error when a conversion fails, so you can find bad values: `WHERE TRY_CAST(x AS INT) IS NULL`. I used them to profile dirty staging data.

**27. What's wrong with DATEDIFF(YEAR, dob, today) for age?**
It counts year boundaries crossed, not full years. Subtract 1 if the birthday hasn't occurred yet this year. I wrapped that logic in `fn_AgeOn`.

**28. How do you split or parse strings in T-SQL?**
`CHARINDEX`, `SUBSTRING`, `LEFT`, `RIGHT`, `PATINDEX`, and `STRING_SPLIT` for delimited lists. I used `PATINDEX` to normalise review periods like `2024 H1` and `H1-2024`.

**29. How do you pivot data in SQL?**
Conditional aggregation (`SUM(CASE WHEN … THEN 1 ELSE 0 END)`) is the most portable way and works well. `PIVOT` is the T-SQL alternative, but it needs a fixed list of columns.

**30. Temp table vs table variable vs CTE?**
A CTE is for one statement and isn't materialised. A temp table (`#t`) is stored in tempdb, has statistics and indexes, and lasts for the session. A table variable (`@t`) is scoped to the batch and has weaker statistics, so it suits small row counts.

---

## C. Advanced (20)

**1. How do you read an execution plan?**
Use the actual plan and look for scans on large tables, key lookups, big gaps between estimated and actual rows, expensive sorts and hash matches, and missing-index hints. Pair it with `SET STATISTICS IO` for logical reads, which is the most reliable comparison metric.

**2. What is sargability?**
Whether a predicate can use an index seek. Functions on the column (`YEAR(date) = 2025`), leading wildcards and implicit conversions make a predicate non-sargable. Rewrite as `date >= '2025-01-01' AND date < '2026-01-01'`.

**3. What is a key lookup, and how do you remove it?**
For each row found in a nonclustered index, SQL Server fetches missing columns from the clustered index. Remove it by adding the columns to `INCLUDE`, or by selecting fewer columns.

**4. What are statistics, and why do they matter?**
Histograms of column values that the optimizer uses to estimate row counts and choose a plan. Stale statistics cause bad plans, so update them after large loads (`UPDATE STATISTICS`).

**5. What is parameter sniffing?**
The optimizer builds a plan from the first parameter values it sees and reuses it, which can be bad for very different values later. Mitigations include `OPTION (RECOMPILE)`, `OPTIMIZE FOR`, or better indexing.

**6. What is a deadlock, and how do you reduce them?**
Two transactions each hold a lock the other needs, and SQL Server kills one as the victim. Reduce them by accessing tables in a consistent order, keeping transactions short, using appropriate indexes, and considering snapshot isolation.

**7. Blocking vs deadlock?**
Blocking is one session waiting for another to release a lock, and it resolves when the lock is released. A deadlock is a circular wait that can't resolve without intervention.

**8. What is READ COMMITTED SNAPSHOT?**
Readers use row versions instead of shared locks, so readers don't block writers and writers don't block readers, at the cost of tempdb space.

**9. What causes index fragmentation, and how do you fix it?**
Inserts, updates and deletes that split pages leave the logical order different from the physical order. Check `sys.dm_db_index_physical_stats`, then `REORGANIZE` (about 5–30%) or `REBUILD` (above about 30%). It matters mainly for large indexes.

**10. What is a columnstore index and when is it better?**
Stores data by column in compressed segments. It's much better for large analytical scans and aggregates (millions of rows) than a rowstore b-tree index, but worse for frequent single-row updates.

**11. What is table partitioning?**
Splitting a large table into partitions by a key (for example, year) so maintenance and queries can target specific partitions. It's useful for very large tables, but not a substitute for good indexes.

**12. What is an indexed view?**
A view with a unique clustered index, so its result is stored and kept up to date. It can speed up aggregates but adds write cost and has many restrictions.

**13. What are the pitfalls of MERGE?**
It has historic bugs and race-condition risks under concurrency, and it can be hard to reason about. Many teams prefer separate `INSERT`/`UPDATE` statements (an upsert) with proper locking hints or constraints.

**14. How would you handle slowly changing dimensions?**
Type 1 overwrites the old value (no history). Type 2 adds a new row with effective-from/to dates (keeps history). Type 3 keeps a previous-value column. My project's `SalaryHistory` and `EmployeeChangeLog` follow the Type 2 idea.

**15. What is the gaps-and-islands problem, and how do you solve it?**
Finding consecutive runs in sequences. The classic trick is `value − ROW_NUMBER() OVER (ORDER BY value)`, which is constant within a run, so grouping by it identifies each island.

**16. How do you query a hierarchy such as an org chart?**
A recursive CTE: the anchor selects the root (`manager_id IS NULL`), the recursive step joins children to the previous level, and you track depth and path.

**17. What is dynamic SQL, and what are the risks?**
SQL built as a string and run with `sp_executesql`. It's useful for variable table or column names, but string concatenation invites SQL injection, so parameterise with `sp_executesql` and `QUOTENAME` for identifiers.

**18. Describe your approach to tuning a slow query.**
Reproduce it and capture a baseline (`STATISTICS IO/TIME`, actual plan). Find the expensive operators, then change **one thing at a time**: sargability, joins, a covering index, a set-based rewrite. Verify the results are identical, re-measure, and record the trade-offs such as write cost.

**19. How do you make a load process idempotent (safe to re-run)?**
Use `CREATE OR ALTER`, `DROP … IF EXISTS`, truncate or delete before reloading staging, wrap changes in a transaction, and key inserts on natural keys so re-runs don't duplicate rows. My staging load and cleaning scripts are re-runnable in this way.

**20. OLTP schema vs star schema (data warehouse)?**
OLTP is normalised for fast, consistent writes. A star schema (a fact table plus denormalised dimensions) is optimised for analytical reads. For heavier reporting I'd model `Attendance` and `PerformanceReviews` as facts with date, employee and department dimensions.
