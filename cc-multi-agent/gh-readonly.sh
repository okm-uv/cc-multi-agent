#!/bin/bash

# ════════════════════════════════════════════════════════════════════
# gh コマンド read-only wrapper
# ホワイトリスト方式で安全なコマンドのみ許可
# ════════════════════════════════════════════════════════════════════

# gh コマンドの存在確認
if ! command -v /usr/bin/gh &> /dev/null; then
  echo "Error: gh command not found at /usr/bin/gh" >&2
  exit 1
fi

COMMAND="$1"
SUBCOMMAND="$2"

# 許可されたコマンド一覧
show_allowed_commands() {
  echo "Allowed commands:" >&2
  echo "  issue: list, view, status" >&2
  echo "  pr: list, view, status, diff, checks" >&2
  echo "  repo: view, list" >&2
  echo "  search: issues, prs, repos, commits, code" >&2
  echo "  browse: (open in browser)" >&2
  echo "  api: GET requests only" >&2
}

case "$COMMAND:$SUBCOMMAND" in
  # issue 関連
  issue:list|issue:view|issue:status)
    /usr/bin/gh "$@"
    ;;
  # PR 関連
  pr:list|pr:view|pr:status|pr:diff|pr:checks)
    /usr/bin/gh "$@"
    ;;
  # repo 関連
  repo:view|repo:list)
    /usr/bin/gh "$@"
    ;;
  # search 関連（具体的なサブコマンドのみ）
  search:issues|search:prs|search:repos|search:commits|search:code)
    /usr/bin/gh "$@"
    ;;
  # browse（read-only なので許可）
  browse:)
    /usr/bin/gh "$@"
    ;;
  # api は GET のみ許可
  api:*)
    # 大文字小文字を区別せず、可変スペースに対応した正規表現
    if [[ "${*,,}" =~ (-x|--method)[[:space:]]*(post|put|patch|delete) ]]; then
      echo "Error: Only GET requests allowed" >&2
      exit 1
    fi
    # -X や --method が指定されていない場合はデフォルトで GET なので許可
    /usr/bin/gh "$@"
    ;;
  # ヘルプは許可
  --help:|help:|-h:)
    /usr/bin/gh "$@"
    ;;
  # その他は拒否
  *)
    echo "Error: '$COMMAND $SUBCOMMAND' is not allowed" >&2
    echo "" >&2
    show_allowed_commands
    exit 1
    ;;
esac
