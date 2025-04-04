local uv = vim.loop

local utils = {}

function utils.isInsideRoot(self)
  if not self.rootFolder then
    return false
  end

  local cwd = vim.fn.getcwd():gsub("\\", "/") -- Normaliza as barras no Windows

  return cwd:find("^" .. self.rootFolder:gsub("\\", "/")) ~= nil -- Verifica se o `cwd` começa com `root`
end

function utils.findRootFolder()
  local path = vim.fn.getcwd():gsub("\\", "/") -- Normaliza o caminho

  while path do
    local csproj_path = path .. "/Assembly-CSharp.csproj" -- Caminho correto

    -- Verifica se o arquivo .csproj existe no diretório atual
    if vim.loop.fs_stat(csproj_path) then
      return path -- Retorna o root folder onde encontrou o .csproj
    end

    -- Subir um diretório
    local parent = vim.fn.fnamemodify(path, ":h")
    if not parent or parent == path then
      break -- Se não conseguir subir mais, para
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
    return path:gsub("\\\\", "\\") -- Convert \ to /
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
      if not name then
        break
      end -- Fim da pasta

      local full_path = path .. "/" .. name
      if type == "directory" then
        scan_dir(full_path) -- Busca dentro das subpastas
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

  local old_files = utils.getCSFilesInFolder(old_root) -- Pega todos os .cs da pasta antiga
  local renamed_files = {}

  for _, old_path in ipairs(old_files) do
    local new_path = old_path:gsub(vim.pesc(old_root), new_root) -- Substitui caminho antigo pelo novo
    table.insert(renamed_files, { old = old_path, new = new_path })
  end

  return renamed_files
end

function utils.isDirectory(path)
  -- Converte barra invertida "\" para barra normal "/" no Windows
  if jit and jit.os == "Windows" then
    path = path:gsub("\\", "/")
  end

  local stat = uv.fs_stat(path)
  return stat and stat.type == "directory"
end

function utils.uriToPath(uri)
  -- Decode percent-encoded characters (e.g., %C3%A7 -> ç)
  local path = uri:gsub("%%(%x%x)", function(hex)
    return string.char(tonumber(hex, 16))
  end)

  -- Convert forward slashes to backslashes (if on Windows)
  if package.config:sub(1, 1) == "\\" then
    path = path:gsub("/", "\\")
  end

  return path
end

function utils.cutPath(path, folder)
  local start_pos = string.find(path, folder)
  if start_pos then
    return string.sub(path, start_pos)
  else
    return nil, "Folder not found in path"
  end
end

return utils
