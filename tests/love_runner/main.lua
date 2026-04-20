function love.load(args)
    local testPath = args and args[1]
    if not testPath or testPath == "" then
        error("expected a test path argument", 2)
    end

    local ok, err = pcall(dofile, testPath)
    if not ok then
        error(err, 0)
    end

    love.event.quit(0)
end
