---
layout: post
title: "Gradle Basics — Init, Build, Test, and the Wrapper"
date: 2026-06-19 00:00:00 +0530
categories: java
tags: [java, gradle, build-tools]
author: "Seroze"
published: true
---

*Gradle is a build tool — it compiles your code, resolves dependencies, runs tests, and packages your application. This post covers the day-to-day commands and the concepts behind them.*

---

## Creating a project with `gradle init`

`gradle init` is an interactive wizard that scaffolds a new project. Run it in an empty directory:

```bash
mkdir my-app && cd my-app
gradle init
```

It will ask:

```
Select type of project to generate:
  1: basic
  2: application       ← pick this for a runnable app
  3: library
  4: Gradle plugin

Select implementation language:
  1: Java

Select build script DSL:
  1: Kotlin             ← build.gradle.kts
  2: Groovy             ← build.gradle

Project name: my-app
Source package: com.example
```

After finishing, you get:

```
my-app/
├── gradlew                        # Gradle wrapper script (Linux/Mac)
├── gradlew.bat                    # Gradle wrapper script (Windows)
├── gradle/
│   └── wrapper/
│       ├── gradle-wrapper.jar     # wrapper bootstrap binary
│       └── gradle-wrapper.properties  # which Gradle version to use
├── settings.gradle.kts            # project name, subproject list
├── build.gradle.kts               # dependencies, plugins, build config
└── src/
    ├── main/java/com/example/
    │   └── App.java
    └── test/java/com/example/
        └── AppTest.java
```

**The source directory convention**

Gradle follows the Maven standard layout. The package name becomes a nested directory path under `src/main/java/` and `src/test/java/`. For a package `com.ridesharing`:

```
src/
├── main/
│   └── java/
│       └── com/
│           └── ridesharing/
│               ├── Main.java
│               ├── Driver.java
│               └── Trip.java
└── test/
    └── java/
        └── com/
            └── ridesharing/
                ├── MainTest.java
                ├── DriverTest.java
                └── TripTest.java
```

The test package mirrors the main package exactly. This is convention, not enforced — but it means test classes get package-private access to the classes they test without needing everything to be `public`.

When Gradle compiles, `src/main/java` goes to `build/classes/java/main/` and `src/test/java` goes to `build/classes/java/test/`. The test classpath includes both so tests can import production classes.

---

## The build file

`build.gradle.kts` (Kotlin DSL) for a Java application looks like this:

```kotlin
plugins {
    java                         // compiles Java source
    application                  // adds 'run' task and creates a distribution
}

repositories {
    mavenCentral()               // where to download dependencies from
}

dependencies {
    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
}

application {
    mainClass = "com.example.App"  // entry point for ./gradlew run
}

tasks.test {
    useJUnitPlatform()           // tell Gradle to use JUnit 5 runner
}
```

`settings.gradle.kts` just names the project and lists subprojects (for single-project builds, it's minimal):

```kotlin
rootProject.name = "my-app"
```

---

## Key commands

All commands use `./gradlew` (the wrapper) rather than `gradle` directly — more on why below.

### `./gradlew tasks`

Lists every available task and a short description. Good starting point when you're unfamiliar with a project.

```bash
./gradlew tasks
```

### `./gradlew build`

The main command. It:
1. Compiles `src/main/java` → `build/classes/java/main/`
2. Compiles `src/test/java` → `build/classes/java/test/`
3. Runs all tests
4. Packages everything into a JAR at `build/libs/my-app.jar`

If any test fails, the build fails.

```bash
./gradlew build
```

### `./gradlew run`

Compiles (if needed) and runs the class specified in `application.mainClass`.

```bash
./gradlew run
```

Pass arguments via `--args`:

```bash
./gradlew run --args="hello world"
```

### `./gradlew test`

Compiles and runs tests only. After it finishes, a human-readable HTML report is generated at:

```
build/reports/tests/test/index.html
```

```bash
./gradlew test

# Run a specific test class
./gradlew test --tests "com.example.AppTest"

# Run a specific test method
./gradlew test --tests "com.example.AppTest.shouldReturnTrue"
```

### `./gradlew clean`

Deletes the `build/` directory. Use this when you want a completely fresh build — useful when you suspect stale compiled classes are causing weird behavior.

```bash
./gradlew clean build   # clean then build in one shot
```

### `./gradlew jar`

Builds just the JAR without running tests.

```bash
./gradlew jar
# output: build/libs/my-app.jar
```

---

## What happens during a build — the three phases

Gradle processes every build in exactly three phases, in order:

**1. Initialization** — Gradle reads `settings.gradle.kts` to find which projects exist and sets up the project hierarchy.

**2. Configuration** — Gradle evaluates every `build.gradle.kts` file. This does NOT run tasks yet — it just builds a graph of all tasks and their dependencies. This is why you can print `tasks` without actually compiling anything.

**3. Execution** — Gradle looks at which tasks you asked for, resolves the dependency graph (e.g., `test` depends on `compileTestJava` which depends on `compileJava`), and executes them in the correct order.

This separation is important: code at the top level of `build.gradle.kts` runs at configuration time (phase 2), not at execution time. Mistakes here cause slow configuration or broken task graphs.

---

## Incremental builds and the build cache

Gradle tracks the inputs and outputs of every task. If nothing changed since the last run, it skips the task and prints `UP-TO-DATE`.

```
> Task :compileJava UP-TO-DATE
> Task :processResources UP-TO-DATE
> Task :classes UP-TO-DATE
> Task :test UP-TO-DATE
```

This makes repeated builds very fast. `./gradlew clean` throws this away — only do it when something is genuinely wrong, not as a habit.

---

## Dependencies — `implementation` vs `api` vs `testImplementation`

```kotlin
dependencies {
    implementation("com.google.guava:guava:32.0.0")
        // available in your main code, NOT exposed to callers of your library

    api("com.fasterxml.jackson.core:jackson-databind:2.15.0")
        // available in main code AND exposed to callers (for libraries only)

    testImplementation("org.junit.jupiter:junit-jupiter:5.10.0")
        // available only in test source set

    runtimeOnly("org.slf4j:slf4j-simple:2.0.0")
        // only on classpath at runtime, not at compile time
}
```

For application projects (not libraries), use `implementation` for everything — `api` only matters when other projects depend on your project as a library.

---

## The Gradle Wrapper — `gradlew` vs `gradle`

The wrapper is the recommended way to run Gradle. Instead of using a globally installed `gradle` command, you use `./gradlew` — a small script that downloads and caches the exact Gradle version specified in `gradle/wrapper/gradle-wrapper.properties`.

```properties
# gradle/wrapper/gradle-wrapper.properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.7-bin.zip
```

**Why use the wrapper instead of global Gradle?**

**Reproducibility** — everyone on the team uses the exact same Gradle version. "Works on my machine" build failures caused by version mismatches disappear.

**No installation required** — a new team member clones the repo and runs `./gradlew build`. They don't need to install anything. The wrapper downloads the right Gradle version automatically on first run.

**CI/CD friendly** — your CI pipeline just runs `./gradlew build`. No setup step to install a specific Gradle version. No drift between what CI uses and what developers use.

**Upgrading is explicit and tracked** — to upgrade Gradle, run:
```bash
./gradlew wrapper --gradle-version 8.8
```
This updates `gradle-wrapper.properties`, which you commit to version control. Every developer and CI job gets the upgrade automatically on next pull. There's a clear history of when and why the version changed.

**Commit the wrapper, not the distribution** — commit `gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar`, and `gradle/wrapper/gradle-wrapper.properties`. Do not commit the downloaded Gradle distribution itself (it lives in `~/.gradle/wrapper/dists/`).

---

## Multi-project builds

Large projects split into subprojects (modules). Here's the full workflow for setting one up from scratch.

### Step 1: `gradle init` — pick Basic (option 4)

When creating a multi-module project, run `gradle init` and choose **option 4 (Basic)**:

```
Select type of project to generate:
  1: Application
  2: Library
  3: Gradle plugin
  4: Basic (build structure only)    ← pick this

Select build script DSL:
  1: Kotlin
  2: Groovy

Project name: fix-engine
```

Basic gives you the wrapper and an empty `settings.gradle.kts` with nothing else — no `src/`, no `build.gradle.kts`. This is intentional: in a multi-module project, each submodule owns its own `build.gradle.kts`, so you don't want Gradle to scaffold one big one at the root.

### Step 2: Create subdirectories manually

Gradle won't create your submodule directories — you do that yourself:

```bash
mkdir fix-core fix-transport fix-session fix-app
```

Inside each, create a `build.gradle.kts` and the standard source layout:

```
fix-engine/
├── gradlew
├── settings.gradle.kts          # root — lists all submodules
├── build.gradle.kts             # optional root build file (shared config)
├── fix-core/
│   ├── build.gradle.kts
│   └── src/main/java/com/seroze/fix/core/
├── fix-transport/
│   ├── build.gradle.kts
│   └── src/main/java/com/seroze/fix/transport/
├── fix-session/
│   ├── build.gradle.kts
│   └── src/main/java/com/seroze/fix/session/
└── fix-app/
    ├── build.gradle.kts
    └── src/main/java/com/seroze/fix/app/
```

### Step 3: Link submodules in `settings.gradle.kts`

The root `settings.gradle.kts` must explicitly declare every submodule — Gradle won't discover them automatically:

```kotlin
rootProject.name = "fix-engine"

include(
    "fix-core",
    "fix-transport",
    "fix-session",
    "fix-app"
)
```

### Step 4: Package naming — use dots, not hyphens

Java package names cannot contain hyphens (`-`). Even though your directory is named `fix-core`, the package name must use dots only:

```
fix-core/  →  package com.seroze.fix.core
fix-transport/  →  package com.seroze.fix.transport
fix-session/  →  package com.seroze.fix.session
fix-app/  →  package com.seroze.fix.app
```

So the directory name and the package name are different things — the directory name can have hyphens (and that's idiomatic for Gradle module names), but the Java package inside it must use dots:

```java
// fix-core/src/main/java/com/seroze/fix/core/FixMessage.java
package com.seroze.fix.core;

public class FixMessage { ... }
```

### Step 5: Wire up inter-module dependencies

Each submodule's `build.gradle.kts` references other modules via `project(":module-name")`:

```kotlin
// fix-session/build.gradle.kts
plugins {
    java
}

dependencies {
    implementation(project(":fix-core"))
    implementation(project(":fix-transport"))
}
```

```kotlin
// fix-app/build.gradle.kts
plugins {
    java
    application
}

dependencies {
    implementation(project(":fix-core"))
    implementation(project(":fix-session"))
}

application {
    mainClass = "com.seroze.fix.app.Main"
}
```

### Building specific modules

```bash
./gradlew :fix-core:build
./gradlew :fix-session:test
./gradlew :fix-app:run

# Build everything
./gradlew build
```

Gradle resolves the dependency order automatically — if `fix-app` depends on `fix-session`, Gradle compiles `fix-session` first.

---

## Quick reference

| Command | What it does |
|---|---|
| `./gradlew tasks` | List all available tasks |
| `./gradlew build` | Compile + test + package JAR |
| `./gradlew run` | Compile and run the main class |
| `./gradlew test` | Compile and run tests only |
| `./gradlew clean` | Delete build/ directory |
| `./gradlew jar` | Package JAR without running tests |
| `./gradlew dependencies` | Show dependency tree |
| `./gradlew wrapper --gradle-version X` | Upgrade the wrapper to version X |
| `./gradlew build --scan` | Upload build scan to scans.gradle.com for debugging |

**The rule on `gradlew` vs `gradle`:** always use `./gradlew`. Never rely on a globally installed `gradle` for project builds — it defeats the purpose of the wrapper.
