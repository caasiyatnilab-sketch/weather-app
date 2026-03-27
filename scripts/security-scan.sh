#!/bin/bash
# 🔒 Security Scan Script
# Runs dependency audits, checks for common vulnerabilities

set -euo pipefail

REPORT="security-report.md"
REPO="${REPO:-$(gh repo view --json nameWithOwner -q '.nameWithOwner')}"

echo "# 🔒 Security Scan Report" > "$REPORT"
echo "" >> "$REPORT"
echo "**Repository:** \`$REPO\`" >> "$REPORT"
echo "**Date:** $(date -u '+%Y-%m-%d %H:%M UTC')" >> "$REPORT"
echo "" >> "$REPORT"

VULNERABILITIES=0
WARNINGS=0

# ─── 1. npm audit (if package.json exists) ───
echo "## 📦 Dependency Audit" >> "$REPORT"
if [ -f "package.json" ]; then
  echo "Running npm audit..." >> "$REPORT"
  echo "" >> "$REPORT"

  AUDIT_JSON=$(npm audit --json 2>/dev/null || echo '{"metadata":{"vulnerabilities":{"critical":0,"high":0,"moderate":0,"low":0,"info":0}}}')
  CRITICAL=$(echo "$AUDIT_JSON" | jq '.metadata.vulnerabilities.critical // 0' 2>/dev/null || echo "0")
  HIGH=$(echo "$AUDIT_JSON" | jq '.metadata.vulnerabilities.high // 0' 2>/dev/null || echo "0")
  MODERATE=$(echo "$AUDIT_JSON" | jq '.metadata.vulnerabilities.moderate // 0' 2>/dev/null || echo "0")
  LOW=$(echo "$AUDIT_JSON" | jq '.metadata.vulnerabilities.low // 0' 2>/dev/null || echo "0")

  echo "| Severity | Count |" >> "$REPORT"
  echo "|----------|-------|" >> "$REPORT"
  echo "| 🔴 Critical | $CRITICAL |" >> "$REPORT"
  echo "| 🟠 High | $HIGH |" >> "$REPORT"
  echo "| 🟡 Moderate | $MODERATE |" >> "$REPORT"
  echo "| 🟢 Low | $LOW |" >> "$REPORT"
  echo "" >> "$REPORT"

  if [ "$CRITICAL" -gt 0 ]; then
    echo "❌ **$CRITICAL critical vulnerabilities found!**" >> "$REPORT"
    VULNERABILITIES=$((VULNERABILITIES + CRITICAL))
  fi
  if [ "$HIGH" -gt 0 ]; then
    echo "⚠️ **$HIGH high-severity vulnerabilities found**" >> "$REPORT"
    VULNERABILITIES=$((VULNERABILITIES + HIGH))
  fi
  if [ "$MODERATE" -gt 0 ]; then
    echo "ℹ️ $MODERATE moderate vulnerabilities" >> "$REPORT"
    WARNINGS=$((WARNINGS + MODERATE))
  fi

  # List top vulnerabilities
  echo "" >> "$REPORT"
  echo "### Top Vulnerabilities" >> "$REPORT"
  npm audit --json 2>/dev/null | jq -r '.vulnerabilities | to_entries | sort_by(.value.severity) | reverse | .[0:10] | .[] | "- **\(.value.severity)**: `\(.key)` — \(.value.via[0].title // "No description")"' >> "$REPORT" 2>/dev/null || echo "Could not parse vulnerability details." >> "$REPORT"
else
  echo "ℹ️ No \`package.json\` found — skipping npm audit." >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 2. Check for outdated lock files ───
echo "## 🔒 Lock File Integrity" >> "$REPORT"
if [ -f "package-lock.json" ]; then
  if git diff --name-only HEAD~5 HEAD 2>/dev/null | grep -q "package.json" && ! git diff --name-only HEAD~5 HEAD 2>/dev/null | grep -q "package-lock.json"; then
    echo "⚠️ \`package.json\` was modified but \`package-lock.json\` was NOT updated" >> "$REPORT"
    WARNINGS=$((WARNINGS + 1))
  else
    echo "✅ \`package-lock.json\` is in sync" >> "$REPORT"
  fi
else
  echo "ℹ️ No lock file found" >> "$REPORT"
fi
echo "" >> "$REPORT"

# ─── 3. Check for exposed secrets ───
echo "## 🔑 Secret Detection" >> "$REPORT"
SECRET_FOUND=0

PATTERNS=(
  'AKIA[0-9A-Z]{16}'
  'sk-[a-zA-Z0-9]{48}'
  'ghp_[a-zA-Z0-9]{36}'
  'xox[baprs]-[a-zA-Z0-9-]+'
  'npm_[A-Za-z0-9]{36}'
  'sk_live_[a-zA-Z0-9]{24}'
  'AIza[0-9A-Za-z_-]{35}'
  'password\s*[:=]\s*["\x27][^"\x27]{8,}'
  'api[_-]?key\s*[:=]\s*["\x27][^"\x27]{8,}'
  'secret\s*[:=]\s*["\x27][^"\x27]{8,}'
  'token\s*[:=]\s*["\x27][^"\x27]{8,}'
)

for pattern in "${PATTERNS[@]}"; do
  RESULTS=$(grep -rnEi "$pattern" --include="*.{js,ts,py,json,yml,yaml,env,conf,cfg,ini,html,md}" . 2>/dev/null | grep -v node_modules | grep -v '.git/' | grep -v 'security-scan.sh' | head -3 || true)
  if [ -n "$RESULTS" ]; then
    echo "⚠️ Potential secret pattern found:" >> "$REPORT"
    echo '```' >> "$REPORT"
    echo "$RESULTS" | head -5 >> "$REPORT"
    echo '```' >> "$REPORT"
    SECRET_FOUND=1
  fi
done

if [ "$SECRET_FOUND" -eq 0 ]; then
  echo "✅ No secrets detected in tracked files" >> "$REPORT"
else
  VULNERABILITIES=$((VULNERABILITIES + 1))
fi
echo "" >> "$REPORT"

# ─── 4. Check .gitignore for sensitive files ───
echo "## 📄 .gitignore Coverage" >> "$REPORT"
if [ -f ".gitignore" ]; then
  SENSITIVE_PATTERNS=(".env" "*.key" "*.pem" "credentials" "secrets" ".npmrc" ".env.local")
  MISSING=()
  for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    if ! grep -q "$pattern" .gitignore 2>/dev/null; then
      MISSING+=("$pattern")
    fi
  done

  if [ ${#MISSING[@]} -gt 0 ]; then
    echo "⚠️ Consider adding these to .gitignore:" >> "$REPORT"
    for m in "${MISSING[@]}"; do
      echo "- \`$m\`" >> "$REPORT"
    done
    WARNINGS=$((WARNINGS + 1))
  else
    echo "✅ .gitignore covers common sensitive patterns" >> "$REPORT"
  fi
else
  echo "❌ No .gitignore file found!" >> "$REPORT"
  VULNERABILITIES=$((VULNERABILITIES + 1))
fi
echo "" >> "$REPORT"

# ─── 5. GitHub Security Settings ───
echo "## ⚙️ GitHub Security Features" >> "$REPORT"
echo "- Check if Dependabot alerts are enabled in repo settings" >> "$REPORT"
echo "- Check if Code scanning is enabled in repo settings" >> "$REPORT"
echo "- Check if Secret scanning is enabled in repo settings" >> "$REPORT"
echo "" >> "$REPORT"

# ─── Summary ───
echo "---" >> "$REPORT"
echo "" >> "$REPORT"
if [ "$VULNERABILITIES" -gt 0 ]; then
  echo "## 🔴 Security Score: $VULNERABILITIES vulnerabilities, $WARNINGS warnings" >> "$REPORT"
  echo "" >> "$REPORT"
  echo "**Immediate action required on security findings above.**" >> "$REPORT"
  exit 1
elif [ "$WARNINGS" -gt 0 ]; then
  echo "## 🟡 Security Score: $WARNINGS warnings" >> "$REPORT"
  echo "" >> "$REPORT"
  echo "Review warnings above when possible." >> "$REPORT"
else
  echo "## 🟢 Security Score: All Clear" >> "$REPORT"
  echo "" >> "$REPORT"
  echo "No security issues detected." >> "$REPORT"
fi

cat "$REPORT"
