#!/bin/bash

# Zero-Tolerance Error Detection Test Script
# This script specifically tests the 0% fail rate requirement
# for mortgage servicing violation detection

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_NAME="MortgageGuardian"
SCHEME="MortgageGuardian"
DESTINATION="platform=iOS Simulator,name=iPhone 15 Pro"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_DIR="build/zero-tolerance-results-${TIMESTAMP}"

mkdir -p "${RESULTS_DIR}"

echo -e "${RED}🚨 ZERO-TOLERANCE ERROR DETECTION TEST${NC}"
echo -e "${RED}=====================================${NC}"
echo -e "${YELLOW}Testing 100% detection requirement for known violation patterns${NC}"
echo ""

# Function to test specific violation category
test_violation_category() {
    local category="$1"
    local test_method="$2"
    local description="$3"
    local log_file="${RESULTS_DIR}/${category}.log"

    echo -e "${BLUE}Testing: ${description}${NC}"

    if xcodebuild test \
        -scheme "${SCHEME}" \
        -destination "${DESTINATION}" \
        -only-testing:"${PROJECT_NAME}Tests/ZeroToleranceTests/${test_method}" \
        > "${log_file}" 2>&1; then
        echo -e "${GREEN}✓ ${description} - ALL VIOLATIONS DETECTED${NC}"
        echo "PASSED: ${description}" >> "${RESULTS_DIR}/summary.txt"
        return 0
    else
        echo -e "${RED}✗ ${description} - DETECTION FAILED${NC}"
        echo -e "${RED}  Log: ${log_file}${NC}"
        echo "FAILED: ${description}" >> "${RESULTS_DIR}/summary.txt"
        return 1
    fi
}

# Test all violation categories
echo -e "${YELLOW}1. Payment Processing Violations (6 patterns)${NC}"
test_violation_category "payment" "testPaymentProcessingViolationDetection" "Payment Processing Violations"

echo -e "${YELLOW}2. Interest Calculation Violations (5 patterns)${NC}"
test_violation_category "interest" "testInterestCalculationViolationDetection" "Interest Calculation Violations"

echo -e "${YELLOW}3. Escrow Violations (5 patterns)${NC}"
test_violation_category "escrow" "testEscrowViolationDetection" "Escrow Violations"

echo -e "${YELLOW}4. Fee and Penalty Violations (5 patterns)${NC}"
test_violation_category "fees" "testFeeAndPenaltyViolationDetection" "Fee and Penalty Violations"

echo -e "${YELLOW}5. Regulatory Compliance Violations (8 patterns)${NC}"
test_violation_category "regulatory" "testRegulatoryComplianceViolationDetection" "Regulatory Compliance Violations"

echo -e "${YELLOW}6. Data Integrity Violations (5 patterns)${NC}"
test_violation_category "data" "testDataIntegrityViolationDetection" "Data Integrity Violations"

echo -e "${YELLOW}7. Edge Cases and Complex Scenarios (6 patterns)${NC}"
test_violation_category "edge" "testEdgeCasesAndComplexScenarios" "Edge Cases and Complex Scenarios"

# Calculate results
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}ZERO-TOLERANCE TEST RESULTS${NC}"
echo -e "${BLUE}========================================${NC}"

if [[ -f "${RESULTS_DIR}/summary.txt" ]]; then
    total_tests=$(wc -l < "${RESULTS_DIR}/summary.txt")
    passed_tests=$(grep -c "PASSED" "${RESULTS_DIR}/summary.txt" || echo 0)
    failed_tests=$(grep -c "FAILED" "${RESULTS_DIR}/summary.txt" || echo 0)

    echo "Total Violation Categories: ${total_tests}"
    echo "Passed: ${passed_tests}"
    echo "Failed: ${failed_tests}"

    if [[ $failed_tests -eq 0 ]]; then
        echo -e "${GREEN}🎉 ZERO-TOLERANCE REQUIREMENT MET!${NC}"
        echo -e "${GREEN}✓ 100% detection rate achieved for all known patterns${NC}"
        echo -e "${GREEN}✓ System meets 0% fail rate requirement${NC}"
        exit 0
    else
        echo -e "${RED}🚨 ZERO-TOLERANCE REQUIREMENT FAILED!${NC}"
        echo -e "${RED}✗ ${failed_tests} violation categories not detected${NC}"
        echo -e "${RED}✗ System does not meet 0% fail rate requirement${NC}"
        echo -e "${RED}✗ SYSTEM NOT PRODUCTION READY${NC}"
        exit 1
    fi
else
    echo -e "${RED}No test results found${NC}"
    exit 1
fi