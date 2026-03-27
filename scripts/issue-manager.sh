#!/bin/bash
# 🏷️ Issue Manager Script
# Handles: auto-labeling, welcome messages, stale cleanup

set -euo pipefail

ACTION="${1:-label}"
REPO="${REPO:-$(gh repo view --json nameWithOwner -q '.nameWithOwner')}"

# ─── Auto-Label Issues ───
label_issue() {
  local issue_number="${ISSUE_NUMBER:-${GITHUB_EVENT_ISSUE_NUMBER:-}}"
  local issue_title="${ISSUE_TITLE:-${GITHUB_EVENT_ISSUE_TITLE:-}}"
  local issue_body="${ISSUE_BODY:-${GITHUB_EVENT_ISSUE_BODY:-}}"

  if [ -z "$issue_number" ]; then
    echo "No issue number provided. Skipping."
    return 0
  fi

  echo "🏷️ Auto-labeling issue #$issue_number..."

  LABELS=()

  # Label by title keywords
  TITLE_LOWER=$(echo "$issue_title" | tr '[:upper:]' '[:lower:]')

  if echo "$TITLE_LOWER" | grep -qiE "bug|error|crash|fix|broken|issue|problem|fail"; then
    LABELS+=("bug")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "feature|request|add|enhance|improve|suggest"; then
    LABELS+=("enhancement")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "doc|readme|wiki|comment|explain"; then
    LABELS+=("documentation")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "question|how|why|what|help|confus"; then
    LABELS+=("question")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "security|vuln|exploit|cve|auth|permission"; then
    LABELS+=("security")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "performance|slow|speed|optimi|fast|memory|cpu"; then
    LABELS+=("performance")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "ui|ux|design|style|css|layout|responsive"; then
    LABELS+=("ui/ux")
  fi
  if echo "$TITLE_LOWER" | grep -qiE "test|spec|coverage|ci|cd|pipeline"; then
    LABELS+=("ci/cd")
  fi

  # Label by body content
  BODY_LOWER=$(echo "$issue_body" | tr '[:upper:]' '[:lower:]')

  if echo "$BODY_LOWER" | grep -qiE "steps to reproduce|expected behavior|actual behavior"; then
    LABELS+=("bug")
  fi
  if echo "$BODY_LOWER" | grep -qiE "would be nice|it would be great|feature request"; then
    LABELS+=("enhancement")
  fi

  # Priority detection
  if echo "$TITLE_LOWER$body_lower" | grep -qiE "urgent|critical|asap|blocking|regression"; then
    LABELS+=("high-priority")
  fi

  # Remove duplicates
  UNIQUE_LABELS=($(printf '%s\n' "${LABELS[@]}" | sort -u))

  if [ ${#UNIQUE_LABELS[@]} -gt 0 ]; then
    LABEL_ARGS=""
    for label in "${UNIQUE_LABELS[@]}"; do
      LABEL_ARGS="$LABEL_ARGS --add-label \"$label\""
    done

    # Create labels if they don't exist, then apply
    for label in "${UNIQUE_LABELS[@]}"; do
      gh label create "$label" --force 2>/dev/null || true
    done

    gh issue edit "$issue_number" --add-label "$(IFS=,; echo "${UNIQUE_LABELS[*]}")" 2>/dev/null || true
    echo "✅ Applied labels: ${UNIQUE_LABELS[*]}"
  else
    echo "ℹ️ No labels matched for issue #$issue_number"
  fi
}

# ─── Welcome First-Time Contributors ───
welcome_contributor() {
  local issue_number="${ISSUE_NUMBER:-${GITHUB_EVENT_ISSUE_NUMBER:-}}"
  local author="${ISSUE_AUTHOR:-${GITHUB_EVENT_SENDER_LOGIN:-}}"

  if [ -z "$issue_number" ] || [ -z "$author" ]; then
    echo "Missing issue number or author. Skipping welcome."
    return 0
  fi

  # Check if author has any prior merged PRs
  PRIOR_PRS=$(gh pr list --author "$author" --state merged --limit 1 --json number --jq 'length' 2>/dev/null || echo "0")
  PRIOR_ISSUES=$(gh issue list --author "$author" --state closed --limit 1 --json number --jq 'length' 2>/dev/null || echo "0")

  if [ "$PRIOR_PRS" -eq 0 ] && [ "$PRIOR_ISSUES" -eq 0 ]; then
    echo "👋 First-time contributor detected: $author"

    COMMENT="👋 Welcome, @${author}! Thanks for opening your first issue in this repo.

Here are some tips:
- Make sure to check our existing issues to avoid duplicates
- If this is a bug report, please include steps to reproduce
- If this is a feature request, describe the use case

We appreciate your contribution! 🎉"

    gh issue comment "$issue_number" --body "$COMMENT" 2>/dev/null || true
    echo "✅ Welcome message posted"
  fi
}

# ─── Stale Issue Cleanup ───
cleanup_stale() {
  echo "🧹 Checking for stale issues and PRs..."

  STALE_DAYS=30
  STALE_LABEL="stale"
  EXEMPT_LABELS=("pinned" "security" "high-priority" "keep-open")

  # Ensure stale label exists
  gh label create "$STALE_LABEL" --color "ededed" --description "Inactive for $STALE_DAYS days" --force 2>/dev/null || true

  # Check issues
  CUTOFF_DATE=$(date -d "-${STALE_DAYS} days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -v-${STALE_DAYS}d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

  if [ -n "$CUTOFF_DATE" ]; then
    gh issue list --state open --limit 100 --json number,createdAt,labels,title --jq ".[] | select(.createdAt < \"$CUTOFF_DATE\") | .number" 2>/dev/null | while read -r issue_num; do
      # Check if exempt
      EXEMPT=$(gh issue view "$issue_num" --json labels --jq '.[].name' 2>/dev/null | grep -ciE "pinned|security|high-priority|keep-open" || echo "0")
      IS_STALE=$(gh issue view "$issue_num" --json labels --jq '.[].name' 2>/dev/null | grep -c "stale" || echo "0")

      if [ "$EXEMPT" -eq 0 ] && [ "$IS_STALE" -eq 0 ]; then
        echo "Marking issue #$issue_num as stale..."
        gh issue edit "$issue_num" --add-label "$STALE_LABEL" 2>/dev/null || true

        COMMENT="🕐 This issue has been inactive for $STALE_DAYS days. It will be closed in 7 days if there's no further activity.

If this issue is still relevant, please comment to keep it open. Otherwise, it will be automatically closed.

/remove-label stale"

        gh issue comment "$issue_num" --body "$COMMENT" 2>/dev/null || true
      fi
    done

    # Close issues stale for 7+ more days
    CUTOFF_CLOSE=$(date -d "-$((STALE_DAYS + 7))" days +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -v-$((STALE_DAYS + 7))d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

    if [ -n "$CUTOFF_CLOSE" ]; then
      gh issue list --state open --label "$STALE_LABEL" --limit 100 --json number --jq '.[].number' 2>/dev/null | while read -r issue_num; do
        LAST_UPDATE=$(gh issue view "$issue_num" --json updatedAt -q '.updatedAt' 2>/dev/null || echo "")
        if [ -n "$LAST_UPDATE" ] && [[ "$LAST_UPDATE" < "$CUTOFF_CLOSE" ]]; then
          echo "Closing stale issue #$issue_num..."
          gh issue comment "$issue_num" --body "🔒 Closing due to inactivity. Feel free to reopen if needed." 2>/dev/null || true
          gh issue close "$issue_num" 2>/dev/null || true
        fi
      done
    fi
  fi

  echo "✅ Stale cleanup complete"
}

# ─── Main ───
case "$ACTION" in
  label)
    label_issue
    ;;
  welcome)
    welcome_contributor
    ;;
  stale)
    cleanup_stale
    ;;
  *)
    echo "Usage: $0 {label|welcome|stale}"
    exit 1
    ;;
esac
