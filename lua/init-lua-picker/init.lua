local config = require('init-lua-picker.config')

local M = {}

--- Check if the given buffer or filepath is a target file (e.g. init.lua / $MYVIMRC)
---@param bufnr? number
---@param filepath? string
---@return boolean
function M.is_target_file(bufnr, filepath)
  local cfg = config.get()

  local path = filepath
  if (not path or path == '') and bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    path = vim.api.nvim_buf_get_name(bufnr)
  end
  path = path or ''

  if path == '' then
    return false
  end

  -- If a custom predicate or pattern list is configured
  if type(cfg.files) == 'function' then
    return cfg.files(bufnr or 0, path)
  elseif type(cfg.files) == 'table' then
    local real_path = vim.uv.fs_realpath(path) or path
    for _, pattern in ipairs(cfg.files) do
      if type(pattern) == 'string' then
        local exp_pattern = vim.fn.expand(pattern)
        local real_pattern = vim.uv.fs_realpath(exp_pattern) or exp_pattern
        if real_path == real_pattern or path == pattern or path:match(pattern) then
          return true
        end
      end
    end
    return false
  end

  -- Default auto-detection: $MYVIMRC or standard config/init.lua
  local real_path = vim.uv.fs_realpath(path) or path

  -- Check $MYVIMRC
  if vim.env.MYVIMRC then
    local myvimrc_real = vim.uv.fs_realpath(vim.env.MYVIMRC) or vim.env.MYVIMRC
    if myvimrc_real == real_path or vim.env.MYVIMRC == path then
      return true
    end
  end

  -- Check stdpath('config')/init.lua
  local std_init = vim.fs.joinpath(vim.fn.stdpath('config'), 'init.lua')
  local std_init_real = vim.uv.fs_realpath(std_init) or std_init
  if std_init_real == real_path or path == std_init then
    return true
  end

  -- Normalized path fallback (e.g. for virtual or newly opened buffers)
  local norm_path = vim.fs.normalize(path)
  if norm_path:match('/nvim/init%.lua$') or norm_path:match('/%.config/nvim/init%.lua$') then
    return true
  end

  return false
end

--- Clean a line of comment delimiters and banner decorations
---@param line string
---@return string
local function clean_comment_line(line)
  local clean = vim.trim(line)
  -- Remove leading do with inline comment
  clean = clean:gsub('^do%s*%-%-%s*', '')
  -- Remove lua comment leaders (e.g. --- or --)
  clean = clean:gsub('^%-%-%-+%s*', ''):gsub('^%-%-%s*', '')
  -- Remove leading banner characters (e.g. ================= or ----------------)
  clean = clean:gsub('^[=%-%*~#]+%s*', '')
  -- Remove trailing banner characters and comments
  clean = clean:gsub('%s*[=%-%*~#]+%s*$', '')
  clean = vim.trim(clean)
  return clean
end

--- Extract section title from preceding comments or inline comment
---@param bufnr number
---@param lnum number 1-indexed line number of `do`
---@return string
function M.extract_section_name(bufnr, lnum)
  local cfg = config.get().sections or {}
  local max_lookback = cfg.max_header_lookback or 6
  local default_name = cfg.default_name or 'Section'

  -- Check inline comment on the exact `do` line first
  local do_lines = vim.api.nvim_buf_get_lines(bufnr, math.max(0, lnum - 1), lnum, false)
  local do_line = do_lines[1] or ''
  local inline_comment = do_line:match('^%s*do%s*%-%-%s*(.+)$')
  if inline_comment then
    local clean = clean_comment_line(inline_comment)
    if clean ~= '' and not clean:match('^do$') and not clean:match('^[=%-%*~#]+$') then
      return clean
    end
  end

  -- Scan preceding lines upwards
  local start_line = math.max(0, lnum - (max_lookback + 1))
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, math.max(0, lnum - 1), false)

  for i = #lines, 1, -1 do
    local raw_line = lines[i]
    local trimmed = vim.trim(raw_line)
    -- Stop if we hit non-comment code or blank separator beyond header
    if trimmed ~= '' and trimmed:match('^%-%-') then
      local clean = clean_comment_line(raw_line)
      if clean ~= '' and not clean:match('^[=%-%*~#]+$') and not clean:match('^do$') then
        return clean
      end
    end
  end

  return string.format('%s (line %d)', default_name, lnum)
end

--- The Snacks picker transform function
---@param item table snacks.picker.finder.Item
---@param ctx? table snacks.picker.finder.ctx
---@return table|boolean|nil
function M.transform(item, ctx)
  if not item then
    return item
  end

  local path = item.file or (item.buf and vim.api.nvim_buf_is_valid(item.buf) and vim.api.nvim_buf_get_name(item.buf)) or ''

  -- Only transform target files (e.g. init.lua)
  if not M.is_target_file(item.buf, path) then
    return item
  end

  local cfg = config.get()

  -- 1. Top-level section (do ... end blocks)
  if cfg.sections and cfg.sections.enabled ~= false then
    if item.depth == 1 and item.ts_kind == 'scope' and item.text and item.text:match('^%s*do%f[%s%z]') then
      local lnum = item.pos and item.pos[1] or 1
      local name = M.extract_section_name(item.buf, lnum)
      item.name = name
      item.text = name
      item.kind = cfg.sections.kind or 'Namespace'
      return item
    end
  end

  -- 2. Plugin setup calls: require('...').setup or require "...".setup
  if cfg.plugin_setups and cfg.plugin_setups.enabled ~= false then
    if item.kind == 'Function' and item.text then
      local setup_match = item.text:match('^%s*(require%b().setup)')
        or item.text:match('^%s*(require%s*["\'][%w%._%-]+["\']%s*%.%s*setup)')
      if setup_match then
        item.name = setup_match
        item.text = item.name
        item.kind = cfg.plugin_setups.kind or 'Function'
        return item
      end
    end
  end

  -- 3. Autocommand calls: vim.api.nvim_create_autocmd
  if cfg.autocmds and cfg.autocmds.enabled ~= false then
    if item.kind == 'Function' and item.text and item.text:match('nvim_create_autocmd') then
      local arg = item.text:match('nvim_create_autocmd%s*%(%s*(%b{})%s*,')
        or item.text:match('nvim_create_autocmd%s*%(%s*(%b\'\')%s*,')
        or item.text:match('nvim_create_autocmd%s*%(%s*(%b"")%s*,')
      if arg then
        arg = vim.trim(arg:gsub('%s+', ' '))
        item.name = 'autocmd(' .. arg .. ')'
        item.text = item.name
        item.kind = cfg.autocmds.kind or 'Event'
        return item
      end
    end
  end

  -- 4. Custom user matchers
  if cfg.custom and #cfg.custom > 0 then
    for _, matcher in ipairs(cfg.custom) do
      local res = matcher(item, ctx)
      if res ~= nil then
        return res
      end
    end
  end

  -- If keep_unmatched is true, retain raw symbol; otherwise filter it out for clean outline
  if cfg.keep_unmatched then
    return item
  end

  return false
end

--- Dedicated finder for init.lua outline
--- Extracts treesitter symbols directly from the target init.lua buffer regardless of current window/buffer
---@param opts? table
---@param ctx? table
---@return table[]
function M.finder(opts, ctx)
  opts = opts or {}
  local target_path = opts.file
  if not target_path or target_path == '' then
    target_path = vim.env.MYVIMRC or vim.fs.joinpath(vim.fn.stdpath('config'), 'init.lua')
  end
  target_path = vim.fn.expand(target_path)
  local real_path = vim.uv.fs_realpath(target_path) or target_path

  if not vim.uv.fs_stat(real_path) then
    vim.notify('init-lua-picker: file not found: ' .. real_path, vim.log.levels.ERROR)
    return {}
  end

  local buf = vim.fn.bufadd(real_path)
  vim.fn.bufload(buf)
  vim.bo[buf].filetype = 'lua'

  local ts_source = require('snacks.picker.source.treesitter')
  local fake_ctx = {
    filter = {
      current_buf = buf,
    },
  }
  local ts_opts = {
    filter = { lua = true },
    tree = opts.tree ~= false,
  }

  local raw_items = ts_source.symbols(ts_opts, fake_ctx)
  local items = {}
  for _, item in ipairs(raw_items) do
    item.file = real_path
    item.buf = buf
    table.insert(items, item)
  end
  return items
end

--- Chain multiple Snacks picker transform functions together
---@param ... (fun(item: table, ctx?: table): (table|boolean|nil))|string
---@return fun(item: table, ctx?: table): (table|boolean|nil)
function M.chain(...)
  local args = { ... }
  local fns = {}

  for _, t in ipairs(args) do
    if type(t) == 'function' then
      table.insert(fns, t)
    elseif type(t) == 'string' then
      local ok, tr = pcall(function()
        return require('snacks.picker.transform')[t]
      end)
      if ok and type(tr) == 'function' then
        table.insert(fns, tr)
      end
    end
  end

  return function(item, ctx)
    for _, fn in ipairs(fns) do
      local res = fn(item, ctx)
      if res == false then
        return false
      elseif res ~= nil and res ~= true then
        item = res
      end
    end
    return item
  end
end

--- Convenience wrapper to chain an existing transform with init-lua-picker's transform
---@param other_transform? (fun(item: table, ctx?: table): (table|boolean|nil))|string
---@return fun(item: table, ctx?: table): (table|boolean|nil)
function M.wrap(other_transform)
  if not other_transform then
    return M.transform
  end
  return M.chain(M.transform, other_transform)
end

--- Hook this transform automatically into Snacks picker configuration
function M.hook_snacks()
  -- If Snacks global is not yet initialized, attempt to require it
  if not _G.Snacks then
    pcall(require, 'snacks')
  end

  if _G.Snacks and _G.Snacks.config then
    local picker_cfg = _G.Snacks.config.picker or {}
    picker_cfg.sources = picker_cfg.sources or {}
    picker_cfg.sources.treesitter = picker_cfg.sources.treesitter or {}

    local ts = picker_cfg.sources.treesitter
    ts.filter = ts.filter or {}
    -- Ensure lua = true is enabled so Treesitter passes do...end scopes to transform
    if ts.filter.lua == nil then
      ts.filter.lua = true
    end

    -- Hook or chain transform
    local existing = ts.transform
    if existing and existing ~= M.transform then
      ts.transform = M.chain(M.transform, existing)
    else
      ts.transform = M.transform
    end
  end
end

--- Register Snacks custom source and named transform
local function register_snacks_extensions()
  -- Register named transform so `transform = "init_lua"` works in Snacks
  pcall(function()
    local snacks_transform = require('snacks.picker.transform')
    snacks_transform.init_lua = M.transform
  end)

  -- Register source `init_lua` so `Snacks.picker.init_lua()` works out-of-the-box
  local cfg = config.get()
  if cfg.register_source then
    pcall(function()
      local sources = require('snacks.picker.config.sources')
      sources.init_lua = {
        finder = function(opts, ctx)
          return M.finder(opts, ctx)
        end,
        format = 'lsp_symbol',
        tree = true,
        transform = M.transform,
      }
    end)
  end
end

--- Open the init.lua outline picker from anywhere
---@param opts? table Additional options to pass to Snacks.picker
function M.open(opts)
  opts = opts or {}

  register_snacks_extensions()

  if _G.Snacks and _G.Snacks.picker then
    return _G.Snacks.picker.pick('init_lua', opts)
  else
    local ok, snacks = pcall(require, 'snacks')
    if ok and snacks.picker then
      return snacks.picker.pick('init_lua', opts)
    else
      vim.notify('init-lua-picker: snacks.nvim picker is not available', vim.log.levels.ERROR)
    end
  end
end

--- Initialize init-lua-picker
---@param opts? InitLuaPickerConfig
function M.setup(opts)
  local cfg = config.set(opts)

  register_snacks_extensions()

  if cfg.auto_hook then
    M.hook_snacks()
  end
end

return M
