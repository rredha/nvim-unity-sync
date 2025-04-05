# nvim-unity-handle

**Nvim Unity Handle** is a lightweight Neovim plugin designed to enhance Unity development inside Neovim. It automatically manages `.csproj` files based on file events, helping you avoid the need to manually regenerate project files in Unity.

> 🧩 Now includes integration with the [nvim-unity](https://github.com/apyra/nvim-unity) Unity package – enabling seamless communication between Unity and Neovim!

---

## ✨ Features

- Automatically adds or removes `<Compile>` tags from `.csproj` files when `.cs` files are created, deleted, or renamed.
- Detects Unity project root based on `Assembly-CSharp.csproj`.
- Hooks into `nvim-tree` and LSP events.
- Offers commands to manually manage project structure.
- Optional C# class template insertion for new files.
- Supports Unity snippets with LuaSnip integration.

* Note that the Assembly-CSharp.csproj will be overwriten by unity, but in this way you can work in your unity project with lsp features like code completions without the need of unity to be open.

---

## 🔧 Plugin Commands

| Command        | Description |
|----------------|-------------|
| `:Uadd`        | Add current `.cs` file to `.csproj`. |
| `:Uaddall`     | Reset and re-add all `.cs` files under `Assets`. |
| `:Ustatus`     | Show project status info. 
| `:Uregenerate` | Sends a message to unity to regenerate the project files. |
| `:Uopen`       | Try to open Unity if there is a valid project folder  |

---

Install via Lazy:

```lua
{
  "apyra/nvim-unity-handler",
  config = function()
    require("unity.plugin").setup({
      unity_path = "path/to/unity/Unity.exe"
        })
  end,
  ft = "cs",
}
```

## 🧩 Unity Editor Integration

To make the integration even smoother, you can install the Unity-side package:

📦 [`nvim-unity`](https://github.com/apyra/nvim-unity)

This Unity package:

- Adds a "Regenerate Project Files" button inside the Unity editor
- Lets you set Neovim as the external script editor (via a launcher script)
- Generates `.csproj`, `.sln`, and `.vscode/` on demand

---

## 🧑‍💻 Contributing
PRs and suggestions welcome! This plugin is still under early development.

---

## 📜 License
MIT








