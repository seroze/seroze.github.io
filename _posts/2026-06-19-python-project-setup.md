---
layout: post
title: "[Python] Setting Up Projects — uv, pip, and pytest"
date: 2026-06-19 00:00:00 +0530
categories: python
tags: [python, uv, pip, pytest, project_setup]
author: "Seroze"
published: true
---

*Python has historically had too many ways to manage dependencies. This post covers the modern approach with `uv`, the pip fallback, and how to run tests with pytest.*

---

## Creating a new project with `uv`

`uv` is a fast Python package manager (written in Rust by Astral, the team behind Ruff). It replaces `pip`, `venv`, `pip-tools`, and partly `poetry` with a single tool.

Install uv:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
# or
pip install uv
```

Create a new project:

```bash
uv init my-project
cd my-project
```

By default that scaffolds an *application* — a flat layout with a runnable
script and no package directory:

```
my-project/
├── pyproject.toml       # project metadata and dependencies
├── README.md
├── .python-version      # pins the Python version for this project
├── .gitignore
└── main.py              # def main(): print("Hello from my-project!")
```

Pass `--lib` and you get a *library* instead — the `src/` layout, with the
package named after the project:

```bash
uv init --lib my-project
```

```
my-project/
├── pyproject.toml       # now also carries [build-system]
├── README.md
├── .python-version
├── .gitignore
└── src/
    └── my_project/
        ├── __init__.py
        └── py.typed     # marks the package as typed (PEP 561)
```

The difference that matters is in `pyproject.toml`, not the directory tree. The
application version has no `[build-system]` table at all, which is deliberate:
an app is something you run, not something anything else installs. `--lib` adds
one, so the project can actually be built and imported by name:

```toml
[build-system]
requires = ["uv_build>=0.11.28,<0.12.0"]   # pin tracks your uv version
build-backend = "uv_build"
```

(It also fills in `authors` from your git config.) So the choice isn't really
flat-vs-`src/` — it's whether anything will ever import this project, which is
the same question the [src layout section](#typical-project-structure) below
turns on.

If you've already made the directory and you're sitting inside it, pass `.`
instead of a name and `uv` takes the project name from the directory:

```bash
mkdir my-project && cd my-project
uv init --lib .
```

Notice there's no `.venv/` yet. That's by design — `uv init` only writes files
(`pyproject.toml`, `main.py`, `README.md`, `.python-version`) and runs `git init`.
It never resolves or installs anything, so there's nothing to put in an
environment yet.

`uv` creates `.venv` **lazily**, on the first command that actually needs one:

```bash
uv venv          # explicit — creates .venv right now
uv run main.py   # creates .venv on demand, then runs
uv add pytest    # creates .venv, then installs
uv sync          # creates .venv from the lockfile
```

So it's not that the venv appears automatically when you init — it appears the
first time you ask uv to do something that requires an interpreter and packages.

---

## Typical project structure

For anything beyond a one-file script, use the **src layout**:

```
my-project/
├── pyproject.toml
├── README.md
├── .gitignore
├── .python-version
├── src/
│   └── my_project/          # your package (underscores, not hyphens)
│       ├── __init__.py
│       ├── main.py
│       ├── models/
│       │   ├── __init__.py
│       │   └── user.py
│       └── services/
│           ├── __init__.py
│           └── auth.py
└── tests/
    ├── conftest.py           # shared fixtures
    ├── test_main.py
    ├── models/
    │   └── test_user.py
    └── services/
        └── test_auth.py
```

**Why `src/` layout?** Without it, `import my_project` in tests would find the local directory instead of the installed package — which can hide import errors that only show up in production. The `src/` layout forces the package to be installed before it can be imported.

**Test files mirror the source structure** — same as Java/Gradle. `src/my_project/models/user.py` → `tests/models/test_user.py`. Pytest discovers test files by looking for files named `test_*.py` or `*_test.py`.

---

## Python naming conventions

| Construct | Convention | Example |
|---|---|---|
| Module / file | `snake_case` | `user_service.py`, `auth_utils.py` |
| Package / directory | `snake_case` | `my_project/`, `http_client/` |
| Class | `PascalCase` | `UserService`, `HttpClient` |
| Function / method | `snake_case` | `get_user()`, `parse_response()` |
| Variable | `snake_case` | `user_id`, `max_retries` |
| Constant | `UPPER_SNAKE_CASE` | `MAX_CONNECTIONS`, `DEFAULT_TIMEOUT` |
| Private method / attribute | `_leading_underscore` | `_validate()`, `_cache` |
| Name-mangled (class-private) | `__double_leading` | `__secret`, `__init_state()` |
| Type alias | `PascalCase` | `UserId = int`, `ResponseMap = dict[str, Any]` |
| Dunder / magic method | `__double_both__` | `__init__`, `__repr__`, `__len__` |

These follow [PEP 8](https://peps.python.org/pep-0008/), the official Python style guide.

---

## Google's Python conventions

[Google's Python Style Guide](https://google.github.io/styleguide/pyguide.html) builds on PEP 8 but adds a few opinions of its own. These are the ones worth internalizing:

### Naming, the Google way

Google spells out the casing rules explicitly. They line up with PEP 8 above, but the guide phrases them as a table you can memorize:

| Type | Convention | Example |
|---|---|---|
| Module | `lower_with_under` | `socket_server` |
| Package | `lower_with_under` | `my_package` |
| Class / Exception | `CapWords` (PascalCase) | `HttpClient`, `ValueError` |
| Function / Method | `lower_with_under()` | `send_request()` |
| Global / Class constant | `CAPS_WITH_UNDER` | `MAX_RETRIES` |
| Variable / Parameter | `lower_with_under` | `retry_count` |
| Instance var (public) | `lower_with_under` | `self.user_id` |
| Instance var (protected) | `_lower_with_under` | `self._cache` |

Google explicitly **avoids** `__double_leading_underscore` for "private" attributes — they prefer a single underscore, because name mangling is rarely worth the friction.

### Things Google is opinionated about

- **No single-character names** except for counters/iterators (`i`, `j`), `e` in `except` clauses, and `f` for file handles. Avoid `l`, `O`, `I` — they look like `1` and `0`.
- **No "dunder" naming for your own modules** — names like `__author__` are discouraged.
- **Prefer descriptive names over abbreviations.** `error_count`, not `err_cnt`.
- **`CapWords` for class names even when they're acronyms** — `HttpServer`, not `HTTPServer`.
- **Module names match the file name** — keep them short and `lower_with_under`.
- **Use one statement per line**, and keep lines ≤ 80 chars (PEP 8 allows 79; Google says 80).

### Docstrings

Google has a distinctive docstring style — sectioned with `Args:`, `Returns:`, `Raises:`:

```python
def fetch_user(user_id: int, *, retries: int = 3) -> User:
    """Fetches a user by ID.

    Args:
        user_id: The unique identifier of the user.
        retries: Number of times to retry on failure.

    Returns:
        The User object matching the given ID.

    Raises:
        UserNotFoundError: If no user exists with that ID.
    """
```

This is the "Google style" you'll see picked up by tools like Sphinx's Napoleon extension. The alternative is NumPy or reST style — pick one and stay consistent across the project.

---

## `pyproject.toml` — the modern config file

`pyproject.toml` is the single file for project metadata, dependencies, and tool config. It replaces `setup.py`, `setup.cfg`, and `requirements.txt` for most purposes.

```toml
[project]
name = "my-project"
version = "0.1.0"
description = "A short description"
requires-python = ">=3.11"
dependencies = [
    "requests>=2.31.0",
    "pydantic>=2.0",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "pytest-cov",
    "ruff",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.pytest.ini_options]
testpaths = ["tests"]
```

---

## Virtual environments — why they matter

A virtual environment is an isolated Python installation for your project. Without one, every project on your machine shares the same global packages — version conflicts are inevitable.

```bash
# Create a venv manually
python -m venv .venv

# Activate it (Linux/Mac)
source .venv/bin/activate

# Activate it (Windows)
.venv\Scripts\activate

# You're now in the venv — pip install goes here, not system-wide
(my-project) $ pip install requests
```

`uv` manages the venv for you automatically — you rarely need to activate it manually.

### VSCode + Jupyter notebooks: kernels and venvs

When you open a Jupyter notebook in VSCode, it asks you to "select a kernel." This is slightly confusing because two separate things are involved.

**What a kernel actually is**

A Jupyter kernel is a background process that receives code from the notebook, executes it, and sends results back. It is described by a `kernel.json` spec file, something like:

```json
{
  "argv": ["/home/user/projects/ml/.venv/bin/python3.12", "-m", "ipykernel_launcher", "-f", "{connection_file}"],
  "display_name": "Python 3.12 (.venv)",
  "language": "python"
}
```

The `argv` field is the key — it points to a Python executable. That executable determines which packages the kernel can see.

**So are they the same thing?**

No — the kernel and the venv are different, but tightly linked:

- The **venv** is the Python environment — the interpreter plus all installed packages under `.venv/`.
- The **kernel** is a running process that uses one specific Python executable.
- When you point a kernel at `.venv/bin/python3.12`, the kernel process runs *inside* that venv — it can import any package installed there.

The venv doesn't know it's being used by a kernel. The kernel just happens to use the venv's Python.

**How to connect a notebook to your venv in VSCode**

Click "Select Kernel" → "Python Environments" → and either pick the venv VSCode detected automatically, or choose "Enter interpreter path" and paste the full path:

```
~/projects/ml/kaggle/stellar-class/.venv/bin/python3.12
```

Use the full path because `~` expansion can be unreliable in some VSCode picker inputs — use the absolute path if the tilde form doesn't work:

```
/home/youruser/projects/ml/kaggle/stellar-class/.venv/bin/python3.12
```

VSCode then launches a kernel process using that Python, giving the notebook access to everything installed in that venv.

<div style="background: #e8f1fb; border-left: 4px solid #4a90d9; padding: 1rem 1.2rem; margin: 1rem 0; border-radius: 0 4px 4px 0;" markdown="1">

**Good to know: register the venv as a named kernel**

Instead of pasting paths every time, register your venv as a proper kernel once:

```bash
# activate the venv first, or use its Python directly
.venv/bin/python -m ipykernel install --user --name stellar-class --display-name "Python (stellar-class)"
```

After this, "Python (stellar-class)" appears in the kernel picker automatically — no path needed. The kernel spec is stored at `~/.local/share/jupyter/kernels/stellar-class/kernel.json`.

</div>

**Why VSCode sometimes doesn't auto-detect your venv**

VSCode scans a few standard locations for venvs (the workspace root, `~/.virtualenvs`, etc.). If your venv lives somewhere else, it won't appear in the list. Pasting the full path or registering via `ipykernel install` are both reliable workarounds.

---

## Managing dependencies with `uv`

### Add a dependency

```bash
uv add requests          # adds to [project.dependencies] in pyproject.toml
uv add pytest --dev      # adds to dev dependencies
uv add "pydantic>=2.0"   # with version constraint
```

`uv add` also updates `uv.lock` — the lockfile that pins every dependency's exact version.

### Install all dependencies (e.g. after cloning a repo)

```bash
uv sync                  # installs everything in pyproject.toml
uv sync --dev            # includes dev dependencies too
```

### Remove a dependency

```bash
uv remove requests
```

### Run a command inside the project environment

```bash
uv run python src/my_project/main.py
uv run pytest
```

`uv run` automatically uses the project's venv without needing to activate it first.

### Show installed packages

```bash
uv pip list
```

---

## Managing dependencies with `pip` (the fallback)

If you're not using `uv`, the traditional approach uses `pip` and a `requirements.txt` file.

```bash
# Create and activate a venv
python -m venv .venv
source .venv/bin/activate

# Install packages
pip install requests pydantic

# Save current environment to a file
pip freeze > requirements.txt

# Install from requirements file (e.g. after cloning)
pip install -r requirements.txt

# Install dev dependencies separately
pip install -r requirements-dev.txt
```

A typical `requirements-dev.txt`:

```
-r requirements.txt      # include production deps
pytest>=8.0
pytest-cov
ruff
```

**`pip freeze` vs `pyproject.toml`:** `pip freeze` pins every transitive dependency including ones you didn't explicitly ask for, which makes upgrades painful. `pyproject.toml` with `uv.lock` is cleaner — you declare direct dependencies, the lockfile handles the rest.

---

## Running tests with pytest

Install pytest:

```bash
uv add pytest --dev
# or
pip install pytest
```

One naming trap first: it's `uv run pytest`, not `uv run test`. `uv run` executes
a command inside the project venv, so `test` means nothing unless you've defined
a script by that name.

### How pytest finds your tests

You never register anything. Pytest walks the directory tree and collects
by name:

- files matching `test_*.py`
- classes matching `Test*` — and they **must not** define `__init__`
- methods and functions matching `test_*`

That last rule about `__init__` catches people coming from `unittest`. A pytest
test class isn't an object you construct; it's just a namespace for grouping
related tests. If you give it a constructor, pytest silently skips the whole
class with a warning.

```python
# tests/test_multidict.py

import pytest                       # not collected — not a test
from my_project import MultiDict    # not collected

@pytest.fixture                     # not collected — it's a fixture
def md():
    return MultiDict([("a", 1), ("b", 2), ("a", 3)])

class TestConstruction:             # collected: name starts with Test, no __init__
    def test_from_pairs(self, md):  # collected: name starts with test_
        assert len(md) == 3

class TestLookup:                   # collected
    def test_getitem_returns_first_value(self, md):
        assert md["a"] == 1
```

`TestConstruction` and `TestLookup` aren't special types you inherit from — they
are plain classes that happen to be named `Test*`. Everything else in the file
(the imports, the `md` fixture) is just module-level code that pytest loads but
doesn't run as a test.

Running `pytest tests/` runs *all* of them. Each test runs independently: they
share no state, and one failing doesn't stop the rest.

### Basic usage

```bash
# Run all tests
pytest

# With verbose output (shows each test name)
pytest -v

# Run a specific file
pytest tests/test_main.py

# Run a specific test function
pytest tests/test_main.py::test_add

# Run a specific test class
pytest tests/test_main.py::TestCalculator

# Run a specific method inside a class
pytest tests/test_main.py::TestCalculator::test_add
```

### Filter by name with `-k`

```bash
# Run tests whose name contains "auth"
pytest -k "auth"

# Run tests matching an expression
pytest -k "auth or login"
pytest -k "not slow"
```

### Failure output

```bash
# Short traceback (default)
pytest

# Full traceback
pytest --tb=long

# Just the error line, no traceback
pytest --tb=line

# Stop after first failure
pytest -x

# Stop after 3 failures
pytest --maxfail=3
```

### Coverage

```bash
uv add pytest-cov --dev

pytest --cov=src/my_project              # coverage for your package
pytest --cov=src/my_project --cov-report=html   # generates htmlcov/index.html
```

---

## Writing tests

Pytest doesn't require test classes — plain functions work fine.

```python
# tests/test_math.py
def test_add():
    assert 1 + 1 == 2

def test_divide_by_zero():
    with pytest.raises(ZeroDivisionError):
        1 / 0
```

### Fixtures — shared setup and teardown

Fixtures are functions that provide data or resources to tests. Pytest injects them by parameter name.

```python
# tests/conftest.py  — fixtures here are available to all test files
import pytest
from my_project.models.user import User

@pytest.fixture
def sample_user():
    return User(name="Alice", age=30)

@pytest.fixture
def db_connection():
    conn = create_test_db()
    yield conn          # test runs here
    conn.close()        # teardown runs after the test
```

```python
# tests/test_user.py
def test_user_name(sample_user):      # pytest injects sample_user automatically
    assert sample_user.name == "Alice"

def test_user_age(sample_user):
    assert sample_user.age == 30
```

The part that matters most: **the fixture re-runs for every test that asks for
it.** Each test gets a fresh object, not a shared one. Stick a `print` in a
fixture and you can watch it happen:

```
>>> fixture ran, building a fresh MultiDict
test_one sees: [('a', 1), ('a', 999)]     <- test_one mutated it
>>> fixture ran, building a fresh MultiDict
test_two sees: [('a', 1)]                 <- test_two is unaffected
```

That's why a test class can freely `del md["a"]` or call `md.clear()` without
wrecking the test that runs next. (If you *want* one shared instance, that's
what `@pytest.fixture(scope="module")` and `scope="session"` are for.)

Where you define a fixture decides who can see it:

- inside a test class — only that class's tests
- at module level in a test file — every test in that file
- in `tests/conftest.py` — every test file in the directory and below

### Plain `assert` — no `assertEqual` needed

Pytest rewrites the bytecode of your `assert` statements so a failure reports
what the values actually were, which is why you never need `unittest`'s
`assertEqual` family:

```
>       assert md.keys() == ["a", "b", "b"]
E       AssertionError: assert ['a', 'b', 'a'] == ['a', 'b', 'b']
E         At index 2 diff: 'a' != 'b'
```

### Parametrize — run one test with multiple inputs

```python
import pytest

@pytest.mark.parametrize("a, b, expected", [
    (1, 2, 3),
    (0, 0, 0),
    (-1, 1, 0),
])
def test_add(a, b, expected):
    assert a + b == expected
```

This runs `test_add` three times with different inputs and reports each separately.

A parametrized test can take fixtures too — pytest matches arguments by name, so
it works out which is which:

```python
@pytest.mark.parametrize("key", ["Content-Type", "content-type", "CONTENT-TYPE"])
def test_lookup_ignores_case(self, ci, key):   # ci = fixture, key = parameter
    assert ci[key] == "json"
```

Finally, if you get tired of typing a path every time, the
`[tool.pytest.ini_options]` block back in `pyproject.toml` is where
`testpaths = ["tests"]` lives — with that set, a bare `uv run pytest` knows
where to look.

---

## How Python import resolution actually works (and why `src/` requires installing)

When you write `from cat_images.client import CatClient`, Python takes the first segment `cat_images` and looks for a directory with that exact name inside each entry in `sys.path`. It does **not** search recursively.

So if your project root is in `sys.path`, Python looks for `<project-root>/cat_images/` — which doesn't exist. The actual package lives at `<project-root>/src/cat_images/`. That `src/` layer in between is what breaks the import.

**Why `from src.cat_images.client import ...` works without installing**

Because `src` is a real directory sitting directly in the project root. Python finds `src/` → `cat_images/` → `client.py` by traversing the import path segments. It's treating `src` as a plain namespace, not a package boundary. It works, but it's an ugly import path and the wrong approach.

**Why `uv pip install -e .` fixes it**

An editable install reads `pyproject.toml`, sees the package source is in `src/`, and registers `src/` itself as a path in the venv's `site-packages`. Now Python can find `cat_images` directly. This is the intended workflow for the `src/` layout — it forces you to install before importing as a proper package, which prevents accidentally importing from your working tree instead of the installed package.

**Why VSCode still warns after installing**

Pylance (VSCode's type checker) does static analysis — it doesn't execute the venv to discover editable install paths the way the Python runtime does. You need to tell it explicitly where to look. Add this to `.vscode/settings.json`:

```json
{
  "python.analysis.extraPaths": ["src"]
}
```

This tells Pylance to also look in `src/` when resolving imports, matching what the editable install does at runtime.

---

## `uv` vs `pip` — when to use which

| | `uv` | `pip` |
|---|---|---|
| Speed | Very fast (written in Rust) | Slower |
| Lockfile | `uv.lock` — exact reproducible installs | None (use `pip freeze`) |
| Config file | `pyproject.toml` | `requirements.txt` |
| Virtual env | Managed automatically | Manual (`python -m venv`) |
| Best for | New projects, teams | Legacy projects, simple scripts |

For new projects, start with `uv`. For existing projects using `requirements.txt`, `pip` works fine — no need to migrate unless you want to.

---

## Quick reference

| Task | `uv` | `pip` |
|---|---|---|
| Create project | `uv init my-project` | `mkdir my-project && python -m venv .venv` |
| Add dependency | `uv add requests` | `pip install requests` |
| Add dev dependency | `uv add pytest --dev` | `pip install pytest` |
| Install from lockfile | `uv sync` | `pip install -r requirements.txt` |
| Run a command | `uv run python main.py` | `source .venv/bin/activate && python main.py` |
| Run tests | `uv run pytest` | `pytest` (inside activated venv) |
| Run specific test | `uv run pytest tests/test_foo.py::test_bar` | `pytest tests/test_foo.py::test_bar` |
| Verbose test output | `pytest -v` | same |
| Stop on first failure | `pytest -x` | same |
