local xmlHandler = require("unity.handler")
local utils = require("unity.utils")
local unityProject = xmlHandler:new()

local api = require "nvim-tree.api"
local Event = api.events.Event
local lspAttached = false

local function trySaveProject()
  local saved, err = unityProject:save()
  if not saved and err then
    vim.notify("[NvimUnity] " .. err, vim.log.levels.ERROR)
  end
end

api.events.subscribe(Event.FileCreated, function(data)
  if lspAttached then return end
  if not unityProject:validateProject() or not utils.isCSFile(data.fname) then return end

  local folderName = utils.cutPath(utils.uriToPath(data.fname), "Assets")
  if unityProject:addCompileTag(folderName) then
    trySaveProject()
  end
end)

api.events.subscribe(Event.FileRemoved, function(data)
  if lspAttached then return end
  if not unityProject:validateProject() or not utils.isCSFile(data.fname) then return end

  local folderName = utils.cutPath(utils.uriToPath(data.fname), "Assets")
  if unityProject:removeCompileTag(folderName) then
    trySaveProject()
  end
end)

api.events.subscribe(Event.WillRenameNode, function(data)
  if not unityProject:validateProject() then return end

  if utils.isDirectory(data.old_name) then
    local updatedFileNames = utils.getUpdatedCSFilesNames(data.old_name, data.new_name)
    if #updatedFileNames == 0 then return end

    local nameChanges = {}
    for _, file in ipairs(updatedFileNames) do
      table.insert(nameChanges, {
        old = utils.cutPath(utils.uriToPath(file.old), "Assets"),
        new = utils.cutPath(utils.uriToPath(file.new), "Assets"),
      })
    end

    unityProject:updateCompileTags(nameChanges)
    trySaveProject()
  else
    if lspAttached then return end

    local nameChanges = {
      {
        old = utils.cutPath(utils.uriToPath(data.old_name), "Assets"),
        new = utils.cutPath(utils.uriToPath(data.new_name), "Assets"),
      }
    }

    unityProject:updateCompileTags(nameChanges)
    trySaveProject()
  end
end)

api.events.subscribe(Event.FolderRemoved, function(data)
  if not unityProject:validateProject() or not data.folder_name then return end

  local folderName = utils.cutPath(utils.uriToPath(data.folder_name), "Assets")
  if unityProject:removeCompileTagsByFolder(folderName) then
    trySaveProject()
  end
end)

vim.api.nvim_create_autocmd("LspNotify", {
  callback = function(args)
    if args.data.method ~= "workspace/didChangeWatchedFiles" then return end

    local changes = args.data.params.changes
    local needSave = false

    if #changes == 1 then
      if not utils.isCSFile(changes[1].uri) or not unityProject:validateProject() then return end

      local fileName = utils.cutPath(utils.uriToPath(changes[1].uri), "Assets")
      if changes[1].type == 1 then
        if unityProject:addCompileTag(fileName) then needSave = true end
      elseif changes[1].type == 3 then
        if unityProject:removeCompileTag(fileName) then needSave = true end
      end
    elseif #changes == 2 then
      if not utils.isCSFile(changes[1].uri) or not utils.isCSFile(changes[2].uri) then return end
      if not unityProject:validateProject() then return end

      if changes[1].type == 3 and changes[2].type == 1 then
        local nameChanges = {
          {
            old = utils.cutPath(utils.uriToPath(changes[1].uri), "Assets"),
            new = utils.cutPath(utils.uriToPath(changes[2].uri), "Assets"),
          }
        }
        if unityProject:updateCompileTags(nameChanges) then needSave = true end
      end
    end

    if needSave then trySaveProject() end
  end,
})

vim.api.nvim_create_autocmd("LspAttach", {
  once = true,
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if unityProject and client and client.name == unityProject:getLspName() then
      if unityProject:validateProject() then
        lspAttached = true
        vim.notify("[NvimUnity] LSP " .. client.name .. " is ready to go, happy coding!", vim.log.levels.INFO)
      end
    end
  end,
})

vim.api.nvim_create_autocmd("LspDetach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client and client.name == unityProject:getLspName() then
      if unityProject:validateProject() then
        vim.notify("[NvimUnity] " .. client.name .. " foi desconectado deste buffer.", vim.log.levels.WARN)
        lspAttached = false
      end
    end
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    unityProject:updateRoot()
    if unityProject:validateProject() then
      vim.notify("[NvimUnity] Unity project detected at " .. unityProject:getRoot(), vim.log.levels.INFO)
    end
  end,
})

vim.api.nvim_create_autocmd("DirChanged", {
  callback = function()
    unityProject:updateRoot()
  end,
})

vim.api.nvim_create_user_command("Uadd", function()
  local bufname = vim.api.nvim_buf_get_name(0)
  if not utils.isCSFile(bufname) then
    vim.api.nvim_err_writeln "This is not a .cs file"
    return
  end

  if not unityProject:validateProject() then
    vim.api.nvim_err_writeln "This is not an Unity project, try to regenerate the csproj files in Unity"
    return
  end

  if vim.fn.filereadable(bufname) == 1 then
    local fileName = unityProject:cutPath(bufname, "Assets")
    fileName = unityProject:uriToPath(fileName)
    local added, msg = unityProject:addCompileTag(fileName)
    if added then
      trySaveProject()
    else
      vim.notify("[NvimUnity] " .. msg, vim.log.levels.WARN)
    end
  end
end, { nargs = 0 })

vim.api.nvim_create_user_command("Uaddall", function()
  if not unityProject:validateProject() then
    vim.api.nvim_err_writeln "This is not an Unity project, try to regenerate the csproj files in Unity"
    return
  end

  local reseted, msg = unityProject:resetCompileTags(9)
  if reseted then
    trySaveProject()
  else
    vim.notify("[NvimUnity] " .. msg, vim.log.levels.WARN)
  end
end, { nargs = 0 })

vim.api.nvim_create_user_command("Ustatus", function()
  if not unityProject:validateProject() then
    vim.notify("[NvimUnity] Nenhum projeto Unity válido detectado.", vim.log.levels.WARN)
    return
  end

  local msg = {
    "🧠 [NvimUnity] Status do Projeto:",
    "📁 Root: " .. unityProject:getRoot(),
    "🔌 LSP Ativo: " .. (lspAttached and "Sim" or "Não"),
  }

  vim.notify(table.concat(msg, "\n"), vim.log.levels.INFO)
end, { nargs = 0 })

