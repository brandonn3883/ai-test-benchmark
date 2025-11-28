#!/bin/bash
# Universal Test Runner (LLM Comparison Version)

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

LLM_FILTER=""
ALL_LLMS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --llm) LLM_FILTER="$2"; shift 2 ;;
        --all-llms) ALL_LLMS=true; shift ;;
        *) echo "Usage: $0 [--llm <chatgpt|claude|gemini|copilot>] [--all-llms]"; exit 1 ;;
    esac
done

echo "=== Universal Test Runner ==="
[ -n "$LLM_FILTER" ] && echo -e "${CYAN}Testing: $LLM_FILTER${NC}"
[ "$ALL_LLMS" = true ] && echo -e "${CYAN}Testing all LLMs separately${NC}"

# Find and set BASE_DIR as absolute path
if [ -d "../ai-test-benchmark" ]; then
    BASE_DIR="$(cd ../ai-test-benchmark && pwd)"
elif [ -d "ai-test-benchmark" ]; then
    BASE_DIR="$(cd ai-test-benchmark && pwd)"
elif [ -d "benchmarks" ]; then
    # Already in ai-test-benchmark directory
    BASE_DIR="$(pwd)"
else
    echo -e "${RED}ERROR: ai-test-benchmark directory not found${NC}"
    echo "Run this script from the ai-test-benchmark directory or its parent."
    exit 1
fi

echo "Base directory: $BASE_DIR"

total=0
passed=0
failed=0
declare -a results

# Cleanup to restore tests if script is interrupted
cleanup_backup() {
    local proj=$1
    if [ -d "$proj/tests_backup/original" ]; then
        echo -e "${YELLOW}Restoring tests from backup for $proj${NC}"
        rm -rf "$proj/tests"
        mv "$proj/tests_backup/original" "$proj/tests"
        rm -rf "$proj/tests_backup"
    fi
}

# Trap to handle script interruption (Ctrl+C, kill)
trap 'echo -e "${RED}Script interrupted, cleaning up...${NC}"' INT TERM

should_test_llm() {
    local path=$1
    [ -z "$LLM_FILTER" ] && [ "$ALL_LLMS" = false ] && return 0
    [ -n "$LLM_FILTER" ] && [[ "$path" == *"/$LLM_FILTER"* ]] && return 0
    [ "$ALL_LLMS" = true ] && [[ "$path" =~ .*/tests/(chatgpt|claude|gemini|copilot)$ ]] && return 0
    return 1
}

get_llm_name() {
    case $1 in
        *chatgpt*) echo "ChatGPT" ;;
        *claude*) echo "Claude" ;;
        *gemini*) echo "Gemini" ;;
        *copilot*) echo "Copilot" ;;
        *) echo "Unknown" ;;
    esac
}

# Backup function - preserves directory structure
swap_tests() {
    local proj="$1"
    local llm="$2"
    
    # Validate source exists
    if [ ! -d "$proj/tests/$llm" ]; then
        echo -e "  ${YELLOW}Warning: No tests for $llm in $proj${NC}"
        return 1
    fi
    
    # Create backup
    mkdir -p "$proj/tests_backup"
    if ! mv "$proj/tests" "$proj/tests_backup/original"; then
        echo -e "  ${RED}Error: Failed to backup tests${NC}"
        return 1
    fi
    
    # Recreate the same directory structure: tests/<llm>/
    mkdir -p "$proj/tests/$llm"
    if ! cp -r "$proj/tests_backup/original/$llm"/* "$proj/tests/$llm/" 2>/dev/null; then
        echo -e "  ${RED}Error: Failed to copy $llm tests${NC}"
        restore_tests "$proj"
        return 1
    fi
    
    return 0
}

# Restore test backups function
restore_tests() {
    local proj="$1"
    
    if [ -d "$proj/tests_backup/original" ]; then
        rm -rf "$proj/tests"
        mv "$proj/tests_backup/original" "$proj/tests"
        rm -rf "$proj/tests_backup"
    fi
}

run_js_tests() {
    local proj_path="$1"
    local name=$(basename "$proj_path")
    local llm=$(get_llm_name "$proj_path")
    
    echo -e "${BLUE}[JS]${NC} $name ${CYAN}($llm)${NC}"
    
    if [ ! -f "$proj_path/package.json" ]; then
        echo -e "  ${YELLOW}No package.json${NC}"
        return 1
    fi
    
    # Run in subshell to isolate directory changes
    (
        cd "$proj_path"
        
        if [ ! -d "node_modules" ]; then
            echo -e "  Installing dependencies..."
            npm install --silent 2>&1 || {
                echo -e "  ${RED}npm install failed${NC}"
                exit 1
            }
        fi
        
        # Always run with coverage
        local test_output
        local test_exit_code
        test_output=$(npm run coverage 2>&1) || test_exit_code=$?
        
        # Extract coverage from summary JSON
        local cov="N/A"
        local stmts="N/A"
        local branch="N/A"
        local funcs="N/A"
        local lines="N/A"
        
        if [ -f "coverage/coverage-summary.json" ]; then
            cov=$(python3 -c "
import json
d = json.load(open('coverage/coverage-summary.json'))['total']
print(f\"{d['lines']['pct']}\")
" 2>/dev/null || echo "N/A")
        fi
        
        if [ -z "$test_exit_code" ] || [ "$test_exit_code" -eq 0 ]; then
            echo -e "  ${GREEN}PASS${NC} (Coverage: ${cov}%)"
            echo "PASS|JS|$name|$llm|$cov" > /tmp/test_result_$$
            exit 0
        else
            echo -e "  ${RED}FAIL${NC} (Coverage: ${cov}%)"
            echo "FAIL|JS|$name|$llm|$cov" > /tmp/test_result_$$
            exit 1
        fi
    )
    local exit_code=$?
    
    # Read result from temp file
    if [ -f /tmp/test_result_$$ ]; then
        local result=$(cat /tmp/test_result_$$)
        rm -f /tmp/test_result_$$
        results+=("[$result]")
    fi
    
    return $exit_code
}

run_py_tests() {
    local proj_path="$1"
    local name=$(basename "$proj_path")
    local llm=$(get_llm_name "$proj_path")
    
    echo -e "${BLUE}[PY]${NC} $name ${CYAN}($llm)${NC}"
    
    if [ ! -d "$proj_path/tests" ] && [ ! -d "$proj_path/test" ]; then
        echo -e "  ${YELLOW}No tests directory${NC}"
        return 1
    fi
    
    (
        cd "$proj_path"
        
        # Activate venv if exists
        if [ -f "$BASE_DIR/venv/bin/activate" ]; then
            source "$BASE_DIR/venv/bin/activate"
        fi
        
        if ! command -v pytest &>/dev/null; then
            echo -e "  ${YELLOW}pytest not found${NC}"
            exit 1
        fi
        
        # Run with coverage, capture exit code
        local test_exit_code
        pytest --cov=src --cov-report=json -q 2>&1 || test_exit_code=$?
        
        # Extract coverage
        local cov="N/A"
        if [ -f "coverage.json" ]; then
            cov=$(python3 -c "import json; print(f\"{json.load(open('coverage.json'))['totals']['percent_covered']:.1f}\")" 2>/dev/null || echo "N/A")
        fi
        
        if [ -z "$test_exit_code" ] || [ "$test_exit_code" -eq 0 ]; then
            echo -e "  ${GREEN}PASS${NC} (Coverage: ${cov}%)"
            echo "PASS|PY|$name|$llm|$cov" > /tmp/test_result_$$
            exit 0
        else
            echo -e "  ${RED}FAIL${NC} (Coverage: ${cov}%)"
            echo "FAIL|PY|$name|$llm|$cov" > /tmp/test_result_$$
            exit 1
        fi
    )
    local exit_code=$?
    
    if [ -f /tmp/test_result_$$ ]; then
        local result=$(cat /tmp/test_result_$$)
        rm -f /tmp/test_result_$$
        results+=("[$result]")
    fi
    
    return $exit_code
}

run_java_tests() {
    local proj_path="$1"
    local name=$(basename "$proj_path")
    local llm=$(get_llm_name "$proj_path")
    
    echo -e "${BLUE}[Java]${NC} $name ${CYAN}($llm)${NC}"
    
    # Detect build tool
    local build_tool=""
    if [ -f "$proj_path/build.gradle" ] || [ -f "$proj_path/build.gradle.kts" ]; then
        build_tool="gradle"
    elif [ -f "$proj_path/pom.xml" ]; then
        build_tool="maven"
    else
        echo -e "  ${YELLOW}No build.gradle or pom.xml found${NC}"
        return 1
    fi
    
    (
        cd "$proj_path"
        
        if [ "$build_tool" = "gradle" ]; then
            # Use Gradle
            local gradle_cmd="gradle"
            [ -f "./gradlew" ] && gradle_cmd="./gradlew"
            
            if ! command -v $gradle_cmd &>/dev/null && [ ! -f "./gradlew" ]; then
                echo -e "  ${YELLOW}Gradle not found${NC}"
                exit 1
            fi
            
            # Run tests with coverage
            local test_exit_code
            $gradle_cmd clean test jacocoTestReport --continue -q 2>&1 || test_exit_code=$?
            
            # Check test results
            local tests_passed=true
            if [ -d "build/test-results/test" ]; then
                if grep -l "failures=\"[1-9]" build/test-results/test/*.xml 2>/dev/null || \
                   grep -l "errors=\"[1-9]" build/test-results/test/*.xml 2>/dev/null; then
                    tests_passed=false
                fi
            fi
            
            # Extract coverage from JaCoCo XML (Gradle puts it in build/)
            local cov="N/A"
            if [ -f "build/reports/jacoco/test/jacocoTestReport.xml" ]; then
                cov=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('build/reports/jacoco/test/jacocoTestReport.xml')
for counter in tree.findall('.//counter[@type=\"LINE\"]'):
    missed = int(counter.get('missed', 0))
    covered = int(counter.get('covered', 0))
    total = missed + covered
    if total > 0:
        print(f'{covered / total * 100:.1f}')
        break
else:
    print('N/A')
" 2>/dev/null || echo "N/A")
            fi
            
        else
            # Use Maven
            if ! command -v mvn &>/dev/null; then
                echo -e "  ${YELLOW}Maven not found${NC}"
                exit 1
            fi
            
            # Run tests with coverage, ignore test failures to still get coverage report
            local test_exit_code
            mvn clean test jacoco:report -Dmaven.test.failure.ignore=true -q 2>&1 || test_exit_code=$?
            
            # Check if tests actually passed by looking at surefire reports
            local tests_passed=true
            if [ -d "target/surefire-reports" ]; then
                if grep -l "failures=\"[1-9]" target/surefire-reports/*.xml 2>/dev/null || \
                   grep -l "errors=\"[1-9]" target/surefire-reports/*.xml 2>/dev/null; then
                    tests_passed=false
                fi
            fi
            
            # Extract coverage from JaCoCo XML
            local cov="N/A"
            if [ -f "target/site/jacoco/jacoco.xml" ]; then
                cov=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('target/site/jacoco/jacoco.xml')
for counter in tree.findall('.//counter[@type=\"LINE\"]'):
    missed = int(counter.get('missed', 0))
    covered = int(counter.get('covered', 0))
    total = missed + covered
    if total > 0:
        print(f'{covered / total * 100:.1f}')
        break
else:
    print('N/A')
" 2>/dev/null || echo "N/A")
            fi
        fi
        
        if [ "$tests_passed" = true ]; then
            echo -e "  ${GREEN}PASS${NC} (Coverage: ${cov}%)"
            echo "PASS|Java|$name|$llm|$cov" > /tmp/test_result_$$
            exit 0
        else
            echo -e "  ${RED}FAIL${NC} (Coverage: ${cov}%)"
            echo "FAIL|Java|$name|$llm|$cov" > /tmp/test_result_$$
            exit 1
        fi
    )
    local exit_code=$?
    
    if [ -f /tmp/test_result_$$ ]; then
        local result=$(cat /tmp/test_result_$$)
        rm -f /tmp/test_result_$$
        results+=("[$result]")
    fi
    
    return $exit_code
}

# JavaScript projects
for proj in "$BASE_DIR"/benchmarks/javascript/*/; do
    [ ! -d "$proj" ] && continue
    proj=$(cd "$proj" && pwd)  # Get absolute path
    
    if [ -n "$LLM_FILTER" ] || [ "$ALL_LLMS" = true ]; then
        for llm_dir in "$proj"/tests/*/; do
            [ ! -d "$llm_dir" ] && continue
            llm_name=$(basename "$llm_dir")
            
            # Check if we should test this LLM
            if [ -n "$LLM_FILTER" ] && [ "$llm_name" != "$LLM_FILTER" ]; then
                continue
            fi
            if [ "$ALL_LLMS" = true ] && [[ ! "$llm_name" =~ ^(chatgpt|claude|gemini|copilot)$ ]]; then
                continue
            fi
            
            # Check if there are actual test files
            if ! ls "$llm_dir"/*.test.js &>/dev/null; then
                continue
            fi
            
            ((total++))
            
            if swap_tests "$proj" "$llm_name"; then
                run_js_tests "$proj" && ((passed++)) || ((failed++))
                restore_tests "$proj"
            else
                ((failed++))
            fi
        done
    else
        ((total++))
        run_js_tests "$proj" && ((passed++)) || ((failed++))
    fi
done

# Python projects
for proj in "$BASE_DIR"/benchmarks/python/*/; do
    [ ! -d "$proj" ] && continue
    proj=$(cd "$proj" && pwd)
    
    if [ -n "$LLM_FILTER" ] || [ "$ALL_LLMS" = true ]; then
        for llm_dir in "$proj"/tests/*/; do
            [ ! -d "$llm_dir" ] && continue
            llm_name=$(basename "$llm_dir")
            
            if [ -n "$LLM_FILTER" ] && [ "$llm_name" != "$LLM_FILTER" ]; then
                continue
            fi
            if [ "$ALL_LLMS" = true ] && [[ ! "$llm_name" =~ ^(chatgpt|claude|gemini|copilot)$ ]]; then
                continue
            fi
            
            if ! ls "$llm_dir"/test_*.py &>/dev/null; then
                continue
            fi
            
            ((total++))
            
            if swap_tests "$proj" "$llm_name"; then
                run_py_tests "$proj" && ((passed++)) || ((failed++))
                restore_tests "$proj"
            else
                ((failed++))
            fi
        done
    else
        ((total++))
        run_py_tests "$proj" && ((passed++)) || ((failed++))
    fi
done

# Java projects
for proj in "$BASE_DIR"/benchmarks/java/*/; do
    [ ! -d "$proj" ] && continue
    proj=$(cd "$proj" && pwd)
    
    if [ -n "$LLM_FILTER" ] || [ "$ALL_LLMS" = true ]; then
        for llm_dir in "$proj"/src/test/java/com/benchmark/*/; do
            [ ! -d "$llm_dir" ] && continue
            llm_name=$(basename "$llm_dir")
            
            if [ -n "$LLM_FILTER" ] && [ "$llm_name" != "$LLM_FILTER" ]; then
                continue
            fi
            if [ "$ALL_LLMS" = true ] && [[ ! "$llm_name" =~ ^(chatgpt|claude|gemini|copilot)$ ]]; then
                continue
            fi
            
            if ! ls "$llm_dir"/*Test.java &>/dev/null; then
                continue
            fi
            
            ((total++))
            
            echo -e "${BLUE}[Java]${NC} $(basename "$proj") ${CYAN}($llm_name)${NC}"
            
            # Java doesn't need swap - just filter by package
            (
                cd "$proj"
                local proj_name=$(basename "$proj")
                
                # Detect build tool
                local build_tool=""
                if [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; then
                    build_tool="gradle"
                elif [ -f "pom.xml" ]; then
                    build_tool="maven"
                else
                    echo -e "  ${YELLOW}No build.gradle or pom.xml found${NC}"
                    exit 1
                fi
                
                local tests_passed=true
                local cov="N/A"
                
                if [ "$build_tool" = "gradle" ]; then
                    local gradle_cmd="gradle"
                    [ -f "./gradlew" ] && gradle_cmd="./gradlew"
                    
                    # Run LLM-specific tests with Gradle
                    # Use the custom task or filter
                    $gradle_cmd clean test${llm_name^} jacocoTestReport --continue -q 2>&1 || \
                    $gradle_cmd clean test --tests "com.benchmark.${llm_name}.*" jacocoTestReport --continue -q 2>&1 || true
                    
                    # Check test results
                    if [ -d "build/test-results/test" ]; then
                        if grep -l "failures=\"[1-9]" build/test-results/test/*.xml 2>/dev/null || \
                           grep -l "errors=\"[1-9]" build/test-results/test/*.xml 2>/dev/null; then
                            tests_passed=false
                        fi
                    fi
                    
                    # Extract coverage
                    if [ -f "build/reports/jacoco/test/jacocoTestReport.xml" ]; then
                        cov=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('build/reports/jacoco/test/jacocoTestReport.xml')
for counter in tree.findall('.//counter[@type=\"LINE\"]'):
    missed = int(counter.get('missed', 0))
    covered = int(counter.get('covered', 0))
    total = missed + covered
    if total > 0:
        print(f'{covered / total * 100:.1f}')
        break
else:
    print('N/A')
" 2>/dev/null || echo "N/A")
                    fi
                else
                    # Maven
                    mvn clean test -Dtest="com.benchmark.$llm_name.**" jacoco:report -Dmaven.test.failure.ignore=true -q 2>&1
                    
                    if [ -d "target/surefire-reports" ]; then
                        if grep -l "failures=\"[1-9]" target/surefire-reports/*.xml 2>/dev/null || \
                           grep -l "errors=\"[1-9]" target/surefire-reports/*.xml 2>/dev/null; then
                            tests_passed=false
                        fi
                    fi
                    
                    if [ -f "target/site/jacoco/jacoco.xml" ]; then
                        cov=$(python3 -c "
import xml.etree.ElementTree as ET
tree = ET.parse('target/site/jacoco/jacoco.xml')
for counter in tree.findall('.//counter[@type=\"LINE\"]'):
    missed = int(counter.get('missed', 0))
    covered = int(counter.get('covered', 0))
    total = missed + covered
    if total > 0:
        print(f'{covered / total * 100:.1f}')
        break
else:
    print('N/A')
" 2>/dev/null || echo "N/A")
                    fi
                fi
                
                if [ "$tests_passed" = true ]; then
                    echo -e "  ${GREEN}PASS${NC} (Coverage: ${cov}%)"
                    echo "PASS|Java|$proj_name|$llm_name|$cov" > /tmp/test_result_$$
                    exit 0
                else
                    echo -e "  ${RED}FAIL${NC} (Coverage: ${cov}%)"
                    echo "FAIL|Java|$proj_name|$llm_name|$cov" > /tmp/test_result_$$
                    exit 1
                fi
            )
            local java_exit=$?
            
            # Read result from temp file
            if [ -f /tmp/test_result_$$ ]; then
                local result=$(cat /tmp/test_result_$$)
                rm -f /tmp/test_result_$$
                results+=("[$result]")
            fi
            
            [ $java_exit -eq 0 ] && ((passed++)) || ((failed++))
        done
    else
        ((total++))
        run_java_tests "$proj" && ((passed++)) || ((failed++))
    fi
done

echo ""
echo "=== Summary ==="
echo -e "Total: $total | ${GREEN}Passed: $passed${NC} | ${RED}Failed: $failed${NC}"

if [ ${#results[@]} -gt 0 ]; then
    echo ""
    echo "=== Coverage Results ==="
    printf "%-8s %-6s %-20s %-12s %s\n" "Status" "Lang" "Project" "LLM" "Coverage"
    printf "%-8s %-6s %-20s %-12s %s\n" "------" "----" "-------" "---" "--------"
    
    for r in "${results[@]}"; do
        # Parse: [PASS|JS|project|llm|coverage]
        # Remove brackets
        r="${r#[}"
        r="${r%]}"
        
        IFS='|' read -r status lang proj llm cov <<< "$r"
        
        # Color the status
        if [ "$status" = "PASS" ]; then
            status_colored="${GREEN}PASS${NC}"
        else
            status_colored="${RED}FAIL${NC}"
        fi
        
        # Color the coverage
        if [ "$cov" != "N/A" ] && [ "$cov" != "0" ]; then
            cov_num=${cov%.*}  # Remove decimal part for comparison
            if [ "$cov_num" -ge 90 ] 2>/dev/null; then
                cov_colored="${GREEN}${cov}%${NC}"
            elif [ "$cov_num" -ge 70 ] 2>/dev/null; then
                cov_colored="${YELLOW}${cov}%${NC}"
            else
                cov_colored="${RED}${cov}%${NC}"
            fi
        else
            cov_colored="${RED}${cov}${NC}"
        fi
        
        printf "%-8b %-6s %-20s %-12s %b\n" "$status_colored" "$lang" "$proj" "$llm" "$cov_colored"
    done
fi

[ $failed -gt 0 ] && exit 1 || exit 0