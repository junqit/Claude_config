#!/bin/bash
# 依赖 jq；字段来源：Claude Code statusline 官方 JSON 结构

input=$(cat)

# --- 解析字段 ---
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
DIR=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
CTX_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
TOK_IN=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
TOK_OUT=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')

# 缓存命中率：prompt_cache.hit_ratio 是 0~1 小数
CACHE_RAW=$(echo "$input" | jq -r '.prompt_cache.hit_ratio // empty')

# --- Git 分支 ---
BRANCH=""
if git -C "$DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" branch --show-current 2>/dev/null)
fi

# --- 颜色 ---
G='\033[32m'; Y='\033[33m'; R='\033[31m'; C='\033[36m'; D='\033[2m'; N='\033[0m'

# ctx 颜色分级
if [ "$CTX_PCT" -lt 50 ]; then C_CTX="$G"
elif [ "$CTX_PCT" -lt 80 ]; then C_CTX="$Y"
else C_CTX="$R"; fi

# CACHE 格式化
if [ -n "$CACHE_RAW" ] && [ "$CACHE_RAW" != "null" ]; then
    CACHE_PCT=$(echo "$CACHE_RAW" | awk '{printf "%.0f", $1 * 100}')
    CACHE_PART="${D}cache:${N}${CACHE_PCT}%"
else
    CACHE_PART="${D}cache:${N}--"
fi

# token 消耗格式化（k 为单位）
fmt_tok() {
    local n=$1
    if [ "$n" -ge 1000 ]; then
        echo "$(echo "$n" | awk '{printf "%.1f", $1/1000}')k"
    else
        echo "$n"
    fi
}
TOK_PART="${D}tok:${N}${TOK_IN}↑$(fmt_tok "$TOK_OUT")↓"

# 分支显示
if [ -n "$BRANCH" ]; then
    BRANCH_PART=" ${C}🌿 ${BRANCH}${N}"
else
    BRANCH_PART=""
fi

# --- 输出 ---
echo -e "[${MODEL}] 📁 ${DIR}${BRANCH_PART} ${C_CTX}ctx:${CTX_PCT}%${N} ${CACHE_PART} ${TOK_PART}"
