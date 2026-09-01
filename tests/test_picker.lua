-- Standalone Unit Test Suite for init-lua-picker.nvim
-- Run with: nvim --headless -u NONE -c "luafile tests/test_picker.lua" -c "q"

local script_dir = vim.fs.dirname(debug.getinfo(1, 'S').source:sub(2))
local root_dir = vim.uv.fs_realpath(vim.fs.dirname(script_dir)) or vim.fs.dirname(script_dir)
package.path = root_dir .. '/lua/?.lua;' .. root_dir .. '/lua/?/init.lua;' .. package.path
vim.opt.rtp:append(root_dir)

-- Ensure snacks.nvim is in runtimepath even when running with `nvim -u NONE`
local data_dir = vim.fn.stdpath('data')
local potential_snacks_paths = {
  root_dir .. '/.deps/snacks.nvim',
  data_dir .. '/lazy/snacks.nvim',
  data_dir .. '/site/pack/core/opt/snacks.nvim',
  vim.fn.expand('~/.local/share/nvim/lazy/snacks.nvim'),
  vim.fn.expand('~/.local/share/nvim/site/pack/core/opt/snacks.nvim'),
}
for _, p in ipairs(potential_snacks_paths) do
  if vim.uv.fs_stat(p) then
    vim.opt.rtp:append(p)
  end
end

-- Initialize snacks
local ok_snacks, snacks = pcall(require, 'snacks')
if ok_snacks and snacks.setup then
  snacks.setup {
    picker = { enabled = true },
  }
end

local picker = require('init-lua-picker')

local total_tests = 0
local passed_tests = 0
local failed_tests = 0

local function test(name, fn)
  total_tests = total_tests + 1
  io.write(string.format('  Testing: %-55s ... ', name))
  local ok, err = pcall(fn)
  if ok then
    passed_tests = passed_tests + 1
    io.write('\27[32m✓ PASS\27[0m\n')
  else
    failed_tests = failed_tests + 1
    io.write('\27[31m✗ FAIL\27[0m\n')
    io.write('    Error: ' .. tostring(err) .. '\n')
  end
end

local function assert_eq(actual, expected, msg)
  if actual ~= expected then
    error(string.format('%s: expected %s, got %s', msg or 'Assertion failed', vim.inspect(expected), vim.inspect(actual)))
  end
end

local function create_test_buffer(filepath, lines)
  local buf = vim.fn.bufadd(filepath)
  vim.fn.bufload(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'lua'
  vim.api.nvim_set_current_buf(buf)
  return buf
end

print('\n==================================================')
print('        init-lua-picker.nvim Unit Tests           ')
print('==================================================\n')

-- -----------------------------------------------------------------------------
-- 1. Test Module Loading & Aliasing
-- -----------------------------------------------------------------------------
test('Module exports required APIs', function()
  assert_eq(type(picker.setup), 'function', 'setup should be a function')
  assert_eq(type(picker.transform), 'function', 'transform should be a function')
  assert_eq(type(picker.chain), 'function', 'chain should be a function')
  assert_eq(type(picker.wrap), 'function', 'wrap should be a function')
  assert_eq(type(picker.open), 'function', 'open should be a function')
  assert_eq(type(picker.is_target_file), 'function', 'is_target_file should be a function')
end)

test('Alias module require("init_lua_picker") works', function()
  local alias = require('init_lua_picker')
  assert_eq(alias, picker, 'Alias must match init-lua-picker')
end)

-- -----------------------------------------------------------------------------
-- 2. Test Real Treesitter Symbol Extraction on Sample Config
-- -----------------------------------------------------------------------------
test('Transforms sample init.lua into clean structural outline', function()
  local sample_path = vim.fs.joinpath(root_dir, 'tests', 'sample_init.lua')
  local lines = vim.fn.readfile(sample_path)
  local buf = create_test_buffer(sample_path, lines)

  -- Configure init-lua-picker to target this sample buffer
  picker.setup {
    files = { sample_path },
  }

  local ts_source = require('snacks.picker.source.treesitter')
  local raw_items = ts_source.symbols({ filter = { lua = true } }, { filter = { current_buf = buf } })

  -- Filter & transform items
  local transformed = {}
  for _, item in ipairs(raw_items) do
    local res = picker.transform(item)
    if res ~= false then
      table.insert(transformed, {
        kind = res.kind,
        name = res.name,
        line = res.pos[1],
      })
    end
  end

  -- Expected outline structure
  local expected = {
    { kind = 'Namespace', name = 'General Options', line = 4 },
    { kind = 'Namespace', name = 'Packages & Plugins', line = 14 },
    { kind = 'Function', name = "require('diffview').setup", line = 15 },
    { kind = 'Function', name = "require('conform').setup", line = 19 },
    { kind = 'Function', name = "require('snacks').setup", line = 23 },
    { kind = 'Namespace', name = 'Keymaps', line = 31 },
    { kind = 'Namespace', name = 'Documentation & Help', line = 37 },
    { kind = 'Namespace', name = 'Autocommands', line = 41 },
    { kind = 'Event', name = "autocmd('BufEnter')", line = 42 },
    { kind = 'Event', name = "autocmd({ 'VimEnter', 'UIEnter' })", line = 47 },
  }

  assert_eq(#transformed, #expected, 'Transformed item count')

  for i, exp in ipairs(expected) do
    assert_eq(transformed[i].kind, exp.kind, string.format('Item %d kind', i))
    assert_eq(transformed[i].name, exp.name, string.format('Item %d name', i))
    assert_eq(transformed[i].line, exp.line, string.format('Item %d line', i))
  end
end)

-- -----------------------------------------------------------------------------
-- 3. Test Visual Representation Rendering
-- -----------------------------------------------------------------------------
test('Simulate visual picker rendering snapshot', function()
  local sample_path = vim.fs.joinpath(root_dir, 'tests', 'sample_init.lua')
  local lines = vim.fn.readfile(sample_path)
  local buf = create_test_buffer(sample_path, lines)

  picker.setup { files = { sample_path } }

  local ts_source = require('snacks.picker.source.treesitter')
  local raw_items = ts_source.symbols({ filter = { lua = true } }, { filter = { current_buf = buf } })

  local lines_rendered = {}
  for _, item in ipairs(raw_items) do
    local res = picker.transform(item)
    if res ~= false then
      local indent = (res.kind == 'Function' or res.kind == 'Event') and '  ' or ''
      local line_str = string.format('%s%-12s %-38s (line %2d)', indent, '[' .. res.kind .. ']', res.name, res.pos[1])
      table.insert(lines_rendered, line_str)
    end
  end

  assert_eq(#lines_rendered, 10, 'Rendered picker should contain exactly 10 items')
end)

-- -----------------------------------------------------------------------------
-- 4. Test Non-Target Files Passthrough
-- -----------------------------------------------------------------------------
test('Leaves non-target files unmodified', function()
  local other_path = '/home/user/project/some_other_file.lua'
  local buf = create_test_buffer(other_path, {
    'local function helper() end',
    'local x = 100',
    'local function worker() end',
  })

  local ts_source = require('snacks.picker.source.treesitter')
  local raw_items = ts_source.symbols({ filter = { lua = true } }, { filter = { current_buf = buf } })

  local transformed = {}
  for _, item in ipairs(raw_items) do
    local res = picker.transform(item)
    if res ~= false then
      table.insert(transformed, res)
    end
  end

  assert_eq(#transformed, #raw_items, 'All items in non-target files must be preserved')
end)

-- -----------------------------------------------------------------------------
-- 5. Test Chaining and Custom Matchers
-- -----------------------------------------------------------------------------
test('Allows custom matchers and chaining', function()
  local custom_called = false
  local custom_transform = function(item)
    if item.name == 'Keymaps' then
      item.name = 'Keymaps (Customized)'
      custom_called = true
    end
    return item
  end

  local chained = picker.chain(picker.transform, custom_transform)

  local dummy_item = {
    buf = 1,
    depth = 1,
    ts_kind = 'scope',
    text = 'do',
    pos = { 30, 0 },
  }

  -- Mock target detection and extract
  local orig_is_target = picker.is_target_file
  picker.is_target_file = function() return true end
  local orig_extract = picker.extract_section_name
  picker.extract_section_name = function() return 'Keymaps' end

  local res = chained(dummy_item)
  assert_eq(res.name, 'Keymaps (Customized)', 'Chained transform should modify item')
  assert_eq(custom_called, true, 'Custom transform function was called')

  -- Restore
  picker.is_target_file = orig_is_target
  picker.extract_section_name = orig_extract
end)

-- -----------------------------------------------------------------------------
-- 6. Test Auto-Hooking into Snacks Configuration
-- -----------------------------------------------------------------------------
test('Auto-hooks into Snacks.config and registers custom source', function()
  picker.setup {
    auto_hook = true,
    register_source = true,
  }

  assert_eq(type(Snacks.config.picker.sources.treesitter.transform), 'function', 'Snacks treesitter transform hooked')
  assert_eq(Snacks.config.picker.sources.treesitter.filter.lua, true, 'Filter lua enabled')
  assert_eq(type(require('snacks.picker.transform').init_lua), 'function', 'Named transform init_lua registered')
  assert_eq(type(require('snacks.picker.config.sources').init_lua), 'table', 'Snacks picker init_lua source registered')
end)

-- -----------------------------------------------------------------------------
-- 7. Test Finding init.lua outline from an unrelated buffer
-- -----------------------------------------------------------------------------
test('Snacks.picker.init_lua extracts outline when inside an unrelated buffer', function()
  local sample_path = vim.fs.joinpath(root_dir, 'tests', 'sample_init.lua')
  local unrelated_buf = create_test_buffer('/some/random/unrelated_file.md', {
    '# Unrelated Markdown File',
    'Some random text',
  })
  vim.api.nvim_set_current_buf(unrelated_buf)

  picker.setup {
    files = { sample_path },
  }

  -- Use M.finder targeting sample_path
  local items = picker.finder({ file = sample_path })
  assert_eq(#items > 0, true, 'Raw items found in target file')

  local transformed = {}
  for _, it in ipairs(items) do
    local res = picker.transform(it)
    if res ~= false then
      table.insert(transformed, res)
    end
  end

  assert_eq(#transformed, 10, 'Expected 10 transformed items from sample_init.lua')
  assert_eq(transformed[1].name, 'General Options', 'First item name')
  assert_eq(transformed[1].file, sample_path, 'File path matches sample_init.lua')
end)

-- -----------------------------------------------------------------------------
-- 8. Test Recursive / Nested Section Detection
-- -----------------------------------------------------------------------------
test('Recursively extracts nested do ... end sections with proper depth', function()
  local nested_path = '/home/user/test_nested_init.lua'
  local buf = create_test_buffer(nested_path, {
    '-- =============================================================================',
    '-- Options',
    '-- =============================================================================',
    'do',
    '  -- ---------------------------------------------------------------------------',
    '  -- UI & Display',
    '  -- ---------------------------------------------------------------------------',
    '  do',
    '    vim.opt.number = true',
    '  end',
    '',
    '  -- ---------------------------------------------------------------------------',
    '  -- Indentation',
    '  -- ---------------------------------------------------------------------------',
    '  do',
    '    vim.opt.tabstop = 2',
    '  end',
    'end',
    '',
    '-- Keymaps',
    'do',
    '  do -- Buffer Navigation',
    '    vim.keymap.set("n", "<leader>w", ":w<cr>")',
    '  end',
    'end',
  })

  picker.setup {
    files = { nested_path },
    sections = { recursive = true },
  }

  local items = picker.finder({ file = nested_path })
  local transformed = {}
  for _, it in ipairs(items) do
    local res = picker.transform(it)
    if res ~= false then
      table.insert(transformed, {
        name = res.name,
        kind = res.kind,
        depth = res.depth,
        line = res.pos[1],
      })
    end
  end

  local expected_nested = {
    { name = 'Options', depth = 1, line = 4 },
    { name = 'UI & Display', depth = 2, line = 8 },
    { name = 'Indentation', depth = 2, line = 15 },
    { name = 'Keymaps', depth = 1, line = 21 },
    { name = 'Buffer Navigation', depth = 2, line = 22 },
  }

  assert_eq(#transformed, #expected_nested, 'Nested item count')
  for i, exp in ipairs(expected_nested) do
    assert_eq(transformed[i].name, exp.name, string.format('Nested item %d name', i))
    assert_eq(transformed[i].depth, exp.depth, string.format('Nested item %d depth', i))
    assert_eq(transformed[i].line, exp.line, string.format('Nested item %d line', i))
  end
end)

print('\n==================================================')
print(string.format('Tests run: %d | Passed: %d | Failed: %d', total_tests, passed_tests, failed_tests))
print('==================================================\n')

if failed_tests > 0 then
  vim.cmd('cquit 1')
else
  vim.cmd('qall!')
end
