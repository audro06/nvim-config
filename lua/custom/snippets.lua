-- 개인 스니펫 (init.lua 맨 끝에서 require)
local ls = require 'luasnip'
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local rep = require('luasnip.extras').rep

-- 끝내지 않은 스니펫에서 커서가 벗어나면 스니펫을 끝낸다.
-- 기본값(꺼짐)이면 스니펫이 계속 살아 있어서, 다른 줄에서 Tab을 누를 때
-- 들여쓰기 대신 예전 스니펫 위치로 커서가 날아간다 (blink super-tab).
ls.setup {
  region_check_events = 'CursorMoved,CursorMovedI',
  delete_check_events = 'TextChanged',
}

-- C++ 전용 스니펫
ls.add_snippets('cpp', {
  -- 'cp'라고 입력하고 자동완성하면 아래 코드가 전개됩니다.
  s('cp', {
    t {
      '#include <bits/stdc++.h>',
      '',
      'using namespace std;',
      '',
      'int main() {',
      '    cin.tie(nullptr)->sync_with_stdio(false);',
      '',
      '    ',
    },
    -- i(1)은 코드가 전개된 후 커서가 처음 위치할 곳입니다.
    i(1),
    t {
      '',
      '    return 0;',
      '}',
    },
  }),
  s('hw', {
    t {
      '#include <iostream>',
      '',
      'using std::cin;',
      'using std::cout;',
      '',
      'int main() {',
      '    cin.tie(nullptr)->sync_with_stdio(false);',
      '    ',
    },
    i(1),
    t { '', '    return 0;', '}' },
  }),
  s('fori', {
    t 'for (int ',
    i(1, 'i'),
    t ' = 0; ',
    rep(1),
    t ' < ',
    i(2, 'n'),
    t '; ++',
    rep(1),
    t ') {',
    t { '', '    ' },
    i(0),
    t { '', '}' },
  }),
})
