function love.conf(t)
    t.identity = "out-of-signal"
    t.version = "11.5"
    t.console = true

    t.window.title = "Out of Signal"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 960
    t.window.minheight = 540
    t.window.vsync = 1

    t.modules.physics = false
end
