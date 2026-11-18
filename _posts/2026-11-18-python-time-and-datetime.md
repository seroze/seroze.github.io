---
layout: post
title: "[Python] time and datetime: every API, with examples"
date: 2026-11-18 00:00:00 +0530
categories: python
tags: [python, datetime, time, timezones]
author: "Seroze"
published: true
---

A quick reference for Python's two clock modules. The split is simple:

- **`time`** is a thin layer over the operating system's clocks. Use it to **measure**
  (how long did this take?) and to **sleep**.
- **`datetime`** is about **calendar dates and times** that people read: "18 November
  2026, 9:30 in Kolkata". Use it for timestamps, dates and durations.

Every output below was produced on Python 3.14, with the machine's zone set to
`Asia/Kolkata`. For more on naive vs aware datetimes and DST, see the
[datetime section of the Python primer](/python-primer/#datetime-and-date).

## Contents

- [The `time` module](#the-time-module)
- [`datetime.date`](#datetimedate)
- [`datetime.time`](#datetimetime)
- [`datetime.datetime`](#datetimedatetime)
- [`datetime.timedelta`](#datetimetimedelta)
- [`datetime.timezone` and `zoneinfo`](#datetimetimezone-and-zoneinfo)
- [Format codes](#format-codes)
- [Gotchas](#gotchas)

## The `time` module

### Clocks

| Function | Returns | Use it for |
|---|---|---|
| `time.time()` | seconds since the epoch (1 Jan 1970 UTC), `float` | a wall-clock timestamp |
| `time.monotonic()` | seconds from an arbitrary start, never goes backwards | timeouts, elapsed time |
| `time.perf_counter()` | the highest-resolution monotonic clock | benchmarking code |
| `time.process_time()` | CPU time of this process (user + system), excludes sleep | CPU cost of code |
| `time.thread_time()` | CPU time of the current thread | per-thread CPU cost |
| `..._ns()` versions | the same, as an `int` of nanoseconds | no float rounding |

Each has an `_ns` twin: `time_ns()`, `monotonic_ns()`, `perf_counter_ns()`,
`process_time_ns()`, `thread_time_ns()`.

```python
import time

start = time.perf_counter()
cpu = time.process_time()
time.sleep(0.2)
print(round(time.perf_counter() - start, 1))  # 0.2   wall time passed
print(round(time.process_time() - cpu, 2))    # 0.0   sleeping uses no CPU
```

`time.time()` can jump backwards when the system clock is corrected (NTP, or someone
changing it by hand). **Never measure durations with it**, or with `datetime.now()`.
Use `monotonic()` or `perf_counter()`.

`time.get_clock_info(name)` tells you what a clock really is on this machine:

```python
time.get_clock_info("monotonic")
# namespace(implementation='clock_gettime(CLOCK_MONOTONIC)', monotonic=True,
#           adjustable=False, resolution=1e-09)
```

### Sleeping

`time.sleep(secs)` pauses the current thread. It takes a float, so `time.sleep(0.05)` is
50 ms. Other threads keep running.

### `struct_time`: a timestamp broken into fields

| Function | Does |
|---|---|
| `time.gmtime(secs)` | timestamp → `struct_time` in UTC |
| `time.localtime(secs)` | timestamp → `struct_time` in local time |
| `time.mktime(st)` | local `struct_time` → timestamp (the inverse of `localtime`) |
| `time.strftime(fmt, st)` | `struct_time` → string |
| `time.strptime(s, fmt)` | string → `struct_time` |
| `time.asctime(st)` / `time.ctime(secs)` | fixed format like `Thu Jan  1 00:00:00 1970` |

```python
t = time.gmtime(0)
print(t)
# time.struct_time(tm_year=1970, tm_mon=1, tm_mday=1, tm_hour=0, tm_min=0,
#                  tm_sec=0, tm_wday=3, tm_yday=1, tm_isdst=0)
print(t.tm_year, t.tm_yday, t[0])                        # 1970 1 1970  (it's also a tuple)
print(time.strftime("%Y-%m-%d %H:%M", t))                # 1970-01-01 00:00
print(time.strptime("2026-11-18", "%Y-%m-%d")[:3])       # (2026, 11, 18)
print(time.mktime(time.localtime(86400)))                # 86400.0  round trip
```

`gmtime()` and `localtime()` with no argument use the current time. `tm_wday` counts
from Monday = 0.

### Local timezone info

| Name | Value in IST |
|---|---|
| `time.tzname` | `('IST', 'IST')`: names without and with DST |
| `time.timezone` | `-19800`: seconds **west** of UTC, so east is negative |
| `time.altzone` | the same, during DST |
| `time.daylight` | `0`: this zone has no DST |
| `time.tzset()` | re-read the `TZ` environment variable (Unix only) |

The sign of `time.timezone` is the opposite of the usual "+05:30". In practice, use
`datetime` and `zoneinfo` for zones instead.

### Low-level clocks (Unix)

`time.clock_gettime(clk_id)`, `clock_gettime_ns`, `clock_settime`, `clock_settime_ns`
and `clock_getres` read, set and query a specific POSIX clock, using constants like
`CLOCK_MONOTONIC`, `CLOCK_REALTIME`, `CLOCK_BOOTTIME` (counts time while suspended) and
`CLOCK_PROCESS_CPUTIME_ID`. `pthread_getcpuclockid(thread_id)` gives the clock for a
thread's CPU time. You rarely need these; `monotonic()` and friends cover the usual cases.

## `datetime.date`

A calendar date: year, month, day. No time, no timezone.

```python
from datetime import date, timedelta

d = date(2026, 11, 18)
d.year, d.month, d.day            # (2026, 11, 18)
d.weekday()                       # 2   Monday = 0
d.isoweekday()                    # 3   Monday = 1
d.isocalendar()                   # IsoCalendarDate(year=2026, week=47, weekday=3)
d.toordinal()                     # 739938   days since 1 Jan of year 1
d.replace(day=1)                  # 2026-11-01   (dates are immutable: returns a new one)
d.isoformat()                     # '2026-11-18'
d.strftime("%a %d %b %Y")         # 'Wed 18 Nov 2026'
d.ctime()                         # 'Wed Nov 18 00:00:00 2026'
d.timetuple()                     # a time.struct_time

date(2026, 12, 25) - d            # timedelta(days=37)
d + timedelta(weeks=2)            # 2026-12-02
```

Constructors:

| Constructor | Example |
|---|---|
| `date.today()` | today in local time |
| `date.fromisoformat(s)` | `date.fromisoformat("2026-11-18")` |
| `date.fromisocalendar(y, week, wd)` | `date.fromisocalendar(2026, 47, 3)` → 2026-11-18 |
| `date.fromordinal(n)` | inverse of `toordinal()` |
| `date.fromtimestamp(secs)` | local date of a timestamp |
| `date.strptime(s, fmt)` | `date.strptime("18/11/2026", "%d/%m/%Y")` (new in 3.14) |

Limits: `date.min` is `0001-01-01`, `date.max` is `9999-12-31` (the module constants
`MINYEAR = 1`, `MAXYEAR = 9999`), and `date.resolution` is one day.

## `datetime.time`

A time of day: hour, minute, second, microsecond, plus an optional `tzinfo` and
`fold`. It's not tied to any date, so you can't subtract two of them.

```python
from datetime import time as dtime   # avoid shadowing the time module

t = dtime(9, 30, 15, 500)
t                                    # 09:30:15.000500
t.hour, t.minute, t.second, t.microsecond   # (9, 30, 15, 500)
t.isoformat(timespec="minutes")      # '09:30'
t.replace(second=0)                  # 09:30:00.000500
t.strftime("%I:%M %p")               # '09:30 AM'
dtime.fromisoformat("09:30")         # 09:30:00
```

`time.strptime(s, fmt)` (new in 3.14) parses one. With a `tzinfo`, `utcoffset()`,
`tzname()` and `dst()` work too. `time.min` is `00:00`, `time.max` is
`23:59:59.999999`, and `time.resolution` is one microsecond.

## `datetime.datetime`

A date and a time together, which makes it a **point in time** when it has a timezone.
It's a subclass of `date`, so it has every `date` method as well.

```python
from datetime import datetime, UTC
from zoneinfo import ZoneInfo

dt = datetime(2026, 11, 18, 9, 30, tzinfo=UTC)
dt.isoformat()                       # '2026-11-18T09:30:00+00:00'
dt.timestamp()                       # 1794994200.0

ist = dt.astimezone(ZoneInfo("Asia/Kolkata"))
ist                                  # 2026-11-18 15:00:00+05:30   same instant
ist.tzname(), ist.utcoffset()        # ('IST', timedelta(seconds=19800))

dt.date()                            # 2026-11-18
dt.time()                            # 09:30:00          (drops the tzinfo)
dt.timetz()                          # 09:30:00+00:00    (keeps it)
dt.replace(tzinfo=None)              # 2026-11-18 09:30:00   naive: same digits, zone gone
dt.timetuple().tm_yday               # 322   day of the year
```

Constructors:

| Constructor | Gives |
|---|---|
| `datetime.now(tz)` | the current time; **pass `UTC`**, or you get naive local time |
| `datetime.today()` | naive local now; same as `now()` with no argument |
| `datetime.fromtimestamp(secs, tz)` | `datetime.fromtimestamp(0, UTC)` → `1970-01-01 00:00:00+00:00` |
| `datetime.fromisoformat(s)` | `"2026-11-18T09:30:00Z"` works (3.11+) |
| `datetime.strptime(s, fmt)` | any format; naive unless the format has `%z` |
| `datetime.combine(date, time)` | `datetime.combine(d, dtime(9, 30))` → `2026-11-18 09:30:00` |
| `datetime.fromordinal(n)`, `fromisocalendar(y, w, d)` | as for `date`, at midnight |

```python
datetime.strptime("18 Nov 2026 09:30 +0530", "%d %b %Y %H:%M %z")
# 2026-11-18 09:30:00+05:30
```

Other methods:

| Method | Does |
|---|---|
| `astimezone(tz)` | the same instant in another zone |
| `utcoffset()`, `tzname()`, `dst()` | ask the `tzinfo`; `None` for naive datetimes |
| `utctimetuple()` | `struct_time` in UTC |
| `ctime()`, `strftime(fmt)`, `isoformat(sep, timespec)` | to a string |

**Deprecated since 3.12:** `datetime.utcnow()` and `datetime.utcfromtimestamp()`. They
return a *naive* datetime that happens to hold UTC, which is easy to mistake for local
time. Use `datetime.now(UTC)` and `datetime.fromtimestamp(secs, UTC)`.

### `fold`: the repeated hour

When clocks go back for DST, a wall time like 1:30 AM happens twice. `fold=0` is the
first one, `fold=1` the second:

```python
ny = ZoneInfo("America/New_York")
a = datetime(2026, 11, 1, 1, 30, tzinfo=ny)
a.utcoffset()                        # -4 hours  (EDT, first 1:30)
a.replace(fold=1).utcoffset()        # -5 hours  (EST, second 1:30)
```

## `datetime.timedelta`

A duration. You get one by subtracting two dates or datetimes, and you add one to shift
a date.

```python
from datetime import timedelta

td = timedelta(days=1, hours=2, minutes=30)
td                                   # 1 day, 2:30:00
td.days, td.seconds, td.microseconds # (1, 9000, 0)   seconds is only the part under a day
td.total_seconds()                   # 95400.0        usually what you want
```

The constructor takes `weeks`, `days`, `hours`, `minutes`, `seconds`, `milliseconds`
and `microseconds`, and stores only days, seconds and microseconds. It supports
arithmetic:

```python
timedelta(hours=5) / timedelta(minutes=30)       # 10.0     how many fit
timedelta(hours=5) // 3                          # 1:40:00
timedelta(hours=5) % timedelta(hours=2)          # 1:00:00
abs(timedelta(hours=-3))                         # 3:00:00
```

Negative durations print strangely, because `days` carries the sign and `seconds` is
always positive:

```python
timedelta(hours=-1)                  # -1 day, 23:00:00
```

`timedelta.max` is `999999999 days, 23:59:59.999999`; `timedelta.resolution` is one
microsecond.

## `datetime.timezone` and `zoneinfo`

`tzinfo` is the abstract base class; you implement `utcoffset()`, `dst()`, `tzname()`
and optionally `fromutc()`. You'll almost never subclass it, because two ready-made
ones cover everything:

- **`timezone(offset, name=None)`**: a **fixed** offset from UTC, with no DST rules.
  `timezone.utc` (also `datetime.UTC`, 3.11+) is the UTC one.
- **`zoneinfo.ZoneInfo("Region/City")`**: a real zone from the IANA database, which
  knows its DST changes and history. Use this for anything a person lives in.

```python
from datetime import timezone, timedelta

tz = timezone(timedelta(hours=5, minutes=30), "IST")
tz.utcoffset(None), tz.tzname(None)  # (timedelta(seconds=19800), 'IST')
timezone(timedelta(hours=-3))        # UTC-03:00
timezone.utc is UTC                  # True
```

`timezone(timedelta(hours=-5))` is "5 hours behind UTC, always"; it's **not** New York,
which is −5 in winter and −4 in summer.

## Format codes

`strftime` turns a date into a string, `strptime` parses one. The common codes:

| Code | Meaning | Example |
|---|---|---|
| `%Y` / `%y` | year | `2026` / `26` |
| `%m` / `%d` | month / day, zero-padded | `11` / `18` |
| `%B` / `%b` | month name / short | `November` / `Nov` |
| `%A` / `%a` | weekday name / short | `Wednesday` / `Wed` |
| `%H` / `%I` | hour, 24 h / 12 h | `09` |
| `%M` / `%S` / `%f` | minute / second / microsecond | `30` / `15` / `000500` |
| `%p` | AM or PM | `AM` |
| `%z` / `%Z` | UTC offset / zone name | `+0530` / `IST` |
| `%j` | day of the year | `322` |
| `%U` / `%W` / `%V` | week number (Sunday start / Monday start / ISO) | `46` / `46` / `47` |
| `%%` | a literal `%` | `%` |

For ISO 8601 strings, skip format codes and use `isoformat()` / `fromisoformat()`: they
are faster and harder to get wrong.

## Gotchas

- **Naive and aware don't mix.** `datetime.now() < datetime.now(UTC)` raises
  `TypeError: can't compare offset-naive and offset-aware datetimes`. And `==` between
  them doesn't raise, it just returns `False`.
- **Store UTC, display local.** Save `datetime.now(UTC)`; call `astimezone(ZoneInfo(...))`
  only when showing it to someone.
- **Adding a day across DST isn't 24 hours.** In New York, noon on 7 March 2026 plus
  `timedelta(days=1)` is noon on 8 March, and only **23 hours** passed, because clocks
  sprang forward that night. Arithmetic on aware datetimes moves the wall clock.
- **Default arguments are evaluated once.** `def log(msg, ts=datetime.now())` freezes
  one timestamp forever. Use `ts=None` and fill it in inside the function.
- **`datetime` is a `date`.** `isinstance(datetime.now(), date)` is `True`, so check for
  `datetime` first when you need to tell them apart.
- **`from datetime import time` shadows the `time` module.** Import it as `dtime`, or
  write `datetime.time`.
- **Measure with `monotonic()` / `perf_counter()`**, not with `time.time()` or
  `datetime.now()`: those can jump when the system clock is corrected.
