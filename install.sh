#!/usr/bin/env bash
# social-monitor 一键安装脚本
# 用法: bash install.sh
# 假设你已经做完 Phase 1 (Clash 路由健康) 和 Phase 2 (主 Chrome 登录所有平台)

set -e

echo "=== 1. 前置检查 ==="
command -v claude >/dev/null || { echo "❌ Claude Code 未装: https://docs.claude.com/claude-code"; exit 1; }
command -v node >/dev/null  || { echo "❌ Node.js 未装"; exit 1; }
command -v uv >/dev/null    || { echo "❌ uv 未装: curl -LsSf https://astral.sh/uv/install.sh | sh"; exit 1; }
echo "  ✓ 工具齐全"

echo
echo "=== 2. 网络层验证 ==="
if curl -sI --max-time 5 https://api.anthropic.com/ 2>&1 | head -1 | grep -q "HTTP"; then
  echo "  ✓ api.anthropic.com 可达"
else
  echo "  ⚠️  api.anthropic.com 不通，先修 Clash"
fi
if curl -sI --max-time 5 https://www.xiaohongshu.com/ 2>&1 | head -1 | grep -qE "HTTP/2 (200|30)"; then
  echo "  ✓ 小红书 TLS 通"
else
  echo "  ⚠️  小红书 TLS 失败，参考 Phase 1 修 Clash"
fi
if curl -sI --max-time 5 https://www.reddit.com/ 2>&1 | head -1 | grep -q "HTTP/2 200"; then
  echo "  ✓ Reddit 可达"
else
  echo "  ⚠️  Reddit 403 / 不通，换 Clash 节点"
fi

echo
echo "=== 3. 装 reddit-mcp-buddy ==="
claude mcp add --transport stdio reddit-buddy -s user -- npx -y reddit-mcp-buddy 2>&1 | tail -2
echo

echo "=== 4. 装 douyin-video-mcp ==="
claude mcp add --transport stdio douyin -s user -- uvx douyin-video-mcp 2>&1 | tail -2
echo

echo "=== 5. 验证 MCP 连接 ==="
claude mcp list 2>&1 | grep -E "reddit-buddy|douyin"

echo
echo "=== 6. 创建 skill 目录 + 文件 ==="
SKILL_DIR="$HOME/.claude/skills/social-monitor"
mkdir -p "$SKILL_DIR"
mkdir -p "$HOME/social-reports"

# 复制 SKILL.md / topics.yaml / 初始 seen.jsonl
GUIDE_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$GUIDE_DIR/SKILL.md" ]; then
  cp "$GUIDE_DIR/SKILL.md" "$SKILL_DIR/SKILL.md"
  cp "$GUIDE_DIR/topics.yaml" "$SKILL_DIR/topics.yaml"
  touch "$SKILL_DIR/seen.jsonl"
  echo "  ✓ skill 文件已部署到 ~/.claude/skills/social-monitor/"
else
  echo "  ⚠️  请把 SKILL.md 和 topics.yaml 放在脚本同目录后重跑"
fi

echo
echo "=== ✅ 安装完成 ==="
echo "下一步:"
echo "  1. 编辑 ~/.claude/skills/social-monitor/topics.yaml 改成你关注的话题"
echo "  2. 在主 Chrome 登录: x.com / linkedin.com / xiaohongshu.com / douyin.com"
echo "  3. 重启 Claude Code"
echo "  4. 在 Claude Code 里说: '/social-monitor' 或 '跑社交监控'"
echo "  5. 报告会写到: ~/social-reports/YYYY-MM-DD.md"
