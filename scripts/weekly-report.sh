#!/bin/bash
# 📊 Weekly Report Script
# Generates a comprehensive weekly summary

set -euo pipefail

REPORT="weekly-report.md"
REPO="${REPO:-$(gh repo view --json nameWithOwner -q '.nameWithOwner')}"
WEEK_AGO=$(date -d "-7 days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -v-7d +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "")

echo "# 📊 Weekly Report" > "$REPORT"
echo "" >> "$REPORT"
echo "**Repository:** \`$REPO\`" >> "$REPORT"
echo "**Period:** $(date -d '-7 days' '+%Y-%m-%d' 2>/dev/null || date -v-7d '+%Y-%m-%d' 2>/dev/null || echo '7 days ago') → $(date '+%Y-%m-%d')" >> "$REPORT"
echo "**Generated:** $(date -u '+%Y-%m-%d %H:%M UTC')" >> "$REPORT"
echo "" >> "$REPORT"

# ─── 1. Activity Summary ───
echo "## 📈 Activity Summary" >> "$REPORT"
echo "" >> "$REPORT"

# Commits
COMMIT_COUNT=$(git log --oneline --since="$WEEK_AGO" 2>/dev/null | wc -l || echo "0")
echo "- **Commits:** $COMMIT_COUNT" >> "$REPORT"

# PRs opened
PRS_OPENED=$(gh pr list --state all --json createdAt --jq "[.[] | select(.createdAt > \"$WEEK_AGO\")] | length" 2>/dev/null || echo "0")
echo "- **PRs opened:** $PRS_OPENED" >> "$REPORT"

# PRs merged
PRS_MERGED=$(gh pr list --state merged --json mergedAt --jq "[.[] | select(.mergedAt > \"$WEEK_AGO\")] | length" 2>/dev/null || echo "0")
echo "- **PRs merged:** $PRS_MERGED" >> "$REPORT"

# Issues opened
ISSUES_OPENED=$(gh issue list --state all --json createdAt --jq "[.[] | select(.createdAt > \"$WEEK_AGO\")] | length" 2>/dev/null || echo "0")
echo "- **Issues opened:** $ISSUES_OPENED" >> "$REPORT"

# Issues closed
ISSUES_CLOSED=$(gh issue list --state closed --json closedAt --jq "[.[] | select(.closedAt > \"$WEEK_AGO\")] | length" 2>/dev/null || echo "0")
echo "- **Issues closed:** $ISSUES_CLOSED" >> "$REPORT"
echo "" >> "$REPORT"

# ─── 2. Contributors ───
echo "## 👥 Contributors This Week" >> "$REPORT"
echo "" >> "$REPORT"
git log --since="$WEEK_AGO" --format="%aN" 2>/dev/null | sort | uniq -c | sort -rn | head -10 | while read -r count author; do
  echo "- **$author**: $count commits" >> "$REPORT"
done || echo "No commits this week." >> "$REPORT"
echo "" >> "$REPORT"

# ─── 3. Open Issues ───
echo "## 📋 Current Open Issues" >> "$REPORT"
echo "" >> "$REPORT"

OPEN_ISSUES=$(gh issue list --state open --limit 20 --json number,title,labels,createdAt --jq '.[] | "- #\(.number): \(.title) [\([.labels[].name] | join(", "))] (opened \(.createdAt | split("T")[0]))"' 2>/dev/null || echo "No open issues.")
echo "$OPEN_ISSUES" >> "$REPORT"
echo "" >> "$REPORT"

TOTAL_OPEN=$(gh issue list --state open --json number --jq 'length' 2>/dev/null || echo "0")
if [ "$TOTAL_OPEN" -gt 20 ]; then
  echo "_... and $((TOTAL_OPEN - 20)) more open issues._" >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 4. Open PRs ───
echo "## 🔀 Current Open Pull Requests" >> "$REPORT"
echo "" >> "$REPORT"

OPEN_PRS=$(gh pr list --state open --limit 20 --json number,title,author,createdAt --jq '.[] | "- #\(.number): \(.title) by @\(.author.login) (opened \(.createdAt | split("T")[0]))"' 2>/dev/null || echo "No open PRs.")
echo "$OPEN_PRS" >> "$REPORT"
echo "" >> "$REPORT"

# ─── 5. CI/CD Status ───
echo "## 🔄 CI/CD Status" >> "$REPORT"
echo "" >> "$REPORT"

RECENT_RUNS=$(gh run list --limit 10 --json name,conclusion,createdAt,status --jq '.[] | "- \(.name): \(.conclusion // .status) (\(.createdAt | split("T")[0]))"' 2>/dev/null || echo "No recent runs.")
echo "$RECENT_RUNS" >> "$REPORT"
echo "" >> "$REPORT"

# Success rate
TOTAL_CI=$(gh run list --limit 50 --json conclusion --jq 'length' 2>/dev/null || echo "0")
SUCCESS_CI=$(gh run list --limit 50 --json conclusion --jq '[.[] | select(.conclusion == "success")] | length' 2>/dev/null || echo "0")
if [ "$TOTAL_CI" -gt 0 ]; then
  RATE=$((SUCCESS_CI * 100 / TOTAL_CI))
  echo "**CI Success Rate:** $RATE% ($SUCCESS_CI/$TOTAL_CI)" >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 6. Security Status ───
echo "## 🔒 Security Status" >> "$REPORT"
echo "" >> "$REPORT"

if [ -f "package.json" ]; then
  AUDIT=$(npm audit --json 2>/dev/null || echo '{"metadata":{"vulnerabilities":{}}}')
  CRITICAL=$(echo "$AUDIT" | jq '.metadata.vulnerabilities.critical // 0' 2>/dev/null || echo "0")
  HIGH=$(echo "$AUDIT" | jq '.metadata.vulnerabilities.high // 0' 2>/dev/null || echo "0")
  MODERATE=$(echo "$AUDIT" | jq '.metadata.vulnerabilities.moderate // 0' 2>/dev/null || echo "0")

  echo "| Severity | Count |" >> "$REPORT"
  echo "|----------|-------|" >> "$REPORT"
  echo "| 🔴 Critical | $CRITICAL |" >> "$REPORT"
  echo "| 🟠 High | $HIGH |" >> "$REPORT"
  echo "| 🟡 Moderate | $MODERATE |" >> "$REPORT"

  if [ "$CRITICAL" -gt 0 ] || [ "$HIGH" -gt 0 ]; then
    echo "" >> "$REPORT"
    echo "⚠️ **Action needed:** Run \`npm audit fix\` to address vulnerabilities." >> "$REPORT"
  fi
else
  echo "ℹ️ No package.json — skipping dependency audit." >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 7. Repo Stats ───
echo "## 📊 Repository Stats" >> "$REPORT"
echo "" >> "$REPORT"

STARS=$(gh repo view --json stargazerCount -q '.stargazerCount' 2>/dev/null || echo "0")
FORKS=$(gh repo view --json forkCount -q '.forkCount' 2>/dev/null || echo "0")
WATCHERS=$(gh repo view --json watchers -q '.watchers.totalCount' 2>/dev/null || echo "0")

echo "- ⭐ Stars: $STARS" >> "$REPORT"
echo "- 🍴 Forks: $FORKS" >> "$REPORT"
echo "- 👀 Watchers: $WATCHERS" >> "$REPORT"
echo "" >> "$REPORT"

# ─── 8. Recommendations ───
echo "## 💡 Recommendations" >> "$REPORT"
echo "" >> "$REPORT"

RECS=()

if [ "$TOTAL_OPEN" -gt 20 ]; then
  RECS+=("High issue count ($TOTAL_OPEN) — consider triaging old issues")
fi

if [ "$CRITICAL" -gt 0 ]; then
  RECS+=("Critical vulnerabilities found — address immediately")
fi

if [ "$COMMIT_COUNT" -eq 0 ]; then
  RECS+=("No commits this week — check if development is stalled")
fi

if [ ${#RECS[@]} -eq 0 ]; then
  RECS+=("Everything looks good! Keep up the great work. 🎉")
fi

for rec in "${RECS[@]}"; do
  echo "- $rec" >> "$REPORT"
done
echo "" >> "$REPORT"

echo "---" >> "$REPORT"
echo "" >> "$REPORT"
echo "_Generated by [RepoBot](https://github.com/caasiyatnilab-sketch/repo-bot) 🤖_" >> "$REPORT"

cat "$REPORT"
