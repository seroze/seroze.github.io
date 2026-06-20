---
layout: post
title: "Backtracking — The Art of Systematic Undoing"
date: 2026-06-20 00:00:00 +0530
categories: competitive-programming
tags: [competitive-programming, backtracking, recursion, dfs]
author: "Seroze"
published: true
---

*Backtracking is just DFS on a decision tree — at each node you make a choice, recurse into it, and undo the choice before trying the next one.*

---

## The core idea

Every backtracking problem can be modeled as a tree where:

- Each **node** is a partial state (decisions made so far).
- Each **edge** is a single choice extending that state.
- **Leaves** are either valid complete solutions or dead ends.

Backtracking = exhaustive search with early termination. You explore the tree depth-first, and whenever a partial state can't lead to any valid solution, you **prune** the branch and backtrack to the parent.

The universal template:

```cpp
void backtrack(State& state, Choices& available) {
    if (is_solution(state)) {
        record(state);
        return;
    }

    for (Choice c : available) {
        if (!is_valid(state, c)) continue;   // prune

        apply(state, c);                      // choose
        backtrack(state, available);          // explore
        undo(state, c);                       // unchoose
    }
}
```

The critical discipline: **every `apply` must be mirrored by an `undo`**. If you forget to undo, choices from one branch bleed into siblings.

---

## Problem 1 — Subsets (power set)

Generate all subsets of `[1, 2, 3, ..., n]`.

At each index `i`, make a binary choice: include `a[i]` or skip it.

```cpp
vector<vector<int>> result;

void backtrack(vector<int>& a, int i, vector<int>& current) {
    result.push_back(current);           // every prefix is a valid subset

    for (int j = i; j < a.size(); j++) {
        current.push_back(a[j]);         // choose a[j]
        backtrack(a, j + 1, current);   // explore subsets starting after j
        current.pop_back();              // unchoose a[j]
    }
}

vector<vector<int>> subsets(vector<int>& a) {
    vector<int> current;
    backtrack(a, 0, current);
    return result;
}
```

The loop iterates `j` from `i` forward (not from 0) to avoid counting the same subset twice in different orderings. There are $$2^n$$ subsets, so time is $$O(2^n \cdot n)$$ (copying each subset takes $$O(n)$$).

---

## Problem 2 — Permutations

Generate all permutations of `n` distinct integers.

The trick: swap element `i` into position `start`, recurse on `[start+1, n)`, then swap back.

```cpp
vector<vector<int>> result;

void backtrack(vector<int>& a, int start) {
    if (start == a.size()) {
        result.push_back(a);
        return;
    }

    for (int i = start; i < a.size(); i++) {
        swap(a[start], a[i]);            // place a[i] at position start
        backtrack(a, start + 1);
        swap(a[start], a[i]);            // restore
    }
}

vector<vector<int>> permutations(vector<int> a) {
    backtrack(a, 0);
    return result;
}
```

There are $$n!$$ permutations, so time is $$O(n! \cdot n)$$.

**Permutations with duplicates:** sort first, then skip if `a[i] == a[start]` and `i != start` (same value was already placed at this position).

```cpp
void backtrack(vector<int>& a, int start) {
    if (start == a.size()) { result.push_back(a); return; }

    unordered_set<int> seen;
    for (int i = start; i < a.size(); i++) {
        if (seen.count(a[i])) continue;   // same value placed here before
        seen.insert(a[i]);
        swap(a[start], a[i]);
        backtrack(a, start + 1);
        swap(a[start], a[i]);
    }
}
```

---

## Problem 3 — Combination Sum

Given `candidates` (distinct positive integers) and a `target`, find all combinations that sum to `target`. You may use each number unlimited times.

The pruning key: sort first, then break early when `candidates[j] > remaining`.

```cpp
vector<vector<int>> result;

void backtrack(vector<int>& cands, int start, int remaining, vector<int>& current) {
    if (remaining == 0) {
        result.push_back(current);
        return;
    }

    for (int i = start; i < cands.size(); i++) {
        if (cands[i] > remaining) break;   // sorted — no point continuing

        current.push_back(cands[i]);
        backtrack(cands, i, remaining - cands[i], current);  // i, not i+1 (reuse allowed)
        current.pop_back();
    }
}

vector<vector<int>> combinationSum(vector<int>& candidates, int target) {
    sort(candidates.begin(), candidates.end());
    vector<int> current;
    backtrack(candidates, 0, target, current);
    return result;
}
```

For **Combination Sum II** (each element used once, may have duplicates): pass `i+1` and skip `cands[i] == cands[i-1]` at the same recursion depth.

```cpp
for (int i = start; i < cands.size(); i++) {
    if (i > start && cands[i] == cands[i-1]) continue;  // skip same value at same level
    if (cands[i] > remaining) break;
    current.push_back(cands[i]);
    backtrack(cands, i + 1, remaining - cands[i], current);
    current.pop_back();
}
```

---

## Problem 4 — N-Queens

Place `n` queens on an `n×n` board such that no two attack each other.

Constraint: no two queens share a column, row, or diagonal. Since we place one queen per row, rows are automatically distinct. Track forbidden columns and diagonals.

```cpp
int n;
vector<vector<string>> result;

// col[c] = queen in column c
// diag1[r-c+n] = queen on major diagonal (r-c constant)
// diag2[r+c]   = queen on minor diagonal (r+c constant)
vector<bool> col, diag1, diag2;

void backtrack(int row, vector<string>& board) {
    if (row == n) {
        result.push_back(board);
        return;
    }

    for (int c = 0; c < n; c++) {
        if (col[c] || diag1[row - c + n] || diag2[row + c]) continue;

        board[row][c] = 'Q';
        col[c] = diag1[row - c + n] = diag2[row + c] = true;

        backtrack(row + 1, board);

        board[row][c] = '.';
        col[c] = diag1[row - c + n] = diag2[row + c] = false;
    }
}

vector<vector<string>> solveNQueens(int _n) {
    n = _n;
    col.assign(n, false);
    diag1.assign(2 * n, false);
    diag2.assign(2 * n, false);
    vector<string> board(n, string(n, '.'));
    backtrack(0, board);
    return result;
}
```

The diagonal indexing is the key insight:
- Major diagonal: `r - c` is constant. Shift by `n` to avoid negatives: `r - c + n`.
- Minor diagonal: `r + c` is constant.

This gives $$O(1)$$ conflict checks instead of scanning the board each time.

---

## Problem 5 — Word Search on a grid

Given a 2D character grid and a word, determine whether the word exists as a connected path (horizontal/vertical, no cell reused).

```cpp
int rows, cols;
vector<vector<char>> grid;
string word;

bool backtrack(int r, int c, int idx) {
    if (idx == word.size()) return true;
    if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
    if (grid[r][c] != word[idx]) return false;

    char tmp = grid[r][c];
    grid[r][c] = '#';   // mark visited

    bool found = backtrack(r+1, c, idx+1)
              || backtrack(r-1, c, idx+1)
              || backtrack(r, c+1, idx+1)
              || backtrack(r, c-1, idx+1);

    grid[r][c] = tmp;   // restore
    return found;
}

bool exist(vector<vector<char>>& g, string w) {
    grid = g; word = w;
    rows = g.size(); cols = g[0].size();
    for (int r = 0; r < rows; r++)
        for (int c = 0; c < cols; c++)
            if (backtrack(r, c, 0)) return true;
    return false;
}
```

In-place mutation with restore (`grid[r][c] = '#'` then restore) avoids a separate `visited` array. This is a common trick in grid backtracking.

Worst case: $$O(m \cdot n \cdot 4^L)$$ where $$L$$ is word length — but in practice pruning cuts this heavily.

---

## Problem 6 — Sudoku Solver

Fill a 9×9 grid so each row, column, and 3×3 box contains digits 1–9 exactly once.

```cpp
bool used_row[9][10] = {}, used_col[9][10] = {}, used_box[9][10] = {};

int box(int r, int c) { return (r / 3) * 3 + c / 3; }

bool solve(vector<vector<char>>& board, int pos) {
    while (pos < 81 && board[pos/9][pos%9] != '.') pos++;
    if (pos == 81) return true;

    int r = pos / 9, c = pos % 9;
    for (int d = 1; d <= 9; d++) {
        if (used_row[r][d] || used_col[c][d] || used_box[box(r,c)][d]) continue;

        board[r][c] = '0' + d;
        used_row[r][d] = used_col[c][d] = used_box[box(r,c)][d] = true;

        if (solve(board, pos + 1)) return true;

        board[r][c] = '.';
        used_row[r][d] = used_col[c][d] = used_box[box(r,c)][d] = false;
    }
    return false;
}

void solveSudoku(vector<vector<char>>& board) {
    // initialize constraint sets from pre-filled cells
    for (int r = 0; r < 9; r++)
        for (int c = 0; c < 9; c++)
            if (board[r][c] != '.') {
                int d = board[r][c] - '0';
                used_row[r][d] = used_col[c][d] = used_box[box(r,c)][d] = true;
            }
    solve(board, 0);
}
```

Pre-computing `used_row/col/box` makes each candidate check $$O(1)$$. Without this, you'd scan the row/column/box for each digit — much slower.

---

## Problem 7 — Letter Combinations of a Phone Number

You're given a sequence of digit presses on an old T9 phone keypad (digits `2–9`). Each digit maps to 2–4 letters. Return every possible string that could have been typed.

```
2 → abc    3 → def    4 → ghi    5 → jkl
6 → mno    7 → pqrs   8 → tuv    9 → wxyz
```

Pressing `2` then `3` can produce any of: `ad, ae, af, bd, be, bf, cd, ce, cf`.

This is a clean illustration of the backtracking template — the state is the combination being built, and the choices at each position are the letters mapped to that digit.

```python
class Solution:
    def letterCombinations(self, digits: str) -> List[str]:
        choices = {
            "2": "abc", "3": "def", "4": "ghi", "5": "jkl",
            "6": "mno", "7": "pqrs", "8": "tuv", "9": "wxyz"
        }

        n = len(digits)
        ret = []

        def solve(pos, cur):
            if pos >= n:
                ret.append(''.join(cur))
                return

            for ch in choices[digits[pos]]:
                cur.append(ch)      # choose
                solve(pos + 1, cur) # explore
                cur.pop()           # unchoose

        solve(0, [])
        return ret
```

The decision tree has depth `n` (one level per digit) and branching factor 3 or 4 (letters per key). Total leaves = total combinations = product of letters per digit, so time is $$O(4^n \cdot n)$$ in the worst case (all 9s and 7s, which map to 4 letters).

What makes this a good first backtracking problem: there is **no pruning needed** — every path from root to leaf is valid. It isolates the choose/explore/unchoose rhythm without the distraction of constraint checking.

---

## Problem 8 — Generate Parentheses

Given `n` pairs of parentheses, generate every string of length `2n` that is a valid bracket sequence. For `n = 3` there are 5 such strings: `((()))`, `(()())`, `(())()`, `()(())`, `()()()`.

The string has `2n` positions. At each position you choose `(` or `)`. The trick is knowing when `)` is legal — you need to track how many unmatched opens you have so far (`cur`):

- You can always add `(`, which increments `cur`.
- You can only add `)` when `cur > 0` (there's an open bracket to close).
- At position `2n`, the string is valid iff `cur == 0` (all brackets matched).

```python
class Solution:
    def generateParenthesis(self, n: int) -> List[str]:
        ret = []

        def solve(pos, res, cur):
            if pos >= 2 * n:
                if cur == 0:          # all brackets matched
                    ret.append(''.join(res))
                return

            for ch in '()':
                if ch == '(':
                    res.append(ch)
                    solve(pos + 1, res, cur + 1)  # one more unmatched open
                    res.pop()
                elif ch == ')' and cur > 0:       # prune: can't close what isn't open
                    res.append(ch)
                    solve(pos + 1, res, cur - 1)
                    res.pop()

        solve(0, [], 0)
        return ret
```

The pruning `cur > 0` is what prevents invalid sequences — it cuts every branch that would produce a `)` with nothing to close. This eliminates the need to validate at the leaf.

Compare this to Letter Combinations (Problem 7): there, every path was valid and we only checked at the leaf. Here, the constraint (`cur > 0`) is checked **mid-path**, halving the branches at each `)` decision.

Time complexity: $$O(4^n / \sqrt{n})$$ — the number of valid sequences is the $$n$$-th Catalan number $$C_n = \frac{1}{n+1}\binom{2n}{n}$$, which grows as $$O(4^n / n^{3/2})$$. Each sequence takes $$O(n)$$ to copy, giving the total.

---

## Recognizing when to prune

Backtracking without pruning is just brute force. The speedup comes entirely from cutting branches early. Ask:

- **Can this partial state ever reach a valid solution?** If not, return immediately.
- **Is the current cost/sum already beyond the target?** Break (especially if candidates are sorted).
- **Is a constraint already violated?** Skip before recursing.

---

## Patterns summary

| Problem | Choice at each step | Key pruning |
|---|---|---|
| Subsets | include or skip `a[i]` | iterate `j` from `i` forward |
| Permutations | place which element at `start` | skip duplicates at same depth |
| Combination Sum | pick `a[i]` (reusable) or move on | `a[i] > remaining` → break |
| N-Queens | place queen in which column for this row | bitmask/boolean for col, diag |
| Word Search | extend path in 4 directions | cell mismatch or already visited |
| Sudoku | which digit fills this cell | row/col/box constraint sets |
| Letter Combinations | which letter maps to this digit | none — all paths are valid |
| Generate Parentheses | add `(` or `)` at each position | `)` only when `cur > 0` |

**The mental checklist:**
1. What is the partial state?
2. What are the choices at each step?
3. What makes a choice invalid (prune)?
4. What makes the state complete (record)?
5. Does undo fully restore the state?
