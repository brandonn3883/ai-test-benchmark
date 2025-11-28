#!/bin/bash

##############################################################
# Coverage Report Generator (LLM Comparison Version)
##############################################################
# Generates coverage reports for each LLM separately
# Creates comparison reports and CSV exports
# Compatible with Bash 3.2+ (macOS default)
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
COMPARE_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --llm)
            LLM_FILTER="$2"
            shift 2
            ;;
        --compare-all)
            COMPARE_ALL=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--llm <chatgpt|claude|gemini|copilot>] [--compare-all]"
            exit 1
            ;;
    esac
done

echo "========================================="
echo "Coverage Report Generator (LLM Comparison)"
echo "========================================="
echo ""

if [ -n "$LLM_FILTER" ]; then
    echo -e "${CYAN}Generating coverage for: $LLM_FILTER${NC}"
elif [ "$COMPARE_ALL" = true ]; then
    echo -e "${CYAN}Generating comparison report for all LLMs${NC}"
else
    echo -e "${CYAN}Generating coverage reports${NC}"
fi
echo ""

# Check directory
if [ ! -d "../ai-test-benchmark" ] && [ ! -d "ai-test-benchmark" ]; then
    echo -e "${RED}ERROR: ai-test-benchmark directory not found${NC}"
    exit 1
fi

cd ../ai-test-benchmark 2>/dev/null || cd ai-test-benchmark

# Create results directory
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="results/coverage_reports/$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

echo "Results will be saved to: $RESULTS_DIR"
echo ""

# Use regular arrays instead of associative arrays
declare -a coverage_keys
declare -a coverage_values
total_projects=0

# Helper function to store coverage data
store_coverage() {
    local key="$1"
    local value="$2"
    coverage_keys+=("$key")
    coverage_values+=("$value")
}

# Helper function to get coverage data
get_coverage() {
    local search_key="$1"
    local i
    for i in "${!coverage_keys[@]}"; do
        if [ "${coverage_keys[$i]}" = "$search_key" ]; then
            echo "${coverage_values[$i]}"
            return 0
        fi
    done
    echo ""
}

# Function to extract JS coverage for specific LLM
extract_js_coverage_llm() {
    local project_path=$1
    local llm_name=$2
    local project_name=$(basename "$project_path")
    
    echo -e "${BLUE}[JavaScript]${NC} $project_name - ${CYAN}$llm_name${NC}"
    
    cd "$project_path"
    
    if [ ! -f "package.json" ]; then
        echo -e "  ${YELLOW}No package.json, skipping${NC}"
        return 0
    fi
    
    # Check if LLM directory has tests
    if [ ! -d "tests/$llm_name" ] || [ -z "$(ls -A tests/$llm_name/*.test.js 2>/dev/null)" ]; then
        echo -e "  ${YELLOW}No tests found for $llm_name, skipping${NC}"
        return 0
    fi
    
    if [ ! -d "node_modules" ]; then
        echo "  Installing dependencies..."
        npm install --silent 2>&1 > /dev/null
    fi
    
    echo "  Generating coverage..."
    
    # Temporarily set up test directory
    temp_tests="tests_backup"
    mkdir -p "$temp_tests"
    mv tests "$temp_tests/original" 2>/dev/null || true
    mkdir -p tests
    cp -r "$temp_tests/original/$llm_name"/* tests/ 2>/dev/null || true
    
    npm run coverage 2>&1 > /dev/null || true
    
    if [ -f "coverage/coverage-summary.json" ]; then
        local statements=$(python3 -c "import json; print(json.load(open('coverage/coverage-summary.json'))['total']['statements']['pct'])" 2>/dev/null || echo "0")
    local branches=$(python3 -c "import json; print(json.load(open('coverage/coverage-summary.json'))['total']['branches']['pct'])" 2>/dev/null || echo "0")
    local functions=$(python3 -c "import json; print(json.load(open('coverage/coverage-summary.json'))['total']['functions']['pct'])" 2>/dev/null || echo "0")
    local lines=$(python3 -c "import json; print(json.load(open('coverage/coverage-summary.json'))['total']['lines']['pct'])" 2>/dev/null || echo "0")
        
        # Default to 0 if empty
        statements=${statements:-0}
        branches=${branches:-0}
        functions=${functions:-0}
        lines=${lines:-0}
        
        echo -e "  ${GREEN}Statements: ${statements}% | Branches: ${branches}% | Functions: ${functions}% | Lines: ${lines}%${NC}"
        
        # Store in arrays
        local key="${project_name}|${llm_name}"
        local value="JavaScript|$project_name|$llm_name|$statements|$branches|$functions|$lines"
        store_coverage "$key" "$value"
        
        # Copy coverage to results
        local report_dir="$RESULTS_DIR/${llm_name}_${project_name}"
        mkdir -p "$report_dir"
        cp -r coverage/* "$report_dir/" 2>/dev/null || true
        
        ((total_projects++))
    else
        echo -e "  ${YELLOW}No coverage generated${NC}"
    fi
    
    # Restore original structure
    rm -rf tests
    mv "$temp_tests/original" tests 2>/dev/null || true
    rm -rf "$temp_tests"
    
    return 0
}

# Function to extract Python coverage for specific LLM
extract_python_coverage_llm() {
    local project_path=$1
    local llm_name=$2
    local project_name=$(basename "$project_path")
    
    echo -e "${BLUE}[Python]${NC} $project_name - ${CYAN}$llm_name${NC}"
    
    cd "$project_path"
    
    if [ ! -d "tests/$llm_name" ] || [ -z "$(ls -A tests/$llm_name/test_*.py 2>/dev/null)" ]; then
        echo -e "  ${YELLOW}No tests found for $llm_name, skipping${NC}"
        return 0
    fi
    
    if [ -f "../../../venv/bin/activate" ]; then
        source ../../../venv/bin/activate
    fi
    
    if ! command -v pytest &> /dev/null; then
        echo -e "  ${YELLOW}pytest not found, skipping${NC}"
        return 0
    fi
    
    echo "  Generating coverage..."
    
    # Temporarily set up test directory
    temp_tests="tests_backup"
    mkdir -p "$temp_tests"
    mv tests "$temp_tests/original" 2>/dev/null || true
    mkdir -p tests
    cp -r "$temp_tests/original/$llm_name"/* tests/ 2>/dev/null || true
    touch tests/__init__.py
    
    pytest --cov=src --cov-report=html --cov-report=json -q 2>&1 > /dev/null || true
    
    if [ -f "coverage.json" ]; then
        local total=$(python3 -c "import json; print(f\"{json.load(open('coverage.json'))['totals']['percent_covered']:.2f}\")" 2>/dev/null || echo "0")
        
        echo -e "  ${GREEN}Coverage: ${total}%${NC}"
        
        local key="${project_name}|${llm_name}"
        local value="Python|$project_name|$llm_name|$total|$total|$total|$total"
        store_coverage "$key" "$value"
        
        local report_dir="$RESULTS_DIR/${llm_name}_${project_name}"
        mkdir -p "$report_dir"
        cp -r htmlcov/* "$report_dir/" 2>/dev/null || true
        
        ((total_projects++))
    else
        echo -e "  ${YELLOW}No coverage generated${NC}"
    fi
    
    # Restore
    rm -rf tests
    mv "$temp_tests/original" tests 2>/dev/null || true
    rm -rf "$temp_tests"
    
    return 0
}

# Function to extract Java coverage for specific LLM
extract_java_coverage_llm() {
    local project_path=$1
    local llm_name=$2
    local project_name=$(basename "$project_path")
    
    echo -e "${BLUE}[Java]${NC} $project_name - ${CYAN}$llm_name${NC}"
    
    cd "$project_path"
    
    if [ ! -f "pom.xml" ]; then
        echo -e "  ${YELLOW}No pom.xml, skipping${NC}"
        return 0
    fi
    
    if ! command -v mvn &> /dev/null; then
        echo -e "  ${YELLOW}Maven not found, skipping${NC}"
        return 0
    fi
    
    # Check if LLM package exists
    if [ ! -d "src/test/java/com/benchmark/$llm_name" ]; then
        echo -e "  ${YELLOW}No tests for $llm_name, skipping${NC}"
        return 0
    fi
    
    echo "  Generating coverage..."
    
    mvn clean test -Dtest="com.benchmark.$llm_name.**" jacoco:report -q 2>&1 > /dev/null || true
    
    if [ -f "target/site/jacoco/jacoco.xml" ]; then
        local coverage=$(python3 -c "
import xml.etree.ElementTree as ET
try:
    tree = ET.parse('target/site/jacoco/jacoco.xml')
    for counter in tree.findall('.//counter[@type=\"LINE\"]'):
        missed = int(counter.get('missed', 0))
        covered = int(counter.get('covered', 0))
        total = missed + covered
        if total > 0:
            print(f'{(covered/total)*100:.2f}')
            break
    else:
        print('0')
except:
    print('0')
" 2>/dev/null || echo "0")
        
        echo -e "  ${GREEN}Coverage: ${coverage}%${NC}"
        
        local key="${project_name}|${llm_name}"
        local value="Java|$project_name|$llm_name|$coverage|$coverage|$coverage|$coverage"
        store_coverage "$key" "$value"
        
        local report_dir="$RESULTS_DIR/${llm_name}_${project_name}"
        mkdir -p "$report_dir"
        cp -r target/site/jacoco/* "$report_dir/" 2>/dev/null || true
        
        ((total_projects++))
    else
        echo -e "  ${YELLOW}No coverage generated${NC}"
    fi
    
    return 0
}

# Determine which LLMs to process
if [ -n "$LLM_FILTER" ]; then
    LLMS_TO_PROCESS=("$LLM_FILTER")
elif [ "$COMPARE_ALL" = true ]; then
    LLMS_TO_PROCESS=("chatgpt" "claude" "gemini" "copilot")
else
    LLMS_TO_PROCESS=("chatgpt" "claude" "gemini" "copilot")
fi

echo "Processing LLMs: ${LLMS_TO_PROCESS[@]}"
echo ""

# Process JavaScript projects
if [ -d "benchmarks/javascript" ]; then
    for project in benchmarks/javascript/*/; do
        if [ -d "$project" ]; then
            original_dir=$(pwd)
            for llm in "${LLMS_TO_PROCESS[@]}"; do
                extract_js_coverage_llm "$project" "$llm"
                cd "$original_dir"
            done
            echo ""
        fi
    done
fi

# Process Python projects
if [ -d "benchmarks/python" ]; then
    for project in benchmarks/python/*/; do
        if [ -d "$project" ]; then
            original_dir=$(pwd)
            for llm in "${LLMS_TO_PROCESS[@]}"; do
                extract_python_coverage_llm "$project" "$llm"
                cd "$original_dir"
            done
            echo ""
        fi
    done
fi

# Process Java projects
if [ -d "benchmarks/java" ]; then
    for project in benchmarks/java/*/; do
        if [ -d "$project" ]; then
            original_dir=$(pwd)
            for llm in "${LLMS_TO_PROCESS[@]}"; do
                extract_java_coverage_llm "$project" "$llm"
                cd "$original_dir"
            done
            echo ""
        fi
    done
fi

# Generate reports
echo "========================================="
echo "Generating Reports"
echo "========================================="
echo ""

# CSV Report
CSV_FILE="$RESULTS_DIR/coverage_comparison.csv"
echo "Language,Project,LLM,Statements,Branches,Functions,Lines" > "$CSV_FILE"

for i in "${!coverage_keys[@]}"; do
    echo "${coverage_values[$i]}" | tr '|' ',' >> "$CSV_FILE"
done

echo -e "${GREEN}+ CSV saved: $CSV_FILE${NC}"

# Markdown Report
MD_FILE="$RESULTS_DIR/comparison_report.md"
cat > "$MD_FILE" << EOF
# LLM Test Generation Comparison Report

Generated: $(date)

## Summary

Total projects analyzed: $total_projects

## Coverage by LLM and Project

| Language | Project | LLM | Statements | Branches | Functions | Lines |
|----------|---------|-----|-----------|----------|-----------|-------|
EOF

# Add data
for i in "${!coverage_keys[@]}"; do
    IFS='|' read -r lang project llm stmt branch func line <<< "${coverage_values[$i]}"
    echo "| $lang | $project | $llm | ${stmt}% | ${branch}% | ${func}% | ${line}% |" >> "$MD_FILE"
done

# Calculate averages per LLM
cat >> "$MD_FILE" << 'EOF'

## Average Coverage by LLM

EOF

for llm in "${LLMS_TO_PROCESS[@]}"; do
    avg=$(awk -F',' -v llm="$llm" '
        $3 == llm { sum += $4; count++ }
        END { if (count > 0) printf "%.2f", sum/count; else print "N/A" }
    ' "$CSV_FILE")
    
    if [ "$avg" != "N/A" ]; then
        echo "- **$llm**: ${avg}%" >> "$MD_FILE"
    fi
done

echo -e "${GREEN}+ Markdown saved: $MD_FILE${NC}"

# HTML Comparison Report
HTML_FILE="$RESULTS_DIR/comparison.html"
cat > "$HTML_FILE" << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>LLM Test Generation Comparison</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1400px;
            margin: 50px auto;
            padding: 20px;
            background: #f5f5f5;
        }
        h1 {
            color: #333;
            border-bottom: 3px solid #4CAF50;
            padding-bottom: 10px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            margin: 20px 0;
        }
        th {
            background: #4CAF50;
            color: white;
            padding: 12px;
            text-align: left;
        }
        td {
            padding: 10px;
            border-bottom: 1px solid #ddd;
        }
        tr:hover {
            background: #f5f5f5;
        }
        .chatgpt { background: #e8f5e9; }
        .claude { background: #e3f2fd; }
        .gemini { background: #fff3e0; }
        .copilot { background: #f3e5f5; }
        .high { color: #4CAF50; font-weight: bold; }
        .medium { color: #FF9800; font-weight: bold; }
        .low { color: #F44336; font-weight: bold; }
        .summary-box {
            background: white;
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
    </style>
</head>
<body>
    <h1>LLM Test Generation Comparison</h1>
    <p><strong>Generated:</strong> TIMESTAMP_PLACEHOLDER</p>
    
    <div class="summary-box">
        <h2>Summary</h2>
        <p>Total projects analyzed: <strong>TOTAL_PROJECTS</strong></p>
    </div>
    
    <h2>Coverage Comparison</h2>
    <table>
        <thead>
            <tr>
                <th>Language</th>
                <th>Project</th>
                <th>LLM</th>
                <th>Statements</th>
                <th>Branches</th>
                <th>Functions</th>
                <th>Lines</th>
                <th>Average</th>
            </tr>
        </thead>
        <tbody>
HTMLEOF

# Add data rows
for i in "${!coverage_keys[@]}"; do
    IFS='|' read -r lang project llm stmt branch func line <<< "${coverage_values[$i]}"
    
    # Calculate average
    avg=$(echo "scale=2; ($stmt + $branch + $func + $line) / 4" | bc 2>/dev/null || echo "0")
    
    # Determine class
    if [ $(echo "$avg >= 90" | bc 2>/dev/null || echo 0) -eq 1 ]; then
        class="high"
    elif [ $(echo "$avg >= 70" | bc 2>/dev/null || echo 0) -eq 1 ]; then
        class="medium"
    else
        class="low"
    fi
    
    cat >> "$HTML_FILE" << HTMLROW
            <tr class="$llm">
                <td>$lang</td>
                <td>$project</td>
                <td><strong>$llm</strong></td>
                <td>${stmt}%</td>
                <td>${branch}%</td>
                <td>${func}%</td>
                <td>${line}%</td>
                <td class="$class">${avg}%</td>
            </tr>
HTMLROW
done

cat >> "$HTML_FILE" << 'HTMLEOF'
        </tbody>
    </table>
    
    <div class="summary-box">
        <h2>Average by LLM</h2>
HTMLEOF

# Calculate and add averages
for llm in "${LLMS_TO_PROCESS[@]}"; do
    avg=$(awk -F',' -v llm="$llm" '
        $3 == llm { sum += $4; count++ }
        END { if (count > 0) printf "%.2f", sum/count; else print "0" }
    ' "$CSV_FILE")
    
    echo "        <p><strong>$llm:</strong> ${avg}%</p>" >> "$HTML_FILE"
done

cat >> "$HTML_FILE" << 'HTMLEOF'
    </div>
    
    <div class="summary-box">
        <h2>Coverage Legend</h2>
        <p>
            <span class="high">■ High (≥90%)</span> |
            <span class="medium">■ Medium (70-89%)</span> |
            <span class="low">■ Low (<70%)</span>
        </p>
    </div>
</body>
</html>
HTMLEOF

# Replace placeholders
sed -i.bak "s/TIMESTAMP_PLACEHOLDER/$(date)/" "$HTML_FILE" 2>/dev/null || sed -i '' "s/TIMESTAMP_PLACEHOLDER/$(date)/" "$HTML_FILE"
sed -i.bak "s/TOTAL_PROJECTS/$total_projects/" "$HTML_FILE" 2>/dev/null || sed -i '' "s/TOTAL_PROJECTS/$total_projects/" "$HTML_FILE"
rm -f "$HTML_FILE.bak"

echo -e "${GREEN}+ HTML saved: $HTML_FILE${NC}"

# Create latest symlink
cd results/coverage_reports
rm -f latest
ln -s "$TIMESTAMP" latest
cd ../..

echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo ""
echo "Projects analyzed: $total_projects"
echo ""
echo "Reports saved to: $RESULTS_DIR"
echo ""
echo "View reports:"
echo "  HTML: $HTML_FILE"
echo "  Markdown: $MD_FILE"
echo "  CSV: $CSV_FILE"
echo ""
echo "Open comparison report:"
echo "  open $HTML_FILE"
echo ""
echo "Or access via latest:"
echo "  open results/coverage_reports/latest/comparison.html"
echo ""
echo "========================================="
echo -e "${GREEN}Coverage analysis complete!${NC}"
echo "========================================="