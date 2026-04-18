local input = {}

function input.getLevelShortcut(key)
    if key == "f1" then
        return 1
    end

    if key == "f2" then
        return 2
    end

    if key == "f3" then
        return 3
    end

    return nil
end

return input
