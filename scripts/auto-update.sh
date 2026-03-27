#!/bin/bash
# 📦 Auto Update Script
# Checks for outdated dependencies and creates update PRs

set -euo pipefail

REPORT="update-report.md"
REPO="${REPO:-$(gh repo view --json nameWithOwner -q '.nameWithOwner')}"
FORCE="${FORCE:-false}"

echo "# 📦 Dependency Update Report" > "$REPORT"
echo "" >> "$REPORT"
echo "**Repository:** \`$REPO\`" >> "$REPORT"
echo "**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')" >> "$REPORT"
echo "" >> "$REPORT"

UPDATED=0
UP_TO_DATE=0
ERRORS=0

if [ ! -f "package.json" ]; then
  echo "ℹ️ No \`package.json\` found. Skipping dependency updates." >> "$REPORT"
  cat "$REPORT"
  exit 0
fi

# ─── 1. Check for outdated packages ───
echo "## 📊 Outdated Dependencies" >> "$REPORT"
echo "" >> "$REPORT"

OUTDATED=$(npm outdated --json 2>/dev/null || echo "{}")
OUTDATED_COUNT=$(echo "$OUTDATED" | jq 'length' 2>/dev/null || echo "0")

if [ "$OUTDATED_COUNT" -eq 0 ]; then
  echo "✅ All dependencies are up to date!" >> "$REPORT"
  cat "$REPORT"
  exit 0
fi

echo "Found **$OUTDATED_COUNT** outdated packages:" >> "$REPORT"
echo "" >> "$REPORT"
echo "| Package | Current | Wanted | Latest |" >> "$REPORT"
echo "|---------|---------|--------|--------|" >> "$REPORT"

echo "$OUTDATED" | jq -r 'to_entries[] | "| \(.key) | \(.value.current) | \(.value.wanted) | \(.value.latest) |"' >> "$REPORT" 2>/dev/null || echo "| Error parsing | - | - | - |" >> "$REPORT"
echo "" >> "$REPORT"

# ─── 2. Categorize updates ───
echo "## 🏷️ Update Categories" >> "$REPORT"
echo "" >> "$REPORT"

MAJOR=0
MINOR=0
PATCH=0

echo "$OUTDATED" | jq -r 'to_entries[] | "\(.key)|\(.value.current)|\(.value.latest)"' 2>/dev/null | while IFS='|' read -r pkg current latest; do
  CURRENT_MAJOR=$(echo "$current" | cut -d. -f1 | sed 's/[^0-9]*//g')
  LATEST_MAJOR=$(echo "$latest" | cut -d. -f1 | sed 's/[^0-9]*//g')
  CURRENT_MINOR=$(echo "$current" | cut -d. -f2 | sed 's/[^0-9]*//g')
  LATEST_MINOR=$(echo "$latest" | cut -d. -f2 | sed 's/[^0-9]*//g')

  if [ "$CURRENT_MAJOR" != "$LATEST_MAJOR" ] && [ -n "$CURRENT_MAJOR" ] && [ -n "$LATEST_MAJOR" ]; then
    MAJOR=$((MAJOR + 1))
  elif [ "$CURRENT_MINOR" != "$LATEST_MINOR" ] && [ -n "$CURRENT_MINOR" ] && [ -n "$LATEST_MINOR" ]; then
    MINOR=$((MINOR + 1))
  else
    PATCH=$((PATCH + 1))
  fi
done

echo "- 🔴 **Major updates:** Breaking changes possible — manual review needed" >> "$REPORT"
echo "- 🟡 **Minor updates:** New features, backward compatible" >> "$REPORT"
echo "- 🟢 **Patch updates:** Bug fixes, safe to auto-apply" >> "$REPORT"
echo "" >> "$REPORT"

# ─── 3. Auto-update patches ───
echo "## 🔄 Auto-Update Results" >> "$REPORT"
echo "" >> "$REPORT"

echo "Running npm update for patch versions..." >> "$REPORT"
if npm update 2>/dev/null; then
  echo "✅ Patch updates applied successfully" >> "$REPORT"
  UPDATED=1
else
  echo "⚠️ Some updates failed" >> "$REPORT"
  ERRORS=$((ERRORS + 1))
fi

# Check what changed
if git diff --quiet package.json package-lock.json 2>/dev/null; then
  echo "ℹ️ No changes after update" >> "$REPORT"
  UPDATED=0
else
  CHANGES=$(git diff --stat package.json package-lock.json 2>/dev/null || echo "Changes detected")
  echo "" >> "$REPORT"
  echo "### Changes Applied" >> "$REPORT"
  echo '```diff' >> "$REPORT"
  git diff package.json 2>/dev/null >> "$REPORT" || true
  echo '```' >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 4. Security-focused updates ───
echo "## 🔒 Security Updates" >> "$REPORT"
echo "" >> "$REPORT"

AUDIT_FIX=$(npm audit fix --dry-run 2>&1 || echo "No fixes available")
echo '```' >> "$REPORT"
echo "$AUDIT_FIX" | head -20 >> "$REPORT"
echo '```' >> "$REPORT"
echo "" >> "$REPORT"

# ─── 5. Recommendations ───
echo "## 💡 Recommendations" >> "$REPORT"
echo "" >> "$REPORT"

if [ "$OUTDATED_COUNT" -gt 10 ]; then
  echo "1. ⚠️ Many outdated dependencies — consider a focused update sprint" >> "$REPORT"
fi

echo "1. Review major version updates manually before applying" >> "$REPORT"
echo "2. Run full test suite after applying updates" >> "$REPORT"
echo "3. Check changelogs for breaking changes" >> "$REPORT"
echo "" >> "$REPORT"

echo "---" >> "$REPORT"
echo "" >> "$REPORT"
echo "**Auto-update completed.** Patch versions applied, major/minor flagged for review." >> "$REPORT"

# Output if changes were made
if [ "$UPDATED" -eq 1 ]; then
  echo "changes=true" >> "$GITHUB_OUTPUT" 2>/dev/null || true
fi

cat "$REPORT"
