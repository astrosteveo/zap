#!/usr/bin/env zsh
#
# Unit Test: Plugin Specification Parsing
#
# Tests the _zap_parse_plugin_spec() function that extracts components
# from plugin specifications.
#
# WHY: Parsing logic needs to correctly extract owner, repo, version, and
# subdirectory from complex specifications. Edge cases include missing
# components, multiple delimiters, and special characters.
#

# Load the declarative module
source "${0:A:h}/../../../lib/declarative.zsh"

# Test setup
TEST_NAME="Plugin Specification Parsing"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
  ((TESTS_PASSED++))
  echo "  ✓ $1"
}

fail() {
  ((TESTS_FAILED++))
  echo "  ✗ $1"
  [[ -n "$2" ]] && echo "    Expected: $2"
  [[ -n "$3" ]] && echo "    Got: $3"
}

run_test() {
  ((TESTS_RUN++))
  echo "Test: $1"
}

echo "=== $TEST_NAME ==="
echo ""

# TC-PARSE-001: Basic specification
run_test "TC-PARSE-001: Parse basic spec (owner/repo)"
_zap_parse_plugin_spec "zsh-users/zsh-autosuggestions"

if [[ "$ZAP_PARSED_OWNER" == "zsh-users" && \
      "$ZAP_PARSED_REPO" == "zsh-autosuggestions" && \
      "$ZAP_PARSED_NAME" == "zsh-users/zsh-autosuggestions" && \
      -z "$ZAP_PARSED_VERSION" && \
      -z "$ZAP_PARSED_SUBDIR" ]]; then
  pass "Basic spec parsed correctly"
else
  fail "Basic spec parsed correctly" \
       "owner=zsh-users, repo=zsh-autosuggestions" \
       "owner=$ZAP_PARSED_OWNER, repo=$ZAP_PARSED_REPO"
fi

# TC-PARSE-002: Specification with version
run_test "TC-PARSE-002: Parse spec with version"
_zap_parse_plugin_spec "zsh-users/zsh-syntax-highlighting@v0.7.0"

if [[ "$ZAP_PARSED_OWNER" == "zsh-users" && \
      "$ZAP_PARSED_REPO" == "zsh-syntax-highlighting" && \
      "$ZAP_PARSED_VERSION" == "v0.7.0" && \
      -z "$ZAP_PARSED_SUBDIR" ]]; then
  pass "Spec with version parsed correctly"
else
  fail "Spec with version parsed correctly" \
       "version=v0.7.0" \
       "version=$ZAP_PARSED_VERSION"
fi

# TC-PARSE-003: Specification with subdirectory
run_test "TC-PARSE-003: Parse spec with subdir"
_zap_parse_plugin_spec "ohmyzsh/ohmyzsh:plugins/git"

if [[ "$ZAP_PARSED_OWNER" == "ohmyzsh" && \
      "$ZAP_PARSED_REPO" == "ohmyzsh" && \
      "$ZAP_PARSED_SUBDIR" == "plugins/git" && \
      -z "$ZAP_PARSED_VERSION" ]]; then
  pass "Spec with subdir parsed correctly"
else
  fail "Spec with subdir parsed correctly" \
       "subdir=plugins/git" \
       "subdir=$ZAP_PARSED_SUBDIR"
fi

# TC-PARSE-004: Full specification
run_test "TC-PARSE-004: Parse full spec (owner/repo@version:subdir)"
_zap_parse_plugin_spec "ohmyzsh/ohmyzsh@master:plugins/git"

if [[ "$ZAP_PARSED_OWNER" == "ohmyzsh" && \
      "$ZAP_PARSED_REPO" == "ohmyzsh" && \
      "$ZAP_PARSED_VERSION" == "master" && \
      "$ZAP_PARSED_SUBDIR" == "plugins/git" ]]; then
  pass "Full spec parsed correctly"
else
  fail "Full spec parsed correctly" \
       "owner=ohmyzsh, repo=ohmyzsh, version=master, subdir=plugins/git" \
       "owner=$ZAP_PARSED_OWNER, repo=$ZAP_PARSED_REPO, version=$ZAP_PARSED_VERSION, subdir=$ZAP_PARSED_SUBDIR"
fi

# TC-PARSE-005: Commit hash version
run_test "TC-PARSE-005: Parse commit hash version"
_zap_parse_plugin_spec "romkatv/powerlevel10k@a0b56da123"

if [[ "$ZAP_PARSED_VERSION" == "a0b56da123" ]]; then
  pass "Commit hash parsed correctly"
else
  fail "Commit hash parsed correctly" \
       "a0b56da123" \
       "$ZAP_PARSED_VERSION"
fi

# TC-PARSE-006: Nested subdirectory
run_test "TC-PARSE-006: Parse nested subdir"
_zap_parse_plugin_spec "owner/repo:path/to/plugin"

if [[ "$ZAP_PARSED_SUBDIR" == "path/to/plugin" ]]; then
  pass "Nested subdir parsed correctly"
else
  fail "Nested subdir parsed correctly" \
       "path/to/plugin" \
       "$ZAP_PARSED_SUBDIR"
fi

# TC-PARSE-007: Dots in repo name
run_test "TC-PARSE-007: Parse repo with dots"
_zap_parse_plugin_spec "owner/repo.name"

if [[ "$ZAP_PARSED_REPO" == "repo.name" ]]; then
  pass "Repo with dots parsed correctly"
else
  fail "Repo with dots parsed correctly" \
       "repo.name" \
       "$ZAP_PARSED_REPO"
fi

# TC-PARSE-008: Hyphens and underscores
run_test "TC-PARSE-008: Parse hyphens and underscores"
_zap_parse_plugin_spec "my-org_name/my-repo_name"

if [[ "$ZAP_PARSED_OWNER" == "my-org_name" && \
      "$ZAP_PARSED_REPO" == "my-repo_name" ]]; then
  pass "Hyphens and underscores parsed correctly"
else
  fail "Hyphens and underscores parsed correctly" \
       "owner=my-org_name, repo=my-repo_name" \
       "owner=$ZAP_PARSED_OWNER, repo=$ZAP_PARSED_REPO"
fi

# TC-PARSE-009: Invalid spec fails gracefully
run_test "TC-PARSE-009: Invalid spec returns error"
if ! _zap_parse_plugin_spec "../evil/repo" 2>/dev/null; then
  pass "Invalid spec rejected"
else
  fail "Invalid spec rejected" \
       "return 1" \
       "return 0"
fi

# TC-PARSE-010: Variables are cleared between parses
run_test "TC-PARSE-010: Variables cleared between parses"
_zap_parse_plugin_spec "owner1/repo1@v1:subdir1"
_zap_parse_plugin_spec "owner2/repo2"

if [[ "$ZAP_PARSED_OWNER" == "owner2" && \
      "$ZAP_PARSED_REPO" == "repo2" && \
      -z "$ZAP_PARSED_VERSION" && \
      -z "$ZAP_PARSED_SUBDIR" ]]; then
  pass "Variables cleared between parses"
else
  fail "Variables cleared between parses" \
       "version and subdir should be empty" \
       "version=$ZAP_PARSED_VERSION, subdir=$ZAP_PARSED_SUBDIR"
fi

# Results
echo ""
echo "=== Results ==="
echo "Tests run: $TESTS_RUN"
echo "Passed: $TESTS_PASSED"
echo "Failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo "Status: ✓ ALL TESTS PASSED"
  exit 0
else
  echo "Status: ✗ SOME TESTS FAILED"
  exit 1
fi
