#!/usr/bin/env python3
"""
Employee Performance & HR Analytics System - synthetic raw dataset generator
=============================================================================
Creates 8 RAW CSV files (departments, job_roles, employees, salary_history,
attendance, performance_reviews, promotions, exits) for a fictional company,
Jan 2022 - Dec 2025.  All data is synthetic.

The raw files deliberately contain data-quality problems (duplicates, blanks,
inconsistent text, impossible values, orphan IDs, mixed date formats) so that
Day 5 (profiling) and Day 6 (cleaning) have real work to do.

Usage:  python generate_hr_dataset.py --out data
Note:   Output depends on the Python version's random generator.  The CSVs
        shipped with the project are the canonical dataset.
"""
import argparse
import csv
import os
import random
from collections import Counter, defaultdict
from datetime import date, timedelta

parser = argparse.ArgumentParser()
parser.add_argument("--out", default="data")
parser.add_argument("--base-hazard", type=float, default=0.032)
args = parser.parse_args()
os.makedirs(args.out, exist_ok=True)

random.seed(42)
START, END = date(2022, 1, 1), date(2025, 12, 31)
BASE_HALF = args.base_hazard


def r1000(x):
    return int(round(x / 1000.0)) * 1000


def clamp(x, lo, hi):
    return max(lo, min(hi, x))


def rand_date(a, b):
    return a + timedelta(days=random.randint(0, (b - a).days))


# --------------------------------------------------------------------------
# Reference data
# --------------------------------------------------------------------------
DEPARTMENTS = [
    (1, "HR", "Mumbai"), (2, "IT", "Bengaluru"), (3, "Finance", "Pune"),
    (4, "Sales", "Delhi"), (5, "Marketing", "Hyderabad"),
    (6, "Operations", "Mumbai"), (7, "Customer Support", "Delhi"),
]
HEADCOUNT = {1: 20, 2: 88, 3: 32, 4: 100, 5: 40, 6: 72, 7: 48}  # = 400

# (title, level, min_salary, max_salary, next_role_title, start_weight)
ROLE_DEFS = {
    1: [("HR Executive", "Junior", 300000, 600000, "HR Generalist", 4),
        ("HR Generalist", "Mid", 450000, 900000, "HR Business Partner", 4),
        ("Talent Acquisition Specialist", "Mid", 450000, 900000, "HR Business Partner", 3),
        ("HR Business Partner", "Senior", 900000, 1600000, None, 1.5),
        ("HR Manager", "Manager", 1200000, 2000000, None, 0)],
    2: [("IT Support Specialist", "Junior", 300000, 650000, "QA Engineer", 3),
        ("Data Analyst", "Mid", 400000, 800000, "Senior Data Analyst", 4),
        ("QA Engineer", "Mid", 450000, 1000000, "Software Engineer", 3),
        ("Software Engineer", "Mid", 800000, 1600000, "Senior Software Engineer", 5),
        ("Senior Data Analyst", "Senior", 700000, 1600000, None, 2),
        ("Senior Software Engineer", "Senior", 1400000, 2600000, None, 2),
        ("IT Manager", "Manager", 1500000, 2500000, None, 0)],
    3: [("Accounts Executive", "Junior", 300000, 600000, "Accountant", 4),
        ("Accountant", "Mid", 400000, 800000, "Financial Analyst", 4),
        ("Financial Analyst", "Mid", 500000, 1000000, "Senior Financial Analyst", 3),
        ("Senior Financial Analyst", "Senior", 900000, 1600000, None, 1.5),
        ("Finance Manager", "Manager", 1300000, 2200000, None, 0)],
    4: [("Sales Executive", "Junior", 300000, 700000, "Senior Sales Executive", 6),
        ("Account Manager", "Mid", 500000, 1000000, "Business Development Manager", 3),
        ("Senior Sales Executive", "Senior", 600000, 1200000, "Business Development Manager", 3),
        ("Business Development Manager", "Senior", 800000, 1500000, None, 1),
        ("Sales Manager", "Manager", 1000000, 1800000, None, 0)],
    5: [("Marketing Executive", "Junior", 300000, 600000, "Digital Marketing Specialist", 4),
        ("Content Strategist", "Mid", 400000, 850000, "Senior Marketing Specialist", 3),
        ("Digital Marketing Specialist", "Mid", 450000, 900000, "Senior Marketing Specialist", 4),
        ("Senior Marketing Specialist", "Senior", 800000, 1400000, None, 1.5),
        ("Marketing Manager", "Manager", 1200000, 2000000, None, 0)],
    6: [("Operations Associate", "Junior", 250000, 500000, "Operations Analyst", 5),
        ("Logistics Coordinator", "Mid", 350000, 700000, "Operations Analyst", 3),
        ("Operations Analyst", "Mid", 450000, 900000, "Senior Operations Analyst", 4),
        ("Senior Operations Analyst", "Senior", 800000, 1400000, None, 1.5),
        ("Operations Manager", "Manager", 1200000, 2000000, None, 0)],
    7: [("Support Associate", "Junior", 220000, 450000, "Customer Support Executive", 6),
        ("Customer Support Executive", "Mid", 300000, 600000, "Senior Support Executive", 4),
        ("Senior Support Executive", "Senior", 500000, 900000, "Support Team Lead", 2),
        ("Support Team Lead", "Lead", 600000, 1100000, None, 1),
        ("Support Manager", "Manager", 900000, 1600000, None, 0)],
}

roles, roles_by_dept, title_to_id = {}, defaultdict(list), {}
rid = 0
for d, lst in ROLE_DEFS.items():
    for (title, level, mn, mx, nxt, w) in lst:
        rid += 1
        roles[rid] = dict(id=rid, dept=d, title=title, level=level, min=mn,
                          max=mx, next=nxt, w=w)
        roles_by_dept[d].append(roles[rid])
        title_to_id[(d, title)] = rid
for r in roles.values():
    r["next_id"] = title_to_id[(r["dept"], r["next"])] if r["next"] else None
dept_manager_role = {d: next(r["id"] for r in roles_by_dept[d] if r["level"] == "Manager")
                     for d in HEADCOUNT}

MALE = ["Aarav", "Vihaan", "Arjun", "Rohan", "Karan", "Rahul", "Vikram", "Amit", "Sanjay", "Rajesh",
        "Manish", "Nikhil", "Aditya", "Siddharth", "Kunal", "Harsh", "Pranav", "Varun", "Deepak", "Gaurav",
        "Mohit", "Ankit", "Suresh", "Ramesh", "Naveen", "Tarun", "Yash", "Abhishek", "Ishaan", "Dev",
        "Ravi", "Sandeep", "Vivek", "Akash", "Pankaj", "Mayank", "Tushar", "Rishi", "Kabir", "Neeraj"]
FEMALE = ["Ananya", "Priya", "Neha", "Sneha", "Divya", "Pooja", "Kavya", "Isha", "Meera", "Riya",
          "Anjali", "Shreya", "Nisha", "Swati", "Aditi", "Tanvi", "Sakshi", "Komal", "Preeti", "Sunita",
          "Kritika", "Radhika", "Simran", "Pallavi", "Shruti", "Aarti", "Rashmi", "Nidhi", "Jyoti", "Bhavna",
          "Mansi", "Ritu", "Sonal", "Vidya", "Lakshmi", "Deepika", "Madhuri", "Payal", "Charu", "Trisha"]
LAST = ["Sharma", "Verma", "Gupta", "Singh", "Kumar", "Mehta", "Iyer", "Nair", "Rao", "Reddy",
        "Patel", "Shah", "Joshi", "Kulkarni", "Malhotra", "Chopra", "Khanna", "Bose", "Das", "Banerjee",
        "Chatterjee", "Mishra", "Pandey", "Tiwari", "Yadav", "Jain", "Agarwal", "Bansal", "Saxena", "Kapoor",
        "Menon", "Pillai", "Desai", "Thakur", "Rathore", "Chauhan", "Bhatt", "Sinha", "Ghosh", "Mukherjee",
        "Naidu", "Hegde", "Shetty", "Gill", "Sethi", "Arora", "Bhatia", "Kohli", "Dutta", "Sen"]
CITIES = ["Mumbai", "Delhi", "Bengaluru", "Pune", "Hyderabad", "Chennai", "Kolkata", "Ahmedabad"]
CITY_W = [20, 18, 18, 12, 12, 8, 6, 6]

# --------------------------------------------------------------------------
# 1. Build employees
# --------------------------------------------------------------------------
emps = []


def new_emp(dept, is_mgr):
    if is_mgr:
        hd, new_hire = rand_date(date(2014, 1, 1), date(2015, 12, 31)), False
    else:
        bucket = random.choices(["pre", 2022, 2023, 2024, 2025], [67.5, 10, 10, 7.5, 5])[0]
        if bucket == "pre":
            yr = random.choices(range(2014, 2022), [1, 1, 2, 2, 3, 3, 4, 4])[0]
            hd, new_hire = rand_date(date(yr, 1, 1), date(yr, 12, 31)), False
        else:
            end = date(2025, 10, 31) if bucket == 2025 else date(bucket, 12, 31)
            hd, new_hire = rand_date(date(bucket, 1, 1), end), True
    if is_mgr:
        role_id = dept_manager_role[dept]
    else:
        cands = [r for r in roles_by_dept[dept] if r["level"] != "Manager"]
        w = [r["w"] * (0.3 if (new_hire and r["level"] in ("Senior", "Lead")) else 1) for r in cands]
        role_id = random.choices(cands, w)[0]["id"]
    gender = random.choices(["Male", "Female", "Other"], [54, 45, 1])[0]
    first = random.choice(MALE if gender == "Male" else FEMALE if gender == "Female" else MALE + FEMALE)
    age = random.randint(32, 42) if is_mgr else random.randint(22, 40) if new_hire else random.randint(21, 38)
    dob = hd - timedelta(days=int(age * 365.25) + random.randint(0, 364))
    return dict(dept=dept, is_mgr=is_mgr, hire_date=hd, role_id=role_id, gender=gender,
                first=first, last=random.choice(LAST), dob=dob,
                city=random.choices(CITIES, CITY_W)[0],
                p=clamp(random.gauss(3.4, 0.6), 1.8, 4.8), forced_exit=None)


for d, n in HEADCOUNT.items():
    emps.append(new_emp(d, True))
    for _ in range(n - 1):
        emps.append(new_emp(d, False))

emps.sort(key=lambda e: (e["hire_date"], e["dept"]))
for i, e in enumerate(emps, 1):
    e["id"] = i
mgr_of_dept = {e["dept"]: e["id"] for e in emps if e["is_mgr"]}

# unique, tidy e-mail addresses
used_mail = Counter()
for e in emps:
    base = f"{e['first']}.{e['last']}".lower()
    used_mail[base] += 1
    e["email"] = (f"{base}@company.com" if used_mail[base] == 1
                  else f"{base}{used_mail[base]}@company.com")

# five older employees retire during the period
pre_staff = [e for e in emps if not e["is_mgr"] and e["hire_date"] <= date(2019, 12, 31)]
for e in random.sample(pre_staff, 5):
    e["dob"] = date(random.randint(1960, 1962), random.randint(1, 12), random.randint(1, 28))
    e["forced_exit"] = rand_date(date(2022, 6, 1), date(2025, 11, 30))

# --------------------------------------------------------------------------
# 2. Simulate salary, promotions and exits (half-year steps)
# --------------------------------------------------------------------------
DEPT_F = {1: 0.7, 2: 1.0, 3: 0.7, 4: 1.5, 5: 1.0, 6: 1.1, 7: 1.7}
REASON_W = ["Better Pay", "Career Growth", "Work-Life Balance", "Relocation",
            "Higher Studies", "Personal Reasons", "Management Issues"]


def simulate(e):
    role, hd = roles[e["role_id"]], e["hire_date"]
    sal_hist, promos, exit_rec = [], [], None
    if hd < START:
        pos = random.uniform(0.3, 0.7) if e["is_mgr"] else random.uniform(0.15, 0.6)
        s22 = r1000(role["min"] + (role["max"] - role["min"]) * pos)
        yrs = (START - hd).days / 365.25
        sal_hist.append((hd, r1000(s22 / (1.06 ** min(yrs, 6))), "Hire"))
        sal_hist.append((START, s22, "Adjustment"))     # opening balance on 2022-01-01
        cur = s22
    else:
        cur = r1000(role["min"] + (role["max"] - role["min"]) * random.uniform(0.1, 0.5))
        sal_hist.append((hd, cur, "Hire"))
    last_change = hd

    for y in range(2022, 2026):
        for half in (1, 2):
            h_start = date(y, 1, 1) if half == 1 else date(y, 7, 1)
            h_end = date(y, 6, 30) if half == 1 else date(y, 12, 31)
            if hd > h_end:
                continue
            exit_dt = etype = reason = None
            eff_start = max(h_start, hd + timedelta(days=120))
            pos = (cur - role["min"]) / float(role["max"] - role["min"])
            mir = (h_start - last_change).days / 30.4
            if e["forced_exit"] and h_start <= e["forced_exit"] <= h_end:
                exit_dt, etype, reason = e["forced_exit"], "Retirement", "Retirement"
            elif not e["is_mgr"] and not e["forced_exit"] and eff_start <= h_end:
                hz = (BASE_HALF * DEPT_F[e["dept"]]
                      * (1.5 if pos < 0.25 else 0.6 if pos > 0.6 else 1.0)
                      * (1.4 if mir > 30 else 0.6 if mir < 12 else 1.0)
                      * (1.7 if e["p"] < 2.8 else 0.6 if e["p"] > 3.8 else 1.0))
                if random.random() < min(hz, 0.5):
                    exit_dt = rand_date(eff_start, h_end)
                    if random.random() < 0.05 + (0.30 if e["p"] < 2.7 else 0.0):
                        etype = "Termination"
                        reason = random.choices(
                            ["Performance", "Policy Violation", "Restructuring"],
                            [6 if e["p"] < 3 else 2, 1, 2])[0]
                    else:
                        etype = "Resignation"
                        w = [3 + (4 if pos < 0.3 else 0), 2 + (4 if mir > 30 else 0),
                             2 + (3 if e["dept"] in (4, 6, 7) else 0), 1.5, 1, 1.5, 1]
                        reason = random.choices(REASON_W, w)[0]
            ev = date(y, 4, 1) if half == 1 else date(y, 10, 1)
            if (not e["is_mgr"] and hd <= ev - timedelta(days=180)
                    and (exit_dt is None or exit_dt > ev)):
                promoted = False
                if role["next_id"] and (ev - last_change).days / 30.4 >= 18:
                    if random.random() < 0.03 + 0.4 * max(0.0, e["p"] - 3.4):
                        new = roles[role["next_id"]]
                        ns = r1000(max(cur * random.uniform(1.10, 1.22), new["min"]))
                        ns = max(min(ns, new["max"]), cur + 1000)
                        promos.append((ev, role["id"], new["id"]))
                        sal_hist.append((ev, ns, "Promotion"))
                        role, cur, last_change, promoted = new, ns, ev, True
                if half == 1 and not promoted and cur < role["max"]:
                    pct = clamp(0.04 + 0.025 * (e["p"] - 3.3) + random.gauss(0, 0.01), 0.01, 0.14)
                    ns = min(r1000(cur * (1 + pct)), role["max"])
                    if ns > cur:
                        sal_hist.append((ev, ns, "Annual Increment"))
                        cur = ns
            if exit_dt:
                exit_rec = (exit_dt, etype, reason)
                break
        if exit_rec:
            break
    e.update(sal_hist=sal_hist, promos=promos, exit=exit_rec, final_role=role["id"])


for e in emps:
    simulate(e)

# --------------------------------------------------------------------------
# 3. Reviews, attendance
# --------------------------------------------------------------------------
reviews = []
for e in emps:
    if e["is_mgr"]:
        continue
    for y in range(2022, 2026):
        for half in (1, 2):
            p_end = date(y, 6, 30) if half == 1 else date(y, 12, 31)
            if e["hire_date"] > p_end - timedelta(days=90):
                continue
            rdate = date(y, 6, random.randint(10, 25)) if half == 1 else date(y, 12, random.randint(5, 20))
            if e["exit"] and e["exit"][0] < rdate:
                continue
            rating = int(clamp(round(e["p"] + random.gauss(0, 0.55)), 1, 5))
            reviews.append([e["id"], mgr_of_dept[e["dept"]], f"{y}-H{half}", rdate, rating])

HOLIDAYS = {(1, 26), (3, 14), (8, 15), (10, 2), (11, 1), (12, 25)}
TS = [f"{m // 60:02d}:{m % 60:02d}:00" for m in range(1440)]
attendance = []
emp_window = {}
for e in emps:
    s = max(e["hire_date"], START)
    t = min(e["exit"][0], END) if e["exit"] else END
    emp_window[e["id"]] = (s, t)
    a_rate = clamp(0.03 + (3.3 - e["p"]) * 0.015 + random.gauss(0, 0.005), 0.005, 0.12)
    d = s
    while d <= t:
        if d.weekday() < 5 and (d.month, d.day) not in HOLIDAYS:
            r = random.random()
            if r < a_rate:
                attendance.append([d, e["id"], "Absent", "", ""])
            elif r < a_rate + 0.025:
                attendance.append([d, e["id"], "Leave", "", ""])
            else:
                ci = int(clamp(random.gauss(545, 18), 495, 630))
                if r < a_rate + 0.04:
                    co = ci + int(clamp(random.gauss(270, 20), 200, 330))
                    attendance.append([d, e["id"], "Half-Day", TS[ci], TS[co]])
                else:
                    co = ci + int(clamp(random.gauss(520, 30), 450, 600))
                    attendance.append([d, e["id"], "Present", TS[ci], TS[co]])
        d += timedelta(days=1)
attendance.sort(key=lambda r: (r[0], r[1]))

# --------------------------------------------------------------------------
# 4. Clean-data sanity checks (so Day 6 can load cleaned rows into the final tables)
# --------------------------------------------------------------------------
for e in emps:
    assert e["dob"] + timedelta(days=18 * 366) <= e["hire_date"]
    seen = set()
    for (dt, sal, why) in e["sal_hist"]:
        assert sal > 0 and dt not in seen
        seen.add(dt)
    assert not e["exit"] or e["exit"][0] > e["hire_date"]
assert len({(r[1], r[0]) for r in attendance}) == len(attendance)
assert len({(r[0], r[2]) for r in reviews}) == len(reviews)
assert all(1 <= r[4] <= 5 and r[0] != r[1] for r in reviews)
for e in emps:
    for (dt, o, n) in e["promos"]:
        assert o != n and dt > e["hire_date"]

clean_counts = dict(employees=len(emps),
                    salary_history=sum(len(e["sal_hist"]) for e in emps),
                    attendance=len(attendance), reviews=len(reviews),
                    promotions=sum(len(e["promos"]) for e in emps),
                    exits=sum(1 for e in emps if e["exit"]))

# --------------------------------------------------------------------------
# 5. Build raw rows (as text) and inject deliberate data-quality problems
# --------------------------------------------------------------------------
iso = lambda d: d.isoformat()
issues = Counter()

emp_rows = [[str(e["id"]), e["first"], e["last"], e["gender"], iso(e["dob"]), iso(e["hire_date"]),
             e["email"], e["city"], str(e["dept"]), str(e["final_role"]),
             "" if e["is_mgr"] else str(mgr_of_dept[e["dept"]])] for e in emps]
by_id = {e["id"]: e for e in emps}

pool = [e["id"] for e in emps if not e["is_mgr"]]
random.shuffle(pool)
_it = iter(pool)
take = lambda n: [next(_it) for _ in range(n)]
row_of = lambda i: emp_rows[i - 1]

# gender variants
ids = take(12)
for i in ids[:5]:
    r = row_of(i); r[3] = {"Male": "M", "Female": "F", "Other": "O"}[r[3]]
for i in ids[5:9]:
    row_of(i)[3] = row_of(i)[3].lower()
for i in ids[9:]:
    row_of(i)[3] = row_of(i)[3].upper()
issues["employees: inconsistent gender values"] = 12
for i in take(10):
    row_of(i)[7] = ""
issues["employees: blank city"] = 10
ids = take(12)
for i in ids[:5]:
    row_of(i)[6] = row_of(i)[6].upper()
for i in ids[5:9]:
    row_of(i)[6] = " " + row_of(i)[6] + " "
for i in ids[9:]:
    row_of(i)[6] = ""
issues["employees: e-mail UPPERCASE"] = 5
issues["employees: e-mail with leading/trailing spaces"] = 4
issues["employees: blank e-mail"] = 3
for i in take(4):
    row_of(i)[5] = iso(date(2027, random.randint(1, 12), random.randint(1, 28)))
issues["employees: hire_date in the future (2027)"] = 4
for i in take(3):
    row_of(i)[4] = iso(by_id[i]["hire_date"] - timedelta(days=int(16.5 * 365.25)))
issues["employees: under 18 at hire"] = 3
for i in take(2):
    row_of(i)[8] = "99"
issues["employees: department_id 99 (does not exist)"] = 2
for i in take(12):
    row_of(i)[5] = by_id[i]["hire_date"].strftime("%d-%m-%Y")
issues["employees: hire_date written DD-MM-YYYY"] = 12
for i in take(6):
    row_of(i)[4] = by_id[i]["dob"].strftime("%d/%m/%Y")
issues["employees: date_of_birth written DD/MM/YYYY"] = 6
ids = take(10)
for i in ids[:5]:
    row_of(i)[1] = "  " + row_of(i)[1].upper() + " "
for i in ids[5:]:
    row_of(i)[2] = row_of(i)[2].lower()
issues["employees: names with odd case/spaces"] = 10
for i in take(2):
    row_of(i)[10] = "9999"
issues["employees: manager_id 9999 (does not exist)"] = 2
ids = take(4)
for a, b in ((ids[0], ids[1]), (ids[2], ids[3])):
    row_of(b)[6] = row_of(a)[6].strip().lower() or "dup@company.com"
issues["employees: e-mail shared by two different employees (pairs)"] = 2
for i in random.sample(range(1, len(emps) + 1), 6):
    emp_rows.append(list(row_of(i)))
issues["employees: exact duplicate rows"] = 6

# salary history
sal_rows = [[str(e["id"]), iso(dt), str(sal), why] for e in emps for (dt, sal, why) in e["sal_hist"]]
idx = list(range(len(sal_rows))); random.shuffle(idx)
_si = iter(idx); stake = lambda n: [next(_si) for _ in range(n)]
for i in stake(4):
    sal_rows[i][2] = "-" + sal_rows[i][2]
for i in stake(2):
    sal_rows[i][2] = "0"
issues["salary_history: negative salary"] = 4
issues["salary_history: zero salary"] = 2
low = [i for i in idx[40:] if int(sal_rows[i][2]) < 600000 and sal_rows[i][3] == "Hire"][:4]
for i in low:
    sal_rows[i][2] = str(int(sal_rows[i][2]) * 10)
issues["salary_history: salary 10x too large (typo outlier)"] = len(low)
ch = [i for i in stake(20)]
for i in ch[:3]:
    sal_rows[i][3] = sal_rows[i][3].lower() + " "
for i in ch[3:6]:
    sal_rows[i][3] = sal_rows[i][3].upper()
for i in ch[6:8]:
    sal_rows[i][3] = "Annual Incr."
for i in ch[8:13]:
    sal_rows[i][3] = ""
for i in ch[13:17]:
    sal_rows[i][2] = "INR " + sal_rows[i][2]
issues["salary_history: change_reason casing/spacing/abbreviation"] = 8
issues["salary_history: blank change_reason"] = 5
issues["salary_history: salary written as 'INR 123456'"] = 4
for k in range(6):
    r = list(random.choice(sal_rows)); r[0] = str(9001 + k)
    sal_rows.append(r)
issues["salary_history: employee_id not in Employees (orphans)"] = 6
for r in random.sample(sal_rows[:-6], 3):
    sal_rows.append(list(r))
issues["salary_history: exact duplicate rows"] = 3

# attendance
att_rows = [[iso(r[0]), str(r[1]), r[2], r[3], r[4]] for r in attendance]
# columns here: date, emp, status, in, out  -> reorder at write time
n_att = len(att_rows)
aidx = random.sample(range(n_att), 1200); _ai = iter(aidx); atake = lambda n: [next(_ai) for _ in range(n)]
variants = {"Present": ["present", "PRESENT", "P", "Present "], "Absent": ["absent", "A", "Absent "],
            "Leave": ["leave", "L"], "Half-Day": ["Half Day", "half-day", "HD"]}
for i in atake(400):
    att_rows[i][2] = random.choice(variants[att_rows[i][2]])
issues["attendance: status spelling variants (P, A, L, HD, lower/upper...)"] = 400
present_idx = [i for i in aidx[400:] if att_rows[i][2] == "Present"]
for i in present_idx[:25]:
    att_rows[i][3], att_rows[i][4] = att_rows[i][4], att_rows[i][3]
issues["attendance: check_out earlier than check_in"] = 25
for i in present_idx[25:85]:
    att_rows[i][3] = att_rows[i][4] = ""
issues["attendance: Present with blank times"] = 60
away = [i for i in random.sample(range(n_att), 4000) if att_rows[i][2] in ("Absent", "Leave")][:30]
for i in away:
    att_rows[i][3], att_rows[i][4] = "09:10:00", "18:00:00"
issues["attendance: Absent/Leave but with check-in/out times"] = len(away)
for i in random.sample(range(n_att), 6):
    att_rows[i][0] = ""
issues["attendance: blank attendance_date"] = 6
extra = []
for _ in range(40):                                    # weekend rows
    r = random.choice(att_rows)
    if not r[0] or r[0] > "2025-12-15":
        continue
    d = date.fromisoformat(r[0])
    sat = d + timedelta(days=5 - d.weekday())
    extra.append([iso(sat + timedelta(days=random.randint(0, 1))), r[1], "Present", "10:00:00", "15:00:00"])
issues["attendance: rows on Saturday/Sunday"] = len(extra)
exited = [e for e in emps if e["exit"] and e["exit"][0] <= date(2025, 11, 15)]
after = 0
while after < 20:
    e = random.choice(exited)
    d = e["exit"][0] + timedelta(days=random.randint(7, 30))
    if d.weekday() < 5 and d <= END:
        extra.append([iso(d), str(e["id"]), "Present", "09:05:00", "18:00:00"]); after += 1
issues["attendance: rows dated after the employee's exit"] = after
for r in random.sample(att_rows, 20):
    x = list(r); x[1] = str(9001 + random.randint(0, 4)); extra.append(x)
issues["attendance: employee_id not in Employees (orphans)"] = 20
for r in random.sample(att_rows, 150):
    extra.append(list(r))
issues["attendance: exact duplicate rows"] = 150
att_rows.extend(extra)
random.shuffle(att_rows)                               # raw exports are rarely sorted
att_out = [[r[1], r[0], r[2], r[3], r[4]] for r in att_rows]

# performance reviews
rev_rows = [[str(r[0]), str(r[1]), r[2], iso(r[3]), str(r[4])] for r in reviews]
ridx = random.sample(range(len(rev_rows)), 60); _ri = iter(ridx); rtake = lambda n: [next(_ri) for _ in range(n)]
for val, n in (("0", 4), ("6", 3), ("7", 2), ("", 3), ("Good", 3), ("N/A", 2)):
    for i in rtake(n):
        rev_rows[i][4] = val
issues["performance_reviews: invalid rating (0, 6, 7, blank, 'Good', 'N/A')"] = 17
for fmt, n in (("{y} H{h}", 4), ("{y}-h{h}", 3), ("H{h}-{y}", 3)):
    for i in rtake(n):
        y, h = rev_rows[i][2].split("-H")
        rev_rows[i][2] = fmt.format(y=y, h=h)
issues["performance_reviews: review_period format variants"] = 10
for i in rtake(4):
    rev_rows[i][1] = rev_rows[i][0]
issues["performance_reviews: reviewer is the employee themself"] = 4
for i in rtake(6):
    rev_rows[i][1] = ""
issues["performance_reviews: blank reviewer_id"] = 6
after = 0
while after < 6:
    e = random.choice(exited)
    rd = e["exit"][0] + timedelta(days=random.randint(20, 60))
    if rd <= END and not e["is_mgr"]:
        rev_rows.append([str(e["id"]), str(mgr_of_dept[e["dept"]]),
                         f"{rd.year}-H{1 if rd.month <= 6 else 2}", iso(rd), str(random.randint(2, 4))])
        after += 1
issues["performance_reviews: review dated after the employee's exit"] = after
for r in random.sample(rev_rows[:len(reviews)], 5):
    rev_rows.append(list(r))
issues["performance_reviews: exact duplicate rows"] = 5

# promotions
promo_rows = [[str(e["id"]), iso(dt), str(o), str(n)] for e in emps for (dt, o, n) in e["promos"]]
pidx = random.sample(range(len(promo_rows)), 5)
for i in pidx[:2]:
    promo_rows[i][3] = promo_rows[i][2]
issues["promotions: old_job_role_id = new_job_role_id"] = 2
for i in pidx[2:5]:
    promo_rows[i][1] = iso(by_id[int(promo_rows[i][0])]["hire_date"] - timedelta(days=200))
issues["promotions: promotion dated before hire"] = 3
r = list(promo_rows[0]); r[0] = "9002"; promo_rows.append(r)
issues["promotions: employee_id not in Employees (orphan)"] = 1
for r in random.sample(promo_rows[:-1], 2):
    promo_rows.append(list(r))
issues["promotions: exact duplicate rows"] = 2

# exits
exit_rows = [[str(e["id"]), iso(e["exit"][0]), e["exit"][1], e["exit"][2]] for e in emps if e["exit"]]
xidx = random.sample(range(len(exit_rows)), 32)
EXIT_VARIANTS = {"Resignation": ["resigned", "RESIGNATION", "Resign", "Resignation "],
                 "Termination": ["terminated", "Termination ", "TERMINATION"],
                 "Retirement": ["retired", "RETIREMENT"]}
for i in xidx[:12]:
    exit_rows[i][2] = random.choice(EXIT_VARIANTS[exit_rows[i][2]])
issues["exits: exit_type spelling variants"] = 12
for i in xidx[12:15]:
    exit_rows[i][1] = iso(by_id[int(exit_rows[i][0])]["hire_date"] - timedelta(days=30))
issues["exits: exit_date before hire_date"] = 3
for i in xidx[15:20]:
    exit_rows[i][3] = "N/A"
for i in xidx[20:26]:
    exit_rows[i][3] = ""
issues["exits: exit_reason 'N/A'"] = 5
issues["exits: blank exit_reason"] = 6
for i in xidx[26:32]:
    exit_rows[i][1] = date.fromisoformat(exit_rows[i][1]).strftime("%d/%m/%Y")
issues["exits: exit_date written DD/MM/YYYY"] = 6
exit_rows.append(["9003", "2024-05-15", "Resignation", "Better Pay"])
issues["exits: employee_id not in Employees (orphan)"] = 1
for r in random.sample(exit_rows[:-1], 3):
    exit_rows.append(list(r))
issues["exits: exact duplicate rows"] = 3

# --------------------------------------------------------------------------
# 6. Write CSV files
# --------------------------------------------------------------------------
def write(name, header, rows):
    with open(os.path.join(args.out, name), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    return len(rows)


counts = {}
counts["departments.csv"] = write("departments.csv", ["department_id", "department_name", "location"],
                                  [list(d) for d in DEPARTMENTS])
counts["job_roles.csv"] = write("job_roles.csv",
                                ["job_role_id", "job_title", "department_id", "job_level", "min_salary", "max_salary"],
                                [[r["id"], r["title"], r["dept"], r["level"], r["min"], r["max"]] for r in roles.values()])
counts["employees.csv"] = write("employees.csv",
                                ["employee_id", "first_name", "last_name", "gender", "date_of_birth", "hire_date",
                                 "email", "city", "department_id", "job_role_id", "manager_id"], emp_rows)
counts["salary_history.csv"] = write("salary_history.csv",
                                     ["employee_id", "effective_date", "base_salary", "change_reason"], sal_rows)
counts["attendance.csv"] = write("attendance.csv",
                                 ["employee_id", "attendance_date", "status", "check_in_time", "check_out_time"], att_out)
counts["performance_reviews.csv"] = write("performance_reviews.csv",
                                          ["employee_id", "reviewer_id", "review_period", "review_date", "rating"], rev_rows)
counts["promotions.csv"] = write("promotions.csv",
                                 ["employee_id", "promotion_date", "old_job_role_id", "new_job_role_id"], promo_rows)
counts["exits.csv"] = write("exits.csv", ["employee_id", "exit_date", "exit_type", "exit_reason"], exit_rows)

print("CLEAN (before injection):", clean_counts)
print("RAW data rows per file:")
for k, v in counts.items():
    print(f"  {k:26s} {v:>8,d}")
print("INJECTED ISSUES:")
for k, v in issues.items():
    print(f"  {v:>4d}  {k}")

# quick business-sense summary on the clean simulation
exits_by_dept = Counter(by_id[e["id"]]["dept"] for e in emps if e["exit"])
print("exits by dept:", dict(sorted(exits_by_dept.items())))
print("exits by year:", dict(sorted(Counter(e["exit"][0].year for e in emps if e["exit"]).items())))
print("exit types:", dict(Counter(e["exit"][1] for e in emps if e["exit"])))
print("promotions by year:", dict(sorted(Counter(p[0].year for e in emps for p in e["promos"]).items())))
