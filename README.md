# nvim-unity

`nvim-unity` is a Neovim plugin that helps you keep your `.csproj` files up to date when working on Unity projects.  
It automatically updates the `<Compile>` entries in your `.csproj` files when C# files or folders are created, renamed, or deleted.

## ✨ Features

- 📁 Automatically tracks file creation, deletion, and renaming inside the `Assets/` folder
- 📄 Automatically updates your `.csproj` with `<Compile Include="...">` entries
- 🧠 Smart LSP integration: defers to LSP when available
- 🧹 Add or reset compile tags manually with commands
- 🛠 Handles folder-level operations (e.g., folder renames or deletions)

## ⚙️ Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "apyra/nvim-unity",
  lazy = false,
  config = function()
    require("nvim-unity.plugin")
  end,
}
```

## 🔌 Setup

No manual setup is needed. The plugin automatically detects when you enter a Unity project (by checking for `.csproj` files inside `./YourProjectName/`).

## 🧪 Commands

| Command      | Description                                               |
|--------------|-----------------------------------------------------------|
| `:Uadd`      | Force add the current `.cs` file to the project file      |
| `:Uaddall`   | Resets all `<Compile>` entries with current `.cs` files   |
| `:Ustatus`   | Prints plugin internal state and current `.csproj` path   |

## 📦 How it Works

- Hooks into `nvim-tree` events and LSP notifications
- Tracks `Assets/**/*.cs` files
- Handles `.csproj` files automatically (inserting, updating, or removing `<Compile>` tags)
- Changes are saved only if necessary

## 📁 Project Structure

This plugin uses a modular Lua structure. Example:

```
lua/
├── nvim-unity/
│   ├── plugin.lua       -- Main entry point
│   ├── handler.lua      -- Handles .csproj logic
│   └── utils.lua        -- Utility functions
```

## ✅ Requirements

- Neovim 0.9+
- [nvim-tree.lua](https://github.com/nvim-tree/nvim-tree.lua)
- A Unity project with existing `.csproj` files (regenerated via Unity)

## 💡 Tips

- Regenerate `.csproj` files in Unity if plugin reports the project as invalid
- Only files under the `Assets/` folder are considered valid for tracking

## 📃 License

MIT License

---

Happy coding! 🎮🧠
