#!/usr/bin/env bash
# nvim-config 설치 스크립트 (Ubuntu/WSL, macOS)
#
#   Neovim, Java(SDKMAN), Maven, Gradle, uv, Claude Code, tree-sitter CLI를 설치하고
#   이 저장소를 ~/.config/nvim 에 받은 뒤 플러그인 / treesitter 파서 / Mason 도구까지 설치한다.
#   이미 설치된 항목은 건너뛰므로 여러 번 실행해도 안전하다.
#
#   사용법:  bash bootstrap.sh [--skip-system]
#     --skip-system   apt/brew 시스템 패키지 설치 단계를 건너뜀 (sudo 없이 실행)
#
#   환경 변수:
#     NVIM_CONFIG_REPO  clone할 저장소 (기본: https://github.com/audro06/nvim-config.git)
set -euo pipefail

REPO_URL="${NVIM_CONFIG_REPO:-https://github.com/audro06/nvim-config.git}"
NVIM_VERSION="v0.12.6"
TREE_SITTER_VERSION="v0.26.7"
JAVA_MAJOR="26"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"
LOCAL_BIN="$HOME/.local/bin"
LOCAL_OPT="$HOME/.local/opt"

# Mason으로 설치할 도구 (언어 서버 / 디버거 / 포매터)
MASON_PACKAGES="clangd codelldb lua-language-server stylua jdtls java-debug-adapter java-test pyright ruff debugpy"
# treesitter 파서 (init.lua 기본 목록 + C++/Java/Python)
TS_PARSERS="'bash','c','cpp','diff','html','java','lua','luadoc','markdown','markdown_inline','python','query','vim','vimdoc'"

SKIP_SYSTEM=0
for arg in "$@"; do
  case "$arg" in
    --skip-system) SKIP_SYSTEM=1 ;;
    -h | --help)
      sed -n '2,13p' "$0"
      exit 0
      ;;
    *)
      echo "알 수 없는 옵션: $arg" >&2
      exit 1
      ;;
  esac
done

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
skip() { printf '\033[2m  - %s (%s)\033[0m\n' "$1" "${2:-이미 설치됨}"; }
die() {
  printf '\033[1;31m오류:\033[0m %s\n' "$*" >&2
  exit 1
}

OS="$(uname -s)"
case "$(uname -m)" in
  x86_64 | amd64) ARCH=x86_64 ;;
  arm64 | aarch64) ARCH=arm64 ;;
  *) die "지원하지 않는 CPU 아키텍처: $(uname -m)" ;;
esac
case "$OS" in
  Linux) PLATFORM=linux ;;
  Darwin) PLATFORM=macos ;;
  *) die "지원하지 않는 OS: $OS (Ubuntu/WSL, macOS만 지원)" ;;
esac

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$LOCAL_BIN" "$LOCAL_OPT"
export PATH="$LOCAL_BIN:$PATH"

download() { curl -fsSL --retry 3 -o "$2" "$1"; }

# ---------------------------------------------------------------- 시스템 패키지
install_system_packages() {
  if [ "$SKIP_SYSTEM" = 1 ]; then
    info "시스템 패키지 설치 건너뜀 (--skip-system)"
    return
  fi

  if [ "$PLATFORM" = linux ]; then
    command -v apt-get >/dev/null || die "apt-get이 없습니다. Ubuntu/Debian 계열만 지원합니다. (--skip-system으로 건너뛸 수 있음)"
    # build-essential: C/C++ 컴파일러 (treesitter 파서 빌드, C++ 코테)
    # nodejs/npm: pyright 언어 서버 / python3-venv: Mason의 debugpy
    local pkgs=(git curl unzip zip build-essential ripgrep python3-venv nodejs npm)
    local missing=()
    for p in "${pkgs[@]}"; do dpkg -s "$p" >/dev/null 2>&1 || missing+=("$p"); done
    if [ ${#missing[@]} -eq 0 ]; then
      skip "apt 패키지"
    else
      info "apt 패키지 설치 (sudo 비밀번호가 필요할 수 있음): ${missing[*]}"
      sudo apt-get update
      sudo apt-get install -y "${missing[@]}"
    fi
  else
    command -v brew >/dev/null || die "Homebrew가 필요합니다: https://brew.sh 설치 후 다시 실행하세요."
    xcode-select -p >/dev/null 2>&1 || die "Xcode Command Line Tools가 필요합니다: xcode-select --install 실행 후 다시 실행하세요."
    # gcc: bits/stdc++.h를 쓰는 C++ 코테 코드용 (macOS 기본 g++는 clang이라 지원 안 함)
    local pkgs=(git curl ripgrep node python gcc unzip zip)
    local missing=()
    for p in "${pkgs[@]}"; do brew list --formula "$p" >/dev/null 2>&1 || missing+=("$p"); done
    if [ ${#missing[@]} -eq 0 ]; then
      skip "brew 패키지"
    else
      info "brew 패키지 설치: ${missing[*]}"
      brew install "${missing[@]}"
    fi
  fi
}

# ---------------------------------------------------------------- Neovim
install_neovim() {
  local dest="$LOCAL_OPT/nvim-$NVIM_VERSION"
  if [ -x "$dest/bin/nvim" ]; then
    skip "Neovim $NVIM_VERSION"
  else
    info "Neovim $NVIM_VERSION 설치"
    local asset="nvim-$PLATFORM-$ARCH.tar.gz"
    download "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/$asset" "$TMP_DIR/nvim.tar.gz"
    rm -rf "$dest" && mkdir -p "$dest"
    tar -xzf "$TMP_DIR/nvim.tar.gz" -C "$dest" --strip-components=1
    # macOS: 다운로드 파일의 격리(quarantine) 속성 제거
    [ "$PLATFORM" = macos ] && xattr -cr "$dest" 2>/dev/null || true
  fi
  ln -sfn "$dest/bin/nvim" "$LOCAL_BIN/nvim"
}

# ---------------------------------------------------------------- tree-sitter CLI (nvim-treesitter 파서 빌드용)
install_tree_sitter() {
  if [ -x "$LOCAL_BIN/tree-sitter" ] && "$LOCAL_BIN/tree-sitter" --version | grep -q "${TREE_SITTER_VERSION#v}"; then
    skip "tree-sitter CLI $TREE_SITTER_VERSION"
    return
  fi
  info "tree-sitter CLI $TREE_SITTER_VERSION 설치"
  local ts_arch=x64
  [ "$ARCH" = arm64 ] && ts_arch=arm64
  download "https://github.com/tree-sitter/tree-sitter/releases/download/$TREE_SITTER_VERSION/tree-sitter-$PLATFORM-$ts_arch.gz" "$TMP_DIR/tree-sitter.gz"
  gunzip -c "$TMP_DIR/tree-sitter.gz" >"$LOCAL_BIN/tree-sitter"
  chmod +x "$LOCAL_BIN/tree-sitter"
  [ "$PLATFORM" = macos ] && xattr -c "$LOCAL_BIN/tree-sitter" 2>/dev/null || true
}

# ---------------------------------------------------------------- Java (SDKMAN) + Maven + Gradle
install_java() {
  if [ ! -d "$HOME/.sdkman" ]; then
    info "SDKMAN 설치"
    download "https://get.sdkman.io" "$TMP_DIR/sdkman.sh"
    bash "$TMP_DIR/sdkman.sh"
  else
    skip "SDKMAN"
  fi
  sed -i.bak 's/sdkman_auto_answer=false/sdkman_auto_answer=true/' "$HOME/.sdkman/etc/config" && rm -f "$HOME/.sdkman/etc/config.bak"

  # SDKMAN 스크립트는 set -eu와 호환되지 않음 (아래에서 결과를 직접 확인)
  set +eu
  # shellcheck disable=SC1091
  source "$HOME/.sdkman/bin/sdkman-init.sh"

  local java_id
  java_id="$(sdk list java | grep -oE "${JAVA_MAJOR}[0-9.]*(\+[0-9.]+)?-tem" | sort -V | tail -1)"
  [ -n "$java_id" ] || die "SDKMAN에서 Java $JAVA_MAJOR (Temurin)을 찾지 못했습니다."
  if [ -d "$HOME/.sdkman/candidates/java/$java_id" ]; then
    skip "Java $java_id"
  else
    info "Java $java_id 설치"
    sdk install java "$java_id"
  fi
  sdk default java "$java_id" >/dev/null
  [ -d "$HOME/.sdkman/candidates/java/$java_id" ] || die "Java $java_id 설치 실패"

  for c in maven gradle; do
    if [ -e "$HOME/.sdkman/candidates/$c/current" ]; then skip "$c"; else
      info "$c 설치"
      sdk install "$c"
      [ -e "$HOME/.sdkman/candidates/$c/current" ] || die "$c 설치 실패"
    fi
  done
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  set -eu
}

# ---------------------------------------------------------------- uv / Claude Code
install_uv() {
  if [ -x "$LOCAL_BIN/uv" ]; then skip "uv"; else
    info "uv 설치"
    download "https://astral.sh/uv/install.sh" "$TMP_DIR/uv.sh"
    UV_NO_MODIFY_PATH=1 sh "$TMP_DIR/uv.sh"
  fi
}

install_claude() {
  if [ -x "$LOCAL_BIN/claude" ]; then skip "Claude Code"; else
    info "Claude Code 설치"
    download "https://claude.ai/install.sh" "$TMP_DIR/claude.sh"
    bash "$TMP_DIR/claude.sh"
  fi
}

# ---------------------------------------------------------------- PATH (~/.local/bin을 맨 앞에)
ensure_path() {
  local line='export PATH="$HOME/.local/bin:$PATH" # nvim-config'
  local rcs=("$HOME/.bashrc")
  [ "$PLATFORM" = macos ] && rcs+=("$HOME/.zshrc")
  for rc in "${rcs[@]}"; do
    touch "$rc"
    if grep -q '# nvim-config' "$rc"; then skip "PATH 설정 ($rc)" "이미 있음"; else
      info "PATH 설정 추가: $rc"
      printf '\n%s\n' "$line" >>"$rc"
    fi
  done
}

# ---------------------------------------------------------------- 설정 저장소
setup_config() {
  if [ -d "$CONFIG_DIR/.git" ] && git -C "$CONFIG_DIR" remote get-url origin 2>/dev/null | grep -q "$(basename "$REPO_URL" .git)"; then
    if [ -z "$(git -C "$CONFIG_DIR" status --porcelain)" ]; then
      info "설정 저장소 업데이트 (git pull)"
      git -C "$CONFIG_DIR" pull --ff-only
    else
      skip "설정 저장소 업데이트" "수정 중인 파일이 있어 git pull 생략"
    fi
    return
  fi
  if [ -e "$CONFIG_DIR" ]; then
    local backup
    backup="$CONFIG_DIR.backup-$(date +%Y%m%d-%H%M%S)"
    info "기존 설정을 백업: $backup"
    mv "$CONFIG_DIR" "$backup"
  fi
  info "설정 저장소 clone: $REPO_URL"
  mkdir -p "$(dirname "$CONFIG_DIR")"
  git clone "$REPO_URL" "$CONFIG_DIR"
}

# ---------------------------------------------------------------- 플러그인 / 파서 / Mason 도구
sync_nvim() {
  # kickstart는 처음 실행할 때 lazy.nvim 최신판을 clone하므로, lock에 적힌 버전으로 미리 받아 둔다
  local lazy_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim"
  local lazy_commit
  lazy_commit="$(grep -oE '"lazy.nvim": \{[^}]*"commit": "[0-9a-f]+"' "$CONFIG_DIR/lazy-lock.json" | grep -oE '[0-9a-f]{40}')"
  if [ ! -d "$lazy_dir" ] && [ -n "$lazy_commit" ]; then
    info "lazy.nvim 설치 (${lazy_commit:0:7})"
    git clone --filter=blob:none https://github.com/folke/lazy.nvim.git "$lazy_dir"
    git -C "$lazy_dir" checkout -q "$lazy_commit"
  fi

  info "플러그인 설치 (lazy-lock.json 버전 기준)"
  nvim --headless "+Lazy! restore" +qa

  info "treesitter 파서 설치"
  nvim --headless -c "lua require('nvim-treesitter').install({ $TS_PARSERS }):wait(600000)" +qa

  info "Mason 도구 설치: $MASON_PACKAGES"
  # dap.lua(mason-nvim-dap)가 시작할 때 codelldb 설치를 시작하는데, 앞 단계에서 nvim이 바로 종료되며
  # 중단된 설치가 깨진 링크를 남길 수 있다 → 깨진 링크 정리 후, 진행 중인 설치가 끝나길 기다렸다가 나머지 설치
  local mason_bin="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin"
  [ -d "$mason_bin" ] && find "$mason_bin" -xtype l -delete
  nvim --headless -c "lua
    local registry = require 'mason-registry'
    registry.refresh()
    local names = vim.split('$MASON_PACKAGES', ' ', { trimempty = true })
    vim.wait(600000, function()
      for _, name in ipairs(names) do
        local ok, pkg = pcall(registry.get_package, name)
        if ok and pkg:is_installing() then return false end
      end
      return true
    end, 1000)
    local missing = vim.tbl_filter(function(name) return not registry.is_installed(name) end, names)
    if #missing > 0 then vim.cmd('MasonInstall ' .. table.concat(missing, ' ')) end
  " +qa
}

install_system_packages
install_neovim
install_tree_sitter
install_java
install_uv
install_claude
ensure_path
setup_config
sync_nvim

cat <<EOF

$(printf '\033[1;32m설치 완료!\033[0m')

다음 단계:
  1. 새 터미널을 열거나:  source ~/.bashrc$([ "$PLATFORM" = macos ] && echo "  (zsh: source ~/.zshrc)")
  2. Claude Code 로그인:  claude
  3. (Copilot 사용 시) nvim에서  :Copilot setup
EOF
