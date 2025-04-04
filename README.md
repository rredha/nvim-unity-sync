# NvimUnity

**NvimUnity** is a lightweight Neovim plugin designed to enhance Unity development inside Neovim. It automatically manages `.csproj` files based on file events, helping you avoid the need to manually regenerate project files in Unity.

> 🧩 Now includes integration with the [nvim-unity-editor](https://github.com/apyra/nvim-unity-editor) Unity package – enabling seamless communication between Unity and Neovim!

---

## ✨ Features

- Automatically adds or removes `<Compile>` tags from `.csproj` files when `.cs` files are created, deleted, or renamed.
- Detects Unity project root based on `Assembly-CSharp.csproj`.
- Hooks into `nvim-tree` and LSP events.
- Offers commands to manually manage project structure.
- Optional C# class template insertion for new files.
- Supports Unity snippets with LuaSnip integration.

---

## 🔧 Plugin Commands

| Command     | Description |
|-------------|-------------|
| `:Uadd`     | Add current `.cs` file to `.csproj`. |
| `:Uaddall`  | Reset and re-add all `.cs` files under `Assets`. |
| `:Ustatus`  | Show project status info. |

---

## 🔁 Recommended Configuration

### Example (NvChad)

Install via Lazy:

```lua
{
  "apyra/nvim-unity",
  config = function()
    require("unity.plugin")
  end,
  ft = "cs",
}
```

Install `omnisharp` with [mason.nvim](https://github.com/williamboman/mason.nvim):

LSP Configuration:

```lua
local lspconfig = require("lspconfig")
lspconfig.omnisharp.setup {
  -- your config here
}
```

Optional Folding Setup (with [nvim-ufo](https://github.com/kevinhwang91/nvim-ufo)):

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

            -- foldfunc = "builtin",
            -- setopt = true,
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
      -- Fold options
      vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
      vim.o.foldcolumn = "1" -- '0' is not bad
      vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true

      require("ufo").setup()
    end,
},
```

---

## 🧹 Unity Snippets Integration

This plugin supports C# Unity snippets using [LuaSnip](https://github.com/L3MON4D3/LuaSnip).

### Installation

Create this file:

**Windows:**
```
C:/Users/YOUR_USERNAME/AppData/Local/nvim/lua/snippets/cs.lua
```

**Linux/macOS:**
```
~/.config/nvim/lua/snippets/cs.lua
```

### Example Snippets

```lua
return {
  s("start", {
    t({ "using UnityEngine;", "", "public class " }),
    i(1, "MyClass"),
    t({ " : MonoBehaviour", "{", "    " }),
    i(0),
    t({ "", "}" }),
  }),
  s("update", {
    t("void Update() {"),
    t({ "", "    " }),
    i(0),
    t({ "", "}" }),
  }),
  s("startmethod", {
    t("void Start() {"),
    t({ "", "    " }),
    i(0),
    t({ "", "}" }),
  }),
  s("awake", {
    t("void Awake() {"),
    t({ "", "    " }),
    i(0),
    t({ "", "}" }),
  }),
}
```

### Loading Snippets

Make sure LuaSnip loads your snippets file by requiring it in your config:

**Linux/macOS:**
```lua
require("luasnip.loaders.from_lua").load({ paths = "~/.config/nvim/lua/snippets" })
```

**Windows:**
```lua
require("luasnip.loaders.from_lua").lazy_load({
  paths = vim.fn.stdpath("config") .. "/lua/snippets"
})
```

This ensures that your `cs.lua` snippets are available when editing C# files.

Once installed, use `<Tab>` or your LuaSnip trigger keys to expand snippets inside `.cs` files.

---

## 🧩 Unity Editor Integration

To make the integration even smoother, you can install the Unity-side package:

📦 [`nvim-unity-editor`](https://github.com/apyra/nvim-unity-editor)

This Unity package:

- Adds a "Regenerate Project Files" button inside the Unity editor
- Lets you set Neovim as the external script editor (via a launcher script)
- Generates `.csproj`, `.sln`, and `.vscode/` on demand

Install it via Git or manually inside Unity's `Packages/` folder. Check its README for full instructions.

---

## 🧑‍💻 Contributing
PRs and suggestions welcome! This plugin is still under early development.

---

## 📜 License
MIT








