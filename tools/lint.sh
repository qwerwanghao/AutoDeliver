#!/usr/bin/env bash
# lint.sh - 代码检查工具
# 用途: 根据项目类型运行适当的代码检查工具

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_step() {
    echo -e "${GREEN}[STEP]${NC} $*"
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
}

# 检测项目类型
detect_project_type() {
    local project_path="$1"

    if [[ -f "${project_path}/package.json" ]]; then
        echo "node"
    elif [[ -f "${project_path}/Cargo.toml" ]]; then
        echo "rust"
    elif [[ -f "${project_path}/go.mod" ]]; then
        echo "go"
    elif [[ -f "${project_path}/pyproject.toml" ]] || [[ -f "${project_path}/setup.py" ]]; then
        echo "python"
    else
        echo "unknown"
    fi
}

# Node.js 代码检查
lint_nodejs() {
    local project_path="$1"
    local fix_mode="$2"
    cd "${project_path}"

    log_step "Node.js 代码检查"

    # 检查包管理器
    local pkg_manager="npm"
    if command -v pnpm &>/dev/null && [[ -f "pnpm-lock.yaml" ]]; then
        pkg_manager="pnpm"
    elif command -v yarn &>/dev/null && [[ -f "yarn.lock" ]]; then
        pkg_manager="yarn"
    fi

    # 检查是否有lint脚本
    local scripts=$(jq -r '.scripts // {}' package.json 2>/dev/null || echo "{}")

    if echo "$scripts" | jq -e '.lint' >/dev/null 2>&1; then
        if [[ "${fix_mode}" == true ]]; then
            # 检查是否有lint:fix脚本
            if echo "$scripts" | jq -e '.["lint:fix"]' >/dev/null 2>&1; then
                log_step "运行代码检查并自动修复..."
                ${pkg_manager} run lint:fix
            elif echo "$scripts" | jq -e '.lintfix' >/dev/null 2>&1; then
                log_step "运行代码检查并自动修复..."
                ${pkg_manager} run lintfix
            else
                log_step "运行代码检查..."
                ${pkg_manager} run lint || true
            fi
        else
            log_step "运行代码检查..."
            ${pkg_manager} run lint
        fi
    else
        # 尝试直接运行eslint
        if command -v eslint &>/dev/null; then
            log_info "使用 ESLint..."
            if [[ "${fix_mode}" == true ]]; then
                eslint . --fix
            else
                eslint .
            fi
        else
            log_info "未找到配置的代码检查工具"
            return 0
        fi
    fi

    log_success "Node.js 代码检查完成"
}

# Rust 代码检查
lint_rust() {
    local project_path="$1"
    local fix_mode="$2"
    cd "${project_path}"

    log_step "Rust 代码检查"

    local clippy_cmd="cargo clippy --all-targets --all-features"
    if [[ "${fix_mode}" == true ]]; then
        clippy_cmd="${clippy_cmd} --fix --allow-dirty --allow-staged"
    fi

    log_info "运行 Clippy..."
    ${clippy_cmd}

    log_success "Rust 代码检查完成"
}

# Go 代码检查
lint_go() {
    local project_path="$1"
    local fix_mode="$2"
    cd "${project_path}"

    log_step "Go 代码检查"

    if [[ "${fix_mode}" == true ]]; then
        log_info "运行 gofmt..."
        gofmt -w .
    fi

    log_info "运行 go vet..."
    go vet ./...

    # 检查是否安装了 golangci-lint
    if command -v golangci-lint &>/dev/null; then
        log_info "运行 golangci-lint..."
        if [[ "${fix_mode}" == true ]]; then
            golangci-lint run --fix
        else
            golangci-lint run
        fi
    fi

    log_success "Go 代码检查完成"
}

# Python 代码检查
lint_python() {
    local project_path="$1"
    local fix_mode="$2"
    cd "${project_path}"

    log_step "Python 代码检查"

    # flake8
    if command -v flake8 &>/dev/null; then
        log_info "运行 flake8..."
        flake8 .
    fi

    # pylint
    if command -v pylint &>/dev/null; then
        log_info "运行 pylint..."
        pylint . || true
    fi

    # black (格式化)
    if [[ "${fix_mode}" == true ]] && command -v black &>/dev/null; then
        log_info "运行 black (格式化)..."
        black .
    fi

    # isort (导入排序)
    if [[ "${fix_mode}" == true ]] && command -v isort &>/dev/null; then
        log_info "运行 isort (导入排序)..."
        isort .
    fi

    log_success "Python 代码检查完成"
}

# 主函数
main() {
    local project_path=""
    local fix_mode=false

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "用法: lint.sh <project_path> [options]"
                echo ""
                echo "选项:"
                echo "  --fix       自动修复可修复的问题"
                echo "  -h, --help  显示此帮助信息"
                exit 0
                ;;
            --fix)
                fix_mode=true
                shift
                ;;
            *)
                if [[ -z "${project_path}" ]]; then
                    project_path="$1"
                else
                    echo "多余的参数: $1" >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "${project_path}" ]]; then
        log_error "项目路径不能为空"
        exit 1
    fi

    if [[ ! -d "${project_path}" ]]; then
        log_error "项目目录不存在: ${project_path}"
        exit 1
    fi

    # 转换为绝对路径
    project_path="$(cd "${project_path}" && pwd)"

    echo "╔═══════════════════════════════════════════════════╗"
    echo "║         代码检查工具                              ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo "项目路径: ${project_path}"
    echo "自动修复: $([[ "${fix_mode}" == true ]] && echo "是" || echo "否")"
    echo ""

    local project_type
    project_type=$(detect_project_type "${project_path}")

    log_info "检测到项目类型: ${project_type}"
    echo ""

    case "${project_type}" in
        node)
            lint_nodejs "${project_path}" "${fix_mode}"
            ;;
        rust)
            lint_rust "${project_path}" "${fix_mode}"
            ;;
        go)
            lint_go "${project_path}" "${fix_mode}"
            ;;
        python)
            lint_python "${project_path}" "${fix_mode}"
            ;;
        *)
            log_info "未知项目类型，无法自动检查"
            ;;
    esac
}

main "$@"
