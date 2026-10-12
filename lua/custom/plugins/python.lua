-- Python 개발 환경 (pyright + ruff + debugpy)
--  - LSP: pyright(자동완성/타입검사) + ruff(린트/코드 액션)
--  - 포맷: 저장 시 ruff로 자동 포맷 + import 정리 (conform)
--  - 가상환경: 프로젝트의 .venv (uv로 만든 것 포함)를 자동 인식
--  - 디버깅: 기존 nvim-dap(dap.lua)의 F9/F10/F11, <leader>b 그대로 사용
return {
  { -- 저장 시 포맷: init.lua의 conform 설정에 python만 추가 (opts는 lazy가 병합)
    --  ruff_fix는 안 쓰는 import를 저장할 때마다 지워버려서 제외 (필요하면 gra 코드 액션으로)
    'stevearc/conform.nvim',
    opts = {
      formatters_by_ft = {
        python = { 'ruff_format', 'ruff_organize_imports' },
      },
    },
  },

  {
    'mfussenegger/nvim-dap-python',
    ft = 'python',
    dependencies = {
      'mfussenegger/nvim-dap',
      'mason-org/mason.nvim',
    },
    config = function()
      local mason = require 'custom.mason'

      -- LSP, 린터/포매터, 디버거를 Mason으로 자동 설치
      mason.ensure_installed { 'pyright', 'ruff', 'debugpy' }

      -- Python 문법 강조 (treesitter)
      require('nvim-treesitter').install { 'python' }

      -- pyright: 프로젝트 루트에 .venv가 있으면 그 인터프리터 사용
      vim.lsp.config('pyright', {
        before_init = function(params, config)
          -- 단일 파일이면 root가 없거나 vim.NIL로 들어옴
          local root = config.root_dir or params.rootPath
          if type(root) ~= 'string' then return end
          local python = root .. '/.venv/bin/python'
          if vim.uv.fs_stat(python) then config.settings = vim.tbl_deep_extend('force', config.settings or {}, { python = { pythonPath = python } }) end
        end,
      })
      -- ruff: hover는 pyright에 맡김
      vim.lsp.config('ruff', {
        on_attach = function(client) client.server_capabilities.hoverProvider = false end,
      })
      vim.lsp.enable { 'pyright', 'ruff' }

      -- 디버거: Mason의 debugpy 사용 (실행 대상 인터프리터는 .venv / VIRTUAL_ENV 자동 인식)
      local dap_python = require 'dap-python'
      dap_python.setup(mason.package_path 'debugpy' .. '/venv/bin/python')
      dap_python.test_runner = 'pytest'

      vim.api.nvim_create_autocmd('FileType', {
        group = vim.api.nvim_create_augroup('custom-python', { clear = true }),
        pattern = 'python',
        callback = function(args)
          local map = function(keys, func, desc, mode) vim.keymap.set(mode or 'n', keys, func, { buffer = args.buf, desc = 'Python: ' .. desc }) end

          map('<leader>pt', dap_python.test_method, '[T]est method (debug)')
          map('<leader>pT', dap_python.test_class, '[T]est class (debug)')
          map('<leader>ps', dap_python.debug_selection, 'Debug [S]election', 'x')

          -- F4: 현재 파일 저장 후 바로 실행 (.venv가 있으면 그 Python, 없으면 python3)
          map('<F4>', function()
            vim.cmd 'write'
            local file = vim.fn.expand '%:p'
            local venv_root = vim.fs.root(0, '.venv')
            local python = venv_root and venv_root .. '/.venv/bin/python' or 'python3'
            vim.cmd 'vnew'
            vim.fn.termopen { python, file }
            vim.cmd 'startinsert'
          end, 'Run current file')
        end,
      })

      pcall(function() require('which-key').add { { '<leader>p', group = '[P]ython' } } end)
    end,
  },
}
