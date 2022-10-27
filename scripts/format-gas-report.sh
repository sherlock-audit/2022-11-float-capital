#!/bin/bash
set -e # Exit with nonzero exit code if anything fails

TEST_REPORT_OUTPUT=$(forge snapshot --gas-report)

echo "$TEST_REPORT_OUTPUT"

testSummaryStartLine=$(echo "$TEST_REPORT_OUTPUT" | awk '/╭──/{ print NR; exit }')

gasReportOnly=$(echo "$TEST_REPORT_OUTPUT" | tail -n +$testSummaryStartLine);

echo "$gasReportOnly" > .gas-report-functions.txt

