#!/usr/bin/env zsh
#
# compfix.zsh - Completion security validation
#
# WHY: Prevents loading completions from insecure (world-writable) directories.
# Malicious actors could inject code into completion scripts that execute when
# you press Tab, leading to code execution exploits (Constitution Principle VI: Security)
#
# Based on Oh-My-Zsh's compfix.zsh
# Reference: https://github.com/ohmyzsh/ohmyzsh/blob/master/lib/compfix.zsh

#
# _zap_handle_completion_insecurities - Check and warn about insecure completion directories
#
# Purpose: Validates that completion directories have secure ownership and permissions
# WHY: World-writable completion directories are a security vulnerability. An attacker
#      with local access could inject malicious completion scripts.
#
_zap_handle_completion_insecurities() {
  # Skip check if user explicitly disabled it
  # WHY: Some environments (e.g., shared servers, containers) may have intentionally
  # relaxed permissions. Allow power users to bypass the check.
  if [[ "$ZAP_DISABLE_COMPFIX" == true ]]; then
    return 0
  fi

  # Use compaudit to find insecure directories
  # WHY: compaudit is Zsh's built-in tool for checking completion directory security.
  # It reports directories with group-writable or world-writable permissions.
  local -aU insecure_dirs
  insecure_dirs=( ${(f@):-"$(compaudit 2>/dev/null)"} )

  # If no insecure directories found, we're good
  [[ -z "${insecure_dirs}" ]] && return 0

  # Print warning about insecure directories
  # WHY: Users need to understand the security risk and how to fix it
  print "[zap] Insecure completion-dependent directories detected:"
  print "[zap] For security, completions will not be loaded from these directories."
  print ""

  # List ownership and permissions of insecure directories
  ls -ld "${(@)insecure_dirs}"
  print ""

  cat <<'EOD'
[zap] SECURITY WARNING: The directories listed above have insecure permissions.
[zap] Malicious users could inject code into completion scripts.

[zap] To fix this issue:
[zap]   1. Run this command to fix permissions:
[zap]      compaudit | xargs chmod g-w,o-w
[zap]
[zap]   2. Ensure the owner is root or your current user:
[zap]      compaudit | xargs chown -R $(whoami)
[zap]
[zap]   3. Then restart your shell:
[zap]      exec zsh

[zap] If you understand the security risk and want to skip this check:
[zap]   Set ZAP_DISABLE_COMPFIX=true in your ~/.zshrc before sourcing zap

[zap] Completions will be disabled until this is resolved.
EOD

  # Return non-zero to indicate insecure state
  # WHY: Caller can decide whether to proceed with completion initialization
  return 1
}

# Run the security check
# WHY: We want to validate security early, before any completions are loaded
_zap_handle_completion_insecurities
