local Plugin = {}
local config = require("unity.config")

-- Função setup (opcionalmente recebe overrides)
function Plugin.setup(opts)
  opts = opts or {}
  if opts.unity_path then
    config.unity_path = opts.unity_path
  end
  if opts.unity_cs_template then
    config.unity_cs_template = opts.unity_cs_template
  end
end

local xmlHandler = require("unity.handler")
local ok, utils = pcall(require, "unity.utils")
if not ok then
	vim.notify("[NvimUnity] Failed to load unity.utils", vim.log.levels.ERROR)
	return
end

local unityProject = xmlHandler:new()
local lspAttached = false

local function trySaveProject()
	local saved, err = unityProject:save()
	if not saved and err then
		vim.notify("[NvimUnity] " .. err, vim.log.levels.ERROR)
	end
end

--------------- Auto Commands --------------------

vim.api.nvim_create_autocmd("LspNotify", {
  pattern =".cs",
	callback = function(args)
		if args.data.method ~= "workspace/didChangeWatchedFiles" then
			return
		end

		local changes = args.data.params.changes
		local needSave = false

		if #changes == 1 then
			if not unityProject:validateProject() then
				return
			end

			local fileName = utils.cutPath(utils.normalizePath(changes[1].uri), "Assets") or ""
			if changes[1].type == 1 then
        if config.unity_cs_template then
				  utils.insertCSTemplate(utils.normalizePath(changes[1].uri))
        end
				if unityProject:addCompileTag(fileName) then
					needSave = true
				end
			elseif changes[1].type == 3 then
				if unityProject:removeCompileTag(fileName) then
					needSave = true
				end
			end
		elseif #changes == 2 then
			if not unityProject:validateProject() then
				return
			end

			if changes[1].type == 3 and changes[2].type == 1 then
				local nameChanges = {
					{
						old = utils.cutPath(utils.normalizePath(changes[1].uri), "Assets") or "",
						new = utils.cutPath(utils.normalizePath(changes[2].uri), "Assets") or "",
					},
				}
				if unityProject:updateCompileTags(nameChanges) then
					needSave = true
				end
			end
		end

		if needSave then
			trySaveProject()
		end
	end,
})

vim.api.nvim_create_autocmd("LspAttach", {
	once = true,
  pattern = ".cs",
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client and unityProject:validateProject() then
				lspAttached = true
				vim.notify("[NvimUnity] LSP " .. client.name .. " is ready to go, happy coding!", vim.log.levels.INFO)
			end
	end,
})

vim.api.nvim_create_autocmd("LspDetach", {
  pattern = ".cs",
	callback = function(args)
			if unityProject:validateProject() then
				lspAttached = false
			end
	end,
})

vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		unityProject:updateRoot()
	end,
})

vim.api.nvim_create_autocmd("VimLeave", {
    callback = function()
        os.execute('pkill -f unity2025')
    end
})

vim.api.nvim_create_autocmd("DirChanged", {
	callback = function()
		  unityProject:updateRoot()
	end,
})

--------------- User Commands --------------------

vim.api.nvim_create_user_command("Ustatus", function()
	if not unityProject:validateProject() then
		vim.notify("[NvimUnity] This is not a valid Unity project.", vim.log.levels.WARN)
		return
	end

	local msg = {
		"🧠 [NvimUnity] Project Status:",
		"📁 Root: " .. unityProject:getRoot(),
		"🔌 LSP Active: " .. (lspAttached and "Yes" or "No"),
	}

	vim.notify(table.concat(msg, "\n"), vim.log.levels.INFO)
end, {
  nargs = 0,
  desc = "Show the status of the current project"
})

vim.api.nvim_create_user_command("Usync", function()

  local response , msg = unityProject:validateProject()
  if not response then
		vim.api.nvim_err_writeln("[NvimUnity] " .. msg)
    return
	end

	local reseted, msg = unityProject:resetCompileTags()
	if reseted then
		trySaveProject()
    vim.cmd('echo ""')
	else
		vim.notify("[NvimUnity] " .. msg, vim.log.levels.WARN)
	end
end, {
  desc = "Sync project files",
})

vim.api.nvim_create_user_command("Uopen", function()
	if not unityProject:validateProject() then
		vim.notify("[NvimUnity] This is not a Unity project ", vim.log.levels.ERROR)
		return
	end
	unityProject:openUnity()
  vim.cmd('echo ""')
end, {
	desc = "Open Unity Editor from Neovim",
})

return Plugin
