#!/bin/bash
# Unit Tests for APA 7th Edition LaTeX Template Compilation Pipeline

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
TEST_DIR="$SCRIPT_DIR/tests"
mkdir -p "$TEST_DIR"

# Source the compilation script functions without running main
source "$SCRIPT_DIR/compile.sh"

# Color formatting for test outputs
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0;0m'

FAILED_TESTS=0
TOTAL_TESTS=0

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$expected" = "$actual" ]; then
        echo -e "  [${GREEN}PASS${NC}] $message"
    else
        echo -e "  [${RED}FAIL${NC}] $message"
        echo "         Expected: '$expected'"
        echo "         Actual:   '$actual'"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

echo "=================================================="
echo "Running Unit Tests for compile.sh"
echo "=================================================="

# Test Case 1: get_biber_version mappings
echo "Test Case 1: get_biber_version mapping..."
assert_equals "2.17" "$(get_biber_version '3.8')" "Version 3.8 maps to Biber 2.17"
assert_equals "2.18" "$(get_biber_version '3.9')" "Version 3.9 maps to Biber 2.18"
assert_equals "2.19" "$(get_biber_version '3.10')" "Version 3.10 maps to Biber 2.19"
assert_equals "2.21" "$(get_biber_version '3.11')" "Version 3.11 maps to Biber 2.21"
assert_equals "2.17" "$(get_biber_version 'unknown')" "Unknown version falls back to Biber 2.17"

# Test Case 2: Parsing .bcf version regex
echo "Test Case 2: Parsing .bcf controlfile version..."
# Create a temporary mock main.bcf file
MOCK_BCF="$TEST_DIR/mock_main.bcf"
cat << 'EOF' > "$MOCK_BCF"
<?xml version="1.0" encoding="utf-8"?>
<bcf:controlfile version="3.11" xmlns:bcf="https://github.com/plk/biblatex/controlfile">
  <bcf:options>
  </bcf:options>
</bcf:controlfile>
EOF

PARSED_BCF_VER=$(grep -Eo 'controlfile version="[0-9]+\.[0-9]+"' "$MOCK_BCF" | grep -Eo '[0-9]+\.[0-9]+' | head -n 1)
assert_equals "3.11" "$PARSED_BCF_VER" "Regex successfully extracts 3.11 version from mock .bcf file"
rm -f "$MOCK_BCF"

# Test Case 3: Mapping Bcf version to Biber version from Mock BCF
echo "Test Case 3: Resolving Biber version from Mock BCF..."
MOCK_BCF="$TEST_DIR/mock_main.bcf"
cat << 'EOF' > "$MOCK_BCF"
<?xml version="1.0" encoding="utf-8"?>
<bcf:controlfile version="3.10" xmlns:bcf="https://github.com/plk/biblatex/controlfile">
</bcf:controlfile>
EOF

PARSED_BCF_VER=$(grep -Eo 'controlfile version="[0-9]+\.[0-9]+"' "$MOCK_BCF" | grep -Eo '[0-9]+\.[0-9]+' | head -n 1)
RESOLVED_BIBER_VER=$(get_biber_version "$PARSED_BCF_VER")
assert_equals "2.19" "$RESOLVED_BIBER_VER" "Correctly resolves Biber 2.19 for BCF version 3.10"
rm -f "$MOCK_BCF"

# Test Case 4: Verify caching dir is created
echo "Test Case 4: Directory structure check..."
assert_equals "true" "$([ -d "$SCRIPT_DIR/.bin" ] && echo "true" || echo "false")" ".bin/ local caching directory exists"

# Test Case 5: Clean Cache logic
echo "Test Case 5: Testing clean_cache function..."
MOCK_PROJECT="$TEST_DIR/mock_project"
mkdir -p "$MOCK_PROJECT/.bin"
touch "$MOCK_PROJECT/.bin/biber"
touch "$MOCK_PROJECT/main.aux"
touch "$MOCK_PROJECT/main.bcf"

# Backup original variables
ORIG_SCRIPT_DIR="$SCRIPT_DIR"
ORIG_BIN_DIR="$BIN_DIR"

# Rebind for mock execution
SCRIPT_DIR="$MOCK_PROJECT"
BIN_DIR="$MOCK_PROJECT/.bin"

# Execute cleanup function
clean_cache >/dev/null 2>&1

# Assert cleanup outcomes
assert_equals "false" "$([ -d "$MOCK_PROJECT/.bin" ] && echo "true" || echo "false")" "Mock .bin directory is removed"
assert_equals "false" "$([ -f "$MOCK_PROJECT/main.aux" ] && echo "true" || echo "false")" "Mock main.aux file is removed"
assert_equals "false" "$([ -f "$MOCK_PROJECT/main.bcf" ] && echo "true" || echo "false")" "Mock main.bcf file is removed"

# Restore variables & clean mock dir
SCRIPT_DIR="$ORIG_SCRIPT_DIR"
BIN_DIR="$ORIG_BIN_DIR"
rm -rf "$MOCK_PROJECT"

echo "=================================================="
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}ALL $TOTAL_TESTS TESTS PASSED SUCCESSFULLY!${NC}"
    exit 0
else
    echo -e "${RED}$FAILED_TESTS OUT OF $TOTAL_TESTS TESTS FAILED.${NC}"
    exit 1
fi
