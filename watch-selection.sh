#!/bin/bash
# watch-selection.sh — 监听 prompt 文件，自动调用 Claude Code 选品
# 用法: bash watch-selection.sh [prompt文件] [result文件]
# 默认: selection-prompt.md → selection-result.json

PROMPT_FILE="${1:-selection-prompt.md}"
RESULT_FILE="${2:-selection-result.json}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROMPT_PATH="$SCRIPT_DIR/$PROMPT_FILE"
RESULT_PATH="$SCRIPT_DIR/$RESULT_FILE"

echo "=== Claude Code 选品监听器 ==="
echo "监听文件: $PROMPT_PATH"
echo "结果文件: $RESULT_PATH"
echo "按 Ctrl+C 停止"
echo ""

if ! command -v fswatch &>/dev/null && ! command -v inotifywait &>/dev/null; then
  echo "[信息] 未检测到 fswatch 或 inotifywait，使用轮询模式（每2秒检查一次）"
  POLL_MODE=true
else
  POLL_MODE=false
fi

LAST_MOD=0
while true; do
  if [ -f "$PROMPT_PATH" ]; then
    # 获取文件修改时间（兼容 macOS 和 Linux）
    if [[ "$OSTYPE" == "darwin"* ]]; then
      CURRENT_MOD=$(stat -f %m "$PROMPT_PATH" 2>/dev/null)
    else
      CURRENT_MOD=$(stat -c %Y "$PROMPT_PATH" 2>/dev/null)
    fi

    if [ "$CURRENT_MOD" != "$LAST_MOD" ] && [ -s "$PROMPT_PATH" ]; then
      LAST_MOD="$CURRENT_MOD"
      echo ""
      echo ">>> [$(date '+%H:%M:%S')] 检测到 prompt 更新，开始选品..."
      echo ""

      PROMPT_CONTENT=$(cat "$PROMPT_PATH")

      # 调用 Claude Code CLI（非交互模式）
      echo "$PROMPT_CONTENT" | claude --print 2>&1 | tee "$RESULT_PATH.tmp"

      # 从输出中提取 JSON 块
      if [ -f "$RESULT_PATH.tmp" ]; then
        python3 -c "
import sys, re, json
text = open('$RESULT_PATH.tmp', 'r', encoding='utf-8').read()
match = re.search(r'\{[\s\S]*\"proposals\"[\s\S]*\}', text)
if match:
    try:
        json.loads(match.group())
        with open('$RESULT_PATH', 'w', encoding='utf-8') as f:
            f.write(match.group())
        print('结果已提取并写入 $RESULT_PATH')
    except Exception as e:
        with open('$RESULT_PATH', 'w', encoding='utf-8') as f:
            f.write(text)
        print(f'警告：JSON 解析失败 ({e})，已保存原始输出')
else:
    with open('$RESULT_PATH', 'w', encoding='utf-8') as f:
        f.write(text)
    print('警告：输出中未找到 JSON，已保存原始输出')
" 2>/dev/null || {
          # Python 不可用时的降级：直接复制原始输出
          cp "$RESULT_PATH.tmp" "$RESULT_PATH"
          echo "警告：python3 不可用，已保存原始输出"
        }
        rm -f "$RESULT_PATH.tmp"
      fi

      echo ""
      echo "<<< [$(date '+%H:%M:%S')] 选品完成，结果已写入 $RESULT_PATH"
      echo ""
    fi
  fi

  if [ "$POLL_MODE" = true ]; then
    sleep 2
  else
    # 使用文件监听工具阻塞等待
    if command -v fswatch &>/dev/null; then
      fswatch -1 "$PROMPT_PATH" 2>/dev/null
    elif command -v inotifywait &>/dev/null; then
      inotifywait -e modify,create "$PROMPT_PATH" 2>/dev/null
    fi
  fi
done
