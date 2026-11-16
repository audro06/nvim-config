-- Markdown 렌더링 (nvim 안에서 보기)
--  - .md를 열면 제목/표/코드 블록/체크박스/인용문/콜아웃을 꾸며서 표시
--  - 커서가 있는 줄과 insert 모드에서는 원래 문법이 보여서 그대로 편집 가능
--  - <leader>tm 으로 켜고 끄기
--  - Nerd Font가 없으면(init.lua의 vim.g.have_nerd_font) 아이콘을 일반 문자로 대체
return {
  'MeanderingProgrammer/render-markdown.nvim',
  ft = { 'markdown' },
  dependencies = { 'nvim-treesitter/nvim-treesitter' },
  keys = {
    { '<leader>tm', '<cmd>RenderMarkdown buf_toggle<cr>', ft = 'markdown', desc = '[T]oggle [M]arkdown render' },
  },
  config = function()
    -- 문서 맨 위 front matter(--- ... ---) 렌더링용
    require('nvim-treesitter').install { 'yaml' }

    ---@module 'render-markdown'
    ---@type render.md.UserConfig
    local opts = {
      latex = { enabled = false }, -- 수식 변환기(latex2text 등) 미설치
    }

    if not vim.g.have_nerd_font then
      -- 콜아웃(> [!NOTE] 등): 앞의 아이콘을 떼고 글자만
      local callouts = {}
      for name, callout in pairs(require('render-markdown.settings').callout.default) do
        callouts[name] = { rendered = callout.rendered:gsub('^%S+ ', '') }
      end

      opts = vim.tbl_deep_extend('force', opts, {
        heading = { icons = { '# ', '## ', '### ', '#### ', '##### ', '###### ' } },
        checkbox = { unchecked = { icon = '☐ ' }, checked = { icon = '☑ ' } },
        callout = callouts,
        code = { language_icon = false },
        link = { enabled = false }, -- 링크 앞 아이콘
        sign = { enabled = false }, -- 왼쪽 sign column 아이콘
      })
    end

    require('render-markdown').setup(opts)
  end,
}
