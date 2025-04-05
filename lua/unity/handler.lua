local utils = require("unity.utils")
local config = require("unity.config")

local XmlCsprojHandler = {}
XmlCsprojHandler.__index = XmlCsprojHandler

function XmlCsprojHandler:getLspName()
	return self.lspName
end

function XmlCsprojHandler:getRoot()
	return self.rootFolder
end

function XmlCsprojHandler:updateRoot()
	if not utils.isInsideRoot(self) then
		self.isUnityProject = false
		-- First try with lps
		local clients = vim.lsp.get_active_clients()
		for _, client in ipairs(clients) do
			if client.name == self.lspName then
				self.rootFolder = client.config.root_dir
			end
		end
		-- then try up in folders
		self.rootFolder = utils.findRootFolder()
	end
end

-- Função para criar um novo objeto
function XmlCsprojHandler:new()
	local obj = {
		rootFolder = nil, -- Variável da instância
		isUnityProject = false,
		lspName = "omnisharp",
	}
	setmetatable(obj, self)
	self.__index = self
	return obj
end

-- Função para carregar o arquivo .csproj
function XmlCsprojHandler:load(filename)
	local file = io.open(filename, "r")
	if not file then
		return false, "File not found"
	end
	self.content = file:read("*a")
	file:close()
	return true
end

-- Função para salvar o arquivo .csproj
function XmlCsprojHandler:save()
	local file = io.open(self.rootFolder .. "/Assembly-CSharp.csproj", "w")
	if not file then
		return false, "Cannot open file for writing"
	end
	file:write(self.content)
	file:close()
	return true
end

-- Função para checar se o projeto é um Unity Project
function XmlCsprojHandler:validateProject()
	-- Verifica se o RootFolder está definido
	if not self.rootFolder then
		return false
	end

	-- Se já foi identificado como um projeto Unity, retorna diretamente
	if self.isUnityProject then
		return true
	end

	-- Caminho do Assembly-CSharp.csproj
	local filePath = self.rootFolder .. "/Assembly-CSharp.csproj"

	-- Verifica se o arquivo existe
	if not utils.fileExists(filePath) then
		return false
	end

	-- Carrega o XML do arquivo .csproj
	if not self:load(filePath) then
		return false
	end

	-- Verifica se o projeto é do Unity
	self.isUnityProject = self:checkProjectCapability("Unity")

	return self.isUnityProject
end

-- Função para checar a tag ProjectCapability e seu atributo
function XmlCsprojHandler:checkProjectCapability(attribute)
	local pattern = '<ProjectCapability.-Include="' .. attribute .. '".-/>'
	if self.content:match(pattern) then
		return true
	end
	return false
end

-- Função para adicionar uma nova Compile tag
function XmlCsprojHandler:addCompileTag(value)
	-- Escapa caracteres especiais no valor
	local escapedValue = value:gsub("([%.%+%-%*%?%^%$%(%)%[%]%%])", "%%%1")
	local pattern = '<Compile%s+Include%s*=%s*["]' .. escapedValue .. '["].-/?>'

	-- Se já existir a tag Compile com esse Include, retorna erro
	if self.content:match(pattern) then
		return false, "[NvimUnity] Script already added in Unity project"
	end

	-- Busca um ItemGroup que já contém <Compile> e adiciona a nova entrada corretamente
	local itemGroupPattern = "(<ItemGroup>.-)(</ItemGroup>)"
	local found = false

	self.content = self.content:gsub(itemGroupPattern, function(before, after)
		if before:match("<Compile") then
			found = true
			return before .. '    <Compile Include="' .. value .. '" />\n' .. after
		end
		return before .. after
	end)

	-- Se nenhum ItemGroup com <Compile> foi encontrado, cria um novo corretamente
	if not found then
		self.content =
			self.content:gsub("%s*$", '\n<ItemGroup>\n    <Compile Include="' .. value .. '" />\n</ItemGroup>\n')
	end

	return true, "[NvimUnity] Script added to Unity project"
end

-- Função para adicionar ou modificar a tag Compile
function XmlCsprojHandler:updateCompileTags(changes)
	-- Expressão para capturar os <ItemGroup> com tags <Compile>
	local itemGroupPattern = "(<ItemGroup>.-</ItemGroup>)"

	-- Processa cada grupo separadamente
	self.content = self.content:gsub(itemGroupPattern, function(itemGroup)
		-- Processa apenas <ItemGroup> que contêm <Compile>
		if itemGroup:match("<Compile") then
			-- Modifica apenas os valores dentro deste grupo
			for _, change in ipairs(changes) do
				local oldValue = change.old:gsub("([%.%+%-%*%?%^%$%(%)%[%]%%])", "%%%1")
				local newValue = change.new
				itemGroup = itemGroup:gsub(
					"(<Compile%s+Include%s*=%s*[\"'])" .. oldValue .. "([\"'])",
					"%1" .. newValue .. "%2",
					1
				)
			end
		end
		return itemGroup -- Retorna o grupo modificado ou intacto
	end)
end

-- Função para remover uma tag Compile
function XmlCsprojHandler:removeCompileTag(attribute)
	local modified = false

	-- Escapa caracteres especiais para regex do Lua
	local escapedAttribute = attribute:gsub("([%.%+%-%*%?%^%$%(%)%[%]%%])", "%%%1")

	-- Atualiza apenas os ItemGroups que contêm <Compile>
	self.content = self.content:gsub("(<ItemGroup>.-</ItemGroup>)", function(itemGroup)
		if not itemGroup:match("<Compile") then
			return itemGroup -- Ignora ItemGroups sem <Compile>
		end

		local lines = {} -- Guarda as linhas atualizadas do ItemGroup
		for line in itemGroup:gmatch("[^\r\n]+") do
			if not line:match("<Compile%s+Include%s*=%s*['\"]" .. escapedAttribute .. "['\"]") then
				table.insert(lines, line) -- Mantém linhas que não precisam ser removidas
			else
				modified = true -- Indica que houve uma remoção
			end
		end

		-- Remove o ItemGroup inteiro se ele ficou apenas com <ItemGroup>...</ItemGroup>
		if #lines == 2 then
			return ""
		end

		return table.concat(lines, "\n")
	end)

	return modified
end

-- Função para remover uma ou varias Compile tags pelo nome da pasta
function XmlCsprojHandler:removeCompileTagsByFolder(folderpath)
	local modified = false

	-- Escapa caracteres especiais para padrões Lua
	local escapedFolderPath = folderpath:gsub("([%.%+%-%*%?%^%$%(%)%[%]%%])", "%%%1")

	-- Atualiza apenas os ItemGroups que contêm <Compile>
	self.content = self.content:gsub("(<ItemGroup>.-</ItemGroup>)", function(itemGroup)
		if not itemGroup:match("<Compile") then
			return itemGroup -- Ignora ItemGroups sem <Compile>
		end

		local lines = {} -- Guarda as linhas atualizadas do ItemGroup
		for line in itemGroup:gmatch("[^\r\n]+") do
			-- Remove apenas as tags <Compile> cujo caminho começa com folderpath
			if not line:match("<Compile%s+Include%s*=%s*['\"]" .. escapedFolderPath .. "[^'\"]*['\"]") then
				table.insert(lines, line) -- Mantém linhas que não precisam ser removidas
			else
				modified = true -- Indica que houve remoção
			end
		end

		-- Remove o ItemGroup inteiro se ele ficou apenas com <ItemGroup>...</ItemGroup>
		if #lines == 2 then
			return ""
		end

		return table.concat(lines, "\n")
	end)

	return modified
end

-- Função para remover all Compile tags e preencher com uma nova lista
function XmlCsprojHandler:resetCompileTags(insertPosition)
	local files = getCSFilesInFolder(self.rootFolder .. "/Assets")
	if #files == 0 then
		return false, "[NvimUnity] No .cs files found in " .. self.rootFolder .. "/Assets..."
	end

	-- Remove todas as <Compile Include="..."/> tags existentes
	self.content = self.content:gsub("<Compile%s+Include%s*=%s*[\"'][^\"']-[\"']%s*/>%s*\n?", "")

	-- Criar novo bloco <ItemGroup>
	local newCompileTags = {}
	for _, file in ipairs(files) do
		local cutFile = self:cutPath(self:uriToPath(file), "Assets")
		table.insert(newCompileTags, '    <Compile Include="' .. cutFile .. '" />')
	end
	local newItemGroup = "  <ItemGroup>\n" .. table.concat(newCompileTags, "\n") .. "\n  </ItemGroup>"

	-- Extrai a tag <Project> e o conteúdo interno
	local openTag, innerContent, closeTag = self.content:match("(<Project.-\n)(.-)(</Project>)")
	if not openTag then
		return false, "[NvimUnity] <Project> tag not found"
	end

	local lines = {}
	for line in innerContent:gmatch("([^\n]*)\n?") do
		table.insert(lines, line)
	end

	-- Contar apenas elementos completos (filhos diretos de <Project>)
	local depth = 0
	local childrenCount = 0
	local insertLine = #lines + 1

	for i, line in ipairs(lines) do
		-- Abertura de tag
		local open = line:match("^%s*<([%w%.%-]+)[^>/]*>$")
		local selfClosing = line:match("^%s*<([%w%.%-]+)[^>]-/>%s*$")
		local close = line:match("^%s*</([%w%.%-]+)>%s*$")

		if selfClosing and depth == 0 then
			childrenCount = childrenCount + 1
		elseif open then
			if depth == 0 then
				childrenCount = childrenCount + 1
			end
			depth = depth + 1
		elseif close then
			depth = math.max(0, depth - 1)
		end

		if childrenCount == insertPosition and depth == 0 then
			insertLine = i + 1
			break
		end
	end

	-- Inserir novo <ItemGroup> no ponto correto
	table.insert(lines, insertLine, newItemGroup)

	-- Atualiza o conteúdo completo
	self.content = openTag .. table.concat(lines, "\n") .. "\n" .. closeTag

	return true, "[NvimUnity] Compile tags reset successfully"
end

function XmlCsprojHandler:openProject()
	local root = self.rootFolder
	local unity = config.unity_path

  -- Verificar se Unity já está rodando (simples, por processo)
  local is_running = vim.fn.system("tasklist"):find("Unity.exe")

  if is_running then
    print("⚠ Unity já está aberto.")
    return
  end

	if not unity or vim.fn.filereadable(unity) == 0 then
		vim.notify("[nvim-unity] Unity path is not set or invalid", vim.log.levels.ERROR)
		return
	end

	-- Checa se o projeto é Unity (tem pasta Assets)
	if vim.fn.isdirectory(root .. "/Assets") == 0 then
		vim.notify("[nvim-unity] This folder is not a Unity project", vim.log.levels.WARN)
		return
	end

	-- Executa Unity com o path do projeto atual
	vim.fn.jobstart({ unity, config.unity_path , root }, {
		detach = true,
	})

	vim.notify("[nvim-unity] Opening Unity project...", vim.log.levels.INFO)
end

return XmlCsprojHandler
