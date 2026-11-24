# nvim-config 작업 안내

이 저장소를 고치는 사람과 AI 세션을 위한 문서다. 사용법은 `README.md`에 있고, 여기에는 **구조, 규칙, 검증 방법, 겪었던 함정, 다음에 할 만한 일**을 적는다.

## 한눈에 보기

- [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) fork 기반의 개인 Neovim 설정. 저장소는 `~/.config/nvim`에 clone되어 있다.
- **플러그인 관리자는 lazy.nvim.** upstream은 `vim.pack`으로 옮겼지만 이 저장소는 따라가지 않는다 (함정 15번).
- 대상 환경: Ubuntu 24.04(WSL2 포함)와 macOS. **Neovim 0.12 이상 필수** (nvim-treesitter `main` 브랜치가 0.12를 요구).
- 원격: `origin` = `audro06/nvim-config` (기본 브랜치 `master`), `upstream` = `nvim-lua/kickstart.nvim`.
- 지원 기능: C++ / Java / Python / Rust (LSP, 디버깅, F4 실행), 테스트(neotest: Python / Java / Rust), 코테(competitest), Jupyter 노트북, Markdown 렌더링, Claude Code 창, Copilot.
- Nerd Font를 쓴다 (`vim.g.have_nerd_font = true`, 터미널 글꼴은 `D2CodingLigature Nerd Font Mono`). 아이콘을 쓰는 플러그인을 추가할 때는 이 값이 `false`여도 깨지지 않게 일반 문자 대체를 둔다 (`markdown.lua`, `neotest.lua` 참고).

## 구조

| 위치 | 역할 |
|---|---|
| `init.lua` | kickstart 본문을 lazy.nvim spec 형태로 유지한 것. **가급적 건드리지 않는다.** SECTION 1~2(옵션, 단축키)는 upstream과 같고, SECTION 3 이후가 lazy spec. upstream과 다른 곳: `have_nerd_font = true`, LSP `servers` 표(clangd, rust_analyzer), treesitter 파서 목록, autopairs·copilot 플러그인, blink `super-tab`, conform `enabled_filetypes`, lazy `rocks` 끄기, 맨 끝의 `require 'custom.*'` |
| `lua/custom/settings.lua` | 개인 옵션, 진단 표시, Copilot 설정 |
| `lua/custom/snippets.lua` | LuaSnip 스니펫 (C++) |
| `lua/custom/plugins/*.lua` | 플러그인 spec. lazy.nvim이 자동으로 읽는다 (`{ import = 'custom.plugins' }`) |
| `lua/custom/mason.lua` | 언어 파일이 Mason 도구를 직접 설치할 때 쓰는 헬퍼 |
| `lua/custom/cxx.lua`, `lua/custom/rust.lua` | 컴파일러 선택(macOS는 brew `g++-NN`), Rust 실행 대상 판별 |
| `lua/custom/neotest_rust.lua` | neotest용 Rust 어댑터 (`rust.lua`의 대상 판별을 재사용) |
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
| `<leader>s` `<leader>t` `<leader>h` `<leader>q` `<leader>f`, `]c` `[c` | kickstart (검색, 토글, git hunk, quickfix, 포맷) | `init.lua` |
| `<leader>a`, `<leader>1`–`4`, `<C-e>` | harpoon | `harpoon.lua` |
| `<leader>b`, `F9` `F10` `F11` | 디버깅 | `dap.lua` |
| `<leader>c` | Claude Code | `claudecode.lua` |
| `<leader>j` | Java | `java.lua` |
| `<leader>p` | Python | `python.lua` |
| `<leader>r` | Rust | `after/ftplugin/rust.lua` |
| `<leader>n`, `]]` `[[` | 노트북 | `jupyter.lua` |
| `<leader>x` | 테스트 (모든 언어 공통, 전역 단축키) | `neotest.lua` |
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
   새 언어를 추가하면 저장 시 포맷을 켤지 정해서 `init.lua`의 conform `enabled_filetypes`에도 넣는다 (목록에 없는 언어는 저장할 때 포맷하지 않는다).
6. `README.md`의 구성 표와 단축키 표를 함께 고친다.
7. 커밋 메시지는 영어로, 한 커밋에 한 가지 변경.

## 검증 방법

```bash
bash scripts/check.sh
```

포맷, 시작 오류, 언어별 파일 열기, 단축키, Markdown 렌더링, `lazy-lock.json` 변동 여부를 확인한다. 커밋 전에 반드시 통과시킨다. GitHub Actions(`.github/workflows/check.yml`)는 포맷과 셸 스크립트만 본다.

`check.sh`가 **보지 않는 것**은 화면 없는 nvim으로 직접 확인한다:

- LSP 연결: 파일을 열고 `vim.wait(...)`로 `vim.lsp.get_clients { bufnr = 0 }`를 기다린다. jdtls는 프로젝트를 불러오는 데 30초 이상 걸린다.
- 디버깅: `dap.listeners.after.event_terminated`로 세션 종료를 기다린다.
- 테스트(neotest): `require('lazy').load { plugins = { 'neotest' } }`로 먼저 불러온 뒤 단축키 콜백을 부르고, `neotest.state.status_counts(adapter_id)`의 `running`이 0이 될 때까지 기다린다. Python은 `.venv`에 pytest, Java는 jdtls가 프로젝트를 다 불러온 뒤(30초 이상)여야 한다.
- 노트북 그래프(image.nvim): 터미널 크기를 물어보기 때문에 pty가 필요하다. `script -qfc "stty rows 40 cols 120; NVIM_IMAGE_BACKEND=sixel nvim --headless ..." log`로 돌리고, `require('image').get_images()`와 log 안의 Sixel 시작 문자(`ESC P`)를 확인한다.
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
13. **`gh` 명령은 `-R audro06/nvim-config`를 붙인다.** `upstream` 원격이 있어서 `gh`가 kickstart 원본 저장소를 기본으로 잡을 수 있다. PR이나 이슈가 kickstart 쪽에 만들어지지 않게 주의한다.
14. sudo는 비밀번호가 필요하다. `bootstrap.sh`의 apt 단계만 sudo를 쓰고, 나머지는 모두 홈 폴더에 설치한다.
15. **kickstart upstream은 lazy.nvim을 버리고 `vim.pack`으로 옮겼다 (2026-04).** `git merge upstream/master`를 하면 `init.lua`가 통째로 충돌한다. 푸는 방법:
    - `init.lua`: SECTION 1~2는 upstream 것을 그대로 받고, SECTION 4~9는 upstream의 `vim.pack.add` + `setup()` 내용을 우리 lazy spec(`opts` / `config`) 안으로 손으로 옮긴다. `git diff <이전 upstream>..upstream/master -- init.lua`로 바뀐 부분만 보면 된다.
    - `lua/custom/plugins/init.lua`는 **우리 것(`return {}`)을 유지**한다. upstream 것은 같은 폴더의 파일을 `require`하는 로더라서 lazy의 `{ import = 'custom.plugins' }`와 같이 쓸 수 없다.
    - `lua/kickstart/plugins/*.lua`는 upstream 것을 받되, 이제 lazy spec이 아니라서 `init.lua`에서 불러올 수 없다 (참고용).
    - `README.md`, `.gitignore`, `.github/`는 우리 것을 유지한다.
16. **neotest는 테스트를 pty로 실행한다.** 출력에 색상 코드(`ESC[32m` 등)가 섞이므로 결과를 읽기 전에 걷어내야 한다. 어댑터의 `results()`는 fast event에서 불리므로 `vim.fn`을 쓰기 전에 `nio.scheduler()`를 부른다 (`neotest_rust.lua`).
17. **neotest-java는 빌드 파일이 없어도 `.git`만 있으면 그 폴더를 자기 프로젝트로 잡는다.** 그대로 두면 Rust/Python 프로젝트의 `<leader>xa`를 가로채서 오류가 난다. `neotest.lua`에서 `root`를 감싸 Maven/Gradle 프로젝트로 제한하고 있다. 플러그인을 올릴 때 여전히 필요한지 확인한다.
18. **WSL에서는 터미널의 픽셀 크기를 알 수 없다** (`ioctl`이 0을 돌려줌). image.nvim은 글자 한 칸을 8x16으로 가정하는데 Windows Terminal의 Sixel은 한 칸을 10x20으로 취급하므로 `jupyter.lua`에서 보정한다. image.nvim은 `image/utils/term`, molten은 `image.utils.term`으로 같은 파일을 따로 불러서 둘 다 고쳐야 한다.
19. **Rust 테스트를 디버그(`<leader>xd`)로 실행하면 테스트 출력이 neotest로 넘어오지 않는다** (codelldb). 그래서 `neotest_rust.lua`는 출력이 비어 있으면 종료 코드로 성공/실패를 판정한다.
20. **LuaSnip은 기본값으로 끝내지 않은 스니펫을 계속 살려 둔다.** blink `super-tab`의 Tab은 스니펫이 살아 있으면 들여쓰기 대신 그 위치로 점프하므로, 다른 줄에서 Tab을 누르면 커서가 예전 스니펫으로 날아간다. `snippets.lua`의 `region_check_events`로 막고 있다. 화면 없는 nvim에서 확인할 때는 `ls.lsp_expand` 뒤에 `nvim_feedkeys('', 'x', false)`로 쌓인 키를 처리해야 한다 (안 하면 `jump_active`가 켜진 채라 검사가 건너뛰어진다).

## 알려진 한계

- 노트북 그래프는 Windows Terminal 1.22 이상·WezTerm(Sixel), Kitty·Ghostty에서만 nvim 안에 표시된다. 그 밖의 터미널, tmux 안, ImageMagick이 없는 컴퓨터에서는 별도 이미지 뷰어 창으로 열린다. Sixel은 화면을 다시 그릴 때 깜빡일 수 있다.
- Markdown의 이미지·수식은 nvim 안에 표시되지 않는다 (image.nvim의 markdown 연동은 꺼 둠).
- 테스트(neotest): C++은 어댑터가 없다 (코테는 competitest). Java는 Maven/Gradle 프로젝트만 되고 단일 파일은 안 된다.
- `:checkhealth`에 남는 경고 중 무시해도 되는 것: jupytext의 healthcheck 오류와 `vim.validate` deprecated(플러그인 쪽 문제), molten의 선택 모듈(plotly 등), image.nvim의 kitty/ueberzug 항목(Sixel을 쓰는 경우), 쓰지 않는 언어 provider(perl, ruby, node).
- 설치 스크립트의 macOS 분기는 맥북 한 대에서만 실행해 봤다. Intel Mac은 확인하지 못했다.
- kickstart upstream은 `8e35dbe`(2026-11)까지 merge했다. 플러그인 관리자가 달라서 앞으로도 merge는 손이 간다 (함정 15번).

## 다음에 할 만한 일

우선순위 순. 사용자가 요청하지 않은 것은 먼저 물어보고 진행한다.

1. **브라우저 Markdown 미리보기** (이미지·수식·mermaid용). 후보: `brianhuster/live-preview.nvim` (외부 의존성 없음). WSL에서는 브라우저를 `explorer.exe`나 `wslview`로 열어야 한다.
2. **Markdown 안의 이미지를 nvim 안에 표시.** `jupyter.lua`의 `setup_image`에서 image.nvim의 `integrations.markdown`을 켜면 된다. 원격 이미지를 자동으로 내려받는 옵션(`download_remote_images`)은 끄는 쪽을 권한다.
3. **`check.sh` 확장.** LSP 연결과 테스트 실행 확인을 선택 옵션(`--lsp`, `--test`)으로 추가.
4. **Neovim / 플러그인 버전 올리기.** `bootstrap.sh`의 `NVIM_VERSION`, `TREE_SITTER_VERSION`과 `lazy-lock.json`을 올리고 전체 검증. 한 번에 하나씩.
5. **`vim.pack`으로 전환할지 검토.** upstream을 계속 따라가려면 전환이 낫지만, `lua/custom/plugins/*.lua` 전부와 `bootstrap.sh`·`check.sh`·lock 파일을 다시 써야 하고 filetype별 지연 로드가 없어진다.
6. 다른 언어 추가 (Go, TypeScript 등). `python.lua`를 본보기로 삼고, neotest 어댑터도 `neotest.lua`에 같이 넣는다.
7. C++ 테스트 어댑터 (GoogleTest / Catch2를 쓰게 되면 `neotest-gtest` 등).

## 변경 이력 요약

- 2026-10: WSL에서 초기 구성 (Java, Python, Claude Code 창, 설치 스크립트), Neovim 0.12.6, Java 26, macOS 지원, Jupyter 노트북
- 2026-11: Rust, Markdown 렌더링, 최종 검수 (개인 설정을 `init.lua`에서 분리, `check.sh`와 CI 추가, clangd 로그 줄이기)
- 2026-11: kickstart upstream merge (lazy.nvim 유지), Nerd Font, 노트북 그래프를 nvim 안에 표시 (image.nvim), 테스트를 neotest로 통합 (`<leader>x`)
