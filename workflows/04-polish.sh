#!/usr/bin/env bash
# 04-polish.sh - 打磨阶段工作流
# 负责代码质量检查、测试和完善

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
TOOLS_DIR="${PROJECT_ROOT}/tools"

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

    if [[ ! -d "${DELIVER_CODE_DIR}" ]] || [[ -z "$(ls -A ${DELIVER_CODE_DIR} 2>/dev/null)" ]]; then
        log_error "代码目录为空: ${DELIVER_CODE_DIR}"
        log_info "请先运行构建阶段: 03-build.sh"
        return 1
    fi

    log_success "前置条件检查通过"
}

# 运行自动化检查
run_automated_checks() {
    log_phase "运行自动化检查"

    local check_results=()

    # 1. Linter 检查
    log_info "运行代码风格检查..."
    if [[ -x "${TOOLS_DIR}/lint.sh" ]]; then
        if "${TOOLS_DIR}/lint.sh" "${DELIVER_CODE_DIR}" 2>&1; then
            check_results+=("✅ Linter: 通过")
        else
            check_results+=("⚠️  Linter: 有警告")
        fi
    else
        check_results+=("⏭️  Linter: 跳过（工具不可用）")
    fi

    # 2. 类型检查
    log_info "运行类型检查..."
    # 根据项目类型运行相应的类型检查
    if [[ -f "${DELIVER_CODE_DIR}/package.json" ]]; then
        if cd "${DELIVER_CODE_DIR}" && npm run type-check 2>/dev/null; then
            check_results+=("✅ 类型检查: 通过")
        else
            check_results+=("⚠️  类型检查: 无或失败")
        fi
    fi

    # 3. 测试
    log_info "运行测试..."
    if [[ -x "${TOOLS_DIR}/verify.sh" ]]; then
        if "${TOOLS_DIR}/verify.sh" "${DELIVER_CODE_DIR}" 2>&1; then
            check_results+=("✅ 测试: 通过")
        else
            check_results+=("❌ 测试: 失败")
        fi
    else
        # 直接运行项目测试
        if cd "${DELIVER_CODE_DIR}" && npm test 2>/dev/null; then
            check_results+=("✅ 测试: 通过")
        else
            check_results+=("⚠️  测试: 未配置或失败")
        fi
    fi

    # 显示结果
    echo ""
    echo "自动化检查结果:"
    for result in "${check_results[@]}"; do
        echo "  ${result}"
    done
    echo ""
}

# 加载提示词
load_prompt() {
    local prompt_file="${PROMPTS_DIR}/polish.txt"

    if [[ ! -f "${prompt_file}" ]]; then
        log_error "提示词文件不存在: ${prompt_file}"
        return 1
    fi

    cat "${prompt_file}"
}

# 运行打磨
run_polish() {
    log_phase "阶段 4: 打磨阶段"

    # 1. 检查前置条件
    check_prerequisites || return 1

    # 2. 运行自动化检查
    run_automated_checks

    # 3. 加载 memory
    log_info "加载项目记忆..."
    local memory_context=$(memory_load_all)

    # 4. 准备提示词
    log_info "准备打磨提示词..."
    local prompt=$(load_prompt)

    # 5. 获取代码统计
    local code_stats="## 代码统计\n\n"
    code_stats+="代码目录: ${DELIVER_CODE_DIR}\n\n"

    if [[ -d "${DELIVER_CODE_DIR}" ]]; then
        code_stats+="文件统计:\n"
        code_stats+=$(find "${DELIVER_CODE_DIR}" -type f | wc -l | awk '{print "  总文件数: " $1}')
        code_stats+="\n\n"

        code_stats+="目录结构:\n\`\`\`\n"
        code_stats+=$(ls -la "${DELIVER_CODE_DIR}" 2>/dev/null | tail -n +4)
        code_stats+="\n\`\`\`\n\n"
    fi

    # 6. 构建完整指令
    local full_instruction="${prompt}

---

## 项目记忆

${memory_context}

## 代码信息

${code_stats}

## 指令

请对 \`deliver/code/\` 中的代码进行全面的质量检查和打磨：

1. 代码质量审查（风格、复杂度、重复）
2. 测试完善（覆盖率和有效性）
3. 功能验证（对照原始需求）
4. 性能优化（明显的瓶颈）
5. 安全检查（常见安全问题）
6. 文档完善（代码文档和使用文档）

将检查清单写入 \`memory/08-checklist.md\`

**重要**:
- 修复所有发现的问题
- 确保测试覆盖核心功能
- 文档要准确完整
- 质量优先于速度
"

    # 7. 调用 Codex 执行
    log_info "调用 Codex 执行打磨..."
    cd "${PROJECT_ROOT}"

    local codex_exec_cmd="${CODEX_CLI} exec"
    codex_exec_cmd="${codex_exec_cmd} --skip-git-repo-check"
    codex_exec_cmd="${codex_exec_cmd} -C \"${DELIVER_CODE_DIR}\""
    codex_exec_cmd="${codex_exec_cmd} --color never"

    echo "$full_instruction" | eval "${codex_exec_cmd}" 2>&1

    # 8. 更新状态
    memory_update_state "polish" "completed" "memory/08-checklist.md"

    log_success "打磨阶段完成！"

    # 9. 显示质量报告
    if [[ -f "${MEMORY_DIR}/08-checklist.md" ]]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  质量报告摘要"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        head -80 "${MEMORY_DIR}/08-checklist.md"
        echo "..."
        echo ""
        echo "完整报告: cat ${MEMORY_DIR}/08-checklist.md"
    fi
}

# ========================================
# 主函数
# ========================================

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
用法: 04-polish.sh

描述:
    打磨阶段 - 代码质量检查、测试和完善

    前置条件:
        - deliver/code/ 必须存在且非空

    阶段输出:
        - deliver/code/           打磨后的代码
        - memory/08-checklist.md  质量检查清单
EOF
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    done

    run_polish
}

# 执行主函数
main "$@"
