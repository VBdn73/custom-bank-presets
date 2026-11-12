-- Own the refresh/cleanup callbacks for client-provided editor layers.
local views = {}

function views.new()
    local active = {}
    local manager = {}

    function manager.remove(layer)
        local previous = active[layer]
        active[layer] = nil
        -- The client may have disposed the host before notifying the plugin.
        if previous and previous.destroy then pcall(previous.destroy) end
    end

    function manager.set(layer, refresh, destroy)
        manager.remove(layer)
        active[layer] = { refresh = refresh, destroy = destroy }
    end

    function manager.update()
        for layer, view in pairs(active) do
            if view.refresh and not pcall(view.refresh) then manager.remove(layer) end
        end
    end

    function manager.clear()
        for layer in pairs(active) do manager.remove(layer) end
    end

    return manager
end

return views
