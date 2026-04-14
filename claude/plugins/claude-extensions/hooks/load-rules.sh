#!/usr/bin/env bash
# Load extension rules from .claude/extensions/rules/ into session context

RULES_DIR="${CLAUDE_PROJECT_DIR}/.claude/extensions/rules"

if [ ! -d "$RULES_DIR" ]; then
  exit 0
fi

FILES=$(find "$RULES_DIR" -name '*.md' 2>/dev/null | sort)

if [ -z "$FILES" ]; then
  exit 0
fi

cat <<'HEADER'
<!-- Extension Rules (auto-loaded) -->

请严格遵守以下扩展规则，它们与本项目的 CLAUDE.md 具有同等优先级。

---

HEADER

echo "$FILES" | while IFS= read -r FILE; do
  FILENAME="$(basename "$FILE")"
  CONTENT="$(cat "$FILE")"
  cat <<EOF
### ${FILENAME}

${CONTENT}

---

EOF
done

echo "<!-- End of Extension Rules -->"
