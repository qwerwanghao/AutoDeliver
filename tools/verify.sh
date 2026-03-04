#!/usr/bin/env bash
# verify.sh - 项目验证工具
# 用途: 根据项目类型自动运行适当的测试和构建命令

set -euo pipefail

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    elif [[ -f "${project_path}/pom.xml" ]]; then
        echo "maven"
    elif [[ -f "${project_path}/build.gradle" ]] || [[ -f "${project_path}/build.gradle.kts" ]]; then
        echo "gradle"
    else
        echo "unknown"
    fi
}

# Node.js 项目验证
verify_nodejs() {
    local project_path="$1"
    cd "${project_path}"

    log_step "Node.js 项目验证"

    # 检查npm/yarn/pnpm
    local pkg_manager="npm"
    if command -v pnpm &>/dev/null && [[ -f "pnpm-lock.yaml" ]]; then
        pkg_manager="pnpm"
    elif command -v yarn &>/dev/null && [[ -f "yarn.lock" ]]; then
        pkg_manager="yarn"
    fi

    log_info "使用包管理器: ${pkg_manager}"

    # 读取package.json中的脚本
    local scripts=$(jq -r '.scripts // {}' package.json 2>/dev/null || echo "{}")

    # 1. 类型检查（如果可用）
    if echo "$scripts" | jq -e '.type-check' >/dev/null 2>&1; then
        log_step "运行类型检查..."
        if ${pkg_manager} run type-check 2>&1; then
            log_success "类型检查通过"
        else
            log_fail "类型检查失败"
            return 1
        fi
    elif [[ -f "tsconfig.json" ]]; then
        log_step "运行TypeScript编译检查..."
        if npx tsc --noEmit 2>&1; then
            log_success "TypeScript类型检查通过"
        else
            log_fail "TypeScript类型检查失败"
            return 1
        fi
    fi

    # 2. 代码检查（如果可用）
    if echo "$scripts" | jq -e '.lint' >/dev/null 2>&1; then
        log_step "运行代码检查..."
        if ${pkg_manager} run lint 2>&1; then
            log_success "代码检查通过"
        else
            log_fail "代码检查失败"
            return 1
        fi
    fi

    # 3. 测试（如果可用）
    local test_found=false
    if echo "$scripts" | jq -e '.test' >/dev/null 2>&1; then
        local test_script=$(echo "$scripts" | jq -r '.test')
        log_step "运行测试..."

        # 检查test脚本是否只是占位符
        if [[ "${test_script}" == "echo"* ]] || [[ "${test_script}" == *"placeholder"* ]]; then
            log_info "test脚本是占位符，尝试直接运行测试文件..."

            # 查找测试文件
            if [[ -f "src/test.js" ]] || [[ -f "test.js" ]] || [[ -f "tests/test.js" ]]; then
                local test_file=""
                [[ -f "src/test.js" ]] && test_file="src/test.js"
                [[ -f "test.js" ]] && test_file="test.js"
                [[ -f "tests/test.js" ]] && test_file="tests/test.js"

                log_info "运行测试文件: ${test_file}"
                if node "${test_file}" 2>&1; then
                    log_success "测试通过"
                    test_found=true
                else
                    log_fail "测试失败"
                    return 1
                fi
            fi
        else
            # 运行实际的test脚本
            if ${pkg_manager} run test 2>&1; then
                log_success "测试通过"
                test_found=true
            else
                log_fail "测试失败"
                return 1
            fi
        fi
    fi

    # 如果没有找到test脚本，尝试查找测试文件
    if [[ "${test_found}" == false ]]; then
        log_info "未找到test脚本，查找测试文件..."
        if [[ -f "src/test.js" ]]; then
            log_step "运行 src/test.js..."
            if node src/test.js 2>&1; then
                log_success "测试通过"
            else
                log_fail "测试失败"
                return 1
            fi
        elif [[ -f "test.js" ]]; then
            log_step "运行 test.js..."
            if node test.js 2>&1; then
                log_success "测试通过"
            else
                log_fail "测试失败"
                return 1
            fi
        else
            log_info "未找到测试文件"
        fi
    fi

    # 4. 构建（如果可用）
    if echo "$scripts" | jq -e '.build' >/dev/null 2>&1; then
        log_step "运行构建..."
        if ${pkg_manager} run build 2>&1; then
            log_success "构建成功"
        else
            log_fail "构建失败"
            return 1
        fi
    fi

    log_success "Node.js 项目验证完成"
    return 0
}

# Rust 项目验证
verify_rust() {
    local project_path="$1"
    cd "${project_path}"

    log_step "Rust 项目验证"

    # 1. 代码检查
    log_step "运行 cargo clippy..."
    if cargo clippy --all-targets --all-features 2>&1; then
        log_success "Clippy 检查通过"
    else
        log_fail "Clippy 检查失败"
        return 1
    fi

    # 2. 测试
    log_step "运行 cargo test..."
    if cargo test 2>&1; then
        log_success "测试通过"
    else
        log_fail "测试失败"
        return 1
    fi

    # 3. 构建
    log_step "运行 cargo build..."
    if cargo build 2>&1; then
        log_success "构建成功"
    else
        log_fail "构建失败"
        return 1
    fi

    log_success "Rust 项目验证完成"
    return 0
}

# Go 项目验证
verify_go() {
    local project_path="$1"
    cd "${project_path}"

    log_step "Go 项目验证"

    # 1. 代码检查
    log_step "运行 go vet..."
    if go vet ./... 2>&1; then
        log_success "Go vet 通过"
    else
        log_fail "Go vet 失败"
        return 1
    fi

    # 2. 测试
    log_step "运行 go test..."
    if go test ./... 2>&1; then
        log_success "测试通过"
    else
        log_fail "测试失败"
        return 1
    fi

    # 3. 构建
    log_step "运行 go build..."
    if go build ./... 2>&1; then
        log_success "构建成功"
    else
        log_fail "构建失败"
        return 1
    fi

    log_success "Go 项目验证完成"
    return 0
}

# Python 项目验证
verify_python() {
    local project_path="$1"
    cd "${project_path}"

    log_step "Python 项目验证"

    # 1. 类型检查（如果可用）
    if command -v mypy &>/dev/null && [[ -f "mypy.ini" || -f ".mypy.ini" || -f "pyproject.toml" ]]; then
        log_step "运行 mypy..."
        if mypy . 2>&1; then
            log_success "Mypy 类型检查通过"
        else
            log_fail "Mypy 类型检查失败"
            return 1
        fi
    fi

    # 2. 代码检查（如果可用）
    if command -v flake8 &>/dev/null; then
        log_step "运行 flake8..."
        if flake8 . 2>&1; then
            log_success "Flake8 检查通过"
        else
            log_fail "Flake8 检查失败"
            return 1
        fi
    fi

    # 3. 测试（如果可用）
    if command -v pytest &>/dev/null; then
        log_step "运行 pytest..."
        if pytest 2>&1; then
            log_success "测试通过"
        else
            log_fail "测试失败"
            return 1
        fi
    elif [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
        log_step "运行 python -m pytest..."
        if python -m pytest 2>&1; then
            log_success "测试通过"
        else
            log_fail "测试失败"
            return 1
        fi
    fi

    log_success "Python 项目验证完成"
    return 0
}

# Maven 项目验证
verify_maven() {
    local project_path="$1"
    cd "${project_path}"

    log_step "Maven 项目验证"

    # 1. 测试
    log_step "运行 mvn test..."
    if mvn test 2>&1; then
        log_success "测试通过"
    else
        log_fail "测试失败"
        return 1
    fi

    # 2. 构建
    log_step "运行 mvn compile..."
    if mvn compile 2>&1; then
        log_success "编译成功"
    else
        log_fail "编译失败"
        return 1
    fi

    log_success "Maven 项目验证完成"
    return 0
}

# Gradle 项目验证
verify_gradle() {
    local project_path="$1"
    cd "${project_path}"

    log_step "Gradle 项目验证"

    local gradle_cmd="./gradlew"
    if [[ ! -f "gradlew" ]] && command -v gradle &>/dev/null; then
        gradle_cmd="gradle"
    fi

    # 1. 测试
    log_step "运行 ${gradle_cmd} test..."
    if ${gradle_cmd} test 2>&1; then
        log_success "测试通过"
    else
        log_fail "测试失败"
        return 1
    fi

    # 2. 构建
    log_step "运行 ${gradle_cmd} build..."
    if ${gradle_cmd} build 2>&1; then
        log_success "构建成功"
    else
        log_fail "构建失败"
        return 1
    fi

    log_success "Gradle 项目验证完成"
    return 0
}

# 未知类型验证
verify_unknown() {
    local project_path="$1"

    log_info "无法识别项目类型，尝试基本检查..."

    # 检查是否有测试目录
    if [[ -d "${project_path}/tests" ]] || [[ -d "${project_path}/test" ]]; then
        log_info "发现测试目录，但不知道如何运行"
    fi

    # 检查是否有 Makefile
    if [[ -f "${project_path}/Makefile" ]]; then
        log_info "发现 Makefile，尝试 'make test'..."
        cd "${project_path}"
        if make test 2>&1; then
            log_success "make test 通过"
        else
            log_info "make test 失败或不存在"
        fi
    fi

    log_info "建议: 手动指定验证命令"
    return 0
}

# 主函数
main() {
    local project_path="$1"

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
    echo "║         项目验证工具                              ║"
    echo "╚═══════════════════════════════════════════════════╝"
    echo "项目路径: ${project_path}"
    echo ""

    local project_type
    project_type=$(detect_project_type "${project_path}")

    log_info "检测到项目类型: ${project_type}"
    echo ""

    local result=0

    case "${project_type}" in
        node)
            verify_nodejs "${project_path}" || result=$?
            ;;
        rust)
            verify_rust "${project_path}" || result=$?
            ;;
        go)
            verify_go "${project_path}" || result=$?
            ;;
        python)
            verify_python "${project_path}" || result=$?
            ;;
        maven)
            verify_maven "${project_path}" || result=$?
            ;;
        gradle)
            verify_gradle "${project_path}" || result=$?
            ;;
        *)
            verify_unknown "${project_path}" || result=$?
            ;;
    esac

    echo ""
    if [[ ${result} -eq 0 ]]; then
        echo "╔═══════════════════════════════════════════════════╗"
        echo "║  ✓ 验证通过                                      ║"
        echo "╚═══════════════════════════════════════════════════╝"
    else
        echo "╔═══════════════════════════════════════════════════╗"
        echo "║  ✗ 验证失败                                      ║"
        echo "╚═══════════════════════════════════════════════════╝"
    fi

    exit ${result}
}

main "$@"
