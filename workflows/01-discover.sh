#!/usr/bin/env bash
# 01-discover.sh - 发现阶段工作流
# 负责分析项目上下文，生成发现报告

set -euo pipefail

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 加载 memory 工具
# shellcheck source=workflows/_memory.sh
source "${PROJECT_ROOT}/workflows/_memory.sh"

# 配置
CONTEXT_DIR="${CONTEXT_DIR:-${PROJECT_ROOT}/context}"
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

# 检查上下文
check_context() {
    log_phase "检查上下文"

    if [[ ! -d "${CONTEXT_DIR}" ]]; then
        log_error "Context 目录不存在: ${CONTEXT_DIR}"
        log_info "请创建 context 目录并添加以下文件："
        log_info "  - context/project.md"
        log_info "  - context/requirements.md"
        log_info "  - context/constraints.md"
        log_info ""
        log_info "可以使用模板："
        log_info "  cp context/templates/*.md context/"
        return 1
    fi

    # 检查必需文件
    local missing_files=()
    [[ ! -f "${CONTEXT_DIR}/project.md" ]] && missing_files+=("project.md")
    [[ ! -f "${CONTEXT_DIR}/requirements.md" ]] && missing_files+=("requirements.md")
    [[ ! -f "${CONTEXT_DIR}/constraints.md" ]] && missing_files+=("constraints.md")

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "缺少必需的上下文文件："
        for file in "${missing_files[@]}"; do
            log_error "  - ${file}"
        done
        log_info ""
        log_info "可以使用模板创建："
        log_info "  cp context/templates/*.md context/"
        return 1
    fi

    log_success "上下文检查通过"

    # 显示上下文摘要
    log_info "上下文文件："
    ls -la "${CONTEXT_DIR}"/*.md 2>/dev/null | awk '{print "  " $NF}' || true
}

# 加载提示词
load_prompt() {
    local prompt_file="${PROMPTS_DIR}/discover.txt"

    if [[ ! -f "${prompt_file}" ]]; then
        log_error "提示词文件不存在: ${prompt_file}"
        return 1
    fi

    cat "${prompt_file}"
}

# 读取上下文内容
read_context() {
    log_info "读取上下文文件..."

    local context_content="# 项目上下文\n\n"
    context_content+="> 生成时间: $(date -Iseconds)\n\n"

    # 按顺序读取
    local files=("project.md" "requirements.md" "constraints.md")
    for file in "${files[@]}"; do
        local filepath="${CONTEXT_DIR}/${file}"
        if [[ -f "$filepath" ]]; then
            context_content+="## ${file}\n\n"
            context_content+="$(cat "$filepath")\n\n"
            context_content+="---\n\n"
        fi
    done

    # 读取其他文件
    for file in "${CONTEXT_DIR}"/*.md; do
        local basename=$(basename "$file")
        if [[ ! "$basename" =~ ^(project|requirements|constraints)\.md$ ]]; then
            context_content+="## ${basename}\n\n"
            context_content+="$(cat "$file")\n\n"
            context_content+="---\n\n"
        fi
    done

    echo -e "$context_content"
}

# 探索现有代码（如果存在）
explore_codebase() {
    local project_path="$1"
    local codebase_info=""

    if [[ -d "$project_path" && "$(ls -A "$project_path" 2>/dev/null)" ]]; then
        log_info "探索现有代码库: ${project_path}"

        # 分析项目结构
        codebase_info+=$'\n## 现有代码库分析\n\n'
        codebase_info+="项目路径: ${project_path}\n\n"

        # 目录结构
        codebase_info+="### 目录结构\n\n"
        codebase_info+="\`\`\`\n"
        codebase_info+="$(cd "$project_path" && find . -type f -name "*.md" -o -name "*.json" -o -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.go" -o -name "*.rs" 2>/dev/null | head -50 | sort)"
        codebase_info+="\n\`\`\`\n\n"

        # 检测项目类型
        codebase_info+="### 项目类型检测\n\n"
        if [[ -f "${project_path}/package.json" ]]; then
            codebase_info+="检测到: Node.js 项目\n\n"
            codebase_info+="依赖信息:\n\`\`\`json\n"
            codebase_info+="$(cat "${project_path}/package.json" | jq '.dependencies // {}' 2>/dev/null || echo "{}")"
            codebase_info+="\n\`\`\`\n\n"
        elif [[ -f "${project_path}/Cargo.toml" ]]; then
            codebase_info+="检测到: Rust 项目\n\n"
        elif [[ -f "${project_path}/go.mod" ]]; then
            codebase_info+="检测到: Go 项目\n\n"
        elif [[ -f "${project_path}/pyproject.toml" ]] || [[ -f "${project_path}/setup.py" ]]; then
            codebase_info+="检测到: Python 项目\n\n"
        else
            codebase_info+="项目类型: 未明确\n\n"
        fi
    else
        codebase_info+=$'\n## 现有代码库\n\n'
        codebase_info+="这是一个新项目，没有现有代码。\n"
    fi

    echo "$codebase_info"
}

# 运行发现
run_discovery() {
    local project_path="${1:-}"

    log_phase "阶段 1: 发现阶段"

    # 1. 检查上下文
    check_context || return 1

    # 2. 初始化 memory
    log_info "初始化项目记忆..."
    memory_init

    # 3. 生成 context 摘要
    log_info "生成上下文摘要..."
    memory_summarize_context

    # 4. 准备提示词
    log_info "准备发现提示词..."
    local prompt=$(load_prompt)
    local context_content=$(read_context)

    # 5. 添加代码库信息
    local codebase_info=$(explore_codebase "$project_path")

    # 6. 构建完整指令
    local full_instruction="${prompt}

---

## 项目上下文

${context_content}

${codebase_info}

## 指令

请按照上述提示词的要求，分析项目上下文并生成完整的发现报告。

**重要**:
1. 将发现报告写入 \`memory/01-discovery.md\`
2. 报告必须完整包含所有要求的章节
3. 对不确定的信息，明确标注需要用户确认
4. 完成后报告已生成并告知用户下一步
"

    # 7. 调用 Claude 执行
    log_info "调用 Claude 执行发现分析..."
    log_info "工作目录: ${PROJECT_ROOT}"

    # 切换到项目根目录执行
    cd "${PROJECT_ROOT}"

    # 使用 Claude Code CLI
    echo "$full_instruction" | ${CLAUDE_CLI} code "${PROJECT_ROOT}" 2>&1

    # 8. 更新状态
    memory_update_state "discover" "completed" "memory/01-discovery.md"

    log_success "发现阶段完成！"
    log_info "发现报告: ${MEMORY_DIR}/01-discovery.md"

    # 9. 显示报告摘要
    if [[ -f "${MEMORY_DIR}/01-discovery.md" ]]; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  发现报告摘要"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        head -50 "${MEMORY_DIR}/01-discovery.md"
        echo "..."
        echo ""
        echo "完整报告: cat ${MEMORY_DIR}/01-discovery.md"
    fi
}

# ========================================
# 主函数
# ========================================

main() {
    local project_path=""

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<EOF
用法: 01-discover.sh [选项]

选项:
    -p, --project PATH    现有项目路径（如果是新项目则省略）
    -h, --help            显示此帮助信息

描述:
    发现阶段 - 分析项目上下文，生成发现报告

    阶段输出:
        - memory/01-discovery.md  发现报告
        - memory/00-context-summary.md  上下文摘要
        - memory/state.json       状态文件
EOF
                exit 0
                ;;
            -p|--project)
                project_path="$2"
                shift 2
                ;;
            *)
                log_error "未知选项: $1"
                exit 1
                ;;
        esac
    done

    # 运行发现
    run_discovery "$project_path"
}

# 执行主函数
main "$@"
