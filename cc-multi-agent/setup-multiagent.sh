#!/bin/bash
set -euo pipefail

WORKSPACE_DIR="/workspace"
CC_DIR="$WORKSPACE_DIR/.cc-multi-agent"

# tmux は Dockerfile でプリインストール済み

# gh コマンド read-only wrapper を設定
echo "alias gh=\"$CC_DIR/gh-readonly.sh\"" >> ~/.zshrc
echo "alias gh=\"$CC_DIR/gh-readonly.sh\"" >> ~/.bashrc

# ~/.claude/CLAUDE.md に TOON ガイドを追記（未追記の場合のみ）
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
mkdir -p "$HOME/.claude"
mkdir -p "$HOME/.claude/skills"

if ! grep -q "## TOON フォーマット" "$CLAUDE_MD" 2>/dev/null; then
  cat >> "$CLAUDE_MD" << 'EOF'

## TOON フォーマット

このプロジェクトでは、エージェント間通信に **TOON (Token-Oriented Object Notation)** を使用します。

- **公式リポジトリ**: https://github.com/toon-format/toon
- **特徴**: LLM 向けに最適化（JSON 比で約40%トークン削減）
- **構文**: YAML のインデント + CSV の表形式

### 基本構文

単純なキー・バリュー（YAML と同じ）:
```toon
context:
  task: タスクの説明
  priority: high
```

配列（`[N]{fields}:` でスキーマ宣言 + CSV 形式）:
```toon
tasks[3]{id,name,status}:
  1,機能A実装,done
  2,機能B実装,doing
  3,テスト作成,pending
```

- `[3]` = 要素数
- `{id,name,status}` = フィールド名
- 各行がオブジェクト

### 使用ファイル

- 指示: `queue/*.toon`
- 報告: `queue/reports/*.toon`
- 設定: `config.toon`
EOF
  echo "TOON guide added to $CLAUDE_MD"
fi

echo "Multi-agent setup completed."
