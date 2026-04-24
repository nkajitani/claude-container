#!/bin/bash
# Claude Code が stdin に送信する JSON データを読み取る
input=$(cat)

# jq を使用してフィールドを抽出する
MODEL=$(echo "$input" | jq -r '.model.display_name')
DIR=$(echo "$input" | jq -r '.workspace.current_dir')
# "// 0" はフィールドが null の場合のフォールバックを提供します
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)

# プログレスバーを構築します：printf -v はスペースを作成し、
# ${var// /▓} は各スペースをブロック文字に置き換えます
BAR_WIDTH=10
FILLED=$((PCT * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))
BAR=""
[ "$FILLED" -gt 0 ] && printf -v FILL "%${FILLED}s" && BAR="${FILL// /▓}"
[ "$EMPTY" -gt 0 ] && printf -v PAD "%${EMPTY}s" && BAR="${BAR}${PAD// /░}"

echo "[$MODEL] $BAR $PCT%"
echo "📁 ${DIR##*/}"
