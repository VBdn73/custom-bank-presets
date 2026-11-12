-- Adapt PrettyUI's overlay stack to the picker components' attachment contract.
local overlays = {}

function overlays.attachTo(contentHost)
    if not contentHost or not contentHost._RegisterOverlay then return nil end
    return function(root, updatePosition)
        contentHost:_RegisterOverlay(root, nil, updatePosition)
        contentHost:_SyncOverlays(false)
        return function() contentHost:_UnregisterOverlay(root) end
    end
end

return overlays
