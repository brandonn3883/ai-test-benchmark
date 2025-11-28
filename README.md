# AI Test Benchmark

A framework for comparing AI-generated test quality across LLMs (ChatGPT, Claude, Gemini, Copilot).

## Quick Start

```bash
./scripts/create_project_template.sh          # Create new project
./scripts/run_all_tests.sh [--llm <name>]     # Run tests
./scripts/generate_coverage_reports.sh        # Generate reports
```

## Project Structure

```
ai-test-benchmark/
├── benchmarks/
│   ├── javascript/<project>/
│   │   ├── src/
│   │   └── tests/{chatgpt,claude,gemini,copilot}/
│   ├── python/<project>/
│   │   ├── src/
│   │   └── tests/{chatgpt,claude,gemini,copilot}/
│   └── java/<project>/
│       └── src/{main,test}/java/com/benchmark/{chatgpt,claude,gemini,copilot}/
├── results/coverage_reports/
└── scripts/
```

## Running Tests

**JavaScript:**
```bash
cd benchmarks/javascript/<project>
npm install
npm test                    # all tests
npm run test:claude         # specific LLM
npm run coverage:claude     # with coverage
```

**Python:**
```bash
cd benchmarks/python/<project>
pip install -r requirements.txt
pytest                      # all tests
pytest tests/claude         # specific LLM
pytest tests/claude --cov=src --cov-report=json
```

**Java:**
```bash
cd benchmarks/java/<project>
gradle wrapper              # if you do not already have a gradle wrapper
./gradlew test              # all tests
./gradlew testClaude        # specific LLM
./gradlew testChatgpt       # specific LLM
./gradlew jacocoTestReport  # generate coverage report
# Coverage XML: build/reports/jacoco/test/jacocoTestReport.xml
```

## Workflow

1. Create project: `./scripts/create_project_template.sh`
2. Add source code to `src/`
3. Generate tests with each LLM using prompts below
4. Save tests to `tests/<llm>/` (or `src/test/java/com/benchmark/<llm>/` for Java)
5. Run coverage: `./scripts/generate_coverage_reports.sh`
6. View results in `results/coverage_reports/latest/`

## Script Options

**run_all_tests.sh:**
```bash
./scripts/run_all_tests.sh                  # Run all tests
./scripts/run_all_tests.sh --llm chatgpt    # Run only ChatGPT tests
./scripts/run_all_tests.sh --llm claude     # Run only Claude tests
./scripts/run_all_tests.sh --all-llms       # Run each LLM separately
```

**generate_coverage_reports.sh:**
```bash
./scripts/generate_coverage_reports.sh                  # All LLMs
./scripts/generate_coverage_reports.sh --llm chatgpt    # Specific LLM
```

Output files:
- `results/coverage_reports/<timestamp>/coverage_comparison.csv`
- `results/coverage_reports/<timestamp>/comparison_report.md`
- `results/coverage_reports/latest/` → symlink to most recent

---

## Test Generation Prompts

### JavaScript (Jest)

```
You are an expert JavaScript test engineer. Generate comprehensive Jest tests.

SOURCE CODE:
[paste your source code here]

REQUIREMENTS:
1. Use Jest testing framework
2. Test all exported functions/classes
3. Include edge cases: null, undefined, empty strings, empty arrays, boundary values
4. Test error handling with expect().toThrow()
5. Aim for 100% code coverage (all lines, branches, functions)
6. Use descriptive test names that explain what is being tested
7. Group related tests with describe() blocks
8. IMPORTANT: Only use Jest built-in features. Do NOT import external libraries like jsdom, @testing-library, or any other packages unless they are already listed in package.json. Use standard Jest matchers and Node.js built-ins only.
9. Make sure it works with the latest version of JavaScript

IMPORT PATH:
Import from: '../../src/[filename]'
Example: const { func1, func2 } = require('../../src/calculator');

OUTPUT:
Generate ONLY the test file code. Do not include explanations or any text before or after the code.
Start directly with the require/import statements.
```

**Save to:** `tests/<llm>/<filename>.test.js`

---

### Python (pytest)

```
You are an expert Python test engineer. Generate comprehensive pytest tests.

SOURCE CODE:
[paste your source code here]

REQUIREMENTS:
1. Use pytest framework
2. Test all public functions/methods
3. Include edge cases: None, empty lists, empty strings, boundary values
4. Test exceptions with pytest.raises()
5. Aim for 100% code coverage
6. Include docstrings for test functions
7. Use descriptive test names (test_function_does_something)
8. Make sure it works with the latest version of Python

IMPORT PATH:
Import from: from src.[module] import [function]
Example: from src.calculator import add, subtract

OUTPUT:
Generate ONLY the test file code. Do not include explanations or any text before or after the code.
Start directly with the import statements.
```

**Save to:** `tests/<llm>/test_<filename>.py`

---

### Java (JUnit 5)

```
You are an expert Java test engineer. Generate comprehensive JUnit 5 tests.

SOURCE CODE:
[paste your source code here]

REQUIREMENTS:
1. Use JUnit 5 framework
2. Test all public methods
3. Include edge cases: null, empty collections, boundary values
4. Test exceptions with assertThrows()
5. Aim for 100% code coverage
6. Include JavaDoc comments
7. Use @Test annotation for each test method
8. Use descriptive method names (testMethodDoesAction)
9. Make sure it works with the latest version of Java

PACKAGE:
package com.benchmark.[chatgpt/claude/gemini/copilot];

OUTPUT:
Generate ONLY the test file code. Do not include explanations or any text before or after the code.
Start directly with the package declaration.
```

**Save to:** `src/test/java/com/benchmark/<llm>/<ClassName>Test.java`

---

## Tips

- Remove markdown code blocks if the LLM includes them in output
- File naming: match source file but add `.test.js` / `test_` prefix / `Test` suffix
- If tests don't run, check import paths first
- Run coverage per-LLM to compare results

## Requirements

- **JavaScript:** Node.js 18+, npm
- **Python:** Python 3.9+, pip
- **Java:** JDK 17+ (21 recommended), Gradle 8+ 

## Docker (Optional)

```bash
docker-compose up -d
docker-compose exec benchmark bash
```