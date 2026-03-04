#!/usr/bin/env bash
# 03-build.sh - 构建阶段工作流
# 负责按计划执行代码构建

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
DELIVER_CODE_DIR="${PROJECT_ROOT}/deliver/code"

# CLI 配置
CODEX_CMD="${CODEX_CMD:-codex}"
CODEX_CLI="${CODEX_CMD} --dangerously-bypass-approvals-and-sandbox"

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

    if [[ ! -f "${MEMORY_DIR}/06-progress.md" ]]; then
        log_error "执行计划不存在: ${MEMORY_DIR}/06-progress.md"
        log_info "请先运行规划阶段: 02-plan.sh"
        return 1
    fi

    log_success "前置条件检查通过"
}

# 初始化构建目录
init_build_dir() {
    log_info "初始化构建目录..."

    mkdir -p "${DELIVER_CODE_DIR}"

    # 如果有现有项目路径，复制或链接
    # 这里假设代码直接在 deliver/code 中创建

    log_success "构建目录已准备: ${DELIVER_CODE_DIR}"
}

# 加载提示词
load_prompt() {
    local prompt_file="${PROMPTS_DIR}/build.txt"

    if [[ ! -f "${prompt_file}" ]]; then
        log_error "提示词文件不存在: ${prompt_file}"
        return 1
    fi

    cat "${prompt_file}"
}

# 运行构建
run_build() {
    log_phase "阶段 3: 构建阶段"

    # 1. 检查前置条件
    check_prerequisites || return 1

    # 2. 初始化构建目录
    init_build_dir

    # 3. 加载 memory
    log_info "加载项目记忆..."
    local memory_context=$(memory_load_all)

    # 4. 准备提示词
    log_info "准备构建提示词..."
    local prompt=$(load_prompt)

    # 5. 构建完整指令
    local full_instruction="${prompt}

---

## 项目记忆

${memory_context}

## 工作目录

代码输出目录: ${DELIVER_CODE_DIR}

## 指令

请按照 \`memory/06-progress.md\` 中的执行计划，逐步实现代码功能：

1. 遵守 \`memory/04-conventions.md\` 中的所有约定
2. 遵守 \`memory/03-decisions.md\` 中的技术决策
3. 按照任务依赖顺序执行
4. 每完成一个任务，更新 progress.md
5. 遇到问题记录到 issues.md
6. 在 ${DELIVER_CODE_DIR} 目录中创建/修改代码

**重要**:
- 先写测试，再写实现（TDD）
- 每个模块完成后进行自检
- 保持代码简洁，避免过度设计
- 持续更新进度和问题记录
- 遇到无法解决的问题，暂停并请求指导
"

    # 6. 调用 Codex 执行
    log_info "调用 Codex 执行构建..."
    log_info "目标目录: ${DELIVER_CODE_DIR}"
    cd "${PROJECT_ROOT}"

    # 使用 codex exec 非交互模式
    local codex_exec_cmd="${CODEX_CLI} exec"
    codex_exec_cmd="${codex_exec_cmd} --skip-git-repo-check"
    codex_exec_cmd="${codex_exec_cmd} -C \"${DELIVER_CODE_DIR}\""
    codex_exec_cmd="${codex_exec_cmd} --color never"

    echo "$full_instruction" | eval "${codex_exec_cmd}" 2>&1

    # 7. 更新状态
    memory_update_state "build" "completed" "deliver/code/"

    log_success "构建阶段完成！"

    # 8. 显示构建摘要
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  构建输出摘要"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ -d "${DELIVER_CODE_DIR}" ]]; then
        local file_count=$(find "${DELIVER_CODE_DIR}" -type f 2>/dev/null | wc -l)
        local dir_count=$(find "${DELIVER_CODE_DIR}" -type d 2>/dev/null | wc -l)

        echo "  代码目录: ${DELIVER_CODE_DIR}"
        echo "  文件数: ${file_count}"
        echo "  目录数: ${dir_count}"
        echo ""
        echo "  目录结构:"
        find "${DELIVER_CODE_DIR}" -type f 2>/dev/null | head -20 || true
        echo "  ..."
    fi

    echo ""
    echo "查看进度: cat ${MEMORY_DIR}/06-progress.md"
    echo "查看问题: cat ${MEMORY_DIR}/07-issues.md"
}

# ========================================
# 主函数
# ========================================

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
用法: 03-build.sh

描述:
    构建阶段 - 按照执行计划实现代码功能

    前置条件:
        - memory/06-progress.md 必须存在

    阶段输出:
        - deliver/code/           代码文件
        - memory/06-progress.md   更新的进度
        - memory/07-issues.md     问题记录
EOF
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    done

    run_build
}

# 执行主函数
main "$@"
