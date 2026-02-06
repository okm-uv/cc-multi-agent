# cc-multi-agent

Claude Code + tmux を使ったマルチエージェント並列開発基盤。

## 概要

任意のプロジェクトに devcontainer 環境をセットアップし、複数の Claude Code エージェントが協調してタスクを実行します。

```
stockholder（ユーザー）
       │
       ▼
   president ─── 方針決定、boss への指示
       │
       ▼
     boss ─────── タスク分解、employee への割り当て、進捗管理
       │
       ▼
  employee1-8 ── 実際のコーディング、調査、テスト
```

## 特徴

- **サンドボックス**: devcontainer 内で `--dangerously-skip-permissions` を安全に使用
- **公式準拠**: Claude Code 公式の devcontainer 設定をベース
- **ファイルベース**: 全ての状態・通信をファイルで管理（TOON形式）
- **スキル化**: 繰り返しパターンを検出し、スキルとして蓄積

## セットアップ

```bash
# 1. このリポジトリを clone（任意の場所でOK）
git clone git@github.com:okm-uv/cc-multi-agent.git

# 2. 対象プロジェクトでセットアップ実行
cd /path/to/my-project
/path/to/cc-multi-agent/setup.sh

# 3. VS Code で開き、"Reopen in Container" を選択

# 4. コンテナ内でエージェント起動
.cc-multi-agent/start.sh

# 5. president に接続して指示を出す
tmux attach -t president
```

## リポジトリ構成

```
cc-multi-agent/              # このリポジトリ
├── README.md                # このファイル
├── SPEC.md                  # 詳細設計仕様書
├── TODO.md                  # 実装タスクリスト
├── setup.sh                 # セットアップスクリプト
└── cc-multi-agent/          # コピー元ファイル群
    ├── CLAUDE.md
    ├── README.md
    ├── config.toon
    ├── start.sh
    ├── setup-multiagent.sh
    ├── gh-readonly.sh
    ├── dashboard.md
    ├── instructions/
    ├── context/
    ├── memory/
    └── skills/
```

## 導入先に生成されるファイル構成

```
my-project/
├── .devcontainer/           # 公式からダウンロード + カスタマイズ
│   ├── devcontainer.json
│   ├── Dockerfile
│   └── init-firewall.sh
└── .cc-multi-agent/         # マルチエージェント関連（隠しフォルダ）
    ├── CLAUDE.md            # エージェント共通ルール
    ├── README.md            # このディレクトリの説明
    ├── config.toon          # 設定ファイル
    ├── start.sh             # エージェント起動
    ├── setup-multiagent.sh  # 追加インストール
    ├── gh-readonly.sh       # gh コマンド制限
    ├── dashboard.md         # 進捗報告（stockholder 向け）
    ├── instructions/        # 各エージェントの指示書
    ├── queue/               # エージェント間通信
    ├── context/             # プロジェクト固有コンテキスト
    ├── memory/              # セッション間記憶
    ├── skills/              # ローカルスキル
    └── logs/                # ログ・バックアップ
```

## tmux セッション構成

```
【president セッション】stockholder との対話用
  └─ president

【multiagent セッション】3x3 = 9ペイン
  ┌─────────┬─────────┬─────────┐
  │  boss   │employee3│employee6│
  ├─────────┼─────────┼─────────┤
  │employee1│employee4│employee7│
  ├─────────┼─────────┼─────────┤
  │employee2│employee5│employee8│
  └─────────┴─────────┴─────────┘
```

## コマンド

```bash
# セッション作成（Claude Code 起動あり）
.cc-multi-agent/start.sh

# セッション作成のみ（Claude Code 起動なし）
.cc-multi-agent/start.sh -s

# セッション削除
.cc-multi-agent/start.sh -d

# president に接続
tmux attach -t president

# multiagent に接続
tmux attach -t multiagent
```

## 関連ファイル

- `SPEC.md` - 詳細な設計仕様書
- `TODO.md` - 実装タスクリスト
