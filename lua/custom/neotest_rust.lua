-- neotest용 Rust 어댑터 (lua/custom/plugins/neotest.lua에서 등록)
--  실행 명령은 lua/custom/rust.lua의 대상 판별을 그대로 써서 단일 파일(rustc --test)과 cargo 프로젝트를 모두 지원한다.
--  (rouge8/neotest-rust는 보관된 저장소이고 cargo-nextest가 따로 필요해서 쓰지 않는다)
--  결과는 `cargo test` 출력의 `test 이름 ... ok/FAILED/ignored` 줄을 읽어서 판정한다.
local lib = require 'neotest.lib'
local nio = require 'nio'
local rust = require 'custom.rust'

---@type neotest.Adapter
---@diagnostic disable-next-line: missing-fields
local adapter = { name = 'custom-rust' }

adapter.root = lib.files.match_root_pattern 'Cargo.toml'

function adapter.filter_dir(name) return name ~= 'target' and name ~= '.git' end

-- #[test], #[tokio::test] 같은 테스트 함수가 있는 .rs 파일
---@async
function adapter.is_test_file(file_path)
  if not vim.endswith(file_path, '.rs') then return false end
  local ok, content = pcall(lib.files.read, file_path)
  return ok and content:find '#%[[%w_:]*test[%]%(]' ~= nil
end

-- 테스트 함수: 속성 이름이 test로 끝나는 함수 (#[test], #[tokio::test]) / 묶음: 본문이 있는 mod
local query = [[
  (
    (attribute_item (attribute [
      (identifier) @_attr
      (scoped_identifier name: (identifier) @_attr)
    ]))
    .
    [(attribute_item) (line_comment) (block_comment)]*
    .
    (function_item name: (identifier) @test.name) @test.definition
    (#eq? @_attr "test")
  )
  (mod_item name: (identifier) @namespace.name body: (declaration_list)) @namespace.definition
]]

---@async
function adapter.discover_positions(path) return lib.treesitter.parse_positions(path, query, { require_namespaces = false }) end

-- cargo가 출력하는 테스트 이름 (파일의 모듈 경로 :: 인라인 mod :: 함수 이름)
---@param pos neotest.Position
---@return string
local function full_name(pos)
  local name = pos.id:sub(#pos.path + 3) -- 위치 id는 "파일경로::mod::함수"
  local modpath = rust.target(pos.path).modpath
  return modpath ~= '' and (modpath .. '::' .. name) or name
end

---@async
---@param args neotest.RunArgs
---@return neotest.RunSpec?
function adapter.build_spec(args)
  nio.scheduler() -- 아래에서 vim.fn을 쓰므로 메인 루프에서 실행
  local pos = args.tree:data()

  if pos.type == 'dir' then
    -- cargo 프로젝트 루트는 한 번에 실행. 그 밖의 폴더는 nil을 돌려주면 neotest가 파일별로 나눠 실행한다
    if args.strategy == 'dap' or not vim.uv.fs_stat(pos.path .. '/Cargo.toml') then return nil end
    return { command = { 'cargo', 'test' }, cwd = pos.path }
  end

  local t = rust.target(pos.path)
  local filter, exact
  if pos.type == 'test' then
    filter, exact = full_name(pos), true
  elseif pos.type == 'namespace' then
    filter = full_name(pos) .. '::'
  end

  if args.strategy ~= 'dap' then return { command = rust.test_cmd(t, filter, exact), cwd = t.root or vim.fs.dirname(pos.path) } end

  -- 디버그: 테스트 바이너리를 빌드한 뒤 codelldb로 실행 (F9와 같은 방식)
  local build = nio.wrap(function(cb) rust.build_for_debug(t, filter or '', cb) end, 1)
  local target, err = build()
  if not target then
    vim.notify('Rust 빌드 실패\n' .. (err or ''), vim.log.levels.ERROR)
    error 'Rust 빌드 실패'
  end
  if exact then table.insert(target.args, '--exact') end
  return {
    cwd = target.cwd,
    strategy = {
      name = 'Rust test: ' .. vim.fn.fnamemodify(target.program, ':t'),
      type = 'codelldb',
      request = 'launch',
      program = target.program,
      args = target.args,
      cwd = target.cwd,
      stopOnEntry = false,
      sourceLanguages = { 'rust' },
    },
  }
end

local statuses = { ok = 'passed', FAILED = 'failed', ignored = 'skipped' }

---@async
---@param result neotest.StrategyResult
---@param tree neotest.Tree
---@return table<string, neotest.Result>
function adapter.results(_, result, tree)
  local ok, output = pcall(lib.files.read, result.output)
  nio.scheduler()
  -- neotest는 터미널(pty)로 실행하므로 cargo가 색상 코드를 섞어 출력한다 → 걷어내고 읽기
  output = ok and output:gsub('\27%[[%d;]*%a', '') or ''

  -- "test tests::adds ... ok", "test tests::panics - should panic ... ok"
  local outcomes = {}
  for line in output:gmatch '[^\r\n]+' do
    local name, outcome = line:match '^test (%S+).- %.%.%. (%a+)$'
    if name and statuses[outcome] then outcomes[name] = statuses[outcome] end
  end

  -- 실패한 테스트의 위치와 메시지: "thread 'tests::adds' (123) panicked at src/lib.rs:10:9:" 다음 줄이 메시지
  local panics = {}
  for name, file, line, message in output:gmatch "thread '([^'\r\n]+)'[^\r\n]- panicked at ([^\r\n]-):(%d+):%d+:\r?\n([^\r\n]*)" do
    panics[name] = { file = file, line = tonumber(line), message = message }
  end

  local results = {}
  for _, node in tree:iter_nodes() do
    local pos = node:data()
    if pos.type == 'test' then
      local name = full_name(pos)
      if outcomes[name] then
        local panic = outcomes[name] == 'failed' and panics[name] or nil
        results[pos.id] = {
          status = outcomes[name],
          short = panic and (name .. ': ' .. panic.message) or nil,
          -- 실패한 줄에 진단 표시 (panic이 이 파일에서 난 경우만)
          errors = panic and { { message = panic.message, line = vim.endswith(pos.path, panic.file) and panic.line - 1 or nil } } or nil,
        }
      end
    end
  end

  if vim.tbl_isempty(results) then
    if result.code ~= 0 then
      -- 컴파일 오류 등으로 테스트가 하나도 돌지 않았으면 실행한 위치를 실패로 표시 (출력은 <leader>xo로 확인)
      results[tree:data().id] = { status = 'failed' }
    elseif not output:find('test result:', 1, true) then
      -- 디버그 실행(<leader>xd)은 테스트 출력이 잡히지 않는다 → 종료 코드로 판정
      results[tree:data().id] = { status = 'passed' }
    end
  end
  return results
end

return adapter
