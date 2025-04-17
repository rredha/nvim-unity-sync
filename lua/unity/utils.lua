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

	local function isUnityProject(dir)
		local function exists(sub)
			local stat = vim.loop.fs_stat(dir .. "/" .. sub)
			return stat and stat.type == "directory"
		end
		return exists("Assets") and exists("Library") and exists("Packages")
	end

	while path do
		if isUnityProject(path) then
			return path
		end

		local parent = vim.fn.fnamemodify(path, ":h")
		if not parent or parent == path then
			break
		end
		path = parent
	end

	return nil, "❌ Unity project root (with Assets, Library, and Packages) not found"
end

function utils.fileExists(filename)
  return vim.loop.fs_stat(filename) ~= nil
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

-- Perguntar para o cgpt como agir aqui se no windows o assets\
function utils.normalizePath(path)
	-- Converte o caminho de URI para formato de path
	path = utils.uriToPath(path)

	-- Normaliza as barras de acordo com o sistema operacional
	if jit.os == "Windows" then
		-- Substitui as barras invertidas duplas para uma única barra invertida
		path = path:gsub("\\\\", "\\")
		-- Além disso, substitui todas as barras para \ no Windows
		path = path:gsub("/", "\\")
	else
		-- No Linux/macOS, substitui barras invertidas para barras normais
		path = path:gsub("\\", "/")
	end

	-- Remove qualquer barra dupla restante (caso algum erro de formatação ocorra)
	path = path:gsub("[\\/]+", "/")

	return path
end

function utils.isCSFile(file)
	return file:sub(-3) == ".cs"
end

function utils.getCSFilesInFolder(root_folder)
	-- Normaliza o caminho do diretório
	root_folder = utils.normalizePath(root_folder)
	local cs_files = {}

	-- Verifica se o diretório existe antes de escanear
	local function directoryExists(path)
		local handle = uv.fs_scandir(path)
		if not handle then
			return false -- Diretório não existe
		end
		return true -- Diretório existe
	end

	-- Função para escanear o diretório
	local function scan_dir(path)
		-- Verifica se o diretório existe antes de prosseguir
		if not directoryExists(path) then
			print("[Error] Directory not found: " .. path)
			return
		end

		local handle = uv.fs_scandir(path)
		while handle do
			local name, type = uv.fs_scandir_next(handle)
			if not name then
				break
			end

			local full_path = path .. "/" .. name
			if type == "directory" then
				scan_dir(full_path) -- Recurssão para subdiretórios
			elseif name:match("%.cs$") then
				table.insert(cs_files, full_path) -- Adiciona arquivo .cs
			end
		end
	end

	-- Inicia a varredura
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
	if not filepath then
		return
	end

	local filename = vim.fn.fnamemodify(filepath, ":t:r")
	local bufnr = vim.fn.bufnr(filepath, true)
	if bufnr == -1 then
		return
	end

	if not vim.api.nvim_buf_is_loaded(bufnr) then
		vim.fn.bufload(bufnr)
	end

	vim.defer_fn(function()
		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

		if #lines == 0 or (#lines == 1 and lines[1] == "") then
			local indent = "    "
			local template = {
				"using UnityEngine;",
				"",
				"public class " .. filename .. " : MonoBehaviour",
				"{",
				"",
				indent
					.. "// Start is called once before the first execution of Update after the MonoBehaviour is created",
				indent .. "void Start()",
				indent .. "{",
				indent .. "}",
				"",
				indent .. "// Update is called once per frame",
				indent .. "void Update()",
				indent .. "{",
				indent .. "}",
				"",
				"}",
			}

			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, template)
		end
	end, 400)
end

return utils
