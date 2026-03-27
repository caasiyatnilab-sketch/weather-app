#!/bin/bash
# 🔍 Health Check Script
# Checks repo health: CI status, open issues, stale PRs, branch protection

set -euo pipefail

REPORT="health-report.md"
REPO="${REPO:-$(gh repo view --json nameWithOwner -q '.nameWithOwner')}"
VERBOSE="${VERBOSE:-false}"

echo "# 🔍 Health Check Report" > "$REPORT"
echo "" >> "$REPORT"
echo "**Repository:** \`$REPO\`" >> "$REPORT"
echo "**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')" >> "$REPORT"
echo "" >> "$REPORT"

SCORE=100
ISSUES=()

# ─── 1. Branch Protection ───
echo "## 🛡️ Branch Protection" >> "$REPORT"
BRANCHES=$(gh api "repos/$REPO/branches" --jq '.[].name' 2>/dev/null || echo "")
PROTECTED_COUNT=0
TOTAL_MAIN=0

for branch in $BRANCHES; do
  if [[ "$branch" == "main" || "$branch" == "master" ]]; then
    TOTAL_MAIN=$((TOTAL_MAIN + 1))
    IS_PROTECTED=$(gh api "repos/$REPO/branches/$branch" --jq '.protected' 2>/dev/null || echo "false")
    if [ "$IS_PROTECTED" = "true" ]; then
      echo "- ✅ \`$branch\` is protected" >> "$REPORT"
      PROTECTED_COUNT=$((PROTECTED_COUNT + 1))
    else
      echo "- ⚠️ \`$branch\` is NOT protected" >> "$REPORT"
      SCORE=$((SCORE - 15))
      ISSUES+=("Branch protection not enabled on \`$branch\`")
    fi
  fi
done

if [ "$TOTAL_MAIN" -eq 0 ]; then
  echo "- ❌ No main/master branch found" >> "$REPORT"
  SCORE=$((SCORE - 10))
fi
echo "" >> "$REPORT"

# ─── 2. Open Issues ───
echo "## 📋 Open Issues" >> "$REPORT"
ISSUE_COUNT=$(gh issue list --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
STALE_ISSUES=$(gh issue list --state open --limit 100 --json createdAt --jq '[.[] | select(.createdAt < (now | strftime("%Y-%m-01T00:00:00Z")))] | length' 2>/dev/null || echo "0")
BUG_ISSUES=$(gh issue list --state open --label "bug" --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")

echo "- **Total open:** $ISSUE_COUNT" >> "$REPORT"
echo "- **Older than 30 days:** $STALE_ISSUES" >> "$REPORT"
echo "- **Bug reports:** $BUG_ISSUES" >> "$REPORT"

if [ "$BUG_ISSUES" -gt 5 ]; then
  echo "- ⚠️ High number of open bugs" >> "$REPORT"
  SCORE=$((SCORE - 10))
  ISSUES+=("$BUG_ISSUES open bug issues — needs triage")
fi

if [ "$STALE_ISSUES" -gt 10 ]; then
  echo "- ⚠️ Many stale issues" >> "$REPORT"
  SCORE=$((SCORE - 5))
fi
echo "" >> "$REPORT"

# ─── 3. Open Pull Requests ───
echo "## 🔀 Open Pull Requests" >> "$REPORT"
PR_COUNT=$(gh pr list --state open --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
DRAFT_PRS=$(gh pr list --state open --draft --limit 100 --json number --jq 'length' 2>/dev/null || echo "0")
REVIEW_PRS=$(gh pr list --state open --json reviewDecision --jq '[.[] | select(.reviewDecision == "CHANGES_REQUESTED")] | length' 2>/dev/null || echo "0")

echo "- **Total open:** $PR_COUNT" >> "$REPORT"
echo "- **Drafts:** $DRAFT_PRS" >> "$REPORT"
echo "- **Changes requested:** $REVIEW_PRS" >> "$REPORT"

if [ "$REVIEW_PRS" -gt 3 ]; then
  echo "- ⚠️ Multiple PRs waiting for changes" >> "$REPORT"
  SCORE=$((SCORE - 5))
fi
echo "" >> "$REPORT"

# ─── 4. Recent CI Runs ───
echo "## 🔄 Recent CI Runs (Last 24h)" >> "$REPORT"
RECENT_RUNS=$(gh run list --limit 20 --json conclusion,createdAt --jq '[.[] | select(.createdAt > (now - 86400 | strftime("%Y-%m-%dT%H:%M:%SZ")))]' 2>/dev/null || echo "[]")
TOTAL_RUNS=$(echo "$RECENT_RUNS" | jq 'length' 2>/dev/null || echo "0")
FAILED_RUNS=$(echo "$RECENT_RUNS" | jq '[.[] | select(.conclusion == "failure")] | length' 2>/dev/null || echo "0")
SUCCESS_RUNS=$(echo "$RECENT_RUNS" | jq '[.[] | select(.conclusion == "success")] | length' 2>/dev/null || echo "0")

echo "- **Total runs:** $TOTAL_RUNS" >> "$REPORT"
echo "- **Successful:** $SUCCESS_RUNS" >> "$REPORT"
echo "- **Failed:** $FAILED_RUNS" >> "$REPORT"

if [ "$FAILED_RUNS" -gt 0 ] && [ "$TOTAL_RUNS" -gt 0 ]; then
  FAIL_RATE=$((FAILED_RUNS * 100 / TOTAL_RUNS))
  if [ "$FAIL_RATE" -gt 30 ]; then
    echo "- ❌ High failure rate: ${FAIL_RATE}%" >> "$REPORT"
    SCORE=$((SCORE - 15))
    ISSUES+=("CI failure rate is ${FAIL_RATE}%")
  else
    echo "- ⚠️ Some failures detected: ${FAIL_RATE}%" >> "$REPORT"
    SCORE=$((SCORE - 5))
  fi
else
  echo "- ✅ All recent runs passed" >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 5. Repository Configuration ───
echo "## ⚙️ Repository Configuration" >> "$REPORT"

# Check for important files
CONFIG_FILES=(
  "README.md"
  "LICENSE"
  ".gitignore"
  ".github/dependabot.yml"
  ".github/workflows"
  ".editorconfig"
  "package.json"
)

for file in "${CONFIG_FILES[@]}"; do
  if [ -f "$file" ] || [ -d "$file" ]; then
    echo "- ✅ \`$file\` exists" >> "$REPORT"
  else
    if [[ "$file" == "README.md" || "$file" == ".gitignore" ]]; then
      echo "- ❌ \`$file\` is MISSING" >> "$REPORT"
      SCORE=$((SCORE - 5))
      ISSUES+=("Missing \`$file\`")
    elif [[ "$file" == "LICENSE" ]]; then
      echo "- ⚠️ \`$file\` is missing" >> "$REPORT"
      SCORE=$((SCORE - 3))
    else
      echo "- ℹ️ \`$file\` not found (recommended)" >> "$REPORT"
    fi
  fi
done
echo "" >> "$REPORT"

# ─── 6. Topics & Description ───
echo "## 🏷️ Repository Metadata" >> "$REPORT"
DESCRIPTION=$(gh repo view --json description -q '.description' 2>/dev/null || echo "")
TOPICS=$(gh repo view --json repositoryTopics -q '.repositoryTopics[].name' 2>/dev/null | tr '\n' ', ' | sed 's/,$//' || echo "")

if [ -z "$DESCRIPTION" ] || [ "$DESCRIPTION" = "null" ]; then
  echo "- ⚠️ No description set" >> "$REPORT"
  SCORE=$((SCORE - 3))
else
  echo "- ✅ Description: $DESCRIPTION" >> "$REPORT"
fi

if [ -z "$TOPICS" ]; then
  echo "- ⚠️ No topics set" >> "$REPORT"
  SCORE=$((SCORE - 2))
else
  echo "- ✅ Topics: $TOPICS" >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── Overall Score ───
echo "---" >> "$REPORT"
echo "" >> "$REPORT"
if [ "$SCORE" -ge 90 ]; then
  EMOJI="🟢"
  STATUS="Excellent"
elif [ "$SCORE" -ge 70 ]; then
  EMOJI="🟡"
  STATUS="Good"
elif [ "$SCORE" -ge 50 ]; then
  EMOJI="🟠"
  STATUS="Needs Attention"
else
  EMOJI="🔴"
  STATUS="Critical"
fi

echo "## $EMOJI Health Score: $SCORE/100 ($STATUS)" >> "$REPORT"
echo "" >> "$REPORT"

if [ ${#ISSUES[@]} -gt 0 ]; then
  echo "### Issues Found" >> "$REPORT"
  for issue in "${ISSUES[@]}"; do
    echo "- $issue" >> "$REPORT"
  done
  echo "" >> "$REPORT"
fi

cat "$REPORT"

# Fail if score is critical
if [ "$SCORE" -lt 50 ]; then
  echo "::error::Health check score is critical: $SCORE/100"
  exit 1
fi
