---
layout: post
title: "Two Pointers in Competitive Programming"
date: 2026-06-18 00:00:00 +0530
categories: competitive-programming
tags: [competitive-programming, two-pointers, arrays]
author: "Seroze"
published: true
---

*Two pointers turns an O(n²) brute force into O(n) by exploiting monotonicity — once you move a pointer in one direction, you never need to go back.*

---

## The core idea

Two pointers works when the search space has a **monotone property**: if a pair `(l, r)` satisfies some condition, moving one pointer in a given direction either keeps or breaks the condition in a predictable way. This lets you eliminate an entire dimension of brute force.

There are two main patterns:

1. **Converging** — pointers start at opposite ends and move toward each other.
2. **Sliding window** — both pointers start at the left and the right pointer expands while the left pointer shrinks to maintain a constraint.

---

## Pattern 1 — Converging pointers

**Use when:** the array is sorted (or the problem has a symmetric structure) and you're looking for a pair satisfying some condition on both ends.

### Two sum in a sorted array

Find two indices `i < j` such that `a[i] + a[j] == target`.

```cpp
bool two_sum(vector<int>& a, int target) {
    int l = 0, r = a.size() - 1;
    while (l < r) {
        int sum = a[l] + a[r];
        if (sum == target) return true;
        else if (sum < target) l++;   // need larger sum, move left pointer right
        else r--;                      // need smaller sum, move right pointer left
    }
    return false;
}
```

Why this works: the array is sorted, so `a[l] + a[r]` is the largest possible sum for the current window. If it's too small, `a[l]` is useless as a left partner for any right pointer — move `l` right. If too large, `a[r]` is useless — move `r` left.

### Three sum (find all unique triplets summing to zero)

Fix one element, then run two-sum on the rest.

```cpp
vector<vector<int>> three_sum(vector<int> a) {
    sort(a.begin(), a.end());
    vector<vector<int>> res;
    int n = a.size();

    for (int i = 0; i < n - 2; i++) {
        if (i > 0 && a[i] == a[i-1]) continue;  // skip duplicates

        int l = i + 1, r = n - 1;
        while (l < r) {
            int sum = a[i] + a[l] + a[r];
            if (sum == 0) {
                res.push_back({a[i], a[l], a[r]});
                while (l < r && a[l] == a[l+1]) l++;  // skip duplicates
                while (l < r && a[r] == a[r-1]) r--;
                l++; r--;
            } else if (sum < 0) l++;
            else r--;
        }
    }
    return res;
}
```

Time: $$O(n^2)$$ — sorting is $$O(n \log n)$$, but the outer loop with inner two-pointer is $$O(n^2)$$.

### Container with most water

Given heights `h[0..n-1]`, find `i < j` that maximizes `(j - i) * min(h[i], h[j])`.

```cpp
int max_water(vector<int>& h) {
    int l = 0, r = h.size() - 1, ans = 0;
    while (l < r) {
        ans = max(ans, (r - l) * min(h[l], h[r]));
        if (h[l] < h[r]) l++;   // shorter side limits us — try a taller left
        else r--;                // try a taller right
    }
    return ans;
}
```

The invariant: always move the pointer on the shorter side. Moving the taller side can only decrease or maintain width while keeping the height the same — it can never increase the water.

---

## Pattern 2 — Sliding window

**Use when:** you need the longest/shortest subarray satisfying some constraint. The right pointer expands the window; the left pointer shrinks it when the constraint is violated.

The template:

```cpp
int l = 0;
for (int r = 0; r < n; r++) {
    // add a[r] to window state

    while (/* window constraint violated */) {
        // remove a[l] from window state
        l++;
    }

    // window [l, r] is now valid — update answer
}
```

### Longest subarray with sum ≤ k (non-negative elements)

```cpp
int longest_subarray(vector<int>& a, int k) {
    int l = 0, sum = 0, ans = 0;
    for (int r = 0; r < a.size(); r++) {
        sum += a[r];
        while (sum > k) {
            sum -= a[l];
            l++;
        }
        ans = max(ans, r - l + 1);
    }
    return ans;
}
```

This only works with non-negative elements — because adding elements always increases the sum, the window is monotone: once sum > k, shrinking from the left will reduce it.

### Longest substring with at most k distinct characters

```cpp
int longest_k_distinct(string s, int k) {
    unordered_map<char, int> freq;
    int l = 0, ans = 0;
    for (int r = 0; r < s.size(); r++) {
        freq[s[r]]++;
        while (freq.size() > k) {
            freq[s[l]]--;
            if (freq[s[l]] == 0) freq.erase(s[l]);
            l++;
        }
        ans = max(ans, r - l + 1);
    }
    return ans;
}
```

### Minimum window substring

Find the shortest window in `s` containing all characters of `t`.

```cpp
string min_window(string s, string t) {
    unordered_map<char, int> need, have_map;
    for (char c : t) need[c]++;

    int have = 0, required = need.size();
    int l = 0, best_l = 0, best_len = INT_MAX;

    for (int r = 0; r < s.size(); r++) {
        char c = s[r];
        have_map[c]++;
        if (need.count(c) && have_map[c] == need[c]) have++;

        while (have == required) {
            if (r - l + 1 < best_len) { best_len = r - l + 1; best_l = l; }
            have_map[s[l]]--;
            if (need.count(s[l]) && have_map[s[l]] < need[s[l]]) have--;
            l++;
        }
    }
    return best_len == INT_MAX ? "" : s.substr(best_l, best_len);
}
```

---

## Pattern 3 — Two pointers on two arrays

**Use when:** merging or comparing two sorted arrays.

### Count pairs with sum equal to target (across two arrays)

Given sorted arrays `a` and `b`, count pairs `(a[i], b[j])` with `a[i] + b[j] == target`.

```cpp
int count_pairs(vector<int>& a, vector<int>& b, int target) {
    int i = 0, j = b.size() - 1, count = 0;
    while (i < a.size() && j >= 0) {
        int sum = a[i] + b[j];
        if (sum == target) { count++; i++; j--; }
        else if (sum < target) i++;
        else j--;
    }
    return count;
}
```

### Merge two sorted arrays

```cpp
vector<int> merge(vector<int>& a, vector<int>& b) {
    vector<int> res;
    int i = 0, j = 0;
    while (i < a.size() && j < b.size()) {
        if (a[i] <= b[j]) res.push_back(a[i++]);
        else res.push_back(b[j++]);
    }
    while (i < a.size()) res.push_back(a[i++]);
    while (j < b.size()) res.push_back(b[j++]);
    return res;
}
```

---

## When two pointers does NOT work

- **Unsorted array for pair-sum problems** — you can't make a monotone argument without sorting first.
- **Negative numbers in sliding window** — adding an element doesn't necessarily increase the sum, so shrinking the window doesn't guarantee removing the violation.
- **Non-contiguous selections** — two pointers only works when the answer is a contiguous subarray or a pair defined by the pointer positions.

For sliding window with negative numbers, use a deque (monotone queue) or segment tree instead.

---

## Quick reference

| Problem shape | Pattern | Prerequisite |
|---|---|---|
| Pair with target sum | Converging | Sorted array |
| Triplet with target sum | Outer loop + converging | Sorted array |
| Longest subarray with constraint | Sliding window | Non-negative values (for sum constraints) |
| Shortest window containing all of t | Sliding window (shrink when valid) | — |
| Pairs across two arrays | Two-array converging | Both arrays sorted |
| Merge two sequences | Two-array forward scan | Both arrays sorted |

**The decision rule:** if you can argue that once you discard a pointer position you will never need it again — two pointers works.
