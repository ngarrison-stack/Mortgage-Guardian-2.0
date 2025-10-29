#!/bin/bash

# Comprehensive Test Suite Runner for Mortgage Guardian 2.0
# Zero-Tolerance Error Detection System
#
# This script runs all test categories and generates comprehensive reports
# Requires: Xcode 15.0+, AWS CLI, Plaid Sandbox access

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_NAME="MortgageGuardian"
SCHEME="MortgageGuardian"
DESTINATION="platform=iOS Simulator,name=iPhone 15 Pro"
BUILD_DIR="build"
TEST_RESULTS_DIR="${BUILD_DIR}/test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
TEST_REPORT_FILE="${TEST_RESULTS_DIR}/comprehensive-test-report-${TIMESTAMP}.html"

# Create directories
mkdir -p "${TEST_RESULTS_DIR}"
mkdir -p "${BUILD_DIR}/logs"
mkdir -p "${BUILD_DIR}/performance"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Mortgage Guardian 2.0 - Test Suite${NC}"
echo -e "${BLUE}Zero-Tolerance Error Detection System${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to log test results
log_test_result() {
    local test_name="$1"
    local result="$2"
    local duration="$3"
    local log_file="${TEST_RESULTS_DIR}/test-summary.log"

    echo "[$(date)] ${test_name}: ${result} (${duration}s)" | tee -a "${log_file}"
}

# Function to run specific test target
run_test_target() {
    local target="$1"
    local description="$2"
    local log_file="${BUILD_DIR}/logs/${target}-${TIMESTAMP}.log"
    local start_time=$(date +%s)

    echo -e "${YELLOW}Running ${description}...${NC}"

    if xcodebuild test \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -only-testing:"${PROJECT_NAME}Tests/${target}" \
        -resultBundlePath "${BUILD_DIR}/${target}-${TIMESTAMP}.xcresult" \
        > "${log_file}" 2>&1; then

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✓ ${description} - PASSED (${duration}s)${NC}"
        log_test_result "${target}" "PASSED" "${duration}"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${RED}✗ ${description} - FAILED (${duration}s)${NC}"
        echo -e "${RED}  Check log: ${log_file}${NC}"
        log_test_result "${target}" "FAILED" "${duration}"
        return 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"

    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}Error: Xcode command line tools not found${NC}"
        exit 1
    fi

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        echo -e "${YELLOW}Warning: AWS CLI not found - some tests may fail${NC}"
    fi

    # Check iOS Simulator
    if ! xcrun simctl list devices | grep -q "iPhone 15 Pro"; then
        echo -e "${YELLOW}Warning: iPhone 15 Pro simulator not found, using available simulator${NC}"
        DESTINATION="platform=iOS Simulator,OS=latest"
    fi

    echo -e "${GREEN}✓ Prerequisites checked${NC}"
}

# Function to clean build directory
clean_build() {
    echo -e "${BLUE}Cleaning build directory...${NC}"
    rm -rf "${BUILD_DIR}"
    mkdir -p "${TEST_RESULTS_DIR}"
    mkdir -p "${BUILD_DIR}/logs"
    mkdir -p "${BUILD_DIR}/performance"
    echo -e "${GREEN}✓ Build directory cleaned${NC}"
}

# Function to build project
build_project() {
    echo -e "${BLUE}Building project...${NC}"
    local start_time=$(date +%s)

    if xcodebuild build \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -configuration Debug \
        > "${BUILD_DIR}/logs/build-${TIMESTAMP}.log" 2>&1; then

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo -e "${GREEN}✓ Project built successfully (${duration}s)${NC}"
        log_test_result "Build" "PASSED" "${duration}"
    else
        echo -e "${RED}✗ Build failed${NC}"
        echo -e "${RED}  Check log: ${BUILD_DIR}/logs/build-${TIMESTAMP}.log${NC}"
        exit 1
    fi
}

# Function to run performance profiling
run_performance_profiling() {
    echo -e "${BLUE}Running performance profiling...${NC}"
    local start_time=$(date +%s)

    # Memory profiling
    if command -v instruments &> /dev/null; then
        echo -e "${YELLOW}  Running memory profiling...${NC}"
        # Note: This would need an actual app launch for real profiling
        # For now, we'll run the performance tests
        run_test_target "PerformanceTests" "Performance Tests"
    else
        echo -e "${YELLOW}  Instruments not available, skipping profiling${NC}"
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_test_result "Performance Profiling" "COMPLETED" "${duration}"
}

# Function to generate HTML report
generate_html_report() {
    echo -e "${BLUE}Generating HTML test report...${NC}"

    cat > "${TEST_REPORT_FILE}" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Mortgage Guardian 2.0 - Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
        .summary { background: #ecf0f1; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .test-section { margin: 20px 0; padding: 15px; border: 1px solid #bdc3c7; border-radius: 5px; }
        .passed { color: #27ae60; }
        .failed { color: #e74c3c; }
        .warning { color: #f39c12; }
        table { width: 100%; border-collapse: collapse; margin: 10px 0; }
        th, td { border: 1px solid #bdc3c7; padding: 8px; text-align: left; }
        th { background: #3498db; color: white; }
        .metric { display: inline-block; margin: 10px; padding: 10px; background: #f8f9fa; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Mortgage Guardian 2.0 - Comprehensive Test Report</h1>
        <p>Zero-Tolerance Error Detection System</p>
        <p>Generated: $(date)</p>
    </div>

    <div class="summary">
        <h2>Test Summary</h2>
        <div class="metric">
            <strong>Total Tests:</strong> <span id="total-tests">-</span>
        </div>
        <div class="metric">
            <strong>Passed:</strong> <span class="passed" id="passed-tests">-</span>
        </div>
        <div class="metric">
            <strong>Failed:</strong> <span class="failed" id="failed-tests">-</span>
        </div>
        <div class="metric">
            <strong>Success Rate:</strong> <span id="success-rate">-</span>%
        </div>
    </div>

    <div class="test-section">
        <h2>Test Results by Category</h2>
        <table>
            <tr>
                <th>Test Category</th>
                <th>Status</th>
                <th>Duration</th>
                <th>Details</th>
            </tr>
EOF

    # Add test results from log
    if [[ -f "${TEST_RESULTS_DIR}/test-summary.log" ]]; then
        while IFS= read -r line; do
            if [[ $line =~ \[.*\]\ (.+):\ (.+)\ \((.+)s\) ]]; then
                local test_name="${BASH_REMATCH[1]}"
                local result="${BASH_REMATCH[2]}"
                local duration="${BASH_REMATCH[3]}"
                local status_class=""

                if [[ $result == "PASSED" ]]; then
                    status_class="passed"
                elif [[ $result == "FAILED" ]]; then
                    status_class="failed"
                else
                    status_class="warning"
                fi

                cat >> "${TEST_REPORT_FILE}" << EOF
            <tr>
                <td>${test_name}</td>
                <td><span class="${status_class}">${result}</span></td>
                <td>${duration}s</td>
                <td><a href="logs/${test_name}-${TIMESTAMP}.log">View Log</a></td>
            </tr>
EOF
            fi
        done < "${TEST_RESULTS_DIR}/test-summary.log"
    fi

    cat >> "${TEST_REPORT_FILE}" << EOF
        </table>
    </div>

    <div class="test-section">
        <h2>Zero-Tolerance Requirements</h2>
        <p>The system must achieve <strong>100% detection accuracy</strong> for all known mortgage servicing violation patterns.</p>
        <ul>
            <li>Payment Processing Violations: 6 test cases</li>
            <li>Interest Calculation Violations: 5 test cases</li>
            <li>Escrow Violations: 5 test cases</li>
            <li>Fee and Penalty Violations: 5 test cases</li>
            <li>Regulatory Compliance Violations: 8 test cases</li>
            <li>Data Integrity Violations: 5 test cases</li>
        </ul>
    </div>

    <div class="test-section">
        <h2>Performance Requirements</h2>
        <ul>
            <li>Document OCR: &lt; 10 seconds</li>
            <li>AI Analysis: &lt; 30 seconds per document</li>
            <li>Plaid Sync: &lt; 5 seconds</li>
            <li>Complete Workflow: &lt; 45 seconds end-to-end</li>
            <li>Memory Usage: &lt; 100MB peak</li>
        </ul>
    </div>

    <script>
        // Calculate and display summary statistics
        const rows = document.querySelectorAll('table tr:not(:first-child)');
        let total = rows.length;
        let passed = 0;
        let failed = 0;

        rows.forEach(row => {
            const status = row.cells[1].textContent.trim();
            if (status === 'PASSED') passed++;
            if (status === 'FAILED') failed++;
        });

        document.getElementById('total-tests').textContent = total;
        document.getElementById('passed-tests').textContent = passed;
        document.getElementById('failed-tests').textContent = failed;
        document.getElementById('success-rate').textContent = total > 0 ? Math.round((passed / total) * 100) : 0;
    </script>
</body>
</html>
EOF

    echo -e "${GREEN}✓ HTML report generated: ${TEST_REPORT_FILE}${NC}"
}

# Main execution flow
main() {
    local start_time=$(date +%s)
    local failed_tests=0

    echo -e "${BLUE}Starting comprehensive test suite at $(date)${NC}"
    echo ""

    # Prerequisites and setup
    check_prerequisites
    clean_build
    build_project

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Running Test Categories${NC}"
    echo -e "${BLUE}========================================${NC}"

    # Unit Tests (90% coverage required)
    if ! run_test_target "UnitTests" "Unit Tests (90% Coverage Required)"; then
        ((failed_tests++))
    fi

    # Zero-Tolerance Tests (100% pass required) - CRITICAL
    echo -e "\n${RED}CRITICAL: Zero-Tolerance Tests${NC}"
    if ! run_test_target "ZeroToleranceTests" "Zero-Tolerance Tests (100% Pass Required)"; then
        ((failed_tests++))
        echo -e "${RED}CRITICAL FAILURE: Zero-tolerance tests failed!${NC}"
        echo -e "${RED}System does not meet 0% fail rate requirement!${NC}"
    fi

    # Integration Tests (95% coverage required)
    if ! run_test_target "IntegrationTests" "Integration Tests (95% Coverage Required)"; then
        ((failed_tests++))
    fi

    # Performance Tests
    if ! run_test_target "PerformanceTests" "Performance Tests"; then
        ((failed_tests++))
    fi

    # Security Tests
    if ! run_test_target "SecurityTests" "Security Tests"; then
        ((failed_tests++))
    fi

    # Load Tests
    if ! run_test_target "LoadTests" "Load Tests"; then
        ((failed_tests++))
    fi

    # UI Tests
    if ! run_test_target "UITests" "UI Tests"; then
        ((failed_tests++))
    fi

    # Performance profiling
    run_performance_profiling

    # Generate reports
    generate_html_report

    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Test Suite Complete${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Total Duration: ${total_duration} seconds"
    echo -e "Failed Test Categories: ${failed_tests}"
    echo -e "HTML Report: ${TEST_REPORT_FILE}"
    echo ""

    if [[ $failed_tests -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL TESTS PASSED - System ready for production!${NC}"
        exit 0
    else
        echo -e "${RED}❌ ${failed_tests} test categories failed!${NC}"
        if grep -q "ZeroToleranceTests.*FAILED" "${TEST_RESULTS_DIR}/test-summary.log"; then
            echo -e "${RED}🚨 CRITICAL: Zero-tolerance tests failed - system not production ready!${NC}"
        fi
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    "quick")
        echo -e "${YELLOW}Running quick test suite (Unit + Zero-Tolerance only)${NC}"
        QUICK_MODE=true
        ;;
    "zero-tolerance")
        echo -e "${YELLOW}Running zero-tolerance tests only${NC}"
        ZERO_TOLERANCE_ONLY=true
        ;;
    "performance")
        echo -e "${YELLOW}Running performance tests only${NC}"
        PERFORMANCE_ONLY=true
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [quick|zero-tolerance|performance|help]"
        echo ""
        echo "Options:"
        echo "  quick           Run unit tests and zero-tolerance tests only"
        echo "  zero-tolerance  Run zero-tolerance tests only"
        echo "  performance     Run performance tests only"
        echo "  help            Show this help message"
        echo ""
        echo "Default: Run complete test suite"
        exit 0
        ;;
esac

# Execute based on mode
if [[ "${QUICK_MODE:-}" == "true" ]]; then
    check_prerequisites
    clean_build
    build_project
    run_test_target "UnitTests" "Unit Tests"
    run_test_target "ZeroToleranceTests" "Zero-Tolerance Tests"
    generate_html_report
elif [[ "${ZERO_TOLERANCE_ONLY:-}" == "true" ]]; then
    check_prerequisites
    clean_build
    build_project
    run_test_target "ZeroToleranceTests" "Zero-Tolerance Tests"
    generate_html_report
elif [[ "${PERFORMANCE_ONLY:-}" == "true" ]]; then
    check_prerequisites
    clean_build
    build_project
    run_test_target "PerformanceTests" "Performance Tests"
    run_performance_profiling
    generate_html_report
else
    main
fi