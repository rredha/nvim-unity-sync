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
	self.hasCSProjectUnityCapability = false
	self.rootFolder = utils.findRootFolder()
end

-- Função para criar um novo objeto
function XmlCsprojHandler:new()
	local obj = {
		rootFolder = nil, -- Variável da instância
		hasCSProjectUnityCapability = false,
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
		return false, "No Unity Project found"
	end

	if self.hasCSProjectUnityCapability then
		return true, "Unity CsProject detected at " .. self.rootFolder
	end

	-- Caminho do Assembly-CSharp.csproj
	local filePath = self.rootFolder .. "/Assembly-CSharp.csproj"

	-- Verifica se o arquivo existe
	if not utils.fileExists(filePath) then
		return false, "No CsProject found, regenerate project files in Unity"
	end

	-- Carrega o XML do arquivo .csproj
	if not self:load(filePath) then
		return false, "Failed to load the Assembly-CSharp.csproj file"
	end

	-- Verifica se o projeto é do Unity
	self.hasCSProjectUnityCapability = self:checkProjectCapability("Unity")

	return self.hasCSProjectUnityCapability, "This is an Unity Project ready to sync"
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
	-- Protege o valor para uso em pattern
	local escapedValue = value:gsub("([%.%+%-%*%?%^%$%(%)%[%]%%])", "%%%1")
	local existingPattern = "<Compile%s+Include%s*=%s*[\"']" .. escapedValue .. "[\"']%s*/?>"

	-- Evita duplicação
	if self.content:match(existingPattern) then
		return false, "[NvimUnity] Script already added in Unity project"
	end

	-- Se placeholder existe, insere nele
	local placeholderPattern = "<!%-%- {{COMPILE_INCLUDES}} %-%->"
	if self.content:match(placeholderPattern) then
		local newLine = '    <Compile Include="' .. value .. '" />\n    <!-- {{COMPILE_INCLUDES}} -->'
		self.content = self.content:gsub(placeholderPattern, newLine, 1)
		return true, "[NvimUnity] Script added to Unity project"
	end

	-- Se não existe placeholder, adiciona bloco novo com placeholder e tag
	local newItemGroup = "  <ItemGroup>\n"
		.. "<!-- Auto-generated block: do not modify manually or remove these commented lines -->\n"
		.. "<!-- {{COMPILE_INCLUDES}} -->\n"
		.. '    <Compile Include="'
		.. value
		.. '" />\n'
		.. "  </ItemGroup>"

	-- Extrai a tag <Project>
	local openTag, innerContent, closeTag = self.content:match("(<Project.-\n)(.-)(</Project>)")
	if not openTag then
		return false, "[NvimUnity] <Project> tag not found"
	end

	-- Divide em linhas para inserir corretamente
	local lines = {}
	for line in innerContent:gmatch("([^\n]*)\n?") do
		table.insert(lines, line)
	end

	-- Conta filhos diretos
	local depth, childrenCount, insertLine = 0, 0, #lines + 1
	for i, line in ipairs(lines) do
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

		if childrenCount == 10 and depth == 0 then
			insertLine = i + 1
			break
		end
	end

	-- Insere o novo bloco na posição definida
	table.insert(lines, insertLine, newItemGroup)
	self.content = openTag .. table.concat(lines, "\n") .. "\n" .. closeTag

	return true, "[NvimUnity] Script added and placeholder created"
end

-- Função para adicionar ou modificar a tag Compile
function XmlCsprojHandler:updateCompileTags(changes)
	-- Expressão para capturar os <ItemGroup> com tags <Compile>
	local itemGroupPattern = "(<ItemGroup>.-</ItemGroup>)"
	local updated = {}

	-- Processa cada grupo separadamente
	self.content = self.content:gsub(itemGroupPattern, function(itemGroup)
		-- Processa apenas <ItemGroup> que contêm <Compile>
		if itemGroup:match("<Compile") then
			-- Modifica apenas os valores dentro deste grupo
			for _, change in ipairs(changes) do
				if type(change.old) == "string" and type(change.new) == "string" then
					local oldValue = change.old:gsub("([%.%+%-%*%?%^%$%(%)%[%]%%])", "%%%1")
					local newValue = change.new

					local newGroup, count = itemGroup:gsub(
						"(<Compile%s+Include%s*=%s*[\"'])" .. oldValue .. "([\"'])",
						"%1" .. newValue .. "%2",
						1
					)

					if count > 0 then
						itemGroup = newGroup
						table.insert(updated, { old = change.old, new = newValue })
					end
				end
			end
		end
		return itemGroup
	end)

	return updated -- opcional: retorna as alterações feitas
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
function XmlCsprojHandler:resetCompileTags()
	local files = utils.getCSFilesInFolder(self.rootFolder .. "/Assets")
	if #files == 0 then
		return false, "[NvimUnity] No .cs files found in " .. self.rootFolder .. "/Assets..."
	end

	-- Criar novo bloco <Compile />
	local newCompileTags = {}
	for _, file in ipairs(files) do
		local cutFile = utils.cutPath(utils.uriToPath(file), "Assets")
		table.insert(newCompileTags, '    <Compile Include="' .. cutFile .. '" />')
	end
	local newBlock = table.concat(newCompileTags, "\n")
	-- Procurar placeholder

	local placeholderPattern = "<!%-%- %{%{COMPILE_INCLUDES%}%} %-%->"
	local startPos, endPos = self.content:find(placeholderPattern)

	if startPos and endPos then
		-- Placeholder existe, substituir apenas as <Compile /> após ele
		local before = self.content:sub(1, endPos)
		local after = self.content:sub(endPos + 1)

		-- Remove os <Compile ... /> somente até </ItemGroup>
		local itemGroupClose = after:find("</ItemGroup>")
		if itemGroupClose then
			local blockBeforeClose = after:sub(1, itemGroupClose - 1)
			local blockAfterClose = after:sub(itemGroupClose)

			-- Limpa apenas os <Compile /> nesse intervalo
			blockBeforeClose = blockBeforeClose:gsub('[ \t]*<Compile%s+Include%s*=%s*"[^"]-"%s*/>%s*\n?', "")

			after = blockBeforeClose .. blockAfterClose
		end

		-- Garante que o "before" termina com quebra de linha
		if not before:match("\n$") then
			before = before .. "\n"
		end

		self.content = before .. newBlock .. after

		return true, "[NvimUnity] Compile tags updated using existing placeholder"
	end

	-- Se NÃO houver placeholder, seguir lógica original, mas inserir o placeholder também
	self.content = self.content:gsub("<Compile%s+Include%s*=%s*[\"'][^\"']-[\"']%s*/>%s*\n?", "")

	local openTag, innerContent, closeTag = self.content:match("(<Project.-\n)(.-)(</Project>)")
	if not openTag then
		return false, "[NvimUnity] <Project> tag not found"
	end

	local lines = {}
	for line in innerContent:gmatch("([^\n]*)\n?") do
		table.insert(lines, line)
	end

	local depth = 0
	local childrenCount = 0
	local insertLine = #lines + 1 -- Começar no final das linhas, como fallback

	-- Identificar a 10ª linha de inserção
	for i, line in ipairs(lines) do
		local open = line:match("^%s*<([%w%.%-]+)[^>/]*>$")
		local selfClosing = line:match("^%s*<([%w%.%-]+)[^>]-/>%s*$")
		local close = line:match("^%s*</([%w%.%-]+)>%s*$")

		-- Considerar tags auto-fechadas ou abertas
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

		-- Determina a linha de inserção após o 10º filho
		if childrenCount == 10 and depth == 0 then
			insertLine = i + 1
			break
		end
	end

	-- Monta bloco com placeholder + tags
	local newBlockWithPlaceholderLines = {
		"  <ItemGroup>",
		"  <!-- Auto-generated block: do not modify manually or remove these commented lines -->",
		"  <!-- {{COMPILE_INCLUDES}} -->",
		newBlock,
		"  </ItemGroup>",
	}

	-- Inserir o novo bloco nas linhas no local adequado
	for i = #newBlockWithPlaceholderLines, 1, -1 do
		table.insert(lines, insertLine, newBlockWithPlaceholderLines[i])
	end

	self.content = openTag .. table.concat(lines, "\n") .. "\n" .. closeTag

	return true, "[NvimUnity] Compile tags inserted with new placeholder"
end

function XmlCsprojHandler:openUnity()
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
	vim.fn.jobstart({ unity, config.unity_path, root }, {
		detach = true,
	})

	vim.notify("[nvim-unity] Opening Unity project...", vim.log.levels.INFO)
end

return XmlCsprojHandler
