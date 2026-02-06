#!/bin/bash
set -euo pipefail

# ════════════════════════════════════════════════════════════════════
# cc-multi-agent セットアップスクリプト
# 対象プロジェクトに .devcontainer/ と .cc-multi-agent/ を作成します
# ════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${1:-$(pwd)}"

echo "cc-multi-agent setup"
echo "===================="
echo "Target directory: $TARGET_DIR"
echo ""

# ════════════════════════════════════════════════════════════════════
# .devcontainer/ 存在チェック
# ════════════════════════════════════════════════════════════════════
if [ -d "$TARGET_DIR/.devcontainer" ]; then
  echo "WARNING: .devcontainer/ already exists."
  read -p "Overwrite? (y/N): " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
  fi
fi

# ════════════════════════════════════════════════════════════════════
# 公式 devcontainer ダウンロード
# ════════════════════════════════════════════════════════════════════
echo "Downloading official devcontainer files..."
mkdir -p "$TARGET_DIR/.devcontainer"

CLAUDE_CODE_REPO="https://raw.githubusercontent.com/anthropics/claude-code/main/.devcontainer"

curl -fsSL -o "$TARGET_DIR/.devcontainer/devcontainer.json" "$CLAUDE_CODE_REPO/devcontainer.json"
curl -fsSL -o "$TARGET_DIR/.devcontainer/Dockerfile" "$CLAUDE_CODE_REPO/Dockerfile"
curl -fsSL -o "$TARGET_DIR/.devcontainer/init-firewall.sh" "$CLAUDE_CODE_REPO/init-firewall.sh"

echo "Downloaded: devcontainer.json, Dockerfile, init-firewall.sh"

# ════════════════════════════════════════════════════════════════════
# Dockerfile に tmux を追加（公式は tmux を含まないため）
# ════════════════════════════════════════════════════════════════════
echo "Adding tmux to Dockerfile..."
sed -i 's/nano \\/nano tmux \\/' "$TARGET_DIR/.devcontainer/Dockerfile"
echo "Added tmux to Dockerfile"

# ════════════════════════════════════════════════════════════════════
# Dockerfile に locale 設定を追加（警告を消すため）
# ════════════════════════════════════════════════════════════════════
echo "Adding locale settings to Dockerfile..."
sed -i 's/nano tmux \\/nano tmux locales \\/' "$TARGET_DIR/.devcontainer/Dockerfile"
# apt-get clean の後に locale 生成を追加
sed -i '/apt-get clean/a RUN sed -i "/en_US.UTF-8/s/^# //" /etc/locale.gen && locale-gen' "$TARGET_DIR/.devcontainer/Dockerfile"
# ENV で locale を設定
sed -i '/ENV DEVCONTAINER=true/a ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8' "$TARGET_DIR/.devcontainer/Dockerfile"
echo "Added locale settings to Dockerfile"

# ════════════════════════════════════════════════════════════════════
# Dockerfile に timezone 設定を追加（JST）
# ════════════════════════════════════════════════════════════════════
echo "Adding timezone settings to Dockerfile..."
sed -i '/ENV LANG=en_US.UTF-8/a ENV TZ=Asia/Tokyo' "$TARGET_DIR/.devcontainer/Dockerfile"
echo "Added timezone settings to Dockerfile"

# ════════════════════════════════════════════════════════════════════
# postStartCommand → postCreateCommand に変更し、setup-multiagent.sh を追加
# ════════════════════════════════════════════════════════════════════
echo "Modifying devcontainer.json..."

# jq がなければ sed で代替
if command -v jq &> /dev/null; then
  # jq を使用: postStartCommand を削除し、postCreateCommand を追加、waitFor を更新
  TMP_FILE=$(mktemp)
  jq 'del(.postStartCommand) | .postCreateCommand = "sudo /usr/local/bin/init-firewall.sh && .cc-multi-agent/setup-multiagent.sh" | .waitFor = "postCreateCommand"' \
    "$TARGET_DIR/.devcontainer/devcontainer.json" > "$TMP_FILE"
  mv "$TMP_FILE" "$TARGET_DIR/.devcontainer/devcontainer.json"
else
  # sed を使用: postStartCommand を postCreateCommand に置き換え、waitFor も更新
  sed -i 's|"postStartCommand": "sudo /usr/local/bin/init-firewall.sh"|"postCreateCommand": "sudo /usr/local/bin/init-firewall.sh \&\& .cc-multi-agent/setup-multiagent.sh"|g' \
    "$TARGET_DIR/.devcontainer/devcontainer.json"
  sed -i 's|"waitFor": "postStartCommand"|"waitFor": "postCreateCommand"|g' \
    "$TARGET_DIR/.devcontainer/devcontainer.json"
fi

echo "Modified devcontainer.json"

# ════════════════════════════════════════════════════════════════════
# .gitignore への追記
# ════════════════════════════════════════════════════════════════════
GITIGNORE="$TARGET_DIR/.gitignore"
MARKER="# cc-multi-agent"

if [ -f "$GITIGNORE" ]; then
  if grep -q "$MARKER" "$GITIGNORE"; then
    echo ".gitignore already contains cc-multi-agent entries, skipping..."
  else
    echo "" >> "$GITIGNORE"
    echo "$MARKER" >> "$GITIGNORE"
    echo ".devcontainer/" >> "$GITIGNORE"
    echo ".cc-multi-agent/" >> "$GITIGNORE"
    echo "Added entries to .gitignore"
  fi
else
  cat > "$GITIGNORE" << EOF
$MARKER
.devcontainer/
.cc-multi-agent/
EOF
  echo "Created .gitignore"
fi

# ════════════════════════════════════════════════════════════════════
# .cc-multi-agent/ 作成
# ════════════════════════════════════════════════════════════════════
echo "Creating .cc-multi-agent/ directory..."

CC_DIR="$TARGET_DIR/.cc-multi-agent"
mkdir -p "$CC_DIR"/{instructions,queue/tasks,queue/reports,logs,context,memory,skills}

# ファイルをコピー（ソースは cc-multi-agent/、コピー先は .cc-multi-agent/）
cp "$SCRIPT_DIR/cc-multi-agent/CLAUDE.md" "$CC_DIR/"
cp "$SCRIPT_DIR/cc-multi-agent/README.md" "$CC_DIR/"
cp "$SCRIPT_DIR/cc-multi-agent/config.toon" "$CC_DIR/"
cp "$SCRIPT_DIR/cc-multi-agent/setup-multiagent.sh" "$CC_DIR/"
cp "$SCRIPT_DIR/cc-multi-agent/start.sh" "$CC_DIR/"
cp "$SCRIPT_DIR/cc-multi-agent/gh-readonly.sh" "$CC_DIR/"
cp "$SCRIPT_DIR/cc-multi-agent/dashboard.md" "$CC_DIR/"

cp "$SCRIPT_DIR/cc-multi-agent/instructions/president.md" "$CC_DIR/instructions/"
cp "$SCRIPT_DIR/cc-multi-agent/instructions/boss.md" "$CC_DIR/instructions/"
cp "$SCRIPT_DIR/cc-multi-agent/instructions/employee.md" "$CC_DIR/instructions/"

cp "$SCRIPT_DIR/cc-multi-agent/context/README.md" "$CC_DIR/context/"
cp "$SCRIPT_DIR/cc-multi-agent/memory/global_context.md" "$CC_DIR/memory/"

# skills ディレクトリがあればコピー
if [ -d "$SCRIPT_DIR/cc-multi-agent/skills/skill-creator" ]; then
  cp -r "$SCRIPT_DIR/cc-multi-agent/skills/skill-creator" "$CC_DIR/skills/"
fi

# 実行権限を付与
chmod +x "$CC_DIR/setup-multiagent.sh"
chmod +x "$CC_DIR/start.sh"
chmod +x "$CC_DIR/gh-readonly.sh"

echo "Created .cc-multi-agent/ with all files"

# ════════════════════════════════════════════════════════════════════
# 完了メッセージ
# ════════════════════════════════════════════════════════════════════
echo ""
echo "✅ Setup completed!"
echo ""
echo "Next steps:"
echo "  1. Open the project in VS Code"
echo "  2. Click 'Reopen in Container' when prompted"
echo "  3. In the container, run: .cc-multi-agent/start.sh"
echo "  4. Connect to president: tmux attach -t president"
echo ""
