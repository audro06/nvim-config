-- Jupyter 노트북 (.ipynb)
--  - 편집: jupytext.nvim이 .ipynb를 `# %%` 셀 구분 Python으로 열고, 저장하면 .ipynb로 되돌림
--          (filetype이 python이라 pyright/ruff/자동완성이 그대로 동작)
--  - 실행: molten.nvim이 Jupyter 커널에서 셀 실행, 출력은 셀 아래 표시
--  - 그래프: 별도 창(기본 이미지 뷰어)으로 자동 표시. WSL은 Windows 뷰어 사용
--  - 커널: 프로젝트에 .venv가 있으면 그 Python, 없으면 기본 python3 커널
--
--  molten은 nvim 전용 Python venv(pynvim, jupyter_client 등)에서 돌아감 → build 단계에서 uv로 생성
local venv = vim.fn.stdpath 'data' .. '/jupyter-venv'
local venv_python = venv .. '/bin/python'

-- molten 실행용 venv 생성 + jupytext CLI 설치 (Lazy 설치/업데이트 시 실행)
---@param plugin LazyPlugin
local function build(plugin)
  local function run(cmd)
    local r = vim.system(cmd, { text = true }):wait()
    if r.code ~= 0 then error(table.concat(cmd, ' ') .. '\n' .. (r.stderr or '')) end
  end
  if vim.fn.executable 'uv' == 0 then error 'uv가 필요합니다 (scripts/bootstrap.sh 참고)' end

  if vim.fn.executable(venv_python) == 0 then run { 'uv', 'venv', '-q', venv } end
  run { 'uv', 'pip', 'install', '-q', '--python', venv_python, 'pynvim', 'jupyter_client', 'ipykernel', 'nbformat', 'pillow' }
  -- WSL에서 그래프를 Windows 뷰어로 열기 위한 훅: .pth로 Python 시작 시 자동 import
  --  (sitecustomize.py는 Ubuntu 시스템 Python의 것에 가려져서 사용 불가)
  local site = vim.trim(vim.system({ venv_python, '-c', 'import sysconfig; print(sysconfig.get_paths()["purelib"])' }, { text = true }):wait().stdout)
  assert(vim.uv.fs_copyfile(vim.fn.stdpath 'config' .. '/scripts/jupyter_wsl_viewer.py', site .. '/nvim_config_wsl_viewer.py'))
  vim.fn.writefile({ 'import nvim_config_wsl_viewer' }, site .. '/nvim_config_wsl_viewer.pth')

  if vim.fn.executable 'jupytext' == 0 then run { 'uv', 'tool', 'install', '-q', 'jupytext' } end

  vim.g.python3_host_prog = venv_python
  -- 처음 설치할 때는 build가 플러그인 로드 전에 실행되어 molten이 runtimepath에 없음
  --  → 그대로 UpdateRemotePlugins 하면 molten이 등록되지 않으므로 먼저 추가
  if not vim.tbl_contains(vim.opt.rtp:get(), plugin.dir) then vim.opt.rtp:prepend(plugin.dir) end
  vim.cmd 'UpdateRemotePlugins'
end

-- 현재 셀(`# %%` ~ 다음 `# %%` 직전)의 줄 범위. 마크다운 셀이면 nil
local function cell_range()
  local header = vim.fn.search('^# %%', 'bcnW')
  local next_header = vim.fn.search('^# %%', 'nW')
  if header > 0 and vim.fn.getline(header):find('[markdown]', 1, true) then return nil end
  local first = header + 1
  local last = next_header > 0 and next_header - 1 or vim.fn.line '$'
  -- 셀 끝의 빈 줄 제외
  while last > first and vim.fn.getline(last):match '^%s*$' do
    last = last - 1
  end
  if last < first then return nil end
  return first, last
end

local function run_cell()
  local first, last = cell_range()
  if first then vim.fn.MoltenEvaluateRange(first, last) end
end

local function goto_next_cell()
  if vim.fn.search('^# %%', 'W') > 0 then vim.cmd 'normal! j' end
end

local function run_all_cells()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local is_header = function(lnum) return lines[lnum] ~= nil and lines[lnum]:match '^# %%' ~= nil end
  local view = vim.fn.winsaveview()

  -- 각 셀의 첫 줄에 커서를 두고 run_cell (첫 `# %%` 이전 코드도 하나의 셀로 취급)
  if not is_header(1) then
    vim.fn.cursor(1, 1)
    run_cell()
  end
  for lnum = 1, #lines do
    -- 내용이 없는 셀(헤더 바로 다음이 헤더)은 건너뜀
    if is_header(lnum) and lnum < #lines and not is_header(lnum + 1) then
      vim.fn.cursor(lnum + 1, 1)
      run_cell()
    end
  end
  vim.fn.winrestview(view)
end

-- 프로젝트 .venv가 있으면 그 Python을 커널로 등록해서 사용
local function init_kernel()
  -- 새 컴퓨터에서는 Jupyter runtime 폴더가 없어서 커널 시작이 실패함 → 미리 생성
  vim.system({ venv_python, '-c', 'import os; from jupyter_core.paths import jupyter_runtime_dir as d; os.makedirs(d(), exist_ok=True)' }):wait()

  local root = vim.fs.root(0, '.venv')
  if not root then
    vim.cmd 'MoltenInit python3'
    return
  end

  local python = root .. '/.venv/bin/python'
  if vim.system({ python, '-c', 'import ipykernel' }):wait().code ~= 0 then
    if vim.fn.confirm('.venv에 ipykernel이 없습니다. 설치할까요?', '&Yes\n&No', 1) ~= 1 then return end
    local cmd = vim.uv.fs_stat(root .. '/pyproject.toml') and { 'uv', 'add', '--dev', 'ipykernel' }
      or { 'uv', 'pip', 'install', '--python', python, 'ipykernel' }
    local r = vim.system(cmd, { cwd = root, text = true }):wait()
    if r.code ~= 0 then
      vim.notify('ipykernel 설치 실패:\n' .. (r.stderr or ''), vim.log.levels.ERROR)
      return
    end
  end

  local project = vim.fn.fnamemodify(root, ':t')
  local name = 'venv-' .. project:lower():gsub('[^%w%-_.]', '-')
  vim.system({ python, '-m', 'ipykernel', 'install', '--user', '--name', name, '--display-name', 'Python (' .. project .. ')' }):wait()
  vim.cmd('MoltenInit ' .. name)
end

return {
  {
    'GCBallesteros/jupytext.nvim',
    lazy = false, -- .ipynb를 열기 전에 로드되어 있어야 변환됨
    config = function()
      -- 메타데이터에 kernelspec이 없는 노트북을 열면 플러그인이 에러 → 언어 정보로 대체, 없으면 python
      local utils = require 'jupytext.utils'
      local extensions = { python = 'py', julia = 'jl', r = 'r', R = 'r', bash = 'sh' }
      utils.get_ipynb_metadata = function(filename)
        local f = assert(io.open(filename, 'r'))
        local metadata = vim.json.decode(f:read 'a').metadata or {}
        f:close()
        local spec = metadata.kernelspec or {}
        local language = spec.language or (spec.name == 'python3' and 'python') or vim.tbl_get(metadata, 'language_info', 'name') or 'python'
        return { language = language, extension = extensions[language] or 'py' }
      end

      require('jupytext').setup { style = 'percent' }
    end,
  },

  {
    'benlubas/molten-nvim',
    version = '^1.0.0',
    lazy = false,
    build = build,
    init = function()
      vim.g.python3_host_prog = venv_python
      vim.g.molten_image_provider = 'none'
      vim.g.molten_auto_image_popup = true -- 그래프는 별도 창으로
      vim.g.molten_auto_open_output = false -- 커서를 올릴 때마다 출력 창 띄우지 않기
      vim.g.molten_virt_text_output = true -- 출력을 셀 아래에 표시
      vim.g.molten_virt_lines_off_by_1 = true -- `# %%` 형식에서 출력이 다음 셀 표시줄 위에 오도록
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_wrap_output = true
    end,
    config = function()
      local map = function(keys, func, desc, mode) vim.keymap.set(mode or 'n', keys, func, { desc = 'Notebook: ' .. desc, silent = true }) end

      map('<leader>ni', init_kernel, 'Start kernel ([I]nit)')
      map('<leader>nc', run_cell, 'Run [C]ell')
      map('<leader>nn', function()
        run_cell()
        goto_next_cell()
      end, 'Run cell and go to [N]ext')
      map('<leader>na', run_all_cells, 'Run [A]ll cells')
      map('<leader>nl', '<cmd>MoltenEvaluateLine<cr>', 'Run [L]ine')
      map('<leader>nv', ':<C-u>MoltenEvaluateVisual<cr>gv<esc>', 'Run selection', 'x')
      map('<leader>no', '<cmd>noautocmd MoltenEnterOutput<cr>', '[O]pen output window')
      map('<leader>nh', '<cmd>MoltenHideOutput<cr>', '[H]ide output')
      map('<leader>nd', '<cmd>MoltenDelete<cr>', '[D]elete cell output')
      map('<leader>np', '<cmd>MoltenImagePopup<cr>', 'Open [P]lot image')
      map('<leader>nx', '<cmd>MoltenInterrupt<cr>', 'Interrupt')
      map('<leader>nR', '<cmd>MoltenRestart!<cr>', '[R]estart kernel')

      local group = vim.api.nvim_create_augroup('custom-jupyter', { clear = true })

      -- 노트북에 저장된 기존 출력 불러오기 / 저장할 때 출력도 .ipynb에 기록
      vim.api.nvim_create_autocmd('User', {
        group = group,
        pattern = 'MoltenInitPost',
        callback = function()
          if vim.api.nvim_buf_get_name(0):match '%.ipynb$' then pcall(vim.cmd, 'MoltenImportOutput') end
        end,
      })
      vim.api.nvim_create_autocmd('BufWritePost', {
        group = group,
        pattern = '*.ipynb',
        callback = function()
          if require('molten.status').initialized() == 'Molten' then pcall(vim.cmd, 'MoltenExportOutput!') end
        end,
      })

      -- .ipynb 안에서 ]] / [[ 로 셀 이동
      vim.api.nvim_create_autocmd('BufEnter', {
        group = group,
        pattern = '*.ipynb',
        callback = function(args)
          vim.keymap.set('n', ']]', goto_next_cell, { buffer = args.buf, desc = 'Notebook: Next cell' })
          vim.keymap.set('n', '[[', function()
            vim.fn.search('^# %%', 'bW')
            vim.fn.search('^# %%', 'bW')
            vim.cmd 'normal! j'
          end, { buffer = args.buf, desc = 'Notebook: Previous cell' })
        end,
      })

      pcall(function() require('which-key').add { { '<leader>n', group = '[N]otebook' } } end)
    end,
  },
}
