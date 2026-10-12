return {
  'mfussenegger/nvim-dap',
  dependencies = {
    -- 디버깅 UI와 필수 의존성
    'rcarriga/nvim-dap-ui',
    'nvim-neotest/nvim-nio',

    -- Mason과 연동하여 디버거(codelldb) 자동 설치
    'williamboman/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    -- Mason을 통해 C++ 디버거인 codelldb를 자동 설치 및 세팅
    require('mason-nvim-dap').setup {
      ensure_installed = { 'codelldb' },
      handlers = {},
    }

    -- UI 초기화
    dapui.setup()

    -- 디버깅이 시작되면 UI를 자동으로 열고, 끝나면 닫도록 설정
    dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
    dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
    dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end

    -- C++ 디버깅 실행 설정
    dap.configurations.cpp = {
      {
        name = 'Launch file',
        type = 'codelldb',
        request = 'launch',
        program = function()
          -- 기본적으로 현재 파일명과 똑같은 이름의 실행파일을 찾습니다.
          return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/' .. vim.fn.expand '%:r', 'file')
        end,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
      },
    }

    -- 직관적인 디버깅 단축키 설정
    vim.keymap.set('n', '<F9>', dap.continue, { desc = 'Debug: Start/Continue' })
    vim.keymap.set('n', '<F10>', dap.step_over, { desc = 'Debug: Step Over' })
    vim.keymap.set('n', '<F11>', dap.step_into, { desc = 'Debug: Step Into' })
    vim.keymap.set('n', '<leader>b', dap.toggle_breakpoint, { desc = 'Debug: Toggle Breakpoint' })
  end,
}
