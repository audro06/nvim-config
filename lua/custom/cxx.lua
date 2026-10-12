-- C++ 컴파일러 선택 (F4, competitest 공용)
--   Linux: g++
--   macOS: 기본 g++는 clang이라 bits/stdc++.h가 없음 → brew gcc의 g++-NN 중 가장 높은 버전
local M = {}

local compiler

function M.compiler()
  if compiler then return compiler end
  compiler = 'g++'
  if vim.fn.has 'mac' == 1 then
    for version = 30, 9, -1 do
      if vim.fn.executable('g++-' .. version) == 1 then
        compiler = 'g++-' .. version
        break
      end
    end
    if compiler == 'g++' then
      vim.schedule(
        function() vim.notify('brew gcc(g++-NN)를 찾지 못해 clang g++를 씁니다. bits/stdc++.h가 필요하면: brew install gcc', vim.log.levels.WARN) end
      )
    end
  end
  return compiler
end

-- clangd 설정 (macOS만): F4와 같은 brew gcc의 libstdc++ 헤더를 보게 함
--   기본 clangd는 Apple libc++ 헤더를 써서 bits/stdc++.h를 못 찾음
--   - compile_commands.json이 g++-NN을 쓰는 프로젝트: --query-driver로 gcc에 헤더 경로를 물어봄
--   - 단일 파일(코테): fallbackFlags에 gcc의 C++ 헤더 경로를 넣음 (F4와 같은 -std=c++23)
---@return vim.lsp.Config
function M.clangd_config()
  if vim.fn.has 'mac' == 0 then return {} end
  return {
    cmd = { 'clangd', '--query-driver=/opt/homebrew/bin/g++-*,/usr/local/bin/g++-*' },
    before_init = function(params)
      local cxx = M.compiler()
      if cxx == 'g++' then return end
      local result = vim.system({ cxx, '-xc++', '-E', '-v', '-' }, { stdin = '' }):wait()
      local flags = { '-std=c++23', '-nostdinc++' }
      local in_list = false
      for line in (result.stderr or ''):gmatch '[^\n]+' do
        if line:find('search starts here', 1, true) then
          in_list = true
        elseif line:find('End of search list', 1, true) then
          break
        elseif in_list and line:find('/include/c++/', 1, true) then
          vim.list_extend(flags, { '-isystem', vim.trim(line) })
        end
      end
      params.initializationOptions = vim.tbl_extend('force', params.initializationOptions or {}, { fallbackFlags = flags })
    end,
  }
end

return M
