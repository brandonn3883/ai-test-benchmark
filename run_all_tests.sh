#!/bin/bash

##############################################################
# Universal Test Runner
##############################################################
# Automatically detects and runs tests for all benchmark projects
# Works with JavaScript, Python, and Java
##############################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Universal Test Runner"
echo "========================================="
echo ""

# Check if we're in the right place
if [ ! -d "../ai-test-benchmark" ] && [ ! -d "ai-test-benchmark" ]; then
    echo -e "${RED}Error: ai-test-benchmark directory not found${NC}"
    echo "Please run this from the directory containing ai-test-benchmark/"
    exit 1
fi

# Navigate to the correct directory
cd ../ai-test-benchmark 2>/dev/null || cd ai-test-benchmark

# Initialize counters
total_projects=0
successful_tests=0
failed_tests=0

# Store results
declare -a test_results

# Function to run JavaScript tests
run_javascript_tests() {
    local project_path=$1
    local project_name=$(basename "$project_path")
    
    echo -e "${BLUE}[JavaScript]${NC} Testing: $project_name"
    echo "  Location: $project_path"
    
    cd "$project_path"
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        echo -e "  ${YELLOW}No package.json found, skipping${NC}"
        return 1
    fi
    
    # Check if node_modules exists
    if [ ! -d "node_modules" ]; then
        echo "  Installing dependencies..."
        npm install --silent 2>&1 > /dev/null
    fi
    
    # Run tests
    echo "  Running tests..."
    if npm test 2>&1 | tee .test_output.tmp; then
        echo -e "  ${GREEN}+ Tests passed${NC}"
        
        # Run coverage
        echo "     Generating coverage..."
        npm run coverage 2>&1 > /dev/null || true
        
        if [ -f "coverage/coverage-summary.json" ]; then
            # Extract coverage percentage
            local coverage=$(cat coverage/coverage-summary.json | grep -o '"total".*"pct":[0-9.]*' | grep -o '[0-9.]*' | head -1)
            echo -e "  ${GREEN}   Coverage: ${coverage}%${NC}"
            test_results+=("[PASS] JavaScript/$project_name: PASS (${coverage}% coverage)")
        else
            test_results+=("[PASS] JavaScript/$project_name: PASS")
        fi
        
        rm -f .test_output.tmp
        return 0
    else
        echo -e "  ${RED}x Tests failed${NC}"
        test_results+=("[FAIL] JavaScript/$project_name: FAIL")
        rm -f .test_output.tmp
        return 1
    fi
}

# Function to run Python tests
run_python_tests() {
    local project_path=$1
    local project_name=$(basename "$project_path")
    
    echo -e "${BLUE}[Python]${NC} Testing: $project_name"
    echo "  Location: $project_path"
    
    cd "$project_path"
    
    # Check if tests directory exists
    if [ ! -d "tests" ] && [ ! -d "test" ]; then
        echo -e "  ${YELLOW}! No tests directory found, skipping${NC}"
        return 1
    fi
    
    # Activate virtual environment if it exists
    if [ -f "../../../venv/bin/activate" ]; then
        source ../../../venv/bin/activate
    fi
    
    # Check if pytest is available
    if ! command -v pytest &> /dev/null; then
        echo -e "  ${YELLOW}! pytest not found, skipping${NC}"
        return 1
    fi
    
    # Run tests with coverage
    echo "     Running tests with coverage..."
    if pytest --cov=src --cov=. --cov-report=term-missing --cov-report=json -v 2>&1 | tee .test_output.tmp; then
        echo -e "  ${GREEN}+ Tests passed${NC}"
        
        # Extract coverage from output or JSON
        if [ -f "coverage.json" ]; then
            local coverage=$(python3 -c "import json; print(json.load(open('coverage.json'))['totals']['percent_covered'])" 2>/dev/null || echo "N/A")
            if [ "$coverage" != "N/A" ]; then
                echo -e "  ${GREEN}   Coverage: ${coverage}%${NC}"
                test_results+=("[PASS] Python/$project_name: PASS (${coverage}% coverage)")
            else
                test_results+=("[PASS] Python/$project_name: PASS")
            fi
        else
            test_results+=("[PASS] Python/$project_name: PASS")
        fi
        
        rm -f .test_output.tmp
        return 0
    else
        echo -e "  ${RED}x Tests failed${NC}"
        test_results+=("[FAIL] Python/$project_name: FAIL")
        rm -f .test_output.tmp
        return 1
    fi
}

# Function to run Java tests
run_java_tests() {
    local project_path=$1
    local project_name=$(basename "$project_path")
    
    echo -e "${BLUE}[Java]${NC} Testing: $project_name"
    echo "  Location: $project_path"
    
    cd "$project_path"
    
    # Check if pom.xml exists
    if [ ! -f "pom.xml" ]; then
        echo -e "  ${YELLOW}! No pom.xml found, skipping${NC}"
        return 1
    fi
    
    # Check if Maven is available
    if ! command -v mvn &> /dev/null; then
        echo -e "  ${YELLOW}! Maven not found, skipping${NC}"
        return 1
    fi
    
    # Run tests with coverage
    echo "     Running tests with coverage..."
    if mvn clean test jacoco:report -q 2>&1 | tee .test_output.tmp; then
        echo -e "  ${GREEN}+ Tests passed${NC}"
        
        # Extract coverage from JaCoCo report
        if [ -f "target/site/jacoco/index.html" ]; then
            local coverage=$(grep -o 'Total[^%]*%' target/site/jacoco/index.html | grep -o '[0-9]*%' | head -1 | tr -d '%' || echo "N/A")
            if [ "$coverage" != "N/A" ]; then
                echo -e "  ${GREEN}   Coverage: ${coverage}%${NC}"
                test_results+=("[PASS] Java/$project_name: PASS (${coverage}% coverage)")
            else
                test_results+=("[PASS] Java/$project_name: PASS")
            fi
        else
            test_results+=("[PASS] Java/$project_name: PASS")
        fi
        
        rm -f .test_output.tmp
        return 0
    else
        echo -e "  ${RED}x Tests failed${NC}"
        test_results+=("[FAIL] Java/$project_name: FAIL")
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
            ((total_projects++))
            
            # Store current directory
            original_dir=$(pwd)
            
            if run_javascript_tests "$project"; then
                ((successful_tests++))
            else
                ((failed_tests++))
            fi
            
            # Return to original directory
            cd "$original_dir"
            echo ""
        fi
    done
fi

# Find and test Python projects
if [ -d "benchmarks/python" ]; then
    for project in benchmarks/python/*/; do
        if [ -d "$project" ]; then
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
    done
fi

# Find and test Java projects
if [ -d "benchmarks/java" ]; then
    for project in benchmarks/java/*/; do
        if [ -d "$project" ]; then
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
    done
fi

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo ""
echo "Total projects found: $total_projects"
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

# Coverage reports locations
echo "Coverage Reports:"
find benchmarks/ -name "index.html" -path "*/coverage/*" -o -path "*/htmlcov/*" -o -path "*/jacoco/*" 2>/dev/null | while read report; do
    echo "     $report"
done

echo ""
echo "========================================="

# Exit with appropriate code
if [ $failed_tests -gt 0 ]; then
    echo -e "${RED}Some tests failed${NC}"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
fi