-- Rust 실행 / 테스트 / 디버그 공용 헬퍼 (after/ftplugin/rust.lua, dap.lua에서 사용)
--
-- 현재 파일이 어떤 "실행 대상"인지 판별해서 알맞은 명령을 만든다.
--   Cargo.toml 없음            → 단일 파일: rustc로 컴파일 후 실행 (코테용, C++ F4와 같은 방식)
--   examples/foo.rs            → cargo run --example foo
--   src/main.rs                → cargo run
--   src/bin/foo.rs             → cargo run --bin foo
--   tests/foo.rs               → cargo test --test foo
--   그 밖의 파일 (lib, 모듈)   → main이 없으니 이 파일의 테스트만 실행: cargo test <모듈 경로>
local M = {}

-- 단일 파일 컴파일에 쓸 에디션 (백준 제출 환경과 맞춤)
M.single_file_edition = '2021'

---@class RustTarget
---@field kind 'single'|'bin'|'example'|'test'|'lib'
---@field file string 현재 파일 절대 경로
---@field root? string Cargo.toml이 있는 폴더 (single이면 nil)
---@field name? string example / bin / test 대상 이름
---@field modpath string 크레이트 안에서 이 파일의 모듈 경로 (예: exercises::ch03_ownership)

---@param file? string 기본값: 현재 버퍼
---@return RustTarget
function M.target(file)
  file = file or vim.api.nvim_buf_get_name(0)
  local root = vim.fs.root(file, 'Cargo.toml')
  if not root then return { kind = 'single', file = file, modpath = '' } end

  local rel = file:sub(#root + 2) -- root 기준 상대 경로
  local t = { file = file, root = root, modpath = '' }

  -- examples/foo.rs 또는 examples/foo/main.rs
  local ex = rel:match '^examples/([^/]+)%.rs$' or rel:match '^examples/([^/]+)/main%.rs$'
  local bin = rel:match '^src/bin/([^/]+)%.rs$' or rel:match '^src/bin/([^/]+)/main%.rs$'
  local test = rel:match '^tests/([^/]+)%.rs$' or rel:match '^tests/([^/]+)/main%.rs$'
  if ex then
    t.kind, t.name = 'example', ex
  elseif bin then
    t.kind, t.name = 'bin', bin
  elseif test then
    t.kind, t.name = 'test', test
  elseif rel == 'src/main.rs' then
    t.kind = 'bin'
  else
    -- src/a/b.rs → a::b,  src/a/mod.rs → a,  src/lib.rs → (루트)
    t.kind = 'lib'
    local mod = rel:match '^src/(.+)%.rs$'
    if mod then
      mod = mod:gsub('/mod$', ''):gsub('^lib$', ''):gsub('^main$', '')
      t.modpath = mod:gsub('/', '::')
    end
  end
  return t
end

-- cargo 명령에 붙일 대상 지정 인자
---@param t RustTarget
---@return string[]
local function target_args(t)
  if t.kind == 'example' then return { '--example', t.name } end
  if t.kind == 'bin' and t.name then return { '--bin', t.name } end
  if t.kind == 'test' then return { '--test', t.name } end
  return {}
end

-- F4: 현재 파일 실행 명령
---@param t RustTarget
---@return string[] cmd, string? cwd
function M.run_cmd(t)
  if t.kind == 'single' then
    local out = vim.fn.fnamemodify(t.file, ':r')
    local compile = string.format('rustc --edition %s -O %s -o %s', M.single_file_edition, vim.fn.shellescape(t.file), vim.fn.shellescape(out))
    return { 'sh', '-c', compile .. ' && exec ' .. vim.fn.shellescape(out) }, vim.fn.fnamemodify(t.file, ':h')
  end
  if t.kind == 'test' then return vim.list_extend({ 'cargo', 'test' }, target_args(t)), t.root end
  if t.kind == 'lib' then return M.test_cmd(t, nil), t.root end
  return vim.list_extend({ 'cargo', 'run' }, target_args(t)), t.root
end

-- 커서가 있는 테스트 함수의 경로 (모듈 경로 :: 인라인 mod :: 함수 이름)
-- 커서가 함수 밖이면 이 파일의 모듈 경로만 돌려줌
---@param t RustTarget
---@return string filter, boolean is_fn 함수 하나를 가리키는지
function M.test_filter_at_cursor(t)
  local parts = {}
  local fn_name
  -- 파싱이 아직 안 된 버퍼면 get_node가 nil을 주므로 먼저 파싱 (rust 파서가 없으면 그냥 넘어감)
  pcall(function() vim.treesitter.get_parser(0, 'rust'):parse() end)
  local ok, node = pcall(vim.treesitter.get_node)
  while ok and node do
    local ty = node:type()
    if ty == 'function_item' or ty == 'mod_item' then
      local name_node = node:field('name')[1]
      if name_node then
        local name = vim.treesitter.get_node_text(name_node, 0)
        if ty == 'function_item' then
          fn_name = fn_name or name
        else
          table.insert(parts, 1, name)
        end
      end
    end
    node = node:parent()
  end
  if t.modpath ~= '' then table.insert(parts, 1, t.modpath) end
  if fn_name then table.insert(parts, fn_name) end
  return table.concat(parts, '::'), fn_name ~= nil
end

-- cargo test 명령 (filter가 nil이면 이 파일 전체 테스트)
---@param t RustTarget
---@param filter? string
---@return string[]
function M.test_cmd(t, filter)
  if t.kind == 'single' then
    -- 단일 파일: rustc --test로 테스트 바이너리를 만들어 실행
    local out = vim.fn.fnamemodify(t.file, ':r') .. '_test'
    local cmd = string.format(
      'rustc --edition %s --test %s -o %s && exec %s',
      M.single_file_edition,
      vim.fn.shellescape(t.file),
      vim.fn.shellescape(out),
      vim.fn.shellescape(out)
    )
    if filter and filter ~= '' then cmd = cmd .. ' ' .. vim.fn.shellescape(filter) end
    return { 'sh', '-c', cmd }
  end
  local cmd = vim.list_extend({ 'cargo', 'test' }, target_args(t))
  -- lib는 src/ 아래 모든 대상(lib, main)을 대상으로 → 별도 인자 없이 이름 필터만
  filter = filter or t.modpath
  if filter ~= '' then vim.list_extend(cmd, { '--', filter }) end
  return cmd
end

-- 오른쪽 세로 분할 터미널에서 실행 (C++/Java/Python F4와 같은 모양)
---@param cmd string[]
---@param cwd? string
function M.open_term(cmd, cwd)
  vim.cmd 'vnew'
  vim.fn.jobstart(cmd, { term = true, cwd = cwd })
  vim.cmd 'startinsert'
end

-- ── 디버그용 빌드 ──────────────────────────────────────────

-- cargo --message-format=json 출력에서 실행 파일 경로 찾기
---@param stdout string
---@param want_test boolean 테스트 바이너리를 찾는지
---@param name? string 대상 이름 (nil이면 첫 번째 실행 파일)
local function find_executable(stdout, want_test, name)
  local found
  for line in stdout:gmatch '[^\n]+' do
    local ok, msg = pcall(vim.json.decode, line)
    if ok and type(msg) == 'table' and msg.reason == 'compiler-artifact' and type(msg.executable) == 'string' then
      local is_test = msg.profile and msg.profile.test == true
      if is_test == want_test and (name == nil or msg.target.name == name) then
        found = msg.executable
        -- lib 테스트를 찾을 땐 lib 대상을 우선 (main.rs 테스트보다)
        if not want_test or vim.tbl_contains(msg.target.kind, 'lib') or name then return found end
      end
    end
  end
  return found
end

-- 빌드 실패 메시지를 보여 줄 때 cargo 출력에서 에러 부분만 추리기
local function build_errors(stdout, stderr)
  local lines = {}
  for line in stdout:gmatch '[^\n]+' do
    local ok, msg = pcall(vim.json.decode, line)
    if ok and type(msg) == 'table' and msg.reason == 'compiler-message' and msg.message.level == 'error' then table.insert(lines, msg.message.rendered) end
  end
  if #lines == 0 then return stderr end
  return table.concat(lines, '\n')
end

---@class RustDebugTarget
---@field program string
---@field args string[]
---@field cwd string

-- 디버깅할 실행 파일을 디버그 모드로 빌드한다 (비동기, 끝나면 메인 루프에서 cb 호출)
---@param t RustTarget
---@param test_filter? string 지정하면 테스트 바이너리를 빌드해 그 테스트만 실행
---@param cb fun(target: RustDebugTarget?, err: string?)
function M.build_for_debug(t, test_filter, cb)
  local want_test = test_filter ~= nil or t.kind == 'test' or t.kind == 'lib'
  cb = vim.schedule_wrap(cb)

  if t.kind == 'single' then
    local out = vim.fn.fnamemodify(t.file, ':r') .. (want_test and '_test_dbg' or '_dbg')
    local cmd = { 'rustc', '--edition', M.single_file_edition, '-g', t.file, '-o', out }
    if want_test then table.insert(cmd, 2, '--test') end
    vim.system(cmd, { text = true }, function(r)
      if r.code ~= 0 then return cb(nil, r.stderr) end
      cb { program = out, args = test_filter and { test_filter } or {}, cwd = vim.fn.fnamemodify(t.file, ':h') }
    end)
    return
  end

  local cmd = { 'cargo', want_test and 'test' or 'build' }
  if want_test then table.insert(cmd, '--no-run') end
  vim.list_extend(cmd, target_args(t))
  if want_test and t.kind == 'lib' then table.insert(cmd, '--lib') end
  table.insert(cmd, '--message-format=json')

  vim.system(cmd, { cwd = t.root, text = true }, function(r)
    if r.code ~= 0 then return cb(nil, build_errors(r.stdout or '', r.stderr or '')) end
    local exe = find_executable(r.stdout or '', want_test, t.name)
    if not exe then return cb(nil, '실행 파일을 찾지 못했습니다: ' .. table.concat(cmd, ' ')) end
    local filter = test_filter or (want_test and t.modpath ~= '' and t.modpath) or nil
    cb { program = exe, args = filter and { filter } or {}, cwd = t.root }
  end)
end

-- F9: 디버그 세션이 있으면 계속, 없으면 빌드 후 codelldb로 시작
--   test_filter를 주면 그 테스트만 디버그 (<leader>rd)
---@param test_filter? string
function M.debug(test_filter)
  local dap = require 'dap'
  if dap.session() then return dap.continue() end

  local t = M.target()
  vim.notify('Rust: 디버그 빌드 중...', vim.log.levels.INFO)
  M.build_for_debug(t, test_filter, function(target, err)
    if not target then
      vim.notify('Rust 빌드 실패\n' .. (err or ''), vim.log.levels.ERROR)
      return
    end
    dap.run {
      name = 'Rust: ' .. vim.fn.fnamemodify(target.program, ':t'),
      type = 'codelldb',
      request = 'launch',
      program = target.program,
      args = target.args,
      cwd = target.cwd,
      stopOnEntry = false,
      sourceLanguages = { 'rust' }, -- Vec, String, Option 등을 보기 좋게 표시
    }
  end)
end

return M
