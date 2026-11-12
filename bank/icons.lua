local catalogue = require("presets/icon_catalogue")
local slots = require("presets/slots")
local renderer = {}
local states, errors = {}, {}
-- Native number labels sit close to the row border. Give replacement icons
-- a small inset like the editor preview, without moving native labels or hits.
local horizontalInset = 4
-- Item artwork includes padding inside its native canvas. Give it a larger
-- canvas than skill sprites so the visible artwork is closer in size.
local itemScale = 4 / 3
-- Keep injected children out of the native category-0 ID sequence. Both IDs
-- remain within the client's accepted range, as in the compact renderer.
local spriteCategory = 1

local function editable(number)
    return number and not number.isRestricted and number.type == ui.ComponentType.LABEL
end

local function release(slot)
    local state = states[slot]
    states[slot] = nil
    if not state then return end
    -- A bank rebuild may already have disposed the old components. Never undo
    -- newer native text, or modify labels that have become restricted.
    pcall(function()
        if editable(state.number) and state.number.content == "" then
            state.number.content = state.original
        end
    end)
    if state.sprite then pcall(function() state.sprite:Destroy() end) end
    if state.text then pcall(function() state.text:Destroy() end) end
end

local function resolve(binding)
    return ui.Interfaces:GetComponent(binding.interfaceID, binding.staticID,
        binding.categoryID, binding.dynamicID)
end

local function apply(binding, store, textStore)
    local slot = binding.slot
    local iconKey = store.get(slot)
    local spriteID, entry = catalogue.resolve(iconKey)
    local iconText = textStore and textStore.get(slot) or ""
    local number = resolve(binding)
    if (not spriteID and iconText == "" and iconKey ~= "blank") or not editable(number) then release(slot); return end
    local parent = number.parent
    if not parent or parent.isRestricted then release(slot); return end
    local state = states[slot]
    if state and (state.number ~= number or state.parent ~= parent or state.spriteID ~= spriteID) then
        release(slot)
        state = nil
    end
    if not state then
        state = { number = number, parent = parent,
            spriteID = spriteID, original = number.content }
        states[slot] = state
        if spriteID then
            local sprite = ui.Sprite.new(parent, spriteCategory, slot)
            assert(sprite, "Native number parent rejected sprite creation.")
            state.sprite = sprite
            sprite.clickthrough = true
            sprite.enabled = false
            catalogue.apply(sprite, spriteID, entry)
            sprite.rgba = 0xFFFFFFFF
        end
    elseif number.content ~= "" then
        -- Native scripts may redraw the number after Logic, including selection.
        state.original = number.content
    end
    if state.sprite then
        local widthLimit = number.width * (entry.objectID and itemScale or 1)
        local scale = math.min(widthLimit / entry.width, number.height / entry.height, 1)
        assert(scale > 0, "Number label has no drawable bounds.")
        local w = math.max(1, math.floor(entry.width * scale))
        local h = math.max(1, math.floor(entry.height * scale))
        state.sprite:SetSize(w, h)
        state.sprite:SetPos(number.x + horizontalInset + math.floor((number.width - w) / 2),
            number.y + math.floor((number.height - h) / 2))
        state.sprite.hidden = not number.visibleGlobal
    -- Selection scripts can reorder native sibling backgrounds after creation.
    -- Raise only our non-interactive child, without changing native hit targets.
        state.sprite:MoveToFront()
        assert((entry.objectID and state.sprite.associatedObjectID or state.sprite.spriteID) == spriteID,
            "Native icon assignment was not accepted.")
    end
    if iconText ~= "" then
        if not state.text then
            state.text = ui.Text.new(parent, spriteCategory + 2, slot)
            assert(state.text, "Native number parent rejected icon text creation.")
            state.text.clickthrough, state.text.enabled = true, false
            state.text.font = id.Font.MUSEO_SANS_11PT_REGULAR or id.Font.MUSEO_SANS_15PT_REGULAR
            state.text.alignHorizontal, state.text.alignVertical = ui.AlignMode.CENTRE, ui.AlignMode.CENTRE
            state.text.maxLines, state.text.isShadowed = 1, true
        end
        state.text:SetSize(40, number.height)
        state.text:SetPos(number.x + horizontalInset + math.floor((number.width - 40) / 2),
            number.y + (spriteID and 6 or 0))
        state.text.content, state.text.rgba = iconText, number.rgba
        state.text.hidden = not number.visibleGlobal
        state.text:MoveToFront()
    elseif state.text then
        state.text:Destroy()
        state.text = nil
    end
    -- Sibling placement inherits native list scrolling/clipping without changing
    -- hit targets, row backgrounds, visibility, or input hooks. Only clear text
    -- after construction, resource assignment and layout have succeeded.
    if number.content ~= "" then number.content = "" end
end

function renderer.update(bindings, store, textStore)
    local active = {}
    for _, binding in ipairs(bindings or {}) do
        local slot = binding.slot
        if slots.valid(slot) then
            active[slot] = true
            local ok, err = pcall(apply, binding, store, textStore)
            if not ok then
                release(slot)
                local message = tostring(err)
                if errors[slot] ~= message then
                    print(("[Preset icons] Preset %d: number retained; %s"):format(slot, message))
                    errors[slot] = message
                end
            else
                errors[slot] = nil
            end
        end
    end
    for slot in pairs(states) do
        if not active[slot] then release(slot) end
    end
end

function renderer.restore()
    for slot in pairs(states) do release(slot) end
    states, errors = {}, {}
end

return renderer
