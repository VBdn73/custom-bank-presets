-- Position a plugin-owned popup beside its anchor, never outside its host.
local position = {}

function position.global(component)
    local point = component.xyGlobal
    if point then return point.x, point.y end
    local x, y = component.x or 0, component.y or 0
    if component.parent then
        local px, py = position.global(component.parent)
        x, y = x + px, y + py
    end
    return x, y
end

function position.beside(root, parent, anchor, width, height)
    local ax, ay = position.global(anchor)
    local px, py = position.global(parent)
    local x, y = ax - px + anchor.width + 8, ay - py
    if x + width > parent.width then x = ax - px - width - 8 end
    root:SetPos(math.max(0, math.min(x, parent.width - width)),
        math.max(0, math.min(y, parent.height - height)))
end

return position
