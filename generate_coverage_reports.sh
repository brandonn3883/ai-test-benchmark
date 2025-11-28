#!/bin/bash
# Coverage Report Generator (LLM Comparison Version)

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

LLM_FILTER=""
COMPARE_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --llm) LLM_FILTER="$2"; shift 2 ;;
        --compare-all) COMPARE_ALL=true; shift ;;
        *) echo "Usage: $0 [--llm <chatgpt|claude|gemini|copilot>] [--compare-all]"; exit 1 ;;
    esac
done

echo "=== Coverage Report Generator ==="

# Find and set BASE_DIR as absolute path
if [ -d "../ai-test-benchmark" ]; then
    BASE_DIR="$(cd ../ai-test-benchmark && pwd)"
elif [ -d "ai-test-benchmark" ]; then
    BASE_DIR="$(cd ai-test-benchmark && pwd)"
elif [ -d "benchmarks" ]; then
    # Already in ai-test-benchmark directory
    BASE_DIR="$(pwd)"
else
    echo -e "${RED}ERROR: ai-test-benchmark not found${NC}"
    echo "Run this script from the ai-test-benchmark directory or its parent."
    exit 1
fi

echo "Base directory: $BASE_DIR"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="$BASE_DIR/results/coverage_reports/$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

# Use a temp file to accumulate results (avoids subshell array issues)
TEMP_RESULTS=$(mktemp)
# Clean up temp file on exit
trap "rm -f $TEMP_RESULTS" EXIT

total=0

# Function to store coverage data - writes to temp file
store_cov() {
    printf "%s\t%s\n" "$1" "$2" >> "$TEMP_RESULTS"
}

# Backup function - preserves directory structure
swap_tests_safe() {
    local proj="$1"
    local llm="$2"
    
    if [ ! -d "$proj/tests/$llm" ]; then
        return 1
    fi
    
    mkdir -p "$proj/tests_backup"
    if ! mv "$proj/tests" "$proj/tests_backup/original" 2>/dev/null; then
        return 1
    fi
    
    # Recreate the same directory structure: tests/<llm>/
    # This keeps relative imports working (e.g., ../../src/slugify)
    mkdir -p "$proj/tests/$llm"
    if ! cp -r "$proj/tests_backup/original/$llm"/* "$proj/tests/$llm/" 2>/dev/null; then
        restore_tests_safe "$proj"
        return 1
    fi
    
    # For Python, ensure __init__.py exists at both levels
    touch "$proj/tests/__init__.py" 2>/dev/null || true
    touch "$proj/tests/$llm/__init__.py" 2>/dev/null || true
    
    return 0
}

restore_tests_safe() {
    local proj="$1"
    
    if [ -d "$proj/tests_backup/original" ]; then
        rm -rf "$proj/tests"
        mv "$proj/tests_backup/original" "$proj/tests"
        rm -rf "$proj/tests_backup"
    fi
}

extract_js_cov() {
    local proj="$1"
    local llm="$2"
    local name=$(basename "$proj")
    
    echo -e "${BLUE}[JS]${NC} $name - ${CYAN}$llm${NC}"
    
    if [ ! -f "$proj/package.json" ]; then
        echo -e "  ${YELLOW}No package.json, skipping${NC}"
        return 0
    fi
    
    if [ ! -d "$proj/tests/$llm" ]; then
        echo -e "  ${YELLOW}No tests for $llm, skipping${NC}"
        return 0
    fi
    
    if ! ls "$proj/tests/$llm"/*.test.js &>/dev/null; then
        echo -e "  ${YELLOW}No .test.js files for $llm, skipping${NC}"
        return 0
    fi
    
    # Backup and swap
    if ! swap_tests_safe "$proj" "$llm"; then
        echo -e "  ${RED}Failed to swap tests${NC}"
        return 1
    fi
    
    # Run in subshell
    local success=false
    (
        cd "$proj"
        
        if [ ! -d "node_modules" ]; then
            npm install --silent 2>&1 >/dev/null || true
        fi
        
        npm run coverage 2>&1 >/dev/null || true
        
        if [ -f "coverage/coverage-summary.json" ]; then
            python3 -c "
import json
d = json.load(open('coverage/coverage-summary.json'))['total']
print(f\"{d['statements']['pct']}|{d['branches']['pct']}|{d['functions']['pct']}|{d['lines']['pct']}\")
" 2>/dev/null > /tmp/cov_result_$$ || echo "0|0|0|0" > /tmp/cov_result_$$
        else
            echo "0|0|0|0" > /tmp/cov_result_$$
        fi
    )
    
    if [ -f /tmp/cov_result_$$ ]; then
        local cov_data=$(cat /tmp/cov_result_$$)
        rm -f /tmp/cov_result_$$
        
        IFS='|' read -r s b f l <<< "$cov_data"
        echo -e "  ${GREEN}Coverage: Stmts:${s}% Branch:${b}% Func:${f}% Lines:${l}%${NC}"
        
        store_cov "${name}|${llm}" "JavaScript|$name|$llm|$s|$b|$f|$l"
        
        # Copy coverage report
        if [ -d "$proj/coverage" ]; then
            mkdir -p "$RESULTS_DIR/${llm}_${name}"
            cp -r "$proj/coverage"/* "$RESULTS_DIR/${llm}_${name}/" 2>/dev/null || true
        fi
        
        ((total++)) || true
    fi
    
    restore_tests_safe "$proj"
    return 0
}

extract_py_cov() {
    local proj="$1"
    local llm="$2"
    local name=$(basename "$proj")
    
    echo -e "${BLUE}[PY]${NC} $name - ${CYAN}$llm${NC}"
    
    if [ ! -d "$proj/tests/$llm" ]; then
        echo -e "  ${YELLOW}No tests for $llm, skipping${NC}"
        return 0
    fi
    
    if ! ls "$proj/tests/$llm"/test_*.py &>/dev/null; then
        echo -e "  ${YELLOW}No test_*.py files for $llm, skipping${NC}"
        return 0
    fi
    
    if ! swap_tests_safe "$proj" "$llm"; then
        echo -e "  ${RED}Failed to swap tests${NC}"
        return 1
    fi
    
    (
        cd "$proj"
        
        # Activate venv if exists
        if [ -f "$BASE_DIR/venv/bin/activate" ]; then
            source "$BASE_DIR/venv/bin/activate"
        fi
        
        if ! command -v pytest &>/dev/null; then
            echo "0" > /tmp/cov_result_$$
            exit 0
        fi
        
        pytest --cov=src --cov-report=html --cov-report=json -q 2>&1 >/dev/null || true
        
        if [ -f "coverage.json" ]; then
            python3 -c "
import json
cov = json.load(open('coverage.json'))['totals']['percent_covered']
print(f'{cov:.2f}')
" 2>/dev/null > /tmp/cov_result_$$ || echo "0" > /tmp/cov_result_$$
        else
            echo "0" > /tmp/cov_result_$$
        fi
    )
    
    if [ -f /tmp/cov_result_$$ ]; then
        local cov=$(cat /tmp/cov_result_$$)
        rm -f /tmp/cov_result_$$
        
        echo -e "  ${GREEN}Coverage: ${cov}%${NC}"
        
        # Python pytest-cov gives single coverage number, use it for all metrics
        store_cov "${name}|${llm}" "Python|$name|$llm|$cov|$cov|$cov|$cov"
        
        if [ -d "$proj/htmlcov" ]; then
            mkdir -p "$RESULTS_DIR/${llm}_${name}"
            cp -r "$proj/htmlcov"/* "$RESULTS_DIR/${llm}_${name}/" 2>/dev/null || true
        fi
        
        ((total++)) || true
    fi
    
    restore_tests_safe "$proj"
    return 0
}

extract_java_cov() {
    local proj="$1"
    local llm="$2"
    local name=$(basename "$proj")
    
    echo -e "${BLUE}[Java]${NC} $name - ${CYAN}$llm${NC}"
    
    # Detect build tool
    local build_tool=""
    if [ -f "$proj/build.gradle" ] || [ -f "$proj/build.gradle.kts" ]; then
        build_tool="gradle"
    elif [ -f "$proj/pom.xml" ]; then
        build_tool="maven"
    else
        echo -e "  ${YELLOW}No build.gradle or pom.xml, skipping${NC}"
        return 0
    fi
    
    if [ ! -d "$proj/src/test/java/com/benchmark/$llm" ]; then
        echo -e "  ${YELLOW}No tests for $llm, skipping${NC}"
        return 0
    fi
    
    (
        cd "$proj"
        
        if [ "$build_tool" = "gradle" ]; then
            local gradle_cmd="gradle"
            [ -f "./gradlew" ] && gradle_cmd="./gradlew"
            
            if ! command -v $gradle_cmd &>/dev/null && [ ! -f "./gradlew" ]; then
                echo -e "  ${YELLOW}Gradle not found, skipping${NC}"
                exit 0
            fi
            
            # Run LLM-specific tests
            $gradle_cmd clean test${llm^} jacocoTestReport --continue -q 2>&1 >/dev/null || \
            $gradle_cmd clean test --tests "com.benchmark.${llm}.*" jacocoTestReport --continue -q 2>&1 >/dev/null || true
            
            # Extract coverage from Gradle's JaCoCo location
            if [ -f "build/reports/jacoco/test/jacocoTestReport.xml" ]; then
                python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('build/reports/jacoco/test/jacocoTestReport.xml')
for counter in tree.findall('.//counter[@type=\"LINE\"]'):
    missed = int(counter.get('missed', 0))
    covered = int(counter.get('covered', 0))
    total = missed + covered
    if total > 0:
        print(f'{covered / total * 100:.2f}')
        break
else:
    print('0')
" 2>/dev/null > /tmp/cov_result_$$ || echo "0" > /tmp/cov_result_$$
            else
                echo "0" > /tmp/cov_result_$$
            fi
        else
            # Maven
            if ! command -v mvn &>/dev/null; then
                echo -e "  ${YELLOW}Maven not found, skipping${NC}"
                exit 0
            fi
            
            mvn clean test -Dtest="com.benchmark.$llm.**" jacoco:report -Dmaven.test.failure.ignore=true -q 2>&1 >/dev/null || true
            
            if [ -f "target/site/jacoco/jacoco.xml" ]; then
                python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('target/site/jacoco/jacoco.xml')
for counter in tree.findall('.//counter[@type=\"LINE\"]'):
    missed = int(counter.get('missed', 0))
    covered = int(counter.get('covered', 0))
    total = missed + covered
    if total > 0:
        print(f'{covered / total * 100:.2f}')
        break
else:
    print('0')
" 2>/dev/null > /tmp/cov_result_$$ || echo "0" > /tmp/cov_result_$$
            else
                echo "0" > /tmp/cov_result_$$
            fi
        fi
    )
    
    if [ -f /tmp/cov_result_$$ ]; then
        local cov=$(cat /tmp/cov_result_$$)
        rm -f /tmp/cov_result_$$
        
        echo -e "  ${GREEN}Coverage: ${cov}%${NC}"
        
        store_cov "${name}|${llm}" "Java|$name|$llm|$cov|$cov|$cov|$cov"
        
        # Copy coverage reports (check both Gradle and Maven locations)
        if [ -d "$proj/build/reports/jacoco" ]; then
            mkdir -p "$RESULTS_DIR/${llm}_${name}"
            cp -r "$proj/build/reports/jacoco"/* "$RESULTS_DIR/${llm}_${name}/" 2>/dev/null || true
        elif [ -d "$proj/target/site/jacoco" ]; then
            mkdir -p "$RESULTS_DIR/${llm}_${name}"
            cp -r "$proj/target/site/jacoco"/* "$RESULTS_DIR/${llm}_${name}/" 2>/dev/null || true
        fi
        
        ((total++)) || true
    fi
    
    return 0
}

# Determine LLMs to process
if [ -n "$LLM_FILTER" ]; then
    LLMS=("$LLM_FILTER")
else
    LLMS=(chatgpt claude gemini copilot)
fi

echo "Processing LLMs: ${LLMS[*]}"
echo ""

# Process JavaScript projects
for proj in "$BASE_DIR"/benchmarks/javascript/*/; do
    [ ! -d "$proj" ] && continue
    proj=$(cd "$proj" && pwd)  # Absolute path
    
    for llm in "${LLMS[@]}"; do
        extract_js_cov "$proj" "$llm"
    done
done

# Process Python projects
for proj in "$BASE_DIR"/benchmarks/python/*/; do
    [ ! -d "$proj" ] && continue
    proj=$(cd "$proj" && pwd)
    
    for llm in "${LLMS[@]}"; do
        extract_py_cov "$proj" "$llm"
    done
done

# Process Java projects
for proj in "$BASE_DIR"/benchmarks/java/*/; do
    [ ! -d "$proj" ] && continue
    proj=$(cd "$proj" && pwd)
    
    for llm in "${LLMS[@]}"; do
        extract_java_cov "$proj" "$llm"
    done
done

echo ""
echo "=== Generating Reports ==="

# Generate CSV from temp file
CSV="$RESULTS_DIR/coverage_comparison.csv"
echo "Language,Project,LLM,Statements,Branches,Functions,Lines" > "$CSV"

while IFS=$'\t' read -r key value; do
    [ -z "$key" ] && continue
    echo "$value" | tr '|' ','
done < "$TEMP_RESULTS" >> "$CSV"

echo "Created: $CSV"

# Generate Markdown report
MD="$RESULTS_DIR/comparison_report.md"
cat > "$MD" << EOF
# LLM Test Coverage Comparison

Generated: $(date)

## Summary

| Language | Project | LLM | Statements | Branches | Functions | Lines |
|----------|---------|-----|------------|----------|-----------|-------|
EOF

while IFS=$'\t' read -r key value; do
    [ -z "$key" ] && continue
    IFS='|' read -r lang proj llm s b f l <<< "$value"
    echo "| $lang | $proj | $llm | ${s}% | ${b}% | ${f}% | ${l}% |"
done < "$TEMP_RESULTS" >> "$MD"

echo "Created: $MD"

# Create 'latest' symlink
cd "$BASE_DIR/results/coverage_reports"
rm -f latest
ln -s "$TIMESTAMP" latest

echo ""
echo -e "${GREEN}=== Complete ===${NC}"
echo "Total project/LLM combinations: $total"
echo "Reports directory: $RESULTS_DIR"
echo ""
echo "Generated files:"
echo "  - $CSV"
echo "  - $MD"