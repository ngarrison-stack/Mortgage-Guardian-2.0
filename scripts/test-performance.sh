#!/bin/bash

# Performance Testing Script for Mortgage Guardian 2.0
# Tests processing time requirements and memory usage

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_NAME="MortgageGuardian"
SCHEME="MortgageGuardian"
DESTINATION="platform=iOS Simulator,name=iPhone 15 Pro"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="build/performance-results-${TIMESTAMP}"

mkdir -p "${RESULTS_DIR}"

echo -e "${BLUE}⚡ PERFORMANCE TESTING SUITE${NC}"
echo -e "${BLUE}============================${NC}"
echo ""

# Performance requirements
echo -e "${YELLOW}Performance Requirements:${NC}"
echo "• Document OCR: < 10 seconds"
echo "• AI Analysis: < 30 seconds per document"
echo "• Plaid Sync: < 5 seconds"
echo "• Complete Workflow: < 45 seconds end-to-end"
echo "• Memory Usage: < 100MB peak"
echo ""

# Function to run performance test
run_performance_test() {
    local test_name="$1"
    local test_method="$2"
    local max_time="$3"
    local description="$4"
    local log_file="${RESULTS_DIR}/${test_name}.log"

    echo -e "${BLUE}Testing: ${description}${NC}"
    echo -e "${YELLOW}  Max allowed time: ${max_time} seconds${NC}"

    local start_time=$(date +%s)

    if xcodebuild test \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -only-testing:"${PROJECT_NAME}Tests/PerformanceTests/${test_method}" \
        > "${log_file}" 2>&1; then

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        if [[ $duration -le $max_time ]]; then
            echo -e "${GREEN}✓ ${description} - PASSED (${duration}s / ${max_time}s max)${NC}"
            echo "PASSED: ${description} (${duration}s)" >> "${RESULTS_DIR}/performance-summary.txt"
            return 0
        else
            echo -e "${RED}✗ ${description} - TOO SLOW (${duration}s / ${max_time}s max)${NC}"
            echo "FAILED: ${description} (${duration}s > ${max_time}s)" >> "${RESULTS_DIR}/performance-summary.txt"
            return 1
        fi
    else
        echo -e "${RED}✗ ${description} - TEST FAILED${NC}"
        echo "FAILED: ${description} (test error)" >> "${RESULTS_DIR}/performance-summary.txt"
        return 1
    fi
}

# Function to test memory usage
test_memory_usage() {
    echo -e "${BLUE}Testing Memory Usage${NC}"

    # Run memory test
    if xcodebuild test \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -only-testing:"${PROJECT_NAME}Tests/PerformanceTests/testMemoryUsageAndCleanup" \
        > "${RESULTS_DIR}/memory.log" 2>&1; then
        echo -e "${GREEN}✓ Memory Usage Test - PASSED${NC}"
        echo "PASSED: Memory Usage Test" >> "${RESULTS_DIR}/performance-summary.txt"
    else
        echo -e "${RED}✗ Memory Usage Test - FAILED${NC}"
        echo "FAILED: Memory Usage Test" >> "${RESULTS_DIR}/performance-summary.txt"
    fi
}

# Function to test concurrent processing
test_concurrent_processing() {
    echo -e "${BLUE}Testing Concurrent Processing${NC}"

    if xcodebuild test \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -only-testing:"${PROJECT_NAME}Tests/PerformanceTests/testConcurrentProcessing" \
        > "${RESULTS_DIR}/concurrent.log" 2>&1; then
        echo -e "${GREEN}✓ Concurrent Processing Test - PASSED${NC}"
        echo "PASSED: Concurrent Processing Test" >> "${RESULTS_DIR}/performance-summary.txt"
    else
        echo -e "${RED}✗ Concurrent Processing Test - FAILED${NC}"
        echo "FAILED: Concurrent Processing Test" >> "${RESULTS_DIR}/performance-summary.txt"
    fi
}

# Function to run load tests
run_load_tests() {
    echo -e "${BLUE}Running Load Tests${NC}"

    if xcodebuild test \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -only-testing:"${PROJECT_NAME}Tests/PerformanceTests/testPerformanceUnderLoad" \
        > "${RESULTS_DIR}/load.log" 2>&1; then
        echo -e "${GREEN}✓ Load Test - PASSED${NC}"
        echo "PASSED: Load Test" >> "${RESULTS_DIR}/performance-summary.txt"
    else
        echo -e "${RED}✗ Load Test - FAILED${NC}"
        echo "FAILED: Load Test" >> "${RESULTS_DIR}/performance-summary.txt"
    fi
}

# Run all performance tests
echo -e "${YELLOW}1. Document OCR Performance${NC}"
run_performance_test "ocr" "testDocumentOCRPerformance" 10 "Document OCR Processing"

echo -e "${YELLOW}2. AI Analysis Performance${NC}"
run_performance_test "ai" "testAIAnalysisPerformance" 30 "AI Analysis Processing"

echo -e "${YELLOW}3. Plaid Sync Performance${NC}"
run_performance_test "plaid" "testPlaidSyncPerformance" 5 "Plaid Bank Data Sync"

echo -e "${YELLOW}4. End-to-End Workflow Performance${NC}"
run_performance_test "workflow" "testEndToEndWorkflowPerformance" 45 "Complete Workflow Processing"

echo -e "${YELLOW}5. Memory Usage Testing${NC}"
test_memory_usage

echo -e "${YELLOW}6. Concurrent Processing Testing${NC}"
test_concurrent_processing

echo -e "${YELLOW}7. Load Testing${NC}"
run_load_tests

# Generate performance report
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}PERFORMANCE TEST RESULTS${NC}"
echo -e "${BLUE}========================================${NC}"

if [[ -f "${RESULTS_DIR}/performance-summary.txt" ]]; then
    total_tests=$(wc -l < "${RESULTS_DIR}/performance-summary.txt")
    passed_tests=$(grep -c "PASSED" "${RESULTS_DIR}/performance-summary.txt" || echo 0)
    failed_tests=$(grep -c "FAILED" "${RESULTS_DIR}/performance-summary.txt" || echo 0)

    echo "Total Performance Tests: ${total_tests}"
    echo "Passed: ${passed_tests}"
    echo "Failed: ${failed_tests}"
    echo ""

    # Show detailed results
    echo -e "${BLUE}Detailed Results:${NC}"
    while IFS= read -r line; do
        if [[ $line == PASSED:* ]]; then
            echo -e "${GREEN}✓ ${line#PASSED: }${NC}"
        elif [[ $line == FAILED:* ]]; then
            echo -e "${RED}✗ ${line#FAILED: }${NC}"
        fi
    done < "${RESULTS_DIR}/performance-summary.txt"

    echo ""
    if [[ $failed_tests -eq 0 ]]; then
        echo -e "${GREEN}🎉 ALL PERFORMANCE REQUIREMENTS MET!${NC}"
        echo -e "${GREEN}✓ System meets all processing time requirements${NC}"
        echo -e "${GREEN}✓ Memory usage within acceptable limits${NC}"
        echo -e "${GREEN}✓ System ready for production load${NC}"
        exit 0
    else
        echo -e "${RED}🚨 PERFORMANCE REQUIREMENTS NOT MET!${NC}"
        echo -e "${RED}✗ ${failed_tests} performance tests failed${NC}"
        echo -e "${RED}✗ System optimization required before production${NC}"
        exit 1
    fi
else
    echo -e "${RED}No performance test results found${NC}"
    exit 1
fi