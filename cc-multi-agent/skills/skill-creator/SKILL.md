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

```
skill-name/
├── SKILL.md          # 必須
├── scripts/          # オプション（実行スクリプト）
└── resources/        # オプション（参照ファイル）
```

## SKILL.md Template

```markdown
---
name: {skill-name}
description: {いつこのスキルを使うか、具体的なユースケースを明記}
---

# {Skill Name}

## Overview
{このスキルが何をするか - 1-2文}

## When to Use
{どういう状況で使うか、トリガーとなるキーワードや状況}
- キーワード例: "〜したい", "〜を作成", "〜を変換"
- ファイルタイプ: .json, .csv, .md など

## Instructions
{具体的な手順 - 番号付きリストで}
1. 入力を確認する
2. 処理を実行する
3. 結果を出力する

## Examples
{入力と出力の例}

### 入力例
{具体的な入力}

### 出力例
{期待される出力}

## Guidelines
{守るべきルール、注意点}
- ルール1
- ルール2
```

## President が作成するスキル設計書フォーマット

president がスキル化を承認する際、以下の設計書を作成して boss に渡します：

```markdown
# スキル設計書: {skill-name}

## 基本情報
- スキル名: {kebab-case}
- 用途: {1文で説明}
- 保存先: グローバル / プロジェクト固有

## description（最重要）
{Claude がいつこのスキルを使うか判断する材料}

## When to Use
{トリガーとなるキーワード、ファイルタイプ、状況}

## Instructions の要点
1. {手順1}
2. {手順2}
3. {手順3}

## 必須の Examples
- 入力例: {概要}
- 出力例: {概要}

## Guidelines
- {守るべきルール}

## 備考
{リサーチで判明した注意点など}
```

## Creation Process

1. **パターンの特定**
   - 何が汎用的か
   - どこで再利用できるか

2. **スキル名の決定**
   - kebab-case を使用（例: api-error-handler）
   - 命名規則:
     - 動詞+名詞: `generate-report`, `validate-input`
     - 名詞+名詞: `api-response-handler`, `meeting-notes-formatter`

3. **description の記述（最重要）**
   - Claude がいつこのスキルを使うか判断する材料
   - 具体的なユースケース、ファイルタイプ、アクション動詞を含める
   - 悪い例: "ドキュメント処理スキル"
   - 良い例: "PDF からテーブルを抽出し CSV に変換する。データ分析ワークフローで使用。"

4. **Instructions の記述**
   - 明確な手順（番号付きリスト）
   - 判断基準
   - エッジケースの対処

5. **既存スキルとの重複確認**
   ```bash
   # グローバルスキル一覧
   ls ~/.claude/skills/

   # プロジェクトスキル一覧
   ls .cc-multi-agent/skills/
   ```

6. **保存**
   - グローバル: /home/node/.claude/skills/{skill-name}/
   - プロジェクト固有: .cc-multi-agent/skills/{skill-name}/

## 使用フロー

このスキルは boss が president からの指示を受けて使用します。

1. employee がスキル化候補を発見 → boss に報告
2. boss → dashboard.md に記載 → president が確認
3. **president が最新仕様をリサーチし、スキル設計書を作成**
4. president が stockholder に承認を依頼（dashboard.md 経由）
5. stockholder が承認
6. president → boss に作成を指示（設計書付き）
7. **boss がこの skill-creator を使用してスキルを作成**
8. 完了報告

※ president がリサーチした最新仕様に基づいて作成すること。
※ president からの設計書に従うこと。

## Examples of Good Skills

### Example 1: API Response Handler（完全版）

```markdown
---
name: api-response-handler
description: REST API のレスポンス処理パターン。エラーハンドリング、リトライロジック、レスポンス正規化を含む。API 統合作業時に使用。
---

# API Response Handler

## Overview
REST API のレスポンスを統一的に処理するパターンを提供します。

## When to Use
- 外部 API を呼び出すコードを書く時
- キーワード: "API", "fetch", "axios", "レスポンス処理"

## Instructions
1. レスポンスのステータスコードを確認
2. エラーの場合はエラーハンドリング
3. 成功の場合はレスポンスを正規化
4. リトライが必要な場合はリトライロジックを適用

## Examples

### 入力例
```typescript
const response = await fetch('/api/users');
```

### 出力例
```typescript
const response = await fetchWithRetry('/api/users', {
  retries: 3,
  onError: (error) => console.error(error)
});
const data = normalizeResponse(response);
```

## Guidelines
- 5xx エラーはリトライ対象
- 4xx エラーはリトライしない
- タイムアウトは 30 秒
```

### Example 2: Meeting Notes Formatter
```markdown
---
name: meeting-notes-formatter
description: 議事録を標準フォーマットに変換する。参加者、決定事項、アクションアイテムを抽出・整理。会議後のドキュメント作成時に使用。
---
```

### Example 3: Data Validation Rules
```markdown
---
name: data-validation-rules
description: 入力データのバリデーションパターン集。メール、電話番号、日付、金額などの検証ルール。フォーム処理やデータインポート時に使用。
---
```

## Reporting Format

スキル生成時は以下の形式で報告：

```
新しいスキルを作成しました。
- スキル名: {name}
- 用途: {description}
- 保存先: {path}
- 内容: {Instructions の要約}
```
