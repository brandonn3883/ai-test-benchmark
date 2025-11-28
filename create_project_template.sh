#!/bin/bash

##############################################################
# Project Template Generator
##############################################################
# Creates projects with separate directories for each LLM's tests
# For data collection ONLY (does not compare LLM's!)
##############################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo "========================================="
echo "Project Template Generator"
echo "LLM Comparison Structure"
echo "========================================="
echo ""

# Check if we're in the right place
if [ ! -d "../ai-test-benchmark" ] && [ ! -d "ai-test-benchmark" ]; then
    echo "ERROR: ai-test-benchmark directory not found"
    echo "Please run this from the directory containing ai-test-benchmark/"
    exit 1
fi

cd ../ai-test-benchmark 2>/dev/null || cd ai-test-benchmark

# Get project details
echo "Which language?"
echo "1) JavaScript"
echo "2) Python"
echo "3) Java"
read -p "Enter choice (1-3): " lang_choice

echo ""
read -p "Enter project name (e.g., my-project): " project_name

# Validate project name
if [[ ! "$project_name" =~ ^[a-z0-9-]+$ ]]; then
    echo "ERROR: Project name must contain only lowercase letters, numbers, and hyphens"
    exit 1
fi

case $lang_choice in
    1)
        LANGUAGE="javascript"
        ;;
    2)
        LANGUAGE="python"
        ;;
    3)
        LANGUAGE="java"
        ;;
    *)
        echo "ERROR: Invalid choice"
        exit 1
        ;;
esac

PROJECT_DIR="benchmarks/$LANGUAGE/$project_name"

# Check if project already exists
if [ -d "$PROJECT_DIR" ]; then
    echo "ERROR: Project already exists: $PROJECT_DIR"
    exit 1
fi

echo ""
echo "Creating $LANGUAGE project: $project_name"
echo "Location: $PROJECT_DIR"
echo ""
echo -e "${CYAN}Test directories for each LLM:${NC}"
echo "  - chatgpt/   (ChatGPT/GPT-4 generated tests)"
echo "  - claude/    (Claude generated tests)"
echo "  - gemini/    (Gemini generated tests)"
echo "  - copilot/   (GitHub Copilot tests)"
echo ""

# Create JavaScript project
create_javascript_project() {
    mkdir -p "$PROJECT_DIR"/src
    mkdir -p "$PROJECT_DIR"/tests/{chatgpt,claude,gemini,copilot}
    
    # package.json
    cat > "$PROJECT_DIR/package.json" << EOF
{
  "name": "$project_name",
  "version": "1.0.0",
  "description": "Benchmark project for AI test generation comparison",
  "scripts": {
    "test": "jest",
    "test:chatgpt": "jest tests/chatgpt",
    "test:claude": "jest tests/claude",
    "test:gemini": "jest tests/gemini",
    "test:copilot": "jest tests/copilot",
    "coverage": "jest --coverage",
    "coverage:chatgpt": "jest tests/chatgpt --coverage --coverageDirectory=coverage/chatgpt",
    "coverage:claude": "jest tests/claude --coverage --coverageDirectory=coverage/claude",
    "coverage:gemini": "jest tests/gemini --coverage --coverageDirectory=coverage/gemini",
    "coverage:copilot": "jest tests/copilot --coverage --coverageDirectory=coverage/copilot"
  },
  "keywords": ["benchmark", "testing", "ai-comparison"],
  "author": "",
  "license": "MIT",
  "devDependencies": {
    "jest": "^29.6.0"
  }
}
EOF

    # jest.config.js
    cat > "$PROJECT_DIR/jest.config.js" << 'EOF'
module.exports = {
  testEnvironment: 'node',
  coverageDirectory: 'coverage',
  collectCoverageFrom: [
    'src/**/*.js',
    '!**/node_modules/**'
  ],
  coverageReporters: ['text', 'html', 'json-summary', 'json'],
  testMatch: ['**/tests/**/*.test.js'],
  coveragePathIgnorePatterns: ['/node_modules/']
};
EOF

    # .gitignore
    cat > "$PROJECT_DIR/.gitignore" << 'EOF'
node_modules/
coverage/
.DS_Store
*.log
EOF

    # README.md
    cat > "$PROJECT_DIR/README.md" << EOF
# $project_name

Benchmark project for comparing AI test generation tools.

## Structure

\`\`\`
$project_name/
├── src/              # Source code
├── tests/
│   ├── chatgpt/     # ChatGPT generated tests
│   ├── claude/      # Claude generated tests
│   ├── gemini/      # Gemini generated tests
│   └── copilot/     # GitHub Copilot tests
└── coverage/        # Coverage reports per LLM
\`\`\`

## Setup

\`\`\`bash
npm install
\`\`\`

## Running Tests

\`\`\`bash
# Run specific LLM tests
npm run test:chatgpt
npm run test:claude
npm run test:gemini
npm run test:copilot

# Run all tests
npm test
\`\`\`

## Coverage Reports

\`\`\`bash
# Generate coverage for specific LLM
npm run coverage:chatgpt
npm run coverage:claude
npm run coverage:gemini
npm run coverage:copilot

# View coverage
open coverage/chatgpt/index.html
open coverage/claude/index.html
\`\`\`

## Workflow

### 1. Add Source Code

Add your code to \`src/\`

### 2. Generate Tests with Each LLM

**For ChatGPT:**
1. Go to chat.openai.com
2. Use prompt from PROMPTS.md
3. Paste generated tests into \`tests/chatgpt/\`
4. Run: \`npm run coverage:chatgpt\`

**For Claude:**
1. Go to claude.ai
2. Use prompt from PROMPTS.md
3. Paste generated tests into \`tests/claude/\`
4. Run: \`npm run coverage:claude\`

**For Gemini:**
1. Go to gemini.google.com
2. Use prompt from PROMPTS.md
3. Paste generated tests into \`tests/gemini/\`
4. Run: \`npm run coverage:gemini\`

**For GitHub Copilot:**
1. Use Copilot in VS Code
2. Save tests to \`tests/copilot/\`
3. Run: \`npm run coverage:copilot\`

### 3. Record Results in Excel

Create spreadsheet with columns:
- Project
- LLM
- Statements %
- Branches %
- Functions %
- Lines %
- Tests Generated
- Notes

## Import Paths

All tests should import from: \`'../../../src/filename'\`

Example:
\`\`\`javascript
const { add, subtract } = require('../../../src/calculator');
\`\`\`
EOF

    # PROMPTS.md
    cat > "$PROJECT_DIR/PROMPTS.md" << 'EOF'
# Test Generation Prompts

## JavaScript / Jest Prompt

Copy this entire prompt and paste into ChatGPT, Claude, or Gemini:

\`\`\`
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

IMPORT PATH:
Import from: '../../../src/[filename]'
Example: const { func1, func2 } = require('../../../src/calculator');

OUTPUT:
Generate ONLY the test file code. Do not include:
- Explanations or markdown
- Code block markers (```)
- Any text before or after the code

Start directly with the require/import statements.
\`\`\`

---

## How to Use

1. **Copy the prompt above**
2. **Replace** `[paste your source code here]` with your actual source file
3. **Paste entire prompt** into LLM (ChatGPT, Claude, Gemini)
4. **Copy the generated code** (remove any markdown if present)
5. **Save to appropriate folder**:
   - ChatGPT → tests/chatgpt/
   - Claude → tests/claude/
   - Gemini → tests/gemini/
6. **Run coverage**: \`npm run coverage:chatgpt\` (or appropriate LLM)

## Tips

- Make sure to use the correct import path: \`'../../../src/filename'\`
- Remove markdown code blocks (```) if the LLM includes them
- File naming: Same as source file but with \`.test.js\`
- If tests don't run, check import paths first
EOF

    # Example source file
    cat > "$PROJECT_DIR/src/example.js" << 'EOF'
/**
 * Example function - replace with your own code
 */
function example() {
  return "Hello, World!";
}

module.exports = { example };
EOF

    # Create empty .gitkeep files
    touch "$PROJECT_DIR/tests/chatgpt/.gitkeep"
    touch "$PROJECT_DIR/tests/claude/.gitkeep"
    touch "$PROJECT_DIR/tests/gemini/.gitkeep"
    touch "$PROJECT_DIR/tests/copilot/.gitkeep"

    echo -e "${GREEN}+ JavaScript project created${NC}"
    echo ""
    echo "Next steps:"
    echo "  cd $PROJECT_DIR"
    echo "  npm install"
}

# Create Python project
create_python_project() {
    mkdir -p "$PROJECT_DIR"/src
    mkdir -p "$PROJECT_DIR"/tests/{chatgpt,claude,gemini,copilot}
    
    # Create __init__.py files
    touch "$PROJECT_DIR/src/__init__.py"
    touch "$PROJECT_DIR/tests/__init__.py"
    touch "$PROJECT_DIR/tests/chatgpt/__init__.py"
    touch "$PROJECT_DIR/tests/claude/__init__.py"
    touch "$PROJECT_DIR/tests/gemini/__init__.py"
    touch "$PROJECT_DIR/tests/copilot/__init__.py"
    
    # pytest.ini
    cat > "$PROJECT_DIR/pytest.ini" << 'EOF'
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
addopts = -v
EOF

    # .gitignore
    cat > "$PROJECT_DIR/.gitignore" << 'EOF'
__pycache__/
*.py[cod]
*$py.class
.coverage
htmlcov/
.pytest_cache/
*.egg-info/
.DS_Store
htmlcov_*/
EOF

    # README.md
    cat > "$PROJECT_DIR/README.md" << EOF
# $project_name

Benchmark project for comparing AI test generation tools.

## Structure

\`\`\`
$project_name/
├── src/              # Source code
└── tests/
    ├── chatgpt/     # ChatGPT generated tests
    ├── claude/      # Claude generated tests
    ├── gemini/      # Gemini generated tests
    └── copilot/     # GitHub Copilot tests
\`\`\`

## Setup

\`\`\`bash
source ../../../venv/bin/activate
pip install pytest pytest-cov
\`\`\`

## Running Tests

\`\`\`bash
# Run specific LLM tests
pytest tests/chatgpt
pytest tests/claude
pytest tests/gemini
pytest tests/copilot
\`\`\`

## Coverage Reports

\`\`\`bash
# Generate coverage for specific LLM
pytest tests/chatgpt --cov=src --cov-report=html:htmlcov_chatgpt --cov-report=json:coverage_chatgpt.json
pytest tests/claude --cov=src --cov-report=html:htmlcov_claude --cov-report=json:coverage_claude.json

# View coverage
open htmlcov_chatgpt/index.html
open htmlcov_claude/index.html
\`\`\`

## Import Paths

All tests should import from: \`src.module\`

Example:
\`\`\`python
from src.calculator import add, subtract
\`\`\`
EOF

    # PROMPTS.md
    cat > "$PROJECT_DIR/PROMPTS.md" << 'EOF'
# Test Generation Prompts

## Python / pytest Prompt

\`\`\`
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

IMPORT PATH:
Import from: from src.[module] import [function]
Example: from src.calculator import add, subtract

OUTPUT:
Generate ONLY the test file code. Do not include:
- Explanations or markdown
- Code block markers (```)
- Any text before or after the code

Start directly with the import statements.
\`\`\`
EOF

    # Example source file
    cat > "$PROJECT_DIR/src/example.py" << 'EOF'
"""Example module - replace with your own code"""

def example():
    """Returns a greeting message."""
    return "Hello, World!"
EOF

    echo -e "${GREEN}+ Python project created${NC}"
    echo ""
    echo "Next steps:"
    echo "  cd $PROJECT_DIR"
    echo "  source ../../../venv/bin/activate"
    echo "  pytest"
}

# Create Java project
create_java_project() {
    java_name=$(echo "$project_name" | sed -r 's/(^|-)([a-z])/\U\2/g')
    
    mkdir -p "$PROJECT_DIR/src"/{main,test}/java/com/benchmark
    mkdir -p "$PROJECT_DIR/src/test/java/com/benchmark"/{chatgpt,claude,gemini,copilot}
    
    # pom.xml
    cat > "$PROJECT_DIR/pom.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.benchmark</groupId>
    <artifactId>$project_name</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <name>$java_name</name>
    <description>Benchmark project for AI test generation comparison</description>

    <properties>
        <maven.compiler.source>11</maven.compiler.source>
        <maven.compiler.target>11</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <junit.version>5.10.0</junit.version>
        <jacoco.version>0.8.11</jacoco.version>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter-api</artifactId>
            <version>\${junit.version}</version>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter-engine</artifactId>
            <version>\${junit.version}</version>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>3.2.2</version>
            </plugin>
            <plugin>
                <groupId>org.jacoco</groupId>
                <artifactId>jacoco-maven-plugin</artifactId>
                <version>\${jacoco.version}</version>
                <executions>
                    <execution>
                        <goals>
                            <goal>prepare-agent</goal>
                        </goals>
                    </execution>
                    <execution>
                        <id>report</id>
                        <phase>test</phase>
                        <goals>
                            <goal>report</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
EOF

    # .gitignore
    cat > "$PROJECT_DIR/.gitignore" << 'EOF'
target/
.idea/
*.iml
.DS_Store
*.class
EOF

    # README.md
    cat > "$PROJECT_DIR/README.md" << EOF
# $project_name

Benchmark project for comparing AI test generation tools.

## Structure

\`\`\`
$project_name/
├── src/
│   ├── main/java/com/benchmark/    # Source code
│   └── test/java/com/benchmark/    # Tests
│       ├── chatgpt/                # ChatGPT tests
│       ├── claude/                 # Claude tests
│       ├── gemini/                 # Gemini tests
│       └── copilot/                # Copilot tests
\`\`\`

## Running Tests

\`\`\`bash
# Run specific LLM tests
mvn test -Dtest="com.benchmark.chatgpt.**"
mvn test -Dtest="com.benchmark.claude.**"
mvn test -Dtest="com.benchmark.gemini.**"
mvn test -Dtest="com.benchmark.copilot.**"

# Run all tests
mvn test
\`\`\`

## Coverage

\`\`\`bash
mvn test jacoco:report
open target/site/jacoco/index.html
\`\`\`
EOF

    # PROMPTS.md
    cat > "$PROJECT_DIR/PROMPTS.md" << 'EOF'
# Test Generation Prompts

## Java / JUnit 5 Prompt

\`\`\`
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

PACKAGE:
package com.benchmark.[chatgpt/claude/gemini/copilot];

OUTPUT:
Generate ONLY the test file code. Do not include:
- Explanations or markdown
- Code block markers (```)
- Any text before or after the code

Start directly with the package declaration.
\`\`\`
EOF

    # Example source file
    cat > "$PROJECT_DIR/src/main/java/com/benchmark/Example.java" << 'EOF'
package com.benchmark;

/**
 * Example class - replace with your own code
 */
public class Example {
    
    /**
     * Returns a greeting message.
     */
    public static String greet() {
        return "Hello, World!";
    }
}
EOF

    # Create .gitkeep files (can remove if we are not committing these, but will keep for now)
    touch "$PROJECT_DIR/src/test/java/com/benchmark/chatgpt/.gitkeep"
    touch "$PROJECT_DIR/src/test/java/com/benchmark/claude/.gitkeep"
    touch "$PROJECT_DIR/src/test/java/com/benchmark/gemini/.gitkeep"
    touch "$PROJECT_DIR/src/test/java/com/benchmark/copilot/.gitkeep"

    echo -e "${GREEN}+ Java project created${NC}"
    echo ""
    echo "Next steps:"
    echo "  cd $PROJECT_DIR"
    echo "  mvn test"
}

# Create the appropriate project
case $lang_choice in
    1)
        create_javascript_project
        ;;
    2)
        create_python_project
        ;;
    3)
        create_java_project
        ;;
esac

echo ""
echo "========================================="
echo "Project Created Successfully!"
echo "========================================="
echo ""
echo "Location: $PROJECT_DIR"
echo ""
echo -e "${CYAN}LLM Test Directories:${NC}"
echo "  tests/chatgpt/    - Paste ChatGPT tests here"
echo "  tests/claude/     - Paste Claude tests here"
echo "  tests/gemini/     - Paste Gemini tests here"
echo "  tests/copilot/    - Paste Copilot tests here"
echo ""
echo -e "${YELLOW}See PROMPTS.md for ready-to-use prompts!${NC}"
echo ""
echo "Workflow:"
echo "  1. Add source code to src/"
echo "  2. Use prompts from PROMPTS.md with each LLM"
echo "  3. Paste generated tests into respective folders"
echo "  4. Run coverage for each: npm run coverage:chatgpt, etc."
echo "  5. Record results in Excel spreadsheet"
echo ""