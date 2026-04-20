local nativeLoader = {}

local HTTPS_MODULE_FILE_NAME = "https.dll"
local HTTPS_MODULE_DIRECTORY = "third_party/native/windows/x64"
local DIRECTORY_SEPARATOR = package.config:sub(1, 1)

local function isAbsolutePath(path)
    local normalizedPath = tostring(path or "")
    return normalizedPath:match("^[A-Za-z]:[\\/]") ~= nil or normalizedPath:sub(1, 2) == "\\\\"
end

local function appendUniquePath(currentValue, newValue)
    if tostring(newValue or "") == "" then
        return currentValue
    end

    local escapedValue = tostring(newValue):gsub("([^%w])", "%%%1")
    if tostring(currentValue or ""):match(escapedValue) then
        return currentValue
    end

    return tostring(newValue) .. ";" .. tostring(currentValue or "")
end

local function getPhysicalSourceRoot()
    if not (love and love.filesystem and love.filesystem.getSourceBaseDirectory and love.filesystem.getSource) then
        return nil
    end

    local sourceBaseDirectory = love.filesystem.getSourceBaseDirectory()
    local sourceName = love.filesystem.getSource()
    if not sourceBaseDirectory or sourceBaseDirectory == "" then
        return nil
    end

    if sourceName and sourceName ~= "" then
        if isAbsolutePath(sourceName) then
            return sourceName
        end
        return sourceBaseDirectory .. DIRECTORY_SEPARATOR .. sourceName
    end

    return sourceBaseDirectory
end

function nativeLoader.configure()
    if nativeLoader._configured == true then
        return
    end

    local sourceBaseDirectory = love and love.filesystem and love.filesystem.getSourceBaseDirectory and love.filesystem.getSourceBaseDirectory() or nil
    local physicalSourceRoot = getPhysicalSourceRoot()

    if physicalSourceRoot then
        package.cpath = appendUniquePath(
            package.cpath,
            physicalSourceRoot .. DIRECTORY_SEPARATOR .. HTTPS_MODULE_DIRECTORY:gsub("/", DIRECTORY_SEPARATOR) .. DIRECTORY_SEPARATOR .. "?.dll"
        )
    end

    if sourceBaseDirectory and sourceBaseDirectory ~= "" then
        package.cpath = appendUniquePath(
            package.cpath,
            sourceBaseDirectory .. DIRECTORY_SEPARATOR .. "?.dll"
        )
    end

    nativeLoader._configured = true
end

function nativeLoader.getBundledModuleFileName()
    return HTTPS_MODULE_FILE_NAME
end

return nativeLoader
