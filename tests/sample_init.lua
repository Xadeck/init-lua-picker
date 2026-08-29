-- =============================================================================
-- General Options
-- =============================================================================
do
  vim.opt.number = true
  vim.opt.relativenumber = true
  vim.opt.wrap = false
  local dummy_local_variable = 42
end

-- =============================================================================
-- Packages & Plugins
-- =============================================================================
do
  require('diffview').setup {
    enhanced_diff_hl = true,
  }

  require('conform').setup {
    formatters_by_ft = { lua = { 'stylua' } },
  }

  require('snacks').setup {
    picker = { enabled = true },
  }
end

-- -----------------------------------------------------------------------------
-- Keymaps
-- -----------------------------------------------------------------------------
do
  vim.keymap.set('n', '<leader>w', ':w<CR>')
  vim.keymap.set('n', '<leader>q', ':q<CR>')
end

--- Documentation & Help
do
  vim.keymap.set('n', '<leader>h', vim.cmd.help)
end

do -- Autocommands
  vim.api.nvim_create_autocmd('BufEnter', {
    pattern = '*',
    callback = function() end,
  })

  vim.api.nvim_create_autocmd({ 'VimEnter', 'UIEnter' }, {
    callback = function() end,
  })
end
