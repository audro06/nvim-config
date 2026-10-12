# nvim-config

[kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim) 기반 개인 Neovim 설정.
C++ / Java / Python 개발과 코테, 오른쪽 분할창의 Claude Code 채팅을 지원한다.

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
| Claude Code | 네이티브 설치 → `~/.local/bin/claude` |
| 이 설정 | `~/.config/nvim`에 clone (기존 설정은 `nvim.backup-<날짜>`로 백업) |
| 플러그인 | `lazy-lock.json`에 고정된 버전으로 설치 |
| treesitter 파서, Mason 도구 | jdtls, pyright, ruff, debugpy, clangd, codelldb 등 |

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
| `lua/custom/plugins/claudecode.lua` | Claude Code 오른쪽 분할창 (claudecode.nvim) |
| `lua/custom/plugins/dap.lua` | 디버거 공통 (nvim-dap, C++ codelldb) |
| `lua/custom/plugins/competitest.lua` | 코테 테스트케이스 실행 (C++ / Java / Python) |
| `lua/custom/plugins/harpoon.lua` | 파일 빠른 이동 |
| `lua/custom/mason.lua` | 언어별 파일에서 Mason 도구를 설치하는 헬퍼 |
| `scripts/bootstrap.sh` | 새 컴퓨터 설치 스크립트 |

Java는 SDKMAN에 설치된 JDK를 모두 jdtls 런타임으로 등록하고, `sdk default`로 지정한 버전을 기본으로 쓴다.
Maven / Gradle 프로젝트는 `pom.xml` / `build.gradle`에 지정한 버전으로 컴파일한다.

Python은 프로젝트 루트의 `.venv`(uv로 만든 것 포함)를 자동으로 인식한다.

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
| `F4` | 현재 파일 컴파일 + 실행 (C++ / Java / Python) |
| `F5`–`F8` | competitest: 실행 / 테스트케이스 추가 / 수정 / 받기 |
| `F9` `F10` `F11` | 디버그: 시작·계속 / step over / step into |
| `<leader>b` | 브레이크포인트 |
| `<leader>a`, `<C-e>`, `<leader>1`–`4` | harpoon |

## kickstart 업데이트 받기

```bash
cd ~/.config/nvim
git remote add upstream https://github.com/nvim-lua/kickstart.nvim.git  # 처음 한 번
git fetch upstream
git merge upstream/master
```
