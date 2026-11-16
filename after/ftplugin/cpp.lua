-- C++ 버퍼 전용 단축키 (Neovim이 .cpp 파일을 열 때마다 자동으로 실행)
--  - LSP(clangd)는 init.lua의 servers, 디버거(codelldb)는 dap.lua, 컴파일러 선택은 lua/custom/cxx.lua

-- F4: 저장 -> 컴파일 -> 새 터미널에서 실행
vim.keymap.set('n', '<F4>', function()
  vim.cmd 'write' -- 현재 파일 저장

  -- 저장되지 않은 버퍼라면 중단
  local file_path = vim.fn.expand '%:p'
  if file_path == '' then
    vim.notify('먼저 파일을 저장해주세요.', vim.log.levels.WARN)
    return
  end

  -- 확장자를 제거한 절대 출력 경로
  local output_path = vim.fn.expand '%:p:r'

  -- shellescape: 한글, 공백, 괄호, 특수문자 등이 포함된 경로 보호
  local escaped_file = vim.fn.shellescape(file_path)
  local escaped_output = vim.fn.shellescape(output_path)

  -- 파일 인코딩 자동 감지 후 컴파일 옵션 동적 추가
  local enc = vim.bo.fileencoding:lower()
  local charset_flags = ''
  if enc == 'cp949' or enc == 'euc-kr' then charset_flags = '-finput-charset=CP949 -fexec-charset=UTF-8' end

  local cxx = require('custom.cxx').compiler()
  local compile_cmd = string.format('%s %s -std=c++23 -Wall -O2 %s -o %s', cxx, charset_flags, escaped_file, escaped_output)
  local command = compile_cmd .. ' && exec ' .. escaped_output

  vim.cmd 'vnew'
  vim.fn.termopen { 'sh', '-c', command }

  vim.cmd 'startinsert'
end, { buffer = true, desc = 'C++: Compile and run current file' })
