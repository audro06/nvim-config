-- 테스트 실행 (neotest): 언어마다 달랐던 테스트 단축키를 <leader>x 하나로 통일
--  - Python: neotest-python (pytest. 프로젝트 .venv 자동 인식, 디버그는 python.lua의 debugpy)
--  - Java:   neotest-java (Maven/Gradle + JUnit. jdtls로 컴파일. JUnit 실행용 jar는 `:NeotestJava setup`으로 한 번 받아야 함)
--  - Rust:   lua/custom/neotest_rust.lua (cargo test / 단일 파일은 rustc --test)
--  - 결과는 줄 옆 표시와 <leader>xs 요약 창, 실패 내용은 <leader>xo
--  - 디버그(<leader>xd)는 기존 nvim-dap(dap.lua)의 F9/F10/F11, <leader>b 그대로 사용

-- 실행 전에 저장 (테스트는 디스크의 파일로 돌아감)
local function save(all) pcall(vim.cmd, all and 'silent wall' or 'silent update') end

-- neotest-java는 빌드 파일이 없어도 .git만 있으면 그 폴더를 Java 프로젝트로 잡아서
-- 다른 언어 프로젝트의 "전체 실행"(<leader>xa)을 가로챈다 → Maven/Gradle 프로젝트에서만 쓰도록 제한
local function java_adapter()
  local adapter = require 'neotest-java' {}
  local find_root = adapter.root
  local build_files = { 'pom.xml', 'build.gradle', 'build.gradle.kts', 'settings.gradle', 'settings.gradle.kts', 'mvnw', 'gradlew' }
  local has_build_file = require('neotest.lib').files.match_root_pattern(unpack(build_files))
  adapter.root = function(dir)
    if has_build_file(dir) then return find_root(dir) end
  end
  return adapter
end

return {
  'nvim-neotest/neotest',
  dependencies = {
    'nvim-neotest/nvim-nio',
    'nvim-lua/plenary.nvim',
    'nvim-treesitter/nvim-treesitter',
    'nvim-neotest/neotest-python',
    'rcasia/neotest-java',
  },
  -- neotest를 쓰기 전에도 `:NeotestJava setup`을 쓸 수 있게 (명령은 neotest-java 것이지만 neotest를 통해 불러야 한다.
  --  neotest-java를 먼저 부르면 그쪽이 neotest를 불러오다가 아래 config가 neotest-java를 다시 require해서 오류가 남)
  cmd = 'NeotestJava',
  keys = {
    {
      '<leader>xt',
      function()
        save()
        require('neotest').run.run()
      end,
      desc = 'Test: Run nearest [T]est',
    },
    {
      '<leader>xf',
      function()
        save()
        require('neotest').run.run(vim.fn.expand '%:p')
      end,
      desc = 'Test: Run [F]ile',
    },
    {
      '<leader>xa',
      function()
        save(true)
        require('neotest').run.run(vim.uv.cwd())
      end,
      desc = 'Test: Run [A]ll (current directory)',
    },
    {
      '<leader>xd',
      function()
        save()
        require('neotest').run.run { strategy = 'dap' }
      end,
      desc = 'Test: [D]ebug nearest test',
    },
    { '<leader>xs', function() require('neotest').summary.toggle() end, desc = 'Test: Toggle [S]ummary' },
    { '<leader>xo', function() require('neotest').output.open { enter = true, auto_close = true } end, desc = 'Test: Show [O]utput' },
  },
  init = function()
    -- which-key 묶음 이름 (neotest는 단축키를 처음 누를 때 로드되므로 여기서 미리 등록)
    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      once = true,
      callback = function()
        pcall(function() require('which-key').add { { '<leader>x', group = 'Test (e[X]ecute)' } } end)
      end,
    })
  end,
  config = function()
    ---@diagnostic disable-next-line: missing-fields
    require('neotest').setup {
      adapters = {
        require 'neotest-python' { runner = 'pytest', dap = { justMyCode = false } },
        java_adapter(),
        require 'custom.neotest_rust',
      },
      -- Nerd Font가 없으면 아이콘을 일반 문자로
      icons = not vim.g.have_nerd_font and {
        passed = '+',
        failed = 'x',
        running = '~',
        skipped = '-',
        unknown = '?',
        watching = 'w',
        notify = '!',
        test = '',
        dir = '',
        file = '',
        namespace = '',
      } or nil,
    }
  end,
}
