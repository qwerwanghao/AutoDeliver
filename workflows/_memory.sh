#!/usr/bin/env bash
# _memory.sh - Memory 工具库
# 用于管理 AI 项目记忆的读写操作

set -euo pipefail

# ========================================
# 配置
# ========================================

MEMORY_DIR="${MEMORY_DIR:-./memory}"
CONTEXT_DIR="${CONTEXT_DIR:-./context}"
LESSONS_FILE="${LESSONS_FILE:-./lessons.md}"

# ========================================
# 初始化
# ========================================

# 初始化 memory 目录
memory_init() {
    mkdir -p "${MEMORY_DIR}"

    # 生成项目ID
    local project_id="proj-$(date +%Y%m%d-%H%M%S)"

    # 初始化 state.json
    cat > "${MEMORY_DIR}/state.json" <<EOF
{
  "version": "1.0",
  "project_id": "${project_id}",
  "created_at": "$(date -Iseconds)",
  "current_phase": "init",
  "phases": {}
}
EOF

    # 初始化 memory 文件
    touch "${MEMORY_DIR}/00-context-summary.md"
    touch "${MEMORY_DIR}/01-discovery.md"
    touch "${MEMORY_DIR}/02-architecture.md"
    touch "${MEMORY_DIR}/03-decisions.md"
    touch "${MEMORY_DIR}/04-conventions.md"
    touch "${MEMORY_DIR}/05-api-contract.md"
    touch "${MEMORY_DIR}/06-progress.md"
    touch "${MEMORY_DIR}/07-issues.md"
    touch "${MEMORY_DIR}/08-checklist.md"

    log_info "Memory 初始化完成，项目ID: ${project_id}"
}

# ========================================
# Context 操作
# ========================================

# 从 context 目录生成摘要
memory_summarize_context() {
    if [[ ! -d "${CONTEXT_DIR}" ]]; then
        log_error "Context 目录不存在: ${CONTEXT_DIR}"
        return 1
    fi

    log_info "正在生成 context 摘要..."

    cat > "${MEMORY_DIR}/00-context-summary.md" <<EOF
# 上下文摘要

> 自动生成于: $(date -Iseconds)

## 项目概述
$(cat "${CONTEXT_DIR}/project.md" 2>/dev/null || echo "未找到 project.md")

## 核心需求
$(cat "${CONTEXT_DIR}/requirements.md" 2>/dev/null || echo "未找到 requirements.md")

## 约束条件
$(cat "${CONTEXT_DIR}/constraints.md" 2>/dev/null || echo "未找到 constraints.md")

## 其他上下文
EOF

    # 追加其他 context 文件
    for file in "${CONTEXT_DIR}"/*.md; do
        local basename=$(basename "$file")
        if [[ ! "$basename" =~ ^(project|requirements|constraints)\.md$ ]]; then
            echo "" >> "${MEMORY_DIR}/00-context-summary.md"
            echo "### ${basename}" >> "${MEMORY_DIR}/00-context-summary.md"
            cat "$file" >> "${MEMORY_DIR}/00-context-summary.md"
        fi
    done

    log_success "Context 摘要已生成"
}

# ========================================
# Memory 读取
# ========================================

# 加载所有 memory 到字符串（用于传递给 AI）
memory_load_all() {
    if [[ ! -d "${MEMORY_DIR}" ]]; then
        echo ""
        return
    fi

    local output="# 项目记忆\n\n"
    output+="> 最后更新: $(date -Iseconds)\n\n"

    # 按顺序读取 memory 文件
    local files=(
        "00-context-summary.md"
        "01-discovery.md"
        "02-architecture.md"
        "03-decisions.md"
        "04-conventions.md"
        "05-api-contract.md"
        "06-progress.md"
        "07-issues.md"
        "08-checklist.md"
    )

    for file in "${files[@]}"; do
        local filepath="${MEMORY_DIR}/${file}"
        if [[ -f "$filepath" ]] && [[ -s "$filepath" ]]; then
            output+="## ${file}\n\n"
            output+="$(cat "$filepath")\n\n"
            output+="---\n\n"
        fi
    done

    echo -e "$output"
}

# 加载特定 memory 文件
memory_load_file() {
    local filename="$1"
    local filepath="${MEMORY_DIR}/${filename}"

    if [[ -f "$filepath" ]]; then
        cat "$filepath"
    else
        echo "# ${filename}\n\n(尚未生成)"
    fi
}

# ========================================
# Memory 写入
# ========================================

# 写入到 memory 文件
memory_write() {
    local filename="$1"
    local content="$2"
    local filepath="${MEMORY_DIR}/${filename}"

    echo "$content" > "$filepath"
    log_info "已写入: ${filename}"
}

# 追加到 memory 文件
memory_append() {
    local filename="$1"
    local content="$2"
    local filepath="${MEMORY_DIR}/${filename}"

    echo -e "\n${content}" >> "$filepath"
    log_info "已追加到: ${filename}"
}

# 记录决策
memory_record_decision() {
    local decision="$1"
    local reason="${2:-}"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    cat >> "${MEMORY_DIR}/03-decisions.md" <<EOF

### ${timestamp}
**决策**: ${decision}
EOF

    if [[ -n "$reason" ]]; then
        echo "**原因**: ${reason}" >> "${MEMORY_DIR}/03-decisions.md"
    fi

    log_info "已记录决策: ${decision}"
}

# 记录问题
memory_record_issue() {
    local title="$1"
    local description="${2:-}"
    local status="${3:-open}"  # open, in_progress, resolved

    local issue_id=$(date +%s)
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    cat >> "${MEMORY_DIR}/07-issues.md" <<EOF

### #${issue_id}: ${title}
- **时间**: ${timestamp}
- **状态**: ${status}
- **描述**: ${description}
EOF

    log_info "已记录问题: #${issue_id} - ${title}"
    echo "$issue_id"
}

# 更新问题状态
memory_update_issue() {
    local issue_id="$1"
    local new_status="$2"
    local resolution="${3:-}"

    # 使用 sed 更新状态
    sed -i.bak "s/- **状态**: .*/- **状态**: ${new_status}/" "${MEMORY_DIR}/07-issues.md"

    if [[ -n "$resolution" ]]; then
        # 在问题末尾添加解决方案
        local temp_file=$(mktemp)
        awk "
            /#${issue_id}/ { found=1 }
            found && /- **状态/ {
                print \$0
                print \"- **解决方案**: ${resolution}\"
                found=0
                next
            }
            { print }
        " "${MEMORY_DIR}/07-issues.md" > "\$temp_file"
        mv "\$temp_file" "${MEMORY_DIR}/07-issues.md"
    fi

    log_info "已更新问题 #${issue_id} 状态为: ${new_status}"
}

# ========================================
# 进度管理
# ========================================

# 更新进度
memory_update_progress() {
    local phase="$1"
    local item="$2"
    local status="${3:-in_progress}"  # pending, in_progress, completed, failed

    # 确保文件存在
    if [[ ! -f "${MEMORY_DIR}/06-progress.md" ]]; then
        cat > "${MEMORY_DIR}/06-progress.md" <<EOF
# 执行进度

## 阶段
EOF
    fi

    # 更新进度项
    local mark=" "
    case "$status" in
        completed) mark="x" ;;
        failed) mark="!" ;;
        in_progress) mark=">" ;;
    esac

    local checklist_item="- [${mark}] ${phase}: ${item}"

    # 检查是否已存在该项
    if grep -q "${phase}: ${item}" "${MEMORY_DIR}/06-progress.md"; then
        # 更新现有项
        sed -i.bak "s/- \[.\] ${phase}: ${item}/[${checklist_item}/" "${MEMORY_DIR}/06-progress.md"
    else
        # 添加新项
        echo "${checklist_item}" >> "${MEMORY_DIR}/06-progress.md"
    fi
}

# ========================================
# 状态管理
# ========================================

# 更新 state.json 中的阶段状态
memory_update_state() {
    local phase="$1"
    local status="$2"
    local output="${3:-}"
    local state_file="${MEMORY_DIR}/state.json"

    if [[ ! -f "$state_file" ]]; then
        log_error "state.json 不存在，请先运行 memory_init"
        return 1
    fi

    local timestamp=$(date -Iseconds)

    # 更新当前阶段
    local temp_file=$(mktemp)
    jq "
        .current_phase = \"${phase}\" |
        .phances.\"${phase}\" = {
            \"status\": \"${status}\",
            \"timestamp\": \"${timestamp}\",
            \"output\": \"${output}\"
        } |
        if .phances.\"${phase}\".updated_at then
            .phances.\"${phase}\".updated_at = \"${timestamp}\"
        else
            .phances.\"${phase}\".updated_at = \"${timestamp}\"
        end
    " "$state_file" > "$temp_file"
    mv "$temp_file" "$state_file"

    log_info "状态已更新: ${phase} -> ${status}"
}

# 获取当前阶段
memory_get_current_phase() {
    local state_file="${MEMORY_DIR}/state.json"

    if [[ ! -f "$state_file" ]]; then
        echo ""
        return
    fi

    jq -r '.current_phase' "$state_file"
}

# 检查是否可恢复
memory_can_restore() {
    local state_file="${MEMORY_DIR}/state.json"

    if [[ ! -f "$state_file" ]]; then
        return 1
    fi

    local current=$(jq -r '.current_phase' "$state_file")
    [[ "$current" != "null" && "$current" != "" && "$current" != "completed" ]]
}

# ========================================
# Lessons 记录
# ========================================

# 记录错误到 lessons.md
memory_record_lesson() {
    local phase="$1"
    local error="$2"
    local cause="$3"
    local solution="$4"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    cat >> "${LESSONS_FILE}" <<EOF

## [${phase}] ${error}

**日期**: ${timestamp}
**阶段**: ${phase}
**错误**: ${error}
**原因**: ${cause}
**修复**: ${solution}
**避免规则**:
- 后续在 ${phase} 阶段，${solution}

EOF

    log_info "已记录经验教训到 lessons.md"
}

# ========================================
# 工具函数
# ========================================

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_success() {
    echo "[SUCCESS] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

# 导出所有函数
export -f memory_init
export -f memory_summarize_context
export -f memory_load_all
export -f memory_load_file
export -f memory_write
export -f memory_append
export -f memory_record_decision
export -f memory_record_issue
export -f memory_update_issue
export -f memory_update_progress
export -f memory_update_state
export -f memory_get_current_phase
export -f memory_can_restore
export -f memory_record_lesson
