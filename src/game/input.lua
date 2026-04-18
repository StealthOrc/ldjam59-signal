local input = {}

function input.getTrackAction(key)
    if key == "1" or key == "left" or key == "a" then
        return 1
    end

    if key == "2" or key == "right" or key == "d" then
        return 2
    end

    if key == "space" or key == "tab" then
        return "toggle"
    end

    return nil
end

return input
