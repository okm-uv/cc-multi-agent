# cc-multi-agent 実装 TODO

> SPEC.md から抽出した実装タスクリスト

## 0. ドキュメント

- [x] `README.md` - リポジトリ説明（人間・LLM向け）
  - [x] 概要、エージェント構成図、特徴
  - [x] セットアップ手順
  - [x] リポジトリ構成、導入先ファイル構成
  - [x] tmux セッション構成、コマンド一覧
- [x] `cc-multi-agent/README.md` - エージェント向けクイックリファレンス
  - [x] 役割確認方法、指示書一覧
  - [x] ディレクトリ構成、エージェント階層図
  - [x] 通信ルール、tmux ターゲット一覧
  - [x] 禁止事項、コンパクション復帰手順

## 1. セットアップスクリプト

- [x] `setup.sh` - 対象プロジェクトへのセットアップスクリプト
  - [x] .devcontainer/ 存在チェック（上書き確認）
  - [x] 公式 devcontainer ダウンロード（devcontainer.json, Dockerfile, init-firewall.sh）
  - [x] Dockerfile に tmux を追加
  - [x] Dockerfile に locale 設定を追加（警告を消すため）
  - [x] Dockerfile に timezone 設定を追加（JST）
  - [x] devcontainer.json の修正
    - postStartCommand → postCreateCommand に変更
    - setup-multiagent.sh を追加
    - waitFor を postCreateCommand に変更
  - [x] .gitignore への追記（未追記の場合のみ）
    - 追記内容: `.devcontainer/` と `.cc-multi-agent/`
  - [x] .cc-multi-agent/ ディレクトリ作成
  - [x] cc-multi-agent/ → .cc-multi-agent/ へコピー

## 2. cc-multi-agent/ 内のファイル群

- [x] `CLAUDE.md` - プロジェクト内 CLAUDE.md
  - [x] コンパクション復帰時の手順
  - [x] TOON フォーマットの基本構文と使用ファイル一覧
  - [x] tmux ペイン参照テーブル（president:0, multiagent:0.0-8）
  - [x] 通信プロトコル（send-keys 2回分離、タイムスタンプ、状態確認）
  - [x] エージェントの状態確認方法（busy/idle インジケータ一覧）
    - busy: `thinking`, `Esc to interrupt`, `Effecting…`, `Boondoggling…`, `Puzzling…`, `Calculating…`, `Fermenting…`, `Crunching…`
    - idle: `❯ ` (プロンプト表示), `bypass permissions on`
  - [x] 未処理報告スキャン方法（通信ロスト対策）
  - [x] RACE-001（同一ファイル書き込み禁止）
  - [x] 並列化ルール（独立タスク vs 依存タスク、1 employee = 1 タスク）
  - [x] 「起こされたら全確認」方式（Claude Code は「待機」できない）
  - [x] stockholder お伺いルール
  - [x] コンテキスト読み込み手順（各エージェント別）
  - [x] Summary 生成時の必須事項
- [x] `config.toon` - 設定ファイル
- [x] `setup-multiagent.sh` - コンテナ起動時の初期設定
  - [x] gh コマンド alias 設定（gh-readonly.sh を使用）
  - [x] ~/.claude/CLAUDE.md に TOON ガイド追記
  - [x] ~/.claude/skills/ ディレクトリ作成
  - 注: tmux は Dockerfile でプリインストール済み
- [x] `start.sh` - エージェント起動スクリプト
  - [x] オプション解析（-s, -d, -h）
  - [x] 前回記録のバックアップ
  - [x] 既存セッションクリーンアップ
  - [x] キューファイル初期化
  - [x] dashboard.md 初期化
  - [x] multiagent セッション作成（3x3 ペイン）
  - [x] president セッション作成
  - [x] Claude Code 起動
  - [x] 指示書の自動読み込み
- [x] `gh-readonly.sh` - gh コマンド read-only wrapper

## 3. instructions（指示書）

- [x] `instructions/president.md`
  - [x] 役割定義（TOON Front Matter）
  - [x] 禁止事項
  - [x] ワークフロー
  - [x] 即座委譲・即座終了の原則
  - [x] 実行計画は boss に任せるルール
  - [x] memory/global_context.md の更新責任
  - [x] スキル化候補の承認とスキル設計書作成
- [x] `instructions/boss.md`
  - [x] 役割定義（TOON Front Matter）
  - [x] 禁止事項
  - [x] ワークフロー（receive, report）
  - [x] タスク分解の前に考えること
  - [x] dashboard.md 更新責任（唯一の更新者）
  - [x] 未処理報告スキャン手順（`ls -la queue/reports/` で全スキャン）
  - [x] スキル化候補の収集と dashboard.md への記載
- [x] `instructions/employee.md`
  - [x] 役割定義（TOON Front Matter）
  - [x] 禁止事項
  - [x] ワークフロー
  - [x] 報告通知プロトコル（boss 状態確認 + リトライ最大3回）
  - [x] skill_candidate の必須記載（省略禁止）
  - [x] ペルソナ設定（カテゴリ別例）

## 4. キュー・テンプレート

- [x] `queue/` ディレクトリ構造
  - [x] `queue/tasks/` - employee 個別タスク用
  - [x] `queue/reports/` - employee 報告用
  - [x] `queue/president_to_boss.toon` テンプレート（directive + goals 形式）
  - [x] `queue/boss_to_employees.toon` テンプレート（assignments 配列形式）
  - [x] `queue/tasks/employee{1-8}.toon` 初期テンプレート（assignment + files 形式）
  - [x] `queue/reports/employee{1-8}_report.toon` 初期テンプレート（report + changes + skill_candidate 形式）
- [x] `dashboard.md` テンプレート
- [x] `context/README.md` テンプレート
- [x] `memory/global_context.md` テンプレート
- [x] `logs/` ディレクトリ

## 5. スキル

- [x] `skills/` ディレクトリ作成（プロジェクト固有スキル用）
- [x] `skills/skill-creator/SKILL.md`
- [x] スキル設計書テンプレート（SKILL.md の標準フォーマット）
  - Front Matter: name, description
  - セクション: Overview, When to Use, Instructions, Examples, Guidelines

## 依存関係

```
setup.sh
├── depends on: 全ての .cc-multi-agent/ 内ファイルのテンプレート
└── creates: .devcontainer/, .cc-multi-agent/

start.sh
├── depends on: setup.sh が作成した構造
└── creates: tmux セッション、初期化されたキューファイル
```

## 優先順位（推奨実装順序）

1. **Phase 1: コアファイル**
   - config.toon
   - gh-readonly.sh
   - setup-multiagent.sh

2. **Phase 2: 指示書**
   - instructions/president.md
   - instructions/boss.md
   - instructions/employee.md

3. **Phase 3: テンプレート**
   - dashboard.md
   - context/README.md
   - memory/global_context.md
   - CLAUDE.md

4. **Phase 4: スクリプト**
   - start.sh
   - setup.sh

5. **Phase 5: スキル**
   - skills/skill-creator/SKILL.md
