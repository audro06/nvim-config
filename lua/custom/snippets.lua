-- 개인 스니펫 (init.lua 맨 끝에서 require)
local ls = require 'luasnip'
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local rep = require('luasnip.extras').rep

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
      '    ios_base::sync_with_stdio(false);',
      '    cin.tie(NULL);',
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
