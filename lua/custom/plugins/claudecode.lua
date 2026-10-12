-- Claude Code 채팅창 (VS Code 확장처럼 오른쪽 분할창)
--  - Claude가 열린 파일/선택 영역을 인식하고, 수정 제안은 diff로 보여줌
--  - <leader>a는 harpoon이 쓰고 있어서 <leader>c 아래에 배치
--  - 터미널 모드에서 일반 모드로 나가기: <Esc><Esc> (init.lua 설정)
return {
  'coder/claudecode.nvim',
  dependencies = { 'folke/snacks.nvim' },
  opts = {
    -- WSL에 설치한 Claude Code 경로 (PATH와 상관없이 실행되도록 직접 지정)
    terminal_cmd = vim.fn.expand '~/.local/bin/claude',
    terminal = {
      split_side = 'right',
      split_width_percentage = 0.35,
    },
  },
  keys = {
    { '<leader>c', nil, desc = '[C]laude Code' },
    { '<leader>cc', '<cmd>ClaudeCode<cr>', desc = '[C]laude: Toggle' },
    { '<leader>cf', '<cmd>ClaudeCodeFocus<cr>', desc = '[C]laude: [F]ocus' },
    { '<leader>cr', '<cmd>ClaudeCode --resume<cr>', desc = '[C]laude: [R]esume' },
    { '<leader>cC', '<cmd>ClaudeCode --continue<cr>', desc = '[C]laude: [C]ontinue' },
    { '<leader>cm', '<cmd>ClaudeCodeSelectModel<cr>', desc = '[C]laude: Select [M]odel' },
    { '<leader>cb', '<cmd>ClaudeCodeAdd %<cr>', desc = '[C]laude: Add current [B]uffer' },
    { '<leader>cs', '<cmd>ClaudeCodeSend<cr>', mode = 'v', desc = '[C]laude: [S]end selection' },
    { '<leader>ca', '<cmd>ClaudeCodeDiffAccept<cr>', desc = '[C]laude: [A]ccept diff' },
    { '<leader>cd', '<cmd>ClaudeCodeDiffDeny<cr>', desc = '[C]laude: [D]eny diff' },
  },
}
