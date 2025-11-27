#!/bin/bash

##############################################################
# Project Template Generator
##############################################################
# Creates standardized project structures for benchmarking
# Ensures all projects follow the same conventions
##############################################################

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "========================================="
echo "Project Template Generator"
echo "========================================="
echo ""

# Check if we're in the right place
if [ ! -d "../ai-test-benchmark" ] && [ ! -d "ai-test-benchmark" ]; then
    echo "ERROR: ai-test-benchmark directory not found"
    echo "Please run this from the directory containing ai-test-benchmark/"
    exit 1
fi

# Navigate to the correct directory
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

# Create JavaScript project
create_javascript_project() {
    mkdir -p "$PROJECT_DIR"/{src,tests}
    
    # package.json
    cat > "$PROJECT_DIR/package.json" << EOF
{
  "name": "$project_name",
  "version": "1.0.0",
  "description": "Benchmark project for AI test generation",
  "scripts": {
    "test": "jest",
    "coverage": "jest --coverage",
    "test:watch": "jest --watch"
  },
  "keywords": ["benchmark", "testing"],
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
  coverageReporters: ['text', 'html', 'json-summary'],
  testMatch: ['**/tests/**/*.test.js']
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

Benchmark project for evaluating AI test generation tools.

## Setup

\`\`\`bash
npm install
\`\`\`

## Run Tests

\`\`\`bash
# Run tests
npm test

# Run with coverage
npm run coverage

# Watch mode
npm test:watch
\`\`\`

## View Coverage

\`\`\`bash
open coverage/index.html
\`\`\`

## Project Structure

\`\`\`
$project_name/
├── src/           # Source code (add your functions here)
├── tests/         # Tests (add your tests here)
├── package.json   # Dependencies and scripts
└── README.md      # This file
\`\`\`

## Adding Your Code

1. Add source files to \`src/\`
2. Add test files to \`tests/\` (name them \`*.test.js\`)
3. Run \`npm test\` to verify
4. Run \`npm run coverage\` to see coverage

## Example

\`\`\`javascript
// src/example.js
function add(a, b) {
  return a + b;
}

module.exports = { add };
\`\`\`

\`\`\`javascript
// tests/example.test.js
const { add } = require('../src/example');

describe('add', () => {
  test('adds two numbers', () => {
    expect(add(1, 2)).toBe(3);
  });
});
\`\`\`
EOF

    # Example files
    cat > "$PROJECT_DIR/src/example.js" << 'EOF'
/**
 * Example function - replace with your own code
 */
function example() {
  return "Hello, World!";
}

module.exports = { example };
EOF

    cat > "$PROJECT_DIR/tests/example.test.js" << 'EOF'
const { example } = require('../src/example');

describe('example', () => {
  test('returns greeting', () => {
    expect(example()).toBe("Hello, World!");
  });
});
EOF

    echo -e "${GREEN}+ JavaScript project created${NC}"
    echo ""
    echo "Next steps:"
    echo "  cd $PROJECT_DIR"
    echo "  npm install"
    echo "  npm test"
}

# Create Python project
create_python_project() {
    mkdir -p "$PROJECT_DIR"/{src,tests}
    
    # Create __init__.py files
    touch "$PROJECT_DIR/src/__init__.py"
    touch "$PROJECT_DIR/tests/__init__.py"
    
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
EOF

    # README.md
    cat > "$PROJECT_DIR/README.md" << EOF
# $project_name

Benchmark project for evaluating AI test generation tools.

## Setup

\`\`\`bash
# Activate virtual environment
source ../../../venv/bin/activate

# Or create project-specific venv
python3 -m venv venv
source venv/bin/activate
pip install pytest pytest-cov
\`\`\`

## Run Tests

\`\`\`bash
# Run tests
pytest

# Run with coverage
pytest --cov=src

# Generate HTML coverage report
pytest --cov=src --cov-report=html

# Run with detailed output
pytest -v --cov=src --cov-report=term-missing
\`\`\`

## View Coverage

\`\`\`bash
open htmlcov/index.html
\`\`\`

## Project Structure

\`\`\`
$project_name/
├── src/           # Source code (add your modules here)
├── tests/         # Tests (add your test files here)
├── pytest.ini     # Pytest configuration
└── README.md      # This file
\`\`\`

## Adding Your Code

1. Add Python modules to \`src/\`
2. Add test files to \`tests/\` (name them \`test_*.py\`)
3. Run \`pytest\` to verify
4. Run \`pytest --cov=src --cov-report=html\` for coverage

## Example

\`\`\`python
# src/example.py
def add(a, b):
    \"\"\"Add two numbers.\"\"\"
    if not isinstance(a, (int, float)) or not isinstance(b, (int, float)):
        raise TypeError("Arguments must be numbers")
    return a + b
\`\`\`

\`\`\`python
# tests/test_example.py
import pytest
from src.example import add

def test_add():
    assert add(1, 2) == 3

def test_add_floats():
    assert add(1.5, 2.5) == 4.0

def test_add_type_error():
    with pytest.raises(TypeError):
        add("1", 2)
\`\`\`
EOF

    # Example files
    cat > "$PROJECT_DIR/src/example.py" << 'EOF'
"""
Example module - replace with your own code
"""

def example():
    """Returns a greeting message."""
    return "Hello, World!"
EOF

    cat > "$PROJECT_DIR/tests/test_example.py" << 'EOF'
from src.example import example

def test_example():
    """Test that example returns correct greeting."""
    assert example() == "Hello, World!"
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
    # Convert project-name to ProjectName for Java
    java_name=$(echo "$project_name" | sed -r 's/(^|-)([a-z])/\U\2/g')
    
    mkdir -p "$PROJECT_DIR/src"/{main,test}/java/com/benchmark
    
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
    <description>Benchmark project for AI test generation</description>

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

Benchmark project for evaluating AI test generation tools.

## Prerequisites

- Java 11 or higher
- Maven 3.6+

## Build

\`\`\`bash
mvn compile
\`\`\`

## Run Tests

\`\`\`bash
# Run tests
mvn test

# Run tests with coverage
mvn test jacoco:report

# Clean and test
mvn clean test
\`\`\`

## View Coverage

\`\`\`bash
open target/site/jacoco/index.html
\`\`\`

## Project Structure

\`\`\`
$project_name/
├── src/
│   ├── main/java/com/benchmark/    # Source code
│   └── test/java/com/benchmark/    # Tests
├── pom.xml                          # Maven configuration
└── README.md                        # This file
\`\`\`

## Adding Your Code

1. Add Java classes to \`src/main/java/com/benchmark/\`
2. Add test classes to \`src/test/java/com/benchmark/\` (name them \`*Test.java\`)
3. Run \`mvn test\` to verify
4. Run \`mvn jacoco:report\` to see coverage

## Example

\`\`\`java
// src/main/java/com/benchmark/Example.java
package com.benchmark;

public class Example {
    public static String greet() {
        return "Hello, World!";
    }
}
\`\`\`

\`\`\`java
// src/test/java/com/benchmark/ExampleTest.java
package com.benchmark;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

public class ExampleTest {
    @Test
    public void testGreet() {
        assertEquals("Hello, World!", Example.greet());
    }
}
\`\`\`
EOF

    # Example files
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

    cat > "$PROJECT_DIR/src/test/java/com/benchmark/ExampleTest.java" << 'EOF'
package com.benchmark;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

/**
 * Example test - replace with your own tests
 */
public class ExampleTest {
    
    @Test
    public void testGreet() {
        assertEquals("Hello, World!", Example.greet());
    }
}
EOF

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
echo "To test with universal scripts:"
echo "  bash run_all_tests.sh"
echo "  bash generate_coverage_reports.sh"
echo ""