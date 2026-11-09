-- Resolve names once per plugin session, in small batches on the logic tick.
local index = { entries = {}, next = 0, maxId = 70000 }
local seenNames = {}
local excludedNameParts = { "(broken)", "(damaged)", "(uncharged)" }
local excludedNamePrefixes = { "augmented", "broken" }

local function isExcluded(lowerName)
    for _, part in ipairs(excludedNameParts) do
        if lowerName:find(part, 1, true) then return true end
    end
    for _, prefix in ipairs(excludedNamePrefixes) do
        if lowerName:sub(1, #prefix) == prefix then return true end
    end
    return false
end

function index.step(limit, lookup)
    local last = math.min(index.maxId, index.next + limit - 1)
    for itemId = index.next, last do
        local ok, name = pcall(function()
            local obj = lookup(itemId)
            return obj and obj.name
        end)
        if ok and type(name) == "string" and name:match("%S") and name ~= "null" then
            local lower = name:lower()
            if not seenNames[name] and not isExcluded(lower) then
                seenNames[name] = true
                index.entries[#index.entries + 1] = { id = itemId, name = name, lower = lower }
            end
        end
    end
    index.next = last + 1
    return index.next > index.maxId
end

function index.search(query)
    query = query:match("^%s*(.-)%s*$"):lower()
    local results = {}
    if query == "" then return results end
    for _, entry in ipairs(index.entries) do
        if entry.lower:find(query, 1, true) then results[#results + 1] = entry end
    end
    table.sort(results, function(a, b)
        local ap, bp = a.lower:find(query, 1, true) == 1, b.lower:find(query, 1, true) == 1
        if ap ~= bp then return ap end
        if a.lower ~= b.lower then return a.lower < b.lower end
        return a.id < b.id
    end)
    return results
end

return index
