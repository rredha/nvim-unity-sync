
# nvim-unity

A Neovim plugin to automatically keep your `.csproj` files updated when working on Unity projects.  
It detects file creations, deletions, renames, and updates `<Compile Include="..."/>` tags accordingly.

---

## 📦 Installation (with Lazy.nvim)

Add this plugin in your `lazy.nvim` configuration:

```lua
{
  "apyra/nvim-unity",
  lazy = false,
  config = function()
    require("nvim-unity.plugin")
  end,
}
```

> Note: This plugin is designed to be placed in `lua/nvim-unity/`

---

## 🛠️ Commands

| Command     | Description                                                              |
|-------------|--------------------------------------------------------------------------|
| `:Uadd`     | Manually add the current `.cs` file to the corresponding `.csproj`       |
| `:Uaddall`  | Reset and re-add all `.cs` files from `Assets/` folder                   |
| `:Ustatus`  | Show status of the current project, LSP status, and Unity project root   |

---

## 🚀 Features

- Automatically adds or removes `<Compile Include="..."/>` tags when `.cs` files are created or deleted
- Detects folder renames and file renames
- Handles file changes by both `nvim-tree` and LSP (`Omnisharp`)
- Notifies when the LSP is attached to the project

---

## 🔧 Recommended Configuration

### 🧠 Use NvChad

We recommend using **NvChad**, which comes bundled with:
- **Lazy.nvim**
- **Mason.nvim**
- **Telescope**
- Beautiful UI and modular configuration

### 🧩 LSP Setup (Omnisharp via Mason)

Install Omnisharp using Mason:

```
:MasonInstall omnisharp
```

LSP Configuration (example for `lspconfig.lua`):

```lua
local lspconfig = require("lspconfig")
local nvlsp = require("nvchad.configs.lspconfig") -- or your own on_attach/capabilities

lspconfig.omnisharp.setup {
  on_attach = nvlsp.on_attach,
  capabilities = nvlsp.capabilities,
  cmd = {
    "dotnet",
    vim.fn.stdpath("data") .. "\mason\packages\omnisharp\libexec\OmniSharp.dll",
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

### 🌳 Treesitter

Ensure the following parser is installed in `nvim-treesitter`:

```lua
ensure_installed = {
  "c_sharp",
}
```

### 🪄 Folding (with `nvim-ufo`)

Recommended plugin for code folding:

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
          provider_selector = function(_, _, _)
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

---

## 💡 Nice Tips

- `NvCheatsheet` (toggle keybindings menu): `<leader>ch`
- LSP:
  - Signature help: `K`
  - Code actions: `<leader>ca`
  - Go to definition: `<C-LeftMouse>` or `gd`
- Open project in Unity with `:!start Unity` or similar shell commands

---

### ⚠️ Important Note

**Do not install an external formatter (like `conform.nvim`)** for C# files.  
Omnisharp **already includes its own formatter**, and installing a separate one may break LSP formatting and cause unexpected behavior.

---
