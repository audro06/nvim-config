# nvim-config 작업 안내

이 저장소를 고치는 사람과 AI 세션을 위한 문서다. 사용법은 `README.md`에 있고, 여기에는 **구조, 규칙, 검증 방법, 겪었던 함정, 다음에 할 만한 일**을 적는다.

## 한눈에 보기

- [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) fork 기반의 개인 Neovim 설정. 저장소는 `~/.config/nvim`에 clone되어 있다.
- 대상 환경: Ubuntu 24.04(WSL2 포함)와 macOS. **Neovim 0.12 이상 필수** (nvim-treesitter `main` 브랜치가 0.12를 요구).
- 원격: `origin` = `audro06/nvim-config` (기본 브랜치 `master`), `upstream` = `nvim-lua/kickstart.nvim`.
- 지원 기능: C++ / Java / Python / Rust (LSP, 디버깅, 테스트, F4 실행), 코테(competitest), Jupyter 노트북, Markdown 렌더링, Claude Code 창, Copilot.
- Nerd Font는 쓰지 않는다 (`vim.g.have_nerd_font = false`). 아이콘을 쓰는 플러그인은 일반 문자로 대체해야 한다.

## 구조

| 위치 | 역할 |
|---|---|
| `init.lua` | kickstart 본문. **가급적 건드리지 않는다.** 고친 곳: LSP `servers` 표(clangd, rust_analyzer), treesitter 파서 목록, autopairs·copilot 플러그인, blink `super-tab`, `jump.on_jump`, lazy `rocks` 끄기, 맨 끝의 `require 'custom.*'` |
| `lua/custom/settings.lua` | 개인 옵션, 진단 표시, Copilot 설정 |
| `lua/custom/snippets.lua` | LuaSnip 스니펫 (C++) |
| `lua/custom/plugins/*.lua` | 플러그인 spec. lazy.nvim이 자동으로 읽는다 (`{ import = 'custom.plugins' }`) |
| `lua/custom/mason.lua` | 언어 파일이 Mason 도구를 직접 설치할 때 쓰는 헬퍼 |
| `lua/custom/cxx.lua`, `lua/custom/rust.lua` | 컴파일러 선택(macOS는 brew `g++-NN`), Rust 실행 대상 판별 |
| `after/ftplugin/{cpp,rust}.lua` | 해당 언어 버퍼 전용 단축키 |
| `scripts/bootstrap.sh` | 새 컴퓨터 설치 스크립트 (여러 번 실행해도 안전) |
| `scripts/check.sh` | 설정 점검 스크립트 |
| `scripts/jupyter_wsl_viewer.py` | WSL에서 노트북 그래프를 Windows 뷰어로 여는 훅 |
| `lazy-lock.json` | 플러그인 버전 고정. **커밋한다** |
| `lua/kickstart/`, `doc/` | kickstart 원본. 쓰지 않지만 upstream merge를 위해 남겨 둠 |

### 단축키 배정

새 단축키는 겹치지 않게 아래 표를 따른다. 언어 전용 키는 **버퍼 전용**(`buffer = ...`)으로 만든다.

| 접두 | 용도 | 정의 위치 |
|---|---|---|
| `<leader>s` `<leader>t` `<leader>h` `<leader>q` `<leader>f` | kickstart (검색, 토글, git hunk, quickfix, 포맷) | `init.lua` |
| `<leader>a`, `<leader>1`–`4`, `<C-e>` | harpoon | `harpoon.lua` |
| `<leader>b`, `F9` `F10` `F11` | 디버깅 | `dap.lua` |
| `<leader>c` | Claude Code | `claudecode.lua` |
| `<leader>j` | Java | `java.lua` |
| `<leader>p` | Python | `python.lua` |
| `<leader>r` | Rust | `after/ftplugin/rust.lua` |
| `<leader>n`, `]]` `[[` | 노트북 | `jupyter.lua` |
| `<leader>tm` | Markdown 렌더링 토글 | `markdown.lua` |
| `F4` | 현재 파일 실행 (언어별 버퍼 전용) | `after/ftplugin/cpp.lua`, `java.lua`, `python.lua`, `after/ftplugin/rust.lua` |
| `F5`–`F8` | competitest | `competitest.lua` |
| `gl` | 커서 위치 진단 보기 | `settings.lua` |

## 작업 규칙

1. **기존 파일 형식을 따른다.** `lua/custom/plugins/`의 파일처럼 맨 위에 한글 주석으로 역할을 적고, 주석은 한글, 단축키 `desc`는 kickstart 방식(`'Java: [T]est ...'`).
2. **stylua로 포맷한다** (`.stylua.toml`). 실행 파일: `~/.local/share/nvim/mason/bin/stylua .`
3. **새 언어·기능은 새 파일로 추가한다.** `init.lua` 본문 수정은 최소로 (upstream merge 충돌 방지).
4. **플러그인 버전을 올리지 않는다.** 아래 "함정" 1번 참고.
5. 새 도구가 필요하면 **`scripts/bootstrap.sh`에도 반영**한다 (`MASON_PACKAGES`, `TS_PARSERS`, 설치 함수). 같은 목록이 Lua 쪽에도 있으니 둘 다 고친다.
6. `README.md`의 구성 표와 단축키 표를 함께 고친다.
7. 커밋 메시지는 영어로, 한 커밋에 한 가지 변경.

## 검증 방법

```bash
bash scripts/check.sh
```

포맷, 시작 오류, 언어별 파일 열기, 단축키, Markdown 렌더링, `lazy-lock.json` 변동 여부를 확인한다. 커밋 전에 반드시 통과시킨다. GitHub Actions(`.github/workflows/check.yml`)는 포맷과 셸 스크립트만 본다.

`check.sh`가 **보지 않는 것**은 화면 없는 nvim으로 직접 확인한다:

- LSP 연결: 파일을 열고 `vim.wait(...)`로 `vim.lsp.get_clients { bufnr = 0 }`를 기다린다. jdtls는 프로젝트를 불러오는 데 30초 이상 걸린다.
- 디버깅·테스트: `dap.listeners.after.event_terminated`로 세션 종료를 기다린다.
- 노트북: 커널 시작 → 셀 실행 → 저장 → `.ipynb` JSON에 출력이 들어갔는지 확인.
- 설치 스크립트: 빈 홈 폴더에서 돌린다.
  `env -i HOME=/tmp/bt-home USER=$USER TERM=dumb PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin NVIM_CONFIG_REPO=$HOME/.config/nvim bash scripts/bootstrap.sh` (10분쯤 걸림. 두 번 실행해서 두 번째에 모두 건너뛰는지도 본다)

실제 화면 모양(그래프 창, Markdown 렌더링 모습, Claude 창)은 화면 없는 nvim으로 확인할 수 없다. 사용자에게 확인을 부탁한다.

## 함정 (실제로 겪은 것)

1. **`:Lazy sync` / `:Lazy update` 금지.** 모든 플러그인이 최신으로 올라가서 `lazy-lock.json`이 통째로 바뀐다. 새 플러그인만 설치할 때는 `nvim --headless "+Lazy! install" +qa`, lock 기준으로 맞출 때는 `"+Lazy! restore"`. 작업 뒤 `git diff lazy-lock.json`에 새 플러그인 줄만 있는지 확인한다.
2. **화면 없는 nvim에서 `nvim_feedkeys`로 단축키를 누르면 일부가 조용히 실행되지 않는다.** 단축키의 Lua 콜백을 직접 부른다: `vim.fn.maparg('<leader>na', 'n', false, true).callback()`
3. **화면 없는 nvim에서는 오류가 `:messages`에 안 남는 경우가 있다** (lazy.nvim의 플러그인 로드 실패 등). `check.sh`처럼 `--cmd`로 `vim.notify`를 먼저 감싸서 기록한다.
4. **`nvim --headless ... +qa`는 진행 중인 Mason 설치를 중단시킨다.** 설치가 끝날 때까지 `vim.wait`로 기다린다 (`bootstrap.sh`의 `sync_nvim` 참고). `:MasonInstall`은 headless에서 stderr 출력을 오류로 취급하므로 `pkg:install()` API를 쓴다.
5. **lazy의 `build`는 처음 설치할 때 플러그인이 runtimepath에 올라오기 전에 실행된다.** `UpdateRemotePlugins`가 필요한 플러그인(molten)은 build 안에서 rtp에 직접 추가해야 등록된다 (`jupyter.lua`).
6. **Ubuntu에서는 venv의 `sitecustomize.py`가 동작하지 않는다** (시스템 Python의 것이 먼저 잡힘). 시작 시 실행할 코드는 `.pth` 파일로 넣는다 (`jupyter.lua`의 build).
7. **jupytext.nvim은 `metadata.kernelspec`이 없는 노트북에서 오류가 난다.** `jupyter.lua`에서 `get_ipynb_metadata`를 덮어써서 막고 있다. 플러그인을 올릴 때 이 부분이 여전히 필요한지 확인한다.
8. **노트북과 같은 이름의 `.py`가 같은 폴더에 있으면** jupytext가 그 `.py`를 노트북 내용으로 읽는다.
9. **mason-lspconfig가 jdtls를 자동으로 띄우면 안 된다.** Java는 nvim-jdtls가 직접 실행한다. jdtls를 `init.lua`의 `servers`에 넣지 않는다.
10. **macOS**: 기본 bash는 3.2(SDKMAN은 4 이상 필요), `find -xtype`·`sort -V` 없음, `g++`는 clang(`bits/stdc++.h` 없음), Homebrew가 PATH 뒤쪽에 붙음. `bootstrap.sh`와 `cxx.lua`가 처리하고 있으니 셸 스크립트를 고칠 때 GNU 전용 옵션을 쓰지 않는다.
11. **clangd는 일반 로그도 stderr로 내보낸다.** `--log=error`가 없으면 `~/.local/state/nvim/lsp.log`가 수백 MB로 커진다 (`cxx.lua`).
12. **Windows에서 WSL 명령을 실행할 때** (`wsl -d Ubuntu-24.04 -- bash -c '...'`) 따옴표와 `$`가 PowerShell에서 깨진다. 스크립트 파일로 저장해서 `bash 파일경로`로 실행한다. WSL의 비대화형 셸은 `~/.bashrc`를 읽지 않으므로 PATH(`~/.local/bin`, SDKMAN, `~/.cargo/bin`)를 직접 잡아야 한다.
13. sudo는 비밀번호가 필요하다. `bootstrap.sh`의 apt 단계만 sudo를 쓰고, 나머지는 모두 홈 폴더에 설치한다.

## 알려진 한계

- 노트북 그래프와 Markdown의 이미지·수식은 nvim 안에 표시되지 않는다. 그래프는 별도 이미지 뷰어 창으로 열린다. Windows Terminal이 이미지 표시를 지원하지 않기 때문이다.
- `:checkhealth`에 남는 경고 중 무시해도 되는 것: jupytext의 healthcheck 오류와 `vim.validate` deprecated(플러그인 쪽 문제), render-markdown의 icons 경고(아이콘을 꺼 둠), molten의 선택 모듈(plotly 등), 쓰지 않는 언어 provider(perl, ruby, node).
- 설치 스크립트의 macOS 분기는 맥북 한 대에서만 실행해 봤다. Intel Mac은 확인하지 못했다.
- kickstart upstream보다 60여 커밋 뒤처져 있다 (2026-11 기준).

## 다음에 할 만한 일

우선순위 순. 사용자가 요청하지 않은 것은 먼저 물어보고 진행한다.

1. **kickstart upstream merge.** `git fetch upstream && git merge upstream/master`. 충돌은 `init.lua`에만 날 것이다 (위 "구조" 표의 고친 곳 목록 참고). merge 뒤 `check.sh`와 언어별 LSP 연결을 다시 확인한다.
2. **브라우저 Markdown 미리보기** (이미지·수식·mermaid용). 후보: `brianhuster/live-preview.nvim` (외부 의존성 없음). WSL에서는 브라우저를 `explorer.exe`나 `wslview`로 열어야 한다.
3. **Nerd Font 도입.** 터미널 글꼴을 Nerd Font로 바꾸면 `init.lua`의 `have_nerd_font = true` 한 줄로 아이콘이 켜진다 (`markdown.lua`가 이 값을 본다).
4. **노트북 그래프를 nvim 안에 표시.** WezTerm이나 Kitty로 터미널을 바꾸면 molten의 `image_provider`(`image.nvim`)를 쓸 수 있다.
5. **테스트 실행을 neotest로 통합.** 지금은 언어마다 방식이 다르다 (Java는 jdtls, Python은 dap-python, Rust는 터미널).
6. **`check.sh` 확장.** LSP 연결 확인을 선택 옵션(`--lsp`)으로 추가.
7. **Neovim / 플러그인 버전 올리기.** `bootstrap.sh`의 `NVIM_VERSION`, `TREE_SITTER_VERSION`과 `lazy-lock.json`을 올리고 전체 검증. 한 번에 하나씩.
8. 다른 언어 추가 (Go, TypeScript 등). `python.lua`를 본보기로 삼는다.

## 변경 이력 요약

- 2026-10: WSL에서 초기 구성 (Java, Python, Claude Code 창, 설치 스크립트), Neovim 0.12.6, Java 26, macOS 지원, Jupyter 노트북
- 2026-11: Rust, Markdown 렌더링, 최종 검수 (개인 설정을 `init.lua`에서 분리, `check.sh`와 CI 추가, clangd 로그 줄이기)
