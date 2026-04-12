#!/bin/bash
# Get the directory of the current script and navigate to project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

echo "Running Backend Tests..."
(cd api && npm test)
BACKEND_EXIT=$?

echo "-------------------------"
echo "Running Frontend Tests..."
flutter test
FRONTEND_EXIT=$?

echo "-------------------------"
if [ $BACKEND_EXIT -eq 0 ] && [ $FRONTEND_EXIT -eq 0 ]; then
    echo "✅ All tests passed!"
    exit 0
else
    echo "❌ Some tests failed."
    [ $BACKEND_EXIT -ne 0 ] && echo "   - Backend tests failed"
    [ $FRONTEND_EXIT -ne 0 ] && echo "   - Frontend tests failed"
    exit 1
fi
