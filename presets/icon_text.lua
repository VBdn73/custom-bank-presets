local names = require("presets/names")
local slots = require("presets/slots")
local storage = require("storage")
local constants = require("constants")
local iconText = {}
local cache, context = {}, nil

local function key(slot)
    local current = names.getContext()
    if current ~= context then cache, context = {}, current end
    if not context then return nil end
    return "presetIconText.v1.displayName." .. context .. "." .. slot
end

function iconText.normalize(value)
    if type(value) == "string" and #value <= constants.maximumIconTextLength
        and (value == "" or value:match("^[A-Za-z0-9]+$")) then
        return value
    end
    return nil, ("Icon text must contain at most %d letters or numbers."):format(constants.maximumIconTextLength)
end

function iconText.get(slot)
    if not slots.valid(slot) then return "" end
    local storageKey = key(slot)
    if not storageKey then return "" end
    if cache[storageKey] == nil then
        cache[storageKey] = iconText.normalize(PersistentDB:GetString(storageKey)) or ""
    end
    return cache[storageKey]
end

function iconText.save(slot, value)
    local normalized, message = iconText.normalize(value)
    if not slots.valid(slot) or normalized == nil then return false, message or "Invalid preset." end
    local storageKey = key(slot)
    if not storageKey then return false, "Log in before saving icon text." end
    if not storage.writeVerified(storageKey, normalized) then return false, "Icon text storage verification failed." end
    cache[storageKey] = normalized
    return true
end

return iconText
