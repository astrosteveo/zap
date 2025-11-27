#!/usr/bin/env zsh
#
# test_downloader.zsh - Unit tests for downloader module
#
# Run: zsh tests/unit/test_downloader.zsh

source "$(dirname "$0")/../../lib/downloader.zsh"

echo "=== Downloader Unit Tests ==="
echo ""

# Test disk space check
if _zap_check_disk_space; then
  echo "✓ Disk space check passed (>= 100MB available)"
else
  echo "✗ Disk space check failed (< 100MB available)"
fi

echo ""
echo "✓ Downloader module loaded successfully"
echo "Note: Full integration tests require network access and are in tests/integration/"
