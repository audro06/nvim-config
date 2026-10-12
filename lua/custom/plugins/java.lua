-- Java 개발 환경 (jdtls + 디버거 + JUnit 테스트)
--  - LSP: nvim-jdtls가 Mason의 jdtls를 프로젝트별 workspace로 실행
--  - 디버깅: 기존 nvim-dap(dap.lua)의 F9/F10/F11, <leader>b 그대로 사용
--  - JDK: SDKMAN 기본 버전(Java 26)으로 실행, 설치된 다른 JDK도 자동 등록
return {
  'mfussenegger/nvim-jdtls',
  ft = 'java',
  dependencies = {
    'mfussenegger/nvim-dap',
    'mason-org/mason.nvim',
  },
  config = function()
    local mason = require 'custom.mason'

    -- jdtls, 디버거, 테스트 러너를 Mason으로 자동 설치
    mason.ensure_installed { 'jdtls', 'java-debug-adapter', 'java-test' }

    -- Java 문법 강조 (treesitter)
    require('nvim-treesitter').install { 'java' }

    -- 디버거/테스트 jar 목록 (nvim-jdtls README 기준)
    local function get_bundles()
      local bundles = {}
      local debug_jar = vim.fn.glob(mason.package_path 'java-debug-adapter' .. '/extension/server/com.microsoft.java.debug.plugin-*.jar', true)
      if debug_jar ~= '' then table.insert(bundles, debug_jar) end

      local excluded = { 'com.microsoft.java.test.runner-jar-with-dependencies.jar', 'jacocoagent.jar' }
      for _, jar in ipairs(vim.fn.glob(mason.package_path 'java-test' .. '/extension/server/*.jar', true, true)) do
        if not vim.tbl_contains(excluded, vim.fn.fnamemodify(jar, ':t')) then table.insert(bundles, jar) end
      end
      return bundles
    end

    -- SDKMAN에 설치된 JDK들을 jdtls 런타임으로 등록 (current = sdk default 버전이 기본)
    --  프로젝트는 pom.xml/build.gradle에 지정한 버전, 단일 파일은 기본 버전으로 컴파일
    local function get_runtimes()
      local sdk_java = vim.fn.expand '~/.sdkman/candidates/java'
      local current = vim.uv.fs_realpath(sdk_java .. '/current')
      local runtimes = {}
      for _, dir in ipairs(vim.fn.glob(sdk_java .. '/*', true, true)) do
        local major = vim.fn.fnamemodify(dir, ':t'):match '^(%d+)'
        if major then
          table.insert(runtimes, {
            name = 'JavaSE-' .. major,
            path = dir,
            default = vim.uv.fs_realpath(dir) == current,
          })
        end
      end
      return runtimes
    end

    local function on_attach(_, bufnr)
      local jdtls = require 'jdtls'
      local map = function(keys, func, desc, mode) vim.keymap.set(mode or 'n', keys, func, { buffer = bufnr, desc = 'Java: ' .. desc }) end

      -- 디버거 연결 + main 클래스 실행 설정 자동 생성
      jdtls.setup_dap { hotcodereplace = 'auto' }
      require('jdtls.dap').setup_dap_main_class_configs()

      map('<leader>jo', jdtls.organize_imports, '[O]rganize imports')
      map('<leader>jv', jdtls.extract_variable, 'Extract [V]ariable', { 'n', 'x' })
      map('<leader>jc', jdtls.extract_constant, 'Extract [C]onstant', { 'n', 'x' })
      map('<leader>jm', function() jdtls.extract_method(true) end, 'Extract [M]ethod', 'x')
      map('<leader>jt', jdtls.test_nearest_method, '[T]est nearest method')
      map('<leader>jT', jdtls.test_class, '[T]est class')
    end

    local function start_jdtls()
      local jdtls_bin = vim.fn.stdpath 'data' .. '/mason/bin/jdtls'
      if vim.fn.executable(jdtls_bin) == 0 then
        vim.notify('jdtls가 아직 설치되지 않았습니다. Mason 설치가 끝나면 파일을 다시 여세요.', vim.log.levels.WARN)
        return
      end

      -- Maven/Gradle 프로젝트 루트, 없으면(단일 파일) 파일이 있는 폴더
      local root_dir = vim.fs.root(0, { 'gradlew', 'mvnw', 'pom.xml', 'build.gradle', 'build.gradle.kts', 'settings.gradle', '.git' }) or vim.fn.expand '%:p:h'
      -- 프로젝트마다 별도의 jdtls workspace 사용
      local workspace_dir = vim.fn.stdpath 'cache' .. '/jdtls/workspace/' .. root_dir:gsub('/', '%%')

      require('jdtls').start_or_attach {
        cmd = {
          jdtls_bin,
          '--jvm-arg=-javaagent:' .. mason.package_path 'jdtls' .. '/lombok.jar', -- Lombok 지원
          '-data',
          workspace_dir,
        },
        root_dir = root_dir,
        settings = {
          java = {
            signatureHelp = { enabled = true },
            contentProvider = { preferred = 'fernflower' }, -- 라이브러리 소스 디컴파일
            configuration = { runtimes = get_runtimes() },
          },
        },
        init_options = { bundles = get_bundles() },
        on_attach = on_attach,
      }
    end

    vim.api.nvim_create_autocmd('FileType', {
      group = vim.api.nvim_create_augroup('custom-java', { clear = true }),
      pattern = 'java',
      callback = function(args)
        start_jdtls()

        -- F4: 현재 파일 저장 후 바로 실행 (단일 파일 소스 실행, 코테용)
        vim.keymap.set('n', '<F4>', function()
          vim.cmd 'write'
          local file = vim.fn.expand '%:p'
          vim.cmd 'vnew'
          vim.fn.termopen { 'java', file }
          vim.cmd 'startinsert'
        end, { buffer = args.buf, desc = 'Java: Run current file' })
      end,
    })

    pcall(function() require('which-key').add { { '<leader>j', group = '[J]ava' } } end)
  end,
}
