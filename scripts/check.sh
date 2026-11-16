#!/usr/bin/env bash
# 설정 점검 스크립트: 설정을 고친 뒤 커밋하기 전에 실행한다.
#
#   1. Lua 포맷 (stylua --check), bootstrap.sh 문법
#   2. nvim이 오류 없이 시작하는지
#   3. 언어별 파일(C++/Java/Python/Rust/Markdown/노트북)을 열었을 때 오류가 없고 단축키가 붙는지
#   4. 점검 중에 lazy-lock.json이 바뀌지 않았는지 (플러그인 버전 고정 확인)
#
#   사용법:  bash scripts/check.sh
#   화면 없는 nvim(--headless)으로 돌리므로 LSP 연결·디버깅·실제 화면 모양까지는 확인하지 않는다.
set -uo pipefail

CONFIG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$CONFIG_DIR" || exit 1
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  set +u
  # shellcheck disable=SC1091
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  set -u
fi

fail=0
ok() { printf '\033[1;32m  ok\033[0m  %s\n' "$*"; }
bad() {
  printf '\033[1;31mFAIL\033[0m  %s\n' "$*"
  fail=1
}

# ---------------------------------------------------------------- 1. 정적 검사
stylua="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/mason/bin/stylua"
if [ -x "$stylua" ]; then
  if "$stylua" --check . >/dev/null 2>&1; then ok "stylua"; else bad "stylua --check (고치기: $stylua .)"; fi
else
  bad "stylua 없음 (Mason으로 설치)"
fi
if bash -n scripts/bootstrap.sh; then ok "bootstrap.sh 문법"; else bad "bootstrap.sh 문법"; fi

lock_before="$(git hash-object lazy-lock.json)"

# ---------------------------------------------------------------- 2~3. nvim 실행 검사
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/files"
printf '#include <iostream>\nint main() { std::cout << 1; }\n' >"$tmp/files/a.cpp"
printf 'public class Main {\n    public static void main(String[] args) {}\n}\n' >"$tmp/files/Main.java"
printf 'print(1)\n' >"$tmp/files/a.py"
printf 'fn main() {}\n' >"$tmp/files/a.rs"
printf '# 제목\n\n- [ ] 할 일\n' >"$tmp/files/a.md"
printf 'local x = 1\n' >"$tmp/files/a.lua"
cat >"$tmp/files/a.ipynb" <<'EOF'
{"cells":[{"cell_type":"code","execution_count":null,"metadata":{},"outputs":[],"source":["print(1)"]}],"metadata":{},"nbformat":4,"nbformat_minor":5}
EOF

cat >"$tmp/check.lua" <<'EOF'
local dir = vim.env.CHECK_DIR
local results = {}
local function report(pass, name, detail) table.insert(results, (pass and 'OK   ' or 'FAIL ') .. name .. (detail and (' — ' .. detail) or '')) end
local function errors()
  -- 오류 알림(vim.notify, lazy.nvim의 플러그인 로드 실패 등) + :messages의 오류 줄
  local found = _G.check_notes or {}
  _G.check_notes = {}
  for line in vim.api.nvim_exec2('messages', { output = true }).output:gmatch '[^\n]+' do
    if line:find 'E%d+:' or line:lower():find 'error' or line:find 'stack traceback' then table.insert(found, line) end
  end
  vim.cmd 'messages clear'
  return found
end
local function has_buf_map(lhs) return vim.fn.maparg(lhs, 'n', false, true).buffer == 1 end
local function has_map(lhs) return vim.fn.maparg(lhs, 'n') ~= '' end

vim.wait(1500)
local e = errors()
report(#e == 0, '시작', e[1])

-- { 파일, 기대하는 filetype, 버퍼 전용 단축키 }
local cases = {
  { 'a.cpp', 'cpp', { '<F4>' } },
  { 'Main.java', 'java', { '<F4>' } },
  { 'a.py', 'python', { '<F4>', '<leader>pt' } },
  { 'a.rs', 'rust', { '<F4>', '<F9>', '<leader>rt' } },
  { 'a.md', 'markdown', {} },
  { 'a.ipynb', 'python', { ']]' } },
}
for _, case in ipairs(cases) do
  local file, ft, maps = case[1], case[2], case[3]
  vim.cmd('edit ' .. dir .. '/' .. file)
  vim.wait(1500)
  local problems = errors()
  if vim.bo.filetype ~= ft then table.insert(problems, 'filetype=' .. vim.bo.filetype) end
  for _, lhs in ipairs(maps) do
    if not has_buf_map(lhs) then table.insert(problems, lhs .. ' 단축키 없음') end
  end
  report(#problems == 0, file, problems[1])
end

-- Markdown 렌더링이 실제로 그려지는지
vim.cmd('edit ' .. dir .. '/a.md')
vim.fn.cursor(vim.fn.line '$', 1)
vim.wait(800)
local ns = vim.api.nvim_get_namespaces()['render-markdown.nvim']
report(ns ~= nil and #vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {}) > 0, 'Markdown 렌더링')

-- 전역 단축키 / 명령
vim.cmd('edit ' .. dir .. '/a.lua')
vim.wait(300)
report(not has_map '<F4>', 'F4는 언어 버퍼 전용 (lua 파일에는 없어야 함)')
for _, lhs in ipairs { '<leader>cc', '<leader>ni', '<leader>na', '<leader>a', '<leader>b', '<F9>', 'gl' } do
  report(has_map(lhs), lhs .. ' 단축키')
end
report(vim.fn.exists ':MoltenInit' == 2, ':MoltenInit (안 되면 :Lazy build molten-nvim)')
report(vim.fn.exists ':ClaudeCode' == 2 or pcall(vim.cmd, 'Lazy load claudecode.nvim'), ':ClaudeCode')

io.write('\n' .. table.concat(results, '\n') .. '\n')
vim.cmd 'qa!'
EOF

# init.lua보다 먼저 실행: 오류 수준 알림을 기록해 둔다 (headless에서는 :messages에 안 남는 경우가 있음)
cat >"$tmp/pre.lua" <<'EOF'
_G.check_notes = {}
local notify = vim.notify
vim.notify = function(msg, level, ...)
  if level and level >= vim.log.levels.ERROR then table.insert(_G.check_notes, (tostring(msg):gsub('\n', ' '))) end
  return notify(msg, level, ...)
end
EOF

if out="$(CHECK_DIR="$tmp/files" timeout 120 nvim --headless --cmd "luafile $tmp/pre.lua" -c "luafile $tmp/check.lua" 2>&1)"; then
  while IFS= read -r line; do
    case "$line" in
      "OK   "*) ok "${line#OK   }" ;;
      "FAIL "*) bad "${line#FAIL }" ;;
    esac
  done <<<"$out"
  grep -q '^OK   ' <<<"$out" || bad "nvim 점검 결과가 없음: $(tail -3 <<<"$out")"
else
  bad "nvim 점검이 끝나지 않음 (timeout 또는 오류): $(tail -3 <<<"$out")"
fi

# ---------------------------------------------------------------- 4. 플러그인 버전 고정
if [ "$(git hash-object lazy-lock.json)" = "$lock_before" ]; then ok "lazy-lock.json 변동 없음"; else bad "점검 중 lazy-lock.json이 바뀜 (git diff lazy-lock.json)"; fi

echo
if [ "$fail" = 0 ]; then
  printf '\033[1;32m모든 점검 통과\033[0m\n'
else
  printf '\033[1;31m실패한 점검이 있습니다\033[0m\n'
fi
exit "$fail"
