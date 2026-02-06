#!/bin/bash
set -euo pipefail

AGENTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# ════════════════════════════════════════════════════════════════════
# オプション解析
# ════════════════════════════════════════════════════════════════════
SETUP_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -s|--setup-only)
      SETUP_ONLY=true
      shift
      ;;
    -d|--destroy)
      tmux kill-session -t multiagent 2>/dev/null || true
      tmux kill-session -t president 2>/dev/null || true
      echo "Sessions destroyed."
      exit 0
      ;;
    -h|--help)
      echo "Usage: start.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  -s, --setup-only  Create sessions without starting Claude Code"
      echo "  -d, --destroy     Kill all sessions"
      echo "  -h, --help        Show this help"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ════════════════════════════════════════════════════════════════════
# 前回記録のバックアップ
# ════════════════════════════════════════════════════════════════════
if [ -f "$AGENTS_DIR/dashboard.md" ]; then
  if grep -q "task_" "$AGENTS_DIR/dashboard.md" 2>/dev/null; then
    BACKUP_DIR="$AGENTS_DIR/logs/backup_$(date '+%Y%m%d_%H%M%S')"
    mkdir -p "$BACKUP_DIR"
    cp "$AGENTS_DIR/dashboard.md" "$BACKUP_DIR/" 2>/dev/null || true
    cp -r "$AGENTS_DIR/queue/reports" "$BACKUP_DIR/" 2>/dev/null || true
    cp -r "$AGENTS_DIR/queue/tasks" "$BACKUP_DIR/" 2>/dev/null || true
  fi
fi

# ════════════════════════════════════════════════════════════════════
# 既存セッションクリーンアップ
# ════════════════════════════════════════════════════════════════════
tmux kill-session -t multiagent 2>/dev/null || true
tmux kill-session -t president 2>/dev/null || true

# ════════════════════════════════════════════════════════════════════
# キューファイル初期化
# ════════════════════════════════════════════════════════════════════
mkdir -p "$AGENTS_DIR/queue/tasks" "$AGENTS_DIR/queue/reports" "$AGENTS_DIR/logs"

for i in {1..8}; do
  cat > "$AGENTS_DIR/queue/tasks/employee${i}.toon" << EOF
# employee${i} 専用タスクファイル
task:
  task_id: null
  description: null
  status: idle
EOF
  cat > "$AGENTS_DIR/queue/reports/employee${i}_report.toon" << EOF
# employee${i} 報告ファイル
report:
  employee: ${i}
  task_id: null
  status: idle
EOF
done

cat > "$AGENTS_DIR/queue/president_to_boss.toon" << 'EOF'
# president → boss 指示キュー
queue: []
EOF

cat > "$AGENTS_DIR/queue/boss_to_employees.toon" << 'EOF'
# 全 employee の割り当て状況
assignments[8]{employee,task_id,status}:
  1,null,idle
  2,null,idle
  3,null,idle
  4,null,idle
  5,null,idle
  6,null,idle
  7,null,idle
  8,null,idle
EOF

# ════════════════════════════════════════════════════════════════════
# dashboard.md 初期化
# ════════════════════════════════════════════════════════════════════
TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
cat > "$AGENTS_DIR/dashboard.md" << EOF
# 📊 進捗報告
最終更新: ${TIMESTAMP}

## 🚨 要対応 - ご判断をお待ちしております
なし

## 🔄 進行中
なし

## ✅ 完了
| 時刻 | タスク | 結果 |
|------|--------|------|

## 🎯 スキル化候補 - 承認待ち
なし

## 🛠️ 生成されたスキル
なし

## ⏸️ 待機中
なし

## ❓ 質問事項
なし
EOF

# ════════════════════════════════════════════════════════════════════
# multiagent セッション作成（3x3 ペイン）
# ════════════════════════════════════════════════════════════════════
tmux new-session -d -s multiagent -n agents
cd "$AGENTS_DIR"

# 3列に分割
tmux split-window -h -t multiagent:0
tmux split-window -h -t multiagent:0

# 各列を3行に分割
tmux select-pane -t multiagent:0.0 && tmux split-window -v && tmux split-window -v
tmux select-pane -t multiagent:0.3 && tmux split-window -v && tmux split-window -v
tmux select-pane -t multiagent:0.6 && tmux split-window -v && tmux split-window -v

# ペインタイトル設定
PANE_TITLES=("boss" "employee1" "employee2" "employee3" "employee4" "employee5" "employee6" "employee7" "employee8")
for i in {0..8}; do
  tmux select-pane -t "multiagent:0.$i" -T "${PANE_TITLES[$i]}"
  tmux send-keys -t "multiagent:0.$i" "cd '$AGENTS_DIR' && clear" Enter
done

# boss ペインの背景色を変更
tmux select-pane -t multiagent:0.0 -P 'bg=#1a1a2e'

# ════════════════════════════════════════════════════════════════════
# president セッション作成
# ════════════════════════════════════════════════════════════════════
tmux new-session -d -s president
tmux send-keys -t president "cd '$AGENTS_DIR' && clear" Enter

# ════════════════════════════════════════════════════════════════════
# Claude Code 起動（--setup-only でスキップ）
# ════════════════════════════════════════════════════════════════════
if [ "$SETUP_ONLY" = false ]; then
  # president 起動
  tmux send-keys -t president "claude --dangerously-skip-permissions"
  tmux send-keys -t president Enter

  sleep 1

  # boss + employee 起動
  for i in {0..8}; do
    tmux send-keys -t "multiagent:0.$i" "claude --dangerously-skip-permissions"
    tmux send-keys -t "multiagent:0.$i" Enter
  done

  echo "Waiting for Claude Code to start..."
  sleep 5

  # ════════════════════════════════════════════════════════════════════
  # 指示書の自動読み込み
  # ════════════════════════════════════════════════════════════════════
  # president
  tmux send-keys -t president "instructions/president.md を読んで役割を理解してください。"
  sleep 0.5
  tmux send-keys -t president Enter

  sleep 2

  # boss
  tmux send-keys -t "multiagent:0.0" "instructions/boss.md を読んで役割を理解してください。"
  sleep 0.5
  tmux send-keys -t "multiagent:0.0" Enter

  sleep 2

  # employee1-8
  for i in {1..8}; do
    tmux send-keys -t "multiagent:0.$i" "instructions/employee.md を読んで役割を理解してください。あなたは employee${i} です。"
    sleep 0.3
    tmux send-keys -t "multiagent:0.$i" Enter
    sleep 0.5
  done

  echo "All agents started and instructions loaded."
fi

# ════════════════════════════════════════════════════════════════════
# 完了メッセージ
# ════════════════════════════════════════════════════════════════════
echo ""
echo "Sessions created:"
tmux list-sessions
echo ""
echo "To connect:"
echo "  President: tmux attach -t president"
echo "  Workers:   tmux attach -t multiagent"
echo ""
