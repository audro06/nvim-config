-- 언어별 플러그인 파일에서 필요한 Mason 패키지를 각자 설치하기 위한 헬퍼
-- (init.lua의 mason-tool-installer 목록을 건드리지 않기 위해 분리)
local M = {}

---@param names string[] Mason 패키지 이름 목록
function M.ensure_installed(names)
  local registry = require 'mason-registry'
  registry.refresh(function()
    for _, name in ipairs(names) do
      local ok, pkg = pcall(registry.get_package, name)
      if ok and not pkg:is_installed() and not pkg:is_installing() then
        vim.notify('Mason: ' .. name .. ' 설치 중...', vim.log.levels.INFO)
        pkg:install()
      end
    end
  end)
end

-- Mason 패키지 설치 경로
---@param name string
---@return string
function M.package_path(name) return vim.fn.stdpath 'data' .. '/mason/packages/' .. name end

return M
