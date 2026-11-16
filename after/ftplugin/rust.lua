-- Rust 버퍼 전용 단축키 (Neovim이 .rs 파일을 열 때마다 자동으로 실행)
--  - LSP(rust-analyzer)는 init.lua의 servers, 디버거(codelldb)는 dap.lua에서 설치/등록
--  - 실행 대상 판별 로직은 lua/custom/rust.lua
local rust = require 'custom.rust'
local buf = vim.api.nvim_get_current_buf()

local map = function(keys, func, desc) vim.keymap.set('n', keys, func, { buffer = buf, desc = 'Rust: ' .. desc }) end

-- 저장 후 터미널에서 실행
local function run_in_term(build_cmd)
  vim.cmd 'write'
  local t = rust.target()
  local cmd, cwd = build_cmd(t)
  rust.open_term(cmd, cwd or t.root)
end

-- F4: 현재 파일 실행
--   단일 파일 → rustc 컴파일 후 실행 / examples → cargo run --example / src/main.rs → cargo run
--   main이 없는 모듈 파일 → 그 파일의 테스트 실행 (예: 코드집 src/exercises/ch03_*.rs)
map('<F4>', function() run_in_term(rust.run_cmd) end, 'Run current file')

-- F9: 디버그 시작/계속 (빌드 → codelldb). F10/F11/<leader>b는 dap.lua 그대로
map('<F9>', function()
  vim.cmd 'write'
  rust.debug()
end, 'Debug: Start/Continue')

-- 테스트
map('<leader>rt', function()
  run_in_term(function(t)
    local filter = rust.test_filter_at_cursor(t)
    return rust.test_cmd(t, filter)
  end)
end, '[T]est at cursor (함수 밖이면 파일 전체)')
map('<leader>rf', function()
  run_in_term(function(t) return rust.test_cmd(t, nil) end)
end, 'Test [F]ile')
map('<leader>ra', function()
  run_in_term(function(t)
    if t.kind == 'single' then return rust.test_cmd(t, '') end
    return { 'cargo', 'test' }
  end)
end, 'Test [A]ll (cargo test)')
map('<leader>rd', function()
  vim.cmd 'write'
  local t = rust.target()
  local filter, is_fn = rust.test_filter_at_cursor(t)
  if not is_fn then
    vim.notify('커서를 테스트 함수 안에 두고 실행하세요.', vim.log.levels.WARN)
    return
  end
  rust.debug(filter)
end, '[D]ebug test at cursor')

-- Cargo 명령
map('<leader>rr', function()
  run_in_term(function() return { 'cargo', 'run' } end)
end, 'cargo [R]un (프로젝트 main)')
map('<leader>rc', function()
  run_in_term(function() return { 'cargo', 'clippy', '--all-targets' } end)
end, 'cargo [C]lippy')
map('<leader>rb', function()
  run_in_term(function() return { 'cargo', 'build' } end)
end, 'cargo [B]uild')

pcall(function() require('which-key').add { { '<leader>r', group = '[R]ust', buffer = buf } } end)
