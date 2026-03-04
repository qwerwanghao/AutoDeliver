#!/usr/bin/env bash
# 05-deliver.sh - 交付阶段工作流
# 负责生成交付物和完成交接

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
DELIVER_DIR="${PROJECT_ROOT}/deliver"
DELIVER_CODE_DIR="${DELIVER_DIR}/code"
DELIVER_DOCS_DIR="${DELIVER_DIR}/docs"
DELIVER_HANDOFF_DIR="${DELIVER_DIR}/handoff"

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
        log_info "请先运行前面的阶段"
        return 1
    fi

    log_success "前置条件检查通过"
}

# 初始化交付目录
init_deliver_dirs() {
    log_info "初始化交付目录..."

    mkdir -p "${DELIVER_DOCS_DIR}"
    mkdir -p "${DELIVER_HANDOFF_DIR}"

    log_success "交付目录已准备"
}

# 复制 memory 到交付目录
copy_memory_to_deliver() {
    log_info "复制项目记忆到交付目录..."

    local deliver_memory_dir="${DELIVER_DIR}/memory"
    mkdir -p "${deliver_memory_dir_dir}"

    cp -r "${MEMORY_DIR}"/* "${deliver_memory_dir_dir}/" 2>/dev/null || true

    log_success "项目记忆已复制"
}

# 加载提示词
load_prompt() {
    local prompt_file="${PROMPTS_DIR}/deliver.txt"

    if [[ ! -f "${prompt_file}" ]]; then
        log_error "提示词文件不存在: ${prompt_file}"
        return 1
    fi

    cat "${prompt_file}"
}

# 获取项目元数据
get_project_metadata() {
    local metadata="## 项目元数据\n\n"

    if [[ -f "${MEMORY_DIR}/state.json" ]]; then
        metadata+="项目ID: $(jq -r '.project_id' "${MEMORY_DIR}/state.json" 2>/dev/null || echo "未知")\n"
        metadata+="开始时间: $(jq -r '.created_at' "${MEMORY_DIR}/state.json" 2>/dev/null || echo "未知")\n"
    fi
    metadata+="交付时间: $(date -Iseconds)\n"

    echo -e "$metadata"
}

# 运行交付
run_deliver() {
    log_phase "阶段 5: 交付阶段"

    # 1. 检查前置条件
    check_prerequisites || return 1

    # 2. 初始化交付目录
    init_deliver_dirs

    # 3. 加载 memory
    log_info "加载项目记忆..."
    local memory_context=$(memory_load_all)

    # 4. 准备提示词
    log_info "准备交付提示词..."
    local prompt=$(load_prompt)

    # 5. 获取项目元数据
    local metadata=$(get_project_metadata)

    # 6. 构建完整指令
    local full_instruction="${prompt}

---

## 项目记忆

${memory_context}

${metadata}

## 指令

请生成交付物到以下目录：

1. **deliver/docs/** - 文档
   - README.md (项目主文档)
   - API.md (API文档，如适用)
   - GUIDE.md (使用指南)
   - DEPLOYMENT.md (部署指南)

2. **deliver/handoff/** - 交接材料
   - FEATURES.md (功能清单)
   - STACK.md (技术栈清单)
   - ISSUES.md (已知问题)
   - SUMMARY.md (项目总结)
   - CHECKLIST.md (验收清单)

3. **deliver/code/** - 代码已在构建阶段生成

**重要**:
- 文档要准确、完整、易懂
- 代码示例必须经过验证
- 遵循标准文档格式
- 交付物要专业、可直接使用
"

    # 7. 调用 Codex 执行
    log_info "调用 Codet 生成交付物..."
    cd "${PROJECT_ROOT}"

    local codex_exec_cmd="${CODEX_CLI} exec"
    codex_exec_cmd="${codex_exec_cmd} --skip-git-repo-check"
    codex_exec_cmd="${codex_exec_cmd} -C \"${DELIVER_DIR}\""
    codex_exec_cmd="${codex_exec_cmd} --color never"

    echo "$full_instruction" | eval "${codex_exec_cmd}" 2>&1

    # 8. 复制 memory
    copy_memory_to_deliver

    # 9. 更新状态
    memory_update_state "deliver" "completed" "deliver/"
    jq '.current_phase = "completed" | .completed_at = "'$(date -Iseconds)'" | .deliver_dir = "./deliver"' "${MEMORY_DIR}/state.json" > "${MEMORY_DIR}/state.json.tmp"
    mv "${MEMORY_DIR}/state.json.tmp" "${MEMORY_DIR}/state.json"

    log_success "交付阶段完成！"

    # 10. 显示交付摘要
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  交付物摘要"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local sections=(
        "deliver/code/:代码"
        "deliver/docs/:文档"
        "deliver/handoff/:交接材料"
        "deliver/memory/:项目记忆"
    )

    for section in "${sections[@]}"; do
        local dir="${section%%:*}"
        local desc="${section##*:}"
        if [[ -d "${PROJECT_ROOT}/${dir}" ]]; then
            local count=$(find "${PROJECT_ROOT}/${dir}" -type f 2>/dev/null | wc -l)
            echo "  ✅ ${desc}: ${count} 个文件"
        fi
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  交付报告"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ -f "${DELIVER_HANDOFF_DIR}/SUMMARY.md" ]]; then
        head -60 "${DELIVER_HANDOFF_DIR}/SUMMARY.md"
        echo "..."
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  📦 交付完成！"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "交付物位置: ${DELIVER_DIR}"
    echo ""
    echo "关键文件:"
    echo "  README:        ${DELIVER_DOCS_DIR}/README.md"
    echo "  使用指南:      ${DELIVER_DOCS_DIR}/GUIDE.md"
    echo "  功能清单:      ${DELIVER_HANDOFF_DIR}/FEATURES.md"
    echo "  验收清单:      ${DELIVER_HANDOFF_DIR}/CHECKLIST.md"
    echo "  项目总结:      ${DELIVER_HANDOFF_DIR}/SUMMARY.md"
    echo ""
    echo "下一步:"
    echo "  1. 查看验收清单: cat ${DELIVER_HANDOFF_DIR}/CHECKLIST.md"
    echo "  2. 查看项目总结: cat ${DELIVER_HANDOFF_DIR}/SUMMARY.md"
    echo "  3. 测试交付物: cd ${DELIVER_DIR} && [测试命令]"
}

# ========================================
# 主函数
# ========================================

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
用法: 05-deliver.sh

描述:
    交付阶段 - 生成交付物和完成交接

    前置条件:
        - deliver/code/ 必须存在且非空

    阶段输出:
        - deliver/docs/     文档
        - deliver/handoff/  交接材料
        - deliver/memory/   项目记忆副本
EOF
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    done

    run_deliver
}

# 执行主函数
main "$@"
