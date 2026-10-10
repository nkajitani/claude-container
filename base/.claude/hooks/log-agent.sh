#!/usr/bin/env bash
# サブエージェントの起動・終了を JSONL で記録する（1層：実行ログ）
#
# SubagentStart / SubagentStop フックから呼ばれ、標準入力の JSON を
# 1 行 1 イベントの JSONL に追記する。
# 記録の失敗で Claude Code の作業を止めないため、必ず終了コード 0 で抜ける。

set -uo pipefail

LOG_DIR="${CLAUDE_AGENT_LOG_DIR:-/root/.claude/logs}"
LOG_FILE="${LOG_DIR}/agents-$(date -u +%Y%m%d).jsonl"

# 以降のどこで失敗しても Claude Code をブロックしない
trap 'exit 0' ERR

input=$(cat)

# jq が無い／JSON が壊れている場合は生データを退避して正常終了
if ! command -v jq >/dev/null 2>&1; then
  mkdir -p "$LOG_DIR" 2>/dev/null
  printf '%s\n' "$input" >> "${LOG_DIR}/agents-raw.jsonl" 2>/dev/null
  exit 0
fi

mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# 分析用エージェント自身は記録しない。
# retrospective はログを分析するエージェントであり、自身の起動が記録されると
# 分析の最中にログが増え、集計に自分が混ざる（自己参照）。
# 除外するエージェントは CLAUDE_AGENT_LOG_EXCLUDE にカンマ区切りで指定する。
agent=$(printf "%s" "$input" | jq -r '.agent_type // empty' 2>/dev/null)
EXCLUDE="${CLAUDE_AGENT_LOG_EXCLUDE:-retrospective}"
if [[ -n "$agent" ]]; then
  IFS=',' read -ra _ex <<< "$EXCLUDE"
  for e in "${_ex[@]}"; do
    # 前後の空白を除去して比較
    e="${e#"${e%%[![:space:]]*}"}"; e="${e%"${e##*[![:space:]]}"}"
    [[ -n "$e" && "$agent" == "$e" ]] && exit 0
  done
fi

# SubagentStop の場合、サブエージェントの transcript からトークン使用量を集計する。
# transcript は内部形式のため、取得できない場合は null のままとし失敗させない。
#
# なお、SubagentStop の時点では transcript の書き込みが終わっていないことがある。
# そのため最大 3 回（計 1.5 秒まで）だけ待って読み直す。
# それでも取得できなければ tokens は null とし、記録自体は必ず残す。
tokens='null'
transcript=$(printf '%s' "$input" | jq -r '.agent_transcript_path // empty' 2>/dev/null)
if [[ -n "$transcript" ]]; then
  for _ in 1 2 3; do
    if [[ -r "$transcript" ]]; then
      t=$(jq -s '
        [ .[] | select(.type == "assistant") | .message.usage | select(. != null) ] as $u
        | if ($u | length) == 0 then null
          else {
            input:        ([ $u[].input_tokens                // 0 ] | add),
            output:       ([ $u[].output_tokens               // 0 ] | add),
            cache_read:   ([ $u[].cache_read_input_tokens     // 0 ] | add),
            cache_create: ([ $u[].cache_creation_input_tokens // 0 ] | add),
            api_calls:    ($u | length)
          }
          | . + { total: (.input + .output + .cache_read + .cache_create) }
          end
      ' "$transcript" 2>/dev/null) || t=''
      if [[ -n "$t" && "$t" != "null" ]]; then
        tokens="$t"
        break
      fi
    fi
    sleep 0.5
  done
fi

printf '%s' "$input" | jq -c \
  --arg ts "$now" \
  --argjson tokens "$tokens" \
  '{
     ts:          $ts,
     event:       (.hook_event_name // "unknown"),
     agent:       (.agent_type      // null),
     agent_id:    (.agent_id        // null),
     session_id:  (.session_id      // null),
     cwd:         (.cwd             // null),
     effort:      (.effort.level    // null),
     tokens:      $tokens
   }' >> "$LOG_FILE" 2>/dev/null

exit 0
