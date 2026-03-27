#!/bin/bash
# 🔀 PR Manager Script
# Handles: auto-labeling, size labels, quality checks

set -euo pipefail

ACTION="${1:-label}"
REPO="${REPO:-$(gh repo view --json nameWithOwner -q '.nameWithOwner')}"

PR_NUMBER="${PR_NUMBER:-${GITHUB_EVENT_PULL_REQUEST_NUMBER:-}}"
PR_TITLE="${PR_TITLE:-${GITHUB_EVENT_PULL_REQUEST_TITLE:-}}"
PR_BODY="${PR_BODY:-${GITHUB_EVENT_PULL_REQUEST_BODY:-}}"

# ─── Auto-Label PRs ───
label_pr() {
  if [ -z "$PR_NUMBER" ]; then
    echo "No PR number provided. Skipping."
    return 0
  fi

  echo "🏷️ Auto-labeling PR #$PR_NUMBER..."

  LABELS=()
  TITLE_LOWER=$(echo "$PR_TITLE" | tr '[:upper:]' '[:lower:]')

  # By type
  if echo "$TITLE_LOWER" | grep -qiE "fix|bug|patch|hotfix"; then
    LABELS+=("bug-fix")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "feat|feature|add|new"; then
    LABELS+=("feature")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "refactor|clean|restructur"; then
    LABELS+=("refactor")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "doc|readme|comment"; then
    LABELS+=("documentation")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "test|spec|coverage"; then
    LABELS+=("tests")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "dep|bump|update.*package|upgrade"; then
    LABELS+=("dependencies")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "ci|cd|pipeline|workflow|action"; then
    LABELS+=("ci/cd")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "style|css|ui|design|responsive"; then
    LABELS+=("ui/ux")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "perf|speed|optim|fast|memory"; then
    LABELS+=("performance")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "security|auth|vuln|fix.*cve"; then
    LABELS+=("security")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "revert"; then
    LABELS+=("revert")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "wip|draft|work.in.progress"; then
    LABELS+=("wip")
  fi

  # By conventional commit prefix
  if echo "$TITLE_LOWER" | grep -qE "^(feat|feature):"; then LABELS+=("feature"); fi
  if echo "$TITLE_LOWER" | grep -qE "^(fix|bugfix):"; then LABELS+=("bug-fix"); fi
  if echo "$TITLE_LOWER" | grep -qE "^docs:"; then LABELS+=("documentation"); fi
  if echo "$TITLE_LOWER" | grep -qE "^style:"; then LABELS+=("ui/ux"); fi
  if echo "$TITLE_LOWER" | grep -qE "^refactor:"; then LABELS+=("refactor"); fi
  if echo "$TITLE_LOWER" | grep -qE "^test:"; then LABELS+=("tests"); fi
  if echo "$TITLE_LOWER" | grep -qE "^chore:"; then LABELS+=("chore"); fi
  if echo "$TITLE_LOWER" | grep -qE "^perf:"; then LABELS+=("performance"); fi
  if echo "$TITLE_LOWER" | grep -qE "^ci:"; then LABELS+=("ci/cd"); fi
  if echo "$TITLE_LOWER" | grep -qE "^deps:"; then LABELS+=("dependencies"); fi

  # Remove duplicates
  UNIQUE_LABELS=($(printf '%s\n' "${LABELS[@]}" | sort -u))

  if [ ${#UNIQUE_LABELS[@]} -gt 0 ]; then
    for label in "${UNIQUE_LABELS[@]}"; do
      gh label create "$label" --force 2>/dev/null || true
    done
    gh pr edit "$PR_NUMBER" --add-label "$(IFS=,; echo "${UNIQUE_LABELS[*]}")" 2>/dev/null || true
    echo "✅ Applied labels: ${UNIQUE_LABELS[*]}"
  fi
}

# ─── Size Labeler ───
size_label() {
  if [ -z "$PR_NUMBER" ]; then
    echo "No PR number. Skipping size check."
    return 0
  fi

  echo "📏 Checking PR size for #$PR_NUMBER..."

  # Get diff stats
  STATS=$(gh pr diff "$PR_NUMBER" --stat 2>/dev/null | tail -1 || echo "0 files changed")
  ADDED=$(echo "$STATS" | grep -oP '\d+ insertion' | grep -oP '\d+' || echo "0")
  DELETED=$(echo "$STATS" | grep -oP '\d+ deletion' | grep -oP '\d+' || echo "0")
  FILES=$(echo "$STATS" | grep -oP '\d+ file' | grep -oP '\d+' || echo "0")

  TOTAL_CHANGES=$((ADDED + DELETED))

  # Remove existing size labels
  for size in "size/XS" "size/S" "size/M" "size/L" "size/XL" "size/XXL"; do
    gh pr edit "$PR_NUMBER" --remove-label "$size" 2>/dev/null || true
  done

  if [ "$TOTAL_CHANGES" -le 10 ]; then
    SIZE="size/XS"
    EMOJI="🟢"
  elif [ "$TOTAL_CHANGES" -le 50 ]; then
    SIZE="size/S"
    EMOJI="🟢"
  elif [ "$TOTAL_CHANGES" -le 200 ]; then
    SIZE="size/M"
    EMOJI="🟡"
  elif [ "$TOTAL_CHANGES" -le 500 ]; then
    SIZE="size/L"
    EMOJI="🟠"
  elif [ "$TOTAL_CHANGES" -le 1000 ]; then
    SIZE="size/XL"
    EMOJI="🔴"
  else
    SIZE="size/XXL"
    EMOJI="🔴"
  fi

  gh label create "$SIZE" --force 2>/dev/null || true
  gh pr edit "$PR_NUMBER" --add-label "$SIZE" 2>/dev/null || true
  echo "$EMOJI PR #$PR_NUMBER: $SIZE ($TOTAL_CHANGES changes across $FILES files)"
}

# ─── Quality Check ───
quality_check() {
  if [ -z "$PR_NUMBER" ]; then
    echo "No PR number. Skipping quality check."
    return 0
  fi

  echo "🔍 Running quality checks on PR #$PR_NUMBER..."

  ISSUES=()

  # Check PR description
  BODY_LENGTH=${#PR_BODY}
  if [ "$BODY_LENGTH" -lt 20 ]; then
    ISSUES+=("PR description is very short ($BODY_LENGTH chars). Consider adding more context.")
  fi

  # Check for WIP/Draft
  TITLE_LOWER=$(echo "$PR_TITLE" | tr '[:upper:]' '[:lower:]')
  if echo "$TITLE_LOWER" | grep -qiE "wip|draft|work.in.progress|do.not.merge"; then
    ISSUES+=("PR appears to be work in progress. Consider converting to draft PR.")
  fi

  # Check for large files
  LARGE_FILES=$(gh pr diff "$PR_NUMBER" --name-only 2>/dev/null | while read -r file; do
    if [ -f "$file" ]; then
      SIZE=$(wc -c < "$file" 2>/dev/null || echo "0")
      if [ "$SIZE" -gt 100000 ]; then
        echo "$file ($(($SIZE / 1024))KB)"
      fi
    fi
  done || true)

  if [ -n "$LARGE_FILES" ]; then
    ISSUES+=("Large files detected:\n$LARGE_FILES")
  fi

  # Check for console.log / debug statements
  DIFF_CONTENT=$(gh pr diff "$PR_NUMBER" 2>/dev/null || echo "")
  DEBUG_LINES=$(echo "$DIFF_CONTENT" | grep -cE "^\+.*console\.(log|debug|warn|error)" || echo "0")
  if [ "$DEBUG_LINES" -gt 0 ]; then
    ISSUES+=("Found $DEBUG_LINES debug statement(s) (console.log/error/etc). Remove before merging.")
  fi

  # Check for TODO/FIXME/HACK
  TODO_LINES=$(echo "$DIFF_CONTENT" | grep -cE "^\+.*(TODO|FIXME|HACK|XXX)" || echo "0")
  if [ "$TODO_LINES" -gt 0 ]; then
    ISSUES+=("Found $TODO_LINES TODO/FIXME/HACK comment(s). Address or create tracking issues.")
  fi

  # Report findings
  if [ ${#ISSUES[@]} -gt 0 ]; then
    COMMENT="## 🔍 PR Quality Check Results

The following items were detected:

"
    for issue in "${ISSUES[@]}"; do
      COMMENT+="- ⚠️ $issue
"
    done
    COMMENT+="
---
_Automated check by RepoBot_"

    gh pr comment "$PR_NUMBER" --body "$COMMENT" 2>/dev/null || true
    echo "⚠️ Quality issues found and reported"
  else
    echo "✅ No quality issues detected"
  fi
}

# ─── Main ───
case "$ACTION" in
  label)
    label_pr
    ;;
  size)
    size_label
    ;;
  quality)
    quality_check
    ;;
  *)
    echo "Usage: $0 {label|size|quality}"
    exit 1
    ;;
esac
