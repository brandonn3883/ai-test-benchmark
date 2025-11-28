#!/bin/bash
# Project Template Generator (LLM Comparison Version)
# Creates project templates for JavaScript, Python, and Java

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Find base directory
if [ -d "../ai-test-benchmark" ]; then
    BASE_DIR="$(cd ../ai-test-benchmark && pwd)"
elif [ -d "ai-test-benchmark" ]; then
    BASE_DIR="$(cd ai-test-benchmark && pwd)"
elif [ -d "benchmarks" ]; then
    BASE_DIR="$(pwd)"
else
    echo -e "${RED}ERROR: ai-test-benchmark directory not found${NC}"
    echo "Run this script from the ai-test-benchmark directory or its parent."
    exit 1
fi

cd "$BASE_DIR"

echo "=== Project Template Generator ==="
echo ""
echo "Language:"
echo "  1) JavaScript (Jest)"
echo "  2) Python (pytest)"
echo "  3) Java (Gradle + JUnit 5)"
echo ""
read -p "Choice (1-3): " lang_choice
read -p "Project name (lowercase, hyphens ok): " project_name

[[ ! "$project_name" =~ ^[a-z0-9-]+$ ]] && echo -e "${RED}ERROR: Invalid project name. Use lowercase letters, numbers, and hyphens only.${NC}" && exit 1

case $lang_choice in
    1) LANGUAGE="javascript" ;;
    2) LANGUAGE="python" ;;
    3) LANGUAGE="java" ;;
    *) echo -e "${RED}ERROR: Invalid choice${NC}" && exit 1 ;;
esac

PROJECT_DIR="$BASE_DIR/benchmarks/$LANGUAGE/$project_name"
[ -d "$PROJECT_DIR" ] && echo -e "${RED}ERROR: Project '$project_name' already exists${NC}" && exit 1

echo ""
echo -e "${BLUE}Creating $LANGUAGE project: $project_name${NC}"

create_javascript_project() {
    mkdir -p "$PROJECT_DIR"/src
    mkdir -p "$PROJECT_DIR"/tests/{chatgpt,claude,gemini,copilot}
    
    cat > "$PROJECT_DIR/package.json" << EOF
{
  "name": "$project_name",
  "version": "1.0.0",
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
  "devDependencies": {
    "jest": "^29.7.0"
  }
}
EOF

    cat > "$PROJECT_DIR/jest.config.js" << 'EOF'
module.exports = {
  testEnvironment: 'node',
  coverageDirectory: 'coverage',
  collectCoverageFrom: ['src/**/*.js', '!**/node_modules/**'],
  coverageReporters: ['text', 'json-summary', 'json'],
  testMatch: ['**/tests/**/*.test.js']
};
EOF

    cat > "$PROJECT_DIR/.gitignore" << 'EOF'
node_modules/
coverage/
*.log
EOF

    cat > "$PROJECT_DIR/src/index.js" << 'EOF'
// Add your source code here

function example() {
    return "Hello, World!";
}

module.exports = { example };
EOF

    # Create placeholder files
    for llm in chatgpt claude gemini copilot; do
        touch "$PROJECT_DIR/tests/$llm/.gitkeep"
    done
    
    echo -e "${GREEN}Created JavaScript project${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Add your source code to src/"
    echo "  2. Generate tests with each LLM"
    echo "  3. Save tests to tests/<llm>/*.test.js"
    echo "  4. Run: cd $PROJECT_DIR && npm install && npm test"
}

create_python_project() {
    mkdir -p "$PROJECT_DIR"/src
    mkdir -p "$PROJECT_DIR"/tests/{chatgpt,claude,gemini,copilot}
    
    cat > "$PROJECT_DIR/pytest.ini" << 'EOF'
[pytest]
testpaths = tests
python_files = test_*.py
addopts = -v
EOF

    cat > "$PROJECT_DIR/requirements.txt" << 'EOF'
pytest>=7.4.0
pytest-cov>=4.1.0
EOF

    cat > "$PROJECT_DIR/.gitignore" << 'EOF'
__pycache__/
*.pyc
.pytest_cache/
htmlcov/
coverage.json
.coverage
venv/
EOF

    touch "$PROJECT_DIR/src/__init__.py"
    touch "$PROJECT_DIR/tests/__init__.py"
    
    for llm in chatgpt claude gemini copilot; do
        touch "$PROJECT_DIR/tests/$llm/__init__.py"
        touch "$PROJECT_DIR/tests/$llm/.gitkeep"
    done

    cat > "$PROJECT_DIR/src/example.py" << 'EOF'
# Add your source code here

def example():
    return "Hello, World!"
EOF

    echo -e "${GREEN}Created Python project${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Add your source code to src/"
    echo "  2. Generate tests with each LLM"
    echo "  3. Save tests to tests/<llm>/test_*.py"
    echo "  4. Run: cd $PROJECT_DIR && pip install -r requirements.txt && pytest"
}

create_java_project() {
    # Create directory structure
    mkdir -p "$PROJECT_DIR/src/main/java/com/benchmark"
    mkdir -p "$PROJECT_DIR/src/test/java/com/benchmark"/{chatgpt,claude,gemini,copilot}
    
    # Create build.gradle
    cat > "$PROJECT_DIR/build.gradle" << 'EOF'
plugins {
    id 'java'
    id 'jacoco'
}

group = 'com.benchmark'
version = '1.0.0'

java {
    sourceCompatibility = JavaVersion.VERSION_21
    targetCompatibility = JavaVersion.VERSION_21
}

repositories {
    mavenCentral()
}

dependencies {    
    // JUnit 5
    testImplementation 'org.junit.jupiter:junit-jupiter:5.10.2'
    testRuntimeOnly 'org.junit.platform:junit-platform-launcher'
}

test {
    useJUnitPlatform()
    finalizedBy jacocoTestReport
}

jacocoTestReport {
    dependsOn test
    reports {
        xml.required = true
        csv.required = true
        html.required = false
    }
}

// Tasks for running specific LLM tests
['chatgpt', 'claude', 'gemini', 'copilot'].each { llm ->
    tasks.register("test${llm.capitalize()}", Test) {
        useJUnitPlatform()
        filter {
            includeTestsMatching "com.benchmark.${llm}.*"
        }
        finalizedBy jacocoTestReport
    }
}
EOF

    # Create settings.gradle
    cat > "$PROJECT_DIR/settings.gradle" << EOF
rootProject.name = '$project_name'
EOF

    # Create gradle.properties
    cat > "$PROJECT_DIR/gradle.properties" << 'EOF'
org.gradle.jvmargs=-Xmx1024m
org.gradle.parallel=true
EOF

    # Create .gitignore
    cat > "$PROJECT_DIR/.gitignore" << 'EOF'
# Gradle
.gradle/
build/
!gradle/wrapper/gradle-wrapper.jar

# IDE
.idea/
*.iml
.vscode/

# Compiled
*.class
EOF

    # Create example source file
    cat > "$PROJECT_DIR/src/main/java/com/benchmark/Example.java" << 'EOF'
package com.benchmark;

/**
 * Example class - replace with your actual source code.
 */
public class Example {
    
    public static String greet() {
        return "Hello, World!";
    }
    
    public static String greet(String name) {
        if (name == null || name.isBlank()) {
            return "Hello, World!";
        }
        return "Hello, " + name + "!";
    }
}
EOF

    # Create placeholder test directories
    for llm in chatgpt claude gemini copilot; do
        touch "$PROJECT_DIR/src/test/java/com/benchmark/$llm/.gitkeep"
    done
    
    echo -e "${BLUE}Setting up Gradle wrapper...${NC}"
    (
        cd "$PROJECT_DIR"
        if command -v gradle &>/dev/null; then
            gradle wrapper --gradle-version 8.5 -q 2>/dev/null || {
                echo -e "${YELLOW}Note: Could not create Gradle wrapper. Run 'gradle wrapper' manually.${NC}"
            }
        else
            echo -e "${YELLOW}Note: Gradle not found. Install Gradle or use './gradlew' after adding wrapper.${NC}"
        fi
    )

    echo -e "${GREEN}Created Java (Gradle) project${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Add your source code to src/main/java/com/benchmark/"
    echo "  2. Generate tests with each LLM"
    echo "  3. Save tests to src/test/java/com/benchmark/<llm>/*Test.java"
    echo "  4. Run: cd $PROJECT_DIR && ./gradlew test"
    echo ""
    echo "Run specific LLM tests:"
    echo "  ./gradlew testChatgpt"
    echo "  ./gradlew testClaude"
    echo "  ./gradlew testGemini"
    echo "  ./gradlew testCopilot"
}

# Create the project
case $lang_choice in
    1) create_javascript_project ;;
    2) create_python_project ;;
    3) create_java_project ;;
esac

echo ""
echo -e "${GREEN}Project created: $PROJECT_DIR${NC}"