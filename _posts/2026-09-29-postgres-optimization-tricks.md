---
layout: post
title: "[Databases] Database Optimization Tricks in Postgres"
date: 2026-09-29 00:00:00 +0530
categories: databases
tags: [databases, postgres, indexing, performance]
author: "Seroze"
published: true
---

A running collection of PostgreSQL optimization tricks, one section per trick.

## Contents
{:.no_toc}

* TOC placeholder — replaced by kramdown
{:toc}

## Covering index

A covering index is an index that contains all the columns a query needs, so PostgreSQL
can answer the query from the index alone without looking up the full table row.

For example, if you often run:

```sql
SELECT name
FROM users
WHERE email = 'a@example.com';
```

An index on `email` can find the matching row, but PostgreSQL may still need to visit the
table to fetch `name`.

You could make the index cover both columns:

```sql
CREATE INDEX ON users (email) INCLUDE (name);
```

Now `email` helps PostgreSQL find the row, and `name` is stored in the index for this query.

PostgreSQL may then use an **index-only scan**. It still sometimes checks the table for
visibility information, so a covering index doesn't guarantee that every query avoids
table access.

Use covering indexes for queries you run often and keep them focused: extra index columns
use disk space and make inserts and updates a bit more expensive.
