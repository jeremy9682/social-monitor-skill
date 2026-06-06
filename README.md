# 用 Claude / Codex / OpenClaw 操控全网社交媒体 — 完整搭建指南

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/jeremy9682/social-monitor-skill?style=social)](https://github.com/jeremy9682/social-monitor-skill/stargazers)
[![GitHub last commit](https://img.shields.io/github/last-commit/jeremy9682/social-monitor-skill)](https://github.com/jeremy9682/social-monitor-skill/commits/main)
[![GitHub issues](https://img.shields.io/github/issues/jeremy9682/social-monitor-skill)](https://github.com/jeremy9682/social-monitor-skill/issues)
[![Discussions](https://img.shields.io/github/discussions/jeremy9682/social-monitor-skill)](https://github.com/jeremy9682/social-monitor-skill/discussions)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-skill-D97757)](https://docs.claude.com/claude-code)
[![MCP](https://img.shields.io/badge/MCP-compatible-blue)](https://modelcontextprotocol.io/)
[![Platforms](https://img.shields.io/badge/platforms-X%20%7C%20LinkedIn%20%7C%20Reddit%20%7C%20%E5%B0%8F%E7%BA%A2%E4%B9%A6%20%7C%20%E6%8A%96%E9%9F%B3-7c3aed)](#当前覆盖矩阵)

> **你将得到什么**：一套能让 Claude Code（订阅额度即可，无需付费API）操控你的 X / 小红书 / 抖音 / Reddit / LinkedIn / 微博 / Bluesky 账号的系统——读取相关帖子、提取热点、抽取视频内容、定时生成跨平台日报。
> 
> **目标用户**：技术能力中等的个人用户（macOS 主，Linux/Windows 适用同思路），有 Claude Code 订阅，想做日常信息流监控但不想被 X API $200/月勒索。
> 
> **本指南来自实测整理**——记录了所有踩过的坑、被 Codex 推翻的判断、网络层 debug 全流程。

## ⚖️ 免责声明 / 商标声明

**Trademarks & Affiliation**: 本仓库非官方项目，跟以下任何公司/产品都没有从属或赞助关系。所有商标归各自持有人所有。
- Claude / Claude Code / Claude in Chrome 是 Anthropic, PBC 的商标
- Codex CLI 是 OpenAI 的产品
- OpenClaw 是其各自维护者的项目
- X / LinkedIn / Reddit / 小红书 / 抖音 / Bluesky / 微博 是各自公司的商标

本指南仅供学习参考。使用者需要：
- 遵守所在地法律法规
- 遵守各社交平台 Terms of Service（X / LinkedIn / Reddit / 小红书 / 抖音 / Bluesky / 微博 等）
- **不进行**批量数据采集、商业转售、规避访问控制、高频自动化操作
- **保持人类频率**：本指南推荐的是"每天 1 次日报扫描"，不是"持续高频爬虫"
- 自行判断是否符合自己的合规要求

作者不对任何因使用本指南导致的账号封禁、数据丢失、法律责任、其他后果负责。
本指南推荐的工具均为公开开源项目，作者不持有任何商业利益。

---

## TL;DR — 三句话总结

1. **不要装"专用社交平台 MCP"做主路线**——它们都不稳，要么被平台施压删除（agent-twitter-client）、要么违反 ToS 主账号风险大（LinkedIn/X）、要么被 Clash 网络层卡死（xiaohongshu headless）
2. **Claude in Chrome（你登录态主浏览器）才是控制平面**——所有平台读/搜/发都走它，不需要任何账号 cookie 导出
3. **专用 MCP 只用于"稳定解析器+官方API"两类**——Reddit MCP（OAuth/匿名）、抖音视频解析 MCP、（可选）微信公众号官方 API MCP

---

## 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│  Claude Code (订阅额度跑，不是 API 付费)                    │
│  ├─ /social-monitor skill (自定义日报)                     │
│  └─ 编排                                                    │
│       ↓                                                      │
│  ┌──────────────────┐  ┌──────────────────────────────┐   │
│  │ Claude in Chrome │  │ 专用 MCP servers             │   │
│  │ (你登录态主Chrome)│  │ - reddit-mcp-buddy           │   │
│  │                  │  │ - douyin-video-mcp           │   │
│  │ 处理:            │  │ - (可选) 微信公众号 MCP      │   │
│  │ - X/LinkedIn 搜+读│  │                              │   │
│  │ - 小红书/抖音搜+读│  │ 处理:                        │   │
│  │ - 微博/Bluesky   │  │ - Reddit (匿名/OAuth)        │   │
│  │ - 任何要登录态的 │  │ - 抖音 URL → 无水印链接+meta │   │
│  └──────────────────┘  └──────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│  网络层 (在中国境内是关键依赖)                              │
│  Clash-Verge + Loyalsoldier ruleset (mode=rule)            │
│  - 国内站点 → DIRECT (你的真实ISP出口)                     │
│  - 国外站点 → 你的代理节点                                 │
│  - 广告/tracker → REJECT                                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🤖 跨 Agent 兼容性（Claude Code / Codex / OpenClaw）

**这套设计**是 agent-portable 的——同一份 SKILL.md + 同一组 MCP servers，三个 agent 都能用。

| 组件 | Claude Code | Codex CLI | OpenClaw |
|---|---|---|---|
| Clash + Loyalsoldier 网络层 | ✅ | ✅ | ✅ (系统级) |
| `reddit-mcp-buddy` MCP | ✅ | ✅ | ✅ (纯 MCP) |
| `douyin-video-mcp` MCP | ✅ | ✅ | ✅ |
| 登录态浏览器 | Claude in Chrome（如已安装）| Codex Browser Use 插件（如已启用）| chrome-devtools-mcp（无登录态）|
| `chrome-devtools-mcp`（公开内容/无登录） | ✅ | ✅ | ✅ |
| TweetClaw X 路线（可选） | 读本仓库 runbook 后调用 | 读本仓库 runbook 后调用 | OpenClaw plugin |
| SKILL.md 位置 | `~/.claude/skills/social-monitor/` | 读 OpenClaw symlink 或 Claude 路径 | `~/.openclaw/skills/social-monitor/`（symlink）|

### 部署到 Codex CLI

⚠️ **先备份**：Codex 配置文件改动前总是备份一次。
```bash
cp ~/.codex/config.toml ~/.codex/config.toml.bak.$(date +%s)
cp ~/.codex/AGENTS.md ~/.codex/AGENTS.md.bak.$(date +%s) 2>/dev/null || true
```

把 reddit-buddy + douyin 加到 `~/.codex/config.toml`（追加到文件末尾即可，TOML 表顺序不敏感）：

```toml
[mcp_servers.reddit-buddy]
command = "npx"
args = ["-y", "reddit-mcp-buddy"]

[mcp_servers.douyin]
command = "uvx"
args = ["douyin-video-mcp"]
```

> Codex CLI 的 `[mcp_servers.<name>]` TOML 格式自 2025 年起支持。如果你的 Codex 版本较老（不支持 MCP），先升级。

在 `~/.codex/AGENTS.md` 末尾追加一段 trigger 说明：

```markdown
# Social Monitor 跨平台社交媒体监控

触发条件：用户说"跑社交监控" / "social-monitor" / "看看今天X/小红书/抖音上有什么新东西"

读取 SKILL.md：`~/.claude/skills/social-monitor/SKILL.md` 或 `~/.openclaw/workspace-<name>/skills/social-monitor/SKILL.md`

Codex 特别提示：
- MCP servers: chrome-devtools / reddit-buddy / douyin (config.toml)
- 浏览器自动化走 browser-use 插件，不是 Claude in Chrome
- Reddit + 抖音解析走纯 MCP，无浏览器依赖
- X / LinkedIn / 小红书需要登录态，走 browser-use 或人工辅助
- 输出 ~/social-reports/YYYY-MM-DD.md
```

### 部署到 OpenClaw

OpenClaw skill 格式跟 Claude Code 完全一致（`SKILL.md` + frontmatter）。最简单的方式是 **symlink**：

```bash
# 安全 symlink 函数：先检查目标是否已存在，存在则 backup 再链接
safe_link() {
  local src="$1" dst="$2"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "${dst}.bak.$(date +%s)"  # 真实文件先备份
  fi
  ln -sfn "$src" "$dst"
}

# 主 skills 目录
mkdir -p ~/.openclaw/skills
safe_link ~/.claude/skills/social-monitor ~/.openclaw/skills/social-monitor

# 各 workspace（如果你有多个 OpenClaw workspace）
shopt -s nullglob 2>/dev/null  # bash: 通配符不匹配时返回空（避免字面值）
setopt nullglob 2>/dev/null     # zsh: 同上
for ws in ~/.openclaw/workspace-*/skills; do
  [ -d "$ws" ] && safe_link ~/.claude/skills/social-monitor "$ws/social-monitor"
done
```

这样所有 OpenClaw workspace 都能读同一份 skill。修改 `~/.claude/skills/social-monitor/SKILL.md` 自动生效全部。

### 关键差异点

**登录态浏览器**是 agent 间差异最大的环节：
- **Claude Code → Claude in Chrome**（Anthropic 浏览器扩展，可使用用户授权的 Chrome 浏览器上下文）
- **Codex CLI → Browser Use 插件**（如果你启用了它；具体名称查 Codex 自己的 marketplace）
- **OpenClaw → chrome-devtools-mcp**（无登录态——能爬公开内容，登录态站点需另外解决）

**纯 MCP 工具完全等价** — Reddit + 抖音解析在哪个 agent 跑结果都一样。

### 可选：TweetClaw X 路线

默认路线仍然是登录态浏览器，适合每天 1 次的人类频率日报。需要结构化
X/Twitter automation 时，可以增加
[`@xquik/tweetclaw`](https://www.npmjs.com/package/@xquik/tweetclaw) 作为
OpenClaw plugin 路线：search tweets、search tweet replies、follower export、
user lookup、monitor tweets、webhooks、media upload / download，以及人工确认后的
post tweets 和 post tweet replies。

完整配置、安全边界和报告格式见
[`TWEETCLAW_X_ROUTE.md`](TWEETCLAW_X_ROUTE.md)。这个路线不替代浏览器默认路线，
只在用户明确要求 TweetClaw、浏览器路线无法返回稳定结构化数据、或任务需要 API-key
工作流时启用。

## 你需要的前置环境

| 组件 | 检查命令 | 怎么装 |
|---|---|---|
| Claude Code | `which claude` | https://docs.claude.com/claude-code |
| Node.js ≥ 22 | `node --version` | nvm 或官网 |
| uv (Python) | `uv --version` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| Go ≥ 1.21 (可选, 中文项目编译) | `go version` | https://go.dev/dl/ |
| Chrome (主浏览器) | 自查 | 官网下载 |
| **Claude in Chrome 扩展** | 见下文 | https://claude.ai/in-chrome |
| Clash-Verge (中国境内必要) | 看任务栏图标 | https://www.clashverge.dev/ |

---

## Phase 1: 网络层（中国境内用户必读，海外用户可跳到 Phase 2）

### 1.1 为什么这步是基础

如果你在中国，你的 Clash 配置会决定**所有平台能不能访问**：
- 海外节点访问中国 CDN（小红书/抖音/B站）→ TLS 直接被切，错误是 `SSL_ERROR_SYSCALL`
- 数据中心 IP 节点访问 Reddit/X → 经常返回 HTTP 403（反爬黑名单）
- 配错的 mode（很多人默认开了 `global` 模式）→ 所有流量都强推到 GLOBAL 节点，rules 完全失效

**真实诊断过程**（学习目的）：
```bash
# 看你 Clash 的运行模式（关键！）
curl -s --unix-socket /tmp/verge/verge-mihomo.sock http://localhost/configs | jq .mode
# 期望: "rule"，如果是 "global" 就是问题
```

### 1.2 切换到 Rule Mode

```bash
curl --unix-socket /tmp/verge/verge-mihomo.sock -X PATCH \
  http://localhost/configs -d '{"mode":"rule"}'
```

⚠️ **运行时改了不持久化**！要持久化，编辑配置文件：

```bash
# Clash-Verge config 路径（macOS）
CLASH_DIR="$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"

# 备份
cp "$CLASH_DIR/clash-verge.yaml" "$CLASH_DIR/clash-verge.yaml.bak"

# 编辑里面的第一行 mode: global -> mode: rule
sed -i '' 's/^mode: global$/mode: rule/' "$CLASH_DIR/clash-verge.yaml"
```

### 1.3 应用 Loyalsoldier 规则集 ⭐ 强烈推荐

[Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules) 是中文社区最成熟的"国内直连+国外走代理"规则集，覆盖 32 万+ 域名/IP，每天自动更新。

**自动应用脚本**（保存为 `apply-loyalsoldier.py`）：

```python
#!/usr/bin/env python3
"""把 Loyalsoldier ruleset 注入到 Clash-Verge 配置 + 切换到 rule mode + reload mihomo"""
from ruamel.yaml import YAML
from pathlib import Path
import os, subprocess

CLASH_DIR = Path(os.path.expanduser(
    "~/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev"
))
TARGET = CLASH_DIR / "clash-verge.yaml"

# 改这里：你想让"代理"流量走哪个 group/节点
# 看 clash-verge.yaml 的 proxy-groups 段，挑一个 Selector 类型的 name
PROXY_GROUP = "PROXY"  # ⚠️ 改成你的实际 group name！看 clash-verge.yaml 里 proxy-groups 段，挑一个 Selector 类型的 name 填这里。常见值: "节点选择" / "🚀 Proxy" / "PROXY" / 你订阅服务给的中文名

mirror = "https://fastly.jsdelivr.net/gh/Loyalsoldier/clash-rules@release"
ruleset_dir = "./ruleset"
INTERVAL = 86400

providers = {
    "reject":       ("domain",    f"{mirror}/reject.txt"),
    "icloud":       ("domain",    f"{mirror}/icloud.txt"),
    "apple":        ("domain",    f"{mirror}/apple.txt"),
    "google":       ("domain",    f"{mirror}/google.txt"),
    "proxy":        ("domain",    f"{mirror}/proxy.txt"),
    "direct":       ("domain",    f"{mirror}/direct.txt"),
    "private":      ("domain",    f"{mirror}/private.txt"),
    "gfw":          ("domain",    f"{mirror}/gfw.txt"),
    "tld-not-cn":   ("domain",    f"{mirror}/tld-not-cn.txt"),
    "telegramcidr": ("ipcidr",    f"{mirror}/telegramcidr.txt"),
    "cncidr":       ("ipcidr",    f"{mirror}/cncidr.txt"),
    "lancidr":      ("ipcidr",    f"{mirror}/lancidr.txt"),
    "applications": ("classical", f"{mirror}/applications.txt"),
}

import time, tempfile

(CLASH_DIR / "ruleset").mkdir(exist_ok=True)
# 时间戳备份（每次运行不覆盖之前的 backup）
backup_path = TARGET.with_suffix(f".yaml.bak.{int(time.time())}")
backup_path.write_bytes(TARGET.read_bytes())
print(f"✓ Backup: {backup_path.name}")

yaml = YAML()
yaml.preserve_quotes = True
yaml.indent(mapping=2, sequence=2, offset=0)
yaml.width = 1000
with open(TARGET) as f:
    cfg = yaml.load(f)

if "rules" not in cfg:
    raise RuntimeError("Config has no 'rules' section — aborting to avoid corruption")

cfg["mode"] = "rule"

cfg.setdefault("rule-providers", {})
for name, (behavior, url) in providers.items():
    cfg["rule-providers"][name] = {
        "type": "http",
        "behavior": behavior,
        "url": url,
        "path": f"{ruleset_dir}/{name}.yaml",
        "interval": INTERVAL,
    }

# Insert RULE-SETs at top (before existing rules)
new_rules = [
    "RULE-SET,applications,DIRECT",
    "RULE-SET,private,DIRECT",
    "RULE-SET,reject,REJECT",
    "RULE-SET,icloud,DIRECT",
    "RULE-SET,apple,DIRECT",
    f"RULE-SET,google,{PROXY_GROUP}",
    f"RULE-SET,proxy,{PROXY_GROUP}",
    "RULE-SET,direct,DIRECT",
    f"RULE-SET,gfw,{PROXY_GROUP}",
    f"RULE-SET,tld-not-cn,{PROXY_GROUP}",
    f"RULE-SET,telegramcidr,{PROXY_GROUP},no-resolve",
    "RULE-SET,cncidr,DIRECT,no-resolve",
    "RULE-SET,lancidr,DIRECT,no-resolve",
]
existing = list(cfg["rules"])
if not any(r.startswith("RULE-SET,reject") for r in existing):
    for offset, r in enumerate(new_rules):
        cfg["rules"].insert(offset, r)

# Atomic write: write to temp file → validate → rename
tmp = TARGET.with_suffix(f".yaml.tmp.{os.getpid()}")
with open(tmp, "w") as f:
    yaml.dump(cfg, f)
# Validate by re-loading
with open(tmp) as f:
    yaml.load(f)  # raises if corrupted
os.replace(tmp, TARGET)

# Reload mihomo
subprocess.run([
    "curl", "--unix-socket", "/tmp/verge/verge-mihomo.sock",
    "-X", "PUT", "http://localhost/configs?force=true",
    "-d", "{}"
])
print("✓ Loyalsoldier applied + mihomo reloaded")
```

```bash
pip install ruamel.yaml
python3 apply-loyalsoldier.py
```

### 1.4 验证

```bash
# 1. xiaohongshu TLS 通了
curl -sI --max-time 8 https://www.xiaohongshu.com/ | head -1
# 期望: HTTP/2 200 或 30x，不是 SSL_ERROR_SYSCALL

# 2. Reddit 不被 403
curl -sI --max-time 8 https://www.reddit.com/ | head -1
# 期望: HTTP/2 200，如果 403 → 换 Clash 节点（避开 Cogent 数据中心 IP）

# 3. 你和 Claude 的连接没断
curl -sI --max-time 8 https://api.anthropic.com/ | head -1
# 期望: 4xx (TLS 握手成功就行)

# 4. 看哪些 RULE-SET 在生效
curl -s --unix-socket /tmp/verge/verge-mihomo.sock http://localhost/providers/rules
```

### 1.5 海外用户的简化版

不用 Loyalsoldier。直接：
```bash
curl --unix-socket /tmp/verge/verge-mihomo.sock -X PATCH \
  http://localhost/configs -d '{"mode":"rule"}'
```
然后跳到 Phase 2。

---

## Phase 2: 安装 Claude in Chrome 扩展

这是**整个系统的核心**——它让 Claude 能驱动你登录态的真实 Chrome。

1. 访问 https://claude.ai/in-chrome 安装扩展
2. 在 Claude Code 里验证 MCP 已加载：

```bash
claude mcp list 2>&1 | grep -i chrome
# 期望看到 chrome-devtools 类的 MCP（注意：Claude in Chrome 扩展是绑在 Claude.ai 账号上的，不在 mcp list 里）
```

在 Claude Code 会话里你应该有这些工具可用：
- `mcp__Claude_in_Chrome__navigate`
- `mcp__Claude_in_Chrome__get_page_text`
- `mcp__Claude_in_Chrome__browser_batch`
- 等等

### 在主 Chrome 登录所有你想用的平台

为了 Claude 能驱动你登录态浏览器，**你自己手动**在 Chrome 里登录这些平台一次：

| 平台 | URL | 必须？ |
|---|---|---|
| X | https://x.com | ✅ |
| LinkedIn | https://linkedin.com | ✅ |
| 小红书 | https://xiaohongshu.com | ✅ |
| 抖音 | https://douyin.com | 推荐（搜索需要） |
| 微博 | https://weibo.com | 可选 |
| Bluesky | https://bsky.app | 可选 |

**重要**：这些登录是你自己的浏览器 session，Claude 不需要你导出 cookie。

---

## Phase 3: 装两个真正稳定的 MCP

### 3.1 Reddit MCP（reddit-mcp-buddy）

```bash
claude mcp add --transport stdio reddit-buddy -s user -- npx -y reddit-mcp-buddy
claude mcp list | grep reddit
# 期望: ✓ Connected
```

**测试**：
```bash
# 调一下 search_reddit
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"0"}}}' | npx -y reddit-mcp-buddy
```

⚠️ **API schema gotcha**（实际踩过的坑）：
- `search_reddit` 返回 `{"results":[...]}`
- `browse_subreddit` 返回 `{"posts":[...]}`
- 两个 key 不一样，写 client 时别混用

如果遇到 HTTP 403：
- 你的 Clash 出口节点在 Reddit 黑名单。换节点（避开 Cogent ISP 等数据中心 IP）
- 或者注册 Reddit script app 走 OAuth：[reddit.com/prefs/apps](https://www.reddit.com/prefs/apps) → script type → 拿 `client_id` + `secret` → 加进 MCP env

### 3.2 抖音视频解析 MCP（douyin-video-mcp）

```bash
claude mcp add --transport stdio douyin -s user -- uvx douyin-video-mcp
claude mcp list | grep douyin
# 期望: ✓ Connected
```

**3 个工具**：
- `parse_douyin_video_info(share_link)` — **不需要 API key**，返回 title/description/cover/like/author
- `get_douyin_download_link(share_link)` — **不需要 API key**，返回无水印下载 URL
- `extract_douyin_text(share_link)` — 需要阿里云 DASHSCOPE_API_KEY 才能跑（音频转文字）

🔑 **重要发现**：你**不需要** ASR 转写。作者填的 description 字段已经包含了视频要点+话题标签+完整简介，**能覆盖 80-90% 信息**。这跟 OpenClaw 的"抖音视频内容提取"是同一回事——调第三方解析 API 拿 description，不是真正的 ASR。

**支持的 URL 格式**：
- ✅ `https://v.douyin.com/XXXXX/` (手机APP分享短链)
- ✅ `https://jingxuan.douyin.com/m/video/{id}`
- ✅ `https://m.douyin.com/share/video/{id}`
- ❌ `https://www.douyin.com/shipin/{id}` (网页版URL，MCP 不支持，会报 "list index out of range")

---

## Phase 4: 不要装的几个 MCP（避雷）

整个调研过程踩过的雷，记录给后来者：

| 想装什么 | 为什么别装 |
|---|---|
| `EnesCinr/twitter-mcp` (391★ X MCP) | 9 个月没更新，依赖废弃的 X API v1.1 |
| `agent-twitter-client` 系列（X 无 API key） | 原仓库被 X 施压删除（[issue#5074](https://github.com/elizaOS/eliza/issues/5074)）。X automation 规则明确说 non-API 网页自动化"may result in permanent suspension" |
| `stickerdaniel/linkedin-mcp-server` (1.8K★) | LinkedIn 明文禁止"浏览器扩展和自动化抓取"，主账号上跑随时被 restrict |
| `xpzouying/xiaohongshu-mcp` (13K★) | Go + headless Chromium，跟 Clash TUN 模式高度不兼容（[详见我们的真实 debug 过程](#踩坑记录)）。**用 Claude in Chrome 替代**就好 |
| `yzfly/douyin-mcp-server` (873★) | 已 archived。**装 fancyboi999/douyin-video-mcp 替代** |
| 任何"必须 X API key"的 MCP | 个人版 Basic 档 $200/月，免费档每月 100 推。**别为 X 付费 API** |

**核心法则**：消费/读取信息走 Claude in Chrome；视频解析、Reddit、官方 API 才装专用 MCP。

---

## Phase 5: 安装 /social-monitor skill

把整套流程封装成一个可重用的 Claude Code skill。

```bash
mkdir -p ~/.claude/skills/social-monitor
mkdir -p ~/social-reports
```

### 5.1 创建 SKILL.md

```bash
cat > ~/.claude/skills/social-monitor/SKILL.md <<'SKILL_EOF'
---
name: social-monitor
description: 跨平台社交媒体监控与内容提取。每天/按需扫描X、LinkedIn、Reddit、小红书、抖音上用户关注话题的高互动帖子，提取标题+作者+互动数据+正文摘要，去重历史已见，生成markdown日报。**触发词**：social monitor / 跑社交监控 / 看看今天X/小红书/抖音上有什么新东西 / 监控AI话题 / 跨平台搜索 / daily social / 信息收集 / 信息流监控 / 社交日报。**配置文件**：~/.claude/skills/social-monitor/topics.yaml。**输出**：~/social-reports/YYYY-MM-DD.md。
---

# Social Monitor 执行手册

## 前置自检（每次执行前）

```bash
claude mcp list | grep -E "reddit-buddy|douyin"   # 都应 ✓ Connected
curl -sI --max-time 5 https://www.xiaohongshu.com/ | head -1   # 期望 200/30x
curl -sI --max-time 5 https://www.reddit.com/ | head -1         # 期望 200
```

任一失败 → 立刻报告用户，不继续。

## 工作流

### Step 1: 加载配置 + 历史
- 读 `~/.claude/skills/social-monitor/topics.yaml`
- 读 `~/.claude/skills/social-monitor/seen.jsonl`（去重）

### Step 2: 平台抓取（能并行就并行）

**X**: navigate `https://x.com/search?q=<topic>+min_faves:500&f=top` → wait 4s → get_page_text → 抽 top 帖

**LinkedIn**: navigate `https://www.linkedin.com/search/results/content/?keywords=<topic>&sortBy=date_posted` → get_page_text

**Reddit**: 调 `mcp__reddit-buddy__search_reddit({query, limit})`。返回 `.results[]`（**不是 .posts**！）

**小红书**: navigate `https://www.xiaohongshu.com/search_result?keyword=<topic_cn>&type=51&source=web_explore_feed` → get_page_text

**抖音**:
1. navigate `https://www.google.com/search?q=site:douyin.com+"<topic_cn>"`
2. javascript_exec 提取 `a[href*="douyin.com"]` 里的 `/video/`、`/share/`、`jingxuan` 链接
3. 对每个 URL 调 `mcp__douyin__parse_douyin_video_info(share_link)`
4. **跳过 `/shipin/` 格式 URL**（MCP 不支持）

### Step 3: 去重
对每个抓到的 post/note/video，查 seen.jsonl 是否已存在唯一 ID。已见跳过。

### Step 4: 生成报告
写到 `~/social-reports/YYYY-MM-DD.md`，结构包含 TL;DR + 趋势观察 + 各平台分组。

### Step 5: 更新 seen.jsonl
追加今日新条目。

## 错误处理

- **小红书登录弹窗** → 报告 "session expired"，要求用户在主 Chrome 重登
- **Reddit 403** → 提示用户切 Clash 节点
- **抖音 captcha 中间页** → 改用 Google site: 搜索绕过
- **TLS_ERROR** → 检查 Clash mode=rule + DOMAIN-SUFFIX,xiaohongshu.com,DIRECT

## 不该做的

- ❌ 不批量爬数据（这是趋势监控不是数据采集）
- ❌ 不发帖（明确"用 Chrome 帮我发推"才发）
- ❌ 不用 agent-twitter-client 系列（X 会封号）
SKILL_EOF
```

### 5.2 创建 topics.yaml（你的关注话题）

```bash
cat > ~/.claude/skills/social-monitor/topics.yaml <<'YAML_EOF'
# 改这里 → 改你的关注话题

topics:
  - "AI agent"
  - "AI OS"
  - "MCP"
  - "Claude Code"

topics_cn:
  - "AI agent"
  - "AI 智能体"
  - "MCP"
  - "Claude Code"

platforms:
  x: true
  linkedin: true
  reddit: true
  xiaohongshu: true
  douyin: true
  bluesky: false   # 待登录后启用
  weibo: false     # 待登录后启用

thresholds:
  x: { min_faves: 500, min_views: 10000 }
  linkedin: {}
  reddit: { min_score: 50 }
  xiaohongshu: { min_likes: 100 }
  douyin: {}

top_n_per_topic: 5
deep_read_n: 2

output_dir: ~/social-reports
YAML_EOF
```

### 5.3 初始化空文件

```bash
touch ~/.claude/skills/social-monitor/seen.jsonl
```

### 5.4 重启 Claude Code，验证 skill 注册

```bash
# 在新的 Claude Code 会话里，输入 /
# 应该能看到 social-monitor 在 skills 列表里
```

---

## Phase 6: 跑第一次 + 定时任务

### 第一次跑

在 Claude Code 里：
```
/social-monitor
```
或对 Claude 说："跑社交监控" / "看看今天 AI agent 话题在 X/小红书/Reddit 有什么新东西"

报告会出现在 `~/social-reports/YYYY-MM-DD.md`。

### 挂定时任务（可选）

**方法 A**：用 Anthropic 的 `schedule` skill
```
schedule "social-monitor daily" cron="0 9 * * *" prompt="/social-monitor"
```

**方法 B**：用 `loop` skill
```
/loop daily 09:00 /social-monitor
```

**方法 C**：系统 cron（持久化最强）
```bash
crontab -e
# 加: 0 9 * * * cd ~/.claude/skills/social-monitor && claude --skill social-monitor
```

---

## 真实运行示例（一次完整跑的输出节选）

```
跨平台 50 条候选 → 去重过门槛 → 38 条新增

🔥 今天最值得看 Top 5:
1. 小红书 "15分钟Claude Code小白入门" — 3.4万赞 🔥
2. 小红书 "智能体搭建完整方法" — 1.7万赞
3. X @VoriHQ Retail AI OS Series B $22M — 8.5K 赞
4. 小红书 "保姆级教程！彻底搞懂Claude Code Skill" — 7,410赞
5. 小红书 "巴菲特芒格炼化成Agent 量子位开源" — 6,808赞

整体趋势:
- Claude Code 在中文圈彻底起飞（>1万赞帖一堆）
- "AI OS" 是分散概念（融资叙事 + 技术内涵两条线）
- Agent 泡沫警惕信号已出（"99%会死掉"高赞）
```

---

## 踩坑记录（学习用，节省你的时间）

### 坑 1: Clash 默认 mode=global
**症状**：所有平台 TLS 失败、Reddit 403、xiaohongshu 连不上
**根因**：global 模式下所有流量都走 GLOBAL 选定节点（往往是某个海外节点），rules 完全失效
**修复**：切到 `mode: rule`，**修改文件持久化**（不只改运行时）

### 坑 2: 试图给 xpzouying/xiaohongshu-mcp 配 cookies
**症状**：以为手动导 cookies.json 就能跳过 headless 登录
**根因**：cookies 只跳过 auth，但 go-rod headless Chromium 还是要走 Clash 网络层加载 xiaohongshu.com，TLS 在网络层就被切了
**修复**：**完全跳过这个 MCP**，用 Claude in Chrome（你登录态主浏览器）替代

### 坑 3: 给抖音视频提取办 DASHSCOPE_API_KEY
**症状**：以为"内容提取"就是 ASR 转写
**根因**：作者填的 description 字段已经覆盖 80-90% 信息
**修复**：用 `parse_douyin_video_info`（无需 key）就够。看 OpenClaw 的实际做法也是这样

### 坑 4: 装了 LinkedIn / X 专用 MCP
**症状**：LinkedIn 主账号被风控警告 / X 账号被限流
**根因**：两个平台 ToS 明文禁止 scraping/自动化
**修复**：走 Claude in Chrome 路线，所有操作"看起来像真人在用"

### 坑 5: search_reddit 返回 0 条以为 MCP 坏了
**症状**：`browse_subreddit` 工作但 `search_reddit` 返回空
**根因**：两个工具的返回 key 不一样（`.posts` vs `.results`）
**修复**：写客户端时按工具区分

### 坑 6: 抖音搜索页 captcha
**症状**：登录抖音网页版后搜索仍触发验证码
**根因**：抖音对登录用户也偶发反爬触发 captcha
**修复**：用 Google `site:douyin.com` 搜索绕过，提取真实 URL 后丢给 MCP

---

## 何时考虑换/扩展

- **想加 Bluesky / 微博 / 知乎** → 在主 Chrome 登录这些平台 → 改 topics.yaml 把对应 platforms 设为 true → 在 SKILL.md 里加对应路线（参考小红书的写法）
- **想加微信公众号发草稿** → 装 [`xwang152-jack/wechat-official-account-mcp`](https://github.com/xwang152-jack/wechat-official-account-mcp)，需要公众号开发者后台的 AppID + AppSecret
- **想做趋势分析（不只是日报）** → 月底跑一次累积分析任务，让 Claude 读 ~/social-reports 里所有 markdown 输出，做趋势总结
- **想发帖（不只是读）** → 直接对 Claude 说"用 Chrome 帮我在 X 发一条..."（每次都需要你确认 send 按钮）

---

## 致谢与参考

- [Loyalsoldier/clash-rules](https://github.com/Loyalsoldier/clash-rules) — Clash 规则集，本指南强烈推荐
- [karanb192/reddit-mcp-buddy](https://github.com/karanb192/reddit-mcp-buddy) — Reddit MCP
- [fancyboi999/douyin-video-mcp](https://github.com/fancyboi999/douyin-video-mcp) — 抖音视频解析 MCP
- [d60/twikit](https://github.com/d60/twikit) — 知道有这个但**不推荐用**（X 风险）
- [Codex CLI](https://github.com/openai/codex) — 整套调研的"second opinion"提供方
- 实测整理

---

## License

随便用。改了请自己负责。

---

## Q&A

**Q: 我没有中国境内的网络，能用吗？**
A: 能。跳过 Phase 1 的 Loyalsoldier 部分，只做 mode=rule 切换。X/LinkedIn/Reddit 都能用。但小红书/抖音可能会因 CDN 拒境外 IP 而部分功能失效——只能尽力。

**Q: 我不用 Clash，用 Surge / Mihomo Party / Quantumult X 行吗？**
A: 行。原理一样：mode=rule + Loyalsoldier ruleset + 关键域名走 DIRECT。具体配置 syntax 看你工具的文档。

**Q: 这套花钱吗？**
A: Claude Code 订阅 + 你已有 VPN 服务，**没有额外费用**。Loyalsoldier 免费，所有 MCP 免费。**绝对不要**为 X API 付钱。

**Q: 会不会被平台封号？**
A: Claude in Chrome 模拟的是你真人在自己浏览器里点击，平台几乎无法区分。但**别滥用**——别让它每分钟刷 100 次某个 topic，别让它批量发帖。**保持人类频率**就安全。

**Q: 多平台日报真的有用吗？**
A: 看你需要。本指南记录的真实运行挖出了 X@garrytan 关于 OpenClaw 的爆款帖、小红书 3.4 万赞 Claude Code 入门教程、Polymarket 关于 Palantir AI OS 的 319K 阅读帖——这些都是有信号价值的内容，比刷信息流被算法投喂高效。

---

**搭建完成后跟着 [Phase 6 第一次跑](#phase-6-跑第一次--定时任务) 做就行。Good luck.**
