---
layout: post
title: "[AtCoder] ABC471 D — Chargers: subtract the common term"
date: 2026-08-16 00:00:00 +0530
categories: competitive-programming
tags: [competitive_programming, atcoder, heap, invariants]
author: "Seroze"
published: true
---

Problem: [ABC471 D — Chargers](https://atcoder.jp/contests/abc471/tasks/abc471_d)

---

Batteries plug in at time $$t$$ with charge $$w$$, gain 1 charge per unit time, cap at $$V$$. Each query either plugs one in or unplugs the one with the highest charge. A heap keyed on $$w$$ is wrong — charges keep moving, so the order looks dynamic.

Writing it out kills the problem. At time $$T$$, an unsaturated battery holds

$$\text{charge}(T) = w + (T - t) = T + (w - t)$$

$$T$$ is the same for everyone, so comparing two batteries is comparing $$w_1 - t_1$$ against $$w_2 - t_2$$ — constants. The order is fixed at insertion time. Key the heap on $$w - t$$, clamp with `min(V, ...)` on the way out; saturation is safe because the largest $$w - t$$ saturates first and ties at $$V$$ don't matter.

```python
import sys
from heapq import heappush, heappop

def main():
    data = sys.stdin.buffer.read().split()
    q, v = int(data[0]), int(data[1])
    out, pq, i = [], [], 2
    for _ in range(q):
        if data[i] == b'1':
            t, w = int(data[i + 1]), int(data[i + 2])
            heappush(pq, (-(w - t), t, w))
            i += 3
        else:
            cur = int(data[i + 1])
            if pq:
                _, t, w = heappop(pq)
                out.append(str(min(v, w + cur - t)))
            else:
                out.append('-1')
            i += 2
    sys.stdout.write('\n'.join(out))

main()
```

$$O(Q \log Q)$$. I got here on gut feeling, but the gut was just pattern-matching the actual reason: whenever every candidate's value is `common_part + item_specific_part`, the common part drops out of every comparison and what's left is a static key.
