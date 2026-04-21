local originalLove = love
local originalTime = os.time

local function assertEqual(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)), 2)
    end
end

local files = {}
local nextTimestamp = 1000

os.time = function()
    nextTimestamp = nextTimestamp + 1
    return nextTimestamp
end

love = {
    filesystem = {
        createDirectory = function(path)
            files[path] = files[path] or {}
            return true
        end,
        write = function(path, content)
            files[path] = content
            return true
        end,
        getInfo = function(path, kind)
            local content = files[path]
            if content == nil then
                return nil
            end

            if type(content) == "table" then
                return { type = "directory" }
            end

            return { type = "file" }
        end,
        read = function(path)
            return files[path]
        end,
        remove = function(path)
            files[path] = nil
            return true
        end,
    },
}

package.loaded["fetch"] = nil
local fetch = require("fetch")

local firstCallbackCallCount = 0
local secondCallbackCallCount = 0

local firstRequestId = fetch.request("https://example.com/first", {}, function(statusCode, responseBody)
    firstCallbackCallCount = firstCallbackCallCount + 1
    assertEqual(statusCode, 200, "first callback receives response status")
    assertEqual(responseBody, "{\"ok\":true}", "first callback receives response body")

    local nestedRequestId = fetch.request("https://example.com/second", {}, function(nestedStatusCode, nestedResponseBody)
        secondCallbackCallCount = secondCallbackCallCount + 1
        assertEqual(nestedStatusCode, 200, "nested callback receives response status")
        assertEqual(nestedResponseBody, "{\"nested\":true}", "nested callback receives response body")
    end)

    files[".web_fetch_bridge/responses/" .. nestedRequestId .. ".json"] = "{\"status\":200,\"body\":\"{\\\"nested\\\":true}\"}"
end)

files[".web_fetch_bridge/responses/" .. firstRequestId .. ".json"] = "{\"status\":200,\"body\":\"{\\\"ok\\\":true}\"}"

fetch.update()
fetch.update()

assertEqual(firstCallbackCallCount, 1, "first response callback runs exactly once")
assertEqual(secondCallbackCallCount, 1, "nested response callback runs exactly once after the table mutates")

os.time = originalTime
love = originalLove
