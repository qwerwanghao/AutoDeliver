#!/usr/bin/env bash
# 02-plan.sh - 规划阶段工作流
# 负责设计架构，生成执行计划

set -euo pipefail

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 加载 memory 工具
# shellcheck source=workflows/_memory.sh
source "${PROJECT_ROOT}/workflows/_memory.sh"

# 配置
MEMORY_DIR="${MEMORY_DIR:-${PROJECT_ROOT}/memory}"
PROMPTS_DIR="${PROMPTS_DIR:-${PROJECT_ROOT}/prompts}"

# CLI 配置
CLAUDE_CMD="${CLAUDE_CMD:-claude}"
CLAUDE_CLI="${CLAUDE_CMD} --dangerously-skip-permissions"

# ========================================
# 工具函数
# ========================================

log_phase() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

log_info() {
    echo "[INFO] $(date '+%H:%M:%S') - $*"
}

log_error() {
    echo "[ERROR] $(date '+%H:%M:%S') - $*" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%H:%M:%S') - $*"
}

# ========================================
# 阶段函数
# ========================================

# 检查前置条件
check_prerequisites() {
    log_phase "检查前置条件"

    if [[ ! -f "${MEMORY_DIR}/01-discovery.md" ]]; then
        log_error "发现报告不存在: ${MEMORY_DIR}/01-discovery.md"
        log_info "请先运行发现阶段: 01-discover.sh"
        return 1
    fi

    if [[ ! -f "${MEMORY_DIR}/00-context-summary.md" ]]; then
        log_error "上下文摘要不存在"
        return 1
    fi

    log_success "前置条件检查通过"
}

# 加载提示词
load_prompt() {
    local prompt_file="${PROMPTS_DIR}/plan.txt"

    if [[ ! -f "${prompt_file}" ]]; then
        log_error "提示词文件不存在: ${prompt_file}"
        return 1
    fi

    cat "${prompt_file}"
}

# 运行规划
run_planning() {
    log_phase "阶段 2: 规划阶段"

    # 1. 检查前置条件
    check_prerequisites || return 1

    # 2. 加载 memory
    log_info "加载项目记忆..."
    local memory_context=$(memory_load_all)

    # 3. 准备提示词
    log_info "准备规划提示词..."
    local prompt=$(load_prompt)

    # 4. 构建完整指令
    local full_instruction="${prompt}

---

## 项目记忆

${memory_context}

## 指令

请基于上述发现报告和项目上下文，按照提示词要求：

1. 设计完整的系统架构 → 写入 \`memory/02-architecture.md\`
2. 记录所有技术决策 → 写入 \`memory/03-decisions.md\`
3. 定义代码约定 → 写入 \`memory/04-conventions.md\`
4. 定义 API 契约（如果适用）→ 写入 \`memory/05-api-contract.md\`
5. 生成详细执行计划 → 写入 \`memory/06-progress.md\`

**重要**:
- 架构设计要简洁实用，避免过度设计
- 每个决策都要有明确理由
- 代码约定要具体可执行
- 任务分解要细到每个任务1-2小时可完成
- 完成后告知用户下一步
"

    # 5. 调用 Claude 执行
    log_info "调用 Claude 执行规划..."
    cd "${PROJECT_ROOT}"

    echo "$full_instruction" | ${CLAUDE_CLI} code "${PROJECT_ROOT}" 2>&1

    # 6. 更新状态
    memory_update_state "plan" "completed" "memory/02-architecture.md, memory/03-decisions.md, memory/04-conventions.md, memory/06-progress.md"

    log_success "规划阶段完成！"

    # 7. 显示输出摘要
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  规划输出摘要"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local outputs=(
        "memory/02-architecture.md:架构设计"
        "memory/03-decisions.md:技术决策"
        "memory/04-conventions.md:代码约定"
        "memory/05-api-contract.md:API契约"
        "memory/06-progress.md:执行计划"
    )

    for output in "${outputs[@]}"; do
        local file="${output%%:*}"
        local desc="${output##*:}"
        if [[ -f "${MEMORY_DIR}/${file}" ]]; then
            echo "  ✅ ${desc}"
        else
            echo "  ⚠️  ${desc} (未生成)"
        fi
    done

    echo ""
    echo "查看架构: cat ${MEMORY_DIR}/02-architecture.md"
    echo "查看计划: cat ${MEMORY_DIR}/06-progress.md"
}

# ========================================
# 主函数
# ========================================

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
用法: 02-plan.sh

描述:
    规划阶段 - 基于发现报告设计架构并生成执行计划

    前置条件:
        - memory/01-discovery.md 必须存在

    阶段输出:
        - memory/02-architecture.md  架构设计
        - memory/03-decisions.md      技术决策
        - memory/04-conventions.md    代码约定
        - memory/05-api-contract.md  API契约
        - memory/06-progress.md      执行计划
EOF
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    done

    run_planning
}

# 执行主函数
main "$@"
