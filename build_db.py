#!/usr/bin/env python3
"""Build telco.db from scratch.

FICTIONAL, synthetic data for a SQL portfolio project. Not affiliated with any
real company. Reproducible: same seed -> same database.

Usage:  python build_db.py [output.db]      (default: telco.db next to this file)
"""
import os
import random
import sqlite3
import sys
from datetime import date, timedelta

SEED = 42
TODAY = date(2026, 9, 30)          # fixed on purpose, so the data never changes
FIRST_SIGNUP = date(2023, 1, 1)
N_CUSTOMERS = 1000
N_SUBS = 1500
N_USAGE = 50000

HERE = os.path.dirname(os.path.abspath(__file__))
DB_PATH = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "telco.db")

FIRST = ["Ayşe", "Mehmet", "Fatma", "Ahmet", "Zeynep", "Mustafa", "Elif", "Emre",
         "Selin", "Burak", "Deniz", "Can", "Merve", "Kerem", "Lina", "Omar",
         "Karim", "Yasmin", "Nour", "Sara", "Hakan", "Esra", "Murat", "Ece",
         "Tarek", "Amira", "Cem", "Derya", "Yusuf", "Leyla"]
LAST = ["Demir", "Kaya", "Yıldız", "Arslan", "Şahin", "Çelik", "Yılmaz", "Aydın",
        "Öztürk", "Doğan", "Haddad", "Benali", "Karaca", "Polat", "Erdem",
        "Koç", "Aksoy", "Güneş", "Bulut", "Tekin", "Mansouri", "Bouzid",
        "Korkmaz", "Avcı", "Türk", "Kurt", "Özdemir", "Taş", "Işık", "Acar"]
CITIES = ["Istanbul", "Ankara", "Izmir", "Bursa", "Antalya", "Adana", "Konya", "Gaziantep"]
CITY_W = [35, 14, 11, 8, 8, 7, 9, 8]

# (plan_id, name, fee TRY, data GB, minutes, type). Plan 6 has no subscribers on purpose.
PLANS = [
    (1, "Starter",       250, 5,   500,  "postpaid"),
    (2, "Plus",          450, 20,  1000, "postpaid"),
    (3, "Max",           750, 60,  3000, "postpaid"),
    (4, "Prepaid Lite",  100, 2,   200,  "prepaid"),
    (5, "Prepaid Plus",  180, 8,   600,  "prepaid"),
    (6, "Legacy 2019",   150, 3,   300,  "postpaid"),
]
PLAN_W = {  # weights for plans 1..5 by segment
    "consumer": [30, 18, 4, 28, 20],
    "business": [10, 35, 45, 5, 5],
}
KINDS = ["call", "sms", "data"]
KIND_W = [40, 25, 35]


def iso(x):
    return x.isoformat()


def main():
    rng = random.Random(SEED)

    # ---- customers ----------------------------------------------------
    span = (TODAY - FIRST_SIGNUP).days
    customers, info = [], {}
    for cid in range(1, N_CUSTOMERS + 1):
        name = f"{rng.choice(FIRST)} {rng.choice(LAST)}"
        city = None if rng.random() < 0.03 else rng.choices(CITIES, CITY_W)[0]
        signup = FIRST_SIGNUP + timedelta(days=rng.randint(0, span))
        segment = "business" if rng.random() < 0.15 else "consumer"
        customers.append((cid, name, city, iso(signup), segment))
        info[cid] = (signup, segment)

    # ---- subscriptions ------------------------------------------------
    ids = list(info)
    no_sub = set(rng.sample(ids, N_CUSTOMERS // 10))        # ~10% never subscribe
    with_sub = [i for i in ids if i not in no_sub]
    owners = with_sub + rng.choices(with_sub, k=N_SUBS - len(with_sub))
    rng.shuffle(owners)

    subs, windows = [], {}
    for sid, cid in enumerate(owners, 1):
        signup, seg = info[cid]
        act = min(TODAY, signup + timedelta(days=rng.randint(0, 30)))
        plan = rng.choices([1, 2, 3, 4, 5], PLAN_W[seg])[0]
        status, canc = "active", None
        r = rng.random()
        if r < 0.15:
            c = act + timedelta(days=rng.randint(30, 700))
            if c <= TODAY:
                status, canc = "cancelled", c
        elif r < 0.20:
            status = "suspended"
        msisdn = f"+90 500 {sid // 10000:03d} {sid % 10000:04d}"
        subs.append((sid, cid, plan, msisdn, iso(act), status, iso(canc) if canc else None))
        if status == "cancelled":
            end = canc
        elif status == "suspended":
            end = max(act, TODAY - timedelta(days=90))
        else:
            end = TODAY
        windows[sid] = (act, end, plan)

    # ---- usage_records ------------------------------------------------
    never_used = set(rng.sample(range(1, N_SUBS + 1), int(N_SUBS * 0.08)))
    weights, factor = [], {}
    for sid in range(1, N_SUBS + 1):
        a, e, _ = windows[sid]
        weights.append(0 if sid in never_used else rng.lognormvariate(0, 0.7) * ((e - a).days + 1))
        factor[sid] = rng.lognormvariate(-0.3, 0.5)
    plan_mb = {p[0]: p[3] * 1024 for p in PLANS}

    picks = rng.choices(range(1, N_SUBS + 1), weights=weights, k=N_USAGE)
    usage = []
    for uid, sid in enumerate(picks, 1):
        a, e, plan = windows[sid]
        day = a + timedelta(days=rng.randint(0, (e - a).days))
        kind = rng.choices(KINDS, KIND_W)[0]
        if rng.random() < 0.03:
            q = 0.0                                          # zero-usage rows
        elif kind == "call":
            q = float(min(120, 1 + int(rng.expovariate(1 / 8))))
        elif kind == "sms":
            q = float(rng.randint(1, 25))
        else:
            q = round(plan_mb[plan] * factor[sid] * rng.uniform(0.03, 0.9), 1)
        usage.append((uid, sid, iso(day), kind, q))

    # ---- write ----------------------------------------------------------
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)
    con = sqlite3.connect(DB_PATH)
    con.execute("PRAGMA foreign_keys = ON")
    with open(os.path.join(HERE, "schema.sql"), encoding="utf-8") as f:
        con.executescript(f.read())
    con.execute("PRAGMA foreign_keys = ON")                  # executescript may reset state
    with con:
        con.executemany("INSERT INTO customers VALUES (?,?,?,?,?)", customers)
        con.executemany("INSERT INTO plans VALUES (?,?,?,?,?,?)", PLANS)
        con.executemany("INSERT INTO subscriptions VALUES (?,?,?,?,?,?,?)", subs)
        con.executemany("INSERT INTO usage_records VALUES (?,?,?,?,?)", usage)

    bad = con.execute("PRAGMA foreign_key_check").fetchall()
    assert not bad, f"foreign key violations: {bad[:3]}"
    for t in ("customers", "plans", "subscriptions", "usage_records"):
        n = con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        print(f"{t:15s} {n:>7,}")
    con.close()
    print(f"built {DB_PATH}  (seed={SEED}, as-of {TODAY})")


if __name__ == "__main__":
    main()
