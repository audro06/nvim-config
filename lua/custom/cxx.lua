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

return M
