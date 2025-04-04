local uv = vim.loop

local utils = {}

function utils.isInsideRoot(self)
  if not self.rootFolder then
    return false
  end

  local cwd = vim.fn.getcwd():gsub("\\", "/")
  return cwd:find("^" .. self.rootFolder:gsub("\\", "/")) ~= nil
end

function utils.findRootFolder()
  local path = vim.fn.getcwd():gsub("\\", "/")

  while path do
    local csproj_path = path .. "/Assembly-CSharp.csproj"
    if vim.loop.fs_stat(csproj_path) then
      return path
    end
    local parent = vim.fn.fnamemodify(path, ":h")
    if not parent or parent == path then
      break
    end
    path = parent
  end
  return nil, "❌ Root folder with Assembly-CSharp.csproj not found"
end

function utils.fileExists(filename)
  local ok, code = os.rename(filename, filename)
  if not ok and code == 2 then
    return false
  else
    return true
  end
end

function utils.normalizePath(path)
  if jit.os == "Windows" then
    return path:gsub("\\\\", "\\")
  else
    return path
  end
end

function utils.isCSFile(file)
  return file:sub(-3) == ".cs"
end

function utils.getCSFilesInFolder(root_folder)
  root_folder = utils.normalizePath(root_folder)
  local cs_files = {}

  local function scan_dir(path)
    local handle = uv.fs_scandir(path)
    while handle do
      local name, type = uv.fs_scandir_next(handle)
      if not name then break end

      local full_path = path .. "/" .. name
      if type == "directory" then
        scan_dir(full_path)
      elseif name:match "%.cs$" then
        table.insert(cs_files, full_path)
      end
    end
  end

  scan_dir(root_folder)
  return cs_files
end

function utils.getUpdatedCSFilesNames(old_root, new_root)
  old_root, new_root = utils.normalizePath(old_root), utils.normalizePath(new_root)

  local old_files = utils.getCSFilesInFolder(old_root)
  local renamed_files = {}

  for _, old_path in ipairs(old_files) do
    local new_path = old_path:gsub(vim.pesc(old_root), new_root)
    table.insert(renamed_files, { old = old_path, new = new_path })
  end

  return renamed_files
end

function utils.isDirectory(path)
  if jit and jit.os == "Windows" then
    path = path:gsub("\\", "/")
  end

  local stat = uv.fs_stat(path)
  return stat and stat.type == "directory"
end

function utils.uriToPath(uri)
  local path = uri:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)

  if package.config:sub(1, 1) == "\\" then
    path = path:gsub("/", "\\")
  end

  return path
end

function utils.cutPath(path, folder)
  if not path or not folder then
    return nil, "Invalid arguments to cutPath"
  end

  local start_pos = string.find(path, folder)
  if start_pos then
    return string.sub(path, start_pos)
  else
    return nil, "Folder not found in path"
  end
end

function utils.insertCSTemplate(filepath)
    print("trying to add template to file: " .. filepath)
  if not filepath then return end

  local filename = vim.fn.fnamemodify(filepath, ":t:r")
  local bufnr = vim.fn.bufnr(filepath, true)
  if bufnr == -1 then return end

  if not vim.api.nvim_buf_is_loaded(bufnr) then
    vim.fn.bufload(bufnr)
  end

  vim.defer_fn(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then return end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    if #lines == 0 or (#lines == 1 and lines[1] == "") then
      local template = {
        "using UnityEngine;",
        "",
        "public class " .. filename .. " : MonoBehaviour",
        "{",
        "    ",
        "}",
      }

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, template)
    end
  end, 400)
end

return utils

