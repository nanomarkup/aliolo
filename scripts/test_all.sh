#!/bin/bash
# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

echo "====================================="
echo "       RUNNING ALL TEST SUITES       "
echo "====================================="

echo ""
echo "▶ Running Backend Tests (Isolated)..."
./scripts/test_backend.sh
BACKEND_EXIT=$?

echo ""
echo "▶ Running Backend E2E Tests (Production Health)..."
./scripts/test_e2e.sh
BACKEND_E2E_EXIT=$?

echo ""
echo "▶ Running Frontend Tests (Unit & Widget)..."
./scripts/test_frontend.sh
FRONTEND_EXIT=$?

echo ""
echo "▶ Running Frontend Golden Tests..."
./scripts/test_goldens.sh
GOLDENS_EXIT=$?

echo ""
echo "▶ Running Frontend Integration Tests (Patrol)..."
./scripts/test_integration.sh
INTEGRATION_EXIT=$?

echo ""
echo "====================================="
echo "            TEST SUMMARY             "
echo "====================================="

ALL_PASSED=true

if [ $BACKEND_EXIT -ne 0 ]; then
    echo "❌ Backend Isolated Tests: FAILED"
    ALL_PASSED=false
else
    echo "✅ Backend Isolated Tests: PASSED"
fi

if [ $BACKEND_E2E_EXIT -ne 0 ]; then
    echo "❌ Backend E2E Tests: FAILED"
    ALL_PASSED=false
else
    echo "✅ Backend E2E Tests: PASSED (or skipped missing auth)"
fi

if [ $FRONTEND_EXIT -ne 0 ]; then
    echo "❌ Frontend Unit/Widget Tests: FAILED"
    ALL_PASSED=false
else
    echo "✅ Frontend Unit/Widget Tests: PASSED"
fi

if [ $GOLDENS_EXIT -ne 0 ]; then
    echo "❌ Frontend Golden Tests: FAILED"
    ALL_PASSED=false
else
    echo "✅ Frontend Golden Tests: PASSED"
fi

if [ $INTEGRATION_EXIT -ne 0 ]; then
    echo "❌ Frontend Integration Tests (Patrol): FAILED"
    ALL_PASSED=false
else
    echo "✅ Frontend Integration Tests (Patrol): PASSED"
fi

echo "====================================="
if [ "$ALL_PASSED" = true ]; then
    echo "🎉 ALL TESTS PASSED SUCCESSFULLY! 🎉"
    exit 0
else
    echo "🚨 SOME TESTS FAILED. PLEASE CHECK THE LOGS ABOVE. 🚨"
    exit 1
fi
