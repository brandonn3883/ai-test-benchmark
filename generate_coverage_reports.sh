#!/bin/bash

##############################################################
# Universal Coverage Report Generator
##############################################################
# Generates coverage reports for all benchmark projects
# Creates unified summary and individual reports
##############################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "========================================="
echo "Universal Coverage Report Generator"
echo "========================================="
echo ""

# Check if we're in the right place
if [ ! -d "../ai-test-benchmark" ] && [ ! -d "ai-test-benchmark" ]; then
    echo -e "${RED}ERROR: ai-test-benchmark directory not found${NC}"
    echo "Please run this from the directory containing ai-test-benchmark/"
    exit 1
fi

# Navigate to the correct directory
cd ../ai-test-benchmark 2>/dev/null || cd ai-test-benchmark

# Create results directory with timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="results/coverage_reports/$TIMESTAMP"
mkdir -p "$RESULTS_DIR"

echo "Results will be saved to: $RESULTS_DIR"
echo ""

# Initialize summary data
declare -a coverage_data
total_projects=0

# Function to extract JavaScript coverage
extract_js_coverage() {
    local project_path=$1
    local project_name=$(basename "$project_path")
    
    echo -e "${BLUE}[JavaScript]${NC} Analyzing: $project_name"
    
    cd "$project_path"
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        echo -e "  ${YELLOW}WARNING: No package.json, skipping${NC}"
        return 1
    fi
    
    # Install dependencies if needed
    if [ ! -d "node_modules" ]; then
        echo "  Installing dependencies..."
        npm install --silent 2>&1 > /dev/null
    fi
    
    # Run coverage
    echo "     Generating coverage..."
    npm run coverage 2>&1 > /dev/null || npm test -- --coverage 2>&1 > /dev/null || true
    
    # Extract coverage data
    if [ -f "coverage/coverage-summary.json" ]; then
        local statements=$(jq -r '.total.statements.pct' coverage/coverage-summary.json 2>/dev/null || echo "0")
        local branches=$(jq -r '.total.branches.pct' coverage/coverage-summary.json 2>/dev/null || echo "0")
        local functions=$(jq -r '.total.functions.pct' coverage/coverage-summary.json 2>/dev/null || echo "0")
        local lines=$(jq -r '.total.lines.pct' coverage/coverage-summary.json 2>/dev/null || echo "0")
        
        echo -e "  ${GREEN}+ Statements: ${statements}% | Branches: ${branches}% | Functions: ${functions}% | Lines: ${lines}%${NC}"
        
        # Save to summary
        coverage_data+=("JavaScript|$project_name|$statements|$branches|$functions|$lines|coverage/index.html")
        
        # Copy coverage report to results
        local report_dir="$RESULTS_DIR/javascript_${project_name}"
        mkdir -p "$report_dir"
        if [ -d "coverage" ]; then
            cp -r coverage/* "$report_dir/" 2>/dev/null || true
        fi
        
        ((total_projects++))
        return 0
    else
        echo -e "  ${YELLOW}WARNING: No coverage data generated${NC}"
        coverage_data+=("JavaScript|$project_name|N/A|N/A|N/A|N/A|N/A")
        return 1
    fi
}

# Function to extract Python coverage
extract_python_coverage() {
    local project_path=$1
    local project_name=$(basename "$project_path")
    
    echo -e "${BLUE}[Python]${NC} Analyzing: $project_name"
    
    cd "$project_path"
    
    # Check if tests exist
    if [ ! -d "tests" ] && [ ! -d "test" ]; then
        echo -e "  ${YELLOW}WARNING: No tests directory, skipping${NC}"
        return 1
    fi
    
    # Activate virtual environment
    if [ -f "../../../venv/bin/activate" ]; then
        source ../../../venv/bin/activate
    fi
    
    # Check if pytest is available
    if ! command -v pytest &> /dev/null; then
        echo -e "  ${YELLOW}WARNING: pytest not found, skipping${NC}"
        return 1
    fi
    
    # Run coverage
    echo "     Generating coverage..."
    pytest --cov=src --cov=. --cov-report=html --cov-report=json --cov-report=term-missing -q 2>&1 > /dev/null || true
    
    # Extract coverage data
    if [ -f "coverage.json" ]; then
        local total_coverage=$(python3 -c "
import json
try:
    data = json.load(open('coverage.json'))
    print(f\"{data['totals']['percent_covered']:.2f}\")
except:
    print('0')
" 2>/dev/null || echo "0")
        
        # Python coverage.py doesn't separate branches/functions in the same way
        # We'll show total coverage for all metrics
        echo -e "  ${GREEN}+ Coverage: ${total_coverage}%${NC}"
        
        coverage_data+=("Python|$project_name|$total_coverage|$total_coverage|$total_coverage|$total_coverage|htmlcov/index.html")
        
        # Copy coverage report to results
        local report_dir="$RESULTS_DIR/python_${project_name}"
        mkdir -p "$report_dir"
        if [ -d "htmlcov" ]; then
            cp -r htmlcov/* "$report_dir/" 2>/dev/null || true
        fi
        
        ((total_projects++))
        return 0
    else
        echo -e "  ${YELLOW}WARNING: No coverage data generated${NC}"
        coverage_data+=("Python|$project_name|N/A|N/A|N/A|N/A|N/A")
        return 1
    fi
}

# Function to extract Java coverage
extract_java_coverage() {
    local project_path=$1
    local project_name=$(basename "$project_path")
    
    echo -e "${BLUE}[Java]${NC} Analyzing: $project_name"
    
    cd "$project_path"
    
    # Check if pom.xml exists
    if [ ! -f "pom.xml" ]; then
        echo -e "  ${YELLOW}WARNING: No pom.xml, skipping${NC}"
        return 1
    fi
    
    # Check if Maven is available
    if ! command -v mvn &> /dev/null; then
        echo -e "  ${YELLOW}WARNING: Maven not found, skipping${NC}"
        return 1
    fi
    
    # Run coverage
    echo "     Generating coverage..."
    mvn clean test jacoco:report -q 2>&1 > /dev/null || true
    
    # Extract coverage data from JaCoCo XML
    if [ -f "target/site/jacoco/jacoco.xml" ]; then
        local instruction=$(python3 -c "
import xml.etree.ElementTree as ET
try:
    tree = ET.parse('target/site/jacoco/jacoco.xml')
    root = tree.getroot()
    for counter in root.findall('.//counter[@type=\"INSTRUCTION\"]'):
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
        
        local branch=$(python3 -c "
import xml.etree.ElementTree as ET
try:
    tree = ET.parse('target/site/jacoco/jacoco.xml')
    root = tree.getroot()
    for counter in root.findall('.//counter[@type=\"BRANCH\"]'):
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
        
        local line=$(python3 -c "
import xml.etree.ElementTree as ET
try:
    tree = ET.parse('target/site/jacoco/jacoco.xml')
    root = tree.getroot()
    for counter in root.findall('.//counter[@type=\"LINE\"]'):
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
        
        local method=$(python3 -c "
import xml.etree.ElementTree as ET
try:
    tree = ET.parse('target/site/jacoco/jacoco.xml')
    root = tree.getroot()
    for counter in root.findall('.//counter[@type=\"METHOD\"]'):
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
        
        echo -e "  ${GREEN}+ Instruction: ${instruction}% | Branch: ${branch}% | Line: ${line}% | Method: ${method}%${NC}"
        
        coverage_data+=("Java|$project_name|$instruction|$branch|$method|$line|target/site/jacoco/index.html")
        
        # Copy coverage report to results
        local report_dir="$RESULTS_DIR/java_${project_name}"
        mkdir -p "$report_dir"
        if [ -d "target/site/jacoco" ]; then
            cp -r target/site/jacoco/* "$report_dir/" 2>/dev/null || true
        fi
        
        ((total_projects++))
        return 0
    else
        echo -e "  ${YELLOW}WARNING: No coverage data generated${NC}"
        coverage_data+=("Java|$project_name|N/A|N/A|N/A|N/A|N/A")
        return 1
    fi
}

# Scan and process JavaScript projects
echo "Scanning for projects..."
echo ""

if [ -d "benchmarks/javascript" ]; then
    for project in benchmarks/javascript/*/; do
        if [ -d "$project" ]; then
            original_dir=$(pwd)
            extract_js_coverage "$project"
            cd "$original_dir"
            echo ""
        fi
    done
fi

# Scan and process Python projects
if [ -d "benchmarks/python" ]; then
    for project in benchmarks/python/*/; do
        if [ -d "$project" ]; then
            original_dir=$(pwd)
            extract_python_coverage "$project"
            cd "$original_dir"
            echo ""
        fi
    done
fi

# Scan and process Java projects
if [ -d "benchmarks/java" ]; then
    for project in benchmarks/java/*/; do
        if [ -d "$project" ]; then
            original_dir=$(pwd)
            extract_java_coverage "$project"
            cd "$original_dir"
            echo ""
        fi
    done
fi

# Generate CSV summary
echo "========================================="
echo "Generating Summary Reports"
echo "========================================="
echo ""

CSV_FILE="$RESULTS_DIR/coverage_summary.csv"
echo "Language,Project,Statements/Instruction,Branches,Functions/Methods,Lines,Report Path" > "$CSV_FILE"

for data in "${coverage_data[@]}"; do
    echo "$data" | tr '|' ',' >> "$CSV_FILE"
done

echo -e "${GREEN}+ CSV summary saved: $CSV_FILE${NC}"

# Generate Markdown summary
MD_FILE="$RESULTS_DIR/coverage_summary.md"
cat > "$MD_FILE" << 'EOF'
# Coverage Report Summary

Generated: TIMESTAMP_PLACEHOLDER

## Overview

Total projects analyzed: TOTAL_PROJECTS

## Coverage by Project

| Language | Project | Statements/Instruction | Branches | Functions/Methods | Lines | Report |
|----------|---------|------------------------|----------|-------------------|-------|--------|
EOF

# Replace timestamp placeholder
sed -i.bak "s/TIMESTAMP_PLACEHOLDER/$(date)/" "$MD_FILE"
sed -i.bak "s/TOTAL_PROJECTS/$total_projects/" "$MD_FILE"
rm -f "$MD_FILE.bak"

# Add data rows
for data in "${coverage_data[@]}"; do
    IFS='|' read -r lang project statements branches functions lines report <<< "$data"
    
    # Format report link
    if [ "$report" != "N/A" ]; then
        report_link="[View Report]($(basename $(dirname "$report"))_$project/index.html)"
    else
        report_link="N/A"
    fi
    
    echo "| $lang | $project | $statements% | $branches% | $functions% | $lines% | $report_link |" >> "$MD_FILE"
done

# Add average calculations
cat >> "$MD_FILE" << 'EOF'

## Coverage Averages

EOF

# Calculate averages for each language
for lang in JavaScript Python Java; do
    avg_coverage=$(awk -F',' -v lang="$lang" '
        $1 == lang && $3 != "N/A" { 
            sum += $3; count++ 
        } 
        END { 
            if (count > 0) 
                printf "%.2f", sum/count; 
            else 
                print "N/A" 
        }' "$CSV_FILE")
    
    if [ "$avg_coverage" != "N/A" ]; then
        echo "- **$lang**: ${avg_coverage}%" >> "$MD_FILE"
    fi
done

echo -e "${GREEN}+ Markdown summary saved: $MD_FILE${NC}"

# Generate HTML index
HTML_FILE="$RESULTS_DIR/index.html"
cat > "$HTML_FILE" << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <title>Coverage Report Summary</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1200px;
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
        .coverage-high { color: #4CAF50; font-weight: bold; }
        .coverage-medium { color: #FF9800; font-weight: bold; }
        .coverage-low { color: #F44336; font-weight: bold; }
        .timestamp {
            color: #666;
            font-size: 0.9em;
        }
        .summary-box {
            background: white;
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }
        a {
            color: #2196F3;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <h1>   Coverage Report Summary</h1>
    <p class="timestamp">Generated: TIMESTAMP_PLACEHOLDER</p>
    
    <div class="summary-box">
        <h2>Overview</h2>
        <p>Total projects analyzed: <strong>TOTAL_PROJECTS</strong></p>
    </div>
    
    <h2>Coverage by Project</h2>
    <table>
        <thead>
            <tr>
                <th>Language</th>
                <th>Project</th>
                <th>Statements/Instruction</th>
                <th>Branches</th>
                <th>Functions/Methods</th>
                <th>Lines</th>
                <th>Report</th>
            </tr>
        </thead>
        <tbody>
HTMLEOF

# Add data rows to HTML
for data in "${coverage_data[@]}"; do
    IFS='|' read -r lang project statements branches functions lines report <<< "$data"
    
    # Determine coverage class
    get_coverage_class() {
        local val=$1
        if [ "$val" = "N/A" ]; then
            echo ""
        elif (( $(echo "$val >= 80" | bc -l 2>/dev/null || echo 0) )); then
            echo "coverage-high"
        elif (( $(echo "$val >= 60" | bc -l 2>/dev/null || echo 0) )); then
            echo "coverage-medium"
        else
            echo "coverage-low"
        fi
    }
    
    stmt_class=$(get_coverage_class "$statements")
    branch_class=$(get_coverage_class "$branches")
    func_class=$(get_coverage_class "$functions")
    line_class=$(get_coverage_class "$lines")
    
    # Format report link
    if [ "$report" != "N/A" ]; then
        report_link="<a href='$(basename $(dirname "$report"))_$project/index.html'>View Report</a>"
    else
        report_link="N/A"
    fi
    
    cat >> "$HTML_FILE" << HTMLROW
            <tr>
                <td>$lang</td>
                <td>$project</td>
                <td class="$stmt_class">${statements}%</td>
                <td class="$branch_class">${branches}%</td>
                <td class="$func_class">${functions}%</td>
                <td class="$line_class">${lines}%</td>
                <td>$report_link</td>
            </tr>
HTMLROW
done

cat >> "$HTML_FILE" << 'HTMLEOF'
        </tbody>
    </table>
    
    <div class="summary-box">
        <h2>Coverage Legend</h2>
        <p>
            <span class="coverage-high">■ High (≥80%)</span> | 
            <span class="coverage-medium">■ Medium (60-79%)</span> | 
            <span class="coverage-low">■ Low (<60%)</span>
        </p>
    </div>
</body>
</html>
HTMLEOF

# Replace placeholders in HTML
sed -i.bak "s/TIMESTAMP_PLACEHOLDER/$(date)/" "$HTML_FILE"
sed -i.bak "s/TOTAL_PROJECTS/$total_projects/" "$HTML_FILE"
rm -f "$HTML_FILE.bak"

echo -e "${GREEN}+ HTML summary saved: $HTML_FILE${NC}"

# Create a "latest" symlink
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
echo "     HTML: $HTML_FILE"
echo "     Markdown: $MD_FILE"
echo "     CSV: $CSV_FILE"
echo ""
echo "Open HTML report:"
echo "  open $HTML_FILE"
echo ""
echo "Or access via latest link:"
echo "  open results/coverage_reports/latest/index.html"
echo ""
echo "========================================="
echo -e "${GREEN}+ Coverage analysis complete!${NC}"
echo "========================================="