# Project Interview Prep: Employee Performance & HR Analytics System

**Remember:** the data is synthetic, and you say so at the start. Every number below should match **your** database. Re-check them before an interview (run `database/project_audit.sql` and `SELECT * FROM dbo.vw_KpiScorecard`).

---

## 1. Resume bullets (pick 3–5)

- Designed and built a normalised SQL Server database (8 core tables, 12 foreign keys, 14 check and 7 unique constraints) for 400 employees and about 297K attendance records, with triggers and an audit table that enforce cross-table business rules.
- Built a `stg → clean → final` pipeline that profiled and cleaned deliberately messy data (duplicates, mixed date formats, orphan IDs, impossible values), reconciling every raw row to a fixed, removed or quarantined outcome (for example 296,960 → 296,726 attendance rows) with a full audit log.
- Defined 13 HR KPIs with exact formulas and a scorecard view; analysis with CTEs, window functions and point-in-time cohorts showed attrition rising from 8.0% to 11.1%, identified Customer Support as the fastest-worsening team (3% → 18%), and found that 37% of reviewed leavers were rated 4–5.
- Tuned queries with execution plans and `STATISTICS IO`: replaced non-sargable filters, added a covering index on the 297K-row attendance table, and rewrote repeated correlated subqueries as single-pass set-based queries *[add your own measured result here, for example "cutting logical reads by X%". Only include a number you actually measured]*.
- Delivered 5 views, 2 functions, 4 stored procedures (including a transactional promotion workflow) and 3 triggers; documented the work in a GitHub repository with a README, a 19-section report, reproducible scripts and a presentation.

**One-line summary for LinkedIn:** *End-to-end SQL Server HR analytics project: data cleaning pipeline, KPI scorecard, attrition analysis, query tuning and database programmability, published on GitHub.*

**Keywords (for applicant tracking systems):** SQL Server, T-SQL, data cleaning, ETL, data modelling, normalization, window functions, CTEs, stored procedures, triggers, views, indexing, query optimization, KPIs, data analysis.

---

## 2. Project questions with answers (15)

**1. Walk me through your project.**
"I built an HR analytics system in SQL Server using a synthetic dataset of 400 employees over four years. I loaded raw CSVs into staging tables, profiled the problems, cleaned them with a documented policy, and loaded a constrained database. Then I defined KPIs and analysed attrition. The main result is that attrition rose from 8% to 11%, mostly resignations, concentrated in Customer Support, and over a third of leavers were highly rated."

**2. Why did you use staging tables?**
Raw data contains values that would fail a typed, constrained import: text salaries, `DD-MM-YYYY` dates, duplicates. Loading everything as text meant nothing failed on import, and I could find every problem with SQL before touching the final tables.

**3. How did you handle duplicates?**
I numbered copies with `ROW_NUMBER() OVER (PARTITION BY key ORDER BY stg_row_id)` and kept the first. I logged the count removed in each table, and the final row counts reconcile exactly with raw counts minus the logged removals.

**4. What was your cleaning policy?**
Fix when the truth can be derived from other data, quarantine when it can't, and never invent values. Example: a future hire date was replaced by the employee's first salary record date, but a zero salary was quarantined because the true value is unknowable.

**5. How do you define attrition?**
Exits in the year divided by average headcount, where average headcount is (opening + closing) ÷ 2. I distinguished voluntary attrition (resignations) from total, and I added regretted attrition, meaning leavers whose last rating was 4–5.

**6. What was your most important finding?**
Voluntary attrition is rising, and Customer Support is the clearest hotspot, going from 3.1% to 17.7% in four years. It's also the lowest-paid department.

**7. Tell me about a hypothesis that turned out to be wrong.**
I expected underpaid employees to leave more. Using a point-in-time cohort (employees active on 31 Dec 2024, pay compared with the role average, exits during 2025), the under-90% group left at 10.7% against 12.0% for the middle group, so it wasn't supported. I reported it as a negative result and recommended market pay data and better exit-reason capture.

**8. Why did you quarantine rows instead of deleting them?**
It preserves the evidence, lets HR follow up with the data owner, and keeps counts reconcilable. Three exit records had dates before the hire date, so I quarantined them, and I stated that attrition is therefore slightly understated.

**9. How did you handle the under-18 birth dates?**
The true value was unknowable, and inventing one would be dishonest. I made `date_of_birth` nullable, set those three to NULL, and noted that age-based KPIs exclude them. This was a deliberate schema change that I documented.

**10. Why triggers, and why only a few?**
Two triggers enforce rules a `CHECK` can't (exit and promotion must be after the hire date, which needs another table). One audit trigger logs department, role and manager changes. I avoided triggers for business logic that should be visible.

**11. What indexes did you add, and which did you deliberately skip?**
I added a covering index on `Attendance(attendance_date)` with included columns, plus foreign-key support indexes. I skipped indexes on small tables, on `status` (only 4 distinct values), and on columns already covered by a unique constraint.

**12. How did you verify your cleaning was correct?**
Constraints during the transactional load, validation queries for cross-table rules (hire ≤ activity ≤ exit, department matches role), row-count reconciliation, and a final audit script with expected values.

**13. What are the biggest limitations?**
Synthetic data; three quarantined exits; managers aren't reviewed; transfers are tracked only from when the audit trigger was added; small departments give noisy rates; every association is not proof of cause.

**14. How would this scale to 100 times the data?**
Attendance would become the pressure point. I'd consider partitioning by year or a columnstore index, archive old years, schedule loads, and move reporting to a star schema or a BI layer.

**15. What would you do differently?**
Define KPI denominators on day one, because "attrition" meant different things until I wrote the formula down. I'd also capture exit reasons in a controlled list and collect market salary data earlier.

---

## 3. Database design questions

**D1. Why separate `Exits`, `SalaryHistory` and `Promotions` from `Employees`?**
Each is a history that changes over time and applies only to some employees. Keeping it in separate tables avoids NULL-heavy columns and repeating groups, and it preserves history instead of overwriting it.

**D2. Why surrogate identity keys?**
They're narrow, stable and independent of business data that can change (such as email). They also make a good clustered key because they're ever-increasing.

**D3. Why `ON DELETE NO ACTION` instead of `CASCADE`?**
HR history must never vanish silently. A cascading delete of an employee would wipe salary, review and attendance history.

**D4. Where did you deliberately break normalisation?**
`Employees.department_id` is derivable from the job role's department. I kept both to simplify queries and allow cross-department roles, and I validate that they agree. That redundancy also let me repair two bad department values.

**D5. How did you model the manager hierarchy?**
A self-referencing foreign key, `Employees.manager_id`. Department heads have NULL. Queries use a left self join so they aren't lost.

---

## 4. Optimization questions

**O1. How did you measure performance?**
`SET STATISTICS IO, TIME ON` and the actual execution plan. I compared logical reads (the stable metric), ran each test several times, and recorded before and after states.

**O2. Give an example of a non-sargable query and the fix.**
`WHERE YEAR(attendance_date) = 2025` can't seek an index. `WHERE attendance_date >= '2025-01-01' AND attendance_date < '2026-01-01'` can. The rewrite only helps when an index on that column exists, so you need both.

**O3. What is a covering index, and where did you use one?**
An index containing all columns a query needs. On `Attendance` I keyed on `attendance_date` and included `employee_id` and `status`, so rate calculations never touch the base table.

**O4. Why not index every column?**
Each index slows inserts and updates and uses space. Low-selectivity columns like `status` rarely help, and on small tables a scan is cheaper than maintaining an index.

**O5. Set-based vs row-by-row: what did you change?**
I replaced repeated correlated subqueries per year with one pass that reads `Employees` and `Exits` once and counts with `CASE`. The results were identical, and the plan was simpler.

---

## 5. Business insight questions

**B1. How would you present attrition to leadership?**
Lead with the trend (8.0% → 11.1%) and the two or three places it's concentrated, then the recommendation with an owner and a metric, and end with the caveats.

**B2. How do you separate correlation from causation?**
Look for confounders (performance, tenure), test with point-in-time cohorts, check for a plausible mechanism, and say "associated with", not "causes".

**B3. What is regretted attrition, and why track it?**
Losing people you'd have wanted to keep, which I proxy as leavers whose latest rating was 4–5. It's more costly than overall attrition.

**B4. How would you prioritise retention actions?**
By risk and value: the fastest-rising department first (Customer Support), then high performers, then the cheapest fixes, and measure the results.

**B5. What if the data contradicts what stakeholders believe?**
Show the evidence plainly (for example, underpaid employees didn't leave more), explain what the data can and can't show, and propose a better test instead of arguing.

---

## 6. Project explanations

### 2-minute version (elevator pitch)

> "I built an end-to-end HR analytics project in SQL Server, using a synthetic company of 400 employees over four years. The raw data was deliberately messy, with duplicates, mixed date formats and impossible values, so I loaded it into staging tables, profiled the problems, and cleaned it with a written policy: fix what can be derived, quarantine what can't, never invent values. Then I loaded a constrained database and defined 13 KPIs.
>
> The key result is that attrition rose from 8% to 11% over four years, almost entirely resignations. Customer Support went from 3% to nearly 18%, and more than a third of the people who left had been rated 4 or 5. I also tested whether underpaid employees left more, and found they didn't, so I recommended collecting market pay data instead of assuming.
>
> Along the way I tuned the slow queries, and built views, stored procedures and triggers. Everything is on GitHub with a README and a full report."

### 5-minute version

1. **Problem (30 s):** "HR data sat in separate spreadsheets, so leadership couldn't tell who was leaving or why. The goal was one trusted database, consistent KPIs and actions."
2. **Data and pipeline (60 s):** "Eight CSV files, almost 300,000 attendance rows. I loaded everything as text into staging, so nothing failed on import, profiled it with SQL (duplicates, bad formats, orphans, impossible values), cleaned it into a typed layer with every action logged, then loaded the final tables in a transaction. Raw and final row counts reconcile exactly."
3. **Design (45 s):** "Normalised to third normal form: eight core tables, twelve foreign keys, check and unique constraints. History lives in separate tables. Cross-table rules, like an exit date after the hire date, are enforced by triggers."
4. **KPIs (45 s):** "I wrote exact formulas. Attrition is exits divided by average headcount, which matters because headcount changes during the year. I added voluntary attrition, regretted attrition and cohort retention."
5. **Findings (75 s):** "Attrition rose from 8.0% to 11.1% and is mostly resignations. Customer Support is the hotspot, up from 3% to 18%, and it's the lowest-paid department. 37% of reviewed leavers were highly rated. Absence is an early-warning signal: ratings fall from 4.0 to 2.8 across absence quartiles. And one hypothesis failed: pay below the role average didn't predict who left."
6. **Engineering and close (45 s):** "I measured queries with execution plans, added a covering index and rewrote non-sargable filters. I built views, procedures with a transaction, and triggers. The main limitations are that the data is synthetic and three exit records were quarantined, so the next step would be real market pay data."

### 10-minute version (add depth and a live demo)

Use the 5-minute structure, then add:

- **Cleaning in detail (2 min):** show the policy table and one reconciliation, for example attendance 296,960 → 296,726, naming each removed group (blank dates, orphans, weekend rows, after-exit rows, duplicates). Explain one judgment call (trusting status over punch times) and one schema change (nullable date of birth).
- **A technical deep-dive (2 min):** pick one:
  - the `LAG` query for two consecutive rating declines, or
  - the point-in-time cohort query (why using 31 Dec 2024 pay and 2025 exits avoids survivorship bias), or
  - the promotion procedure: three tables changed inside a transaction with `XACT_ABORT`.
- **Optimization story (1 min):** the non-sargable `YEAR()` filter, why the rewrite alone didn't help until the index existed, and the indexes you chose **not** to build.
- **Live demo (1 min):** `SELECT * FROM dbo.vw_KpiScorecard ORDER BY kpi_year;` then `EXEC dbo.usp_AttritionByDepartment @Year = 2025;`.
- **Recommendations and trade-offs (1 min):** the prioritised actions, and the confidence level you attach to each finding.
- **Questions to expect:** "What would you do with real data?", "How did you know your cleaning was right?", "Which finding are you least sure about?" (answer: the promotion one, because the raw association weakens under a fairer test).

---

## 7. Final checklist before any interview

- [ ] I can say the data is synthetic and why that matters
- [ ] I know my five numbers: **8.0% → 11.1%**, **3.1% → 17.7%**, **37%**, **4.04 → 2.80**, **headcount −14**
- [ ] I can explain the attrition formula and why it uses average headcount
- [ ] I can describe one thing that went wrong and what I did about it
- [ ] I can open the repo, the scorecard view and one query without searching
