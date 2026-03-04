# AI 自主交付系统

> 五阶段 AI 自主开发系统 - 从发现到交付全程 AI 参与

## 🎯 系统概述

这是一个基于 Claude 和 Codex 的 AI 自主交付系统，实现了 **发现 → 规划 → 构建 → 打磨 → 交付** 的完整开发流程。

### 核心特点

- **AI 全程参与**: 只需提供上下文，AI 自主完成从分析到交付的全流程
- **Memory 机制**: 通过持久化记忆突破 AI 上下文窗口限制
- **阶段化管理**: 五个清晰的阶段，每个阶段有明确输入输出
- **断点续传**: 支持从任意阶段恢复，灵活控制进度
- **经验学习**: 自动记录经验教训，跨项目复用

## 📋 五阶段流程

```
┌────────────────────────────────────────────────────────────────┐
│                     AI 自主交付流程                            │
└────────────────────────────────────────────────────────────────┘

  ┌──────────┐      ┌──────────┐     ┌──────────┐    ┌──────────┐    ┌──────────┐
  │          │      │          │     │          │    │          │    │          │
  │ ① 发现   │ ───▶ │ ② 规划   │───▶ │ ③ 构建   │───▶│ ④ 打磨   │───▶│ ⑤ 交付   │
  │ Discover │      │  Plan    │     │  Build   │    │  Polish  │    │ Deliver  │
  │          │      │          │     │          │    │          │    │          │
  │ ·需求分析 │      │ ·架构设计 │     │ ·编写代码  │    │ ·质量检查 │    │ ·生成文档 │
  │ ·风险识别 │      │ ·任务分解 │     │ ·功能实现  │    │ ·测试完善 │    │ ·完成交接 │
  │ ·技术选型 │      │ ·约定定义 │     │ ·持续记录  │    │ ·性能优化 │    │ ·经验总结 │
  └──────────┘      └──────────┘     └──────────┘    └──────────┘    └──────────┘
       │                 │                │                │                │
       ▼                ▼                ▼               ▼                ▼
  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
  │ 01-发现  │     │ 02-架构  │    │ 03-决策   │    │ 04-约定  │     │ 06-进度  │
  │ 报告.md  │     │ 设计.md  │    │ 记录.md   │    │ 规范.md  │     │ 跟踪.md  │
  └──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘

  用户输入                                                   Memory 持久化
  ┌──────────┐                                                   │
  │ context/ │                                                   │
  │ project  │ ──────────────────────────────────────────────────┘
  │ reqs     │              阶段间信息传递
  │ constr  │
  └──────────┘
```

## 🚀 快速开始

### 1. 安装

```bash
# 克隆仓库
git clone https://github.com/your-repo/ai-projects.git
cd ai-projects

# 确保脚本可执行
chmod +x ai-deliver
chmod +x workflows/*.sh
```

### 2. 初始化项目

```bash
# 创建上下文文件
./ai-deliver init
```

### 3. 编辑上下文

```bash
# 编辑项目概述
vi context/project.md

# 编辑需求文档
vi context/requirements.md

# 编辑约束条件
vi context/constraints.md
```

### 4. 运行流程

```bash
# 运行完整五阶段流程
./ai-deliver run

# 从现有项目开始
./ai-deliver run -p /path/to/project

# 自动确认模式（非交互）
./ai-deliver run -y
```

## 📂 项目结构

```
ai-projects/
├── ai-deliver              # 主入口命令
├── lessons.md              # 跨项目经验教训
│
├── context/                # 用户输入（只读）
│   ├── project.md          # 项目概述
│   ├── requirements.md     # 需求文档
│   ├── constraints.md      # 约束条件
│   └── templates/          # 模板文件
│
├── memory/                 # AI 工作记忆（读写）
│   ├── 00-context-summary.md
│   ├── 01-discovery.md
│   ├── 02-architecture.md
│   ├── 03-decisions.md
│   ├── 04-conventions.md
│   ├── 05-api-contract.md
│   ├── 06-progress.md
│   ├── 07-issues.md
│   ├── 08-checklist.md
│   └── state.json
│
├── deliver/                # 最终交付物
│   ├── code/               # 代码
│   ├── docs/               # 文档
│   └── handoff/            # 交接材料
│
├── workflows/              # 工作流脚本
│   ├── _memory.sh          # Memory 工具库
│   ├── 01-discover.sh      # 发现阶段
│   ├── 02-plan.sh          # 规划阶段
│   ├── 03-build.sh         # 构建阶段
│   ├── 04-polish.sh        # 打磨阶段
│   ├── 05-deliver.sh       # 交付阶段
│   └── full-pipeline.sh    # 完整流程
│
└── prompts/                # 提示词模板
    ├── discover.txt
    ├── plan.txt
    ├── build.txt
    ├── polish.txt
    └── deliver.txt
```

## 🔧 命令参考

### 主命令

```bash
ai-deliver <命令> [选项]
```

### 可用命令

| 命令 | 说明 |
|------|------|
| `init` | 初始化新项目（创建 context 文件） |
| `run` | 运行完整五阶段流程 |
| `discover` | 只运行发现阶段 |
| `plan` | 只运行规划阶段 |
| `build` | 只运行构建阶段 |
| `polish` | 只运行打磨阶段 |
| `deliver` | 只运行交付阶段 |
| `status` | 显示项目状态 |
| `memory show` | 显示项目记忆 |
| `lessons show` | 显示经验教训 |
| `clean` | 清理项目文件 |
| `help` | 显示帮助信息 |

### 选项

| 选项 | 说明 |
|------|------|
| `-p, --project PATH` | 指定项目路径 |
| `-s, --start PHASE` | 从指定阶段开始 |
| `-y, --yes` | 自动确认（非交互模式） |
| `-v, --version` | 显示版本信息 |

## 📖 详细使用

### 场景 1: 新项目开发

```bash
# 1. 初始化
ai-deliver init

# 2. 编辑需求
vi context/project.md
vi context/requirements.md
vi context/constraints.md

# 3. 运行完整流程
ai-deliver run
```

### 场景 2: 从现有项目添加功能

```bash
# 1. 指定现有项目路径
ai-deliver run -p /path/to/project

# 2. 编辑需求（说明要添加什么功能）
vi context/requirements.md

# 3. 运行流程
ai-deliver run
```

### 场景 3: 从特定阶段恢复

```bash
# 比如之前在规划阶段中断，现在继续
ai-deliver run -s plan
```

### 场景 4: 自动化/CI 模式

```bash
# 跳过所有确认，自动执行
ai-deliver run -y
```

## 🧠 Memory 机制

### 为什么需要 Memory？

AI 的上下文窗口有限，在执行长项目时会遗忘早期决策。Memory 机制通过持久化存储关键信息，确保 AI 在整个流程中保持一致性。

### Memory 文件说明

| 文件 | 说明 |
|------|------|
| `00-context-summary.md` | 用户输入的摘要 |
| `01-discovery.md` | 发现阶段产出 |
| `02-architecture.md` | 架构设计 |
| `03-decisions.md` | 技术决策记录 |
| `04-conventions.md` | 命名和风格约定 |
| `05-api-contract.md` | API 设计契约 |
| `06-progress.md` | 执行进度 |
| `07-issues.md` | 遇到的问题 |
| `08-checklist.md` | 质量检查清单 |
| `state.json` | 状态快照 |

### Memory 工作原理

1. **阶段开始时**: AI 读取所有 Memory 文件到上下文
2. **阶段进行中**: AI 更新相关 Memory 文件
3. **阶段切换时**: Memory 作为桥梁传递信息

## 📚 Context 模板

### project.md

描述项目的基本信息：
- 项目名称和类型
- 项目描述
- 目标用户
- 项目状态（新项目/现有项目）

### requirements.md

详细的功能需求：
- 核心功能（必须实现）
- 扩展功能（应该实现）
- 非功能需求（性能、安全等）

### constraints.md

任何限制和约束：
- 技术栈限制
- 资源约束
- 平台约束
- 法律合规要求

## 🎯 交付物

完成后的 `deliver/` 目录包含：

### code/
- 源代码
- 配置文件
- 依赖清单

### docs/
- README.md - 项目主文档
- API.md - API 文档（如适用）
- GUIDE.md - 使用指南
- DEPLOYMENT.md - 部署指南

### handoff/
- FEATURES.md - 功能清单
- STACK.md - 技术栈清单
- ISSUES.md - 已知问题
- SUMMARY.md - 项目总结
- CHECKLIST.md - 验收清单

## 🔍 故障排查

### 问题：找不到 claude 或 codex 命令

```bash
# 检查安装
which claude
which codex

# 安装 Claude Code CLI
npm install -g @anthropic-ai/claude-code

# 安装 Codex CLI
npm install -g codex-cli
```

### 问题：脚本没有执行权限

```bash
chmod +x ai-deliver
chmod +x workflows/*.sh
```

### 问题：想要重新开始

```bash
# 清空 memory
ai-deliver memory clean

# 清空 deliver
ai-deliver clean --all
```

### 问题：查看当前状态

```bash
ai-deliver status
```

## 🤝 贡献

欢迎贡献！请随时提交 Issue 和 Pull Request。

## 📄 许可证

MIT License

## 🙏 致谢

本系统基于以下理念：
- "独立负责的资深工程师"工作流
- "AI 技术合伙人"交付框架
- Context-Memory-Output 设计模式

---

**版本**: 1.0.0
**最后更新**: 2026-03-04
