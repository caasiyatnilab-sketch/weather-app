#!/bin/bash
# 🛠️ Auto Fix Script
# Auto-fixes lint, format, and dependency issues

set -euo pipefail

REPORT="fix-report.md"
REPO="${REPO:-$(gh repo view --json nameWithOwner -q '.nameWithOwner')}"

echo "# 🛠️ Auto-Fix Report" > "$REPORT"
echo "" >> "$REPORT"
echo "**Repository:** \`$REPO\`" >> "$REPORT"
echo "**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')" >> "$REPORT"
echo "" >> "$REPORT"

CHANGES_MADE=false
FIXES=()

# ─── 1. Install dependencies if needed ───
if [ -f "package.json" ]; then
  echo "📦 Installing dependencies..." >> "$REPORT"
  npm ci 2>/dev/null || npm install 2>/dev/null || true
  echo "" >> "$REPORT"
fi

# ─── 2. Lint Fix ───
echo "## 🔍 Lint Fixes" >> "$REPORT"
if [ -f "package.json" ]; then
  # Check if eslint is configured
  if grep -q '"eslint"' package.json 2>/dev/null || [ -f ".eslintrc.js" ] || [ -f ".eslintrc.json" ] || [ -f ".eslintrc.yml" ] || [ -f "eslint.config.js" ] || [ -f "eslint.config.mjs" ]; then
    echo "Running ESLint --fix..." >> "$REPORT"
    LINT_OUTPUT=$(npx eslint . --fix --ext .js,.jsx,.ts,.tsx 2>&1 || true)
    if echo "$LINT_OUTPUT" | grep -q "fixed"; then
      echo "✅ ESLint auto-fixed issues" >> "$REPORT"
      CHANGES_MADE=true
      FIXES+=("ESLint fixes applied")
    else
      echo "ℹ️ No ESLint fixes needed or ESLint not fully configured" >> "$REPORT"
    fi
  else
    echo "ℹ️ ESLint not configured. Consider adding it." >> "$REPORT"
  fi
else
  echo "ℹ️ No package.json found. Skipping lint fixes." >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 3. Format Fix ───
echo "## 🎨 Format Fixes" >> "$REPORT"
if [ -f "package.json" ]; then
  # Check if prettier is configured
  if grep -q '"prettier"' package.json 2>/dev/null || [ -f ".prettierrc" ] || [ -f ".prettierrc.js" ] || [ -f ".prettierrc.json" ] || [ -f "prettier.config.js" ]; then
    echo "Running Prettier..." >> "$REPORT"
    PRETTIER_OUTPUT=$(npx prettier --write "**/*.{js,jsx,ts,tsx,json,css,scss,md,html}" 2>&1 || true)
    if [ -n "$PRETTIER_OUTPUT" ]; then
      echo "✅ Prettier formatted files" >> "$REPORT"
      CHANGES_MADE=true
      FIXES+=("Prettier formatting applied")
    fi
  else
    echo "ℹ️ Prettier not configured. Consider adding it." >> "$REPORT"
  fi
fi
echo "" >> "$REPORT"

# ─── 4. Dependency Fixes ───
echo "## 📦 Dependency Fixes" >> "$REPORT"
if [ -f "package.json" ]; then
  # Run npm audit fix
  echo "Running npm audit fix..." >> "$REPORT"
  AUDIT_OUTPUT=$(npm audit fix 2>&1 || true)
  if echo "$AUDIT_OUTPUT" | grep -qiE "fixed|added|removed|changed"; then
    echo "✅ npm audit fix applied changes" >> "$REPORT"
    echo '```' >> "$REPORT"
    echo "$AUDIT_OUTPUT" | head -20 >> "$REPORT"
    echo '```' >> "$REPORT"
    CHANGES_MADE=true
    FIXES+=("npm audit fixes applied")
  else
    echo "ℹ️ No npm audit fixes available" >> "$REPORT"
  fi

  # Update package-lock.json
  if [ -f "package-lock.json" ]; then
    npm install --package-lock-only 2>/dev/null || true
  fi
else
  echo "ℹ️ No package.json. Skipping dependency fixes." >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 5. File Cleanup ───
echo "## 🧹 File Cleanup" >> "$REPORT"

# Remove trailing whitespace from source files
echo "Removing trailing whitespace..." >> "$REPORT"
WS_FIXED=0
find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" -o -name "*.json" -o -name "*.md" -o -name "*.html" -o -name "*.css" -o -name "*.yml" -o -name "*.yaml" \) \
  -not -path "./node_modules/*" \
  -not -path "./.git/*" \
  -not -path "./dist/*" \
  -not -path "./build/*" \
  -exec sed -i 's/[[:space:]]*$//' {} \; 2>/dev/null || true

WS_FIXED=$(git diff --name-only 2>/dev/null | wc -l || echo "0")
if [ "$WS_FIXED" -gt 0 ]; then
  echo "✅ Fixed trailing whitespace in $WS_FIXED files" >> "$REPORT"
  CHANGES_MADE=true
  FIXES+=("Trailing whitespace removed from $WS_FIXED files")
fi

# Ensure files end with newline
echo "Ensuring files end with newline..." >> "$REPORT"
find . -type f \( -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" -o -name "*.json" -o -name "*.css" \) \
  -not -path "./node_modules/*" \
  -not -path "./.git/*" \
  -exec sh -c 'test "$(tail -c1 "$1" | wc -l)" -eq 0 && echo "" >> "$1"' _ {} \; 2>/dev/null || true

echo "" >> "$REPORT"

# ─── 6. Common Bug Fixes ───
echo "## 🐛 Common Fixes" >> "$REPORT"

# Check for missing semicolons in JS (basic)
# Check for common issues in HTML
if find . -name "*.html" -not -path "./node_modules/*" | head -1 | grep -q .; then
  echo "Checking HTML files..." >> "$REPORT"
  
  # Fix missing charset
  find . -name "*.html" -not -path "./node_modules/*" -exec grep -L "charset" {} \; 2>/dev/null | while read -r file; do
    if [ -n "$file" ]; then
      echo "ℹ️ \`$file\` might be missing charset declaration" >> "$REPORT"
    fi
  done

  # Fix missing viewport
  find . -name "*.html" -not -path "./node_modules/*" -exec grep -L "viewport" {} \; 2>/dev/null | while read -r file; do
    if [ -n "$file" ]; then
      echo "ℹ️ \`$file\` might be missing viewport meta tag" >> "$REPORT"
    fi
  done
fi
echo "" >> "$REPORT"

# ─── 7. .gitignore improvements ───
echo "## 📄 .gitignore Check" >> "$REPORT"
if [ -f ".gitignore" ]; then
  MISSING=()
  for pattern in "node_modules/" ".env" "dist/" "build/" "*.log" ".DS_Store" "Thumbs.db"; do
    if ! grep -q "$pattern" .gitignore 2>/dev/null; then
      MISSING+=("$pattern")
    fi
  done

  if [ ${#MISSING[@]} -gt 0 ]; then
    echo "" >> .gitignore
    echo "# Auto-added by RepoBot" >> .gitignore
    for pattern in "${MISSING[@]}"; do
      echo "$pattern" >> .gitignore
    done
    echo "✅ Added missing patterns to .gitignore: ${MISSING[*]}" >> "$REPORT"
    CHANGES_MADE=true
    FIXES+=("Updated .gitignore with missing patterns")
  else
    echo "✅ .gitignore looks good" >> "$REPORT"
  fi
else
  echo "⚠️ No .gitignore file found!" >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── Summary ───
echo "---" >> "$REPORT"
echo "" >> "$REPORT"
if [ "$CHANGES_MADE" = true ]; then
  echo "## ✅ Changes Made" >> "$REPORT"
  for fix in "${FIXES[@]}"; do
    echo "- $fix" >> "$REPORT"
  done
  echo "" >> "$REPORT"
  echo "A PR will be created with these changes." >> "$REPORT"
  echo "changes=true" >> "$GITHUB_OUTPUT" 2>/dev/null || true
else
  echo "## ✅ No Changes Needed" >> "$REPORT"
  echo "" >> "$REPORT"
  echo "Your codebase is clean! No fixes were necessary." >> "$REPORT"
fi

cat "$REPORT"
