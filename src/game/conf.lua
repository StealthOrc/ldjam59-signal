function love.conf(t)
    t.identity = "northbound-drift-run"
    t.version = "11.5"
    t.console = true

    t.window.title = "Northbound Drift Run"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.minwidth = 960
    t.window.minheight = 540
    t.window.vsync = 1

    t.modules.physics = false
end
