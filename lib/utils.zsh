#!/usr/bin/env zsh
#
# utils.zsh - Common utility functions for Zap
#
# WHY: Centralized utility functions ensure consistent behavior across modules
# and reduce code duplication (per constitution principle I)

# Environment variables
: ${ZAP_DIR:="${HOME}/.zap"}
: ${ZAP_DATA_DIR:="${XDG_DATA_HOME:-$HOME/.local/share}/zap"}
: ${ZAP_PLUGIN_DIR:="$ZAP_DATA_DIR/plugins"}
: ${ZAP_ERROR_LOG:="$ZAP_DATA_DIR/errors.log"}

#
# Profiling support (T060)
#
# Enable profiling with: ZAP_PROFILE=1
# Output format: [PROFILE] operation_name: X.XXXs
#
# WHY: Performance debugging requires visibility into bottlenecks (User Story 5)
#
typeset -gA ZAP_PROFILE_TIMES

#
# _zap_profile_start - Start timing an operation
#
# Purpose: Record start time for profiling
# Parameters:
#   $1 - Operation name
# Returns: 0 always
# Side Effects: Sets ZAP_PROFILE_TIMES[$1]
#
_zap_profile_start() {
  [[ -z "${ZAP_PROFILE:-}" ]] && return 0

  local operation="$1"
  # Use EPOCHREALTIME for microsecond precision (Zsh 5.0+)
  ZAP_PROFILE_TIMES[$operation]="$EPOCHREALTIME"
  return 0
}

#
# _zap_profile_end - End timing and report duration
#
# Purpose: Calculate and report operation duration
# Parameters:
#   $1 - Operation name
# Returns: 0 always
# Output: Profiling line to stderr if ZAP_PROFILE set
#
_zap_profile_end() {
  [[ -z "${ZAP_PROFILE:-}" ]] && return 0

  local operation="$1"
  local start_time="${ZAP_PROFILE_TIMES[$operation]:-0}"

  if [[ "$start_time" != "0" ]]; then
    local end_time="$EPOCHREALTIME"
    local duration=$(printf "%.3f" $(($end_time - $start_time)))
    echo "[PROFILE] $operation: ${duration}s" >&2
  fi

  return 0
}

#
# _zap_log_error - Log error messages to error log file
#
# Purpose: Record plugin failures with timestamp, level, and resolution steps
# Parameters:
#   $1 - Log level (ERROR|WARN|INFO)
#   $2 - Plugin identifier (owner/repo)
#   $3 - Error reason
#   $4 - Resolution steps (optional)
# Returns: 0 always (logging should never fail the operation)
#
# WHY: Persistent error logging enables debugging without blocking shell startup
# (per FR-028)
#
_zap_log_error() {
  local level="$1"
  local plugin="$2"
  local reason="$3"
  local resolution="${4:-See zap doctor for diagnostics}"

  # Ensure log directory exists
  mkdir -p "$(dirname "$ZAP_ERROR_LOG")" 2>/dev/null

  # ISO 8601 timestamp
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date +"%Y-%m-%d %H:%M:%S")

  # Append to log file (atomic write per FR-035)
  {
    echo "[$timestamp] $level: $plugin"
    echo "  Reason: $reason"
    echo "  Action: $resolution"
    echo ""
  } >> "$ZAP_ERROR_LOG" 2>/dev/null

  # Rotate log if > 100 entries (FR-028)
  # WHY: Prevent unbounded log growth while keeping recent errors accessible
  if [[ -f "$ZAP_ERROR_LOG" ]]; then
    local entry_count=$(grep -c "^\[" "$ZAP_ERROR_LOG" 2>/dev/null || echo 0)
    if (( entry_count > 100 )); then
      tail -n 400 "$ZAP_ERROR_LOG" > "${ZAP_ERROR_LOG}.tmp" 2>/dev/null
      mv "${ZAP_ERROR_LOG}.tmp" "$ZAP_ERROR_LOG" 2>/dev/null
    fi
  fi

  return 0
}

#
# _zap_sanitize_repo_name - Validate and sanitize repository names
#
# Purpose: Prevent path traversal and invalid characters in repo specifications
# Parameters:
#   $1 - Repository name (owner/repo format)
# Returns: 0 if valid, 1 if invalid
# Output: Sanitized repo name on stdout if valid
#
# WHY: Security requirement to prevent malicious repository names (FR-027)
#
_zap_sanitize_repo_name() {
  local repo="$1"

  # Must contain exactly one slash
  if [[ ! "$repo" =~ ^[a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+$ ]]; then
    return 1
  fi

  # No path traversal attempts
  if [[ "$repo" == *".."* ]]; then
    return 1
  fi

  echo "$repo"
  return 0
}

#
# _zap_sanitize_version - Validate version strings as valid Git refs
#
# Purpose: Ensure version pins are valid Git references
# Parameters:
#   $1 - Version string (tag, commit, or branch name)
# Returns: 0 if valid, 1 if invalid
# Output: Sanitized version on stdout if valid
#
# WHY: Prevent command injection via malicious version strings (FR-027)
#
_zap_sanitize_version() {
  local version="$1"

  # Empty version is valid (means latest)
  [[ -z "$version" ]] && return 0

  # Basic validation: alphanumeric, dots, dashes, slashes (for branches like feat/new)
  if [[ ! "$version" =~ ^[a-zA-Z0-9._/-]+$ ]]; then
    return 1
  fi

  # No shell metacharacters or path traversal
  if [[ "$version" == *";"* || "$version" == *"|"* || "$version" == *"&"* || "$version" == *".."* ]]; then
    return 1
  fi

  echo "$version"
  return 0
}

#
# _zap_sanitize_path - Validate subdirectory paths
#
# Purpose: Ensure path annotations are safe relative paths
# Parameters:
#   $1 - Subdirectory path
# Returns: 0 if valid, 1 if invalid
# Output: Sanitized path on stdout if valid
#
# WHY: Prevent directory traversal attacks via path: annotations (FR-027)
#
_zap_sanitize_path() {
  local subpath="$1"

  # Empty path is valid (means root)
  [[ -z "$subpath" ]] && return 0

  # No absolute paths
  if [[ "$subpath" == /* ]]; then
    return 1
  fi

  # No parent directory traversal
  if [[ "$subpath" == *".."* ]]; then
    return 1
  fi

  # Basic validation: alphanumeric, dashes, underscores, slashes
  if [[ ! "$subpath" =~ ^[a-zA-Z0-9_/-]+$ ]]; then
    return 1
  fi

  echo "$subpath"
  return 0
}

#
# _zap_print_error - Display error message to user
#
# Purpose: Consistent error formatting with actionable messages
# Parameters:
#   $1 - What failed
#   $2 - Why it failed
#   $3 - How to fix (optional)
# Returns: None (display only)
#
# WHY: UX requirement for clear, actionable error messages (FR-013, constitution III)
#
_zap_print_error() {
  local what="$1"
  local why="$2"
  local how="${3:-}"

  # Only print if not in quiet mode
  if [[ -z "${ZAP_QUIET:-}" ]]; then
    echo "⚠ $what: $why" >&2
    [[ -n "$how" ]] && echo "  $how" >&2
  fi
}

#
# _zap_print_success - Display success message to user
#
# Purpose: Consistent success formatting
# Parameters:
#   $1 - Success message
# Returns: None (display only)
#
_zap_print_success() {
  local message="$1"

  # Only print if not in quiet mode
  if [[ -z "${ZAP_QUIET:-}" ]]; then
    echo "✓ $message"
  fi
}

#
# _zap_print_downloading - Display download progress indicator
#
# Purpose: Show user that plugin download is in progress
# Parameters:
#   $1 - Plugin identifier (owner/repo)
# Returns: None (display only)
#
_zap_print_downloading() {
  local plugin="$1"

  # Only print if not in quiet mode
  if [[ -z "${ZAP_QUIET:-}" ]]; then
    echo "⬇ Downloading $plugin..."
  fi
}

#
# _zap_format_time_ago - Format timestamp as human-readable "time ago"
#
# Purpose: Convert epoch timestamp to relative time for display in zap status
# Parameters:
#   $1 - Epoch timestamp (seconds since 1970-01-01)
# Returns: 0 always
# Output: Human-readable time string (e.g., "5 minutes ago", "2 hours ago")
#
# WHY: User Story 5 requires displaying when plugins were loaded with
# human-friendly relative timestamps for better UX
#
_zap_format_time_ago() {
  local timestamp="$1"
  local now=$(date +%s)
  local diff=$((now - timestamp))

  # Handle negative or zero differences
  if [[ $diff -le 0 ]]; then
    echo "just now"
    return 0
  fi

  # Calculate time units
  local seconds=$diff
  local minutes=$((seconds / 60))
  local hours=$((minutes / 60))
  local days=$((hours / 24))
  local weeks=$((days / 7))
  local months=$((days / 30))
  local years=$((days / 365))

  # Format based on largest relevant unit
  if [[ $years -gt 0 ]]; then
    if [[ $years -eq 1 ]]; then
      echo "1 year ago"
    else
      echo "$years years ago"
    fi
  elif [[ $months -gt 0 ]]; then
    if [[ $months -eq 1 ]]; then
      echo "1 month ago"
    else
      echo "$months months ago"
    fi
  elif [[ $weeks -gt 0 ]]; then
    if [[ $weeks -eq 1 ]]; then
      echo "1 week ago"
    else
      echo "$weeks weeks ago"
    fi
  elif [[ $days -gt 0 ]]; then
    if [[ $days -eq 1 ]]; then
      echo "1 day ago"
    else
      echo "$days days ago"
    fi
  elif [[ $hours -gt 0 ]]; then
    if [[ $hours -eq 1 ]]; then
      echo "1 hour ago"
    else
      echo "$hours hours ago"
    fi
  elif [[ $minutes -gt 0 ]]; then
    if [[ $minutes -eq 1 ]]; then
      echo "1 minute ago"
    else
      echo "$minutes minutes ago"
    fi
  else
    if [[ $seconds -eq 1 ]]; then
      echo "1 second ago"
    else
      echo "$seconds seconds ago"
    fi
  fi
}
