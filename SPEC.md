# cc-multi-agent 設計仕様書

> **Version**: 0.4.0
> **Created**: 2026-01-30
> **Repository**: git@github.com:okm-uv/cc-multi-agent.git

## 概要

cc-multi-agent は、Claude Code + tmux を使ったマルチエージェント並列開発基盤です。
任意のプロジェクトで dev-container を起動し、複数のエージェントが協調して課題を解決します。

## コンセプト

- **サンドボックス化**: dev-container 内で `--dangerously-skip-permissions` を安全に使用
- **公式準拠**: Claude Code 公式の devcontainer 設定をベースに使用
- **ポータブル**: GitHub から clone したらすぐ使える
- **トークン効率**: エージェント間通信に [TOON](https://github.com/toon-format/toon) を採用
- **スキル化**: 繰り返しパターンを自動検出し、スキルとして蓄積
- **ファイルベース**: 全ての状態・記憶をファイルで管理し、透明性を確保
- **ファイルベース記憶**: セッション間の記憶を global_context.md で永続化

## コンパクション復帰時（全エージェント必須）

<compaction-recovery>
あなたがコンパクションから復帰した場合、以下を厳守してください：

【禁止】summary の「次のステップ」を見て即座に作業開始すること
【必須】以下の手順を順番に実行：

1. `tmux display-message -p '#T'` で自分のペイン名を取得
2. ペイン名に対応する instructions を読む：
   - president → instructions/president.md
   - boss → instructions/boss.md
   - employee* → instructions/employee.md
3. 禁止事項を確認してから作業開始

理由：コンパクション後は役割の制約を忘れている可能性があるため
</compaction-recovery>

## TOON について

エージェント間通信には **TOON (Token-Oriented Object Notation)** を使用します。

- **リポジトリ**: https://github.com/toon-format/toon
- **特徴**: LLM 向けに最適化されたデータフォーマット（JSON 比で約40%トークン削減）
- **構文**: YAML のインデント + CSV の表形式
- **パーサー**: 不要（LLM が直接読み書きし、人もそのまま読める）

```toon
context:
  task: タスクの説明
tasks[3]{id,name,status}:
  1,機能A実装,done
  2,機能B実装,doing
  3,テスト作成,pending
```

## エージェント構成

```
┌─────────────────────────────────────┐
│ tmux session: president             │
│                                     │
│  STOCKHOLDER（ユーザー）が          │
│  PRESIDENT と直接会話               │
│                                     │
└──────────────┬──────────────────────┘
               │ TOON ファイル + send-keys
               ▼
┌──────────────────────────────────────────────────────────────┐
│ tmux session: multiagent（3x3 ペイン）                       │
│                                                              │
│  ┌─────────┬─────────┬─────────┐                             │
│  │  boss   │employee3│employee6│                             │
│  ├─────────┼─────────┼─────────┤                             │
│  │employee1│employee4│employee7│                             │
│  ├─────────┼─────────┼─────────┤                             │
│  │employee2│employee5│employee8│                             │
│  └─────────┴─────────┴─────────┘                             │
│                                                              │
│  ペイン参照: multiagent:0.0 (boss), multiagent:0.1-8 (E1-8)  │
└──────────────────────────────────────────────────────────────┘
```

| 役割 | 責任 |
|------|------|
| stockholder | ユーザー。president のターミナルで直接会話し、目標・要件を指示 |
| president | プロジェクト全体の方針決定、boss への指示、stockholder への報告 |
| boss | タスク分解、employee への割り当て、進捗管理、dashboard.md 更新 |
| employee | 実際のコーディング、調査、テスト実行 |

**重要**: stockholder は president の tmux セッションで直接 Claude Code と対話します。
ファイル経由の指示（`stockholder_to_president.toon`）は不要です。

## 使用フロー

```bash
# 1. cc-multi-agent を clone（任意の場所でOK）
git clone git@github.com:okm-uv/cc-multi-agent.git

# 2. 対象プロジェクトでセットアップ
cd /path/to/my-project
/path/to/cc-multi-agent/setup.sh

# 3. VS Code で開く → "Reopen in Container"
code .

# 4. コンテナ内でエージェント起動
.cc-multi-agent/start.sh

# 5. stockholder として president に指示を出す
```

## リポジトリ構成

```
cc-multi-agent/                       # このリポジトリ
├── README.md                         # リポジトリ説明（人間・LLM向け）
├── SPEC.md                           # 詳細設計仕様書
├── TODO.md                           # 実装タスクリスト
├── setup.sh                          # セットアップスクリプト
└── cc-multi-agent/                   # コピー元ファイル群
    ├── README.md                     # エージェント向けクイックリファレンス
    ├── CLAUDE.md                     # エージェント共通ルール
    ├── config.toon                   # 設定ファイル
    ├── dashboard.md                  # 進捗ダッシュボード
    ├── start.sh                      # エージェント起動スクリプト
    ├── setup-multiagent.sh           # tmux 等の追加インストール
    ├── gh-readonly.sh                # gh コマンド read-only wrapper
    ├── instructions/                 # 各エージェントの指示書
    ├── queue/                        # エージェント間通信
    ├── context/                      # プロジェクト固有コンテキスト
    ├── memory/                       # セッション間記憶
    └── skills/                       # ローカルスキル
```

**注意**: リポジトリ内は `cc-multi-agent/`（見えるフォルダ）、導入先は `.cc-multi-agent/`（隠しフォルダ）になります。

## 導入先に生成されるファイル構成

対象プロジェクトに以下が生成されます：

```
my-project/
├── .devcontainer/                    # 公式からダウンロード + カスタマイズ
│   ├── devcontainer.json             # postStartCommand → postCreateCommand に変更
│   ├── Dockerfile                    # 公式 + tmux 追加
│   └── init-firewall.sh              # 公式のまま
├── .cc-multi-agent/                  # マルチエージェント関連（隠しフォルダ）
│   ├── README.md                     # エージェント向けクイックリファレンス
│   ├── CLAUDE.md                     # プロジェクト内 CLAUDE.md（階層構造・通信プロトコル）
│   ├── config.toon                   # 設定ファイル
│   ├── setup-multiagent.sh           # tmux 等の追加インストール
│   ├── start.sh                      # エージェント起動スクリプト
│   ├── gh-readonly.sh                # gh コマンド read-only wrapper
│   ├── instructions/
│   │   ├── president.md              # president の指示書
│   │   ├── boss.md                   # boss の指示書
│   │   └── employee.md               # employee の指示書
│   ├── queue/
│   │   ├── president_to_boss.toon    # president → boss 指示
│   │   ├── boss_to_employees.toon    # 全 employee の割り当て状況一覧
│   │   ├── tasks/
│   │   │   └── employee{1-8}.toon    # boss → employee 割り当て（各自専用）
│   │   └── reports/
│   │       └── employee{1-8}_report.toon  # employee → boss 報告
│   ├── logs/                         # ログ・バックアップ
│   ├── context/
│   │   ├── README.md                 # コンテキストファイルの説明
│   │   └── {project}.md              # プロジェクト固有のコンテキスト
│   ├── memory/
│   │   └── global_context.md         # stockholder の好み・重要な意思決定
│   ├── skills/                       # ローカルスキル（プロジェクト固有）
│   │   └── {skill-name}/
│   │       └── SKILL.md
│   └── dashboard.md                  # 進捗ダッシュボード
├── .gitignore                        # 追記（初回のみ）
└── ... (既存のプロジェクトファイル)
```

## setup.sh の挙動

```
setup.sh 実行
    │
    ▼
.devcontainer/ 存在する？
    │
    ├─ Yes → 「上書きしますか？」確認
    │           │
    │           ├─ Yes → 続行
    │           └─ No  → エラー終了
    │
    └─ No → 続行
    │
    ▼
公式 devcontainer をダウンロード
    │ - devcontainer.json
    │ - Dockerfile
    │ - init-firewall.sh
    │
    ▼
Dockerfile を修正
    │ - tmux を追加（公式は含まないため）
    │ - locales を追加 + locale-gen 実行
    │ - LANG/LC_ALL 環境変数を設定
    │
    ▼
devcontainer.json を修正
    │ - postStartCommand → postCreateCommand に変更
    │ - setup-multiagent.sh を追加
    │ - waitFor を postCreateCommand に変更
    │
    ▼
.gitignore に追記済み？
    │
    ├─ Yes → スキップ
    └─ No  → 追記
    │
    ▼
.cc-multi-agent/ 作成
    │
    ▼
完了
```

## devcontainer 設定

### 公式からダウンロード

```bash
CLAUDE_CODE_REPO="https://raw.githubusercontent.com/anthropics/claude-code/main/.devcontainer"

curl -o .devcontainer/devcontainer.json "$CLAUDE_CODE_REPO/devcontainer.json"
curl -o .devcontainer/Dockerfile "$CLAUDE_CODE_REPO/Dockerfile"
curl -o .devcontainer/init-firewall.sh "$CLAUDE_CODE_REPO/init-firewall.sh"
```

### Dockerfile の修正

公式 Dockerfile に以下を追加します（node ユーザーは sudo が制限されているため）：

```bash
# tmux を追加（apt-get の行に追加）
sed -i 's/nano \\/nano tmux \\/' Dockerfile

# locale を追加
sed -i 's/nano tmux \\/nano tmux locales \\/' Dockerfile

# locale 生成
sed -i '/apt-get clean/a RUN sed -i "/en_US.UTF-8/s/^# //" /etc/locale.gen && locale-gen' Dockerfile

# 環境変数設定
sed -i '/ENV DEVCONTAINER=true/a ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8' Dockerfile

# タイムゾーン設定（JST）
sed -i '/ENV LANG=en_US.UTF-8/a ENV TZ=Asia/Tokyo' Dockerfile
```

### devcontainer.json の修正

公式は `postStartCommand`（毎回実行）を使用していますが、setup-multiagent.sh は一度だけ実行すれば良いため、`postCreateCommand` に変更します。

```json
// 変更前（公式）
"postStartCommand": "sudo /usr/local/bin/init-firewall.sh",
"waitFor": "postStartCommand"

// 変更後
"postCreateCommand": "sudo /usr/local/bin/init-firewall.sh && .cc-multi-agent/setup-multiagent.sh",
"waitFor": "postCreateCommand"
```

### setup-multiagent.sh の内容

```bash
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
```

### 認証方式

公式の方式に従い、volume マウントで認証情報を永続化します：

```json
"mounts": [
  "source=claude-code-config-${devcontainerId},target=/home/node/.claude,type=volume"
],
"containerEnv": {
  "CLAUDE_CONFIG_DIR": "/home/node/.claude"
}
```

- 初回起動時: `claude login` でログイン
- 以降: volume に保存され、コンテナ再起動後も維持

## gh コマンド read-only 制限

### gh-readonly.sh

```bash
#!/bin/bash

# ホワイトリスト方式（より安全）
COMMAND="$1"
SUBCOMMAND="$2"

case "$COMMAND:$SUBCOMMAND" in
  issue:list|issue:view|issue:status|\
  pr:list|pr:view|pr:status|pr:diff|pr:checks|\
  repo:view|repo:list|\
  search:*|browse:*)
    /usr/bin/gh "$@"
    ;;
  api:*)
    # api は GET のみ、かつ危険なメソッドを除外
    if [[ "$*" =~ (-X|--method)[[:space:]]*(POST|PUT|PATCH|DELETE) ]]; then
      echo "Error: Only GET requests allowed" >&2
      exit 1
    fi
    /usr/bin/gh "$@"
    ;;
  *)
    echo "Error: '$COMMAND $SUBCOMMAND' is not allowed" >&2
    exit 1
    ;;
esac
```

## 通信プロトコル

### イベント駆動通信（TOON + send-keys）

- **ポーリング禁止**: API コスト節約のため
- **指示・報告**: TOON ファイルに記述
- **通知**: tmux send-keys で相手を起こす（必ず Enter を使用、C-m 禁止）

### 報告の流れ（割り込み防止）

- **下→上への報告**: dashboard.md 更新のみ（send-keys 禁止）
- **上→下への指示**: TOON + send-keys で起こす
- **stockholder への報告**: boss が dashboard.md を更新
- 理由: stockholder の入力中に割り込みが発生するのを防ぐ

### tmux send-keys の正しい使い方（超重要）

#### 絶対禁止パターン

```bash
# ダメな例1: 1行で書く
tmux send-keys -t multiagent:0.0 'メッセージ' Enter

# ダメな例2: && で繋ぐ
tmux send-keys -t multiagent:0.0 'メッセージ' && tmux send-keys -t multiagent:0.0 Enter
```

**理由**: 1回のBash呼び出しでEnterが正しく解釈されないため

#### 正しい方法（2回に分ける）

**【1回目】** メッセージを送る：
```bash
tmux send-keys -t multiagent:0.0 'queue/president_to_boss.toon に新しい指示があります。確認して実行してください。'
```

**【2回目】** Enter を送る：
```bash
tmux send-keys -t multiagent:0.0 Enter
```

### タイムスタンプの取得方法（必須）

タイムスタンプは **必ず `date` コマンドで取得** してください。自分で推測してはいけません。

```bash
# dashboard.md の最終更新（時刻のみ）
date "+%Y-%m-%d %H:%M"
# 出力例: 2026-01-30 15:46

# TOON 用（ISO 8601形式）
date "+%Y-%m-%dT%H:%M:%S"
# 出力例: 2026-01-30T15:46:30
```

### エージェントの状態確認

指示を送る前に、相手が処理中でないか確認します。

```bash
tmux capture-pane -t multiagent:0.0 -p | tail -20
```

| 状態 | インジケータ |
|------|-------------|
| busy | `thinking`, `Esc to interrupt`, `Effecting…`, `Boondoggling…`, `Puzzling…`, `Calculating…`, `Fermenting…`, `Crunching…` |
| idle | `❯ ` (プロンプト表示), `bypass permissions on` |

処理中の場合は完了を待つか、急ぎなら割り込み可。

### 未処理報告スキャン（通信ロスト対策）

employee の send-keys 通知が届かない場合があります（boss が処理中だった等）。
安全策として、起こされたら全報告をスキャンします。

```bash
# 全報告ファイルの一覧取得
ls -la queue/reports/
```

各報告ファイルについて：
1. `task_id` を確認
2. dashboard.md の「進行中」「完了」と照合
3. dashboard に未反映の報告があれば処理する

### 同一ファイル書き込み禁止（RACE-001）

複数の employee が同一ファイルに書き込むことは禁止です。

```
❌ 禁止:
  employee1 → output.md
  employee2 → output.md  ← 競合

✅ 正しい:
  employee1 → output_1.md
  employee2 → output_2.md
```

競合リスクがある場合：
1. status を `blocked` に設定
2. notes に「競合リスクあり」と記載
3. boss に確認を求める

### 並列化ルール

| タスクの種類 | 実行方法 |
|-------------|---------|
| 独立タスク | 複数 employee に同時割り当て |
| 依存タスク | 順番に実行 |

**1 employee = 1 タスク（完了まで）**

employee には一度に1つのタスクのみ割り当てます。完了報告を受けてから次のタスクを割り当てます。

### 「起こされたら全確認」方式

Claude Code は「待機」できません。プロンプト待ちは「停止」です。

#### やってはいけないこと

```
employee を起こした後、「報告を待つ」と言う
→ employee が send-keys しても処理できない
```

#### 正しい動作

1. employee を起こす
2. 「ここで停止します」と言って処理終了
3. employee が send-keys で起こしてくる
4. 全報告ファイルをスキャン
5. 状況把握してから次アクション

### ファイル構成

| ファイル | 用途 |
|----------|------|
| `queue/president_to_boss.toon` | president → boss への指示 |
| `queue/boss_to_employees.toon` | 全 employee の割り当て状況一覧 |
| `queue/tasks/employee{1-8}.toon` | boss → employee への割り当て（各自専用） |
| `queue/reports/employee{1-8}_report.toon` | employee → boss への報告 |
| `dashboard.md` | 全体進捗（stockholder 向け） |
| `memory/global_context.md` | stockholder の好み・重要な意思決定 |

**注意**: stockholder → president はファイル経由ではなく、直接会話で行います。

### 通信フォーマット例

**president_to_boss.toon**
```toon
directive:
  id: 1
  priority: high
  description: ユーザー認証機能を実装してください
goals[2]{id,description}:
  1,ログイン・ログアウト機能
  2,セッション管理
```

**employee{N}.toon**
```toon
assignment:
  employee: 1
  task_id: 101
  description: ログインAPIの実装
files[2]{path,action}:
  src/api/auth.ts,create
  src/api/auth.test.ts,create
```

**employee{N}_report.toon**
```toon
report:
  employee: 1
  task_id: 101
  timestamp: 2026-01-30T15:46:30
  status: done
  summary: ログインAPI実装完了
changes[2]{path,lines}:
  src/api/auth.ts,+85
  src/api/auth.test.ts,+42
skill_candidate:
  found: false
```

**employee{N}_report.toon（スキル化候補あり）**
```toon
report:
  employee: 1
  task_id: 102
  timestamp: 2026-01-30T16:30:00
  status: done
  summary: 認証ミドルウェア実装完了
changes[1]{path,lines}:
  src/middleware/auth.ts,+120
skill_candidate:
  found: true
  name: auth-middleware-generator
  description: 認証ミドルウェアのボイラープレートを生成
  reason: 同じパターンを3回実行した
```

**boss_to_employees.toon（全 employee の割り当て状況一覧）**
```toon
# 全 employee の割り当て状況
assignments[8]{employee,task_id,description,status}:
  1,101,ログインAPI実装,in_progress
  2,102,認証ミドルウェア,done
  3,null,null,idle
  4,null,null,idle
  5,null,null,idle
  6,null,null,idle
  7,null,null,idle
  8,null,null,idle
```

## tmux セッション構成

### 2セッション構成

```
【president セッション】stockholder との対話用
  └─ Pane 0: president

【multiagent セッション】boss + employee（3x3 = 9ペイン）
  ┌─────────┬─────────┬─────────┐
  │  boss   │employee3│employee6│  Pane 0, 3, 6
  ├─────────┼─────────┼─────────┤
  │employee1│employee4│employee7│  Pane 1, 4, 7
  ├─────────┼─────────┼─────────┤
  │employee2│employee5│employee8│  Pane 2, 5, 8
  └─────────┴─────────┴─────────┘
```

### ペイン参照

| エージェント | tmux ターゲット |
|-------------|----------------|
| president | `president:0` |
| boss | `multiagent:0.0` |
| employee1 | `multiagent:0.1` |
| employee2 | `multiagent:0.2` |
| ... | ... |
| employee8 | `multiagent:0.8` |

### start.sh の処理

```bash
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
```

## config.toon

```toon
# .cc-multi-agent/config.toon

version: 1.0

language: ja

project:
  name:
  root: /workspace

logging:
  level: info
  path: logs/
```

**注意**: employee 数は 8 人固定です。

## stockholder お伺いルール（最重要）

```
████████████████████████████████████████████████████████████
█  stockholder への確認事項は全て「🚨 要対応」に集約！  █
████████████████████████████████████████████████████████████
```

- stockholder の判断が必要なものは **全て** dashboard.md の「🚨 要対応」セクションに書く
- 詳細セクションに書いても、**必ず要対応にもサマリを書く**
- 対象: スキル化候補、著作権問題、技術選択、ブロック事項、質問事項
- **これを忘れると stockholder に怒られます。絶対に忘れないでください。**

### 要対応に記載すべき事項

| 種別 | 例 |
|------|-----|
| スキル化候補 | 「スキル化候補 4件【承認待ち】」 |
| 著作権問題 | 「ASCII アート著作権確認【判断必要】」 |
| 技術選択 | 「DB 選定【PostgreSQL vs MySQL】」 |
| ブロック事項 | 「API 認証情報不足【作業停止中】」 |
| 質問事項 | 「予算上限の確認【回答待ち】」 |

## スキル化候補

### 判断基準

| 基準 | 該当したらスキル化候補 |
|------|------------------------|
| 他プロジェクトでも使えそう | ✅ |
| 同じパターンを2回以上実行 | ✅ |
| 他の employee にも有用 | ✅ |
| 手順や知識が必要な作業 | ✅ |

### employee の責務

employee は報告時に必ず `skill_candidate` を記載します（省略禁止）。

```toon
report:
  employee: 1
  task_id: 101
  status: done
  summary: ログインAPI実装完了
skill_candidate:
  found: false
```

`found: true` の場合は詳細も記載：

```toon
skill_candidate:
  found: true
  name: api-auth-generator
  description: 認証API のボイラープレートを生成
  reason: 同じパターンを3回実行した
```

### boss の責務

- employee からの報告で `skill_candidate` を確認
- 重複チェック
- dashboard.md の「スキル化候補」セクションに記載
- 「🚨 要対応」セクションにもサマリを記載

### president の責務

- スキル化候補を承認
- スキル設計書を作成
- 承認後、boss に作成を指示

## dashboard.md の更新責任

**boss は dashboard.md を更新する唯一の責任者です。**

president も employee も dashboard.md を更新しません。boss のみが更新します。

### 更新タイミング

| タイミング | 更新セクション | 内容 |
|------------|----------------|------|
| タスク受領時 | 進行中 | 新規タスクを「進行中」に追加 |
| 完了報告受信時 | 完了 | 完了したタスクを「完了」に移動 |
| 要対応事項発生時 | 🚨 要対応 | stockholder の判断が必要な事項を追加 |

### なぜ boss だけが更新するのか

1. **単一責任**: 更新者が1人なら競合しない
2. **情報集約**: boss は全 employee の報告を受ける立場
3. **品質保証**: 更新前に全報告をスキャンし、正確な状況を反映

## instructions（指示書）

各指示書は TOON Front Matter + Markdown 形式です。

### 共通ルール

- **口調**: 敬体（です・ます）で統一
- **通信**: TOON + send-keys
- **報告**: dashboard.md 更新（下→上）
- **指示**: TOON + send-keys（上→下）
- **ペルソナ**: 言葉遣いは敬体、作業品質はプロフェッショナル

### president.md

```toon
---
role: president
version: 1.0

forbidden_actions[5]{id,action,description}:
  F001,self_execute_task,自分でファイルを読み書きしてタスクを実行
  F002,direct_employee_command,boss を通さず employee に直接指示
  F003,use_task_agents,Task agents を使用
  F004,polling,ポーリング（待機ループ）
  F005,skip_context_reading,コンテキストを読まずに作業開始

workflow[5]{step,action,note}:
  1,receive_command,stockholder から指示を受ける
  2,write_toon,queue/president_to_boss.toon に書く
  3,send_keys,multiagent:0.0 (boss) に通知（2回に分ける）
  4,wait_for_report,boss が dashboard.md を更新するのを待つ
  5,report_to_stockholder,dashboard.md を読んで stockholder に報告

files:
  command_queue: queue/president_to_boss.toon
  dashboard: dashboard.md
---
```

**責任:**
- stockholder からの指示を受けて方針決定
- boss への指示のみ（employee への直接指示禁止）
- スキル化候補の承認とスキル設計書の作成
- stockholder への確認が必要な判断は dashboard.md 経由で報告

**即座委譲・即座終了の原則:**
長い作業は自分でやらず、即座に boss に委譲して終了してください。
これにより stockholder は次のコマンドを入力できます。

```
stockholder: 指示 → president: TOON書く → send-keys → 即終了
                                              ↓
                                        stockholder: 次の入力可能
                                              ↓
                                  boss・employee: バックグラウンドで作業
                                              ↓
                                  dashboard.md 更新で報告
```

**実行計画は boss に任せる:**
president が決めるのは「目的」と「成果物」のみです。
以下は全て boss の裁量であり、president が指定してはいけません：
- employee の人数
- 担当者の割り当て
- 検証方法・ペルソナ設計・シナリオ設計
- タスクの分割方法

```toon
# ❌ 悪い例（president が実行計画まで指定）
directive:
  description: install.bat を検証してください
  employee_count: 5
  assignments[2]{employee,persona}:
    1,Windows専門家
    2,WSL専門家

# ✅ 良い例（boss に任せる）
directive:
  description: install.bat のフルインストールフローをシミュレーション検証してください。手順の抜け漏れ・ミスを洗い出してください。
# 人数・担当・方法は書かない。boss が判断する。
```

### boss.md

```toon
---
role: boss
version: 1.0

forbidden_actions[5]{id,action,description}:
  F001,self_execute_task,自分でファイルを読み書きしてタスクを実行
  F002,direct_stockholder_report,president を通さず stockholder に直接報告
  F003,use_task_agents,Task agents を使用
  F004,polling,ポーリング（待機ループ）
  F005,skip_context_reading,コンテキストを読まずにタスク分解

workflow_receive[8]{step,action,note}:
  1,receive_wakeup,president から send-keys で起こされる
  2,read_toon,queue/president_to_boss.toon を読む
  3,update_dashboard,dashboard.md の「進行中」を更新
  4,analyze_and_plan,指示を目的として受け取り実行計画を設計
  5,decompose_tasks,タスクを分解
  6,write_toon,queue/tasks/employee{N}.toon に書く
  7,send_keys,各 employee に通知（2回に分ける）
  8,stop,処理を終了しプロンプト待ち

workflow_report[3]{step,action,note}:
  1,receive_wakeup,employee から send-keys で起こされる
  2,scan_all_reports,queue/reports/ の全報告をスキャン
  3,update_dashboard,dashboard.md を更新（president への send-keys は行わない）

files:
  input: queue/president_to_boss.toon
  assignments: queue/boss_to_employees.toon
  task_template: queue/tasks/employee{N}.toon
  report_pattern: queue/reports/employee{N}_report.toon
  dashboard: dashboard.md
---
```

**責任:**
- タスク分解と employee への割り当て
- 進捗管理と dashboard.md の更新（唯一の更新責任者）
- スキル化候補の収集と dashboard.md への記載

**タスク分解の前に考えること:**
president の指示は「目的」です。それをどう達成するかは boss が自ら設計します。

| # | 問い | 考えるべきこと |
|---|------|----------------|
| 1 | 目的分析 | stockholder が本当に欲しいものは？成功基準は？ |
| 2 | タスク分解 | どう分解すれば最も効率的か？並列可能か？依存関係は？ |
| 3 | 人数決定 | 何人の employee が最適か？1人で十分なら1人でよい |
| 4 | 観点設計 | レビューならどんな観点が有効か？ |
| 5 | リスク分析 | 競合（RACE-001）の恐れは？依存関係の順序は？ |

### employee.md

```toon
---
role: employee
version: 1.0

forbidden_actions[5]{id,action,description}:
  F001,direct_president_report,boss を通さず president に直接報告
  F002,direct_stockholder_contact,stockholder に直接話しかける
  F003,unauthorized_work,指示されていない作業を勝手に行う
  F004,polling,ポーリング（待機ループ）
  F005,skip_context_reading,コンテキストを読まずに作業開始

workflow[7]{step,action,note}:
  1,receive_wakeup,boss から send-keys で起こされる
  2,read_toon,queue/tasks/employee{N}.toon を読む（自分専用ファイルのみ）
  3,update_status,status を in_progress に更新
  4,execute_task,タスクを実行
  5,write_report,queue/reports/employee{N}_report.toon に報告を書く
  6,update_status,status を done に更新
  7,send_keys,boss に通知（2回に分ける・必須）

files:
  task: queue/tasks/employee{N}.toon
  report: queue/reports/employee{N}_report.toon
---
```

**責任:**
- 割り当てられたタスクの実行
- 報告ファイルの更新（skill_candidate 必須）
- 他の employee のタスクへの干渉禁止

**報告通知プロトコル（通信ロスト対策）:**

1. boss の状態確認: `tmux capture-pane -t multiagent:0.0 -p | tail -20`
2. idle なら send-keys、busy なら 10 秒待機してリトライ（最大3回）
3. 3回リトライしても busy なら send-keys を送信（報告ファイルは既に書いてあるので boss がスキャンで発見）

**ペルソナ設定:**
タスクに最適なペルソナを設定し、そのペルソナとして最高品質の作業を行います。

| カテゴリ | ペルソナ例 |
|----------|----------|
| 開発 | シニアソフトウェアエンジニア、QA エンジニア |
| ドキュメント | テクニカルライター、ビジネスライター |
| 分析 | データアナリスト、戦略アナリスト |

## .gitignore への追記

```gitignore
# cc-multi-agent
.devcontainer/
.cc-multi-agent/
```

## 競合時の挙動

| ファイル | 競合シナリオ | 対処 |
|----------|--------------|------|
| `.devcontainer/` | 既存あり | ユーザー確認 → No ならエラー終了 |
| `.gitignore` | 既存あり | 追記済みならスキップ、なければ追記 |
| `.cc-multi-agent/` | 既存あり | 上書き |

## セキュリティ考慮事項

1. **コンテナ分離**: dev-container 内で実行されるため、ホスト環境への影響を最小化
2. **ファイアウォール**: init-firewall.sh により、許可されたドメインのみへのアクセス
3. **gh 制限**: read-only wrapper により、意図しない変更を防止
4. **認証情報**: volume マウントにより、コンテナ内に閉じ込め

## コンテキスト読み込み手順

各エージェントは作業開始前に以下の順序でコンテキストを読み込みます。

### president

1. `.cc-multi-agent/CLAUDE.md` を読む
2. `memory/global_context.md` を読む（stockholder の好み・記憶）
3. `config.toon` でプロジェクト設定を確認
4. `dashboard.md` で現在状況を把握
5. 読み込み完了を報告してから作業開始

### boss

1. `.cc-multi-agent/CLAUDE.md` を読む
2. `memory/global_context.md` を読む
3. `config.toon` でプロジェクト設定を確認
4. `queue/president_to_boss.toon` で指示確認
5. タスクに `project` がある場合、`context/{project}.md` を読む
6. 読み込み完了を報告してから分解開始

### employee

1. `.cc-multi-agent/CLAUDE.md` を読む
2. `memory/global_context.md` を読む
3. `config.toon` でプロジェクト設定を確認
4. `queue/tasks/employee{N}.toon` で自分の指示確認
5. タスクに `project` がある場合、`context/{project}.md` を読む
6. `target_path` と関連ファイルを読む
7. ペルソナを設定
8. 読み込み完了を報告してから作業開始

## Summary 生成時の必須事項

コンパクション用の summary を生成する際は、以下を必ず含めてください：

1. **エージェントの役割**: president / boss / employee のいずれか
2. **主要な禁止事項**: そのエージェントの禁止事項リスト
3. **現在のタスク ID**: 作業中の task_id

これにより、コンパクション後も役割と制約を即座に把握できます。

## 記憶管理（memory/global_context.md）

stockholder の好みや重要な意思決定をファイルで永続化します。
コンパクション後も、このファイルを読めば文脈を復元できます。

**記憶すべきもの:**
- stockholder の好み（「シンプル好き」「過剰機能嫌い」等）
- 重要な意思決定と理由
- プロジェクト横断の知見
- 解決した問題と解決方法

**記憶しないもの:**
- 一時的なタスク詳細（TOON に書く）
- ファイルの中身（読めば分かる）
- 進行中タスクの詳細（dashboard.md に書く）

**更新タイミング:**
- stockholder が好みを表明した時
- 重要な意思決定をした時
- 問題が解決した時
- stockholder が「覚えておいて」と言った時

**更新責任者:** president（stockholder との会話から抽出して記録）

## dashboard.md テンプレート

```markdown
# 📊 進捗報告
最終更新: YYYY-MM-DD HH:MM

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
```

## context/README.md テンプレート

```markdown
# context ディレクトリ

プロジェクト固有のコンテキストを管理するディレクトリ。

## 目的
- プロジェクトごとの知識・決定事項を保存
- セッション間での情報共有
- 新規参加者（employee）への引継ぎ

## 使い方

### 新規プロジェクト追加時
1. `context/{project_id}.md` を作成
2. 下記テンプレートに沿って記載

### 作業開始時
1. `memory/global_context.md` を読む（システム全体の設定）
2. `context/{project_id}.md` を読む（プロジェクト固有情報）

## テンプレート

# {project_id}
最終更新: YYYY-MM-DD

## What（これは何か）
{1-2文で説明}

## Why（なぜやるのか）
- 目的:
- 成功の定義:

## Who（誰が関係するか）
- 責任者:
- 関係者:

## Constraints（制約）
- 期限:
- 予算:
- その他:

## Current State（今どこにいるか）
- ステータス: {未着手/進行中/レビュー中/完了}
- 進捗:
- 次のアクション:
- ブロッカー:

## Decisions（決まったこと）
| 日付 | 決定事項 | 理由 |
|------|----------|------|

## Notes（メモ）
{自由記述}
```

## スキル設計書フォーマット

スキルは `/home/node/.claude/skills/{skill-name}/SKILL.md` に保存します（devcontainer 内グローバル）。
プロジェクト固有のスキルは `.cc-multi-agent/skills/{skill-name}/SKILL.md` に保存します。

```markdown
---
name: {skill-name}
description: {いつこのスキルを使うか、具体的なユースケースを明記}
---

# {Skill Name}

## Overview
{このスキルが何をするか}

## When to Use
{どういう状況で使うか、トリガーとなるキーワードや状況}

## Instructions
{具体的な手順}

## Examples
{入力と出力の例}

## Guidelines
{守るべきルール、注意点}
```

### スキル作成フロー

1. employee がスキル化候補を発見 → boss に報告
2. boss → dashboard.md の「スキル化候補」に記載
3. president が最新仕様をリサーチし、スキル設計書を作成
4. stockholder に承認を依頼（dashboard.md 経由）
5. 承認後、president → boss に作成を指示
6. boss が skill-creator スキルを使用して作成

## skill-creator スキル

```markdown
---
name: skill-creator
description: 汎用的な作業パターンを発見した際に、再利用可能な Claude Code スキルを自動生成する。繰り返し使えるワークフロー、ベストプラクティス、ドメイン知識をスキル化する時に使用。
---

# Skill Creator - スキル自動生成

## Overview

作業中に発見した汎用的なパターンを、再利用可能な Claude Code スキルとして保存します。
これにより、同じ作業を繰り返す際の品質と効率が向上します。

## When to Create a Skill

以下の条件を満たす場合、スキル化を検討してください：

1. **再利用性**: 他のプロジェクトでも使えるパターン
2. **複雑性**: 単純すぎず、手順や知識が必要なもの
3. **安定性**: 頻繁に変わらない手順やルール
4. **価値**: スキル化することで明確なメリットがある

## Skill Structure

生成するスキルは以下の構造に従います：

skill-name/
├── SKILL.md          # 必須
├── scripts/          # オプション（実行スクリプト）
└── resources/        # オプション（参照ファイル）

## SKILL.md Template

---
name: {skill-name}
description: {いつこのスキルを使うか、具体的なユースケースを明記}
---

# {Skill Name}

## Overview
{このスキルが何をするか}

## When to Use
{どういう状況で使うか、トリガーとなるキーワードや状況}

## Instructions
{具体的な手順}

## Examples
{入力と出力の例}

## Guidelines
{守るべきルール、注意点}

## Creation Process

1. パターンの特定
   - 何が汎用的か
   - どこで再利用できるか

2. スキル名の決定
   - kebab-case を使用（例: api-error-handler）
   - 動詞+名詞 or 名詞+名詞

3. description の記述（最重要）
   - Claude がいつこのスキルを使うか判断する材料
   - 具体的なユースケース、ファイルタイプ、アクション動詞を含める
   - 悪い例: "ドキュメント処理スキル"
   - 良い例: "PDF からテーブルを抽出し CSV に変換する。データ分析ワークフローで使用。"

4. Instructions の記述
   - 明確な手順
   - 判断基準
   - エッジケースの対処

5. 保存
   - グローバル: /home/node/.claude/skills/{skill-name}/
   - プロジェクト固有: .cc-multi-agent/skills/{skill-name}/
   - 既存スキルと名前が被らないか確認

## 使用フロー

このスキルは boss が president からの指示を受けて使用します。

1. employee がスキル化候補を発見 → boss に報告
2. boss → president に報告
3. **president が最新仕様をリサーチし、スキル設計を行う**
4. president が stockholder に承認を依頼（dashboard.md 経由）
5. stockholder が承認
6. president → boss に作成を指示（設計書付き）
7. **boss がこの skill-creator を使用してスキルを作成**
8. 完了報告

※ president がリサーチした最新仕様に基づいて作成すること。
※ president からの設計書に従うこと。

## Examples of Good Skills

### Example 1: API Response Handler
---
name: api-response-handler
description: REST API のレスポンス処理パターン。エラーハンドリング、リトライロジック、レスポンス正規化を含む。API 統合作業時に使用。
---

### Example 2: Meeting Notes Formatter
---
name: meeting-notes-formatter
description: 議事録を標準フォーマットに変換する。参加者、決定事項、アクションアイテムを抽出・整理。会議後のドキュメント作成時に使用。
---

### Example 3: Data Validation Rules
---
name: data-validation-rules
description: 入力データのバリデーションパターン集。メール、電話番号、日付、金額などの検証ルール。フォーム処理やデータインポート時に使用。
---

## Reporting Format

スキル生成時は以下の形式で報告：

「新しいスキルを作成しました。
- スキル名: {name}
- 用途: {description}
- 保存先: {path}」
```

## memory/global_context.md テンプレート

```markdown
# Global Context
最終更新: YYYY-MM-DD

## stockholder の好み
- {好み1}
- {好み2}

## 重要な意思決定
| 日付 | 決定事項 | 理由 |
|------|----------|------|

## プロジェクト横断の知見
- {知見1}
- {知見2}

## 解決した問題
| 日付 | 問題 | 解決方法 |
|------|------|----------|
```

## README.md

2つの README.md を提供します。

### リポジトリ README.md（ルート）

人間および LLM 向けのリポジトリ説明。以下を含む：

- 概要（何をするツールか）
- エージェント構成図
- 特徴
- セットアップ手順
- リポジトリ構成
- 導入先に生成されるファイル構成
- tmux セッション構成
- コマンド一覧

### cc-multi-agent/README.md（エージェント向け）

導入先の `.cc-multi-agent/README.md` にコピーされる。エージェントが読むクイックリファレンス。以下を含む：

- 自分の役割の確認方法（`tmux display-message -p '#T'`）
- 対応する指示書の一覧
- ディレクトリ構成
- エージェント階層図
- 通信ルール（上→下、下→上）
- send-keys の正しい使い方
- tmux ターゲット一覧
- 禁止事項
- コンパクション復帰時の手順

