# cc-multi-agent CLAUDE.md

このファイルは Claude Code マルチエージェント環境の共通ルールを定義します。

## コンパクション復帰時（全エージェント必須）

あなたがコンパクションから復帰した場合、以下を厳守してください：

**【禁止】** summary の「次のステップ」を見て即座に作業開始すること

**【必須】** 以下の手順を順番に実行：

1. `tmux display-message -p '#T'` で自分のペイン名を取得
2. ペイン名に対応する instructions を読む：
   - president → instructions/president.md
   - boss → instructions/boss.md
   - employee* → instructions/employee.md
3. 禁止事項を確認してから作業開始

**理由:** コンパクション後は役割の制約を忘れている可能性があるため

## TOON フォーマット

エージェント間通信には **TOON (Token-Oriented Object Notation)** を使用します。

- **公式リポジトリ**: https://github.com/toon-format/toon
- **特徴**: LLM 向けに最適化（JSON 比で約40%トークン削減）
- **構文**: YAML のインデント + CSV の表形式
- **パーサー**: 不要（LLM が直接読み書きし、人もそのまま読める）

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

### 使用ファイル一覧

- **指示**: `queue/*.toon`
- **報告**: `queue/reports/*.toon`
- **設定**: `config.toon`

## tmux ペイン参照

| エージェント | tmux ターゲット |
|-------------|----------------|
| president | `president:0` |
| boss | `multiagent:0.0` |
| employee1 | `multiagent:0.1` |
| employee2 | `multiagent:0.2` |
| employee3 | `multiagent:0.3` |
| employee4 | `multiagent:0.4` |
| employee5 | `multiagent:0.5` |
| employee6 | `multiagent:0.6` |
| employee7 | `multiagent:0.7` |
| employee8 | `multiagent:0.8` |

## 通信プロトコル

### イベント駆動通信（TOON + send-keys）

- **ポーリング禁止**: API コスト節約のため
- **指示・報告**: TOON ファイルに記述
- **通知**: tmux send-keys で相手を起こす（**必ず Enter を使用、C-m 禁止**）

### 報告の流れ（割り込み防止）

- **下→上への報告**: dashboard.md 更新のみ（send-keys 禁止）
- **上→下への指示**: TOON + send-keys で起こす
- **stockholder への報告**: boss が dashboard.md を更新
- 理由: stockholder の入力中に割り込みが発生するのを防ぐ

### tmux send-keys の正しい使い方（超重要）

**絶対禁止パターン:**

```bash
# ダメな例1: 1行で書く
tmux send-keys -t multiagent:0.0 'メッセージ' Enter

# ダメな例2: && で繋ぐ
tmux send-keys -t multiagent:0.0 'メッセージ' && tmux send-keys -t multiagent:0.0 Enter
```

**理由:** 1回のBash呼び出しでEnterが正しく解釈されないため

**正しい方法（2回に分ける）:**

**【1回目】** メッセージを送る：
```bash
tmux send-keys -t multiagent:0.0 'queue/president_to_boss.toon に新しい指示があります。確認して実行してください。'
```

**【2回目】** Enter を送る：
```bash
tmux send-keys -t multiagent:0.0 Enter
```

## タイムスタンプの取得方法（必須）

タイムスタンプは **必ず `date` コマンドで取得** してください。自分で推測してはいけません。

```bash
# dashboard.md の最終更新（時刻のみ）
date "+%Y-%m-%d %H:%M"
# 出力例: 2026-01-30 15:46

# TOON 用（ISO 8601形式）
date "+%Y-%m-%dT%H:%M:%S"
# 出力例: 2026-01-30T15:46:30
```

## エージェントの状態確認

指示を送る前に、相手が処理中でないか確認します。

```bash
tmux capture-pane -t multiagent:0.0 -p | tail -20
```

| 状態 | インジケータ |
|------|-------------|
| busy | `thinking`, `Esc to interrupt`, `Effecting…`, `Boondoggling…`, `Puzzling…`, `Calculating…`, `Fermenting…`, `Crunching…` |
| idle | `❯ ` (プロンプト表示), `bypass permissions on` |

処理中の場合は完了を待つか、急ぎなら割り込み可。

## 未処理報告スキャン（通信ロスト対策）

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

## RACE-001（同一ファイル書き込み禁止）

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

## 並列化ルール

| タスクの種類 | 実行方法 |
|-------------|---------|
| 独立タスク | 複数 employee に同時割り当て |
| 依存タスク | 順番に実行 |

**1 employee = 1 タスク（完了まで）**

employee には一度に1つのタスクのみ割り当てます。完了報告を受けてから次のタスクを割り当てます。

## 「起こされたら全確認」方式

Claude Code は「待機」できません。プロンプト待ちは「停止」です。

### やってはいけないこと

```
employee を起こした後、「報告を待つ」と言う
→ employee が send-keys しても処理できない
```

### 正しい動作

1. employee を起こす
2. 「ここで停止します」と言って処理終了
3. employee が send-keys で起こしてくる
4. 全報告ファイルをスキャン
5. 状況把握してから次アクション

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

## ファイル構成

| ファイル | 用途 |
|----------|------|
| `queue/president_to_boss.toon` | president → boss への指示 |
| `queue/boss_to_employees.toon` | 全 employee の割り当て状況一覧 |
| `queue/tasks/employee{1-8}.toon` | boss → employee への割り当て（各自専用） |
| `queue/reports/employee{1-8}_report.toon` | employee → boss への報告 |
| `dashboard.md` | 全体進捗（stockholder 向け） |
| `memory/global_context.md` | stockholder の好み・重要な意思決定 |

**注意**: stockholder → president はファイル経由ではなく、直接会話で行います。
