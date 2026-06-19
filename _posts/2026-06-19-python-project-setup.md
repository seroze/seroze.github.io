---
layout: post
title: "Setting Up Python Projects — uv, pip, and pytest"
date: 2026-06-19 00:00:00 +0530
categories: python
tags: [python, uv, pip, pytest, project-setup]
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

This scaffolds:

```
my-project/
├── pyproject.toml       # project metadata and dependencies
├── README.md
├── .python-version      # pins the Python version for this project
├── .gitignore
└── src/
    └── my_project/
        └── __init__.py
```

`uv init` also creates a virtual environment at `.venv/` automatically on first use.

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
