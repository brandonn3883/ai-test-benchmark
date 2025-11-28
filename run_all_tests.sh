#!/bin/bash

##############################################################
# Universal Test Runner
##############################################################
# Run tests for specific LLMs or all LLMs
# Supports: --llm <name>, --all-llms, or default (all tests)
##############################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
LLM_FILTER=""
ALL_LLMS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --llm)
            LLM_FILTER="$2"
            shift 2
            ;;
        --all-llms)
            ALL_LLMS=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--llm <chatgpt|claude|gemini|copilot>] [--all-llms]"
            exit 1
            ;;
    esac
done

echo "========================================="
echo "Universal Test Runner"
echo "========================================="
echo ""

if [ -n "$LLM_FILTER" ]; then
    echo -e "${CYAN}Running tests for: $LLM_FILTER${NC}"
elif [ "$ALL_LLMS" = true ]; then
    echo -e "${CYAN}Running tests for all LLMs separately${NC}"
else
    echo -e "${CYAN}Running all tests${NC}"
fi
echo ""

# Check if we're in the right place
if [ ! -d "../ai-test-benchmark" ] && [ ! -d "ai-test-benchmark" ]; then
    echo -e "${RED}Error: ai-test-benchmark directory not found${NC}"
    echo "Please run this from the directory containing ai-test-benchmark/"
    exit 1
fi

cd ../ai-test-benchmark 2>/dev/null || cd ai-test-benchmark

# Initialize counters
total_projects=0
successful_tests=0
failed_tests=0

declare -a test_results

# Function to check if we should test this directory
should_test_llm() {
    local test_path=$1
    
    # If no filter, test everything
    if [ -z "$LLM_FILTER" ] && [ "$ALL_LLMS" = false ]; then
        return 0
    fi
    
    # If filtering by specific LLM
    if [ -n "$LLM_FILTER" ]; then
        if [[ "$test_path" == *"/$LLM_FILTER"* ]] || [[ "$test_path" == *"/$LLM_FILTER/"* ]]; then
            return 0
        else
            return 1
        fi
    fi
    
    # If running all LLMs, check if this is an LLM directory
    if [ "$ALL_LLMS" = true ]; then
        if [[ "$test_path" =~ .*/tests/(chatgpt|claude|gemini|copilot)$ ]]; then
            return 0
        else
            return 1
        fi
    fi
    
    return 1
}

# Function to get LLM name from path
get_llm_name() {
    local path=$1
    if [[ "$path" =~ chatgpt ]]; then
        echo "ChatGPT"
    elif [[ "$path" =~ claude ]]; then
        echo "Claude"
    elif [[ "$path" =~ gemini ]]; then
        echo "Gemini"
    elif [[ "$path" =~ copilot ]]; then
        echo "Copilot"
    else
        echo "Unknown"
    fi
}

# Function to run JavaScript tests
run_javascript_tests() {
    local project_path=$1
    local project_name=$(basename "$project_path")
    local llm_name=$(get_llm_name "$project_path")
    
    echo -e "${BLUE}[JavaScript]${NC} Testing: $project_name ${CYAN}($llm_name)${NC}"
    echo "  Location: $project_path"
    
    cd "$project_path"
    
    if [ ! -f "package.json" ]; then
        echo -e "  ${YELLOW}No package.json found, skipping${NC}"
        return 1
    fi
    
    if [ ! -d "node_modules" ]; then
        echo "  Installing dependencies..."
        npm install --silent 2>&1 > /dev/null
    fi
    
    echo "  Running tests..."
    if npm test 2>&1 | tee .test_output.tmp; then
        echo -e "  ${GREEN}+ Tests passed${NC}"
        
        # Run coverage
        echo "  Generating coverage..."
        npm run coverage 2>&1 > /dev/null || true
        
        if [ -f "coverage/coverage-summary.json" ]; then
            local coverage=$(cat coverage/coverage-summary.json | grep -o '"total".*"pct":[0-9.]*' | grep -o '[0-9.]*' | head -1)
            echo -e "  ${GREEN}Coverage: ${coverage}%${NC}"
            test_results+=("[PASS] JavaScript/$project_name ($llm_name): ${coverage}%")
        else
            test_results+=("[PASS] JavaScript/$project_name ($llm_name): PASS")
        fi
        
        rm -f .test_output.tmp
        return 0
    else
        echo -e "  ${RED}x Tests failed${NC}"
        test_results+=("[FAIL] JavaScript/$project_name ($llm_name): FAIL")
        rm -f .test_output.tmp
        return 1
    fi
}

# Function to run Python tests
run_python_tests() {
    local project_path=$1
    local project_name=$(basename "$project_path")
    local llm_name=$(get_llm_name "$project_path")
    
    echo -e "${BLUE}[Python]${NC} Testing: $project_name ${CYAN}($llm_name)${NC}"
    echo "  Location: $project_path"
    
    cd "$project_path"
    
    if [ ! -d "tests" ] && [ ! -d "test" ]; then
        echo -e "  ${YELLOW}No tests directory found, skipping${NC}"
        return 1
    fi
    
    if [ -f "../../../venv/bin/activate" ]; then
        source ../../../venv/bin/activate
    fi
    
    if ! command -v pytest &> /dev/null; then
        echo -e "  ${YELLOW}pytest not found, skipping${NC}"
        return 1
    fi
    
    echo "  Running tests with coverage..."
    if pytest --cov=src --cov=. --cov-report=term-missing --cov-report=json -v 2>&1 | tee .test_output.tmp; then
        echo -e "  ${GREEN}+ Tests passed${NC}"
        
        if [ -f "coverage.json" ]; then
            local coverage=$(python3 -c "import json; print(json.load(open('coverage.json'))['totals']['percent_covered'])" 2>/dev/null || echo "N/A")
            if [ "$coverage" != "N/A" ]; then
                echo -e "  ${GREEN}Coverage: ${coverage}%${NC}"
                test_results+=("[PASS] Python/$project_name ($llm_name): ${coverage}%")
            else
                test_results+=("[PASS] Python/$project_name ($llm_name): PASS")
            fi
        else
            test_results+=("[PASS] Python/$project_name ($llm_name): PASS")
        fi
        
        rm -f .test_output.tmp
        return 0
    else
        echo -e "  ${RED}x Tests failed${NC}"
        test_results+=("[FAIL] Python/$project_name ($llm_name): FAIL")
        rm -f .test_output.tmp
        return 1
    fi
}

# Function to run Java tests
run_java_tests() {
    local project_path=$1
    local project_name=$(basename "$project_path")
    local llm_name=$(get_llm_name "$project_path")
    
    echo -e "${BLUE}[Java]${NC} Testing: $project_name ${CYAN}($llm_name)${NC}"
    echo "  Location: $project_path"
    
    cd "$project_path"
    
    if [ ! -f "pom.xml" ]; then
        echo -e "  ${YELLOW}No pom.xml found, skipping${NC}"
        return 1
    fi
    
    if ! command -v mvn &> /dev/null; then
        echo -e "  ${YELLOW}Maven not found, skipping${NC}"
        return 1
    fi
    
    echo "  Running tests with coverage..."
    if mvn clean test jacoco:report -q 2>&1 | tee .test_output.tmp; then
        echo -e "  ${GREEN}+ Tests passed${NC}"
        
        if [ -f "target/site/jacoco/index.html" ]; then
            local coverage=$(grep -o 'Total[^%]*%' target/site/jacoco/index.html | grep -o '[0-9]*%' | head -1 | tr -d '%' || echo "N/A")
            if [ "$coverage" != "N/A" ]; then
                echo -e "  ${GREEN}Coverage: ${coverage}%${NC}"
                test_results+=("[PASS] Java/$project_name ($llm_name): ${coverage}%")
            else
                test_results+=("[PASS] Java/$project_name ($llm_name): PASS")
            fi
        else
            test_results+=("[PASS] Java/$project_name ($llm_name): PASS")
        fi
        
        rm -f .test_output.tmp
        return 0
    else
        echo -e "  ${RED}x Tests failed${NC}"
        test_results+=("[FAIL] Java/$project_name ($llm_name): FAIL")
        rm -f .test_output.tmp
        return 1
    fi
}

# Main execution
echo "Scanning for projects..."
echo ""

# Find and test JavaScript projects
if [ -d "benchmarks/javascript" ]; then
    for project in benchmarks/javascript/*/; do
        if [ -d "$project" ]; then
            
            # Check if we should test this project
            if [ -n "$LLM_FILTER" ] || [ "$ALL_LLMS" = true ]; then
                # Test specific LLM subdirectories
                for llm_dir in "$project"/tests/*; do
                    if [ -d "$llm_dir" ] && should_test_llm "$llm_dir"; then
                        # Check if there are test files
                        if ls "$llm_dir"/*.test.js 1> /dev/null 2>&1; then
                            ((total_projects++))
                            original_dir=$(pwd)
                            
                            # Temporarily adjust the project structure
                            # Move LLM tests to main tests directory
                            temp_tests="$project/tests_backup"
                            mkdir -p "$temp_tests"
                            mv "$project/tests" "$temp_tests/original" 2>/dev/null || true
                            mkdir -p "$project/tests"
                            cp -r "$llm_dir"/* "$project/tests/" 2>/dev/null || true
                            
                            if run_javascript_tests "$project"; then
                                ((successful_tests++))
                            else
                                ((failed_tests++))
                            fi
                            
                            # Restore original structure
                            rm -rf "$project/tests"
                            mv "$temp_tests/original" "$project/tests" 2>/dev/null || true
                            rm -rf "$temp_tests"
                            
                            cd "$original_dir"
                            echo ""
                        fi
                    fi
                done
            else
                # Test all tests in the project
                ((total_projects++))
                original_dir=$(pwd)
                
                if run_javascript_tests "$project"; then
                    ((successful_tests++))
                else
                    ((failed_tests++))
                fi
                
                cd "$original_dir"
                echo ""
            fi
        fi
    done
fi

# Find and test Python projects
if [ -d "benchmarks/python" ]; then
    for project in benchmarks/python/*/; do
        if [ -d "$project" ]; then
            
            if [ -n "$LLM_FILTER" ] || [ "$ALL_LLMS" = true ]; then
                for llm_dir in "$project"/tests/*; do
                    if [ -d "$llm_dir" ] && should_test_llm "$llm_dir"; then
                        if ls "$llm_dir"/test_*.py 1> /dev/null 2>&1; then
                            ((total_projects++))
                            original_dir=$(pwd)
                            
                            temp_tests="$project/tests_backup"
                            mkdir -p "$temp_tests"
                            mv "$project/tests" "$temp_tests/original" 2>/dev/null || true
                            mkdir -p "$project/tests"
                            cp -r "$llm_dir"/* "$project/tests/" 2>/dev/null || true
                            
                            if run_python_tests "$project"; then
                                ((successful_tests++))
                            else
                                ((failed_tests++))
                            fi
                            
                            rm -rf "$project/tests"
                            mv "$temp_tests/original" "$project/tests" 2>/dev/null || true
                            rm -rf "$temp_tests"
                            
                            cd "$original_dir"
                            echo ""
                        fi
                    fi
                done
            else
                ((total_projects++))
                original_dir=$(pwd)
                
                if run_python_tests "$project"; then
                    ((successful_tests++))
                else
                    ((failed_tests++))
                fi
                
                cd "$original_dir"
                echo ""
            fi
        fi
    done
fi

# Find and test Java projects
if [ -d "benchmarks/java" ]; then
    for project in benchmarks/java/*/; do
        if [ -d "$project" ]; then
            
            if [ -n "$LLM_FILTER" ] || [ "$ALL_LLMS" = true ]; then
                # For Java, LLM dirs are in src/test/java/com/benchmark/
                for llm_dir in "$project"/src/test/java/com/benchmark/*; do
                    if [ -d "$llm_dir" ] && should_test_llm "$llm_dir"; then
                        if ls "$llm_dir"/*Test.java 1> /dev/null 2>&1; then
                            ((total_projects++))
                            original_dir=$(pwd)
                            
                            # For Java, we'll use Maven test filtering
                            llm_name=$(basename "$llm_dir")
                            
                            cd "$project"
                            if mvn test -Dtest="com.benchmark.$llm_name.**" jacoco:report -q 2>&1 > /dev/null; then
                                ((successful_tests++))
                                echo -e "${GREEN}+ Tests passed for $llm_name${NC}"
                            else
                                ((failed_tests++))
                                echo -e "${RED}x Tests failed for $llm_name${NC}"
                            fi
                            
                            cd "$original_dir"
                            echo ""
                        fi
                    fi
                done
            else
                ((total_projects++))
                original_dir=$(pwd)
                
                if run_java_tests "$project"; then
                    ((successful_tests++))
                else
                    ((failed_tests++))
                fi
                
                cd "$original_dir"
                echo ""
            fi
        fi
    done
fi

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo ""
echo "Total test runs: $total_projects"
echo -e "${GREEN}+ Passed: $successful_tests${NC}"
if [ $failed_tests -gt 0 ]; then
    echo -e "${RED}x Failed: $failed_tests${NC}"
else
    echo "x Failed: 0"
fi
echo ""

# Detailed results
if [ ${#test_results[@]} -gt 0 ]; then
    echo "Detailed Results:"
    for result in "${test_results[@]}"; do
        echo "  $result"
    done
    echo ""
fi

echo "========================================="

# Exit with appropriate code
if [ $failed_tests -gt 0 ]; then
    echo -e "${RED}Some tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi