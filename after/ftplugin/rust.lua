-- Rust 버퍼 전용 단축키 (Neovim이 .rs 파일을 열 때마다 자동으로 실행)
--  - LSP(rust-analyzer)는 init.lua의 servers, 디버거(codelldb)는 dap.lua에서 설치/등록
--  - 실행 대상 판별 로직은 lua/custom/rust.lua
--  - 테스트 실행/디버그는 공통 단축키 <leader>x (lua/custom/plugins/neotest.lua)
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
