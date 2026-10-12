return {
  'xeluxee/competitest.nvim',
  dependencies = { 'MunifTanjim/nui.nvim' },
  config = function()
    require('competitest').setup {
      -- 컴파일 명령어 (작성하셨던 C++23 기준 반영)
      compile_command = {
        cpp = { exec = require('custom.cxx').compiler(), args = { '-std=c++23', '-Wall', '-O2', '$(FNAME)', '-o', '$(FNOEXT)' } },
        java = { exec = 'javac', args = { '$(FNAME)' } },
      },
      -- 실행 명령어
      run_command = {
        cpp = { exec = './$(FNOEXT)' },
        java = { exec = 'java', args = { '$(FNOEXT)' } },
        python = { exec = 'python3', args = { '$(FNAME)' } },
      },
      -- 테스트케이스 파일을 한 폴더에 모아 저장
      testcases_directory = 'testcases',
      testcases_use_single_file = false,
      testcases_input_file_format = '$(FNOEXT)_input$(TCNUM).txt',
      testcases_output_file_format = '$(FNOEXT)_output$(TCNUM).txt',
      -- 창 분할 방식 (수평/수직 분할 비율 등 조절 가능)
      split_ui = {
        position = 'right',
        relative_to_editor = true,
        total_width = 0.3,
        vertical_layout = {
          display_mode = 'split',
          set_relative_numbers = false,
        },
      },
    }
  end,
  -- 기존 단축키(<F5>)를 덮어쓰거나 새로운 단축키 할당
  keys = {
    { '<F5>', '<cmd>CompetiTest run<CR>', desc = 'CP: 모든 테스트케이스 실행' },
    { '<F6>', '<cmd>CompetiTest add_testcase<CR>', desc = 'CP: 새 테스트케이스(입력값) 추가' },
    { '<F7>', '<cmd>CompetiTest edit_testcase<CR>', desc = 'CP: 테스트케이스 수정' },
    { '<F8>', '<cmd>CompetiTest receive testcases<CR>', desc = 'CP: 테스트케이스 결과 확인' },
  },
}
