# TelcoDB: Mobile Subscriber & Usage Analytics

A SQL learning project built around a fictional mobile operator database. All names, numbers and data are made up and not affiliated with any real company.

## Schema

- `customers`: who the subscribers are (city, segment, signup date)
- `plans`: tariffs with monthly fee, data and minutes
- `subscriptions`: phone numbers linking customers to plans, with status
- `usage_records`: calls, SMS and data usage per subscription

## Setup

Requires SQLite. From this folder:

```
sqlite3 telco.db
.read schema.sql
```

## Progress

- [x] Schema design and seed data
- [x] SELECT, WHERE, ORDER BY, LIMIT, LIKE, BETWEEN, IN
- [ ] Joins
- [ ] GROUP BY, HAVING, aggregates
- [ ] Subqueries and CTEs
- [ ] Window functions
- [ ] Indexes and EXPLAIN on a large generated dataset
- [ ] Migration to PostgreSQL

## Tools

SQLite, DB Browser for SQLite
