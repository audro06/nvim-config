return {
  'ThePrimeagen/harpoon',
  branch = 'harpoon2',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    local harpoon = require 'harpoon'

    -- 하푼 기본 설정 초기화
    harpoon:setup()

    -- 단축키 설정 (자신의 손에 맞게 자유롭게 변경 가능)

    -- 1. 현재 파일을 하푼 리스트에 추가 (Add)
    vim.keymap.set('n', '<leader>a', function() harpoon:list():add() end, { desc = '[A]dd to Harpoon' })

    -- 2. 하푼 전체 메뉴 열기 (여기서 파일 순서를 바꾸거나 지울 수 있습니다)
    vim.keymap.set('n', '<C-e>', function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = 'Open Harpoon window' })

    -- 3. 1~4번째 파일로 빛의 속도로 점프
    vim.keymap.set('n', '<leader>1', function() harpoon:list():select(1) end, { desc = 'Harpoon to file 1' })
    vim.keymap.set('n', '<leader>2', function() harpoon:list():select(2) end, { desc = 'Harpoon to file 2' })
    vim.keymap.set('n', '<leader>3', function() harpoon:list():select(3) end, { desc = 'Harpoon to file 3' })
    vim.keymap.set('n', '<leader>4', function() harpoon:list():select(4) end, { desc = 'Harpoon to file 4' })
  end,
}
