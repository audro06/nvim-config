# nvim-config

[kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) 기반 개인 Neovim 설정.
C++ / Java / Python / Rust 개발과 코테, Jupyter 노트북(.ipynb), Markdown 렌더링, 오른쪽 분할창의 Claude Code 채팅을 지원한다.

## 설치

Ubuntu(WSL 포함)와 macOS를 지원한다.

```bash
git clone https://github.com/audro06/nvim-config.git /tmp/nvim-config
bash /tmp/nvim-config/scripts/bootstrap.sh
```

스크립트가 하는 일 (이미 설치된 항목은 건너뜀):

| 항목 | 버전 / 방식 |
|---|---|
| 시스템 패키지 | Ubuntu: `apt` (sudo 필요) / macOS: `brew` |
| Neovim | v0.12.6 → `~/.local/opt`, `~/.local/bin/nvim` |
| tree-sitter CLI | v0.26.7 → `~/.local/bin` |
| Java | SDKMAN, Temurin 26 (기본), Maven, Gradle |
| Python | uv |
| Rust | rustup (stable) + rust-src, clippy, rustfmt |
| Claude Code | 네이티브 설치 → `~/.local/bin/claude` |
| 이 설정 | `~/.config/nvim`에 clone (기존 설정은 `nvim.backup-<날짜>`로 백업) |
| 플러그인 | `lazy-lock.json`에 고정된 버전으로 설치 |
| Jupyter | molten용 Python venv (`~/.local/share/nvim/jupyter-venv`), jupytext CLI |
| treesitter 파서, Mason 도구 | jdtls, pyright, ruff, debugpy, clangd, rust-analyzer, codelldb 등 |

설치 후:

1. 새 터미널 열기 (또는 `source ~/.bashrc`)
2. `claude` 실행해서 로그인
3. Copilot을 쓴다면 nvim에서 `:Copilot setup`

`--skip-system`을 붙이면 sudo가 필요한 시스템 패키지 단계를 건너뛴다.
macOS에서는 Homebrew와 Xcode Command Line Tools(`xcode-select --install`)가 먼저 필요하다.

## 구성

| 파일 | 내용 |
|---|---|
| `init.lua` | kickstart 기본 설정 + 개인 설정 (C++ F4 실행, 스니펫, Copilot) |
| `lua/custom/plugins/java.lua` | nvim-jdtls, Java 디버깅 / JUnit 테스트 |
| `lua/custom/plugins/python.lua` | pyright + ruff, 저장 시 포맷, debugpy / pytest |
| `lua/custom/plugins/jupyter.lua` | .ipynb 편집(jupytext.nvim) + 셀 실행(molten.nvim) |
| `lua/custom/plugins/markdown.lua` | .md 파일을 nvim 안에서 렌더링 (render-markdown.nvim) |
| `lua/custom/plugins/claudecode.lua` | Claude Code 오른쪽 분할창 (claudecode.nvim) |
| `lua/custom/plugins/dap.lua` | 디버거 공통 (nvim-dap, C++/Rust codelldb) |
| `after/ftplugin/rust.lua` | Rust 단축키 (F4 실행, F9 디버그, `<leader>r` 테스트/cargo) |
| `lua/custom/rust.lua` | Rust 실행 대상 판별, 디버그 빌드 |
| `lua/custom/plugins/competitest.lua` | 코테 테스트케이스 실행 (C++ / Java / Python / Rust) |
| `lua/custom/plugins/harpoon.lua` | 파일 빠른 이동 |
| `lua/custom/mason.lua` | 언어별 파일에서 Mason 도구를 설치하는 헬퍼 |
| `scripts/bootstrap.sh` | 새 컴퓨터 설치 스크립트 |
| `scripts/jupyter_wsl_viewer.py` | WSL에서 노트북 그래프를 Windows 이미지 뷰어로 여는 훅 |

Java는 SDKMAN에 설치된 JDK를 모두 jdtls 런타임으로 등록하고, `sdk default`로 지정한 버전을 기본으로 쓴다.
Maven / Gradle 프로젝트는 `pom.xml` / `build.gradle`에 지정한 버전으로 컴파일한다.

Python은 프로젝트 루트의 `.venv`(uv로 만든 것 포함)를 자동으로 인식한다.

### Rust

rust-analyzer(Mason)가 저장할 때마다 clippy로 검사하고 rustfmt로 포맷한다.
F4 / F9는 현재 파일 위치를 보고 무엇을 실행할지 정한다.

| 현재 파일 | F4 (실행) | F9 (디버그) |
|---|---|---|
| `Cargo.toml` 없는 단일 파일 (코테) | `rustc --edition 2021 -O` 후 실행 | `-g`로 컴파일 후 디버그 |
| `examples/foo.rs` | `cargo run --example foo` | 그 example 디버그 |
| `src/main.rs`, `src/bin/foo.rs` | `cargo run` / `cargo run --bin foo` | 그 바이너리 디버그 |
| `tests/foo.rs` | `cargo test --test foo` | 그 테스트 바이너리 디버그 |
| 그 밖의 `src/` 파일 (main 없음) | 이 파일의 테스트만: `cargo test -- <모듈 경로>` | 이 파일의 테스트 디버그 |

표준 라이브러리 자동완성이 안 되면 `rustup component add rust-src`.

### Jupyter 노트북

- `.ipynb`를 열면 `# %%`로 셀이 구분된 Python으로 보이고, 저장하면 `.ipynb`로 돌아간다. 셀 출력(그래프 포함)도 함께 저장된다.
- `<leader>ni`로 커널 시작. 프로젝트에 `.venv`가 있으면 그 Python을 커널로 등록해서 쓰고(ipykernel이 없으면 설치 여부를 물어봄), 없으면 기본 `python3` 커널(패키지 없음)을 쓴다.
  numpy 등이 필요하면 프로젝트를 만들어 쓴다: `uv init && uv add numpy matplotlib`
- 그래프는 nvim 안이 아니라 기본 이미지 뷰어 창으로 열린다 (WSL은 Windows 뷰어).
- 주의: 노트북과 같은 이름의 `.py` 파일(`hw.ipynb` ↔ `hw.py`)이 같은 폴더에 있으면 jupytext가 그 `.py`를 노트북 내용으로 읽는다.

## 단축키

`<leader>`는 스페이스.

| 키 | 동작 |
|---|---|
| `<leader>cc` | Claude 창 열기/닫기 |
| `<leader>cs` | (비주얼 모드) 선택 영역을 Claude에 보내기 |
| `<leader>cb` | 현재 파일을 Claude 대화에 추가 |
| `<leader>ca` / `<leader>cd` | Claude 수정 제안 수락 / 거절 |
| `<leader>jt` / `<leader>jT` | Java 테스트: 메서드 / 클래스 |
| `<leader>jo` | Java import 정리 |
| `<leader>jv` `<leader>jc` `<leader>jm` | Java 변수 / 상수 / 메서드 추출 |
| `<leader>pt` / `<leader>pT` | Python 테스트 디버그: 메서드 / 클래스 |
| `<leader>tm` | (Markdown) 렌더링 켜기 / 끄기 |
| `<leader>ni` | 노트북 커널 시작 |
| `<leader>nc` / `<leader>nn` | 현재 셀 실행 / 실행 후 다음 셀로 |
| `<leader>na` | 모든 셀 실행 |
| `<leader>nl` / `<leader>nv` | 현재 줄 / (비주얼 모드) 선택 영역 실행 |
| `<leader>no` / `<leader>nh` / `<leader>nd` | 출력 창 열기 / 출력 숨기기 / 셀 출력 지우기 |
| `<leader>np` | 그래프 다시 열기 |
| `<leader>nx` / `<leader>nR` | 실행 중단 / 커널 재시작 |
| `]]` / `[[` | (노트북) 다음 / 이전 셀 |
| `F4` | 현재 파일 컴파일 + 실행 (C++ / Java / Python / Rust) |
| `F5`–`F8` | competitest: 실행 / 테스트케이스 추가 / 수정 / 받기 |
| `F9` `F10` `F11` | 디버그: 시작·계속 / step over / step into (Rust는 F9가 빌드까지) |
| `<leader>b` | 브레이크포인트 |
| `<leader>rt` / `<leader>rd` | Rust: 커서가 있는 테스트 실행 / 디버그 |
| `<leader>rf` / `<leader>ra` | Rust: 이 파일의 테스트 / 전체 `cargo test` |
| `<leader>rr` `<leader>rb` `<leader>rc` | Rust: `cargo run` / `build` / `clippy` |
| `<leader>a`, `<C-e>`, `<leader>1`–`4` | harpoon |

## kickstart 업데이트 받기

```bash
cd ~/.config/nvim
git remote add upstream https://github.com/nvim-lua/kickstart.nvim.git  # 처음 한 번
git fetch upstream
git merge upstream/master
```
