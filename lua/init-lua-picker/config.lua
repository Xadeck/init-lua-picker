local M = {}

---@class InitLuaPickerSectionConfig
---@field enabled? boolean Enable section header detection from `do ... end` blocks
---@field max_header_lookback? number Number of lines above `do` to scan for comment headers
---@field kind? string Symbol kind to assign in picker (default: 'Namespace')
---@field default_name? string Fallback name prefix when no comment header is found

---@class InitLuaPickerSetupConfig
---@field enabled? boolean Enable `require('...').setup` detection
---@field kind? string Symbol kind to assign in picker (default: 'Function')

---@class InitLuaPickerAutocmdConfig
---@field enabled? boolean Enable `nvim_create_autocmd` detection
---@field kind? string Symbol kind to assign in picker (default: 'Event')

---@class InitLuaPickerConfig
---@field files? string[]|(fun(bufnr: number, path: string): boolean) Custom file matcher list or predicate. If nil, auto-detects $MYVIMRC and stdpath('config')/init.lua
---@field auto_hook? boolean Automatically hook into Snacks.config.picker.sources.treesitter during setup() (default: true)
---@field register_source? boolean Register `Snacks.picker.init_lua` source and helper (default: true)
---@field keep_unmatched? boolean Keep other non-matching symbols in target file instead of filtering them out (default: false)
---@field sections? InitLuaPickerSectionConfig Section header options
---@field plugin_setups? InitLuaPickerSetupConfig Plugin setup detection options
---@field autocmds? InitLuaPickerAutocmdConfig Autocommand detection options
---@field custom? (fun(item: table, ctx?: table): (table|boolean|nil))[] List of custom matcher functions

---@type InitLuaPickerConfig
M.defaults = {
  files = nil,
  auto_hook = true,
  register_source = true,
  keep_unmatched = false,
  sections = {
    enabled = true,
    max_header_lookback = 6,
    kind = 'Namespace',
    default_name = 'Section',
  },
  plugin_setups = {
    enabled = true,
    kind = 'Function',
  },
  autocmds = {
    enabled = true,
    kind = 'Event',
  },
  custom = {},
}

---@type InitLuaPickerConfig
M.options = vim.deepcopy(M.defaults)

--- Set active configuration
---@param opts? InitLuaPickerConfig
---@return InitLuaPickerConfig
function M.set(opts)
  M.options = vim.tbl_deep_extend('force', vim.deepcopy(M.defaults), opts or {})
  return M.options
end

--- Get current configuration
---@return InitLuaPickerConfig
function M.get()
  return M.options
end

return M
