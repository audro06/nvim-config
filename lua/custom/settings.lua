-- 개인 설정 (init.lua 맨 끝에서 require)
--  kickstart 기본값을 덮어쓰는 옵션, 진단 표시, Copilot 설정을 모아 둔다.
--  init.lua 본문을 건드리지 않아야 kickstart upstream을 merge할 때 충돌이 적다.

-- 들여쓰기 4칸
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

vim.o.number = true -- 현재 줄 번호
vim.o.relativenumber = true

-- 한글 Windows에서 만든 파일(cp949/euc-kr)도 깨지지 않게 열기
vim.opt.fileencodings = { 'utf-8', 'cp949', 'euc-kr', 'latin1' }

-- 진단 메시지는 줄 끝에 표시하지 않고, gl로 띄워서 보기
vim.diagnostic.config { virtual_text = false }
vim.keymap.set('n', 'gl', vim.diagnostic.open_float, { desc = 'Show diagnostic under cursor' })

-- Copilot 설정: Tab 대신 Ctrl+J로 수락하기
vim.g.copilot_no_tab_map = true
vim.keymap.set('i', '<C-J>', 'copilot#Accept("\\<CR>")', {
  expr = true,
  replace_keycodes = false,
})

-- 이 폴더들 아래에서는 Copilot 끄기 (코테 연습용)
local disabled_roots = {
  vim.fn.expand '~/boj',
}

local function copilot_should_be_disabled()
  local cwd = vim.fn.getcwd()
  for _, root in ipairs(disabled_roots) do
    -- 현재 작업 디렉터리가 root 하위이면 비활성화
    if cwd:sub(1, #root) == root then return true end
  end
  return false
end

-- Neovim이 시작될 때, 그리고 버퍼를 열 때마다 Copilot on/off 조정
vim.api.nvim_create_autocmd({ 'VimEnter', 'BufRead', 'BufNewFile' }, {
  group = vim.api.nvim_create_augroup('custom-copilot', { clear = true }),
  callback = function()
    if vim.fn.exists ':Copilot' ~= 2 then return end

    if copilot_should_be_disabled() then
      vim.cmd 'Copilot disable'
    else
      vim.cmd 'Copilot enable'
    end
  end,
})
