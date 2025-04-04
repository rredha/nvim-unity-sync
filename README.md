
# nvim-unity

Neovim integration for Unity C# development.

## 🔧 Plugin Commands (`nvim-unity`)

| Command     | Description                                      |
|-------------|--------------------------------------------------|
| `:Uadd`     | Force add the current `.cs` file to the project. |
| `:Uaddall`  | Re-add all `.cs` files from `Assets/` to the `.csproj`. |
| `:Ustatus`  | Print diagnostics and the current Unity project root. |

## 🔧 Recommended Configuration

We suggest using the following tools and configuration with `nvim-unity`:

### 🧪 Use NvChad

NvChad is a feature-rich Neovim configuration that already comes with:

- [Lazy.nvim](https://github.com/folke/lazy.nvim)
- [Mason.nvim](https://github.com/williamboman/mason.nvim)
- [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

### ⚙️ OmniSharp via Mason

Install OmniSharp with Mason:

```bash
:Mason
# Then install "omnisharp"
```

Configure `lspconfig` for C# with:

```lua
local lspconfig = require("lspconfig")
local nvlsp = require("plugins.configs.lspconfig")

lspconfig.omnisharp.setup {
  on_attach = nvlsp.on_attach,
  capabilities = nvlsp.capabilities,
  cmd = {
    "dotnet",
    vim.fn.stdpath "data" .. "\\mason\\packages\\omnisharp\\libexec\\OmniSharp.dll",
  },
  settings = {
    FormattingOptions = {
      EnableEditorConfigSupport = true,
      OrganizeImports = true,
      NewLine = "\n",
      UseTabs = false,
      TabSize = 4,
      IndentationSize = 4,
      SpacingAfterMethodDeclarationName = false,
      SpaceWithinMethodDeclarationParenthesis = false,
      SpaceBetweenEmptyMethodDeclarationParentheses = false,
      SpaceAfterMethodCallName = false,
      SpaceWithinMethodCallParentheses = false,
      SpaceBetweenEmptyMethodCallParentheses = false,
      SpaceAfterControlFlowStatementKeyword = true,
      SpaceWithinExpressionParentheses = false,
      SpaceWithinCastParentheses = false,
      SpaceWithinOtherParentheses = false,
      SpaceAfterCast = false,
      SpacesIgnoreAroundVariableDeclaration = false,
      SpaceBeforeOpenSquareBracket = false,
      SpaceBetweenEmptySquareBrackets = false,
      SpaceWithinSquareBrackets = false,
      SpaceAfterColonInBaseTypeDeclaration = true,
      SpaceAfterComma = true,
      SpaceAfterDot = false,
      SpaceAfterSemicolonsInForStatement = true,
      SpaceBeforeColonInBaseTypeDeclaration = true,
      SpaceBeforeComma = false,
      SpaceBeforeDot = false,
      SpaceBeforeSemicolonsInForStatement = false,
      SpacingAroundBinaryOperator = "single",
      IndentBraces = false,
      IndentBlock = true,
      IndentSwitchSection = true,
      IndentSwitchCaseSection = true,
      IndentSwitchCaseSectionWhenBlock = true,
      LabelPositioning = "oneLess",
      WrappingPreserveSingleLine = false,
      WrappingKeepStatementsOnSingleLine = false,
      NewLinesForBracesInTypes = true,
      NewLinesForBracesInMethods = true,
      NewLinesForBracesInProperties = true,
      NewLinesForBracesInAccessors = true,
      NewLinesForBracesInAnonymousMethods = true,
      NewLinesForBracesInControlBlocks = true,
      NewLinesForBracesInAnonymousTypes = true,
      NewLinesForBracesInObjectCollectionArrayInitializers = true,
      NewLinesForBracesInLambdaExpressionBody = true,
      NewLineForElse = true,
      NewLineForCatch = true,
      NewLineForFinally = true,
      NewLineForMembersInObjectInit = true,
      NewLineForMembersInAnonymousTypes = true,
      NewLineForClausesInQuery = true,
    },
    Sdk = {
      IncludePrereleases = true,
    },
  },
}
```

### 🧩 Treesitter

Ensure `c_sharp` is added in your `treesitter` config:

```lua
require("nvim-treesitter.configs").setup {
  ensure_installed = {
    "lua",
    "c_sharp", -- Required for C# syntax highlighting and folding
  },
  highlight = { enable = true },
}
```

### 📦 Folding with `nvim-ufo`

Install and configure `nvim-ufo` and `statuscol`:

```lua
{
  "kevinhwang91/nvim-ufo",
  event = "BufRead",
  dependencies = {
    { "kevinhwang91/promise-async" },
    {
      "luukvbaal/statuscol.nvim",
      config = function()
        local builtin = require "statuscol.builtin"
        require("statuscol").setup {
          relculright = true,
          segments = {
            { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
            { text = { "%s" }, click = "v:lua.ScSa" },
            { text = { builtin.lnumfunc, " " }, click = "v:lua.ScLa" },
          },
          provider_selector = function(bufnr, filetype, buftype)
            return { "lsp", "indent" }
          end,
        }
      end,
    },
  },
  config = function()
    vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
    vim.o.foldcolumn = "1"
    vim.o.foldlevel = 99
    vim.o.foldlevelstart = 99
    vim.o.foldenable = true

    require("ufo").setup()
  end,
}
```

## 🪄 Nice Tips

| Feature / Shortcut           | Description                                            |
|------------------------------|--------------------------------------------------------|
| `<leader>ch`                 | Toggle **NvCheatsheet** with all keymaps.             |
| `<leader>ff`, `fb`, etc      | **Telescope** for files, buffers, etc.                |
| `gd`, `gD`, `<C-LeftClick>`  | Go to definition/declaration.                         |
| `K`                          | Show signature help.                                  |
| `<leader>ca`                 | Show code actions.                                    |
| `:Mason`                     | Open Mason UI.                                        |
| `:Lazy`                      | Manage plugins with Lazy.                             |
| `:Uadd`, `:Uaddall`, `:Ustatus` | Use `nvim-unity` plugin commands.                  |

## ⚠️ Important Note

**Do not** configure a formatter (e.g. `conform.nvim`) for `.cs` files — OmniSharp already provides formatting. Adding another formatter may break LSP functionality.
