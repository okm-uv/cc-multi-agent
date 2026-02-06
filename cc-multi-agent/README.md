# .cc-multi-agent

マルチエージェント環境のランタイムディレクトリ。

## あなたがエージェントの場合

### 1. 自分の役割を確認

```bash
tmux display-message -p '#T'
```

### 2. 対応する指示書を読む

| ペイン名 | 指示書 |
|----------|--------|
| president | `instructions/president.md` |
| boss | `instructions/boss.md` |
| employee* | `instructions/employee.md` |

### 3. 共通ルールを読む

`CLAUDE.md` に全エージェント共通のルールがあります。

## ディレクトリ構成

```
.cc-multi-agent/
├── CLAUDE.md            # 全エージェント共通ルール（必読）
├── config.toon          # プロジェクト設定
├── dashboard.md         # 進捗報告（stockholder 向け）
├── instructions/        # 各エージェントの指示書
│   ├── president.md
│   ├── boss.md
│   └── employee.md
├── queue/               # エージェント間通信
│   ├── president_to_boss.toon
│   ├── boss_to_employees.toon
│   ├── tasks/           # employee 個別タスク
│   │   └── employee{1-8}.toon
│   └── reports/         # employee 報告
│       └── employee{1-8}_report.toon
├── context/             # プロジェクト固有コンテキスト
├── memory/              # セッション間記憶
│   └── global_context.md
├── skills/              # ローカルスキル
└── logs/                # ログ・バックアップ
```

## エージェント階層

```
stockholder（ユーザー）
     │ 直接会話
     ▼
 president ──── 方針決定
     │ queue/president_to_boss.toon + send-keys
     ▼
   boss ─────── タスク分解、進捗管理、dashboard.md 更新
     │ queue/tasks/employee{N}.toon + send-keys
     ▼
employee1-8 ── 実作業
     │ queue/reports/employee{N}_report.toon + send-keys
     └──────────────────────────────────────────────────► boss
```

## 通信ルール

### 上→下（指示）
1. TOON ファイルに書く
2. send-keys で相手を起こす（2回に分ける）

### 下→上（報告）
1. TOON ファイルに書く
2. send-keys で boss を起こす
3. **boss が dashboard.md を更新**（唯一の更新者）

### send-keys の正しい使い方

```bash
# 1回目: メッセージ
tmux send-keys -t multiagent:0.0 'メッセージ'

# 2回目: Enter
tmux send-keys -t multiagent:0.0 Enter
```

## tmux ターゲット

| エージェント | ターゲット |
|-------------|-----------|
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

## 禁止事項（全エージェント共通）

- ポーリング（待機ループ）
- コンテキストを読まずに作業開始
- Task agents の使用

## コンパクション復帰時

1. `tmux display-message -p '#T'` で自分のペイン名を取得
2. 対応する指示書を読む
3. 禁止事項を確認してから作業開始
