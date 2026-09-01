# init-lua-picker.nvim

A lightweight Neovim plugin that transforms
[snacks.nvim](https://github.com/folke/snacks.nvim) Treesitter symbol picker
into a high-level, structured outline navigator for your `init.lua`
configuration.

______________________________________________________________________

## 🎯 Purpose

In modular or monolithic Neovim configurations (especially single-file
`init.lua` setups), default Treesitter and LSP symbol pickers can be flooded
with hundreds of granular variables, assignments, and local closures.

`init-lua-picker` filters and transforms raw Treesitter symbols in your
`init.lua` into a clean, hierarchical outline consisting of:

1. **Top-level Sections** (`do ... end` blocks labeled by header comments)
1. **Plugin Setup Blocks** (`require('...').setup`)
1. **Autocommands** (`vim.api.nvim_create_autocmd(...)`)
1. **Custom Matchers** (user-extensible patterns)

For all other buffers (e.g. your project files, Go, C++, Python, Markdown,
etc.), the standard Treesitter symbol picker behavior is completely untouched.

______________________________________________________________________

## 📐 Conventions

To take full advantage of `init-lua-picker`, structure your `init.lua` using
these conventions:

### 1. Section Blocks (`do ... end`)

Enclose logical sections of your configuration inside top-level `do ... end`
blocks preceded by a comment banner or inline comment.

**Banner Headers (Recommended):**

```lua
-- =============================================================================
-- Options
-- =============================================================================
do
  vim.opt.number = true
  vim.opt.relativenumber = true
end

-- -----------------------------------------------------------------------------
-- Keymaps
-- -----------------------------------------------------------------------------
do
  vim.keymap.set('n', '<leader>w', ':update<CR>')
end
```

**Doc Comments or Simple Headers:**

```lua
--- Autocommands
do
  ...
end

-- Packages & Plugins
do
  ...
end
```

**Inline Comments:**

```lua
do -- Misc & Integrations
  require('google')
end
```

**Nested / Recursive Sections (Subsections):**

Sections can be grouped recursively inside parent `do ... end` blocks. Snacks picker displays them with proper tree hierarchy and indentation:

```lua
-- =============================================================================
-- Options
-- =============================================================================
do
  -- ---------------------------------------------------------------------------
  -- UI & Display
  -- ---------------------------------------------------------------------------
  do
    vim.opt.number = true
    vim.opt.relativenumber = true
  end

  -- ---------------------------------------------------------------------------
  -- Indentation
  -- ---------------------------------------------------------------------------
  do
    vim.opt.tabstop = 2
    vim.opt.shiftwidth = 0
  end
end

-- =============================================================================
-- Keymaps
-- =============================================================================
do
  do -- Buffer Navigation
    vim.keymap.set('n', '<leader>w', ':update<CR>')
    vim.keymap.set('n', '<leader>d', ':BufDel<CR>')
  end
end
```

The plugin automatically strips decorative banners (`=`, `-`, `*`, `~`, `#`) and
comment leaders (`--`, `---`) to extract the clean title (e.g., `Options`,
`UI & Display`, `Keymaps`).

### 2. Plugin Setup Calls

Any plugin configuration using the standard `require('...').setup` pattern is
automatically detected and listed under the `Function` category:

```lua
require('conform').setup { ... }
require('diffview').setup { ... }
require('catppuccin').setup { ... }
```

### 3. Autocommand Calls

`vim.api.nvim_create_autocmd` invocations are parsed and listed under the
`Event` category with their event trigger:

```lua
vim.api.nvim_create_autocmd('BufEnter', { ... })
-- Displays as: autocmd('BufEnter')

vim.api.nvim_create_autocmd({ 'VimEnter', 'UIEnter' }, { ... })
-- Displays as: autocmd({ 'VimEnter', 'UIEnter' })
```

______________________________________________________________________

## 🔌 Integration with Snacks.nvim

`init-lua-picker` supports multiple integration workflows depending on how you
prefer to organize your Neovim configuration:

### Method 1: Automatic Hooking (Required *after* Snacks)

Call `require('init-lua-picker').setup()` after `require('snacks').setup(...)`.
It automatically:

- Enables `filter.lua = true` in Snacks treesitter source (required for
  Treesitter to inspect `do ... end` scopes).
- Hooks into `Snacks.config.picker.sources.treesitter.transform`.
- Preserves and chains any existing transform functions you already had
  configured.
- Registers the custom `Snacks.picker.init_lua()` picker and named transform
  `"init_lua"`.

```lua
-- 1. Setup snacks
require('snacks').setup {
  picker = {
    enabled = true,
  },
}

-- 2. Setup init-lua-picker (auto-hooks into Snacks treesitter picker)
require('init-lua-picker').setup()
```

### Method 2: Explicit Transform (Required *before* or during Snacks setup)

If you prefer explicit declarative configuration, pass
`require('init-lua-picker').transform` directly inside `snacks.setup`:

```lua
local init_picker = require('init-lua-picker')

require('snacks').setup {
  picker = {
    enabled = true,
    sources = {
      treesitter = {
        filter = {
          lua = true, -- REQUIRED so treesitter includes scope blocks
        },
        transform = init_picker.transform,
      },
    },
  },
}
```

Or reference the registered named transform string:

```lua
require('init-lua-picker').setup()

require('snacks').setup {
  picker = {
    sources = {
      treesitter = {
        filter = { lua = true },
        transform = "init_lua",
      },
    },
  },
}
```

### Method 3: Combining / Chaining Multiple Transforms

If you have other custom transforms for Treesitter symbols in other contexts,
use `chain` or `wrap` to compose them together:

```lua
local init_picker = require('init-lua-picker')

local function my_custom_transform(item, ctx)
  -- custom symbol transformation logic...
  return item
end

require('snacks').setup {
  picker = {
    sources = {
      treesitter = {
        filter = { lua = true },
        transform = init_picker.chain(
          init_picker.transform,
          my_custom_transform
        ),
      },
    },
  },
}
```

______________________________________________________________________

## ⌨️ Suggested Keymaps

```lua
-- Standard treesitter symbols (transforms when in init.lua, normal everywhere else):
vim.keymap.set('n', '<leader>pt', function() Snacks.picker.treesitter() end, { desc = 'Pick Treesitter symbols' })

-- Dedicated picker to open init.lua outline from ANY buffer:
vim.keymap.set('n', '<leader>pi', function() require('init-lua-picker').open() end, { desc = 'Pick init.lua section' })
-- Or via Snacks:
vim.keymap.set('n', '<leader>pi', function() Snacks.picker.init_lua() end, { desc = 'Pick init.lua section' })
```

______________________________________________________________________

## 📦 Installation

### Neovim 0.12+ `vim.pack.add`

```lua
vim.pack.add {
  'https://github.com/folke/snacks.nvim',
  'https://github.com/Xadeck/init-lua-picker',
}
```

### lazy.nvim

```lua
{
  'Xadeck/init-lua-picker',
  dependencies = { 'folke/snacks.nvim' },
  opts = {},
}
```

______________________________________________________________________

## ⚙️ Configuration Options

Default options:

```lua
require('init-lua-picker').setup {
  -- Target file matching:
  -- nil = auto-detect $MYVIMRC and stdpath('config')/init.lua
  -- Can also be a list of paths/globs or a function(bufnr, filepath): boolean
  files = nil,

  -- Automatically hook into Snacks.config.picker.sources.treesitter
  auto_hook = true,

  -- Register Snacks.picker.init_lua source and helper
  register_source = true,

  -- If false, discards raw AST symbols in init.lua to keep outline clean.
  -- If true, keeps non-matching symbols.
  keep_unmatched = false,

  -- Section header settings (`do ... end` blocks preceded by comments)
  sections = {
    enabled = true,
    recursive = true,           -- Enable nested/recursive section grouping
    max_depth = nil,            -- nil = unlimited depth, or set number (e.g. 1 for top-level only)
    max_header_lookback = 6,    -- Number of lines above `do` to scan for comment headers
    kind = 'Namespace',         -- Symbol kind icon in picker
    default_name = 'Section',   -- Fallback name prefix if no header comment found
  },

  -- Plugin setup call detection (`require('...').setup`)
  plugin_setups = {
    enabled = true,
    kind = 'Function',
  },

  -- Autocommand detection (`nvim_create_autocmd`)
  autocmds = {
    enabled = true,
    kind = 'Event',
  },

  -- Custom matcher functions:
  -- list of fun(item: table, ctx?: table): (table|boolean|nil)
  custom = {},
}
```

### Adding Custom Matchers

You can easily extend `init-lua-picker` with custom patterns:

```lua
require('init-lua-picker').setup {
  custom = {
    -- Match vim.keymap.set calls in init.lua outline
    function(item)
      if item.text and item.text:match('vim%.keymap%.set') then
        local lhs = item.text:match("vim%.keymap%.set%s*%([^,]+,%s*['\"]([^'\"]+)['\"]")
        if lhs then
          item.name = 'keymap: ' .. lhs
          item.text = item.name
          item.kind = 'Key'
          return item
        end
      end
    end,
  },
}
```

______________________________________________________________________

## 🧪 Testing & Presubmits

Run the test suite locally with:

```bash
bash tests/run_tests.sh
```

To automatically run tests before every commit and push, configure Git to use the repo's presubmit hooks:

```bash
git config core.hooksPath .githooks
```

GitHub Actions will also run the test suite on every push and pull request.

______________________________________________________________________

## 📄 License

MIT

