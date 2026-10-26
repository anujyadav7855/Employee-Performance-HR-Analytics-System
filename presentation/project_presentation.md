# Employee Performance & HR Analytics System: Presentation Outline

**Format:** 13 slides, about 10 minutes (about 45 seconds a slide), plus Q&A.
**Audience options:** hiring managers and interviewers (technical focus on slides 3–6, 11) or HR leadership (focus on slides 7–10, 12).
**Rule for every slide:** one message, at most one chart or table, and the number first.

---

## Slide 1: Title

**Employee Performance & HR Analytics System**
SQL Server · 400 employees · 2022–2025 · synthetic data
*Your name · GitHub link*

**Say:** "I built an end-to-end SQL project that takes messy HR data from raw files to a clean database, KPIs, and recommendations on why people are leaving."

---

## Slide 2: The problem

- HR data sits in separate spreadsheets: employees, salaries, attendance, reviews, exits.
- Leadership can't answer: *Who is leaving? Are we losing our best people? What relates to it?*
- **Goal:** one trusted database, consistent KPIs, and actions.

**Say:** Frame it as a business problem before any technology. Mention the 20 business questions you started from.

---

## Slide 3: Data and pipeline

**Diagram:** `CSV files → stg (raw text) → clean (typed, rejects logged) → final tables → views / procedures`

- 8 source files, **296,960 attendance rows**, 406 employee rows
- Raw data was messy on purpose: duplicates, mixed date formats, orphan IDs, impossible values

**Say:** "Loading everything as text first meant nothing failed on import, and I could profile the problems with SQL before touching the final tables."

---

## Slide 4: Database design

**Visual:** the ER diagram (`screenshots/er_diagram.png`)

- 8 core tables plus an audit table, normalised to 3NF
- 12 foreign keys, 14 check constraints, 7 unique constraints
- History kept in separate tables (salary, promotions, exits)

**Say:** Pick one design decision to explain: exits as their own table, or nullable date of birth ("I would rather store NULL than invent a value").

---

## Slide 5: Data quality: what I found and what I did

**Visual:** the raw-to-final reconciliation table (README, "Data cleaning in one table")

- Policy: **fix when the truth can be derived, quarantine when it can't, never invent**
- Example: a future hire date was repaired from the employee's first salary record
- Every change is logged, and every rejected row is kept with a reason

**Say:** Show one number that reconciles, for example Attendance 296,960 → 296,726 with each removed group named.

---

## Slide 6: KPIs I defined

| KPI | Definition |
|---|---|
| Attrition rate | Exits ÷ average headcount |
| Regretted attrition | Leavers whose last rating was 4–5 |
| Promotion rate | Promoted ÷ average headcount |
| Attendance / absenteeism | Present (Absent) records ÷ all records |

**Say:** "Defining the denominator precisely was the key step. 'Attrition' meant different things until I wrote it down."

---

## Slide 7: The scorecard

**Visual:** line chart of attrition by year, with the scorecard table underneath

| | 2022 | 2023 | 2024 | 2025 |
|---|---|---|---|---|
| Attrition % | 8.01 | 8.50 | 9.56 | **11.07** |
| Voluntary % | 6.19 | 6.80 | 8.90 | 10.40 |
| Headcount | 286 | 302 | 305 | 291 |

**Say:** "Attrition has risen every year, and nearly all of it is resignations."

---

## Slide 8: Where and who

**Visual:** attrition by department, 2022 vs 2025

- **Customer Support: 3.1% → 17.7%**, and it is the lowest-paid department
- IT 12.2% in 2025; Sales has the highest exit share (37%)
- **37% of reviewed leavers were rated 4–5**

**Say:** Note the caveat that HR and Marketing are small, so one exit moves their rate.

---

## Slide 9: What did NOT explain it (my favourite slide)

| Pay position on 31 Dec 2024 | Left in 2025 |
|---|---|
| Under 90% of role average | 10.7% |
| 90–110% | 12.0% |
| Over 110% | 8.3% |

- I tested "underpaid people leave" with a point-in-time cohort, and it **wasn't supported**
- But "Better Pay" is the top stated exit reason, so the two sources disagree

**Say:** "I report negative results. The recommendation is to get market pay data and better exit-reason capture, not to assume."

---

## Slide 10: Early-warning signals

- **Absence vs performance:** average rating 4.04 → 2.80 from the lowest to the highest absence quartile
- 7 employees dropped a full rating point; 21 active employees had two declines in a row
- Performance overall is flat (3.40–3.42), so it doesn't explain the rise in exits

**Say:** "These are associations, not causes, but they give managers a short, specific list."

---

## Slide 11: Recommendations

| Priority | Action | KPI |
|---|---|---|
| 1 | Workload and pay review for Customer Support | Attrition below 10% |
| 2 | Stay conversations for top-rated and underpaid high performers | Regretted attrition |
| 3 | Decide the hiring policy (headcount fell 14 in 2025) | Headcount, workload |
| 4 | Review IT and Sales manager pay bands (4 people paid above their manager) | No undocumented inversions |

**Say:** Give each action an owner and a metric.

---

## Slide 12: Technical highlights

- **Window functions, CTEs (incl. recursive), cohort analysis** for the findings
- **Tuning:** measured with `STATISTICS IO` and plans; sargable filters, a covering index, a single-pass rewrite; I also documented indexes I chose **not** to add
- **Programmability:** 5 views, 2 functions, 4 procedures (one multi-table transaction), 3 triggers incl. an audit trigger

**Say:** Choose one to explain in depth, for example "the promotion procedure changes three tables inside a transaction, so a failure can't leave a promotion without a raise."

---

## Slide 13: Limitations and next steps

- Synthetic data: findings show the method, not real-world truth
- 3 exit records quarantined, so attrition is slightly understated
- **Next:** Power BI dashboard, market salary data, an attrition-risk model in Python, scheduled loads

**Say:** End on the question you'd ask next: "With real data, I'd first test the pay hypothesis against external benchmarks."

---

## Appendix slides (keep ready for questions)

- Top performers list, high-absence list, promotion-ready list (9 employees)
- Cleaning policy table
- Index decision table
- Query examples: `LAG` for rating declines, the `NOT IN` vs `NOT EXISTS` trap

## Delivery tips

- Rehearse once with a timer and trim the slide you rush.
- Memorise the five numbers: **8.0% → 11.1%**, **3.1% → 17.7%**, **37%**, **4.04 → 2.80**, **−14 headcount**.
- Prepare a one-sentence answer for "what would you do differently?" (for example, define the KPI denominators on day one).
