#!/usr/bin/env bash
# full-pipeline.sh - 五阶段完整流程主入口
# 负责协调整个 AI 自主交付流程

set -euo pipefail

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 加载 memory 工具
# shellcheck source=workflows/_memory.sh
source "${PROJECT_ROOT}/workflows/_memory.sh"

# 配置
WORKFLOWS_DIR="${PROJECT_ROOT}/workflows"
MEMORY_DIR="${MEMORY_DIR:-${PROJECT_ROOT}/memory}"

# ========================================
# 工具函数
# ========================================

log_banner() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║         AI 自主交付系统 - 五阶段完整流程                   ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

log_phase() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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

log_warning() {
    echo "[WARNING] $(date '+%H:%M:%S') - $*"
}

# 用户确认
prompt_user() {
    local message="$1"
    local default="${2:-n}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ${message}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [[ "$AUTO_CONFIRM" == "true" ]]; then
        log_info "自动确认模式: 继续"
        return 0
    fi

    read -p "继续? [Y/n] " -n 1 -r response
    echo ""

    if [[ "$response" =~ ^[Yy]$ ]] || [[ -z "$response" ]]; then
        return 0
    else
        return 1
    fi
}

# 显示当前状态
show_current_status() {
    if [[ ! -f "${MEMORY_DIR}/state.json" ]]; then
        echo "  状态: 新项目"
        return
    fi

    local current_phase=$(jq -r '.current_phase' "${MEMORY_DIR}/state.json" 2>/dev/null || echo "unknown")
    local project_id=$(jq -r '.project_id' "${MEMORY_DIR}/state.json" 2>/dev/null || echo "unknown")
    local created_at=$(jq -r '.created_at' "${MEMORY_DIR}/state.json" 2>/dev/null || echo "unknown")

    echo "  项目ID: ${project_id}"
    echo "  创建时间: ${created_at}"
    echo "  当前阶段: ${current_phase}"

    if [[ "$current_phase" != "init" ]] && [[ "$current_phase" != "unknown" ]] && [[ "$current_phase" != "null" ]]; then
        echo "  状态: 可以从 '${current_phase}' 阶段恢复"
    fi
}

# ========================================
# 阶段执行函数
# ========================================

# 执行单个阶段
run_phase() {
    local phase_name="$1"
    local phase_script="$2"
    local phase_desc="$3"

    log_phase "阶段 ${phase_name}: ${phase_desc}"

    # 记录开始时间
    local start_time=$(date +%s)

    # 执行阶段脚本
    if bash "${phase_script}"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_success "${phase_desc} 完成！(耗时: ${duration}秒)"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_error "${phase_desc} 失败！(耗时: ${duration}秒)"

        # 记录到 lessons
        if [[ -f "${PROJECT_ROOT}/lessons.md" ]]; then
            echo "" >> "${PROJECT_ROOT}/lessons.md"
            echo "## 阶段失败: ${phase_name}" >> "${PROJECT_ROOT}/lessons.md"
            echo "- 时间: $(date -Iseconds)" >> "${PROJECT_ROOT}/lessons.md"
            echo "- 阶段: ${phase_desc}" >> "${PROJECT_ROOT}/lessons.md"
            echo "- 请检查 memory/ 目录和日志排查问题" >> "${PROJECT_ROOT}/lessons.md"
        fi

        return 1
    fi
}

# ========================================
# 恢复流程
# ========================================

try_restore() {
    if ! memory_can_restore; then
        return 1
    fi

    local current_phase=$(memory_get_current_phase)

    log_warning "检测到未完成的项目，当前阶段: ${current_phase}"

    read -p "是否从该阶段继续? [Y/n] " -n 1 -r response
    echo ""

    if [[ ! "$response" =~ ^[Yy]$ ]] && [[ -n "$response" ]]; then
        log_info "重新开始流程"
        return 1
    fi

    log_info "从阶段 '${current_phase}' 恢复"

    # 根据当前阶段决定从哪里开始
    case "$current_phase" in
        discover)
            return 0
            ;;
        plan)
            # 从规划阶段开始
            run_phase "2" "${WORKFLOWS_DIR}/02-plan.sh" "规划" || return $?
            ;;
        build)
            # 从构建阶段开始
            run_phase "3" "${WORKFLOWS_DIR}/03-build.sh" "构建" || return $?
            ;;
        polish)
            # 从打磨阶段开始
            run_phase "4" "${WORKFLOWS_DIR}/04-polish.sh" "打磨" || return $?
            ;;
        *)
            log_warning "未知阶段: ${current_phase}，从头开始"
            return 1
            ;;
    esac

    return 0
}

# ========================================
# 主流程
# ========================================

run_full_pipeline() {
    local project_path="${1:-}"
    local start_from="${2:-}"

    log_banner

    # 检查是否需要恢复
    if [[ -z "$start_from" ]] && memory_can_restore; then
        if try_restore; then
            # 恢复成功，继续执行剩余阶段
            start_from="continue"
        else
            # 重新开始
            start_from="discover"
        fi
    fi

    # 确定起始阶段
    if [[ -z "$start_from" ]]; then
        start_from="discover"
    fi

    # 根据起始阶段执行流程
    case "$start_from" in
        discover)
            # 完整流程
            run_phase "1" "${WORKFLOWS_DIR}/01-discover.sh" "发现" "$project_path" || return $?

            if ! prompt_user "发现阶段已完成，查看 memory/01-discovery.md"; then
                log_warning "用户取消"
                return 1
            fi

            ;&
            # fallthrough
        plan|continue)
            run_phase "2" "${WORKFLOWS_DIR}/02-plan.sh" "规划" || return $?

            if ! prompt_user "规划阶段已完成，查看 memory/02-architecture.md 和 memory/06-progress.md"; then
                log_warning "用户取消"
                return 1
            fi

            ;&
            # fallthrough
        build)
            run_phase "3" "${WORKFLOWS_DIR}/03-build.sh" "构建" || return $?
            # 构建阶段不需要用户确认，直接继续

            ;&
            # fallthrough
        polish)
            run_phase "4" "${WORKFLOWS_DIR}/04-polish.sh" "打磨" || return $?

            if ! prompt_user "打磨阶段已完成，查看 memory/08-checklist.md"; then
                log_warning "用户取消"
                return 1
            fi

            ;&
            # fallthrough
        deliver)
            run_phase "5" "${WORKFLOWS_DIR}/05-deliver.sh" "交付" || return $?

            # 交付完成
            log_banner
            log_success "🎉 项目交付完成！"
            echo ""
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  交付物"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  📁 deliver/code/     - 代码"
            echo "  📁 deliver/docs/     - 文档"
            echo "  📁 deliver/handoff/  - 交接材料"
            echo "  📁 deliver/memory/   - 项目记忆"
            echo ""
            echo "  查看验收清单: cat deliver/handoff/CHECKLIST.md"
            echo "  查看项目总结: cat deliver/handoff/SUMMARY.md"
            echo ""
            ;;

        *)
            log_error "无效的起始阶段: ${start_from}"
            return 1
            ;;
    esac

    return 0
}

# ========================================
# 主函数
# ========================================

main() {
    local project_path=""
    local start_from=""
    local auto_confirm=false

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
用法: full-pipeline.sh [选项]

选项:
    -p, --project PATH    现有项目路径（如果是新项目则省略）
    -s, --start PHASE     从指定阶段开始 (discover|plan|build|polish|deliver)
    -y, --yes             自动确认（非交互模式）
    -h, --help            显示此帮助信息

描述:
    五阶段完整流程 - 从发现到交付的全自动 AI 开发流程

    阶段说明:
        1. discover  - 发现阶段：分析需求，生成发现报告
        2. plan      - 规划阶段：设计架构，生成执行计划
        3. build     - 构建阶段：按计划实现代码
        4. polish    - 打磨阶段：质量检查和测试
        5. deliver   - 交付阶段：生成交付物和文档

示例:
    # 完整流程（新项目）
    full-pipeline.sh

    # 从现有项目开始
    full-pipeline.sh -p /path/to/project

    # 从特定阶段开始
    full-pipeline.sh -s plan

    # 自动确认模式
    full-pipeline.sh -y

输出:
    - memory/       项目记忆和状态
    - deliver/      最终交付物
EOF
                exit 0
                ;;
            -p|--project)
                project_path="$2"
                shift 2
                ;;
            -s|--start)
                start_from="$2"
                shift 2
                ;;
            -y|--yes)
                auto_confirm=true
                export AUTO_CONFIRM="true"
                shift
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    done

    # 显示当前状态
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  当前状态"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_current_status
    echo ""

    # 运行完整流程
    if run_full_pipeline "$project_path" "$start_from"; then
        exit 0
    else
        exit 1
    fi
}

# 执行主函数
main "$@"
